# Current Progress Notes

Last updated: 2026-07-18

## What Exists Right Now

We have built the foundation for the ReleaseOps platform:

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
- outputs for important networking IDs

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

Next we should build the RDS-ready network/security layer:

- security group for EKS application path
- security group for RDS PostgreSQL
- RDS subnet group using database subnet IDs
- KMS/Secrets Manager design before actual database creation

Then we move toward IAM, ECR, SQS, RDS, and EKS.

