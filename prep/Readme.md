# Installing Tailscale on Proxmox LXC Container

## 1. Prepare the Container

Inside the container console, run:

```bash
apt update && apt upgrade
apt install curl -y
apt install sudo =y
```

## 2. Install Tailscale Addon

**On the Proxmox host console**, run the following script:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/addon/add-tailscale-lxc.sh)"
```

- Select your target CT (container) from the menu
- Wait for the installation to complete

## 3. Reboot the Container

Inside the **container console**, run either:

```bash
reboot
```

or

```bash
shutdown -r now
```

## 4. Start Tailscale

After the container reboots, run:

```bash
tailscale up
```

You will be prompted to authenticate and will receive a URL that looks like this:

```
https://login.tailscale.com/a/b6e60b7017319
```

**Note:** Your URL will be different. Copy and paste it into your browser to complete authentication.

## 5. Final Update (Optional)

```bash
apt update && apt upgrade
```

---

## Important Notes

- Distinguish between commands run on the **Proxmox host** versus inside the **container (CT)**
- Make sure to complete the authentication step in your browser when prompted
- The authentication URL is unique to your installation
