.PHONY: help dev up down logs restart reload status validate pull

help: ## Show this help
	@echo "Caddy Reverse Proxy - Available Commands"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

dev: ## Serve homepage locally (http://localhost:8080)
	cd homepage && python3 -m http.server 8080

up: ## Start Caddy
	docker compose up -d

down: ## Stop Caddy
	docker compose down

logs: ## Show logs (follow)
	docker compose logs -f

reload: ## Reload Caddyfile (no downtime)
	docker exec caddy caddy reload --config /etc/caddy/Caddyfile

restart: down up ## Restart Caddy

status: ## Show running containers
	docker compose ps

validate: ## Validate Caddyfile syntax
	docker exec caddy caddy validate --config /etc/caddy/Caddyfile

pull: ## Pull latest images
	docker compose pull
