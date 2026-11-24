# terraform-sre-observability-guardrails

Synthetic reference repository demonstrating SRE observability guardrails in Terraform (New Relic NRQL alert conditions + AWS CloudWatch Metric Streams) paired with a Kubernetes Spot High-Availability Kustomize overlay and ArgoCD Application manifest.

## Why This Exists

Three recurring failure patterns show up in cloud observability and Kubernetes operations:

1. **Silent batch stagnation**: Scheduled cron jobs, Airflow DAGs, or systemd workers stop emitting events without raising an error counter, leaving static error-rate alerts green while jobs stay stalled.
2. **Diluted error ratios**: High-frequency `/health` probes or synthetic pings flood denominator counts so user-facing `5xx` outages sit below percentage thresholds.
3. **Unbounded CloudWatch telemetry bills & single-node Spot outages**: Streaming entire AWS namespaces into OpenTelemetry sinks spikes ingestion cost, while running critical APIs without `topologySpreadConstraints` and `PodDisruptionBudget` lets Spot preemptions drop all replicas at once.

This repository encodes strict, validated Terraform modules and Kubernetes/ArgoCD manifests that prevent those failure modes by construction.

## Origin & Sanitization

All code, module defaults, workload names (`checkout-api`, `nightly-etl-worker`, `session-cache`), environment names (`synthetic-prod`), ARNs (`000000000000`), and alert queries in this repository are 100% synthetic. Patterns reflect general SRE practices and contain zero proprietary topologies, account IDs, endpoints, or credentials.

## What It Intentionally Does Not Do

- Does not provision AWS IAM roles, Kinesis Data Firehose delivery streams, VPC networking, or EKS clusters.
- Does not create real New Relic notification destinations, Slack webhooks, or PagerDuty routing keys.
- Does not deploy cluster-wide Kubernetes RBAC (`ClusterRole` / `ClusterRoleBinding`) or privileged containers.
- Does not run `terraform apply` against live cloud accounts in CI.

## Architecture

```text
+-----------------------------------------------------------------------------+
|                        Synthetic Platform Guardrails                        |
+-----------------------------------------------------------------------------+
|                                                                             |
|  [nightly-etl-worker] ---> Heartbeat Events ---> [nrql-deadman-watchdog]    |
|                            (missing/0 signal)    fill_option=static (0)     |
|                                                  open_violation_on_exp=true |
|                                                                             |
|  [checkout-api] ---------> TransactionError ---> [nrql-distinct-session]    |
|                            uniqueCount(session)  excludes /health* noise    |
|                                                                             |
|  [session-cache] --------> AWS/ElastiCache  ---> [cw-metric-stream-filter]  |
|  (RDS + Redis)             AWS/RDS (allowlist)   otel0.7 / otel1.0 / json   |
|                                                  rejects empty filters      |
|                                                                             |
|  [ArgoCD Application] ---> [prod-spot-ha] -----> Deployment (replicas >= 2) |
|  (prune + selfHeal)        Kustomize Overlay     hostname: DoNotSchedule    |
|                                                  zone: ScheduleAnyway       |
|                                                  PDB: minAvailable >= 1     |
+-----------------------------------------------------------------------------+
```

## Module & Overlay Summary

### Terraform Modules

| Component | Path | Provider | Key Guardrail |
| :--- | :--- | :--- | :--- |
| Deadman Watchdog | [modules/nrql-deadman-watchdog](modules/nrql-deadman-watchdog) | `newrelic/newrelic ~> 3.30` | Enforces `fill_option = "static"`, `fill_value = 0`, `open_violation_on_expiration = true`, and `critical` threshold `equals 0`. |
| Distinct Session Alert | [modules/nrql-distinct-session-alert](modules/nrql-distinct-session-alert) | `newrelic/newrelic ~> 3.30` | Validates NRQL queries use `uniqueCount(...)` or `filter(...)`, with `static`/`baseline` mode and optional `warning` tier. |
| CloudWatch Stream Filter | [modules/cw-metric-stream-filter](modules/cw-metric-stream-filter) | `hashicorp/aws ~> 5.0` | Enforces non-empty `include_filter` allowlists (no `exclude_filter`, no empty namespace wildcards) and validated `output_format`. |
| Synthetic Stack Example | [examples/synthetic-platform-stack](examples/synthetic-platform-stack) | `aws ~> 5.0`, `newrelic ~> 3.30` | Wires all three modules for `nightly-etl-worker`, `checkout-api`, and `session-cache` (`AWS/ElastiCache` and `AWS/RDS`). |

### Kubernetes & ArgoCD Layout

| Component | Path | Purpose |
| :--- | :--- | :--- |
| Hardened Base Workload | [k8s/spot-ha-overlay/base](k8s/spot-ha-overlay/base) | Non-root `Deployment` (`readOnlyRootFilesystem: true`, `ALL` capabilities dropped, probes, resource limits) + `PodDisruptionBudget` (`minAvailable: 1`). |
| Spot HA Overlay | [k8s/spot-ha-overlay/overlays/prod-spot-ha](k8s/spot-ha-overlay/overlays/prod-spot-ha) | Scales to `replicas: 2` and enforces `topologySpreadConstraints` across nodes and zones. |
| ArgoCD Sync Definition | [k8s/spot-ha-overlay/argocd/application.yaml](k8s/spot-ha-overlay/argocd/application.yaml) | Targets `overlays/prod-spot-ha` with automated `prune: true` and `selfHeal: true`. |

## Kubernetes Spot HA Design Notes

- **Node spread (`kubernetes.io/hostname`, `maxSkew: 1`, `whenUnsatisfiable: DoNotSchedule`)**: Hard constraint preventing two replicas from landing on the same EC2 instance, avoiding total outage when a single Spot instance receives a 2-minute interruption notice.
- **Zone spread (`topology.kubernetes.io/zone`, `maxSkew: 1`, `whenUnsatisfiable: ScheduleAnyway`)**: Soft multi-AZ preference so pods spread across Availability Zones when capacity exists without blocking scheduling during transient zone Spot capacity shortages.
- **Disruption budget (`minAvailable: 1`)**: Blocks voluntary node drains (cluster upgrades, Karpenter consolidation) from evicting the last healthy replica. Note that the `base` Deployment keeps `replicas: 1` (0 voluntary disruptions allowed) until `overlays/prod-spot-ha` scales it to `replicas: 2`.
- **Pod hardening**: Disables service account token automounting (`automountServiceAccountToken: false`), enforces `seccompProfile: RuntimeDefault`, mounts `/tmp` as `emptyDir`, and avoids `ClusterRole` / `ClusterRoleBinding`.

## Quickstart

Validate Terraform formatting and static configuration locally without live cloud credentials (the New Relic provider requires placeholder env vars during `terraform validate`):

```bash
export NEW_RELIC_API_KEY="synthetic-placeholder-key"
export NEW_RELIC_ACCOUNT_ID="1234567"
export NEW_RELIC_REGION="US"

terraform fmt -check -recursive

for dir in \
  modules/nrql-deadman-watchdog \
  modules/nrql-distinct-session-alert \
  modules/cw-metric-stream-filter \
  examples/synthetic-platform-stack; do
  terraform -chdir="${dir}" init -backend=false
  terraform -chdir="${dir}" validate
done

kubectl kustomize k8s/spot-ha-overlay/overlays/prod-spot-ha
```

Run the Python guardrail test suite (`pytest` + `PyYAML`):

```bash
python -m pip install pytest pyyaml
pytest -v
```
