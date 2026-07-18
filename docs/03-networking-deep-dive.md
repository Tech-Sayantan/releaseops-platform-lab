# Networking Deep Dive

Last updated: 2026-07-18

## Sleepy Revision Path

If you are reading this while tired, read these sections first:

1. `The Big Picture`
2. `One-Minute Mental Model`
3. `Public Vs Private Vs Database Subnets`
4. `NAT Gateway`
5. `S3 Gateway VPC Endpoint`
6. `Common Production Issues`
7. `Interview Questions To Practice`

Core story:

```text
We built one VPC.
Inside that VPC we created three subnet tiers.
Public is for entry points.
Private application is for EKS workloads.
Database is for RDS.
NAT gives private workloads outbound access.
S3 endpoint reduces NAT usage for S3 traffic.
```

## The Big Picture

We are building a VPC that can support:

- EKS
- RDS
- public ingress
- private application workloads
- cost-controlled outbound access

The network has three subnet tiers:

```text
public
private application
isolated database
```

This is the foundation for the rest of the platform.

## One-Minute Mental Model

Think of the VPC like a campus.

```text
VPC = the full campus
subnets = separate buildings or zones
route table = traffic rules for each zone
Internet Gateway = front gate to the internet
NAT Gateway = controlled outbound exit for private zones
VPC endpoint = private shortcut to an AWS service
```

In our lab:

```text
public subnet      = front-facing zone
private app subnet = internal app zone
database subnet    = protected data zone
```

## Exact Network Shape In This Lab

VPC CIDR:

```text
10.40.0.0/16
```

Public subnets:

```text
10.40.0.0/24 in us-east-1a
10.40.1.0/24 in us-east-1b
```

Private application subnets:

```text
10.40.2.0/24 in us-east-1a
10.40.3.0/24 in us-east-1b
```

Database subnets:

```text
10.40.20.0/24 in us-east-1a
10.40.21.0/24 in us-east-1b
```

## Why We Chose A `/16` VPC CIDR

The VPC CIDR is:

```text
10.40.0.0/16
```

That gives us a reasonably large private IP space for the lab.

Why useful:

- easy to split into multiple `/24` subnets
- enough room for public, private, and database tiers
- simple to read during review

This lab is not doing advanced CIDR exhaustion planning, but the shape is still
realistic enough for interview discussion.

## VPC Resource Basics

Important settings in the VPC:

```hcl
enable_dns_support   = true
enable_dns_hostnames = true
```

Why they matter:

- RDS private endpoints need DNS resolution
- EKS and AWS integrations rely heavily on DNS
- many private-service flows become painful if DNS is broken

Interview line:

> I enable VPC DNS support and hostnames because private AWS services, cluster
> integrations, and managed endpoints depend on working internal DNS.

## Public Vs Private Vs Database Subnets

This is one of the most important design ideas in the whole lab.

### Public Subnets

Public subnets are for resources that need an intentional internet-facing path.

In our design, public subnets are suitable for:

- public Application Load Balancer
- NAT Gateway

Their route table includes:

```text
0.0.0.0/0 -> Internet Gateway
```

That means resources in those subnets can use the internet path directly.

### Private Application Subnets

Private application subnets are for workloads like:

- EKS nodes
- application pods
- internal workloads that should not get public IP exposure

Their route table includes:

```text
0.0.0.0/0 -> NAT Gateway
```

Meaning:

```text
they can go out
but outside systems cannot directly come in
```

That is why private subnets are commonly used for app workloads.

### Database Subnets

Database subnets are more locked down.

Their route table has only the local VPC route:

```text
10.40.0.0/16 -> local
```

They do not have:

```text
0.0.0.0/0 -> Internet Gateway
0.0.0.0/0 -> NAT Gateway
```

Meaning:

```text
database traffic stays private inside the VPC
```

Interview line:

> Private application subnets and isolated database subnets are not the same.
> App subnets may need controlled outbound access. Database subnets should stay
> private and usually avoid general internet egress.

## Route Tables

A route table decides where packets go next.

We created separate route tables for:

- public subnets
- private application subnets
- database subnets

Why separate route tables are good:

- each subnet tier can have different behavior
- design is easier to review
- future changes are safer

If everything shared one route table, database isolation would become much
harder to reason about.

## Internet Gateway

The Internet Gateway is the VPC attachment that allows internet routing for
public subnet resources.

Without it:

```text
public subnet cannot truly be public
```

Important nuance:

An Internet Gateway by itself does not make every resource public. A resource
also needs:

- the correct route
- a public IP or public-facing attachment path
- security rules that allow the traffic

## NAT Gateway

The lab uses one NAT Gateway.

Purpose:

Private workloads often still need outbound connectivity for things like:

- pulling packages
- pulling images
- reaching public APIs
- reaching AWS services that do not have private endpoints configured

Without NAT:

```text
private subnet workloads may be unable to reach the outside world
```

With NAT:

```text
private workloads can initiate outbound connections
but they are not directly reachable from the internet
```

### Why Only One NAT Gateway?

This was a deliberate lab decision:

- lower cost
- simpler for short-lived practice
- acceptable for interview learning

Production comparison:

- one NAT per AZ is more resilient
- VPC endpoints can reduce NAT dependence
- centralized egress patterns exist in some enterprises

Interview line:

> For the lab I used one NAT Gateway as a cost-controlled compromise. In
> production I would consider one NAT per AZ and service-specific VPC endpoints
> based on availability and cost requirements.

