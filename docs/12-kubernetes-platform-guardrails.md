# Kubernetes Platform Guardrails

Last updated: 2026-07-21

## What We Built

We built the first Kubernetes-side platform layer by follow-along typing.

Folder:

```text
k8s/platform/base
```

Files:

```text
kustomization.yaml
namespaces.yaml
releaseops-serviceaccounts.yaml
releaseops-resourcequota.yaml
releaseops-limitrange.yaml
releaseops-default-deny.yaml
releaseops-support-rbac.yaml
```

Live objects verified in EKS:

```text
namespaces: releaseops, observability, argocd
service accounts: api, worker, notifications, frontend
ResourceQuota: releaseops-compute-quota
LimitRange: releaseops-default-container-limits
```

The default-deny policy, Pod Security Admission labels, and support RBAC were
added later as reference code. Verify live state before claiming they were
applied.

This step does not create new AWS paid resources like LoadBalancers, EBS
volumes, RDS instances, or EC2 nodes. These are Kubernetes API objects inside
the existing cluster.

## Why We Built This

An empty Kubernetes cluster is not ready for serious app deployment.

Before putting applications into the cluster, we want some basic structure:

```text
Where will apps live?
Which identity will each Pod use?
How much CPU/memory can the namespace consume?
What default CPU/memory should containers get?
```

This is the platform foundation before application deployment.

Interview version:

> Before deploying applications, I prepare Kubernetes guardrails: namespaces for
> separation, service accounts for workload identity, ResourceQuota for
> namespace-level budgets, and LimitRange for default/min/max container
> resources.

## Kustomize

File:

```text
k8s/platform/base/kustomization.yaml
```

Kustomize groups multiple Kubernetes YAML files together.

Our file:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespaces.yaml
  - releaseops-serviceaccounts.yaml
  - releaseops-resourcequota.yaml
  - releaseops-limitrange.yaml
```

`kubectl kustomize` only renders the final YAML:

```bash
kubectl kustomize k8s/platform/base
```

`kubectl apply -k` sends those objects to the cluster:

```bash
kubectl apply -k k8s/platform/base
```

Simple difference:

```text
kubectl kustomize = show me what will be applied
kubectl apply -k  = apply it to the cluster
```

Kustomize vs Helm:

```text
Kustomize = organize and patch plain YAML
Helm      = template and package configurable apps
```

For simple platform guardrails, Kustomize is enough. For our Java application
packaging later, Helm will be more useful.

## Namespaces

File:

```text
namespaces.yaml
```

Created namespaces:

```text
releaseops
observability
argocd
```

Meaning:

```text
releaseops    = future application workloads
observability = future monitoring/logging/tracing tools
argocd        = future Argo CD installation
```

A namespace is a logical boundary. It is not a hard security boundary by
itself.

It becomes useful when combined with:

```text
RBAC
ResourceQuota
LimitRange
NetworkPolicy
labels
admission policy
```

Interview line:

> A namespace gives logical separation inside a cluster. I do not treat it as a
> complete security boundary by itself, but with RBAC, ResourceQuota,
> LimitRange, and NetworkPolicy it becomes a useful operational boundary.

## Service Accounts

File:

```text
releaseops-serviceaccounts.yaml
```

Created service accounts in the `releaseops` namespace:

```text
api
worker
notifications
frontend
```

A ServiceAccount is the identity of a Pod inside Kubernetes.

Human example:

```text
Tan logs in with a user identity.
```

Pod example:

```text
api Pod runs as api ServiceAccount.
worker Pod runs as worker ServiceAccount.
```

Why not use only `default`?

Because later different workloads may need different permissions:

```text
api           -> app API permissions
worker        -> SQS consume permissions
notifications -> notification permissions
frontend      -> probably no AWS permissions
```

Interview line:

> I avoid running all workloads under the default service account. I create
> service accounts per workload so RBAC and cloud permissions can be scoped
> cleanly.

## ResourceQuota

File:

```text
releaseops-resourcequota.yaml
```

ResourceQuota is the total namespace budget.

Our quota:

```text
requests.cpu:    1500m
requests.memory: 2Gi
limits.cpu:      3
limits.memory:   4Gi
pods:            20
services:        10
secrets:         20
configmaps:      20
```

What this means:

```text
All Pods in releaseops together cannot request more than 1.5 CPU.
All Pods in releaseops together cannot request more than 2Gi memory.
The namespace cannot have more than 20 Pods.
```

This is useful in shared clusters because one app or team should not consume the
whole cluster by accident.

Common error:

```text
Forbidden: exceeded quota
```

That usually means the namespace budget has been reached.

Interview line:

> ResourceQuota controls total consumption at namespace level. It protects a
> shared cluster from one team or app consuming too many resources.

## LimitRange

File:

```text
releaseops-limitrange.yaml
```

LimitRange controls default/min/max resources per container.

Our settings:

```text
default request: 100m CPU, 128Mi memory
default limit:   500m CPU, 512Mi memory
min:             50m CPU, 64Mi memory
max:             1 CPU, 1Gi memory
```

Request means:

```text
The amount Kubernetes scheduler reserves for the container.
```

Limit means:

```text
The maximum amount the container is allowed to use.
```

Why this matters:

```text
requests too high  -> Pod may stay Pending
limits too low     -> app may get OOMKilled or throttled
requests missing   -> poor scheduling and HPA problems
```

Interview line:

> Requests help the scheduler place Pods. Limits cap runtime usage. LimitRange
> gives safe defaults per container, while ResourceQuota caps total namespace
> usage.

## Pod Security Admission

The `releaseops` Namespace is labeled with the built-in `restricted` Pod
Security Standard:

```yaml
pod-security.kubernetes.io/enforce: restricted
pod-security.kubernetes.io/audit: restricted
pod-security.kubernetes.io/warn: restricted
```

- `enforce` rejects Pods that violate the profile.
- `audit` records violations in the audit event.
- `warn` returns a warning to the user.

This is admission-time security. It does not inspect runtime behavior and does
not replace RBAC, image scanning, NetworkPolicy, or container security controls.

Production gotcha:

Do not switch a busy namespace directly to `enforce` without checking existing
workloads. Start with audit/warn, correct violations, then enforce through a
controlled change.

## Default-Deny NetworkPolicy

The platform base defines:

```yaml
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

