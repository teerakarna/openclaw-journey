# openclaw-journey

Automated deployment of [OpenClaw](https://github.com/steipete/openclaw) on a hardened Debian 12 VM on Proxmox.

Provision the VM with Terraform, harden and configure with Ansible. No ports exposed to the public internet — Tailscale is the only inbound path once provisioning is complete.

Full write-up: [OpenClaw Journey](https://teerakarna.github.io/posts/openclaw-journey/)

---

## What's in the box

| Tool | Purpose |
|---|---|
| Terraform + bpg/proxmox | Clone Debian 12 template, upload cloud-init snippet, provision VM |
| cloud-init | SSH key injection, hostname, base package install |
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
- An OpenClaw gateway token (`openssl rand -hex 32`)

**Proxmox datastore:** Terraform uploads the cloud-init snippet to the `local` datastore. Snippets must be enabled on it — in the Proxmox UI go to **Datacenter → Storage → local → Edit** and ensure `Snippets` is checked under Content.

---

## Quick start

### 1. Create the Debian 12 cloud-init template (one-time)

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

If VM ID `9000` conflicts with an existing VM, use a different ID and update `template_vm_id` in `terraform.tfvars`.

### 2. Provision with Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — see variables.tf for full reference
```

Required variables:

| Variable | Description |
|---|---|
| `proxmox_url` | Proxmox API URL, e.g. `https://192.168.1.100:8006/` |
| `vm_ip` | Static IP to assign to the VM |
| `gateway` | Default gateway |
| `ssh_public_key` | SSH public key injected for the `openclaw` user |

Authenticate via environment variables:

```bash
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
# Fill in your values (see secrets.yml.example for all fields)
ansible-vault encrypt vars/secrets.yml

ansible-playbook -i inventory.ini site.yml --ask-vault-pass
```

Ansible runs three roles in order: `hardening` → `tailscale` → `openclaw`.

---

## Secrets

Copy `ansible/vars/secrets.yml.example` to `ansible/vars/secrets.yml`, fill in your values, then encrypt with `ansible-vault`.

| Key | Required | Description |
|---|---|---|
| `tailscale_auth_key` | Yes | One-time auth key from Tailscale admin console |
| `discord_bot_token` | Yes | Discord bot token for the OpenClaw agent |
| `openclaw_gateway_token` | Yes | Gateway secret — generate with `openssl rand -hex 32` |
| `local_network` | No | Your LAN CIDR for UFW allow rules (default: `192.168.0.0/16`) |
| `openclaw_port` | No | Port OpenClaw listens on (default: `4096`) |

---

## Security

- SSH key auth only, root login disabled
- UFW: default deny inbound; outbound allowlisted; LAN SSH allowed
- fail2ban: SSH brute-force protection — 5 attempts, 1-hour ban
- Unattended security upgrades enabled
- OpenClaw runs as a non-root `openclaw` system user
- systemd service hardening: `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem`
- All secrets managed via ansible-vault — no plaintext credentials in the repo
- No public ports — Tailscale is the only way in after provisioning

---

## Repository structure

```
terraform/
  main.tf                    # VM resource (full clone + cloud-init)
  variables.tf               # All input variables with defaults
  outputs.tf                 # VM IP + SSH connection string
  terraform.tfvars.example   # Copy to terraform.tfvars and fill in
  cloud-init/
    user-data.yaml.tpl       # Bootstrap template: SSH key injection, base packages

ansible/
  site.yml                   # Main playbook (hardening → tailscale → openclaw)
  inventory.ini              # Target host
  ansible.cfg                # Project-level Ansible config
  vars/
    secrets.yml              # ansible-vault encrypted (git-ignored)
    secrets.yml.example      # Template — copy, fill in, encrypt
  roles/
    hardening/               # sshd config, UFW rules, fail2ban, sysctl hardening
    tailscale/               # Install Tailscale package + register with auth key
    openclaw/
      tasks/main.yml         # Node.js install, clone repo, write .env, enable service
      templates/
        env.j2               # .env file template
        openclaw.service.j2  # systemd unit template
```

---

## After provisioning

OpenClaw is reachable from any device on your tailnet at `http://<tailscale-ip>:4096`.

Once confirmed over Tailscale, drop the public SSH port:

```bash
ssh openclaw@<tailscale-ip>
sudo ufw delete allow 22/tcp
sudo ufw allow in on tailscale0 to any port 22
```

SSH is then only reachable via Tailscale.
