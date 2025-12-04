#!/bin/bash
# (¯`·¯`·.¸¸.·´¯`·.¸¸.·´¯`·.¸¸.·´¯`··´¯)
# Docker + Portainer + Tailscale (HTTPS via Tailscale certs)
# (¯`·¯`·.¸¸.·´¯`·.¸¸.·´¯`·.¸¸.·´¯`··´¯)
set -euo pipefail

# === Parameters ===
PORTAINER_VERSION="${PORTAINER_VERSION:-latest}"
TAILNET_DOMAIN="shorthair-egret.ts.net"          # Your tailnet name
HOSTNAME="$(hostname)"
CERT_DIR="/etc/tailscale/certs"

# === Best practice: Use a pre-generated ephemeral/reusable key ===
# Generate via: tailscale admin console → Settings → Keys → Create key
# Recommended flags: --ephemeral --reusable --tag=tag:server --expire=2160h
TAILSCALE_AUTHKEY="${TAILSCALE_AUTHKEY:-}"        # Set via env or secrets!

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

# === Authenticate Tailscale (headless, no manual approval) ===
if [[ -z "$TAILSCALE_AUTHKEY" ]]; then
  echo "ERROR: TAILSCALE_AUTHKEY not set. Generate an ephemeral/reusable key with tags." >&2
  exit 1
fi
tailscale up --authkey="${TAILSCALE_AUTHKEY}" --ssh --accept-dns=false --hostname="${HOSTNAME}"

# === Fetch Tailscale LetsEncrypt certs ===
mkdir -p "$CERT_DIR"
tailscale cert "${HOSTNAME}.${TAILNET_DOMAIN}" \
  --cert-file "${CERT_DIR}/cert.pem" \
  --key-file "${CERT_DIR}/key.pem"

# === Run Portainer with Tailscale certs (HTTPS on 9443) ===
docker volume create portainer_data
docker run -d \
  -p 9443:9443 \
  -p 9000:9000 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  -v "${CERT_DIR}":/certs:ro \
  portainer/portainer-ce:${PORTAINER_VERSION} \
  --sslcert /certs/cert.pem \
  --sslkey /certs/key.pem

# === Renewal script (idempotent, won't fail timer) ===
cat << 'EOF' > /usr/local/bin/tailscale-cert-renew.sh
#!/bin/bash
set -euo pipefail
CERT_DIR="/etc/tailscale/certs"
HOSTNAME="$(hostname)"
TAILNET_DOMAIN="shorthair-egret.ts.net"

# Renew cert if expiring soon (fails gracefully if not needed yet)
tailscale cert "${HOSTNAME}.${TAILNET_DOMAIN}" \
  --cert-file "${CERT_DIR}/cert.pem" \
  --key-file "${CERT_DIR}/key.pem" || true

# Reload Portainer to pick up new cert
docker restart portainer || true
EOF
chmod +x /usr/local/bin/tailscale-cert-renew.sh

# === Systemd timer for daily renewal ===
cat << 'EOF' > /etc/systemd/system/tailscale-cert-renew.service
[Unit]
Description=Renew Tailscale certs and restart Portainer
After=network-online.target tailscaled.service
Requires=tailscaled.service
[Service]
Type=oneshot
ExecStart=/usr/local/bin/tailscale-cert-renew.sh
EOF

cat << 'EOF' > /etc/systemd/system/tailscale-cert-renew.timer
[Unit]
Description=Daily Tailscale cert renewal
[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=5h
[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now tailscale-cert-renew.timer

# === Final cleanup ===
apt autoremove -y && apt clean
echo "✅ Done. Access Portainer: https://${HOSTNAME}.${TAILNET_DOMAIN}:9443"
