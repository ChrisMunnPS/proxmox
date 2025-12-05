# Installing Tailscale on Proxmox LXC Container

## 01. Prepare the Container

Inside the container console, run:

```bash
apt update && apt upgrade
apt install curl -y
apt install sudo =y
```

## 02. Install Tailscale Addon

**On the Proxmox host console**, run the following script:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/addon/add-tailscale-lxc.sh)"
```

- Select your target CT (container) from the menu
- Wait for the installation to complete

## 03. Reboot the Container

Inside the **container console**, run either:

```bash
reboot
```

or

```bash
shutdown -r now
```

## 04.

## 05. Start Tailscale

After the container reboots, run:

```bash
tailscale up
```

You will be prompted to authenticate and will receive a URL that looks like this:

```
https://login.tailscale.com/a/b6e60b7017319
```

**Note:** Your URL will be different. Copy and paste it into your browser to complete authentication.

## 06. Final Update (Optional)

```bash
apt update && apt upgrade
```


## 07. Get certificate

```bash
tailscale cert
```


## 08. Allow SSH



## 09:  Install docker (https://get.docker.com)

```bash
# Download Script
curl -fsSL https://get.docker.com -o install-docker.sh

# Verify the script's content
#
#   $ cat install-docker.sh
#
# run the script either as root, or using sudo to perform the installation.
#
sudo sh install-docker.sh
```

---

## Important Notes

- Distinguish between commands run on the **Proxmox host** versus inside the **container (CT)**
- Make sure to complete the authentication step in your browser when prompted
- The authentication URL is unique to your installation
