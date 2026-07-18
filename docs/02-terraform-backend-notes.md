# Terraform Backend Notes

Last updated: 2026-07-18

## Sleepy Revision Path

If you are revising quickly, read these sections first:

1. `What A Terraform Backend Is`
2. `Why We Created The Backend First`
3. `What We Built In This Lab`
4. `State Locking`
5. `Common Production Issues`
6. `Interview Questions To Practice`

The main story is simple:

```text
Terraform needs a state file.
Local state is fragile for real work.
So we store state remotely in S3.
We protect it with encryption, versioning, and locking.
```

## One-Minute Mental Model

Imagine Terraform as an accountant.

AWS resources are the real-world assets. Terraform state is the accountant's
ledger. Without the ledger, Terraform forgets what it created and cannot safely
compare desired state with real state.

In our lab:

```text
AWS resources = the things we build
Terraform state = Terraform's memory
S3 bucket = remote place where that memory lives
Locking = only one person/process can write the memory at a time
```

## What A Terraform Backend Is

A Terraform backend is the place where Terraform stores state.

State is usually a file such as:

```text
terraform.tfstate
```

That file contains the mapping between:

- Terraform resource addresses
- real AWS resource IDs
- outputs
- metadata Terraform needs for future plans and applies

Without state, Terraform does not safely know what it already created.

## Why We Created The Backend First

Terraform state can be local or remote.

Local state is acceptable for very small solo experiments, but it has serious
problems for anything long-lived:

- the file can be lost
- the file can be accidentally committed
- another machine does not automatically have the same truth
- concurrent writes are dangerous
- secret values can sit on a laptop with weak controls

That is why real teams usually move state into a controlled remote backend.

## What We Built In This Lab

Our bootstrap step created:

- an S3 bucket for Terraform state
- bucket versioning
- server-side encryption
- public access block
- a DynamoDB table kept as a legacy locking learning artifact

The main dev root now uses an S3 backend:

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

Read this slowly:

`bucket`

The S3 bucket where state lives.

`key`

The logical path of the state object inside the bucket.

`region`

The AWS region where that bucket exists.

`encrypt = true`

The state object should be stored encrypted.

`use_lockfile = true`

Use S3-native locking support so concurrent writes are blocked.

## What The State File Actually Contains

The state file is not just a list of names.

It can contain:

- resource IDs
- output values
- dependency metadata
- provider metadata
- sometimes sensitive values

Important warning:

If Terraform generates or receives a secret value, that value may still exist
in state even if it is marked sensitive and hidden from normal output.

That is why state storage must be treated as sensitive infrastructure data.

## Why S3 Works Well For Terraform State

S3 is a common backend choice because it gives us:

- durability
- encryption
- access control
- versioning
- integration with AWS IAM

Versioning matters a lot. If someone accidentally overwrites or damages state,
older object versions may help recovery.

Interview line:

> I like S3 for Terraform state because it gives durable remote storage,
> encryption, versioning, and tight AWS IAM control.

## What The `key` Means

This part is easy to gloss over:

```hcl
key = "infra/envs/dev/terraform.tfstate"
```

The bucket can hold many state files. The `key` tells Terraform which state
object belongs to this environment.

Think of it like:

```text
bucket = filing cabinet
key    = exact folder path inside the cabinet
```

Real teams often use different keys for:

- `dev`
- `staging`
- `prod`
- separate Terraform projects

This separation matters because each environment should have its own state
history and blast radius.

## Bootstrap State Problem

There is a chicken-and-egg problem:

```text
Terraform backend resources must already exist
before Terraform can use them as a backend
```

That is why bootstrap is usually handled separately.

Common patterns in real teams:

- one small separate Terraform project for backend bootstrap
- manual one-time setup
- organization-level landing-zone automation

In our lab, the backend bootstrap was treated as its own small setup step.

## State Locking

State locking prevents two operations from modifying the same state at the same
time.

Without locking:

```text
Engineer A runs terraform apply
Engineer B runs terraform apply
Both try to update the same state
Result can become inconsistent or corrupted
```

With locking, Terraform does something like:

```text
Acquiring state lock...
```

