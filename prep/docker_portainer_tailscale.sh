#!/bin/bash
# (¯`·¯`·.¸¸.·´¯`·.¸¸.·´¯`·.¸¸.·´¯`··´¯)
# ( \                                / )
# ( ) Docker + Portainer + Tailscale ( )
# ( /                                \ )
# (.·´¯`·.¸¸.·´¯`·.¸¸.·´¯`·.¸¸.·´¯`·. )

set -euo pipefail

# === Parameters ===
PORTAINER_VERSION="${PORTAINER_VERSION:-latest}"   # override with e.g. 2.21.0
TAILNET_DOMAIN="shorthair-egret.ts.net"            # your tailnet domain
HOSTNAME="$(hostname)"
CERT_DIR="/etc/tailscale/certs"

# === System Update ===
export DEBIAN_FRONTEND=noninteractive
apt update && apt upgrade -y

# === Install Docker ===
apt install -y ca-certificates curl gnupg lsb-release
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/debian bookworm stable" > /etc/apt/sources.list.d/docker.list
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable docker && systemctl start docker

# === Install Tailscale ===
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --ssh --accept-dns=false   # adjust flags as needed

# === Fetch Tailscale Certificates ===
mkdir -p "$CERT_DIR"
tailscale cert "${HOSTNAME}.${TAILNET_DOMAIN}" \
  --cert-file "${CERT_DIR}/cert.pem" \
  --key-file "${CERT_DIR}/key.pem"

# === Install Portainer with Tailscale Certs ===
docker volume create portainer_data
docker run -d \
  -p 9443:9443 \
  -p 9000:9000 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  -v ${CERT_DIR}:/certs:ro \
  portainer/portainer-ce:${PORTAINER_VERSION} \
  --sslcert /certs/cert.pem \
  --sslkey /certs/key.pem

# === Setup Renewal Script ===
cat << 'EOF' > /usr/local/bin/tailscale-cert-renew.sh
#!/bin/bash
set -euo pipefail

CERT_DIR="/etc/tailscale/certs"
HOSTNAME="$(hostname)"
TAILNET_DOMAIN="shorthair-egret.ts.net"

tailscale cert "${HOSTNAME}.${TAILNET_DOMAIN}" \
  --cert-file "${CERT_DIR}/cert.pem" \
  --key-file "${CERT_DIR}/key.pem"

docker restart portainer
EOF

chmod +x /usr/local/bin/tailscale-cert-renew.sh

# === Systemd Service ===
cat << 'EOF' > /etc/systemd/system/tailscale-cert-renew.service
[Unit]
Description=Renew Tailscale certificates and reload Portainer
After=network-online.target tailscaled.service
Requires=tailscaled.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/tailscale-cert-renew.sh
EOF

# === Systemd Timer ===
cat << 'EOF' > /etc/systemd/system/tailscale-cert-renew.timer
[Unit]
Description=Run Tailscale certificate renewal daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now tailscale-cert-renew.timer

# === Cleanup ===
apt autoremove -y && apt clean

echo "✅ Deployment complete: Docker, Portainer, and Tailscale certs installed with auto-renewal."
