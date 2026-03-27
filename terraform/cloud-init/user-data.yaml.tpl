#cloud-config

hostname: ${hostname}
fqdn: ${hostname}.local

users:
  - name: openclaw
    groups: [sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${ssh_pubkey}

ssh_pwauth: false
disable_root: true

package_update: true
package_upgrade: true
packages:
  - curl
  - git
  - ufw
  - fail2ban
  - unattended-upgrades
  - apt-listchanges
  - qemu-guest-agent
  - ca-certificates
  - gnupg

runcmd:
  - systemctl enable --now qemu-guest-agent