An empty selector chooses every Pod in the namespace. Because there are no
allow rules in this policy, selected Pods are denied by default in both
directions. Application charts must add explicit allow policies for DNS,
ingress, database access, and required external APIs.

NetworkPolicies are additive, so the application allow policy works alongside
the namespace default deny. The cluster network plugin must support policy
enforcement; merely creating the API object is not enough.

## Namespace Support RBAC

The support Role permits read-only troubleshooting inside `releaseops`:

```text
get/list/watch Pods, logs, events, Services, ConfigMaps,
Deployments, ReplicaSets, and HPAs
```

The RoleBinding grants that Role to the `releaseops-support` group. The group
must still be supplied by the cluster's user authentication integration.

This is intentionally namespace-scoped. A support engineer does not need
cluster-admin merely to inspect one application's Pods and logs.

## Verification Commands

Render local YAML:

```bash
kubectl kustomize k8s/platform/base
```

Apply to cluster:

```bash
kubectl apply -k k8s/platform/base
```

Check namespaces:

```bash
kubectl get namespaces releaseops observability argocd --show-labels
```

Check service accounts:

```bash
kubectl get serviceaccounts -n releaseops
```

Check quota:

```bash
kubectl describe resourcequota releaseops-compute-quota -n releaseops
```

Check limit range:

```bash
kubectl describe limitrange releaseops-default-container-limits -n releaseops
```

Check policy and RBAC:

```bash
kubectl get networkpolicy,role,rolebinding -n releaseops
kubectl auth can-i get pods -n releaseops \
  --as=example-support-user \
  --as-group=releaseops-support
```

## What We Learn From This Step

This step teaches a mature Kubernetes habit:

```text
Do not start with Deployments immediately.
Prepare the namespace, identity, and resource guardrails first.
```

Weak interview answer:

> I deploy my app using Deployment and Service.

Better interview answer:

> Before deploying the app, I prepare namespaces, service accounts, resource
> quotas, and limit ranges. Then I add RBAC, NetworkPolicy, app manifests, Helm,
> and GitOps.
