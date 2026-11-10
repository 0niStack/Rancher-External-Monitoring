# Rancher external monitoring

Cluster metrics are collected inside the Rancher-managed cluster and pushed (`remote_write`)
to a Prometheus + Grafana server **outside** the cluster. Only outbound HTTPS from the cluster is needed.

```
[Cluster] node-exporter + kube-state-metrics + kubelet/cAdvisor + Longhorn manager
    └─ Prometheus (6h buffer) ──remote_write──▶ [External Prometheus] ──▶ [External Grafana]
```

Dashboard sections: node CPU/RAM (master + worker), image/container-runtime disk, PVC usage + PV mapping, Longhorn volumes and node disks.

## Layout

```
01-server/   Prometheus + Grafana (Docker Compose), alert rules, provisioned dashboard
02-cluster/  kube-prometheus-stack values, remote-write secret, Longhorn ServiceMonitor
03-verify/   Checks that every metric family arrived
```

## 1. External server

```bash
cd 01-server
cp .env.example .env && nano .env     # set PROM_USER / PROM_PASSWORD / Grafana admin
# if you change PROM_USER, also change `username:` in prometheus/prometheus.yml
./gen-auth.sh                         # writes prometheus/web.yml (bcrypt) + secrets/password
docker compose up -d
```

Prometheus runs with `--web.enable-remote-write-receiver` and basic auth.
Put HTTPS in front (Nginx, Caddy, or Traefik) so the cluster can push to
`https://prometheus.example.com/api/v1/write`. Never expose it over plain HTTP.

Grafana: `http://<server>:3000`. The datasource and the dashboard
**Rancher Cluster: Nodes, Image Storage, PVC and Longhorn** (folder *Rancher Cluster*) are provisioned automatically.

## 2. Cluster

Edit `02-cluster/values.yaml`:
- `externalLabels.cluster`: a unique name for this cluster
- `remoteWrite[0].url`: your HTTPS endpoint

```bash
./02-cluster/create-secret.sh writer 'SAME_PASSWORD_AS_ENV'
./02-cluster/install.sh
```

`install.sh` installs kube-prometheus-stack (Grafana, Alertmanager and default rules disabled)
and applies the Longhorn ServiceMonitor. If Rancher Monitoring is already installed in this
cluster, remove it first or don't run both.

## 3. Verify

On the server, after a minute or two:

```bash
./03-verify/verify.sh
```

Every line should show more than 0 series.

## Notes

- **Docker image storage**: kubelet does not expose a metric for the image store itself, so it is tracked
  through the node filesystem that holds it. If `/var/lib/docker` (or `/var/lib/containerd`, `/var/lib/rancher` on RKE2)
  is on its own disk, it appears as its own mountpoint. Otherwise images share `/` and show up there.
  Use the **Mountpoint** dropdown. The pod table uses cAdvisor `container_fs_usage_bytes` (writable layers and logs).
- **PVC panels** use `kubelet_volume_stats_*` joined with `kube_persistentvolumeclaim_info`, so the PV name and
  storage class are shown. The StorageClass dropdown is a regex (default `longhorn`, use `.*` for all).
- **Longhorn panels** need the ServiceMonitor from `02-cluster`. Metric names follow Longhorn's `longhorn_volume_*`
  and `longhorn_node_storage_*`; if a panel is empty, check the exact names on your Longhorn version in Prometheus.
- `writeRelabelConfigs` keeps only the metric families the dashboard uses. Add names to the regex if you extend it.
- Alert rules in `01-server/prometheus/rules/storage.yml` are evaluated by Prometheus. To get notifications,
  add an Alertmanager to the server and point `prometheus.yml` at it.
- A kubelet or node-exporter target in Rancher/RKE2 shows as down only if the firewall blocks port 10250 or 9100
  between nodes; the in-cluster Prometheus scrapes them, not the external server.

## Dashboards (both provisioned automatically)

| File | Dashboard |
|---|---|
| `01-server/grafana/dashboards/cluster-storage-overview.json` | Nodes CPU/RAM, image storage, PVC/PV, Longhorn (incl. `/var/lib/longhorn-disk`) |
| `01-server/grafana/dashboards/pods-namespaces-resources.json` | Namespaces (Rancher project ID), pods per node, CPU/memory/requests/limits per node, namespace and pod, restarts |

Longhorn data path is `/var/lib/longhorn-disk`. The storage dashboard has panels for it from Longhorn's own metrics
(`longhorn_disk_*`) and, if it is a separately mounted disk, from node-exporter too.

The namespace-to-project mapping needs `metricLabelsAllowlist` in `02-cluster/values.yaml`, then re-run
`./02-cluster/install.sh`. Rancher exposes the project **ID** (p-xxxxx), not the project name.

## Using your existing Grafana (Prometheus only on the new VM)

1. Start only Prometheus: `cd 01-server && ./gen-auth.sh && docker compose -f docker-compose.prometheus-only.yml up -d`
2. In your Grafana add the datasource from `existing-grafana/datasource-rancher-prometheus.yml`
   (name `Rancher-Prometheus`, uid `rancher-cluster-prom`, not default).
3. Import both dashboards from `01-server/grafana/dashboards/` (Dashboards > New > Import).
   They use a **Prometheus (Rancher)** dropdown, so they only query this datasource and never your other ones.
