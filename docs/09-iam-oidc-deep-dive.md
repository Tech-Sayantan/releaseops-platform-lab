# IAM And GitHub OIDC Deep Dive

Last updated: 2026-07-19

## What We Built

We created the AWS identity layer that will later allow GitHub Actions to run
Terraform without storing long-lived AWS access keys in GitHub.

Current Terraform module:

```text
infra/modules/iam
```

Current root module call:

```text
infra/envs/dev/main.tf
```

Terraform resources created:

```text
module.github_oidc.aws_iam_openid_connect_provider.github
module.github_oidc.aws_iam_role.github_actions
module.github_oidc.aws_iam_policy.terraform_permissions
module.github_oidc.aws_iam_role_policy_attachment.terraform_permissions
```

Root outputs now expose:

```text
github_oidc_provider_arn
github_actions_role_name
github_actions_role_arn
github_actions_policy_arn
github_oidc_subject
```

The most important output for future CI/CD work is:

```text
github_actions_role_arn
```

GitHub Actions will use that role ARN to request temporary AWS credentials.

## The Problem This Solves

Without OIDC, many teams put AWS access keys into GitHub repository secrets:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

That works, but it is risky.

Why?

- The key is long-lived.
- If leaked, it can be abused until someone rotates it.
- People forget to rotate secrets.
- The same key may get reused across repos or environments.
- Auditing becomes harder because the credential is not tied cleanly to one
  workflow identity.

OIDC avoids this by replacing static keys with short-lived credentials.

The GitHub workflow asks AWS:

```text
I am this exact repository and branch. Can I assume this IAM role?
```

AWS checks the trust policy. If the request matches, AWS STS returns temporary
credentials.

## Mental Model

Use this picture:

```text
GitHub Actions workflow
        |
        | asks GitHub for an OIDC token
        v
GitHub OIDC token
        |
        | sent to AWS STS
        v
AWS IAM role trust policy checks:
  - Is the issuer GitHub?
  - Is the audience sts.amazonaws.com?
  - Is the subject this repo and branch?
        |
        v
Temporary AWS credentials
        |
        v
Terraform plan/apply in CI
```

In plain English:

- GitHub Actions is the worker trying to enter AWS.
- The OIDC token is its identity document.
- AWS IAM OIDC provider tells AWS to trust GitHub as an identity provider.
- The IAM role is the temporary AWS identity the workflow can borrow.
- The trust policy decides who is allowed to borrow the role.
- The permission policy decides what the role can do after it is borrowed.

## IAM OIDC Provider

Terraform resource:

```text
aws_iam_openid_connect_provider.github
```

This tells AWS:

```text
GitHub is an external identity provider that I am willing to recognize.
```

Provider URL:

```text
https://token.actions.githubusercontent.com
```

This is the issuer URL for GitHub Actions OIDC tokens.

Client ID:

```text
sts.amazonaws.com
```

This means the token is intended to be used with AWS STS.

Interview version:

> I configured an IAM OIDC provider for GitHub Actions so workflows can use
> federated identity instead of static AWS keys.

## IAM Role

Terraform resource:

```text
aws_iam_role.github_actions
```

Role name:

```text
releaseops-dev-github-actions-terraform
```

This role is what GitHub Actions will assume when it needs to manage AWS
infrastructure.

Important point:

An IAM role by itself does nothing useful until two things are attached:

- a trust policy
- a permission policy

## Trust Policy

Terraform data source:

```text
data.aws_iam_policy_document.github_actions_assume_role
```

This builds the role's trust policy.

The trust policy answers:

```text
Who is allowed to assume this role?
```

In our lab, the trusted identity is:

```text
repo:Tech-Sayantan/releaseops-platform-lab:ref:refs/heads/main
```

That means:

- repository owner: `Tech-Sayantan`
- repository name: `releaseops-platform-lab`
- branch: `main`

So a workflow from some random repository should not be able to assume this
role.

Important condition:

```text
token.actions.githubusercontent.com:aud = sts.amazonaws.com
```

This says the token must be intended for AWS STS.

Another important condition:

```text
token.actions.githubusercontent.com:sub =
repo:Tech-Sayantan/releaseops-platform-lab:ref:refs/heads/main
```

This restricts access to one repo and one branch.

Interview version:

> The trust policy is scoped to the GitHub OIDC provider, the STS audience, and
> the exact repository/branch subject. That prevents arbitrary GitHub repos from
> assuming the role.

## Permission Policy

Terraform resource:

```text
aws_iam_policy.terraform_permissions
```

The permission policy answers:

```text
What can the role do after it is assumed?
```

For this lab, the role has broad permissions across services we are building:

