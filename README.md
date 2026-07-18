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
- Database security group and application security group.
- PostgreSQL ingress from the application security group to the database
  security group.
- Terraform outputs for VPC, subnet, NAT Gateway, S3 endpoint, DB subnet group,
  and security group IDs.

Not started yet:

- IAM, KMS, ECR, SQS/DLQ, Secrets Manager
- RDS PostgreSQL
- EKS and add-ons
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
│   ├── 01-current-progress.md
│   ├── 02-terraform-backend-notes.md
│   ├── 03-networking-deep-dive.md
│   ├── 04-interview-cheatsheet.md
│   └── 05-rds-networking-notes.md
├── infra/
│   ├── envs/dev/
│   │   └── Dev environment root module
│   └── modules/
│       ├── networking/
│       │   └── Reusable networking module
│       └── rds/
│           └── RDS networking and security preparation module
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

The lab currently has a NAT Gateway. NAT Gateway has hourly and data-processing
cost. Keep the lab moving and tear down by the target date in
`PROJECT_MASTER_PLAN.md`.

## Learning Notes

Start with:

- [Current Progress](docs/01-current-progress.md)
- [Terraform Backend Notes](docs/02-terraform-backend-notes.md)
- [Networking Deep Dive](docs/03-networking-deep-dive.md)
- [Interview Cheatsheet](docs/04-interview-cheatsheet.md)
- [RDS Networking Notes](docs/05-rds-networking-notes.md)
