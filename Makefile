.PHONY: help build up down restart logs shell shell-root audit hardened-run railway-deploy railway-logs railway-vars clean nuke

IMAGE   := openclaw:local
COMPOSE := docker compose

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# ── Setup ─────────────────────────────────────────────────────────────────────

init: ## First-time setup: copy .env and create workspace
	@[ -f .env ] || (cp .env.example .env && echo "Created .env — fill in your API keys before running.")
	@mkdir -p workspace
	@echo "Done. Edit .env then run: make build && make up"

build: ## Build the Docker image
	$(COMPOSE) build --no-cache

# ── Lifecycle ─────────────────────────────────────────────────────────────────

up: ## Start openclaw in the background
	$(COMPOSE) up -d

down: ## Stop and remove containers
	$(COMPOSE) down

restart: ## Restart the container
	$(COMPOSE) restart openclaw

logs: ## Follow container logs
	$(COMPOSE) logs -f openclaw

# ── Debug ─────────────────────────────────────────────────────────────────────

shell: ## Open a shell inside the running container (as openclaw user)
	$(COMPOSE) exec openclaw sh

shell-root: ## Open a root shell (for debugging only — never in production)
	docker exec -u root -it openclaw sh

# ── Security ──────────────────────────────────────────────────────────────────

audit: ## Run a quick security audit on the image
	@echo "==> Checking for root processes inside container..."
	@docker exec openclaw sh -c "id && ps aux" 2>/dev/null || echo "Container not running."
	@echo "==> Scanning image with docker scout (if available)..."
	@docker scout cves $(IMAGE) 2>/dev/null || echo "docker scout not installed — skipping CVE scan."

hardened-run: ## Run with full hardening flags (no compose, single container)
	docker run -d \
	  --name openclaw-hardened \
	  --read-only \
	  --cap-drop=ALL \
	  --security-opt=no-new-privileges \
	  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
	  --network=none \
	  --cpus="1.0" \
	  --memory="512m" \
	  --env-file .env \
	  -v $(PWD)/workspace:/workspace \
	  $(IMAGE)

# ── Railway ───────────────────────────────────────────────────────────────────

railway-deploy: ## Deploy to Railway (requires: npm i -g @railway/cli && railway login)
	railway up

railway-logs: ## Tail Railway logs
	railway logs

railway-vars: ## Push .env variables to Railway (run once after init)
	@[ -f .env ] || (echo "No .env found. Run: make init" && exit 1)
	railway variables set $(shell grep -v '^#' .env | grep '=' | xargs)

# ── Cleanup ───────────────────────────────────────────────────────────────────

clean: ## Remove containers and dangling images
	$(COMPOSE) down --remove-orphans
	docker image prune -f

nuke: ## Remove everything including the built image and workspace data (DESTRUCTIVE)
	@read -p "This will delete the image AND workspace data. Are you sure? [y/N] " ans && [ "$$ans" = "y" ]
	$(COMPOSE) down --volumes --remove-orphans
	docker rmi $(IMAGE) 2>/dev/null || true
	@echo "Done."
