# ReleaseOps Platform Lab - Status

Last updated: 2026-07-18  
Master plan: `PROJECT_MASTER_PLAN.md`  
Target teardown complete: 2026-07-26

## Current State

Completed:

- Terraform backend bootstrap applied.
- S3 state bucket exists with versioning, encryption, and public access block.
- DynamoDB lock table exists as a legacy-locking learning artifact.
- Main dev root uses the S3 backend with native lockfile support.
- Custom networking module created.
- VPC applied in `us-east-1`.
- Two public and two private subnets applied across `us-east-1a` and
  `us-east-1b`.
- Two isolated database subnets applied across `us-east-1a` and `us-east-1b`.
- Internet Gateway, public route table, private route table, and associations
  applied.
- Database route table and database subnet associations applied.
- One lab NAT Gateway applied for private application subnet outbound access.
- S3 Gateway VPC Endpoint applied for private application subnet S3 access.
- EKS and AWS Load Balancer Controller discovery tags applied to public and
  private application subnets.
- NAT and S3 endpoint outputs added.
- RDS module created and wired into the dev root.
- RDS DB subnet group applied using isolated database subnets.
- Database security group and application security group applied.
- PostgreSQL ingress rule applied from application security group to database
  security group on TCP `5432`.
- Root outputs added for DB subnet group and RDS/application security groups.
- KMS key and alias applied for database-related encryption.
- Secrets Manager secret and secret version applied for PostgreSQL credentials.
- Random PostgreSQL password generated and stored in Secrets Manager.
- Private encrypted PostgreSQL RDS instance applied.
- Safe root outputs added for database endpoint, port, name, secret ARN, and
  KMS key ARN.
- ECR module created and wired into the dev root.
- ECR repositories applied for `api`, `worker`, `notifications`, and
  `frontend`.
- ECR scan on push, immutable image tags, and lifecycle policies applied.
- Safe root outputs added for ECR repository names, URLs, and ARNs.

Observed identifiers from the latest verified terminal output:

- VPC: `vpc-047a19a79c5090ded`
- NAT Gateway: `nat-07705be2ac693339d`
- S3 Gateway VPC Endpoint: `vpce-06175a13cdaf34560`
- RDS identifier: `releaseops-dev-postgres`
- ECR repositories: `releaseops-dev/api`, `releaseops-dev/worker`,
  `releaseops-dev/notifications`, `releaseops-dev/frontend`
- State bucket: `releaseops-tan25-dev-tfstate`
- Legacy DynamoDB table: `releaseops-tan25-dev-tf-locks`

Do not treat these IDs as permanent. Verify live state before using them.

Not started:

- Terraform state-address refactor exercise
- IAM, SQS/DLQ
- EKS and add-ons
- Java application
- Docker images
- Helm and GitOps repository
- GitHub Actions pipelines
- Argo CD applications
- observability
- autoscaling and failure drills

## Exact Next Step

Resume inside:

```text
/Users/sayantanchowdhury/Documents/Codex/releaseops-platform-lab
```

Continue after **Networking Module Phase 2**:

1. Confirm `terraform plan` still shows no changes.
2. Add SQS deployment queue and DLQ.
3. Add IAM/OIDC preparation for GitHub Actions.
4. Continue toward EKS modules.

The guide must deliver this one small type-along block at a time.

## Immediate Verification Commands

Run these from `infra/envs/dev` before the next edit:

```bash
terraform fmt -check -recursive
terraform validate
terraform state list
terraform plan -detailed-exitcode
```

Interpret `terraform plan -detailed-exitcode` correctly:

- `0`: success, no changes
- `1`: error
- `2`: success, changes exist

Do not run `apply` until the plan has been reviewed.

## Current Cost Posture

At this status point, EKS, ALB, and worker nodes should not exist yet. NAT
Gateway, KMS, Secrets Manager, and RDS PostgreSQL do exist and have cost.
Verify live state before relying on this status.

The expensive-resource window starts no earlier than July 23 unless Tan reaches
the apply milestone sooner and is ready to continue without idle days.

## Locked Decisions

- Four Java services in one application monorepo
- One RDS PostgreSQL instance with four isolated schemas/users for the lab
- Three repositories: infrastructure, application, GitOps
- Terraform owns AWS; Argo CD owns Kubernetes desired state
- GitHub OIDC and EKS Pod Identity; no static AWS keys
- One NAT Gateway for lab; production comparison documented
- One shared ALB and existing domain
- SQS plus DLQ for approved deployment work
- Reusable Helm chart plus Argo CD ApplicationSet
- Prometheus/Grafana/Loki/Tempo/OpenTelemetry with short retention
- HPA plus a short Karpenter Spot scaling drill
- Full cleanup by July 26
- Daily model: GPT-5.6 Terra Medium when available; GPT-5.4 Medium fallback
- Escalation model: GPT-5.6 Sol High or GPT-5.5 High only for hard checkpoints

## Change Log

No changes to the locked plan.
