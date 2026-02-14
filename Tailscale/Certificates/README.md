
# 🔐 Proxmox + Tailscale TLS Certs for an LXC (n8n)

![Proxmox](https://img.shields.io/badge/Proxmox-ED5C2B?logo=proxmox&logoColor=white)
![Tailscale](https://img.shields.io/badge/Tailscale-000000?logo=tailscale&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?logo=linux&logoColor=111)
![LXC](https://img.shields.io/badge/LXC-333333?logo=linuxcontainers&logoColor=white)
![HTTPS](https://img.shields.io/badge/HTTPS-enabled-success)
![Status](https://img.shields.io/badge/homelab-approved-blue)

---

## ✅ Executive summary

This repo documents how to expose a service running inside a **Proxmox LXC** over your **Tailscale** network using a valid **TLS certificate** for your `*.ts.net` hostname.

You’ll end up with:

- A Tailscale-connected LXC (example CT `102`)
- A stable hostname like `n8n.<your-tailnet>.ts.net`
- A real TLS cert issued by Tailscale (no self-signed warnings)
- Two supported approaches:
  - **Option A: `tailscale serve`** (fastest, lowest effort, recommended)
  - **Option B: `tailscale cert`** (you get cert files to use with nginx/caddy/etc)

---

## 📌 Table of contents

- [Architecture](#-architecture)
- [Prerequisites](#-prerequisites)
- [Step 1: Proxmox LXC config for Tailscale](#-step-1-proxmox-lxc-config-for-tailscale)
- [Step 2: Install and connect Tailscale inside the LXC](#-step-2-install-and-connect-tailscale-inside-the-lxc)
- [Option A: HTTPS via tailscale serve](#-option-a-https-via-tailscale-serve-recommended)
- [Option B: Generate cert files with tailscale cert](#-option-b-generate-cert-files-with-tailscale-cert)
- [Webhooks and base URL for n8n](#-webhooks-and-base-url-for-n8n)
- [Troubleshooting](#-troubleshooting)
- [Security notes](#-security-notes)

---

## 🧭 Architecture

### Option A: tailscale serve (recommended)
Tailscale terminates HTTPS and proxies to your local app:

`browser -> https://n8n.<tailnet>.ts.net -> tailscale serve -> http://127.0.0.1:5678`

### Option B: tailscale cert
Tailscale mints cert files and you terminate TLS with your own web server:

`browser -> https://n8n.<tailnet>.ts.net -> nginx/caddy (TLS) -> http://127.0.0.1:5678`

---

## 🧰 Prerequisites

- Proxmox VE host with an LXC container (example: CT **102**)
- Root access to:
  - Proxmox host shell
  - Container shell (`pct enter 102`)
- A Tailscale tailnet with admin access
- You know your desired hostname (example: `n8n` → `n8n.<tailnet>.ts.net`)

---

## 🧱 Step 1: Proxmox LXC config for Tailscale

Tailscale prefers a working `/dev/net/tun`. Configure the container to allow it.

On the **Proxmox host**:

```bash
nano /etc/pve/lxc/102.conf
````

Add:

```ini
features: keyctl=1,nesting=1
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

Restart the container:

```bash
pct reboot 102
```

✅ If you do NOT want to enable TUN, you can still run Tailscale later in userspace mode with `--tun=userspace-networking`.

---

## 🔗 Step 2: Install and connect Tailscale inside the LXC

Enter the container:

```bash
pct enter 102
```

Install Tailscale:

```bash
apt update
apt install -y curl
curl -fsSL https://tailscale.com/install.sh | sh
systemctl enable --now tailscaled
```

### Create an auth key (Tailscale admin console)

In the Tailscale admin console:

1. Go to **Settings → Keys** (or **Auth keys**)
2. Click **Generate auth key**
3. Suggested settings:

   * Description: `proxmox-ct102-n8n`
   * Reusable: optional (ON if you rebuild often)
   * Ephemeral: optional (usually OFF for a stable service node)
   * Expiry: your preference
4. Copy the key starting with `tskey-...`

### Bring the node up and set the hostname

Inside the container:

```bash
tailscale up --authkey tskey-PASTE_HERE --hostname n8n
```

Userspace fallback (if you skipped the `/dev/net/tun` config):

```bash
tailscale up --authkey tskey-PASTE_HERE --hostname n8n --tun=userspace-networking
```

Validate:

```bash
tailscale status
tailscale ip -4
```

At this point, you should have a hostname like:

`n8n.<your-tailnet>.ts.net`

---

## 🚀 Option A: HTTPS via tailscale serve (recommended)

This is the easiest way to get HTTPS without managing cert files.

Assuming n8n is listening on `127.0.0.1:5678`:

```bash
tailscale serve https / http://127.0.0.1:5678
```

Check status:

```bash
tailscale serve status
```

Now open:

`https://n8n.<your-tailnet>.ts.net`

To stop serving later:

```bash
tailscale serve reset
```

---

## 🧾 Option B: Generate cert files with tailscale cert

Use this if you want the cert and key on disk (for nginx/caddy/traefik, etc).

### 1) Generate the cert

Inside the container:

```bash
tailscale cert n8n.<your-tailnet>.ts.net
```

This produces two files in the current directory:

* `n8n.<your-tailnet>.ts.net.crt`
* `n8n.<your-tailnet>.ts.net.key`

### 2) Move them somewhere sensible

```bash
mkdir -p /etc/ssl/tailscale
mv n8n.<your-tailnet>.ts.net.* /etc/ssl/tailscale/
chmod 600 /etc/ssl/tailscale/n8n.<your-tailnet>.ts.net.key
```

### 3) Example nginx snippet

```nginx
server {
    listen 443 ssl;
    server_name n8n.<your-tailnet>.ts.net;

    ssl_certificate     /etc/ssl/tailscale/n8n.<your-tailnet>.ts.net.crt;
    ssl_certificate_key /etc/ssl/tailscale/n8n.<your-tailnet>.ts.net.key;

    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

Reload nginx:

```bash
systemctl reload nginx
```

### Notes on renewal

Tailscale certs are short-lived by design. You’ll typically want a renewal mechanism:

* cron/systemd timer calling `tailscale cert ...` periodically
* reload your web server after renewal

If you don’t want to manage renewals, Option A (`tailscale serve`) is the lowest-maintenance path.

---

## 🪝 Webhooks and base URL for n8n

If you use n8n webhooks, set the public URL so generated webhook URLs are correct.

Typical environment variables:

* `N8N_HOST=n8n.<your-tailnet>.ts.net`
* `N8N_PROTOCOL=https`
* `N8N_PORT=5678`
* `WEBHOOK_URL=https://n8n.<your-tailnet>.ts.net/`

Then restart n8n (method depends on how you installed it).

---

## 🧯 Troubleshooting

### `tailscale up` fails with TUN errors

* Ensure `/etc/pve/lxc/102.conf` has the TUN lines
* Restart the container
* Or use userspace mode:

  ```bash
  tailscale up --tun=userspace-networking ...
  ```

### HTTPS works but the app is unreachable

Check the app is listening:

```bash
ss -lntp | grep 5678
curl -I http://127.0.0.1:5678
```

### Wrong hostname / doesn’t resolve

Confirm the node name:

```bash
tailscale status
```

If needed, re-run:

```bash
tailscale up --hostname n8n
```

---

## 🛡️ Security notes

* `https://n8n.<tailnet>.ts.net` is reachable by devices on your Tailscale network.
* If you enable public access (Funnel), treat it like exposing a service to the internet.
* Keep your auth keys safe and prefer short expiry unless you specifically need long-lived keys.
* Restrict access with Tailscale ACLs if you have multiple users/devices.

---

## ✨ Quick command recap

```bash
# Proxmox host
nano /etc/pve/lxc/102.conf
pct restart 102

# Container
pct enter 102
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --authkey tskey-... --hostname n8n
tailscale serve https / http://127.0.0.1:5678
```

---

## 📎 License

MIT or whatever you prefer. 🙂

```
::contentReference[oaicite:0]{index=0}
```
