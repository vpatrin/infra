# Setting Up a Hetzner VPS for Production — Solo Dev Edition

A single VPS running Docker behind Caddy, with defense-in-depth security.
Everything here is generic — no project-specific config. Just a Debian server,
locked down and ready for containers.

This guide assumes a fresh Hetzner Cloud server. Adjust provider-specific
steps (console, firewall UI) for other providers.

---

**What we'll cover:**

1. [Hetzner Cloud Console](#1-hetzner-cloud-console) — server, firewall, networking
2. [DNS setup (Porkbun)](#2-dns-setup-porkbun) — domain + wildcard routing
3. [First connection as root](#3-first-connection-as-root) — system setup + user creation
4. [SSH hardening](#4-ssh-hardening) — key-only auth, root disabled
5. [Fail2ban](#5-fail2ban) — SSH brute-force protection
6. [Firewall (ufw)](#6-firewall-ufw) — OS-level port control
7. [Unattended upgrades](#7-unattended-upgrades) — automatic security patches
8. [Docker](#8-docker) — official repo install
9. [Git](#9-git) — required for deploy workflow
10. [Local SSH config](#10-local-ssh-config) — convenient access from your machine
11. [Swap](#11-swap) — safety net for memory pressure
12. [Timezone](#12-timezone) — UTC for consistent log and timer behavior
13. [Docker log rotation](#13-docker-log-rotation) — prevent disk fill from container logs

---

## 1. Hetzner Cloud Console

### Create the server

- **Type**: CX22 (2 vCPU, 4 GB RAM, 40 GB SSD)
- **Location**: Falkenstein (FSN1) — Hetzner's oldest datacenter, most stable
- **Image**: Debian 13 (Trixie) — stable release since August 2025, standard for production
- **SSH Key**: add your public key (`id_ed25519.pub`) for passwordless access
- **Name**: `web-01` — professional convention, scalable (`web-02` if needed later)

### Create the firewall

Name: `allow-ssh-http-https` — named by function, not by project (reusable).

Inbound rules:

| Protocol | Port | Source | Purpose |
|----------|------|--------|---------|
| TCP | 22 | Any | SSH — server administration |
| TCP | 80 | Any | HTTP — web traffic |
| TCP | 443 | Any | HTTPS — encrypted web traffic |

Outbound: all open (the server needs to download packages, pull Docker images, etc.).

Apply directly to server `web-01`.

> This firewall operates at the Hetzner network level: traffic is blocked before it reaches the machine. We'll also add `ufw` on the server for defense in depth (two independent layers).

### Result

- Server IP: `<VPS_IP>`
- IPv6: `<VPS_IPV6>`

---

## 2. DNS Setup (Porkbun)

### Buy the domain

- Domain: `yourdomain.dev`

### Configure DNS

Delete the default records (ALIAS + CNAME pointing to Porkbun's parking page), then add:

| Type | Host | Value | Purpose |
|------|------|-------|---------|
| A | `@` | `<VPS_IP>` | Root domain → `yourdomain.dev` |
| A | `*` | `<VPS_IP>` | Wildcard → all subdomains (`api.`, `status.`, etc.) |

> The wildcard `*` covers all subdomains. No need to create a record per project — Caddy (reverse proxy on the server) routes each subdomain to the right Docker container.
>
> `@` and `*` are separate: `*` does NOT cover the root domain. You need both.

---

## 3. First Connection as Root

First connection with root (the only user that exists at this point):

```bash
ssh root@<VPS_IP>
```

### Update the system

```bash
apt update && apt upgrade -y
```

Debian minimal doesn't include `sudo` or `curl` by default (unlike Ubuntu):

```bash
apt install -y sudo curl
```

### Set the hostname

```bash
hostnamectl set-hostname web-01
echo "127.0.1.1 web-01" >> /etc/hosts
```

`hostnamectl` changes the machine name (shown in the prompt). The `/etc/hosts` line lets `sudo` resolve the hostname locally — without it, every `sudo` command prints a "unable to resolve host" warning.

### Create your user

```bash
adduser <your-user>
usermod -aG sudo <your-user>
```

`adduser` creates the user with a home directory and asks for a password. This password is only used for `sudo` (not SSH). Store it in a password manager.

`usermod -aG sudo` adds the user to the sudo group → admin command access.

### Copy the SSH key

```bash
mkdir -p /home/<your-user>/.ssh
cp ~/.ssh/authorized_keys /home/<your-user>/.ssh/
chown -R <your-user>:<your-user> /home/<your-user>/.ssh
chmod 700 /home/<your-user>/.ssh
chmod 600 /home/<your-user>/.ssh/authorized_keys
```

Copy root's authorized public key to your user so you can SSH in with the same key. The permissions (700/600) are mandatory — SSH refuses to work if `.ssh` is too permissive.

### Test the connection BEFORE locking root

Open a **second terminal** without closing the root session:

```bash
ssh <your-user>@<VPS_IP>
sudo whoami  # must print "root"
```

Never lock root before confirming the new user works. Otherwise you lock yourself out.

---

## 4. SSH Hardening

Edit the SSH config:

```bash
sudo nano /etc/ssh/sshd_config
```

Change these 3 lines:

```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
```

Restart SSH:

```bash
sudo systemctl restart sshd
```

### What each line does

**`PermitRootLogin no`** (default: `prohibit-password`)

Root can no longer SSH in at all, even with a key. An attacker must now guess the username AND possess the private key. Root remains accessible locally via `sudo`.

**`PasswordAuthentication no`** (default: `yes`)

Disables password authentication over SSH. Only a private key allows connection. Eliminates 100% of brute-force password attacks — this is the highest-impact change.

**`PubkeyAuthentication yes`** (default: `yes`, but commented out)

Explicitly forces public key authentication. No real change, but if a system update changed the default, the config stays protected.

> After restarting sshd, existing sessions stay open. Always test in a new terminal before closing the current session.

### Why the user password is still useful

The password doesn't serve for SSH (blocked), but for:

1. **`sudo`** — every admin command requires the password. If someone steals the SSH key, they get a user shell but can't do anything as root without the password (defense in depth).
2. **Hetzner console** — if you lock yourself out of SSH (bad config, lost key), you can access the server via the Hetzner web console with login/password.

---

## 5. Fail2ban

Fail2ban monitors log files and bans IPs that show malicious patterns (repeated failed SSH logins, HTTP auth failures, etc.). It works by adding temporary firewall rules.

```bash
sudo apt install -y fail2ban
```

Fail2ban works out of the box for SSH — the default config (`/etc/fail2ban/jail.conf`) enables the `sshd` jail, which bans IPs after 5 failed login attempts for 10 minutes.

To customize without touching the default config (which gets overwritten on package updates), create a local override:

```bash
sudo tee /etc/fail2ban/jail.local <<'EOF'
[sshd]
enabled = true
maxretry = 3
bantime = 1h
findtime = 10m
EOF

sudo systemctl enable --now fail2ban
```

These are recommended settings — stricter than the defaults (5 retries, 10min ban):

| Setting | Default | Recommended | Meaning |
|---------|---------|-------------|---------|
| `maxretry` | 5 | 3 | Ban after N failed attempts |
| `bantime` | 10m | 1h | Ban duration |
| `findtime` | 10m | 10m | Window in which retries are counted |

### Verify

```bash
sudo fail2ban-client status          # list active jails
sudo fail2ban-client status sshd     # banned IPs + stats
sudo fail2ban-client set sshd unbanip <IP>  # manual unban
sudo journalctl -u fail2ban --since "1 week ago"
```

> With `PasswordAuthentication no`, brute-force SSH attacks always fail at the key exchange stage. Fail2ban still helps by banning scanners early, reducing log noise and wasted CPU on handshakes.

---

## 6. Firewall (ufw)

```bash
sudo apt install -y ufw
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### What ufw does

The server has 65535 ports. Without an OS firewall, they're all potentially reachable. `ufw` closes everything by default (`policy DROP`), then opens only what's needed:

- **Port 22** (OpenSSH) → SSH access
- **Port 80** (HTTP) → web traffic to Caddy
- **Port 443** (HTTPS) → encrypted web traffic to Caddy

Everything else is blocked. If you later start PostgreSQL (port 5432), it listens on the machine but isn't accessible from the outside.

### Why ufw + Hetzner firewall

- **Hetzner firewall** = blocks at the network level, before traffic reaches the machine
- **ufw** = blocks at the OS level, on the machine

If either one has a bug or misconfiguration, the other protects you. This is the defense-in-depth principle.

### Useful commands

```bash
sudo ufw status          # active rules (simple view)
sudo ufw status verbose  # detailed view with default policies
sudo ss -tlnp            # services listening (independent of firewall)
```

> `ss -tlnp` shows services that are listening, `ufw status` shows what's reachable from outside. A service can listen without being accessible (blocked by ufw).

---

## 7. Unattended Upgrades

Automatic security patches. Without this, the VPS only gets patched when you manually run `apt upgrade` — leaving a window where known CVEs sit unpatched.

```bash
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades  # answer Yes
```

This creates `/etc/apt/apt.conf.d/20auto-upgrades` with:

```
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
```

The default Debian config (`50unattended-upgrades`) only applies security updates — not general package upgrades. This is the correct behavior for a production server: you get CVE fixes automatically, but nothing breaks from unexpected version bumps.

### Verify it works

```bash
cat /etc/apt/apt.conf.d/20auto-upgrades           # should show "1" for both
sudo unattended-upgrades --dry-run --debug 2>&1 | head -20  # what would be upgraded
journalctl -u unattended-upgrades --since "1 week ago"      # recent activity
```

### What it does NOT cover

- **Docker images** — container base images are not managed by apt. Use Dependabot or Trivy for container CVEs.
- **Major version upgrades** — only patches within the current Debian release. OS upgrades (Debian 13 → 14) are always manual.

---

## 8. Docker

Install via the official Docker repository (recommended for production — not the `get.docker.com` convenience script):

```bash
# Dependencies + GPG key
sudo apt install -y ca-certificates gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repo to apt sources
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Allow your user to run docker without sudo
sudo usermod -aG docker <your-user>
```

After `usermod`, disconnect and reconnect for the group to take effect:

```bash
exit
ssh web-01
docker run hello-world   # must work without sudo
```

---

## 9. Git

Required for the deploy workflow (`git pull` on the VPS). Debian minimal may not include it:

```bash
sudo apt install -y git
```

Configure identity (used in commit metadata if you ever commit on the server — rare, but clean):

```bash
git config --global user.name "<your-name>"
git config --global user.email "<your-email>"
```

---

## 10. Local SSH Config

Create or edit `~/.ssh/config` on your machine:

```
Host web-01
    HostName <VPS_IP>
    User <your-user>
    IdentityFile ~/.ssh/id_ed25519
```

Connect with `ssh web-01` instead of `ssh <your-user>@<VPS_IP>`.

> During initial setup you may have `User root` — update to your user after SSH hardening.

---

## 11. Swap

Swap is a file on disk that acts as emergency RAM. Disk is 50-100x slower than RAM, so swap is a safety net, not a permanent solution. If you're constantly swapping, you have a real memory problem to solve.

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf
sudo sysctl -p /etc/sysctl.d/99-swappiness.conf
```

| Command | Purpose |
|---------|---------|
| `fallocate -l 2G` | Reserve 2 GB of disk space without writing every byte |
| `chmod 600` | Only root can read/write the swap file |
| `mkswap` | Format the file as swap |
| `swapon` | Activate swap immediately |
| `/etc/fstab` entry | Make swap persistent across reboots |
| `swappiness=10` | Only use swap when truly out of other options |

Verify:

```bash
free -h
```

---

## 12. Timezone

Servers should run UTC. It avoids daylight saving confusion, makes log correlation straightforward, and is the standard for production systems.

Debian on Hetzner defaults to UTC, but verify:

```bash
timedatectl
```

If not UTC:

```bash
sudo timedatectl set-timezone UTC
```

All systemd timers on this VPS use UTC schedules (e.g., `OnCalendar=Mon 02:00` = 02:00 UTC). Keep this in mind when reading logs or scheduling jobs — 02:00 UTC is 03:00 CET (winter) or 04:00 CEST (summer).

---

## 13. Docker Log Rotation

By default, Docker stores container logs as JSON with no size limit. On a small VPS, one chatty container can fill the disk.

Configure daemon-level defaults in `/etc/docker/daemon.json`:

```bash
sudo tee /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

sudo systemctl restart docker
```

> **Warning:** `systemctl restart docker` stops all running containers briefly. On a live server, run this during a maintenance window or accept a few seconds of downtime.

This caps every container at 10 MB × 3 files = 30 MB of logs. New containers pick up the default automatically.

> Per-service overrides can be set in `docker-compose.yml` via the `logging:` key. The daemon default acts as a safety net for any container that doesn't specify its own policy.
