# Terraform Backend Notes

## Why We Created A Backend First

Terraform stores a map of what it created in a state file. Without remote state,
that file sits locally, for example:

```text
terraform.tfstate
```

Local state is okay for very small solo experiments, but it is risky for real
work:

- it can be lost
- it can be accidentally committed
- teammates cannot share it safely
- concurrent applies can corrupt or conflict with state

So we created a backend first.

## What The Backend Contains

The backend bootstrap created:

- an S3 bucket for Terraform state
- versioning on the bucket
- server-side encryption
- public access block
- a DynamoDB table as a legacy locking learning artifact

The main dev root uses an S3 backend with native lockfile support:

```hcl
terraform {
  backend "s3" {
    bucket       = "releaseops-tan25-dev-tfstate"
    key          = "infra/envs/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

## Important Concept: Bootstrap State

There is a chicken-and-egg problem:

> Terraform backend resources must exist before Terraform can use them as a
> backend.

So the backend bootstrap has its own local state at first. After that, the main
infra uses the remote backend.

This is common in real teams. Some teams manage the bootstrap manually. Some use
a small separate Terraform project. Some use organization-wide landing-zone
automation.

## State Locking

State locking prevents two Terraform operations from modifying the same state at
the same time.

Example problem without locking:

```text
Engineer A runs terraform apply
Engineer B runs terraform apply at the same time
Both think they own the truth
State can become inconsistent
```

With locking, Terraform says:

```text
Acquiring state lock...
```

Only one operation can proceed.

## Why DynamoDB Still Appears In The Lab

Older Terraform S3 backend patterns used DynamoDB for locking. Newer S3 backend
support includes native lockfile support. We keep the DynamoDB table as a
learning artifact so we can explain both old and current patterns in
interviews.

Interview phrasing:

> "Historically I used S3 plus DynamoDB for remote state and locking. In newer
> Terraform versions, S3 native lockfile support can be used. The important
> principle is that state must be remote, encrypted, versioned, and protected
> from concurrent writes."

## Output-Only Apply

We added outputs such as:

```hcl
output "database_subnet_ids" {
  value = module.networking.database_subnet_ids
}
```

Terraform may ask for an apply even when no AWS resources change:

```text
Plan: 0 to add, 0 to change, 0 to destroy.
```

That can still be real because outputs are stored in state. Adding an output
updates Terraform's state metadata, not AWS infrastructure.

Interview phrasing:

> "Outputs are part of state. Adding or changing outputs can require an apply
> even when no remote infrastructure changes."

