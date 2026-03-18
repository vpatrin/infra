# Observability Journey

Strategy for adding observability to the platform — Compose first, then K3s.

---

## Why Now

The platform has grown from static pages to a RAG-powered wine recommender. `docker logs` and `journalctl` answered yesterday's questions. Today's questions are different:

- Is retrieval quality degrading? Are similarity scores drifting?
- How much are LLM calls costing per day? Per recommendation?
- Which queries return zero candidates? What do users actually ask?
- Did last Monday's scraper run change embedding quality?

These need structured logs, metrics, and dashboards — not SSH + grep.

## Memory Budget

The VPS has 4GB RAM + 2GB swap. Current allocation:

| Service | Limit | Actual |
|---------|-------|--------|
| Caddy | 256 MB | ~30 MB |
| PostgreSQL + pgvector | 1 GB | ~200 MB |
| Umami | 256 MB | ~150 MB |
| Uptime Kuma | 256 MB | ~80 MB |
| Coupette (backend + bot) | — | ~300 MB |
| **Total** | | **~760 MB** |

That leaves ~3.2 GB available. The observability stack must fit in **~800 MB** with room to breathe.

| Component | Role | Budget |
|-----------|------|--------|
| Grafana | Dashboards + alerting | 256 MB |
| Loki | Log aggregation (recent logs, not long-term) | 256 MB |
| Alloy | Log + metric collection (replaces Promtail + node_exporter) | 128 MB |
| Prometheus | Metrics scraping + storage | 192 MB |
| **Total** | | **832 MB** |

Tight but workable. Loki runs in single-binary mode with aggressive retention (7 days). Prometheus uses 15s scrape interval, 7-day TSDB retention. No long-term storage — this is operational observability, not analytics.

---

## Phase A — Compose (learn the stack)

Build everything in `docker-compose.yml` on the existing VPS. Goal: working dashboards, validated config, understood failure modes.

### Components

```
Alloy ──→ Loki    ──→ Grafana
  │                      ↑
  └──→ Prometheus ───────┘
```

