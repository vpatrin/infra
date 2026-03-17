# Dockerfile Patterns for Production

How to build production Docker images for Python apps on a single VPS.
Multi-stage builds with Poetry, security hardening, and build context
hygiene. The patterns are generic — adapt to your stack.

For compose-level patterns (3-file setup, networking, profiles,
healthchecks), see [COMPOSE_GUIDE.md](COMPOSE_GUIDE.md).

---

**What we'll cover:**

1. [Multi-stage build](#1-multi-stage-build) — builder + runtime with Poetry
2. [Security hardening](#2-security-hardening) — non-root, stripped pip, env flags
3. [.dockerignore](#3-dockerignore) — keeping the build context clean
4. [Checklist](#4-checklist) — before you ship

---

## 1. Multi-Stage Build

Builder stage installs dependencies, runtime stage copies only what's
needed.

```dockerfile
# --- Stage 1: Builder ---
FROM python:3.12-slim@sha256:<pinned-digest> AS builder

ARG POETRY_VERSION=2.3.2
RUN pip install --no-cache-dir poetry==${POETRY_VERSION}
WORKDIR /build

# Copy shared package (path dependency)
COPY core/ core/

# Copy service dependency files
COPY backend/pyproject.toml backend/poetry.lock backend/
WORKDIR /build/backend
ENV VIRTUAL_ENV=/opt/venv
RUN python -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
# Install deps into the venv, then re-install core as a proper package
RUN poetry install --only main --no-interaction \
    && pip install --no-cache-dir --no-deps --force-reinstall /build/core

# --- Stage 2: Runtime ---
FROM python:3.12-slim@sha256:<pinned-digest>

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/opt/venv/bin:$PATH"

WORKDIR /app

# Copy only the venv — no pip/setuptools/poetry in the final image
COPY --from=builder /opt/venv /opt/venv
# Strip pip from the runtime image (not needed, avoids Trivy CVEs)
RUN pip uninstall pip -y && rm -rf /usr/local/lib/python*/site-packages/pip*

# Copy application code
COPY backend/ backend/

# Non-root user
RUN useradd --no-create-home --uid 1000 appuser
USER appuser

EXPOSE 8001
CMD ["uvicorn", "backend.app:app", "--host", "0.0.0.0", "--port", "8001"]
```

### Why each decision matters

| Decision | Why |
|----------|-----|
| Pinned digest (`@sha256:...`) | Tags are mutable; digest guarantees reproducible builds |
| Poetry in builder only | No build tools in runtime image — smaller surface, fewer CVEs |
| Strip pip (`pip uninstall pip -y`) | Eliminates pip CVEs from Trivy scans since runtime never installs packages |
| `--only main` | Excludes dev dependencies (pytest, ruff) from prod image |
| Non-root user (`USER appuser`) | Combined with `read_only`, prevents filesystem writes and privilege escalation |
| `PYTHONUNBUFFERED=1` | Ensures logs appear immediately in `docker compose logs` |
| `PYTHONDONTWRITEBYTECODE=1` | Avoids noisy write-attempt errors under `read_only` |

**Path dependency re-install** deserves a callout: Poetry installs local
path dependencies (like `core/`) as editable symlinks pointing to
`/build/core/` — which doesn't exist in the runtime stage. The
`pip install --force-reinstall` re-installs core as a proper package so
imports survive the multi-stage copy.

---

## 2. Security Hardening

The Dockerfile side of container security. Compose-level hardening
(`read_only`, `cap_drop`, `mem_limit`) is covered in
[COMPOSE_GUIDE.md](COMPOSE_GUIDE.md#2-security-hardening).

### Non-root user

```dockerfile
RUN useradd --no-create-home --uid 1000 appuser
USER appuser
```

The process runs as `appuser` (UID 1000), not root. Combined with
`read_only: true` in compose, a compromised process can't write to the
filesystem or escalate privileges.

### Strip build tools from runtime

```dockerfile
COPY --from=builder /opt/venv /opt/venv
RUN pip uninstall pip -y && rm -rf /usr/local/lib/python*/site-packages/pip*
```

The runtime image has no pip, no poetry, no setuptools. This eliminates
an entire class of CVEs that Trivy would otherwise flag, and prevents
a compromised container from installing additional packages.

### Environment variables

```dockerfile
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1
```

- **`PYTHONUNBUFFERED=1`** — logs appear immediately in `docker compose logs`
  instead of being buffered.
- **`PYTHONDONTWRITEBYTECODE=1`** — prevents Python from writing `.pyc`
  files, which would fail under `read_only: true` and clutter logs with
  permission errors.

---

## 3. .dockerignore

The `.dockerignore` controls what goes into the build context (what
Docker sends to the daemon before the build starts). A bloated context
slows every build.

```dockerignore
# Python bytecode + caches
__pycache__/
*.py[cod]
*.egg-info/
.venv/
.pytest_cache/
.coverage
.ruff_cache/

# Git
.git/
.gitignore
.githooks/

# CI/CD
.github/

# Dev tools
scripts/
.vscode/
.idea/

# Secrets
.env
.env.local

# Docker meta (don't send into itself)
docker-compose.yml
.dockerignore

# Docs (not needed in containers)
*.md
LICENSE
```

Notable: `.git/` (large, cache-busts every build) and `.env` (secrets
shouldn't reach the daemon even if never COPYed).

---

## 4. Checklist

Before shipping a new Dockerfile:

- [ ] Multi-stage build (builder + runtime)
- [ ] Base image pinned by digest, not just tag
- [ ] No pip/poetry/setuptools in the final image
- [ ] Runs as non-root user (`USER appuser`)
- [ ] `PYTHONUNBUFFERED=1` and `PYTHONDONTWRITEBYTECODE=1` set
- [ ] `.dockerignore` excludes `.git/`, `.env`, dev tools, docs
- [ ] No secrets in the image or build context
