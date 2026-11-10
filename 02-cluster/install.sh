#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update
helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace -f values.yaml
kubectl apply -f longhorn-servicemonitor.yaml
kubectl -n monitoring get pods