**Alloy** (Grafana's unified collector) replaces the need for separate Promtail + node_exporter. Single binary that:
- Tails container logs via Docker socket → pushes to Loki
- Scrapes Prometheus metrics from coupette's `/metrics` endpoint
- Exposes node-level metrics (CPU, memory, disk)

**Loki** stores logs in single-binary mode. Filesystem storage, 7-day retention. No S3, no chunks — simple.

**Prometheus** scrapes application metrics. 15s interval, 7-day TSDB retention. Targets: coupette `/metrics`, Alloy self-metrics, Caddy metrics (if enabled).

**Grafana** renders dashboards. Provisioned via YAML — datasources and dashboards are config-as-code, not click-ops.

### Dashboards

**1. Platform Overview** — the "is everything OK?" screen
- Container up/down status, restart counts
- CPU / memory / disk usage (node-level from Alloy)
- Caddy request rate + error rate (4xx, 5xx)
- Log volume per service

**2. Recommendations & RAG Quality** — the reason we're doing this
- Request rate, latency p50/p95/p99 (total, retrieval, LLM)
- Similarity score distribution (top hit, min hit)
- Candidate count distribution, zero-candidate rate
- Token usage (in/out), estimated daily cost
- Live query log table (recent queries with scores)
- Low-quality flag: queries where `top_similarity < 0.7`

**3. Scraper & Data Pipeline** — weekly health
- Scraper run duration, products scraped/enriched/embedded
- Embedding batch sizes, pgvector insert rate
- Error log panel filtered to scraper events

### Coupette Contract

Coupette must emit structured JSON logs and Prometheus metrics. Infra provides the collection and visualization — coupette provides the signals.

**Structured log fields** (one JSON line per recommendation):
```
event, query, candidate_count, top_similarity, min_similarity,
retrieval_ms, llm_ms, total_ms, tokens_in, tokens_out, model, status, error
```

**Prometheus metrics** (exposed at `/metrics`):
```
coupette_recommendation_duration_seconds    histogram (stage: retrieval|llm|total)
coupette_recommendation_candidates          histogram
coupette_recommendation_similarity_score    histogram (rank: top|min)
coupette_recommendation_tokens_total        counter   (direction: in|out)
coupette_recommendation_errors_total        counter   (stage: retrieval|llm)
```

### Caddy Routing

```
grafana.victorpatrin.dev  → grafana:3002
```

Loki and Prometheus are internal-only — no public exposure.

### File Layout

```
services/
├── grafana/
│   └── provisioning/
│       ├── datasources/
│       │   └── datasources.yaml      # Loki + Prometheus
│       └── dashboards/
│           ├── dashboards.yaml        # Dashboard provider config
│           ├── platform-overview.json
│           └── rag-quality.json
├── prometheus/
│   └── prometheus.yml                 # Scrape config
└── alloy/
    └── config.alloy                   # Log + metric collection
```

### Deliverables

- [ ] Add Grafana, Loki, Prometheus, Alloy to `docker-compose.yml`
- [ ] Alloy config: Docker log collection + Prometheus remote-write
- [ ] Prometheus scrape config: coupette `/metrics`, Alloy self-metrics
- [ ] Grafana provisioning: datasources (Loki + Prometheus)
- [ ] Dashboard JSON: Platform Overview
- [ ] Dashboard JSON: Recommendations & RAG Quality
- [ ] Caddy route for `grafana.victorpatrin.dev`
- [ ] ADR: `decisions/0007-observability-stack.md`
- [ ] Update ROADMAP.md, SERVICE_CATALOG.md, INFRASTRUCTURE.md

---

## Phase B — K3s Migration (production-grade)

Once Phase A is validated and the dashboards are useful, migrate the full stack to K3s. The observability stack migrates alongside everything else — not separately.

### What Changes

| Compose | K3s |
|---------|-----|
| `docker-compose.yml` services | Kubernetes Deployments + Services |
| Docker volumes | PersistentVolumeClaims (local-path) |
| Alloy tails Docker socket | Alloy DaemonSet tails node logs |
| Prometheus local TSDB | Prometheus with PVC, or kube-prometheus-stack Helm chart |
| Grafana provisioning YAMLs | Same YAMLs, mounted via ConfigMap |
| Caddy reverse proxy | K3s Traefik Ingress (built-in) or keep Caddy as Ingress |
| `internal` Docker network | Kubernetes Service DNS (`svc.cluster.local`) |

### What Stays the Same

- Dashboard JSONs — portable between Compose and K3s Grafana
- Prometheus scrape targets — same `/metrics` endpoints, different DNS names
- Alloy config — same pipeline, different input (node logs vs Docker socket)
- Loki single-binary mode — same config, different storage backend (PVC vs bind mount)
- Alert rules — Grafana-managed, stored in provisioning config

### K3s-Specific Additions

- **Flux GitOps** — watches `k8s/` directory, auto-deploys on push
- **kube-state-metrics** — pod/deployment/node status in Prometheus
- **Ingress metrics** — Traefik exposes request metrics natively
- **Resource requests/limits** — same memory budget, enforced by K8s

### File Layout (K3s)

```
k8s/
├── base/
│   ├── grafana/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap-dashboards.yaml  # Reuses Phase A dashboard JSONs
│   │   └── configmap-datasources.yaml
│   ├── loki/
│   ├── prometheus/
│   └── alloy/
└── overlays/
    └── prod/
        └── kustomization.yaml
```

### Migration Checklist

- [ ] K3s installed via Ansible (Phase 8 prerequisite)
- [ ] Translate Compose services → K8s manifests
- [ ] Migrate Grafana provisioning → ConfigMaps
- [ ] Validate dashboards work with K8s service DNS
- [ ] Flux watches `k8s/` path for GitOps deploys
- [ ] Decommission Compose stack

---

## Decision Log

| Decision | Rationale |
|----------|-----------|
| Alloy over Promtail + node_exporter | Single binary, fewer containers, lower memory, Grafana-native |
| Loki over ELK/EFK | 10x less memory, no JVM, LogQL is good enough |
| Prometheus over VictoriaMetrics | Industry standard, better K3s ecosystem (kube-prometheus-stack) |
| 7-day retention | Operational observability, not compliance. Keeps storage under 2 GB |
| Grafana provisioning over click-ops | Config-as-code, survives container rebuilds, portable to K3s |
| Compose first, K3s second | Learn the stack with fast feedback loops before adding K8s complexity |
| Dashboard JSONs are the portable artifact | Same files work in Compose Grafana and K8s Grafana |
