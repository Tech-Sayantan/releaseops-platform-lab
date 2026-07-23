# Scenario Drills And Gotchas

Use this file as mock interview practice. For each scenario, first answer in
your own words, then compare with the structure here.

For the full vendor-neutral Kubernetes diagnostic sequence and twenty detailed
failure scenarios, use `docs/23-kubernetes-troubleshooting-playbook.md`.

## Scenario 1: Pod Is Pending

Question:

> A deployment is created, but the pod stays Pending. How do you troubleshoot?

Answer structure:

1. Check the pod events.

```bash
kubectl describe pod <pod-name> -n releaseops
```

2. Check if it is scheduling or image related.

Common reasons:

- insufficient CPU or memory
- node selector or taint mismatch
- PVC waiting for storage
- image pull secret problem
- quota exceeded

3. Check nodes.

```bash
kubectl get nodes
kubectl describe node <node-name>
```

4. Check namespace quota.

```bash
kubectl describe resourcequota -n releaseops
```

Speakable answer:

> I start from `kubectl describe pod` because events usually tell me whether
> the problem is scheduler, image pull, storage, or quota. Then I check node
> capacity, namespace quota, and any constraints like taints or selectors.

## Scenario 2: Pod Is CrashLoopBackOff

This means Kubernetes started the container, but it exited repeatedly.

Commands:

```bash
kubectl logs <pod-name> -n releaseops --previous
kubectl describe pod <pod-name> -n releaseops
```

Likely causes:

- bad environment variable
- missing secret
- database connection failure
- app starts slower than probe timing
- JVM memory too low

Gotcha:

Readiness failure and CrashLoopBackOff are different. Readiness means the pod
is alive but not ready for traffic. CrashLoopBackOff means the process keeps
dying.

## Scenario 3: EKS Node Is Ready But Pods Cannot Reach RDS

Trace the path:

```text
Pod -> node ENI -> private subnet route table -> RDS security group -> RDS
```

Check:

- application security group is allowed into database security group
- RDS is in database subnets
- RDS is not public
- app uses correct endpoint and port
- DNS resolution works inside the pod
- NetworkPolicy is not blocking egress

Interview phrase:

> For RDS connectivity I do not only check Kubernetes. I check the full network
> path: pod, node, subnet routing, security groups, DNS, and database listener.

## Scenario 4: EBS CSI Add-On Times Out

This happened in the lab.

Root issue:

- The EBS CSI controller needed AWS permissions.
- The add-on existed, but its controller could not call required EC2 APIs.

Fix:

- create IAM role for the add-on
- associate it through EKS Pod Identity
- verify controller pods

Interview phrase:

> Installing an EKS add-on is not always enough. Some add-ons need AWS API
> permissions. For EBS CSI, the controller needs permissions to create and
> attach EBS volumes.

## Scenario 5: Terraform Wants To Replace RDS

First reaction:

Stop. Do not apply.

Check:

- What argument caused replacement?
- Is `deletion_protection` enabled in production?
- Is final snapshot configured?
- Is backup retention configured?
- Is this change intended?
- Can we change it without replacement?

Speakable answer:

> For stateful resources, replacement is a change-management event, not a
> routine apply. I would inspect the exact diff, confirm backup/snapshot
> posture, get approval, and plan rollback.

## Scenario 6: GitHub Actions OIDC Fails

Symptoms:

- `AccessDenied`
- `Not authorized to perform sts:AssumeRoleWithWebIdentity`

Check:

- workflow has `permissions: id-token: write`
- role trust policy has correct GitHub repo
- branch condition matches
- role ARN is correct
- AWS account and region are correct

Gotcha:

OIDC removes long-lived AWS keys, but it does not remove IAM design. You still
need least privilege and tight trust conditions.

## Scenario 7: SQS Message Processed Twice

This is normal. SQS standard queues are at-least-once delivery.

Design response:

- make worker idempotent
- store processed message ID or business key
- use visibility timeout
- use DLQ for repeated failures
- monitor age of oldest message

Speakable answer:

> I assume duplicate delivery can happen and design the consumer to be
> idempotent. SQS helps with retries, but the application must handle duplicate
> messages safely.

## Scenario 8: HPA Does Not Scale

Check:

- Metrics Server installed?
- Pods have CPU requests?
- HPA target configured?
- Load actually exists?

Gotcha:

HPA CPU utilization is calculated against CPU requests. If requests are
missing, CPU-based HPA cannot behave properly.

## Scenario 9: Argo CD Shows Healthy But App Is Broken

Argo CD knows Kubernetes desired state, not business correctness.

Check:

- pod logs
- readiness endpoint
- application metrics
- database connectivity
- dependency health

Interview phrase:

> GitOps sync status is not the same as application health. I use Argo CD for
> desired-state reconciliation, then observability for runtime behavior.

## Scenario 10: Cost Is Rising During Lab

Immediate expensive items:

- EKS control plane
- NAT Gateway
- RDS
- EC2 worker node
- EBS volumes
- Load balancer if created

Actions:

- scale node group down if pausing
- avoid PVC smoke tests unless needed
- avoid ALB until app exposure is required
- tear down on schedule

For this lab, cleanup is part of the project story.
