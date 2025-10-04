# Load .env if present (for ORACLE_PASSWORD, ORACLE_SERVICE, etc.)
ifneq (,$(wildcard .env))
include .env
export
endif

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
.DEFAULT_GOAL := help

# ----------------------------
# Global configurable settings
# ----------------------------
COMPOSE         ?= docker compose
ORACLE_CONT     ?= atp-oracle
ORACLE_USER     ?= system
ORACLE_SERVICE  ?= XEPDB1     # Change if your service name differs (XE, ORCL...)
PYTHON          ?= python
R               ?= Rscript
VENV            ?= .venv

# NOTE: Keep spaces-in-paths quoted when running commands.
RANKING_DIR     := "Transform/Ranking Scraping"

# SQL file discovery (alphabetical inside each group).
STAGING  := $(sort $(wildcard ETL/SQL/Tables/Staging/*.sql))
TABLES   := $(filter-out $(STAGING),$(sort $(wildcard ETL/SQL/Tables/*.sql)))
PROCS    := $(sort $(wildcard ETL/SQL/Procedures&Functions/*.sql))  # keep quoted when used
VIEWS    := $(sort $(wildcard ETL/SQL/views/*.sql))

# ------------------------------------------------------------------------------
# R transform order (explicit to avoid lexicographic surprises, e.g., 5_1, 6_1)
# Override at runtime with:
#   make features R_SCRIPTS="Transform/One.R Transform/Two.R"
# ------------------------------------------------------------------------------
R_SCRIPTS ?= \
  Transform/DataTransform1.R \
  Transform/DataTransform2.R \
  Transform/DataTransform3.R \
  Transform/DataTransform4.R \
  Transform/DataTransform5.R \
  Transform/DataTransform5_1.R \
  Transform/DataTransform6.R \
  Transform/DataTransform6_1.R \
  Transform/DataTransform7.R \
  Transform/DataTransform8.R \
  Transform/DataTransform9.R \
  Transform/DataTransform10.R \
  Transform/DataTransform11.R \
  Transform/DataTransform12.R \
  Transform/DataTransformFinal.R

# --------------------------------
# Friendly help (default make goal)
# --------------------------------
.PHONY: help
help: ## Show this help
	@awk 'BEGIN{FS":.*##"; printf "\nAvailable targets:\n"} /^[a-zA-Z0-9_.-]+:.*##/{printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ---------------------------
# Docker / Oracle management
# ---------------------------
.PHONY: db-up db-down db-logs db-restart db-cli db-sql db-wait db-seed db-reset
db-up: ## Start Oracle container in background
	$(COMPOSE) up -d oracle

db-down: ## Stop and remove containers + volumes
	$(COMPOSE) down -v

db-logs: ## Tail Oracle logs
	$(COMPOSE) logs -f oracle

db-restart: db-down db-up ## Restart Oracle container

db-cli: ## Open SQL*Plus as SYSDBA inside the container
	docker exec -it $(ORACLE_CONT) bash -lc "sqlplus -s / as sysdba"

db-sql: ## Run a given SQL file: make db-sql SCRIPT=path/to/file.sql
	@if [ -z "$(SCRIPT)" ]; then echo "Usage: make db-sql SCRIPT=path/to/file.sql"; exit 1; fi
	docker cp "$(SCRIPT)" $(ORACLE_CONT):/tmp/host_script.sql
	docker exec -it $(ORACLE_CONT) bash -lc "sqlplus -L -s $(ORACLE_USER)/$$ORACLE_PASSWORD@//localhost:1521/$$ORACLE_SERVICE @/tmp/host_script.sql"

db-wait: ## Wait until Oracle responds to SQL*Plus
	@echo "Waiting for Oracle ($(ORACLE_CONT)) to accept connections..."
	until docker exec -i $(ORACLE_CONT) bash -lc 'echo "select 1 from dual;" | sqlplus -L -s / as sysdba | grep -q 1'; do \
	  sleep 2; echo -n "."; \
	done
	@echo; echo "Oracle is ready."

db-seed: ## Apply schema in order: Staging -> Tables -> Procs/Funcs -> Views
	@set -e; \
	for f in $(STAGING); do \
	  echo ">> STAGING: $$f"; \
	  docker cp "$$f" $(ORACLE_CONT):/tmp/host_script.sql; \
	  docker exec -i $(ORACLE_CONT) bash -lc 'sqlplus -L -s $(ORACLE_USER)/$$ORACLE_PASSWORD@//localhost:1521/$$ORACLE_SERVICE @/tmp/host_script.sql'; \
	done; \
	for f in $(TABLES); do \
	  echo ">> TABLE: $$f"; \
	  docker cp "$$f" $(ORACLE_CONT):/tmp/host_script.sql; \
	  docker exec -i $(ORACLE_CONT) bash -lc 'sqlplus -L -s $(ORACLE_USER)/$$ORACLE_PASSWORD@//localhost:1521/$$ORACLE_SERVICE @/tmp/host_script.sql'; \
	done; \
	for f in $(PROCS); do \
	  echo ">> PROC/FUNC: $$f"; \
	  docker cp "$$f" $(ORACLE_CONT):/tmp/host_script.sql; \
	  docker exec -i $(ORACLE_CONT) bash -lc 'sqlplus -L -s $(ORACLE_USER)/$$ORACLE_PASSWORD@//localhost:1521/$$ORACLE_SERVICE @/tmp/host_script.sql'; \
	done; \
	for f in $(VIEWS); do \
	  echo ">> VIEW: $$f"; \
	  docker cp "$$f" $(ORACLE_CONT):/tmp/host_script.sql; \
	  docker exec -i $(ORACLE_CONT) bash -lc 'sqlplus -L -s $(ORACLE_USER)/$$ORACLE_PASSWORD@//localhost:1521/$$ORACLE_SERVICE @/tmp/host_script.sql'; \
	done
	@echo "Schema deployed."

db-reset: db-down db-up db-wait db-seed ## Full DB reset (drops volumes)

# -----------------
# Python utilities
# -----------------
.PHONY: venv
venv: ## Create Python venv and install requirements
	$(PYTHON) -m venv $(VENV)
	. $(VENV)/bin/activate; pip install -U pip; pip install -r requirements.txt

# -------------------------
# Rankings scraping/parsing
# -------------------------
.PHONY: rankings
rankings: ## Download and parse ATP rankings (headless HTML -> CSV)
	$(PYTHON) $(RANKING_DIR)/Ranking_scraping.py
	$(PYTHON) $(RANKING_DIR)/rankings_to_csv.py

# -------------
# Python ETL(s)
# -------------
YEAR ?=
.PHONY: etl
etl: ## Run all Python extractors for a given season (require YEAR=YYYY)
	@test -n "$(YEAR)" || (echo "Usage: make etl YEAR=2024"; exit 1)
	$(PYTHON) ETL/Extractor/runner.py tournaments --year $(YEAR)
	$(PYTHON) ETL/Extractor/runner.py players --year $(YEAR)
	$(PYTHON) ETL/Extractor/runner.py matches --year $(YEAR)
	$(PYTHON) ETL/Extractor/runner.py stats --year $(YEAR)

# -------------------------------
# R: install packages if requested
# -------------------------------
.PHONY: r-setup
r-setup: ## Install R packages from r-packages.txt (if present), otherwise use defaults
	@PKGFILE="r-packages.txt"; \
	TMP=$$(mktemp); \
	cat > $$TMP <<'RSCRIPT'
pkgs_file <- "r-packages.txt"
if (file.exists(pkgs_file)) {
  pkgs <- scan(pkgs_file, what = character(), quiet = TRUE)
} else {
  pkgs <- c("data.table","dplyr","readr","stringr","lubridate","tidyr","purrr","zoo","progress","roll")
}
new <- setdiff(pkgs, rownames(installed.packages()))
if (length(new)) install.packages(new, dependencies = TRUE)
invisible(lapply(pkgs, library, character.only = TRUE))
cat("R packages installed and loaded.\n")
RSCRIPT
	$(R) $$TMP; rm -f $$TMP

# ------------------------------
# R: run the full feature build
# ------------------------------
.PHONY: features features-dry
features-dry: ## Print the ordered list of R transform scripts that would be run
	@echo "R transform order:"; \
	for s in $(R_SCRIPTS); do \
	  if [ -f "$$s" ]; then echo "  - $$s"; else echo "  - $$s  (missing, will be skipped)"; fi; \
	done

features: ## Build the match–player feature panel by sourcing all R scripts in order
	@TMP=$$(mktemp); \
	cat > $$TMP <<'RSCRIPT'
options(error = function(e) { message("FATAL: ", conditionMessage(e)); quit(save="no", status = 1) })
# 1) Ensure packages
pkgs <- c("data.table","dplyr","readr","stringr","lubridate","tidyr","purrr","zoo","progress","roll")
new <- setdiff(pkgs, rownames(installed.packages()))
if (length(new)) install.packages(new, dependencies = TRUE)
invisible(lapply(pkgs, library, character.only = TRUE))

# 2) Ordered list injected by Make (env var R_SCRIPTS)
order <- unlist(strsplit(Sys.getenv("R_SCRIPTS"), "\\s+"))
if (length(order) == 0L) stop("R_SCRIPTS is empty")

cat(">>> Running R transforms (in order):\n")
for (s in order) {
  if (!nzchar(s)) next
  if (!file.exists(s)) {
    cat(sprintf(" - SKIP (not found): %s\n", s))
    next
  }
  cat(sprintf("\n>>> SOURCE: %s\n", s))
  source(s, echo = TRUE, max.deparse.length = Inf)
}
cat("\nAll transforms finished. Check the exported dataset.\n")
RSCRIPT
	R_SCRIPTS='$(R_SCRIPTS)' $(R) $$TMP; rm -f $$TMP

# ---------------------------
# Full end-to-end pipeline(s)
# ---------------------------
.PHONY: all
all: db-up db-wait db-seed rankings etl features ## End-to-end: DB -> rankings -> ETL -> features (require YEAR=YYYY)
	@echo "End-to-end pipeline finished."
