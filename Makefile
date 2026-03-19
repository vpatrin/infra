.PHONY: help dev-homepage logs status validate-caddy reload-caddy deploy

help: ## Show this help
	@echo "Platform Infrastructure - Available Commands"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

dev-homepage: ## Serve homepage locally (http://localhost:8080)
	cd services/homepage && python3 -m http.server 8080

logs: ## Show logs (follow)
	docker compose logs -f

status: ## Show running containers
	docker compose ps

validate-caddy: ## Validate Caddy configuration
	docker exec caddy caddy validate --config /etc/caddy/Caddyfile --adapter
	
reload-caddy: ## Reload Caddy configuration
	docker exec caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile

deploy: ## Trigger production deploy via GitHub Actions
	@echo "⚠️  This will deploy to production (web-01)."
	@read -p "Type 'approve' to continue: " confirm && [ "$$confirm" = "approve" ] || { echo "Aborted."; exit 1; }
	gh workflow run deploy
	@echo "Deploy triggered. Watch: gh run watch"
