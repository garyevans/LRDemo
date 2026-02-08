# Demo selector:
#   make up ENV=16
#   make psql ENV=18 NODE=b
#   make reset-all && make up-all
#
# Defaults
ENV  ?= 16          # 16 or 18
NODE ?= a           # a or b

# Compose service/container naming convention from your docker-compose.yml
SERVICE   = pg$(ENV)_$(NODE)
CONTAINER = pg$(ENV)_$(NODE)
DB        = demo
USER      = postgres

# Host ports (from your YAML)
PORT_16_a = 54161
PORT_16_b = 54162
PORT_18_a = 54181
PORT_18_b = 54182

ifeq ($(ENV),16)
  ifeq ($(NODE),a)
    PORT=$(PORT_16_a)
  else
    PORT=$(PORT_16_b)
  endif
else ifeq ($(ENV),18)
  ifeq ($(NODE),a)
    PORT=$(PORT_18_a)
  else
    PORT=$(PORT_18_b)
  endif
else
  $(error ENV must be 16 or 18)
endif

PSQL = docker exec -i $(CONTAINER) psql -U $(USER) -d $(DB)

# -----------------------------
# Lifecycle
# -----------------------------
up:
	docker compose up -d pg$(ENV)_a pg$(ENV)_b

up-all:
	docker compose up -d

down:
	docker compose down

reset: # wipe volumes for chosen ENV only
	docker compose down
	docker volume rm -f $$(docker volume ls -q | grep -E '^pg$(ENV)_' ) 2>/dev/null || true

reset-all: # wipe all volumes
	docker compose down -v

# -----------------------------
# Readiness + access
# -----------------------------
wait: # wait for chosen node
	@echo "Waiting for $(CONTAINER) (ENV=$(ENV) NODE=$(NODE))..."
	@until docker exec $(CONTAINER) pg_isready -U $(USER) -d $(DB) >/dev/null 2>&1; do sleep 0.3; done
	@echo "Ready: $(CONTAINER) on localhost:$(PORT)"

wait-env: # wait for both nodes in chosen ENV
	@$(MAKE) wait ENV=$(ENV) NODE=a
	@$(MAKE) wait ENV=$(ENV) NODE=b

psql: up wait
	docker exec -it $(CONTAINER) psql -U $(USER) -d $(DB)

# Quick connection strings (handy for tools)
conninfo:
	@echo "postgresql://$(USER):postgres@localhost:$(PORT)/$(DB)"

logs:
	docker logs -f $(CONTAINER)

# -----------------------------
# Script runners (optional: if you keep demo SQL outside init/)
# -----------------------------
# Run a SQL file against a chosen node:
#   make runsql ENV=16 NODE=a FILE=sql/10_demo.sql
FILE ?=
runsql: up wait
	@if [ -z "$(FILE)" ]; then echo "Set FILE=path/to/file.sql"; exit 1; fi
	$(PSQL) < $(FILE)

# Convenience: run same file on both nodes in the ENV
runsql-env: up wait-env
	@if [ -z "$(FILE)" ]; then echo "Set FILE=path/to/file.sql"; exit 1; fi
	@$(MAKE) runsql ENV=$(ENV) NODE=a FILE=$(FILE)
	@$(MAKE) runsql ENV=$(ENV) NODE=b FILE=$(FILE)

# -----------------------------
# Logical replication status helpers
# -----------------------------
repl-status: up wait
	@echo "== $(CONTAINER): subscriptions =="
	@$(PSQL) -c "SELECT subname, subenabled, subconninfo FROM pg_subscription;"
	@echo
	@echo "== $(CONTAINER): subscription stats =="
	@$(PSQL) -c "SELECT subname, relid::regclass AS table, received_lsn, latest_end_lsn, last_msg_send_time, last_msg_receipt_time FROM pg_stat_subscription;"

pub-status: up wait
	@echo "== $(CONTAINER): publications =="
	@$(PSQL) -c "SELECT pubname, puballtables, pubinsert, pubupdate, pubdelete, pubtruncate FROM pg_publication;"
	@echo
	@echo "== $(CONTAINER): publication tables =="
	@$(PSQL) -c "SELECT pubname, schemaname, tablename FROM pg_publication_tables ORDER BY 1,2,3;"

# A safe “smoke test” to show replication is alive (adjust table name to your init scripts)
# Example assumes a table demo.items exists and is part of publication(s)
smoke: up wait-env
	@echo "Insert on $(ENV)_a, read on $(ENV)_b (adjust table if needed)"
	@docker exec -i pg$(ENV)_a psql -U $(USER) -d $(DB) -c "INSERT INTO demo.items(note) VALUES ('smoke test from a ' || now());"
	@sleep 1
	@docker exec -i pg$(ENV)_b psql -U $(USER) -d $(DB) -c "SELECT * FROM demo.items ORDER BY id DESC LIMIT 5;"

help:
	@echo "Targets:"
	@echo "  make up ENV=16|18            # start the two-node env"
	@echo "  make up-all                  # start everything"
	@echo "  make psql ENV=18 NODE=b      # interactive psql into a node"
	@echo "  make wait-env ENV=16         # wait for both nodes"
	@echo "  make repl-status ENV=16 NODE=a"
	@echo "  make pub-status  ENV=18 NODE=b"
	@echo "  make runsql FILE=sql/x.sql ENV=16 NODE=a"
	@echo "  make runsql-env FILE=sql/x.sql ENV=18"
	@echo "  make smoke ENV=16            # simple replication proof (adjust table name)"
	@echo "  make reset ENV=16            # wipe volumes for one env"
	@echo "  make reset-all               # wipe everything"