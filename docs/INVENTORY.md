# Inventory — Host → Stack Mapping

Source of truth for which stacks run on which hosts. Update when stacks move between hosts or new stacks are added.

## web-01 (Hetzner CX22, Debian 13)

| Stack | Services | Notes |
|---|---|---|
| `caddy` | caddy | Reverse proxy, TLS termination, serves homepage + `/srv/coupette` |
| `postgres` | shared-postgres | PostgreSQL 16 + pgvector; DBs: `saq_sommelier`, `umami` |
| `coupette-redis` | coupette-redis | Cache for coupette app |
| `umami` | umami | Self-hosted analytics |
| `uptime-kuma` | uptime-kuma | Status page + alerting |
| `observability` | loki, prometheus, cadvisor, alloy, grafana | Logs, metrics, dashboards (server + agent on same host) |

## Planned hosts

- `pi-home` (Raspberry Pi, LAN) — separate host, no cross-host networking for now. Candidate stacks: `pihole`, `vaultwarden`. See [ROADMAP.md](./ROADMAP.md).

## Deploy

Each host holds a clone of this repo at `~/infra` and runs `docker compose -f stacks/<name>/docker-compose.yml up -d` for each of its stacks. For web-01 this is automated via `scripts/deploy_infra.sh` (triggered through `make deploy` → GitHub Action → SSH).

Startup dependency order (matters on cold boot, not on re-deploy):

```
postgres → coupette-redis → caddy → umami → uptime-kuma → observability
```

Cross-stack dependencies (`umami` needs postgres healthy) rely on application-level retry, not `depends_on` — each stack is its own compose.
