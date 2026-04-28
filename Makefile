.PHONY: help bootstrap up down status dev-homepage validate-caddy reload-caddy deploy tunnel create-secret edit-secret encrypt-vault decrypt-vault

# Stacks in startup dependency order (data plane first, then edge, then apps).
STACKS := postgres coupette-redis caddy umami uptime-kuma observability

# -----------------------------------------------------------------------
# Local development commands
# -----------------------------------------------------------------------
help: ## Show this help
	@echo "Platform Infrastructure - Available Commands"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+%?:.*?##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

bootstrap: ## One-time: create shared Docker network + external volumes
	@docker network create internal 2>/dev/null || true
	@docker volume create shared-postgres_pgdata 2>/dev/null || true
	@docker volume create uptime-kuma_uptime-kuma-data 2>/dev/null || true
	@echo "Bootstrap complete."

up: ## Start all stacks (dev mode — loopback ports)
	@for s in $(STACKS); do \
		echo "==> $$s"; \
		dev=""; [ -f stacks/$$s/docker-compose.dev.yml ] && dev="-f stacks/$$s/docker-compose.dev.yml"; \
		docker compose -f stacks/$$s/docker-compose.yml $$dev up -d; \
	done

down: ## Stop all stacks
	@for s in $(STACKS); do \
		docker compose -f stacks/$$s/docker-compose.yml down; \
	done

up-%: ## Start a single stack: make up-caddy
	@dev=""; [ -f stacks/$*/docker-compose.dev.yml ] && dev="-f stacks/$*/docker-compose.dev.yml"; \
	docker compose -f stacks/$*/docker-compose.yml $$dev up -d

down-%: ## Stop a single stack: make down-caddy
	@docker compose -f stacks/$*/docker-compose.yml down

logs-%: ## Follow logs for a single stack: make logs-observability
	@docker compose -f stacks/$*/docker-compose.yml logs -f

status: ## Show running containers (all stacks)
	@for s in $(STACKS); do \
		echo "==> $$s"; \
		docker compose -f stacks/$$s/docker-compose.yml ps; \
	done

dev-homepage: ## Serve homepage locally (http://localhost:8080)
	cd stacks/caddy/homepage && python3 -m http.server 8080

# -----------------------------------------------------------------------
# Caddy
# -----------------------------------------------------------------------
validate-caddy: ## Validate Caddyfile syntax
	docker exec caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

reload-caddy: ## Reload Caddy configuration
	docker exec caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile

# -----------------------------------------------------------------------
# Operations
# -----------------------------------------------------------------------
deploy: ## Trigger production deploy via GitHub Actions (override branch with REF=...)
	@ref="$(or $(REF),main)"; \
	echo "⚠️  This will deploy '$$ref' to production (web-01)."; \
	read -p "Type 'approve' to continue: " confirm && [ "$$confirm" = "approve" ] || { echo "Aborted."; exit 1; }; \
	gh workflow run deploy -f ref="$$ref"
	@echo "Deploy triggered. Watch: gh run watch"

tunnel: ## SSH tunnel to Grafana (:3002)
	@echo "Grafana: http://localhost:3002"
	ssh -N -L 3002:127.0.0.1:3002 web-01

# -----------------------------------------------------------------------
# Secrets management (SOPS + Ansible Vault)
# -----------------------------------------------------------------------
create-secret: ## Encrypt a .env file: make create-secret FILE=secrets/aws-infra-backup.env
	@test -n "$(FILE)" || { echo "Usage: make create-secret FILE=secrets/<name>.env"; exit 1; }
	sops --encrypt --input-type dotenv --output-type json "$(FILE)" > "$(FILE).enc.tmp" && mv "$(FILE).enc.tmp" "$(FILE).enc" && rm "$(FILE)"
	@echo "Encrypted: $(FILE).enc"

edit-secret: ## Edit an encrypted secret: make edit-secret FILE=secrets/aws-infra-backup.env.enc
	@test -n "$(FILE)" || { echo "Usage: make edit-secret FILE=secrets/<name>.env.enc"; exit 1; }
	sops --input-type json --output-type json "$(FILE)"

encrypt-vault: ## Encrypt Ansible vault
	cd ansible && ansible-vault encrypt group_vars/all/vault.yml

decrypt-vault: ## Decrypt Ansible vault
	cd ansible && ansible-vault decrypt group_vars/all/vault.yml
