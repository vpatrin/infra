# ADR 0005: Systemd Timers for Scheduled Jobs

**Date:** 2026-03-17
**Status:** Accepted

---

## Context

The platform has recurring jobs: weekly database backups (`pg_dump`), daily stock availability refresh, and weekly product scraping. These jobs need reliable scheduling, failure visibility, and clean separation from long-running services.

## Decision Drivers

- Jobs are one-shot processes, not long-running services — they start, do work, and exit
- Failure must be visible (`journalctl`) and alertable (Uptime Kuma push monitors, planned)
- Scheduling must survive VPS reboots — missed jobs should run on next boot
- Docker Compose manages service lifecycles, not cron-like scheduling
- Single VPS, single developer — the scheduling tool must be already present and battle-tested

## Options Considered

### Container-level cron (cron inside Docker)

Run `cron` as PID 1 inside a container, with crontab entries calling scripts. But cron in containers is fragile: no native log integration (stdout isn't captured by `docker logs`), PID 1 signal handling is wrong (cron doesn't forward SIGTERM), and failure exits are invisible — the container stays "healthy" even when jobs fail. Adding `supercrond` or `go-crond` fixes some issues but adds a dependency for a solved problem.

### Docker Compose `restart: always` with sleep loops

A container that runs a job, sleeps until next scheduled time, then repeats. Keeps everything in Compose. But the sleep loop loses schedule precision over time, `docker compose ps` shows it as perpetually "running" (hiding whether the job succeeded), and a Compose restart resets the sleep timer. This is a hack pretending to be a scheduler.

### Systemd timers

Native to the OS. `.timer` units define the schedule, `.service` units define the job. `Persistent=true` ensures missed runs execute on boot. `journalctl -u <service>` shows full output. `systemctl list-timers` gives a dashboard. Failed runs set the unit to `failed` state — visible in `systemctl status` and alertable via Uptime Kuma push monitors.

## Decision

**Use systemd timers for all scheduled jobs. Docker Compose manages long-running services only.**

Each job gets a pair of units:

```ini
# pg-backup.timer
[Unit]
Description=Weekly PostgreSQL backup

[Timer]
OnCalendar=Mon 02:00
Persistent=true

[Install]
WantedBy=timers.target
```

```ini
# pg-backup.service
[Unit]
Description=PostgreSQL backup

[Service]
Type=oneshot
User=victor
WorkingDirectory=/home/victor/infra
ExecStart=/home/victor/infra/services/postgres/backups/backup.sh
```

Timer units live in `/etc/systemd/system/` and are enabled with `systemctl enable --now <timer>`.

The boundary is clear: Compose owns processes that must always be running (Caddy, Postgres, app backends). Systemd owns processes that run on a schedule and exit (backups, scrapers, availability refreshes).

## Consequences

- `systemctl list-timers` shows all scheduled jobs, next run times, and last trigger — a single-command dashboard.
- `journalctl -u pg-backup.service --since "1 week ago"` shows full output from the last run. No log driver configuration needed.
- `Persistent=true` means a VPS reboot at 02:00 doesn't skip the backup — it runs on boot.
- Failed jobs set the systemd unit to `failed` state. Uptime Kuma push monitors (planned) can alert on this.
- Timer scheduling lives outside the repo (in `/etc/systemd/system/`). Timer unit files are committed to the repo for reference but must be manually copied to the VPS. This gap closes when Ansible manages server configuration.
- App repos own their job scripts but depend on infra to manage the timer units. Changing a schedule requires SSH access, not a code change.
