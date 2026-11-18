#!/usr/bin/env bash
# Adds a random value to every Secret Manager secret that has no version yet.
# Values never touch Terraform state or Git. Safe to re-run (idempotent).
#
# Usage: PROJECT_ID=gke-terraform-ardin01 ./scripts/seed-secrets.sh
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
SECRETS=(keycloak-admin-password keycloak-db-password grafana-admin-password apisix-admin-key)

for s in "${SECRETS[@]}"; do
  if [[ -n "$(gcloud secrets versions list "$s" --project "$PROJECT_ID" --limit=1 --format='value(name)' 2>/dev/null)" ]]; then
    echo "skip   $s (already has a version)"
    continue
  fi
  # 32 alphanumeric chars: no quoting problems in Helm values / URLs
  openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32 \
    | gcloud secrets versions add "$s" --project "$PROJECT_ID" --data-file=- >/dev/null
  echo "seeded $s"
done

echo
echo "Read a value with: gcloud secrets versions access latest --secret=<name>"
