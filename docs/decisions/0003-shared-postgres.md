# ADR 0003: Shared PostgreSQL Instance

**Date:** 2026-03-16
**Status:** Accepted

## Context

Multiple services need PostgreSQL: coupette (with pgvector for wine embeddings) and umami (analytics). On a 4GB VPS, each Postgres instance carries memory overhead. pgvector requires a non-vanilla Postgres image.

## Options considered

1. **Per-service Postgres containers** — full isolation, but 2 instances = 2GB committed to databases alone. Init scripts, backups, and upgrades multiply. Overkill for this scale.
2. **Managed database (Hetzner, Supabase, Neon)** — zero ops, but adds external dependency and cost (~$10-15/mo). Latency increases for co-located setup. Vendor lock-in for pgvector availability.
3. **Single shared instance, multiple databases** — one `pgvector/pgvector:pg16` container. Init scripts create isolated users and databases. Each service connects with its own credentials. One backup script, one memory budget (1GB), one upgrade path.

## Decision

Run a single shared PostgreSQL container (`shared-postgres`) with per-service databases and users. Init script (`services/postgres/init-scripts/01-init-databases.sh`) creates databases on first boot. Uses `pgvector/pgvector:pg16` to support coupette's vector embeddings — superset of vanilla Postgres, so umami works unchanged.

## Rationale

- One Postgres to back up, monitor, and upgrade — `pg_dump` covers both databases in one script
- Memory budget is 1GB instead of 2GB+ — leaves headroom for app containers
- Adding a new database is a one-line addition to the init script

## Consequences

- Single point of failure — if Postgres goes down, both umami and coupette are affected. Mitigated by healthchecks and `restart: unless-stopped`.
- App repos depend on `shared-postgres` being available on the `internal` network (see [ADR 0006](0006-consolidate-repos.md)).
- Upgrading Postgres major versions requires migrating all databases at once.
