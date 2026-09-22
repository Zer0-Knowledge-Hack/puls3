#!/usr/bin/env bash
# Generates local development secrets for puls3_server. Safe to re-run: it never
# overwrites existing files. Values are random and only valid on your machine.
set -euo pipefail
cd "$(dirname "$0")/../puls3_server"

rand() { openssl rand -hex 16; }

if [ ! -f .env ]; then
  {
    echo "POSTGRES_PASSWORD=$(rand)"
    echo "REDIS_PASSWORD=$(rand)"
    echo "POSTGRES_TEST_PASSWORD=$(rand)"
    echo "REDIS_TEST_PASSWORD=$(rand)"
  } > .env
  echo "Created puls3_server/.env"
else
  echo "puls3_server/.env already exists, keeping it"
fi

if [ ! -f config/passwords.yaml ]; then
  # shellcheck disable=SC1091
  set -a; . ./.env; set +a
  awk -v pg="$POSTGRES_PASSWORD" -v rd="$REDIS_PASSWORD" \
      -v pgt="$POSTGRES_TEST_PASSWORD" -v rdt="$REDIS_TEST_PASSWORD" '
    /^[a-z]+:/ { section = $1 }
    /<generate>/ {
      if (section == "development:" && $1 == "database:") { sub(/<generate>/, pg) }
      else if (section == "development:" && $1 == "redis:") { sub(/<generate>/, rd) }
      else if (section == "test:" && $1 == "database:") { sub(/<generate>/, pgt) }
      else if (section == "test:" && $1 == "redis:") { sub(/<generate>/, rdt) }
      else { cmd = "openssl rand -hex 32"; cmd | getline v; close(cmd); sub(/<generate>/, v) }
    }
    { print }
  ' config/passwords.example.yaml > config/passwords.yaml
  echo "Created puls3_server/config/passwords.yaml"
else
  echo "puls3_server/config/passwords.yaml already exists, keeping it"
fi
