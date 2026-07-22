# ReleaseOps Application Reference

This folder is an interview-ready reference for the application layer that
would run on the EKS platform.

The lab infrastructure already created:

- EKS
- ECR repositories
- RDS PostgreSQL
- SQS and DLQ
- Kubernetes namespaces and service accounts

This application reference explains how the four services fit into that
platform.

## Services

| Service | Purpose | AWS/Kubernetes angle |
|---|---|---|
| `release-service` | Stores release metadata and artifact digest | REST API, PostgreSQL schema |
| `approval-service` | Records approval decisions | Calls release-service, publishes SQS message |
| `deployment-service` | Processes deployment jobs | SQS consumer, idempotency, retry/DLQ |
| `incident-service` | Records failed deployment and rollback metadata | Audit trail and incident workflow |

## Why This Is Not Hello World

The domain lets us discuss real platform concerns:

- database ownership
- async messaging
- SQS retries and DLQ
- idempotent workers
- readiness and liveness probes
- structured logs and trace IDs
- image build and ECR push
- Helm values per service
- GitOps promotion by image digest

## Maven Structure

In a full build, this would be a Maven multi-module project:

```text
pom.xml
services/
  release-service/
  approval-service/
  deployment-service/
  incident-service/
```

For the NatWest interview, the main thing is to explain the architecture,
pipeline, and production behavior, not to spend the final prep days coding CRUD.

## Speakable Interview Story

> I designed ReleaseOps as a compact release-management platform. It has four
> Java services, private PostgreSQL on RDS, SQS for approval-to-deployment
> handoff, ECR for immutable images, Helm for Kubernetes packaging, and Argo CD
> for GitOps delivery. The point was not only to deploy a service, but to show
> how infra, app delivery, observability, security, and troubleshooting fit
> together.