## S3 Gateway VPC Endpoint

A VPC endpoint gives private connectivity from the VPC to an AWS service.

In our case, we created an S3 Gateway Endpoint.

Without the endpoint:

```text
private subnet -> NAT Gateway -> public path -> S3
```

With the endpoint:

```text
private subnet -> private route -> S3
```

Why this matters:

- reduces NAT usage
- can reduce cost
- is a cleaner AWS-internal path for S3 traffic

Important nuance:

This endpoint helps workloads inside the VPC.

It does **not** change how your laptop talks to S3 for Terraform backend usage.

That is a different path.

## Gateway Endpoint Vs Interface Endpoint

This interview question appears often.

Gateway endpoints are commonly used for:

- S3
- DynamoDB

Interface endpoints are commonly used for:

- ECR API
- Secrets Manager
- STS
- KMS
- CloudWatch Logs
- SSM

Important difference:

- Gateway endpoints are route-table based
- Interface endpoints create ENIs in subnets and usually cost money hourly

Interview line:

> S3 and DynamoDB typically use Gateway Endpoints. Many other AWS services use
> Interface Endpoints backed by ENIs.

## Why We Used Explicit CIDRs

Earlier, the networking logic could have calculated subnet CIDRs inside the
module using subnet math.

Instead, we moved to explicit CIDRs in the root environment config:

```hcl
public_subnet_cidrs = [
  "10.40.0.0/24",
  "10.40.1.0/24",
]
```

Why this is good:

- reviewers can see exact network intent immediately
- environment-specific allocations stay in the root
- module remains reusable
- refactors become easier to reason about

Interview line:

> I prefer environment-specific CIDRs in the root config because the actual
> network intent becomes visible during review, while the child module stays
> focused on resource construction.

## Variable Validation

The networking module validates that subnet CIDR lists line up with AZ count.

Example:

```hcl
validation {
  condition     = length(var.public_subnet_cidrs) == var.az_count
  error_message = "public_subnet_cidrs must contain exactly one CIDR block per Availability Zone."
}
```

Why useful:

If someone passes one public subnet CIDR but asks for two AZs, Terraform fails
early with a clear error instead of producing confusing downstream failures.

## EKS Subnet Discovery Tags

Public and private application subnets have Kubernetes-related tags.

Public subnet example:

```hcl
"kubernetes.io/role/elb" = "1"
```

Private application subnet example:

```hcl
"kubernetes.io/role/internal-elb" = "1"
```

Cluster association tag:

```hcl
"kubernetes.io/cluster/releaseops-dev" = "shared"
```

Why this matters:

AWS Kubernetes controllers use these tags to discover which subnets can host
load balancers.

If these tags are missing, you may see:

- Ingress without an address
- `LoadBalancer` service stuck pending
- controller logs saying no suitable subnets found

## Terraform Resource Flow

The reusable networking module conceptually created:

- VPC
- subnets
- Internet Gateway
- NAT Gateway
- route tables
- route table associations
- S3 endpoint

The dev root passes:

- VPC CIDR
- subnet CIDR lists
- AZ count
- common tags

The module returns:

- VPC ID
- subnet IDs
- NAT ID
- S3 endpoint ID
- availability zones

That output flow is why later modules can consume networking values without
hardcoding AWS IDs.

## Common Production Issues

### App In Private Subnet Cannot Reach AWS Service

Possible causes:

- no NAT route
- missing VPC endpoint
- DNS problem
- IAM permission missing
- security group or network policy problem

Debug path:

1. Check route table.
2. Check whether a VPC endpoint exists for that service.
3. Check DNS resolution.
4. Check IAM permission.
5. Check SG and NetworkPolicy.

### Load Balancer Does Not Appear

Possible causes:

- subnet tags missing
- wrong scheme requested
- controller IAM missing
- service/ingress misconfiguration

Debug path:

1. `kubectl describe ingress` or service
2. controller logs
3. subnet tags
4. IAM role
5. scheme type

### RDS Is Reachable Publicly By Mistake

Possible causes:

- wrong subnet placement
- broad security group
- public accessibility enabled

Fix path:

1. confirm DB subnet group uses isolated subnets
2. confirm RDS is not publicly accessible
3. confirm SG source is restricted

## Interview Questions To Practice

### Why use three subnet tiers?

Because internet-facing components, application workloads, and databases have
different risk profiles and routing needs.

### Why use NAT Gateway?

To allow private workloads to initiate outbound connections without giving them
direct internet reachability.

### Why add an S3 endpoint if NAT already exists?

To provide a cleaner private path to S3 and reduce NAT usage and cost.

### Why isolate database subnets?

Because databases should stay reachable only through controlled private paths,
not general internet routes.

### Why explicit CIDRs instead of generated ones?

Because explicit CIDRs improve reviewability and keep environment-specific
network intent visible.

## Speakable Interview Answers

- "The network is intentionally split into public, private application, and
  isolated database tiers."
- "Public subnets are for entry points like ALB and NAT, private app subnets
  are for workloads, and database subnets are for RDS."
- "NAT is about controlled outbound connectivity from private subnets, not about
  app-to-database traffic."
- "App-to-RDS traffic inside the VPC uses the local route and security controls,
  not NAT."
- "The S3 gateway endpoint gives private subnet resources a cleaner private path
  to S3."

## Verification Commands

Useful checks from the environment root:

```bash
terraform output
terraform state list | grep -E "subnet|route_table|nat|vpc_endpoint"
terraform plan
```
