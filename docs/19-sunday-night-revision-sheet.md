# Sunday Night Revision Sheet

Use this as the final fast pass before Monday.

## Tell Me About The Project

> I built ReleaseOps, a production-shaped EKS platform for release-management
> workflows. Terraform provisions AWS infrastructure: VPC, public/private/
> database subnets, NAT, S3 endpoint, RDS PostgreSQL, ECR, SQS with DLQ, IAM
> OIDC for GitHub Actions, and EKS. Kubernetes handles the workload layer with
> namespaces, service accounts, quotas, limits, Helm packaging, and GitOps
> references through Argo CD. I also documented troubleshooting, cost controls,
> and cleanup.

## Strongest Technical Points

- private RDS in database subnets
- pods connect through private networking, not public DB exposure
- GitHub Actions OIDC instead of static AWS keys
- EKS add-on troubleshooting with EBS CSI and Pod Identity
- SQS plus DLQ for resilient async processing
- ECR immutable tags and lifecycle cleanup
- Helm chart with probes, resources, HPA, PDB, NetworkPolicy
- Terraform plan guard with Python

## Three Real Troubleshooting Stories

1. EKS add-on timeout
   EBS CSI add-on timed out because it needed AWS permissions. Fixed with EKS
   Pod Identity role and association.

2. Terraform module not installed
   After adding a module, Terraform plan failed until `terraform init` was run
   again. This taught that module installation is part of init.

3. Output-only Terraform change
   Terraform sometimes shows only output changes. That updates state outputs
   but does not change real infrastructure.

## Banking Client Framing

Say:

- controlled delivery
- audit trail
- least privilege
- immutable artifacts
- environment approvals
- disaster recovery thinking
- cost awareness
- operational readiness

Avoid:

- "I just deployed an app"
- "I used admin access everywhere"
- "I would manually fix production and later update Git"

## Five Questions To Practice

1. Why RDS outside Kubernetes instead of StatefulSet?
2. How does GitHub Actions access AWS without access keys?
3. What happens when an SQS worker crashes halfway?
4. How do you debug a pod that cannot connect to RDS?
5. What is the difference between Terraform drift and Argo CD drift?
