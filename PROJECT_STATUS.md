# ReleaseOps Platform Lab - Status

Last updated: 2026-07-20
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
- SQS module created and wired into the dev root.
- Deployment events SQS queue and DLQ applied.
- Redrive policy applied from the main deployment queue to the DLQ.
- Safe root outputs added for deployment queue and DLQ names, URLs, and ARNs.
- IAM OIDC provider for GitHub Actions applied.
- IAM role, policy, and role-policy attachment for future GitHub Actions
  Terraform automation applied.
- Safe root outputs added for GitHub OIDC provider, role, policy, and allowed
  subject.
- EKS module created and wired into the dev root.
- EKS cluster `releaseops-dev-eks` applied on Kubernetes `1.34`.
- EKS managed node group `releaseops-dev-default` applied with one `t3.small`
  On-Demand worker node.
- EKS public API endpoint restricted to `203.92.62.70/32`; private endpoint
  access is also enabled.
- Safe root outputs added for EKS cluster, endpoint, security group, roles, and
  node group.
- Local kubeconfig context `releaseops-dev-eks` added and `kubectl get nodes`
  verified one `Ready` node.
- EKS managed add-ons applied: VPC CNI, CoreDNS, kube-proxy, EBS CSI, and EKS
  Pod Identity Agent.
- EBS CSI controller recovered from `CrashLoopBackOff` by adding a dedicated
  EKS Pod Identity role and association.
- Terraform plan verified clean after the timeout recovery.
- Kubernetes platform guardrail manifests added, applied, and verified for
  namespaces, service accounts, ResourceQuota, and LimitRange.

Observed identifiers from the latest verified terminal output:

- VPC: `vpc-047a19a79c5090ded`
- NAT Gateway: `nat-07705be2ac693339d`
- S3 Gateway VPC Endpoint: `vpce-06175a13cdaf34560`
- RDS identifier: `releaseops-dev-postgres`
- ECR repositories: `releaseops-dev/api`, `releaseops-dev/worker`,
  `releaseops-dev/notifications`, `releaseops-dev/frontend`
- SQS queues: `releaseops-dev-deployment-events`,
  `releaseops-dev-deployment-events-dlq`
- GitHub Actions IAM role: `releaseops-dev-github-actions-terraform`
- GitHub OIDC subject:
  `repo:Tech-Sayantan/releaseops-platform-lab:ref:refs/heads/main`
- EKS cluster: `releaseops-dev-eks`
- EKS cluster status: `ACTIVE`
- EKS cluster version: `1.34`
- EKS cluster security group: `sg-0a81133fb056d7bf1`
- EKS node group: `releaseops-dev-default`
- EKS node group status: `ACTIVE`
- EKS worker node observed by Kubernetes: `ip-10-40-2-87.ec2.internal`
- EKS managed add-ons: `vpc-cni`, `coredns`, `kube-proxy`,
  `aws-ebs-csi-driver`, `eks-pod-identity-agent`
- EBS CSI IAM role: `releaseops-dev-ebs-csi-role`
- EBS CSI Pod Identity association: `a-lnzlbxltzuvye0lak`
- State bucket: `releaseops-tan25-dev-tfstate`
- Legacy DynamoDB table: `releaseops-tan25-dev-tf-locks`

Do not treat these IDs as permanent. Verify live state before using them.

Not started:

- Terraform state-address refactor exercise
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

Continue after **EKS Managed Add-Ons**:

1. Confirm `terraform plan` still shows no changes.
2. Start basic RBAC discussion and decide the first app-facing Kubernetes
   permissions.
3. Add storage smoke test later only if needed, because PVCs can create EBS
   volumes and increase cost.
4. Continue toward application manifests, Helm, and GitOps.

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

At this status point, EKS and one worker node now exist. NAT Gateway, KMS,
Secrets Manager, and RDS PostgreSQL also exist and have cost. The EKS add-ons
do not add a major direct cost by themselves, but the EBS CSI driver can create
paid EBS volumes later if we create PVCs. ALB should not exist yet. Verify live
state before relying on this status.

The expensive-resource window has started. Do not leave the EKS cluster, NAT,
and RDS idle for days. Continue the lab or tear it down by the target date.

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
