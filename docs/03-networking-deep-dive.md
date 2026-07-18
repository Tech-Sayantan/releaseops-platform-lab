# Networking Deep Dive

## The Big Picture

We are building a VPC that can support EKS, RDS, public ingress, private
application workloads, and cost-controlled outbound access.

The network has three subnet tiers:

```text
public
private application
isolated database
```

This is the foundation for the rest of the platform.

## VPC

The VPC CIDR is:

```text
10.40.0.0/16
```

That gives us enough internal IP space to divide the network into smaller
subnets.

The VPC has DNS support and DNS hostnames enabled:

```hcl
enable_dns_support   = true
enable_dns_hostnames = true
```

This matters for EKS, RDS, AWS service discovery, private DNS, and normal
application connectivity.

## Public Subnets

Public subnets:

```text
10.40.0.0/24
10.40.1.0/24
```

Public subnets have a route:

```text
0.0.0.0/0 -> Internet Gateway
```

They are used for resources that intentionally need an internet-facing path,
such as:

- public Application Load Balancer
- NAT Gateway

Public subnets are tagged:

```hcl
"kubernetes.io/role/elb" = "1"
```

This allows AWS Load Balancer Controller to discover them for internet-facing
load balancers.

## Private Application Subnets

Private application subnets:

```text
10.40.2.0/24
10.40.3.0/24
```

These are where EKS worker nodes should live. They do not directly expose public
IPs. Their default route goes through NAT:

```text
0.0.0.0/0 -> NAT Gateway
```

Why NAT?

Private workloads often need outbound access:

- pulling container images
- calling public APIs
- downloading packages during bootstrap
- reaching AWS services that do not have endpoints configured

NAT allows outbound access without making workloads directly reachable from the
internet.

Private app subnets are tagged:

```hcl
"kubernetes.io/role/internal-elb" = "1"
```

This allows internal load balancers to use them.

## Database Subnets

Database subnets:

```text
10.40.20.0/24
10.40.21.0/24
```

These are isolated. Their route table has only the automatic local route:

```text
10.40.0.0/16 -> local
```

They do not have:

```text
0.0.0.0/0 -> Internet Gateway
0.0.0.0/0 -> NAT Gateway
```

That means RDS can communicate privately inside the VPC, but it does not have a
direct internet route.

Interview phrasing:

> "Private application subnets and isolated database subnets are different.
> Application subnets may need controlled outbound access, but database subnets
> should normally avoid direct internet or NAT routes."

## NAT Gateway

The lab uses one NAT Gateway.

This is a deliberate cost-controlled decision:

- cheaper than one NAT per AZ
- acceptable for a short practice lab
- not the highest-availability production design

Production reference:

- one NAT Gateway per AZ reduces cross-AZ dependency and improves availability
- VPC endpoints can reduce NAT traffic and cost
- some organizations use centralized egress patterns

Interview phrasing:

> "For a short lab I used one NAT Gateway to control cost. In production I would
> consider NAT per AZ and VPC endpoints depending on availability, data volume,
> and compliance requirements."

## S3 Gateway VPC Endpoint

A VPC endpoint is a private route from your VPC to an AWS service.

Without endpoint:

```text
private subnet -> NAT Gateway -> public AWS S3 endpoint
```

With S3 Gateway Endpoint:

```text
private subnet -> S3 Gateway Endpoint -> S3
```

Gateway endpoints are commonly used for:

- S3
- DynamoDB

Interface endpoints are used for many other AWS services:

- ECR
- CloudWatch Logs
- Secrets Manager
- STS
- KMS
- SSM

Interface endpoints create ENIs and usually have hourly cost. Gateway endpoints
for S3/DynamoDB are usually preferred when they fit the requirement.

Important detail:

The S3 endpoint helps resources inside the VPC. It does not change how your
laptop uploads Terraform state to S3.

## Why We Moved To Explicit CIDRs

Earlier, the module used subnet math:

```hcl
cidrsubnet(var.vpc_cidr, 8, count.index)
```

That is useful for learning, but for this lab we moved CIDRs into the environment
configuration:

```hcl
public_subnet_cidrs = [
  "10.40.0.0/24",
  "10.40.1.0/24",
]
```

This makes intent visible at review time.

Good Terraform design:

- root environment decides environment-specific values
- child module builds resources from those values
- outputs return the IDs needed by other modules

Interview phrasing:

> "I prefer keeping environment-specific network allocations in the root
> environment config, while the module focuses on resource construction. This
> improves reviewability and reduces surprise during refactors."

## Variable Validation

The module validates that each subnet CIDR list has exactly one CIDR per AZ.

Example:

```hcl
validation {
  condition     = length(var.public_subnet_cidrs) == var.az_count
  error_message = "public_subnet_cidrs must contain exactly one CIDR block per Availability Zone."
}
```

This catches mistakes early.

Without validation, Terraform may fail later with a confusing index error.
With validation, the module gives a clear message before resource evaluation
gets messy.

Interview phrasing:

> "I use variable validation to fail fast and give module consumers clear error
> messages before Terraform reaches confusing resource-level failures."

## EKS Subnet Discovery Tags

Public and private application subnets have:

```hcl
"kubernetes.io/cluster/releaseops-dev" = "shared"
```

Public subnets also have:

```hcl
"kubernetes.io/role/elb" = "1"
```

Private application subnets also have:

```hcl
"kubernetes.io/role/internal-elb" = "1"
```

These tags help Kubernetes AWS controllers choose the correct subnets for load
balancers.

Common failure if tags are missing:

- Ingress stays without an address
- Service type `LoadBalancer` remains pending
- AWS Load Balancer Controller logs say no suitable subnets were found

Troubleshooting path:

```text
kubectl describe ingress
kubectl logs -n kube-system deployment/aws-load-balancer-controller
check subnet tags
check IAM permissions
check ingress scheme: internet-facing vs internal
```

