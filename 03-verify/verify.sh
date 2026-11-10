#!/usr/bin/env bash
# Run on the external server: ./verify.sh   (reads ../01-server/.env)
set -euo pipefail
cd "$(dirname "$0")/../01-server"; set -a; . ./.env; set +a
q() { curl -fsS -u "$PROM_USER:$PROM_PASSWORD" --data-urlencode "query=$1" http://localhost:9090/api/v1/query | python3 -c 'import sys,json;d=json.load(sys.stdin)["data"]["result"];print(len(d),"series")'; }
echo -n "node-exporter targets:  "; q 'up{job="node-exporter"}'
echo -n "kubelet volume stats:   "; q 'kubelet_volume_stats_used_bytes'
echo -n "cAdvisor fs usage:      "; q 'container_fs_usage_bytes'
echo -n "longhorn volumes:       "; q 'longhorn_volume_capacity_bytes'
echo -n "longhorn node storage:  "; q 'longhorn_node_storage_capacity_bytes'
