#!/usr/bin/env bash
set -euo pipefail
USER_NAME="${1:-writer}"
PASS="${2:?usage: $0 <user> <password>}"
kubectl get ns monitoring >/dev/null 2>&1 || kubectl create ns monitoring
kubectl -n monitoring create secret generic remote-write-auth \
  --from-literal=username="$USER_NAME" --from-literal=password="$PASS" \
  --dry-run=client -o yaml | kubectl apply -f -
