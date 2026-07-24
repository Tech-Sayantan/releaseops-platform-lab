# Current Progress Notes

Last updated: 2026-07-24

## Sleepy Restart Path

If you open this repo tomorrow and feel lost, read these sections in order:

1. `What Exists Right Now`
2. `Current AWS Shape`
3. `Next Planned Work`
4. `RDS PostgreSQL Completed`
5. `ECR Completed`
6. `SQS And DLQ Completed`
7. `IAM And GitHub OIDC Completed`
8. `EKS Foundation Completed`
9. `EKS Managed Add-Ons Completed`

This file is meant to answer one practical question:

```text
Where exactly are we in the lab right now?
```

## One-Minute Restart Summary

The AWS foundation was built, verified, and then destroyed to stop lab cost:

- networking
- RDS
- ECR
- SQS and DLQ
- IAM/OIDC for GitHub Actions
- EKS cluster and one managed worker node
- EKS managed add-ons
- Kubernetes platform guardrails

The paid dev stack teardown completed on 2026-07-24:

```text
Apply complete! Resources: 0 added, 0 changed, 60 destroyed.
```

The separate Terraform bootstrap backend still exists because it is protected
with `prevent_destroy`: S3 backend bucket resources plus the legacy DynamoDB
lock table.

## What Exists Right Now

We built the foundation for the ReleaseOps platform:

- Terraform backend bootstrap
- Main dev Terraform root
- Custom networking module
- VPC
- public subnets
- private application subnets
- isolated database subnets
- public, private, and database route tables
- Internet Gateway
- one lab NAT Gateway
- S3 Gateway VPC Endpoint
- EKS/Load Balancer subnet discovery tags
- RDS DB subnet group
- database security group
- application security group
- PostgreSQL ingress from application security group to database security group
- KMS key and alias for database-related encryption
- Secrets Manager secret and secret version for PostgreSQL credentials
- private encrypted PostgreSQL RDS instance
- reusable ECR module
- ECR repositories for `api`, `worker`, `notifications`, and `frontend`
- ECR lifecycle policies for image cleanup
- reusable SQS module
- deployment events SQS queue
- deployment events DLQ
- SQS redrive policy from main queue to DLQ
- outputs for important networking and RDS preparation IDs
- outputs for ECR repository names, URLs, and ARNs
- outputs for deployment queue and DLQ names, URLs, and ARNs
- IAM OIDC provider for GitHub Actions
- IAM role for GitHub Actions Terraform execution
- IAM policy and attachment for the Terraform execution role
- outputs for GitHub OIDC provider, role, policy, and allowed subject
- EKS cluster `releaseops-dev-eks`
- EKS managed node group `releaseops-dev-default`
- one `t3.small` worker node in private application subnets
- restricted public EKS API endpoint access
- outputs for EKS cluster, endpoint, security group, roles, and node group
- EKS managed add-ons: VPC CNI, CoreDNS, kube-proxy, EBS CSI, and EKS Pod
  Identity Agent
- EBS CSI Pod Identity role and association

## Current AWS Shape

```text
VPC: 10.40.0.0/16

Public subnets:
  10.40.0.0/24 in us-east-1a
  10.40.1.0/24 in us-east-1b

Private application subnets:
  10.40.2.0/24 in us-east-1a
  10.40.3.0/24 in us-east-1b

Isolated database subnets:
  10.40.20.0/24 in us-east-1a
  10.40.21.0/24 in us-east-1b
```

Routing:

- public subnets route `0.0.0.0/0` to the Internet Gateway
- private application subnets route `0.0.0.0/0` to one NAT Gateway
- private application subnets use an S3 Gateway Endpoint for S3 traffic
- database subnets have only the automatic local VPC route

## Why This Is A Good Baseline

This is not just "a VPC with subnets." It already teaches the subnet separation
used in real AWS platforms:

- public subnet: internet-facing entry points such as ALB and NAT Gateway
- private app subnet: EKS worker nodes and application workloads
- isolated database subnet: RDS with no direct internet or NAT route

This separation matters because each subnet tier has a different risk profile.
An ALB needs to receive internet traffic. An EKS node usually needs controlled
outbound access. A database should be reachable only from trusted application
paths.

