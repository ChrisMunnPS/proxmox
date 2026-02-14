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
