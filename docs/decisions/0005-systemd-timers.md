# ADR 0005: Systemd Timers for Scheduled Jobs

**Date:** 2026-03-17
**Status:** Accepted

## Context

The platform has recurring jobs: weekly database backups, daily stock availability refresh, weekly product scraping. These are one-shot processes that start, do work, and exit — not long-running services. Scheduling must survive VPS reboots, and failure must be visible and alertable.

## Options considered

1. **Container-level cron** — `cron` as PID 1 inside a container. But no native log integration (`stdout` not captured by `docker logs`), PID 1 signal handling is wrong, failure exits are invisible — container stays "healthy" when jobs fail.
2. **Docker Compose sleep loops** — container runs job, sleeps until next scheduled time. But sleep loop loses precision over time, `docker compose ps` shows perpetually "running", restart resets the timer. A hack pretending to be a scheduler.
3. **Systemd timers** — native to the OS. `.timer` units define schedule, `.service` units define the job. `Persistent=true` runs missed jobs on boot. `journalctl` shows full output. Failed runs set unit to `failed` state — visible and alertable via Uptime Kuma push monitors.

## Decision

Use systemd timers for all scheduled jobs. Docker Compose manages long-running services only. Each job gets a `.timer` + `.service` pair. Timer units live in `systemd/` in the repo and are synced to `/etc/systemd/system/` by the deploy script.

## Rationale

- `systemctl list-timers` shows all jobs, next run times, last trigger — single-command dashboard
- `journalctl -u pg-backup.service` shows full output, no log driver config needed
- `Persistent=true` means a VPS reboot doesn't skip the backup — it runs on boot
- Clear boundary: Compose owns always-running processes, systemd owns scheduled ones

## Consequences

- Timer unit files are committed to the repo but must be synced to the VPS. Deploy script handles this; Ansible will formalize it later.
- App repos own their job scripts but depend on infra to manage the timer units. Changing a schedule requires updating the unit file and redeploying.
