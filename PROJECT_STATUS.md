# ReleaseOps Platform Lab - Status

Last updated: 2026-07-24
Master plan: `PROJECT_MASTER_PLAN.md`  
Target teardown complete: 2026-07-26

## Current State

Read-only cluster audit on 2026-07-23:

- `releaseops` had no live Deployment, Pod, Service, HPA, PDB, Ingress, PVC, or
  Helm release.
- The four workload ServiceAccounts, ResourceQuota, and LimitRange were present.
- Application workload YAML remains a locally validated Helm/GitOps reference.

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
- Kubernetes platform guardrails applied and verified: namespaces, service
  accounts, ResourceQuota, and LimitRange.
- Application reference architecture added for four Java/Spring Boot services:
  release, approval, deployment worker, and incident/audit.
- Dockerfile reference added for production-shaped Spring Boot image builds.
- Reusable Helm chart added and expanded with ConfigMap, Deployment, optional
  Service and Ingress, three probe types, HPA behavior, PDB, ingress/egress
  NetworkPolicy, optional RBAC, rollout safety, topology spreading, resources,
  and pod security controls.
- Kubernetes interview reference manifests added for migration Job, scheduled
  CronJob, StatefulSet and persistent storage, DaemonSet, Pod Security Admission,
  default-deny networking, and namespace-scoped support RBAC.
- Vendor-neutral Kubernetes core deep dive and symptom-based troubleshooting
  playbook added. These distinguish applied objects from locally rendered
  reference objects.
- GitOps reference added with Argo CD AppProject, ApplicationSet, and dev
  values files.
- GitHub Actions workflows added for credential-free Terraform PR validation,
  trusted main-branch Terraform planning, application PR CI, reusable Java
  application CI, immutable image publication, structured GitOps promotion, and
  Helm validation.
- Application CI/CD wiring now runs app PR validation automatically and can
  publish/promote `release-service` from `main`.
- Composite release-metadata action added to demonstrate reusable custom action
  design without confusing notification with enforced approval.
- Jenkins Declarative Pipeline and Shared Library references added for Maven,
  SonarQube, image build/scan/SBOM, short-lived AWS access, ECR publication,
  and GitOps promotion.
- Structured Python GitOps updater added to validate and write an immutable
  image repository and digest into a Helm values file.
- Python unit tests added for successful promotion update, idempotent retry,
  and mutable-tag rejection.
- Python helper scripts added for EKS health reporting, Terraform plan guarding,
  and interview drill practice.
- Interview-prep documentation added for architecture, CI/CD, Helm, GitOps,
  Python scripting, scenario drills, troubleshooting, command walkthrough, and
  cleanup.
- Final revision notes added for Terraform/EKS concepts, observability, and
  autoscaling.

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
- Kubernetes namespaces: `releaseops`, `observability`, `argocd`
- ReleaseOps service accounts: `api`, `worker`, `notifications`, `frontend`
- ReleaseOps quota: `releaseops-compute-quota`
- ReleaseOps limit range: `releaseops-default-container-limits`
- State bucket: `releaseops-tan25-dev-tfstate`
- Legacy DynamoDB table: `releaseops-tan25-dev-tf-locks`

Do not treat these IDs as permanent. Verify live state before using them.

Not live-deployed yet:

- Argo CD applications
- full Java service implementation beyond the compact `release-service`
  reference API
- full observability stack
- external ingress and domain wiring
- reference application Deployments, Services, HPAs, PDBs, and NetworkPolicies
- newly added Pod Security Admission, default-deny policy, and support RBAC changes

## Exact Next Step

Resume inside:

```text
/Users/sayantanchowdhury/Documents/Codex/releaseops-platform-lab
```

For interview prep mode:

1. Read `docs/24-cicd-release-gitops-deep-dive.md`.
2. Read `docs/25-cicd-troubleshooting-playbook.md`.
3. Walk `.github/`, `jenkins/`, `scripts/update_gitops_image.py`, `gitops/`,
   and `charts/` beside those chapters.
4. Return to `docs/13-client-interview-prep-index.md` for the complete map.
5. Practice the scenarios in `docs/15-scenario-drills-and-gotchas.md`.
6. Tear down the paid AWS resources using `docs/18-cleanup-runbook.md` when the
   study/demo window is complete.

Follow-along mode is paused. The repository is now a study/reference project.
For Kubernetes-first study, begin with `docs/22-kubernetes-core-deep-dive.md`
and then use `docs/23-kubernetes-troubleshooting-playbook.md` after each topic.
For the current CI/CD pass, use `docs/24-cicd-release-gitops-deep-dive.md` and
then answer the scenarios in `docs/25-cicd-troubleshooting-playbook.md`.

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

- 2026-07-22: Added interview-ready reference layer: app architecture, Docker,
  Helm, GitOps, CI/CD workflows, Python helper scripts, and deep prep notes.
- 2026-07-23: Expanded the Kubernetes study/reference layer with production
  workload patterns, optional controllers, security guardrails, stateful/batch/
  node-agent examples, and a detailed troubleshooting playbook. No new live
  workload or billable cloud resource was created.
- 2026-07-24: Added the production CI/CD study layer with reusable GitHub
  Actions workflows, a composite action, Jenkins Shared Library references,
  digest-based GitOps promotion, a structured Python updater, and a detailed
  troubleshooting playbook. No workflow was dispatched and no cloud or cluster
  resource was changed.
