# ELK VM

> Centralized SIEM core for the homelab security stack. Runs Elasticsearch, Kibana, and Fluent Bit on NixOS — fully declarative, reproducible, and version-controlled.

Part of the [Homelab Security Stack](https://github.com/impulseSecDev/NIX-HOMELAB-SECURITY-STACK).

---

## Overview

The ELK VM is the log aggregation and analysis hub for the homelab. All hosts ship structured logs via Fluent Bit over a dedicated WireGuard log shipping channel. Logs are indexed in Elasticsearch and visualized through Kibana with KQL queries and custom dashboards.

The entire VM state is declared in NixOS configuration. Elasticsearch and Kibana run as Docker containers via `virtualisation.oci-containers` — managed by systemd, fully reproducible despite running in containers.

---

## Stack

| Component | Version | Purpose |
|---|---|---|
| Elasticsearch | 8.13.0 | Log storage, indexing, KQL search |
| Kibana | 8.13.0 | Dashboards, visualizations, alerting |
| Fluent Bit | 4.x | Structured log ingestion, local log shipping |
| Nginx | — | HTTPS reverse proxy, Tailscale-only access |
| Wazuh Agent | 4.14.3 | Host monitoring, FIM, alert shipping to Wazuh VM |
| sops-nix | — | Encrypted secrets management |

---

## Architecture

### Log Ingestion

All homelab hosts run Fluent Bit and ship logs to Elasticsearch over a dedicated WireGuard interface (`wg0`) — deliberately separated from admin traffic. Each host tags its logs with a unique `logstash_prefix` so indices are cleanly separated per host in Elasticsearch.

```
Daily Driver  ─┐
Wazuh VM      ─┤  WireGuard wg0 (log shipping only)  →  Fluent Bit  →  Elasticsearch
Vaultwarden   ─┤
Laptop        ─┘
ELK VM        ──  localhost  →  Fluent Bit  →  Elasticsearch
```

### Access

Kibana is accessible exclusively over the Tailscale mesh — Nginx terminates TLS on the Tailscale interface. Not reachable from the public internet.

```
Tailnet member → Tailscale → ELK VM Nginx (HTTPS) → Kibana
```

### TLS

Wildcard certificate for `*.mesh.mydomain.com` provisioned automatically via the NixOS `security.acme` module using Cloudflare DNS-01 challenge validation. No manual certificate management.

### Secrets

All credentials (Elasticsearch username, password) are managed via sops-nix — encrypted at rest in version control, decrypted at activation time using a host-specific age key. Fluent Bit receives credentials via a sops-managed config template rendered to `/run/secrets/fluent-bit.conf` at runtime. No credentials are hardcoded in any configuration file.

---

## NixOS Module Structure

```
nixos/
├── configuration.nix     # Entry point, imports all modules
├── hardware-configuration.nix
├── flake.nix
├── elasticsearch.nix     # Elasticsearch + Kibana oci-containers
├── fluent-bit.nix        # Fluent Bit with sops template
├── nginx.nix             # HTTPS reverse proxy for Kibana
├── wireguard.nix         # wg0 log shipping tunnel
├── sops.nix              # sops-nix configuration
└── secrets/
    └── secrets.yaml      # sops-encrypted secrets (safe to commit)
```

---

## Defense in Depth

- Kibana not exposed publicly — Tailscale-only access
- Elasticsearch bound to localhost — not reachable outside the VM directly
- Log shipping over encrypted WireGuard tunnel — VPS relay cannot read contents
- Wazuh agent monitors the VM itself — FIM on config files, rootkit detection
- TLS on all external-facing interfaces via automated Let's Encrypt certificates
- sops-nix encrypted secrets — no plaintext credentials in version control

---

## Tech Stack

`NixOS` `Elasticsearch` `Kibana` `Fluent Bit` `WireGuard` `Tailscale` `Nginx` `Docker` `sops-nix` `ACME / Let's Encrypt` `Cloudflare DNS-01` `KQL` `SIEM` `Log aggregation` `Declarative infrastructure`
