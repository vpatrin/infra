# ADR 0002: Caddy as Reverse Proxy

**Date:** 2026-03-16
**Status:** Accepted

## Context

The platform needs a reverse proxy to terminate TLS, route traffic to multiple services (homepage, umami, uptime-kuma, coupette), and serve static files — all on a single VPS with multiple domains and subdomains.

## Options considered

1. **Nginx** — industry standard, massive ecosystem. But TLS requires manual certbot setup, config syntax is verbose, reloads need a signal or restart. Operational overhead not justified for 4 domains.
2. **Traefik** — auto-discovery via Docker labels, built-in ACME. But label-based config scatters routing logic across compose files — harder to reason about with multiple repos on the same network.
3. **Caddy** — automatic HTTPS out of the box (ACME + auto-renewal, zero config). Caddyfile syntax is minimal (~40 lines for all routing). Native static file serving. Live reload via `caddy reload` with no downtime.

## Decision

Use Caddy 2 as the reverse proxy. Auto-TLS and Caddyfile simplicity eliminate cert renewal and reload scripting. Caddy also serves static files directly (homepage, coupette SPA), removing the need for a separate static file server.

## Rationale

- TLS is fully automated — no certbot crons, no renewal failures to debug
- Adding a new service route is a 3-line Caddyfile change + reload
- All routing logic lives in one file (`services/caddy/Caddyfile`), not scattered across Docker labels or Nginx includes

## Consequences

- Caddy's ecosystem is smaller than Nginx's — advanced features (rate limiting, WAF) may require plugins or moving to a different proxy later.
- App repos depend on Caddy routes existing in this repo (see [ADR 0006](0006-consolidate-repos.md)).