Only one process should continue.

That is not just a convenience feature. It protects infrastructure correctness.

## Why DynamoDB Still Appears In This Lab

Historically, many AWS Terraform backends used:

```text
S3 for state
DynamoDB for locking
```

Newer Terraform backend support can use S3 native lockfile support instead.

We kept DynamoDB in the lab because it is still useful to understand both
patterns in interviews.

Interview line:

> Historically I used S3 plus DynamoDB for remote state and locking. In newer
> Terraform versions, S3 native lockfile support can also be used. The key
> principle is that state must be remote, protected, and safe from concurrent
> writes.

## Why Remote State Is A Security Topic Too

Many people treat backend setup like boring plumbing. It is not.

Terraform state often becomes one of the most sensitive files in the platform
because it may include:

- internal resource IDs
- network structure
- outputs
- secret-adjacent metadata
- sometimes actual generated secrets

That means backend setup is both:

- an operational concern
- a security concern

## Outputs And State

Outputs are stored in Terraform state too.

That is why Terraform can sometimes show:

```text
Plan: 0 to add, 0 to change, 0 to destroy.
```

and still require an apply if output metadata changed.

Example:

```hcl
output "database_subnet_ids" {
  value = module.networking.database_subnet_ids
}
```

AWS resources may not change, but state metadata changes.

Interview line:

> Outputs are part of Terraform state. So adding or changing outputs can require
> an apply even when no AWS infrastructure changes.

## File Locations In This Lab

Backend bootstrap work belongs conceptually to:

```text
bootstrap/
```

Main environment backend usage belongs to:

```text
infra/envs/dev/backend.tf
```

Important rule:

```text
bootstrap creates backend resources
infra/envs/dev uses backend resources
```

## Common Production Issues

### State Lock Stuck

Possible causes:

- someone cancelled an apply
- CI job crashed midway
- another Terraform process is genuinely still running

Safe response:

1. Check whether another real run is still active.
2. Identify owner and timestamp.
3. Only unlock when you are sure the lock is stale.

Interview line:

> I treat force-unlock as a cautious production action. I first confirm that no
> valid apply is still running, because concurrent writers are more dangerous
> than waiting a bit longer.

### Wrong Backend Key

Possible symptom:

```text
Terraform shows unexpected resources
or wants to recreate existing ones
```

Possible cause:

The environment is pointing at the wrong state key.

Fix path:

1. Check backend `bucket`.
2. Check backend `key`.
3. Check AWS account and region.
4. Confirm you are in the correct root module directory.

### State Contains Sensitive Data

Possible cause:

Terraform generated a password or managed secret material.

Fix path:

1. Restrict who can access backend storage.
2. Encrypt backend storage.
3. Avoid exposing secrets through outputs.
4. Consider whether some secrets should be injected outside Terraform in stricter environments.

## Interview Questions To Practice

### Why use remote state?

Because Terraform state is the source of truth for resource mapping. Remote
state allows shared, durable, encrypted, controlled access.

### Why is local state risky?

It can be lost, committed accidentally, or updated unsafely by multiple people
or machines.

### Why use locking?

To prevent concurrent writes to the same state, which can create inconsistent
or conflicting infrastructure.

### What is the bootstrap problem?

Terraform cannot use backend resources until they already exist, so backend
creation is often handled as a separate one-time step or a separate project.

### Does state contain secrets?

It can. Sensitive outputs may be hidden from display, but the underlying state
may still hold sensitive values or metadata.

## Speakable Interview Answers

- "Terraform state is the memory Terraform uses to map code to real resources."
- "Remote state is not only a team collaboration feature, it is also a safety
  and security feature."
- "I separate backend bootstrap from the main environment because Terraform
  cannot use a backend that does not exist yet."
- "Locking prevents two applies from both thinking they own the truth."
- "I treat state access like privileged infrastructure access, because state can
  reveal or contain sensitive platform information."

## Verification Commands

Useful checks from the environment root:

```bash
terraform init
terraform validate
terraform plan
terraform output
```

Useful mental check:

```text
am I in infra/envs/dev
or am I accidentally running Terraform from the wrong directory
```
