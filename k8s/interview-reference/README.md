# Kubernetes Interview Reference Manifests

These manifests cover important Kubernetes workload types that do not belong in
the reusable stateless-service Helm chart.

They are intentionally **not** connected by a `kustomization.yaml`. Do not run
`kubectl apply -f k8s/interview-reference/` as a bundle. Some examples contain
placeholder images, and the storage example can create a paid cloud volume when
used with a real CSI provisioner.

## What Is Real In ReleaseOps

| Resource | Where it belongs | ReleaseOps use |
|---|---|---|
| Deployment | Helm chart | Long-running stateless Java API and worker Pods |
| Service | Helm chart | Stable in-cluster address for HTTP services |
| ConfigMap | Helm chart | Non-secret Spring configuration |
| Secret reference | Helm chart | Database credentials materialized separately |
| HPA | Helm chart | Pod replica scaling |
| PDB | Helm chart | Protection during voluntary disruption |
| NetworkPolicy | Helm chart | Explicit ingress and egress rules |
| Ingress | Helm chart, disabled in the lab | External HTTP routing after a controller exists |
| Role and RoleBinding | `k8s/platform/base` | Namespace-scoped support access example |
| Job | This reference folder | One-time Flyway database migration |
| CronJob | This reference folder | Scheduled stale-release report |
| StatefulSet and PVC | This reference folder | Ordered stateful workload example; not the business database |
| DaemonSet | This reference folder | One telemetry agent per node |

## Why We Do Not Use Every Resource Everywhere

Production design starts with workload behavior, not with a checklist of object
kinds. ReleaseOps keeps business data in managed PostgreSQL on RDS, so running a
second PostgreSQL database as a StatefulSet would be artificial and less
reliable. The StatefulSet example exists to teach identity, ordering, and
persistent storage without changing that architecture decision.

Likewise, only node-level agents should use a DaemonSet. A Java API should use a
Deployment because it needs replicas, rolling updates, and replaceable Pods.

## Safe Local Checks

These commands parse and inspect files without sending them to a cluster:

```bash
kubectl create --dry-run=client --validate=false -f k8s/platform/base/releaseops-support-rbac.yaml -o yaml
kubectl create --dry-run=client --validate=false -f k8s/interview-reference/jobs.yaml -o yaml
kubectl create --dry-run=client --validate=false -f k8s/interview-reference/statefulset-storage.yaml -o yaml
kubectl create --dry-run=client --validate=false -f k8s/interview-reference/daemonset-telemetry.yaml -o yaml
```

Do not apply the storage or ingress examples to the live lab merely for study.
They can trigger cloud resources when the relevant controllers are installed.
