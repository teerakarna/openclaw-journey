# SOUL — openclaw-journey

Metacontext for AI assistants, future contributors, and future-me.

## What this repo is

A reproducible, security-first deployment of OpenClaw on Proxmox. The goal is a
self-hosted, always-on AI agent that is:

- **Isolated** — proper VM boundary, not a container on a laptop
- **Reproducible** — destroy and rebuild in ~15 minutes
- **Hardened** — minimal attack surface, no public ports, non-root service user
- **Auditable** — every configuration decision is explicit and version-controlled

## Design decisions

### Proxmox over containers-on-macOS

Containers on macOS run through a Linux VM anyway (HyperKit/QEMU). A dedicated
Proxmox VM skips the emulation layer, runs proper Linux security primitives natively,
and does not depend on a laptop staying open. The VM is always-on and can be snapshotted
before risky agentic operations.

### Debian 12 over the alternatives

- **Alpine**: binary compatibility issues with Node.js native modules ruled it out
- **Ubuntu 24.04**: heavier default install, snap overhead, less minimal
- **Rocky Linux 9**: SELinux complexity is unjustified for a single-purpose personal VM
- **Debian 12**: minimal, stable, AppArmor-default, excellent cloud image support,
  long LTS cycle, well-documented hardening path

### Terraform + Ansible, not Ansible-only

Terraform owns the VM lifecycle (create, resize, destroy). Ansible owns the
configuration inside it. This separation means you can reprovision the VM without
redoing the app config, and reconfigure the app without touching infrastructure.

### cloud-init for bootstrap only

cloud-init solves the chicken-and-egg problem: Ansible needs SSH to connect, but SSH
needs a key — cloud-init injects the key before Ansible runs. Beyond that, cloud-init
stays minimal. Ansible is more readable, idempotent, and testable for everything else.

### Tailscale over VPN or port-forwarding

No firewall rules to maintain, no dynamic DNS, no certificates to rotate. Tailscale's
WireGuard mesh gives encrypted, authenticated access from any device on the tailnet.
The OpenClaw gateway never binds to a public interface.

### ansible-vault for secrets

Simple, no extra infrastructure required. The intention is to migrate to SOPS + age
keys eventually, which gives better key management without a Vault server.

## What this is NOT

- A production multi-tenant deployment
- A general-purpose Proxmox provisioning framework
- A Proxmox tutorial — assumes a working Proxmox host

## Intended evolution

1. Snapshot-before-task automation via the Proxmox API
2. SOPS + age keys replacing ansible-vault
3. Ollama sidecar VM for local LLM inference
4. Renovate for dependency updates on Node.js packages

## Notes for AI assistants

- Prefer minimal changes — do not add abstractions the codebase does not currently need
- Security decisions are intentional — flag concerns, do not silently remove hardening
- The Ansible roles are deliberately simple; do not refactor into collections without asking
- All secrets go through ansible-vault or environment variables — never plaintext in
  committed files
- `terraform.tfvars` and `vars/secrets.yml` are git-ignored; never suggest committing them