## Important Terraform Commands

Run from:

```text
/Users/sayantanchowdhury/Documents/Codex/releaseops-platform-lab/infra/envs/dev
```

```bash
terraform fmt -recursive
terraform validate
terraform plan
terraform output
terraform state list
```

Useful focused checks:

```bash
terraform state list | grep database
terraform state list | grep -E "nat|vpc_endpoint|route_table|subnet"
terraform state list | grep ecr
terraform state list | grep sqs
terraform state list | grep -E "github_oidc|iam"
terraform state list | grep eks
aws eks list-addons --cluster-name releaseops-dev-eks --region us-east-1
kubectl get pods -n kube-system -o wide
kubectl get pods -n kube-system -l app=ebs-csi-controller
```

## What To Watch In Every Plan

For networking, do not only look at the total number of resources. Look for the
kind of action:

- `add` is usually safe if it is expected
- `change` is okay only if it is an in-place update you understand
- `destroy` is dangerous for foundational resources
- `-/+` means replacement and must be reviewed carefully

Good plan examples we saw:

```text
Plan: 2 to add, 0 to change, 0 to destroy.
```

This added two database subnets.

```text
Plan: 3 to add, 0 to change, 0 to destroy.
```

This added a database route table and two associations.

```text
Plan: 2 to add, 1 to change, 0 to destroy.
```

This added NAT resources and updated the private route table.

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

This added the S3 Gateway VPC Endpoint.

```text
Plan: 0 to add, 4 to change, 0 to destroy.
```

This updated subnet tags in place for EKS and load balancer discovery.

## Next Planned Work

Next we should build the next Kubernetes platform layer:

- namespaces
- basic RBAC/service account discussion
- resource requests and limits
- application deployment preparation

Then we move toward namespaces, platform add-ons, and the Java application.

## RDS-Ready Networking Completed

We created an `rds` Terraform module and wired it into the dev root.

Current resources:

```text
module.rds.aws_db_subnet_group.this
module.rds.aws_security_group.database
module.rds.aws_security_group.application
module.rds.aws_vpc_security_group_ingress_rule.postgres_from_application
```

Meaning:

- the DB subnet group tells RDS which isolated database subnets it may use
- the database security group protects the future PostgreSQL database
- the application security group represents workloads allowed to talk to RDS
- the ingress rule allows only application SG traffic to DB SG on TCP `5432`

The actual RDS PostgreSQL instance now exists.

## RDS PostgreSQL Completed

We added a small cost-controlled PostgreSQL RDS instance:

```text
module.rds.aws_db_instance.postgres
```

Important properties:

- private RDS endpoint only
- `publicly_accessible = false`
- encrypted storage using the customer-managed KMS key
- credentials generated by Terraform and stored in Secrets Manager
- no password output
- small lab instance class
- Single-AZ for cost control
- deletion protection disabled for teardown
- final snapshot skipped for teardown speed

Safe root outputs now include:

```text
database_endpoint
database_port
database_name
database_secret_arn
database_kms_key_arn
```

The password is intentionally not exposed through Terraform outputs.

## ECR Completed

We created a reusable `ecr` module and wired it into the dev root.

Current repositories:

```text
releaseops-dev/api
releaseops-dev/worker
releaseops-dev/notifications
releaseops-dev/frontend
```

Each repository has:

- scan on push enabled
- immutable image tags
- AES256 encryption
- lifecycle policy for cleanup

Safe root outputs now include:

```text
ecr_repository_names
ecr_repository_urls
ecr_repository_arns
```

The URLs are what GitHub Actions will later use for Docker image pushes.

## SQS And DLQ Completed

We created a reusable `sqs` module and wired it into the dev root.

Current queues:

```text
releaseops-dev-deployment-events
releaseops-dev-deployment-events-dlq
```

The main queue will support future async deployment work:

```text
api service -> deployment-events queue -> worker service
```

The DLQ will store messages that fail too many processing attempts.

Safe root outputs now include:

```text
deployment_queue_name
deployment_queue_url
deployment_queue_arn
deployment_dlq_name
deployment_dlq_url
deployment_dlq_arn
```