- S3 and DynamoDB for Terraform backend/state locking behavior
- EC2/VPC for networking and EKS dependencies
- RDS for PostgreSQL
- ECR for container image repositories
- SQS for deployment queues
- EKS for Kubernetes cluster work
- IAM for future EKS/service-role work
- KMS and Secrets Manager for encryption and secrets
- ELB/Auto Scaling/CloudWatch/Logs for EKS and observability support

This is acceptable for a short-lived lab, but it is broader than a strict
production policy.

Production improvement:

- split plan and apply roles
- scope resources using ARNs where possible
- restrict IAM changes carefully
- use branch/environment based trust controls
- require GitHub Environment approvals before apply
- use policy boundaries or permission boundaries in stronger organizations

Interview version:

> For the lab I used a broad Terraform execution role so we can move quickly
> across services. In production I would reduce blast radius with separate
> roles, tighter resource ARNs, branch/environment restrictions, and approval
> gates for apply.

## Role Policy Attachment

Terraform resource:

```text
aws_iam_role_policy_attachment.terraform_permissions
```

This attaches the permission policy to the IAM role.

Think of it like this:

```text
IAM role = identity
IAM policy = allowed actions
attachment = connect identity to permissions
```

Without the attachment, the role can exist and even be assumable, but it would
not have the intended permissions.

## Why We Use Outputs

The IAM module exposes internal values:

```text
oidc_provider_arn
github_actions_role_name
github_actions_role_arn
github_actions_policy_arn
github_subject
```

The dev root re-exposes selected values:

```text
github_oidc_provider_arn
github_actions_role_name
github_actions_role_arn
github_actions_policy_arn
github_oidc_subject
```

This is the Terraform module pattern:

```text
child module creates resources
child module outputs useful values
root module calls child module
root module outputs values humans or automation need
```

We will later copy `github_actions_role_arn` into the GitHub Actions workflow.

## Why This Is Production-Shaped

This is production-shaped because it avoids a common bad practice:

```text
storing permanent AWS keys in GitHub
```

Instead, it uses:

```text
federated identity + short-lived credentials + scoped trust
```

That is the modern CI/CD pattern.

For an interview, say:

> I prefer GitHub Actions OIDC over static AWS keys. The workflow receives a
> short-lived OIDC token from GitHub, AWS validates the issuer, audience, and
> subject, and then STS issues temporary credentials for a tightly scoped IAM
> role.

## Common Issues And Fixes

### Terraform Says Module Not Installed

Symptom:

```text
Error: Module not installed
```

Cause:

You added or changed a module block, but did not run:

```bash
terraform init
```

Fix:

```bash
cd /Users/sayantanchowdhury/Documents/Codex/releaseops-platform-lab/infra/envs/dev
terraform init
```

### Unsupported Argument In Module

Symptom:

```text
Error: Unsupported argument
```

Cause:

The root module passed an argument that the child module does not declare in
its `variables.tf`, or the root module is pointing to the wrong source folder.

In our lab this happened because the root was trying to call:

```text
../../modules/github_oidc
```

But the real module folder was:

```text
../../modules/iam
```

Fix:

```hcl
module "github_oidc" {
  source = "../../modules/iam"
}
```

Then rerun:

```bash
terraform init
terraform validate
```

### Duplicate Output Definition

Symptom:

```text
Error: Duplicate output definition
```

Cause:

Two output blocks in the same module have the same name.

In our lab, root outputs were accidentally pasted into the child IAM module.

Fix:

- keep child module outputs in `infra/modules/iam/outputs.tf`
- keep root environment outputs in `infra/envs/dev/outputs.tf`

Remember:

```text
Child module outputs expose child values to root.
Root outputs expose final values outside Terraform.
```

### GitHub Actions Fails To Assume Role

Possible causes:

- wrong repository name in `github_repository`
- wrong branch in `github_branch`
- workflow missing `id-token: write`
- role ARN copied incorrectly
- trust policy subject does not match the workflow source

Future workflow requirement:

```yaml
permissions:
  id-token: write
  contents: read
```

Without `id-token: write`, GitHub cannot request the OIDC token.

## Verification Commands

Run from:

```text
/Users/sayantanchowdhury/Documents/Codex/releaseops-platform-lab/infra/envs/dev
```

Check IAM/OIDC state:

```bash
terraform state list | grep -E "github_oidc|iam"
```

Check outputs:

```bash
terraform output | grep -E "github|oidc"
```

Check drift:

```bash
terraform plan
```

Expected result after apply:

```text
No changes. Your infrastructure matches the configuration.
```

## Final Interview Story

Use this version:

> In this project, I configured GitHub Actions to access AWS using OIDC instead
> of static access keys. Terraform created an IAM OIDC provider for GitHub, an
> IAM role for the infrastructure pipeline, a trust policy restricted to the
> exact repository and branch, and a permission policy for Terraform-managed
> AWS resources. This gives the pipeline temporary credentials through STS and
> reduces the risk of long-lived credential leakage.

