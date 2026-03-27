# ADR 0010: Migrate DNS from Porkbun to Hetzner DNS

**Date:** 2026-03-25
**Status:** Accepted

## Context

DNS records for `victorpatrin.dev` and `coupette.club` are managed manually in Porkbun's dashboard. This is the only piece of infrastructure not captured in code — a VPS IP change requires logging into a web UI and editing records by hand.

Terraform manages the cloud firewall via the Hetzner Cloud provider (Terraform config). Since v1.54 (Oct 2025), the `hetznercloud/hcloud` provider includes native DNS resources (`hcloud_zone`, `hcloud_zone_rrset`), using the same API and token.

The old Hetzner DNS Console (`dns.hetzner.com`) with its separate API is shutting down in May 2026. Community providers (`timohirt/hetznerdns`, `germanbrew/hetznerdns`) are deprecated. The hcloud-native path is the only supported option going forward.

## Options considered

1. **Stay on Porkbun DNS** — no migration effort, but DNS remains manual. No Terraform provider.
2. **Cloudflare DNS** — feature-rich (proxy, WAF), but adds a third-party dependency for a simple A-record setup. Overkill.
3. **Hetzner DNS via hcloud provider** — free, same `HCLOUD_TOKEN`, native Terraform resources. Same vendor as the VPS.

## Decision

Migrate authoritative DNS to Hetzner DNS using the native `hcloud` provider. Porkbun remains the domain registrar (registration, renewal, WHOIS). Only the nameserver delegation changes.

DNS zones and RRSets are defined in Terraform. A records reference `var.vps_ip` — set to web-01's IP via `.tfvars`. During DR, update this variable to point to the replacement server.

## Rationale

- **Single provider, single token** — VPS + firewall + DNS all use `hcloud` with `HCLOUD_TOKEN`. No new credentials.
- **No new vendor** — Hetzner already hosts the VPS and state backend. Consolidates the control plane.
- **Free and simple** — Hetzner DNS has no cost and no record limits. Matches the complexity of a 2-domain, 4-record setup.
- **Reversible** — switching NS back to Porkbun takes 5 minutes. Low-risk migration.

## Consequences

- Nameserver delegation change requires manual action at Porkbun (one-time).
- DNS propagation takes up to 48 hours after NS switch (typically much faster).
- Porkbun dashboard is no longer the source of truth for DNS records — Terraform is.
- DNS lives in the Terraform state (permanent state), decoupled from server provisioning. A records reference `var.vps_ip` — during DR, update this variable to point to the new server. DNS never switches automatically.
