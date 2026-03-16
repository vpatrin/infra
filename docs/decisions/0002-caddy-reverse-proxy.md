# ADR 0002: Caddy as Reverse Proxy

**Date:** 2026-03-16
**Status:** Accepted

---

## Context

The platform needs a reverse proxy to terminate TLS, route traffic to multiple services (homepage, umami, uptime-kuma, coupette), and serve static files — all on a single VPS.

## Decision Drivers

- Solo developer — minimal ops burden
- Multiple domains and subdomains need TLS
- Static file serving (homepage SPA, coupette frontend) alongside reverse proxying
- No dedicated load balancer or CDN

## Options Considered

### Nginx

Industry standard. Massive ecosystem, well-documented. But TLS requires manual certbot setup (or a sidecar like acme-companion), config syntax is verbose, and reloads need a signal or restart. For a single VPS with 4 domains, the operational overhead isn't justified.

### Traefik

Auto-discovery via Docker labels, built-in ACME. But the label-based config scatters routing logic across compose files — harder to reason about when multiple repos attach to the same network. Dashboard is nice but unnecessary at this scale. More moving parts than needed.

### Caddy

Automatic HTTPS out of the box (ACME + auto-renewal, zero config). Caddyfile syntax is minimal — the entire routing config is 40 lines. Supports static file serving natively. Live reload via `caddy reload` with no downtime. Single binary, small image.

## Decision

**Use Caddy 2 as the reverse proxy.** The auto-TLS and Caddyfile simplicity eliminate an entire class of ops tasks (cert renewal, reload scripting). The Caddyfile is the single source of truth for all routing — readable by anyone in under a minute.

Caddy also serves static files directly (homepage at `/srv/homepage`, coupette SPA at `/srv/coupette`), removing the need for a separate static file server.

## Consequences

- TLS is fully automated — no certbot crons, no renewal failures to debug.
- Adding a new service route is a 3-line Caddyfile change + reload.
- All routing logic lives in one file (`services/caddy/Caddyfile`), not scattered across Docker labels or Nginx includes.
- Caddy's ecosystem is smaller than Nginx's — advanced features (rate limiting, WAF) may require plugins or moving to a different proxy later.
- App repos depend on Caddy routes existing in this repo (see platform contract in [ADR 0001](0001-consolidate-repos.md)).