The queue URL is useful for application configuration. The queue ARN is useful
for IAM permissions and monitoring.

## IAM And GitHub OIDC Completed

We created a reusable `iam` module and wired it into the dev root as:

```text
module.github_oidc
```

Current resources:

```text
module.github_oidc.aws_iam_openid_connect_provider.github
module.github_oidc.aws_iam_role.github_actions
module.github_oidc.aws_iam_policy.terraform_permissions
module.github_oidc.aws_iam_role_policy_attachment.terraform_permissions
```

Meaning:

- the OIDC provider tells AWS to recognize GitHub Actions identity tokens
- the IAM role is the AWS identity GitHub Actions can temporarily assume
- the trust policy restricts assumption to this repo and branch
- the permission policy gives Terraform enough access for this lab
- the role-policy attachment connects the role to the permissions

Safe root outputs now include:

```text
github_oidc_provider_arn
github_actions_role_name
github_actions_role_arn
github_actions_policy_arn
github_oidc_subject
```

Important verified subject:

```text
repo:Tech-Sayantan/releaseops-platform-lab:ref:refs/heads/main
```

The `github_actions_role_arn` will later be used in GitHub Actions workflows.

## EKS Foundation Completed

We created a reusable `eks` module and wired it into the dev root.

Current resources:

```text
module.eks.aws_eks_cluster.this
module.eks.aws_eks_node_group.default
module.eks.aws_iam_role.cluster
module.eks.aws_iam_role.node
module.eks.aws_iam_role_policy_attachment.cluster_policy
module.eks.aws_iam_role_policy_attachment.node_cni_policy
module.eks.aws_iam_role_policy_attachment.node_ecr_policy
module.eks.aws_iam_role_policy_attachment.node_worker_policy
```

Current live cluster:

```text
releaseops-dev-eks
```

Current live node group:

```text
releaseops-dev-default
```

Verified with:

```bash
aws eks describe-cluster --name releaseops-dev-eks --region us-east-1
aws eks describe-nodegroup --cluster-name releaseops-dev-eks --nodegroup-name releaseops-dev-default --region us-east-1
aws eks update-kubeconfig --name releaseops-dev-eks --region us-east-1 --alias releaseops-dev-eks
kubectl get nodes -o wide
```

The node was observed as:

```text
ip-10-40-2-87.ec2.internal   Ready
```

Safe root outputs now include:

```text
eks_cluster_name
eks_cluster_arn
eks_cluster_endpoint
eks_cluster_security_group_id
eks_cluster_role_arn
eks_node_role_arn
eks_node_group_name
```

## EKS Managed Add-Ons Completed

We added the standard EKS add-ons needed before application deployment:

```text
vpc-cni
coredns
kube-proxy
aws-ebs-csi-driver
eks-pod-identity-agent
```

The timeout during apply did not leave the cluster broken. Live checks showed
the add-ons existed. The EBS CSI controller initially crashed because it did not
have AWS credentials to call EC2 APIs for EBS volume work.

We fixed that with a dedicated EKS Pod Identity role:

```text
releaseops-dev-ebs-csi-role
```

and a Pod Identity association:

```text
kube-system/ebs-csi-controller-sa -> releaseops-dev-ebs-csi-role
```

Final verification:

```text
Terraform plan: No changes
EBS CSI controller pods: 6/6 Running
All core kube-system add-on pods: Running
```

## Kubernetes Platform Guardrails Completed

We added the first Kubernetes-side platform layer:

```text
k8s/platform/base
```

Created files:

```text
kustomization.yaml
namespaces.yaml
releaseops-serviceaccounts.yaml
releaseops-resourcequota.yaml
releaseops-limitrange.yaml
```

Applied and verified live objects:

```text
namespaces: releaseops, observability, argocd
service accounts: api, worker, notifications, frontend
ResourceQuota: releaseops-compute-quota
LimitRange: releaseops-default-container-limits
```

This created Kubernetes objects only. It did not create a LoadBalancer, EBS
volume, RDS instance, or new EC2 node.

Next Kubernetes topic:

```text
RBAC and first app-facing permissions
```
