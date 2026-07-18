# ECR Deep Dive

Last updated: 2026-07-18

## What We Built

We created a reusable Terraform module for Amazon ECR and called it from the
dev environment root.

Current repositories:

```text
releaseops-dev/api
releaseops-dev/worker
releaseops-dev/notifications
releaseops-dev/frontend
```

Each repository has:

- scan on push enabled
- tag immutability enabled
- AES256 encryption
- common tags
- an ECR lifecycle policy

Terraform resources:

```text
module.ecr.aws_ecr_repository.this["api"]
module.ecr.aws_ecr_repository.this["worker"]
module.ecr.aws_ecr_repository.this["notifications"]
module.ecr.aws_ecr_repository.this["frontend"]

module.ecr.aws_ecr_lifecycle_policy.this["api"]
module.ecr.aws_ecr_lifecycle_policy.this["worker"]
module.ecr.aws_ecr_lifecycle_policy.this["notifications"]
module.ecr.aws_ecr_lifecycle_policy.this["frontend"]
```

## What ECR Is

ECR means Elastic Container Registry.

It is AWS's managed private container image registry. In simple words, it is
where our Docker images will live before EKS pulls them.

The future release flow will look like this:

```text
Developer pushes code
GitHub Actions builds Docker image
GitHub Actions pushes image to ECR
EKS pulls image from ECR
Argo CD deploys the Kubernetes workload
```

Without ECR, we would have nowhere private and AWS-native to store the images
that our Kubernetes cluster needs to run.

## Why One Repository Per Service

We created separate repositories for each service:

- `api`
- `worker`
- `notifications`
- `frontend`

This is a realistic production pattern because each service has a separate
image history and release lifecycle.

If every service used one shared repository, image management would become
messy. It would be harder to see which image belongs to which service, harder
to apply lifecycle rules cleanly, and harder to scope future permissions.

Interview line:

> I usually prefer one ECR repository per deployable service because it keeps
> image history, lifecycle policy, scanning, and access control cleaner.

## Why We Used `for_each`

The ECR module uses:

```hcl
for_each = local.repositories
```

This creates one resource per repository name.

With input:

```hcl
ecr_repository_names = [
  "api",
  "worker",
  "notifications",
  "frontend"
]
```

Terraform creates stable addresses:

```text
aws_ecr_repository.this["api"]
aws_ecr_repository.this["worker"]
aws_ecr_repository.this["notifications"]
aws_ecr_repository.this["frontend"]
```

This is better than `count` for named resources.

With `count`, Terraform addresses resources by number:

```text
aws_ecr_repository.this[0]
aws_ecr_repository.this[1]
```

That can become risky if you reorder the list. With `for_each`, the resource
identity is tied to the service name, not its position in the list.

Interview gotcha:

> For stable named infrastructure like repositories, queues, IAM users, or
> service-specific resources, `for_each` is usually safer than `count`.

## What Tag Immutability Means

We set:

```hcl
image_tag_mutability = "IMMUTABLE"
```

This means an existing image tag cannot be overwritten.

Example:

```text
releaseops-dev/api:v1.0.0
```

If this tag already exists, nobody can push a different image with the same
tag.

This matters because mutable image tags can create confusing production
incidents.

Bad situation:

```text
Monday: api:v1.0.0 points to image A
Tuesday: api:v1.0.0 gets overwritten and points to image B
```

Now rollback, debugging, and audit become painful because the same tag no
longer means the same artifact.

Good pattern:

- use immutable version tags such as `v1.2.3`
- use Git SHA tags such as `sha-a1b2c3d`
- avoid relying only on `latest`

Interview line:

> I prefer immutable image tags because a deployed tag should always point to
> the same image digest. It makes rollback and incident debugging safer.

## What Scan On Push Means

We enabled:

```hcl
scan_on_push = true
```

This asks ECR to scan images when they are pushed.

The goal is to detect known vulnerabilities in container images. For example,
if a base image contains a vulnerable OpenSSL or Linux package, the scan can
surface that.

Production gotcha:

Scanning does not automatically make images safe. It only reports findings.
Teams still need a policy for what happens when critical vulnerabilities are
found.

Example production rules:

- block deployment if critical vulnerabilities exist
- allow dev deployments but block prod
- require base image rebuild
- create security tickets automatically

## Why Lifecycle Policies Matter

Every CI run can push a new image.

Example:

```text
api:sha-1111111
api:sha-2222222
api:sha-3333333
api:sha-4444444
```

If old images are never deleted, ECR storage grows forever.

Our lifecycle policy does two things:

- expires untagged images after a few days
- keeps only a limited number of tagged images for known tag prefixes

This is a cost and hygiene control.

Interview line:

> I add ECR lifecycle policies early because image storage can quietly grow
> over time, especially in active CI/CD systems.

## What The Root Outputs Give Us

The dev root now exposes:

```text
ecr_repository_names
ecr_repository_urls
ecr_repository_arns
```

The most important one for CI is:

```text
ecr_repository_urls
```

GitHub Actions will later use these URLs as Docker push destinations.

Example future push target:

```text
923988301700.dkr.ecr.us-east-1.amazonaws.com/releaseops-dev/api:sha-a1b2c3d
```

## Common ECR Production Issues

### Image Push Fails

Common causes:

- GitHub Actions role does not have ECR permissions
- Docker login to ECR was not performed
- repository name is wrong
- image tag already exists and tag immutability blocks overwrite

Fix path:

1. Check the CI role permissions.
2. Check `aws ecr get-login-password`.
3. Check the repository URL.
4. Check whether the tag already exists.

### Pod Cannot Pull Image From ECR

Common causes:

- EKS node role lacks ECR read permission
- private subnet cannot reach ECR API
- NAT Gateway or VPC endpoints are missing
- image tag does not exist
- Kubernetes image name is wrong

Fix path:

1. Check pod events with `kubectl describe pod`.
2. Look for `ImagePullBackOff` or `ErrImagePull`.
3. Verify the image exists in ECR.
4. Verify node or pod IAM permissions.
5. Verify private networking path to ECR.

### Old Images Increase Cost

Common causes:

- no lifecycle policy
- too many SHA images retained
- old branch images never cleaned up

Fix path:

1. Add lifecycle policy.
2. Keep enough images for rollback.
3. Delete untagged images quickly.
4. Align image retention with release policy.

## Interview Questions To Practice

### Why not use DockerHub?

DockerHub can work for public images, but ECR is better for private AWS
workloads because it integrates with IAM, EKS, CloudTrail, and AWS networking.

### Why immutable tags?

Immutable tags prevent accidental overwrites and make deployments traceable.
They help with rollback and audit.

### What is the difference between image tag and image digest?

An image tag is a human-friendly label.

Example:

```text
api:v1.2.0
```

An image digest is the content identity of the image.

Example:

```text
sha256:...
```

The digest is more exact. In production, some teams deploy by digest for the
strongest reproducibility.

### Why lifecycle policy?

To control storage cost and keep repositories clean while still retaining
enough images for rollback.

### Why `for_each` instead of `count`?

Because the repositories are named resources. `for_each` keeps stable resource
addresses based on service names.

## Verification Commands

Run from:

```text
/Users/sayantanchowdhury/Documents/Codex/releaseops-platform-lab/infra/envs/dev
```

```bash
terraform state list | grep ecr
terraform output ecr_repository_urls
terraform plan | grep "No changes"
```

Expected plan result:

```text
No changes. Your infrastructure matches the configuration.
```
