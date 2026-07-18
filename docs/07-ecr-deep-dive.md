# ECR Deep Dive

Last updated: 2026-07-18

## Sleepy Revision Path

If you are revising quickly, read these sections first:

1. `What ECR Is`
2. `One-Minute Mental Model`
3. `Why One Repository Per Service`
4. `Why We Used for_each`
5. `What Tag Immutability Means`
6. `What Scan On Push Means`
7. `Common ECR Production Issues`

Core story:

```text
Code becomes a Docker image.
That image needs a private registry.
ECR is that registry in AWS.
CI pushes images there.
EKS later pulls images from there.
```

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

## One-Minute Mental Model

Think of ECR as a private warehouse for container images.

```text
source code = recipe
docker build = making the packaged product
container image = packaged product
ECR = private warehouse
EKS = place where the product is used
```

Flow:

```text
developer pushes code
CI builds Docker image
CI pushes image to ECR
Kubernetes pulls image from ECR
pods start from that image
```

## What ECR Is

ECR means Elastic Container Registry.

It is AWS's managed private container image registry.

In simple words:

```text
it is where our Docker images live before the cluster pulls them
```

Without ECR, we would have nowhere AWS-native and private to store the images
our workloads need.

## Why One Repository Per Service

We created separate repositories for:

- `api`
- `worker`
- `notifications`
- `frontend`

Why this is better than one giant shared repository:

- each service has its own image history
- lifecycle policies stay cleaner
- future permissions can be scoped better
- operational debugging is easier

## Why We Used `for_each`

The module uses:

```hcl
for_each = local.repositories
```

This creates one repository per service name.

Input:

```hcl
ecr_repository_names = [
  "api",
  "worker",
  "notifications",
  "frontend"
]
```

Terraform addresses:

```text
aws_ecr_repository.this["api"]
aws_ecr_repository.this["worker"]
aws_ecr_repository.this["notifications"]
aws_ecr_repository.this["frontend"]
```

Why `for_each` is better than `count` here:

- repository identity is based on service name
- list order changes are less risky
- resource addresses are easier to understand

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

If that tag already exists, a different image cannot silently replace it.

Why that matters:

Bad scenario:

```text
Monday: v1.0.0 points to image A
Tuesday: v1.0.0 is overwritten and now points to image B
```

Now rollback and audit become confusing.

## What Scan On Push Means

We enabled:

```hcl
scan_on_push = true
```

This asks ECR to scan images for known vulnerabilities when they are pushed.

Important nuance:

```text
scan on push does not automatically fix vulnerabilities
```

It only reports findings. Teams still need policy and action.

Typical production follow-up:

- block prod deployment for critical findings
- allow dev but create a security ticket
- rebuild base images
- review the vulnerable package chain

## Why Lifecycle Policies Matter

Every CI run can create another image.

Example:

```text
api:sha-1111111
api:sha-2222222
api:sha-3333333
api:sha-4444444
```

If old images are never cleaned up:

- storage grows
- repositories get messy
- rollback hygiene becomes poor

Our lifecycle policy does two important things:

- expire old untagged images
- keep only a limited number of tagged images

This is both:

- a cost control
- an operational hygiene control

## Root Outputs And Why They Matter

The dev root exposes:

```text
ecr_repository_names
ecr_repository_urls
ecr_repository_arns
```

Most important for CI:

```text
ecr_repository_urls
```

Future example:

```text
923988301700.dkr.ecr.us-east-1.amazonaws.com/releaseops-dev/api:sha-a1b2c3d
```

Why output both URL and ARN?

- URL is useful for pushing images
- ARN is useful for IAM policy scoping

## Terraform Walkthrough

Important module inputs:

- `name_prefix`
- `repository_names`
- `image_tag_mutability`
- `max_tagged_images`
- `untagged_image_expire_days`
- `force_delete`
- `tags`

Meaning:

`name_prefix`

Builds names like `releaseops-dev/api`.

`repository_names`

The service list that becomes one repository each.

`image_tag_mutability`

Controls whether tags may be overwritten.

`max_tagged_images`

How many tagged images we keep.

`untagged_image_expire_days`

How fast untagged images are cleaned up.

`force_delete`

Allows easier teardown in this lab even if images still exist.

## Common ECR Production Issues

### Image Push Fails

Possible causes:

- CI role lacks ECR permission
- Docker login to ECR missing
- repository URL is wrong
- immutable tag already exists

Debug path:

1. Check CI role permissions.
2. Check login/auth step.
3. Check repository URL.
4. Check whether the tag already exists.

### Pod Cannot Pull Image

Possible causes:

- node or pod role lacks ECR read permission
- private subnet cannot reach required AWS endpoints
- image tag does not exist
- image reference in Kubernetes is wrong

Debug path:

1. `kubectl describe pod`
2. check for `ErrImagePull` or `ImagePullBackOff`
3. verify image exists in ECR
4. verify IAM
5. verify network path

### Image Storage Cost Grows

Possible causes:

- no lifecycle policy
- too many SHA images retained
- untagged images never cleaned up

Fix path:

1. add lifecycle rules
2. align retention with rollback needs
3. remove stale image buildup

## Interview Questions To Practice

### What is ECR?

AWS's managed private container image registry.

### Why not only use DockerHub?

Because ECR integrates more naturally with IAM, EKS, CloudTrail, and AWS
networking for private workloads.

### Why immutable tags?

To prevent silent overwrites and make deployments traceable and rollback-safe.

### Why lifecycle policy?

To control storage growth and keep repositories clean without losing the most
important recent images.

### Why `for_each` instead of `count`?

Because repositories are named resources and `for_each` keeps stable addresses
based on service names.

## Speakable Interview Answers

- "ECR is the private registry where CI pushes container images before EKS
  pulls them."
- "Each service gets its own repository so history, retention, and permissions
  stay clean."
- "I enabled immutable tags because a deployed tag should always map to the same
  artifact."
- "I enabled scan on push for early vulnerability visibility, but scanning alone
  is not enough without a response policy."
- "I added lifecycle rules because image storage grows quietly in active CI/CD
  systems."

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
