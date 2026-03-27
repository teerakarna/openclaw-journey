# openclaw-journey

Automated deployment of [OpenClaw](https://github.com/steipete/openclaw) on a hardened Debian 12 VM on Proxmox.

Provision the VM with Terraform, harden and configure with Ansible. No ports exposed to the public internet — Tailscale only.

Full write-up: [OpenClaw Journey blog post](https://teerakarna.github.io/posts/openclaw-journey/)

---

## What's in the box

| Tool | Purpose |
|---|---|
| Terraform + bpg/proxmox | Clone Debian 12 template, cloud-init bootstrap |
| cloud-init | SSH key injection, base package install |
| Ansible | OS hardening, Tailscale install + auth, OpenClaw systemd service |
| Tailscale | Zero-trust access — the only inbound path |
| Discord | Primary agent interface |

---

## Prerequisites

- Proxmox VE 8.x host
- Terraform >= 1.9
- Ansible >= 2.15
- A Tailscale auth key (one-time use, from the Tailscale admin console)
- A Discord bot token

---

## Quick start

### 1. Create the Proxmox template (one-time)

SSH into your Proxmox host as root:

```bash
wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2

qm create 9000 --name debian-12-cloud --memory 2048 --cores 2 \
  --net0 virtio,bridge=vmbr0 --serial0 socket --vga serial0

qm importdisk 9000 debian-12-genericcloud-amd64.qcow2 local-lvm

qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --ipconfig0 ip=dhcp
qm set 9000 --agent enabled=1

qm template 9000
```

Change VM ID `9000` if it conflicts with an existing VM and update `template_vm_id` in `terraform.tfvars`.

### 2. Provision with Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — Proxmox URL, node, VM IP, SSH public key

export PROXMOX_VE_USERNAME="root@pam"
export PROXMOX_VE_API_TOKEN="root@pam!openclaw=<your-token-secret>"

terraform init
terraform apply
```

Terraform outputs the VM IP and an SSH connection string when complete.

### 3. Deploy with Ansible

```bash
cd ../ansible
# Update inventory.ini with the IP from terraform output

cp vars/secrets.yml.example vars/secrets.yml
# Fill in: tailscale_auth_key, discord_bot_token, openclaw_gateway_token
ansible-vault encrypt vars/secrets.yml

ansible-playbook -i inventory.ini site.yml --ask-vault-pass
```

---

## Security

- SSH key auth only, root login disabled
- UFW: default deny inbound; outbound allowlisted
- fail2ban: SSH, 5 attempts, 1-hour ban
- Unattended security upgrades enabled
- OpenClaw runs as a non-root `openclaw` system user
- systemd service hardening: `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem`
- All secrets via ansible-vault — no plaintext credentials in the repo
- No public ports — Tailscale is the only way in

---

## Repo structure

```
terraform/
  main.tf                    # VM resource + cloud-init file upload
  variables.tf               # All input variables
  outputs.tf                 # VM IP + SSH string
  terraform.tfvars.example   # Copy to terraform.tfvars and fill in
  cloud-init/
    user-data.yaml.tpl       # Bootstrap template: SSH key, base packages

ansible/
  site.yml                   # Main playbook
  inventory.ini              # Target host
  ansible.cfg                # Project-level Ansible config
  vars/
    secrets.yml              # ansible-vault encrypted secrets (git-ignored)
    secrets.yml.example      # Template — copy and fill in
  roles/
    hardening/               # SSH config, UFW, fail2ban, sysctl
    tailscale/               # Install Tailscale + auth
    openclaw/                # Node.js, clone, .env, systemd service
```

---

## After provisioning

OpenClaw is reachable at `http://<tailscale-ip>:4096` from any device on your tailnet.

Once confirmed over Tailscale, tighten UFW to drop the public SSH port:

```bash
ssh openclaw@<tailscale-ip>
sudo ufw delete allow 22/tcp
sudo ufw allow in on tailscale0 to any port 22
```
