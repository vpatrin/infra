.PHONY: help up down dev-homepage logs status validate-caddy reload-caddy deploy tunnel create-secret edit-secret

COMPOSE := docker compose -f docker-compose.yml -f docker-compose.dev.yml

help: ## Show this help
	@echo "Platform Infrastructure - Available Commands"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

up: ## Start local dev stack (excludes postgres + umami, see #70)
	$(COMPOSE) up -d caddy uptime-kuma umami alloy grafana shared-postgres

down: ## Stop local dev stack
	$(COMPOSE) down

dev-homepage: ## Serve homepage locally (http://localhost:8080)
	cd services/homepage && python3 -m http.server 8080

logs: ## Show logs (follow)
	$(COMPOSE) logs -f

status: ## Show running containers
	$(COMPOSE) ps

validate-caddy: ## Validate Caddyfile syntax
	docker exec caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

reload-caddy: ## Reload Caddy configuration
	docker exec caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile

tunnel: ## SSH tunnel to Grafana (:3002)
	@echo "Grafana: http://localhost:3002"
	ssh -N -L 3002:127.0.0.1:3002 web-01

deploy: ## Trigger production deploy via GitHub Actions
	@echo "⚠️  This will deploy to production (web-01)."
	@read -p "Type 'approve' to continue: " confirm && [ "$$confirm" = "approve" ] || { echo "Aborted."; exit 1; }
	gh workflow run deploy
	@echo "Deploy triggered. Watch: gh run watch"

create-secret: ## Encrypt a .env file: make create-secret FILE=secrets/aws-infra-backup.env
	@test -n "$(FILE)" || { echo "Usage: make create-secret FILE=secrets/<name>.env"; exit 1; }
	sops --encrypt --input-type dotenv --output-type json "$(FILE)" > "$(FILE).enc.tmp" && mv "$(FILE).enc.tmp" "$(FILE).enc" && rm "$(FILE)"
	@echo "Encrypted: $(FILE).enc"

edit-secret: ## Edit an encrypted secret: make edit-secret FILE=secrets/aws-infra-backup.env.enc
	@test -n "$(FILE)" || { echo "Usage: make edit-secret FILE=secrets/<name>.env.enc"; exit 1; }
	sops --input-type json --output-type json "$(FILE)"
