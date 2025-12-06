#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="configs/orders_stream.yml"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

# Load environment variables from .env if present
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Configuration file $CONFIG_FILE does not exist. Exiting."
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required to parse YAML."
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is required because PostgreSQL runs in a container."
  exit 1
fi

if [ -z "${DOCKER_PG_CONTAINER:-}" ]; then
  echo "ERROR: Please set DOCKER_PG_CONTAINER to your running Postgres container name (e.g. export DOCKER_PG_CONTAINER=postgres)."
  exit 1
fi

read_yaml() {
  local key="$1"
  python3 - <<PY
import sys, yaml
with open("$CONFIG_FILE", "r") as f:
    cfg = yaml.safe_load(f)
keys = "$key".split('.')
val = cfg
for k in keys:
    val = val.get(k)
    if val is None:
        break
if isinstance(val, (int, float)):
    print(val)
elif val is None:
    print("")
else:
    print(str(val))
PY
}

PG_HOST=$(read_yaml postgres.host)
PG_PORT=$(read_yaml postgres.port)
DB_NAME=$(read_yaml postgres.db)
DB_USER=$(read_yaml postgres.user)
DB_PASSWORD=$(read_yaml postgres.password)

if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
  echo "ERROR: Failed to read database settings from $CONFIG_FILE."
  exit 1
fi

SUPERUSER=$(docker exec "$DOCKER_PG_CONTAINER" /bin/sh -lc 'echo -n "$POSTGRES_USER"' || true)
[ -z "$SUPERUSER" ] && SUPERUSER=postgres
SUPERPASS=$(docker exec "$DOCKER_PG_CONTAINER" /bin/sh -lc 'echo -n "$POSTGRES_PASSWORD"' || true)

exec_psql_super() {
  if [ -n "$SUPERPASS" ]; then
    docker exec -i -e PGPASSWORD="$SUPERPASS" "$DOCKER_PG_CONTAINER" psql -v ON_ERROR_STOP=1 -U "$SUPERUSER" -d postgres -c "$1"
  else
    docker exec -i "$DOCKER_PG_CONTAINER" psql -v ON_ERROR_STOP=1 -U "$SUPERUSER" -d postgres -c "$1"
  fi
}

exec_psql_file_as_db_user() {
  if [ ! -f "$1" ]; then
    echo "ERROR: SQL file $1 not found."
    exit 1
  fi
  if [ -z "$DB_PASSWORD" ]; then
    echo "ERROR: DB password is empty; cannot authenticate as $DB_USER."
    exit 1
  fi
  cat "$1" | docker exec -i -e PGPASSWORD="$DB_PASSWORD" "$DOCKER_PG_CONTAINER" psql -v ON_ERROR_STOP=1 -h 127.0.0.1 -p "${PG_PORT:-5432}" -U "$DB_USER" -d "$DB_NAME"
}

exec_psql_super "DROP DATABASE IF EXISTS \"$DB_NAME\";"
exec_psql_super "DROP ROLE IF EXISTS \"$DB_USER\";"
exec_psql_super "CREATE ROLE \"$DB_USER\" LOGIN PASSWORD '$DB_PASSWORD';"
exec_psql_super "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"
exec_psql_super "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"
exec_psql_super "ALTER DATABASE \"$DB_NAME\" OWNER TO \"$DB_USER\";"

db_sql_path="$PROJECT_ROOT/db/orders.sql"
if [ -f "$db_sql_path" ]; then
  exec_psql_file_as_db_user "$db_sql_path"
else
  echo "WARNING: $db_sql_path not found. Skipping schema load."
fi

echo "Database setup complete for $DB_NAME."
