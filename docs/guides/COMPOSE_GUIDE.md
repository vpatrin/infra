# Docker Compose Patterns for Production

How to structure compose files for containerized apps on a single VPS
behind a reverse proxy. The patterns are generic — adapt to your stack.

This guide covers the 3-file compose setup, networking, dev/prod workflow,
profiles, healthchecks, and logging. For Dockerfile patterns (multi-stage
builds, security hardening), see [DOCKERFILE_GUIDE.md](DOCKERFILE_GUIDE.md).

---

**What we'll cover:**

1. [The 3-file compose pattern](#1-the-3-file-compose-pattern) — base, dev override, prod override
2. [Security hardening](#2-security-hardening) — read-only, no caps, mem limits
3. [Networking](#3-networking) — plugging into the platform
4. [Dev vs prod workflow](#4-dev-vs-prod-workflow) — local builds vs pre-built images
5. [Profiles for optional services](#5-profiles-for-optional-services) — dev-only postgres, one-shot jobs
6. [Healthchecks](#6-healthchecks) — dependency ordering that actually works
7. [Logging](#7-logging) — rotation so the disk doesn't fill
8. [Checklist](#8-checklist) — before you ship

---

## 1. The 3-File Compose Pattern

Instead of one `docker-compose.yml` with conditionals and env-gated
logic, split into three files with clear roles:

| File | Role | When it's used |
|------|------|----------------|
| `docker-compose.yml` | Base config — hardened, prod-safe defaults | Always |
| `docker-compose.dev.yml` | Dev overrides — env files, port bindings, hot reload | Explicitly: `-f docker-compose.yml -f docker-compose.dev.yml` |
| `docker-compose.prod.yml` | Prod overrides — pre-built images, restart policy | Explicitly: `-f docker-compose.yml -f docker-compose.prod.yml` |

### Why three files

We name the dev file `docker-compose.dev.yml` (not `.override.yml`) so
it's never auto-loaded — running `docker compose up` on prod without
`-f` flags only picks up the base file. Both dev and prod require
explicit `-f` flags:

- **Dev**: `docker compose -f docker-compose.yml -f docker-compose.dev.yml up`
  — adds env files, port bindings, hot reload.
- **Prod**: `docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d`
  — adds restart policy, mem limits, pre-built images.

The base file is prod-safe by default (hardened, no volume mounts, no
port bindings). Dev convenience is layered on top via the dev file, not
baked in.

### Base file (`docker-compose.yml`)

The base defines every service with full hardening, healthchecks, and
networking. It builds from local Dockerfiles — CI and dev both use this.

```yaml
name: myapp
services:
  backend:
    build:
      context: .
      dockerfile: backend/Dockerfile
    container_name: myapp-backend
    env_file: .env
    ports:
      - "127.0.0.1:8001:8001"   # localhost only — Caddy proxies public traffic
    read_only: true
    security_opt: [no-new-privileges:true]
    cap_drop: [ALL]
    mem_limit: 512m
    logging:
      driver: json-file
      options:
        max-size: "50m"
        max-file: "3"
    healthcheck:
      # Most images don't bundle curl
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8001/health')"]
      interval: 10s
      timeout: 3s
      retries: 3
      start_period: 5s
    networks:
      - internal

networks:
  internal:
    external: true
```

Key decisions:

- **`context: .`** (project root, not `backend/`): the Dockerfile needs
  access to the shared `core/` package. Build context must include
  everything the Dockerfile `COPY`s.
- **`127.0.0.1:8001:8001`**: binds to localhost only. Caddy (in the
  reverse proxy) handles public routing. Never expose ports to `0.0.0.0`
  unless you want the internet to reach the container directly.
- **`env_file: .env`**: secrets stay in `.env` (gitignored), never
  inline in the compose file.

### Dev override (`docker-compose.dev.yml`)

Minimal — only what changes for local development:

```yaml
services:
  backend:
    volumes:
      - ./backend:/app/backend
    command: ["uvicorn", "backend.app:app", "--reload", "--host", "0.0.0.0", "--port", "8001"]
```

Volume mounts overlay the baked-in code with your local files. The
command override adds `--reload` so uvicorn watches for changes.

### Prod override (`docker-compose.prod.yml`)

Replaces `build:` with pre-built images from a container registry:

```yaml
services:
  backend:
    image: ghcr.io/youruser/myapp-backend:${IMAGE_TAG:?Set IMAGE_TAG (e.g. v1.3.0)}
    restart: unless-stopped
```

- **`IMAGE_TAG:?`** — fails immediately with a clear error if you
  forget to set it. No accidental deploys of `latest`.
- **`restart: unless-stopped`** — not in the base file because dev
  containers shouldn't auto-restart (you want to see crashes).

Deploy command:

```bash
IMAGE_TAG=v1.3.0 docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

---

## 2. Security Hardening

Every container gets the same baseline in the compose file:

```yaml
read_only: true
security_opt: [no-new-privileges:true]
cap_drop: [ALL]
mem_limit: 512m
```

| Setting | What it does | Why |
|---------|-------------|-----|
| `read_only: true` | Mounts the container filesystem as read-only | A compromised process can't write malware, modify configs, or create persistence |
| `no-new-privileges` | Blocks `setuid`/`setgid` binaries from escalating | Even if a setuid binary exists in the image, it can't gain elevated privileges |
| `cap_drop: [ALL]` | Removes all Linux capabilities | Containers don't need `NET_RAW`, `SYS_ADMIN`, etc. Start with nothing, add back only what's proven necessary |
| `mem_limit` | Caps memory usage | Prevents a memory leak from taking down the entire VPS |

### When you need to add caps back

Third-party images (Postgres, Caddy) often need specific capabilities
for initialization. The rule: drop all, then add back the minimum.

```yaml
# Postgres needs these to chown its data directory on first start
cap_drop: [ALL]
cap_add: [CHOWN, SETUID, SETGID, DAC_OVERRIDE, FOWNER]

# Caddy needs this to bind to ports 80/443
cap_drop: [ALL]
cap_add: [NET_BIND_SERVICE]
```

**Always test cap changes on the actual VPS.** Some images work fine in
local Docker Desktop but fail on Linux because Desktop's VM has
different kernel defaults. When adding caps to a third-party image,
check the image docs and test the startup sequence on the target host.

### `tmpfs` for images that need to write

Some images expect to write to `/tmp`. Since `read_only: true` blocks
this, mount a tmpfs:

```yaml
read_only: true
tmpfs:
  - /tmp
```

This gives the container a writable `/tmp` backed by memory, not disk.
It's ephemeral (cleared on restart) and doesn't weaken the read-only
guarantee for the rest of the filesystem.

---

## 3. Networking

All app containers join a shared Docker network so the reverse proxy
and database can reach them by container name:

```yaml
networks:
  internal:
    external: true
```

**`external: true`** means Compose doesn't create or destroy this
network — it must already exist. Your infrastructure stack creates it
once; app stacks attach to it.

This lets the reverse proxy reach your container by service name
(`backend:8001`), your app reach the database (`postgres:5432`), and
services within the same stack communicate directly
(`http://backend:8001`).

### Environment overrides for container networking

Your `.env` file typically has `localhost` values for bare-metal dev
tools (DBeaver, `make dev`). In containers, service names replace
`localhost`. Use `environment:` in the compose file to override:

```yaml
backend:
  env_file: .env
  environment:
    DB_HOST: postgres              # overrides DB_HOST=localhost from .env

bot:
  env_file: .env
  environment:
    BACKEND_URL: http://backend:8001  # overrides localhost:8001 from .env
```

This way one `.env` file serves both bare-metal and containerized usage
without duplication.

---

## 4. Dev vs Prod Workflow

| Task | Command |
|------|---------|
| Dev (default) | `docker compose -f docker-compose.yml -f docker-compose.dev.yml up` |
| Dev (rebuild) | `docker compose -f docker-compose.yml -f docker-compose.dev.yml up --build` |
| Dev (with postgres) | `docker compose -f docker-compose.yml -f docker-compose.dev.yml --profile dev up` |
| Prod deploy | `IMAGE_TAG=v1.3.0 docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d` |
| Prod migrate | Same `-f` flags with `run --rm migrate` |
| Prod logs | Same `-f` flags with `logs -f backend` |

Prod uses pre-built GHCR images from tagged releases. The VPS never
runs `docker build` — it only pulls images. Always pin to exact version
tags, never `latest`.

---

## 5. Profiles for Optional Services

Compose profiles let you define services that don't start by default:

```yaml
postgres:
  profiles: ["dev"]
  image: pgvector/pgvector:pg16
  # ...

migrate:
  profiles: ["migrate"]
  build:
    context: .
    dockerfile: backend/Dockerfile
  command: ["alembic", "-c", "core/alembic.ini", "upgrade", "head"]
  # ...
```

- **`profiles: ["dev"]`** — Postgres only starts with `--profile dev`.
  In production, the app uses a shared Postgres on the same network.
- **`profiles: ["migrate"]`** — one-shot migration runner, triggered
  manually when needed.

### depends_on with `required: false`

When a profiled service is a dependency, mark it optional:

```yaml
backend:
  depends_on:
    postgres:
      condition: service_healthy
      required: false   # works without the dev postgres
```

Without `required: false`, `docker compose up backend` in prod would
fail because the `postgres` service (profiled as dev-only) isn't running.

---

## 6. Healthchecks

Healthchecks turn "container is running" into "service is ready." This
matters for `depends_on: condition: service_healthy`.

### HTTP services

Use Python's stdlib to avoid installing curl in a slim image:

```yaml
healthcheck:
  test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8001/health')"]
  interval: 10s
  timeout: 3s
  retries: 3
  start_period: 5s
```

`start_period` gives the app time to boot before health failures count
toward `retries`. Without it, a slow startup marks the container as
unhealthy before it finishes booting — blocking any downstream
`depends_on: condition: service_healthy`.

### Postgres

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER:-postgres}"]
  interval: 5s
  timeout: 3s
  retries: 5
```

The double `$$` escapes the variable so Compose doesn't interpolate it —
the shell inside the container resolves it instead.

### One-shot jobs (scraper)

Jobs that run and exit don't need healthchecks. Pair with
`restart: "no"` so Docker doesn't try to restart them:

```yaml
scraper:
  restart: "no"
  # no healthcheck
```

---

## 7. Logging

Every service gets log rotation to prevent disk fill:

```yaml
logging:
  driver: json-file
  options:
    max-size: "50m"
    max-file: "3"
```

This caps each service at 3 x 50 MB = 150 MB of logs. Older logs are
rotated out automatically.

Infra services use `10m` (low output); chatty app services use `50m`.
The VPS daemon default is `10m x 3` (see VPS setup guide) — per-service
config overrides it, so always set it explicitly.

---

## 8. Checklist

Before shipping a new service:

- [ ] `read_only: true` in compose
- [ ] `cap_drop: [ALL]` — caps added back only if proven necessary
- [ ] `security_opt: [no-new-privileges:true]`
- [ ] `mem_limit` set
- [ ] Log rotation configured
- [ ] Ports bound to `127.0.0.1`, not `0.0.0.0`
- [ ] Joins the `internal` network (`external: true`)
- [ ] Healthcheck defined for long-running services
- [ ] No secrets inline in compose — use `env_file`
- [ ] Tested with `read_only` and `cap_drop` on the actual VPS
