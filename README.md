# infra
Server configuration for `victorpatrin.dev`, reverse proxy routing, and static assets for victorpatrin.dev 

## What's in here

- **Caddyfile** — reverse proxy routing + TLS termination for all subdomains
- **docker-compose.yml** — Caddy container
- **homepage/** — static site served on `victorpatrin.dev`

## Deployment
```bash
ssh web-01
cd ~/infra
git pull
docker compose up -d --build
```

## Routing

| Domain | Target |
|--------|--------|
| `victorpatrin.dev` | Static homepage |
| `s.victorpatrin.dev` | url-shortener |