# ADR 0003: Shared PostgreSQL Instance

**Date:** 2026-03-16
**Status:** Accepted

---

## Context

Multiple services need PostgreSQL: coupette (with pgvector for wine embeddings) and umami (analytics). On a 4GB VPS, how we run Postgres matters — each instance carries memory overhead and operational burden.

## Decision Drivers

- 4GB RAM total — memory is the binding constraint
- Two databases today, potentially more as new services launch
- pgvector required for coupette's RAG search — needs a non-vanilla Postgres image
- Solo developer — fewer things to operate is better

## Options Considered

### Per-service Postgres containers

Each app bundles its own Postgres. Full isolation — one crash doesn't affect another. But on a 4GB VPS with `mem_limit`, two Postgres containers means 2GB committed to databases alone. Init scripts, backups, and upgrades multiply per instance. Overkill for this scale.

### Managed database (Hetzner, Supabase, Neon)

Zero ops, automated backups, connection pooling. But adds external dependency and cost (~$10-15/mo minimum). Latency increases for a co-located setup. Vendor lock-in for pgvector availability. At our traffic level, managed Postgres solves problems we don't have.

### Single shared instance, multiple databases

One `pgvector/pgvector:pg16` container serving both databases. Init scripts create isolated users and databases on first start. Each service connects with its own credentials — umami can't see coupette's data and vice versa. One backup script, one memory budget (1GB), one upgrade path.

## Decision

**Run a single shared PostgreSQL container (`shared-postgres`) with per-service databases and users.**

The init-script pattern (`services/postgres/init-scripts/01-init-databases.sh`) creates databases and users on first boot. Each service's credentials are scoped to its own database. The container uses `pgvector/pgvector:pg16` to support coupette's vector embeddings — this is a superset of vanilla Postgres, so umami works without changes.

The container is reachable by name (`shared-postgres`) on the `internal` Docker network. App repos connect to it without exposing Postgres to the public internet — the port binding is `127.0.0.1:5432` (localhost only, for DBeaver and Alembic from the host).

## Consequences

- One Postgres to back up, monitor, and upgrade — `pg_dump` covers both databases in one script.
- Memory budget is 1GB instead of 2GB+ — leaves headroom for app containers and pgvector workloads.
- Adding a new database is a one-line addition to the init script + a new `.env` entry.
- Single point of failure — if Postgres goes down, both umami and coupette are affected. Acceptable at this scale; mitigated by healthchecks and `restart: unless-stopped`.
- App repos depend on `shared-postgres` being available on the `internal` network (see platform contract in [ADR 0006](0006-consolidate-repos.md)).
- Upgrading Postgres major versions requires migrating all databases at once, not incrementally.
