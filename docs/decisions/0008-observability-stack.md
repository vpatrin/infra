# ADR 0008: Observability Stack

**Date:** 2026-03-19
**Status:** Accepted

## Context

The platform has grown from static pages to a RAG-powered wine recommender with weekly scraping, embedding pipelines, and LLM calls. `docker logs` and `journalctl` cannot answer "is retrieval quality degrading?", "what's the daily LLM cost?", or "did the scraper succeed?". We need structured logs, metrics, time-series storage, and dashboards. Goal is to learn the stack on Compose first, then migrate to K3s alongside everything else.

## Options considered

1. **Grafana stack (Grafana + Loki + Prometheus + Alloy)** — industry-standard open-source observability. Alloy unifies log collection, metric scraping, and node metrics in one container. All components have mature Helm charts for K3s migration. Config-as-code: Grafana provisioning, Prometheus scrape configs, Alloy pipeline config.
2. **ELK/EFK (Elasticsearch + Kibana)** — powerful full-text search, but Elasticsearch wants 2-4GB heap — prohibitive on a 4-8GB VPS with pgvector. JVM-based, no native Prometheus metrics, weaker K3s story.
3. **SaaS (Datadog, Grafana Cloud)** — zero infra to manage, but defeats the learning objective. Vendor lock-in, no portable skills for K3s self-hosted migration.
4. **VictoriaMetrics + Grafana** — lower memory than Prometheus, but smaller community, weaker K3s integration (`kube-prometheus-stack` is the standard), still needs Loki for logs.

## Decision

Grafana stack: Grafana + Loki + Prometheus + Alloy. Alloy tails container logs via Docker socket (pushes to Loki) and exposes node metrics (scraped by Prometheus). Loki and Prometheus retain 7 days on local filesystem. Grafana dashboards provisioned as code (JSON + YAML). Temporary localhost port bindings until WireGuard (Phase 9).

## Rationale

- Grafana + Prometheus is the Kubernetes metrics standard — directly transferable skills and portable dashboards
- Alloy replaces 3 separate tools (Promtail, Grafana Agent, node_exporter) with one container
- Config-as-code means dashboards survive container rebuilds and are portable from Compose to K3s
- Learning the stack on Compose first gives fast feedback loops before K3s migration

## Consequences

- Four new containers to maintain and upgrade. Two query languages to learn (LogQL, PromQL).
- Alloy requires Docker socket access (read-only) — mitigated by `cap_drop: ALL`, `read_only: true`, `no-new-privileges`.
- Dashboard JSON is brittle — build in UI, export, clean up, commit.
- Alerting rules and application dashboards deferred until coupette emits structured metrics.
