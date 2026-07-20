# Kubernetes Platform Guardrails

Last updated: 2026-07-20

## What We Added

We added the first Kubernetes-side platform layer under:

```text
k8s/platform/base
```

This layer contains:

```text
namespaces
service accounts
resource quota
limit range
kustomization
```

No new AWS paid resource is created by these manifests. These are Kubernetes API
objects stored in the cluster.

These manifests were applied to the live EKS cluster and verified with
`kubectl`.

## Why This Is Not Terraform

Terraform owns AWS infrastructure in this lab:

```text
VPC, RDS, ECR, SQS, IAM, EKS
```

Kubernetes YAML owns Kubernetes objects:

```text
Namespace, ServiceAccount, Deployment, Service, Ingress, NetworkPolicy
```

Later, Argo CD will continuously apply the Kubernetes YAML from Git. That is the
GitOps model.

Interview version:

> Terraform provisions the platform infrastructure, while Argo CD owns
> Kubernetes desired state. I avoid making both tools manage the same object
> because that creates ownership conflicts.

## Namespaces

We created:

```text
releaseops
observability
argocd
```

A namespace is a logical boundary inside a Kubernetes cluster.

It is not a hard security boundary by itself. It becomes useful when combined
with:

```text
RBAC
ResourceQuota
LimitRange
NetworkPolicy
labels
admission policy
```

Simple mental model:

```text
Cluster = office building
Namespace = department floor
RBAC = who can enter rooms
ResourceQuota = department budget
NetworkPolicy = who can talk to whom
```

## Service Accounts

We created one service account per future application service:

```text
api
worker
notifications
frontend
```

A service account is the identity of a Pod inside Kubernetes.

This matters because later we can say:

```text
The api Pod runs as the api service account.
The worker Pod runs as the worker service account.
Only the workload that needs AWS permissions gets AWS permissions.
```

In production, avoid running everything as the default service account.

Interview version:

> A Kubernetes service account gives an identity to a workload inside the
> cluster. I use separate service accounts per application component so RBAC and
> cloud permissions can be scoped per workload.

## ResourceQuota

ResourceQuota limits total usage inside a namespace.

Our lab quota says the `releaseops` namespace can use up to:

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

This protects the small lab node from accidental overload.

Production version:

> ResourceQuota helps prevent one team or namespace from consuming the whole
> cluster. It is especially useful in shared clusters where multiple teams
> deploy workloads.

## LimitRange

LimitRange defines default and allowed resource values for containers.

Our defaults:

```text
default request: 100m CPU, 128Mi memory
default limit:   500m CPU, 512Mi memory
min:             50m CPU, 64Mi memory
max:             1 CPU, 1Gi memory
```

This means if a container forgets to specify resources, Kubernetes will still
apply a default request and limit.

Why this matters:

- scheduler needs requests to place Pods correctly
- limits prevent runaway containers from consuming too much CPU/memory
- HPA works better when requests are defined
- production clusters become unstable when resource sizing is random

Interview version:

> Requests are used by the scheduler for placement. Limits cap runtime usage.
> LimitRange gives safe defaults, while ResourceQuota caps the total namespace
> consumption.

## Common Production Issue

Problem:

```text
Pods are Pending.
```

Possible causes:

- namespace ResourceQuota is exhausted
- container requests are too high for available nodes
- node selectors or taints do not match
- PVC is waiting for storage
- image pull failure is being mistaken for scheduling failure

Good troubleshooting commands:

```bash
kubectl describe pod <pod-name> -n releaseops
kubectl describe quota -n releaseops
kubectl describe limitrange -n releaseops
kubectl get events -n releaseops --sort-by=.lastTimestamp
```

## Verification We Ran

Namespaces:

```bash
kubectl get namespaces releaseops observability argocd --show-labels
```

Service accounts:

```bash
kubectl get serviceaccounts -n releaseops
```

Resource quota:

```bash
kubectl describe resourcequota releaseops-compute-quota -n releaseops
```

Limit range:

```bash
kubectl describe limitrange releaseops-default-container-limits -n releaseops
```

## What We Did Not Add Yet

We did not add NetworkPolicy yet.

Reason:

NetworkPolicy enforcement depends on the cluster network implementation. AWS VPC
CNI can support Kubernetes NetworkPolicy, but it must be configured correctly.
We will add it deliberately, not casually, so we can explain what is enforcing
the policy.

That is an important senior-level point:

> A NetworkPolicy YAML file is only useful if the cluster has a network plugin
> that enforces NetworkPolicy.
