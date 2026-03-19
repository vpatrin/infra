<!-- Based on https://github.com/joelparkerhenderson/architecture-decision-record (MADR) -->

# ADR 0008: Observability Stack

**Date:** 2026-03-19
**Status:** Accepted

---

## Context

The platform has grown from static pages and third-party services to a RAG-powered wine recommender with weekly scraping, embedding pipelines, and LLM calls. The questions we need to answer have changed:

- Is retrieval quality degrading? Are similarity scores drifting?
- How much are LLM calls costing per day? Per recommendation?
- Which queries return zero candidates? What do users actually ask?
- Did last Monday's scraper run change embedding quality?
- Are systemd timers (backups, scraper, availability) running successfully?

`docker logs` and `journalctl` cannot answer these. They require structured logs, metrics, time-series storage, and dashboards.

The previous roadmap (Phase 8) deferred observability until K3s migration, citing memory constraints on the 4GB VPS. That rationale no longer holds — the VPS can be upgraded to 8GB, and the operational need is immediate.

## Decision Drivers

- **Learning journey** — build observability on Compose first, understand the stack deeply, then migrate to K3s alongside everything else
- **K3s migration path** — tools chosen must have a clear Kubernetes story (Helm charts, DaemonSets, standard CRDs)
- **Single-binary preference** — fewer containers, less memory, simpler debugging on a single VPS
- **Config-as-code** — dashboards, datasources, and alerting rules must survive container rebuilds and be portable across Compose and K3s
- **Solo developer** — complexity must stay proportional to scale

## Options Considered

### Option A: Grafana stack (Grafana + Loki + Prometheus + Alloy)

The Grafana LGTM stack. Alloy is Grafana's unified telemetry collector — replaces Promtail, Grafana Agent, and node_exporter with a single binary.

**Pros:**
- Grafana is the most widely deployed dashboard tool — directly transferable skills
- Prometheus is the Kubernetes metrics standard — `kube-prometheus-stack` Helm chart is the default for K8s observability
- Loki is purpose-built for log aggregation without full-text indexing — lightweight, pairs naturally with Grafana
- Alloy unifies log collection, metric scraping, and node metrics in one container — fewer moving parts
- All components have mature Helm charts and K3s integration
- Config-as-code: Grafana provisioning, Prometheus scrape configs, Alloy pipeline config — all declarative files
- Alloy can collect systemd unit status for timer observability

**Cons:**
- Loki is log-grep, not full-text search — no field-level indexing like Elasticsearch
- Four containers (Grafana, Loki, Prometheus, Alloy) — more than a SaaS solution
- LogQL and PromQL are two query languages to learn

### Option B: ELK/EFK (Elasticsearch + Logstash/Fluentd + Kibana)

The enterprise log analytics stack.

**Pros:**
- Powerful full-text search and field-level indexing
- Kibana has rich visualization and alerting
- Mature ecosystem, widely documented

**Cons:**
- Elasticsearch alone wants 2–4GB heap — prohibitive on a 4–8GB VPS with pgvector already running
- JVM-based — high baseline memory, slow startup, complex tuning
- Overkill for operational observability on a single-service platform
- No native Prometheus metrics — would need a separate metrics pipeline
- Weaker K3s story compared to Grafana stack

### Option C: Datadog / Grafana Cloud (SaaS)

Hosted observability — zero infrastructure to manage.

**Pros:**
- No containers to run or maintain
- Polished UX, built-in alerting, APM, tracing
- Free tiers available (limited)

**Cons:**
- Defeats the learning objective — the goal is to understand the stack, not outsource it
- Vendor lock-in, cost scales with data volume
- No portable skills for K3s self-hosted migration
- Free tiers have aggressive retention and cardinality limits

### Option D: VictoriaMetrics + Grafana

Drop-in Prometheus replacement with better compression and lower memory.

**Pros:**
- Lower memory footprint than Prometheus for metrics storage
- Compatible with PromQL — Grafana dashboards work unchanged
- Single-binary option

**Cons:**
- Smaller community and ecosystem than Prometheus
- Weaker K3s integration — no equivalent of `kube-prometheus-stack`
- Still needs Loki (or equivalent) for logs — doesn't simplify the stack
- Less industry recognition — Prometheus is the resume keyword

## Decision

**Grafana stack: Grafana + Loki + Prometheus + Alloy.**

This is the industry-standard open-source observability stack for platforms targeting Kubernetes. Choosing it on Compose first means:

1. Learning the tools with fast feedback loops (docker compose up, break things, iterate)
2. Building dashboards and configs that are directly portable to K3s
3. Developing PromQL and LogQL fluency that transfers to any Kubernetes role

### Architecture

```
Alloy ──push──→ Loki    ──query──→ Grafana
  │                                   ↑
  └──expose──→ Prometheus ──query─────┘
```

- **Alloy** — tails container logs via Docker socket (pushes to Loki), exposes node-level metrics and systemd unit status (scraped by Prometheus)
- **Loki** — log aggregation, single-binary mode, filesystem storage, 7-day retention
- **Prometheus** — metrics scraping (15s interval), local TSDB, 7-day retention
- **Grafana** — dashboards and explore UI, provisioned via config-as-code (YAML + JSON)

### Network access

Initially, observability services use temporary localhost port bindings (e.g., `127.0.0.1:3002:3000` for Grafana). Phase 9 (WireGuard VPN) removes these and moves access behind a WireGuard tunnel — no public Caddy routes, no host port bindings.

### Phasing

- **Phase 8a** — deploy the stack on Compose, platform overview dashboard, temporary localhost access
- **Phase 8b** — application dashboards (blocked on coupette emitting structured logs and Prometheus metrics)
- **Phase 9** — WireGuard VPN, remove localhost bindings, tunnel-only access
- **K3s migration** — same tools, same dashboards, different deployment substrate (Helm charts, DaemonSets, PVCs)

## Consequences

**Easier:**
- Platform health visible at a glance — no more SSH + grep
- Structured log queries across all containers (LogQL)
- Time-series metrics with historical comparison (PromQL)
- Dashboard JSONs portable from Compose to K3s — build once, migrate unchanged
- Systemd timer health visible in Grafana alongside container metrics

**Harder:**
- Four new containers to maintain and upgrade
- Two query languages to learn (LogQL, PromQL)
- Dashboard JSON is brittle — build in UI, export, clean up, commit
- Alloy requires Docker socket access (read-only) — grants container metadata visibility

**Deferred:**
- Alerting rules — get dashboards right first, add alerts as a follow-up
- Application metrics — blocked on coupette contract (structured logs + `/metrics` endpoint)
- Tracing (Tempo) — not needed until request flows span multiple services
