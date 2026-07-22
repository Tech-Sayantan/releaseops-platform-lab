# ReleaseOps Service Contracts

## `release-service`

Owns:

- releases
- versions
- artifact digest
- release lifecycle state

Typical endpoints:

```text
POST /releases
GET /releases/{id}
PATCH /releases/{id}/state
GET /releases?service=deployment-service&environment=dev
```

Production gotcha:

> Do not deploy mutable tags like `latest`. Store and deploy immutable artifact
> digests.

## `approval-service`

Owns:

- approval request
- approval decision
- approver
- policy result

Typical flow:

```text
API request -> approval row -> approved event -> SQS deployment queue
```

Production gotcha:

> Approval must be auditable. A failed deployment later should still show who
> approved what, when, and for which artifact digest.

## `deployment-service`

Owns:

- deployment job
- deployment status
- retry count
- rollback metadata

Consumes:

```text
releaseops-dev-deployment-events
```

Production gotcha:

> SQS delivery is at-least-once. The worker must be idempotent so duplicate
> messages do not create duplicate deployments.

## `incident-service`

Owns:

- incident record
- failed deployment link
- impact
- rollback action
- audit event

Production gotcha:

> Incident data must be append-friendly and searchable by release ID,
> deployment ID, trace ID, and timeframe.

