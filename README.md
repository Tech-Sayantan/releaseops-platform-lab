# ReleaseOps Platform Lab

ReleaseOps is a production-shaped DevOps interview lab. The target platform is
an AWS EKS-based release-management system with Terraform, RDS PostgreSQL,
Java/Spring Boot services, Docker, Helm, GitHub Actions, Argo CD, GitOps,
observability, autoscaling, troubleshooting drills, and a verified teardown.

This repository currently contains the Terraform backend bootstrap, the dev
environment root module, the custom networking module, and detailed study notes
for everything built so far.

## Current Build State

Completed:

- S3 remote state backend bucket with encryption, versioning, public access
  block, and native S3 lockfile support.
- DynamoDB table kept as a legacy state-locking learning artifact.
- Dev Terraform root configured with the S3 backend.
- Custom networking module.
- VPC in `us-east-1`.
- Two public subnets across two Availability Zones.
- Two private application subnets across two Availability Zones.
- Two isolated database subnets across two Availability Zones.
- Internet Gateway for public subnet internet routing.
- One lab NAT Gateway for private application subnet outbound access.
- Dedicated route tables for public, private application, and database subnets.
- S3 Gateway VPC Endpoint attached to the private application route table.
- EKS and AWS Load Balancer Controller discovery tags on public/private
  application subnets.
- RDS DB subnet group using the isolated database subnets.
- KMS key and alias for database-related encryption.
- Secrets Manager secret and secret version for PostgreSQL credentials.
- Private encrypted PostgreSQL RDS instance.
- Database security group and application security group.
- PostgreSQL ingress from the application security group to the database
  security group.
- Terraform outputs for VPC, subnet, NAT Gateway, S3 endpoint, DB subnet group,
  security group IDs, secret/KMS ARNs, and safe RDS connection metadata.
- ECR repositories for `api`, `worker`, `notifications`, and `frontend`.
- ECR image scan on push, immutable tags, and lifecycle cleanup policies.
- SQS deployment-events queue and dead-letter queue.
- SQS redrive policy for failed deployment messages.
- IAM OIDC provider for GitHub Actions.
- IAM role, policy, and attachment for future Terraform automation from GitHub
  Actions.
- Terraform outputs for the GitHub Actions OIDC provider, role, policy, and
  allowed subject.
- EKS cluster `releaseops-dev-eks` on Kubernetes `1.34`.
- EKS managed node group `releaseops-dev-default` with one `t3.small`
  On-Demand worker node.
- EKS public API endpoint restricted to the current `/32` lab IP, with private
  endpoint access also enabled.
- EKS managed add-ons for VPC CNI, CoreDNS, kube-proxy, EBS CSI, and EKS Pod
  Identity Agent.
- Dedicated EKS Pod Identity role and association for the EBS CSI controller.

Not started yet:

- Java services
- Docker images
- Helm charts
- GitHub Actions pipelines
- Argo CD GitOps
- Observability and autoscaling drills

## Repository Layout

```text
.
├── bootstrap/
│   └── Terraform used once to create the remote state backend
├── docs/
│   ├── 00-how-to-use-these-notes.md
│   ├── 01-current-progress.md
│   ├── 02-terraform-backend-notes.md
│   ├── 03-networking-deep-dive.md
│   ├── 04-interview-cheatsheet.md
│   ├── 05-rds-networking-notes.md
│   ├── 06-real-world-devops-tickets.md
│   ├── 07-ecr-deep-dive.md
│   ├── 08-sqs-dlq-deep-dive.md
│   ├── 09-iam-oidc-deep-dive.md
│   ├── 10-eks-foundation-deep-dive.md
│   └── 11-eks-addons-troubleshooting.md
├── infra/
│   ├── envs/dev/
│   │   └── Dev environment root module
│   └── modules/
│       ├── networking/
│       │   └── Reusable networking module
│       ├── ecr/
│       │   └── Reusable ECR module for service image repositories
│       ├── rds/
│       │   └── RDS networking and security preparation module
│       ├── iam/
│       │   └── GitHub Actions OIDC IAM module
│       ├── eks/
│       │   └── EKS cluster and managed node group module
│       └── sqs/
│           └── Reusable SQS plus DLQ module
├── PROJECT_MASTER_PLAN.md
├── PROJECT_STATUS.md
└── AGENTS.md
```

## How To Work From Here

Run Terraform from the dev environment root:

```bash
cd /Users/sayantanchowdhury/Documents/Codex/releaseops-platform-lab/infra/envs/dev
terraform fmt -recursive
terraform validate
terraform plan
```

Do not run `apply` casually. Review the plan first, especially for any
`destroy` or replacement action involving VPCs, subnets, route tables, NAT,
RDS, or EKS resources.

## Cost Warning

The lab currently has a NAT Gateway, customer-managed KMS key, Secrets Manager
secret, RDS PostgreSQL instance, EKS control plane, and one `t3.small` EKS
worker node. These are real paid AWS resources. Keep the lab moving and tear
down by the target date in `PROJECT_MASTER_PLAN.md`.

## Learning Notes

Start with:

- [How To Use These Notes](docs/00-how-to-use-these-notes.md)
- [Current Progress](docs/01-current-progress.md)
- [Terraform Backend Notes](docs/02-terraform-backend-notes.md)
- [Networking Deep Dive](docs/03-networking-deep-dive.md)
- [Interview Cheatsheet](docs/04-interview-cheatsheet.md)
- [RDS Networking Notes](docs/05-rds-networking-notes.md)
- [Real-World DevOps Tickets](docs/06-real-world-devops-tickets.md)
- [ECR Deep Dive](docs/07-ecr-deep-dive.md)
- [SQS And DLQ Deep Dive](docs/08-sqs-dlq-deep-dive.md)
- [IAM And GitHub OIDC Deep Dive](docs/09-iam-oidc-deep-dive.md)
- [EKS Foundation Deep Dive](docs/10-eks-foundation-deep-dive.md)
- [EKS Add-Ons And Troubleshooting](docs/11-eks-addons-troubleshooting.md)
