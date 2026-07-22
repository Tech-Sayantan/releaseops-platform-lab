# Observability And Autoscaling Reference

This part is reference design for the final interview story. The full stack is
not live-deployed in the lab to save time and cost, but the design is what a
production-shaped EKS platform should include.

## What Observability Means

Observability is not just logs.

It has three main signals:

- logs: what happened
- metrics: how much, how fast, how many
- traces: where time was spent across services

For ReleaseOps:

- logs show release requests, approvals, worker attempts, failures
- metrics show request rate, error rate, latency, queue depth, pod CPU/memory
- traces show request path across API, database, queue producer, and worker

## Recommended Stack

For a realistic EKS platform:

- Prometheus for metrics
- Grafana for dashboards
- Loki for logs
- Tempo or Jaeger for traces
- OpenTelemetry collector for telemetry pipeline
- CloudWatch for AWS-native metrics and logs

In a banking/client environment, the exact tools may differ, but the concepts
stay the same.

## Golden Signals

For APIs:

- latency
- traffic
- errors
- saturation

For workers:

- queue depth
- age of oldest message
- processing success/failure count
- DLQ message count
- retry count

For RDS:

- CPU
- connections
- free storage
- read/write latency
- deadlocks
- slow queries

For EKS:

- node CPU/memory
- pod restarts
- pending pods
- CoreDNS health
- node readiness
- HPA behavior

## ReleaseOps Dashboards

Dashboard 1: Platform Health

- node count
- node Ready status
- pod restarts by namespace
- pending pods
- kube-system pod health

Dashboard 2: Application Health

- request rate
- error rate
- p95 latency
- readiness failure count
- JVM memory

Dashboard 3: Deployment Pipeline

- successful deployments
- failed deployments
- SQS queue depth
- DLQ messages
- average deployment processing time

Dashboard 4: Cost And Capacity

- node CPU/memory utilization
- NAT data processing trend
- RDS utilization
- unused EBS volumes

## Alert Examples

Good alerts are actionable.

Examples:

- DLQ message count greater than zero for 5 minutes
- p95 API latency above threshold for 10 minutes
- RDS CPU above 80 percent for 15 minutes
- pod restart count increasing rapidly
- node NotReady for more than 5 minutes
- queue age of oldest message above expected processing SLA

Bad alerts:

- CPU briefly high for 30 seconds
- every warning log
- alerts with no runbook

Interview phrase:

> I prefer fewer actionable alerts over noisy alerting. Every production alert
> should have an owner, impact, threshold reason, and runbook.

## Autoscaling Layers

There are three different scaling levels.

### 1. Pod Scaling With HPA

HPA changes replica count.

It needs:

- Metrics Server or metrics provider
- resource requests
- target metric

Common CPU example:

```text
If average CPU utilization goes above 70 percent, increase replicas.
```

Gotcha:

If CPU requests are missing, CPU utilization math is weak or impossible.

### 2. Node Scaling With Cluster Autoscaler Or Karpenter

If HPA creates more pods but the cluster has no capacity, pods stay Pending.

Node autoscaling adds more worker capacity.

Cluster Autoscaler:

- scales existing node groups
- simpler mental model

Karpenter:

- provisions right-sized nodes dynamically
- more flexible
- powerful for Spot and mixed workloads

### 3. Database Scaling

RDS does not scale like pods.

Options:

- larger instance class
- storage autoscaling
- read replica for read-heavy workloads
- query/index optimization
- connection pooling

Gotcha:

Do not solve every DB issue by scaling compute. Slow queries, missing indexes,
and connection leaks are common.

## Failure Drill: Queue Backlog

Symptom:

- SQS queue depth rises
- deployment worker CPU is low
- API still accepts requests

Possible causes:

- worker replicas too low
- worker cannot authenticate to AWS
- downstream DB slow
- poison messages repeatedly fail
- visibility timeout too short

Fix path:

- inspect worker logs
- check DLQ
- check age of oldest message
- verify worker IAM
- scale worker if capacity-bound
- fix idempotency/retry logic

## Failure Drill: HPA Scales Pods But Latency Still High

Possible causes:

- DB bottleneck
- queue bottleneck
- JVM thread pool saturation
- external dependency slow
- node capacity pressure

Interview phrase:

> Scaling pods only helps if the application tier is the bottleneck. If RDS or
> an external dependency is saturated, HPA may add replicas but not fix latency.

## Production Gotchas

- Metrics without labels are hard to use.
- High-cardinality labels can overload metrics systems.
- Logs without correlation IDs are painful during incidents.
- Traces are most useful when service boundaries are instrumented consistently.
- Alert thresholds must match business impact, not random numbers.
- Autoscaling must be tested before traffic spikes, not during the incident.
