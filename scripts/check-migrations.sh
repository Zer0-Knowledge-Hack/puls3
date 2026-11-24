#!/usr/bin/env bash
# Checks the server migrations (#373):
#   1. the models produce no pending migration;
#   2. a fresh database and an upgraded one end with the same schema.
#
# Usage: scripts/check-migrations.sh [base-ref]
#   base-ref  the commit whose migrations the "upgraded" database starts from.
#             Default: the merge base of HEAD and origin/main.
#
# Needs a Postgres server and `serverpod` on PATH. It creates two scratch
# databases (mig_fresh and mig_upgraded) and drops them when it ends.
#
# Environment (defaults match the local test database in
# docs/testing/local-environment.md):
#   PGHOST, PGPORT, PGUSER, PGPASSWORD  how to reach Postgres (localhost:9090,
#                                       postgres, ci_database_password)
#   PG_CONTAINER                        run psql and pg_dump inside this Docker
#                                       container instead of using local tools
#   SERVERPOD_BIN                       the serverpod command (default: serverpod)
#
# puls3_server/config/passwords.yaml must have a `test:` section whose
# `database` password is PGPASSWORD; CI writes it.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
server="$root/puls3_server"
migrations="$server/migrations"

export PGHOST="${PGHOST:-localhost}"
export PGPORT="${PGPORT:-9090}"
export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-ci_database_password}"
serverpod_bin="${SERVERPOD_BIN:-serverpod}"

base="${1:-}"
if [ -z "$base" ]; then
  base="$(git -C "$root" merge-base HEAD origin/main)"
fi

work="$(mktemp -d)"
fresh_db=mig_fresh
upgraded_db=mig_upgraded
restore_migrations=false

pg() {
  if [ -n "${PG_CONTAINER:-}" ]; then
    docker exec -i -e PGUSER -e PGPASSWORD "$PG_CONTAINER" "$@"
  else
    "$@"
  fi
}

drop_databases() {
  for db in "$fresh_db" "$upgraded_db"; do
    pg psql -q -d postgres -c "DROP DATABASE IF EXISTS $db" >/dev/null 2>&1 || true
  done
}

cleanup() {
  if [ "$restore_migrations" = true ] && [ -d "$work/head-migrations" ]; then
    rm -rf "$migrations"
    cp -R "$work/head-migrations" "$migrations"
  fi
  drop_databases
  rm -rf "$work"
}
trap cleanup EXIT

# Applies the migrations folder in puls3_server/migrations to one database and
# exits (the maintenance role does not serve requests).
apply_migrations() {
  (
    cd "$server"
    SERVERPOD_DATABASE_NAME="$1" \
      SERVERPOD_DATABASE_HOST="$PGHOST" \
      SERVERPOD_DATABASE_PORT="$PGPORT" \
      dart bin/main.dart --mode test --role maintenance --apply-migrations
  )
}

schema() {
  # pg_dump prints a random restrict token on every run; it is not schema.
  pg pg_dump --schema-only --no-owner --no-privileges "$1" | grep -vE '^[\](un)?restrict '
}

echo "== 1/2 The models produce no pending migration"
if [ -n "$(git -C "$root" status --porcelain -- puls3_server/migrations)" ]; then
  echo "puls3_server/migrations has uncommitted changes; commit or stash them first." >&2
  exit 2
fi
(cd "$server" && "$serverpod_bin" create-migration --no-analytics >/dev/null)
pending="$(git -C "$root" status --porcelain -- puls3_server/migrations)"
# Leave the repository as it was found: the dry run writes nowhere to keep.
git -C "$root" checkout -q -- puls3_server/migrations
git -C "$root" clean -fdq -- puls3_server/migrations
if [ -n "$pending" ]; then
  echo "The models differ from the last migration. Run 'serverpod create-migration' and commit the result:" >&2
  echo "$pending" >&2
  exit 1
fi
echo "ok: no pending migration"

echo "== 2/2 A fresh database and an upgraded one end with the same schema (base $base)"
drop_databases
pg psql -q -d postgres -c "CREATE DATABASE $fresh_db" >/dev/null
pg psql -q -d postgres -c "CREATE DATABASE $upgraded_db" >/dev/null

apply_migrations "$fresh_db"
schema "$fresh_db" >"$work/fresh.sql"

# Upgraded path: the base's migrations first, then this branch's.
cp -R "$migrations" "$work/head-migrations"
mkdir "$work/base"
git -C "$root" archive "$base" -- puls3_server/migrations | tar -x -C "$work/base"
restore_migrations=true
rm -rf "$migrations"
cp -R "$work/base/puls3_server/migrations" "$migrations"
# The server code is this branch's, so after the base migrations it reports
# that the database does not match its target and exits non-zero. That is
# expected here; what matters is that the base's last migration was applied.
apply_migrations "$upgraded_db" || true
base_last="$(ls "$migrations" | grep -E '^[0-9]+-' | sort | tail -1)"
applied="$(pg psql -tA -d "$upgraded_db" -c "SELECT version FROM serverpod_migrations WHERE module = 'puls3'")"
if [ "$applied" != "$base_last" ]; then
  echo "The base migrations did not apply: expected $base_last, found '$applied'." >&2
  exit 1
fi
rm -rf "$migrations"
cp -R "$work/head-migrations" "$migrations"
restore_migrations=false
apply_migrations "$upgraded_db"
schema "$upgraded_db" >"$work/upgraded.sql"

if ! diff -u "$work/fresh.sql" "$work/upgraded.sql"; then
  echo "The fresh and the upgraded schemas differ (diff above: - fresh, + upgraded)." >&2
  exit 1
fi
echo "ok: both paths end with the same schema"
