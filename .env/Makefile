ifneq (,$(wildcard .env))
include .env
export
endif

.PHONY: db-up db-down db-logs db-restart db-cli db-sql

db-up:
	docker compose up -d oracle

db-down:
	docker compose down -v

db-logs:
	docker compose logs -f oracle

db-restart: db-down db-up

db-cli:
	docker exec -it atp-oracle bash -lc "sqlplus -s / as sysdba"

db-sql:
	@if [ -z "$(SCRIPT)" ]; then echo "Uso: make db-sql SCRIPT=path/to/file.sql"; exit 1; fi
	docker cp $(SCRIPT) atp-oracle:/tmp/host_script.sql
	docker exec -it atp-oracle bash -lc "sqlplus -s system/$$ORACLE_PASSWORD@//localhost:1521/$$ORACLE_SERVICE @/tmp/host_script.sql"
