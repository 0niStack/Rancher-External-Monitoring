#!/usr/bin/env bash
# Generates prometheus/web.yml (bcrypt basic auth) and the self-scrape password file from .env
set -euo pipefail
cd "$(dirname "$0")"
[ -f .env ] || { echo "Create .env first: cp .env.example .env"; exit 1; }
set -a; . ./.env; set +a

HASH=$(docker run --rm httpd:2.4-alpine htpasswd -nbBC 10 "" "$PROM_PASSWORD" | tr -d ':\n' | sed 's/^\$2y/$2a/')

cat > prometheus/web.yml <<YML
basic_auth_users:
  ${PROM_USER}: '${HASH}'
YML

printf '%s' "$PROM_PASSWORD" > prometheus/secrets/password
chmod 600 prometheus/secrets/password
echo "Wrote prometheus/web.yml and prometheus/secrets/password"
