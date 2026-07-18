# Interview Cheatsheet

## Terraform State

Question:

> Why do you use remote state?

Answer:

> Terraform state is the source of truth for resource mappings. I use remote
> state so the team has one shared, encrypted, versioned state location with
> locking. Local state is risky because it can be lost, accidentally committed,
> or modified concurrently.

## State Locking

Question:

> What does Terraform state locking prevent?

Answer:

> It prevents two Terraform operations from writing to the same state at the
> same time. Without locking, concurrent applies can cause inconsistent state or
> conflicting infrastructure changes.

## Module Design

Question:

> How do you think about Terraform modules?

Answer:

> I treat a module like a function. `variables.tf` is the input interface,
> resources are the implementation, and outputs are return values. The root
> environment should describe environment-specific intent, while modules should
> build reusable infrastructure from that input.

## Explicit CIDRs

Question:

> Why not let the module calculate all subnet CIDRs?

Answer:

> Calculated CIDRs are fine for simple demos, but explicit CIDRs make network
> intent visible during review. They also reduce surprise during refactors,
> especially once EKS, RDS, and route tables depend on those subnets.

## Plan Review

Question:

> What do you check before applying Terraform?

Answer:

> I check whether the plan is additive, in-place, replacement, or destructive.
> For foundational resources like VPCs, subnets, route tables, NAT, RDS, and EKS,
> I pay special attention to destroy or replacement actions.

## Public vs Private vs Isolated Subnets

Question:

> Why use three subnet tiers?

Answer:

> Public subnets host internet-facing entry points such as ALB and NAT. Private
> application subnets host workloads like EKS nodes that need controlled outbound
> access. Isolated database subnets host RDS and avoid direct internet or NAT
> routes.

## NAT Gateway

Question:

> Why use NAT Gateway?

Answer:

> NAT Gateway lets workloads in private subnets initiate outbound connections
> without making those workloads publicly reachable. For production, I consider
> NAT per AZ or VPC endpoints depending on availability and cost. For this lab,
> one NAT Gateway is a cost-controlled compromise.

## VPC Endpoint

Question:

> What is a VPC endpoint?

Answer:

> A VPC endpoint provides private connectivity from a VPC to an AWS service
> without requiring traffic to go through the public internet path. S3 and
> DynamoDB use Gateway Endpoints. Many other services use Interface Endpoints.

## S3 Gateway Endpoint

Question:

> Why add an S3 Gateway Endpoint if you already have NAT?

Answer:

> It lets private subnet resources reach S3 through a private route instead of
> using NAT. This can reduce NAT data processing cost and is cleaner for AWS
> service access from private workloads.

## Database Subnet Isolation

Question:

> Why should RDS be in isolated database subnets?

Answer:

> RDS should not be directly internet-facing. Isolated database subnets have only
> local VPC routing. Applications can reach RDS privately through security-group
> controlled paths, but the database does not get general outbound internet
> access.

## DB Subnet Group

Question:

> What is a DB subnet group in RDS?

Answer:

> A DB subnet group is an RDS-specific object that lists the subnets where AWS is
> allowed to place database resources. Instead of passing one subnet directly to
> RDS, I create a DB subnet group with isolated database subnets across at least
> two Availability Zones, then attach the RDS instance or cluster to that group.

## RDS Security Group Path

Question:

> How does your application connect to RDS securely?

Answer:

> RDS is placed in isolated database subnets and protected by a database security
> group. The database security group allows PostgreSQL on TCP `5432` only from
> the application security group, not from the whole VPC CIDR. Later, EKS
> workloads receive the application network identity through the node or pod
> security design, and Kubernetes NetworkPolicy adds pod-level control.

## KMS vs Secrets Manager

Question:

> What is the difference between KMS and Secrets Manager?

Answer:

> KMS manages encryption keys. Secrets Manager stores sensitive values like
> database credentials. In this lab, the KMS key encrypts database-related data
> and the Secrets Manager secret stores the PostgreSQL credential JSON. KMS is
> the lock/key system; Secrets Manager is the protected locker.

## Terraform And Secret State

Question:

> Is it safe for Terraform to generate a database password?

Answer:

> It can be acceptable for a controlled lab, but the generated password is stored
> in Terraform state even if it is marked sensitive and not printed in outputs.
> For stricter production setups, I would evaluate secret injection outside
> Terraform, managed rotation, or another approved credential workflow.

## RDS Lab Settings

Question:

> Which RDS settings did you choose for the lab, and how would production differ?

Answer:

> The lab uses a small private encrypted PostgreSQL instance, Single-AZ,
> short backup retention, no deletion protection, and skipped final snapshot for
> easy teardown. In production I would usually consider Multi-AZ, deletion
> protection, final snapshots, longer backup retention/PITR, stricter rotation,
> performance monitoring, and possibly RDS Proxy.

## Security Group Source

Question:

> Why use a security group as the source instead of `10.40.0.0/16`?

Answer:

> A CIDR rule allows anything with an IP in that range to attempt access. A
> security-group-to-security-group rule is tighter because AWS allows traffic
> only from resources associated with the approved source security group.

## EKS Subnet Tags

Question:

> Why do EKS subnets need Kubernetes tags?

Answer:

> AWS Kubernetes controllers use subnet tags to discover where they can create
> load balancers. Public subnets use `kubernetes.io/role/elb`, private subnets
> use `kubernetes.io/role/internal-elb`, and cluster tags associate the subnets
> with a cluster.

## Missing Load Balancer Troubleshooting

Question:

> Your Kubernetes Ingress is not getting an ALB. What do you check?

Answer:

> I check the Ingress events, AWS Load Balancer Controller logs, subnet tags,
> IAM permissions, security groups, and whether the Ingress requested an
> internet-facing or internal scheme.

## Output-Only Apply

Question:

> Can Terraform apply with zero infrastructure changes?

Answer:

> Yes. Outputs are stored in state. Adding or changing outputs can require an
> apply even when no AWS resources are added, changed, or destroyed.

## Lab vs Production

Question:

> Is this lab production-grade?

Answer:

> It implements production patterns, but with cost-controlled compromises. For
> example, the lab uses one NAT Gateway and a small future RDS instance. In
> production I would evaluate NAT per AZ, Multi-AZ RDS, backups, deletion
> protection, RDS Proxy, stricter secrets rotation, and environment/account
> separation.
