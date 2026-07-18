# RDS Networking Notes

Last updated: 2026-07-18

## Sleepy Revision Path

If you are revising quickly, read these sections first:

1. `What We Built`
2. `One-Minute Mental Model`
3. `DB Subnet Group`
4. `Security Groups`
5. `How Application Traffic Will Flow Later`
6. `KMS And Secrets Manager`
7. `Common Production Issues`

Core story:

```text
Our app will run in EKS.
Our database runs in AWS RDS.
RDS lives in isolated database subnets.
Only approved application traffic should reach it.
Secrets Manager stores credentials.
KMS protects encryption.
```

## What We Built

We added a dedicated Terraform module:

```text
infra/modules/rds
```

This module currently creates:

- DB subnet group
- database security group
- application security group
- PostgreSQL ingress rule from application SG to database SG
- KMS key and alias
- Secrets Manager secret and secret version
- generated PostgreSQL master password
- private encrypted PostgreSQL RDS instance

The actual PostgreSQL database now exists.

## One-Minute Mental Model

Think of the database layer like a secure vault area inside the VPC.

```text
VPC = the full building
database subnets = the locked vault wing
DB subnet group = list of approved vault rooms
RDS = actual managed database
database SG = vault door rule
application SG = approved client badge
Secrets Manager = password locker
KMS = encryption key system
```

The whole design is trying to do four things:

- keep the database private
- allow only approved app traffic
- store credentials outside code
- encrypt important data

## Why RDS Instead Of Running PostgreSQL In Kubernetes

Could we run PostgreSQL in Kubernetes? Yes, technically.

Why we chose RDS instead:

- AWS manages much of the database infrastructure
- backups and maintenance patterns are more normal for many teams
- interviewers often expect app-on-EKS plus DB-on-RDS understanding
- this is a more realistic pattern for many companies

Interview line:

> For many teams, stateless application workloads run in Kubernetes while
> relational databases stay on managed services like RDS to reduce operational
> burden.

## DB Subnet Group

RDS does not take one subnet directly. It uses a DB subnet group.

Simple mental model:

```text
VPC = city
subnets = neighborhoods
DB subnet group = approved database neighborhoods
RDS instance = actual database house
```

In our lab:

```text
releaseops-dev-db-subnet-group
  -> isolated database subnet in us-east-1a
  -> isolated database subnet in us-east-1b
```

Why use two subnets across two AZs even for a small lab?

- follows the normal RDS pattern
- keeps the design Multi-AZ-ready
- matches real-world expectations better

## Security Groups

We created two security groups:

```text
application security group
database security group
```

The database security group allows:

```text
source: application security group
target: database security group
port:   TCP 5432
```

Meaning:

```text
Only resources associated with the application SG
can reach PostgreSQL on port 5432.
```

This is more secure than:

- `0.0.0.0/0`
- broad VPC CIDR access unless truly necessary

## Why SG-To-SG Is Better Than Broad CIDR

Bad pattern:

```text
allow 10.40.0.0/16 to reach PostgreSQL
```

That means anything in the VPC range may attempt access.

Better pattern:

```text
allow only the approved application security group
```

Why better:

- tighter scope
- clearer intent
- easier review
- easier interview explanation

Interview line:

> I prefer security-group-to-security-group rules when possible because they
> express workload identity more clearly than broad CIDR-based access.

## How Application Traffic Will Flow Later

Later, the Java service will receive:

```text
DB_HOST=<rds-private-endpoint>
DB_PORT=5432
DB_NAME=releaseops
DB_USER=<from secret>
DB_PASSWORD=<from secret>
```

Network flow:

```text
Java pod
  -> EKS node or pod ENI
  -> private VPC local route
  -> RDS private endpoint
  -> database security group
  -> PostgreSQL
```

Important:

This path does **not** use:

- Internet Gateway
- NAT Gateway

Why?

Because app-to-RDS traffic inside the same VPC uses the local VPC route.

That is a very important interview concept.

## EKS Design Choice Still Pending

The `application` security group exists, but EKS is not built yet.

Later, workloads may receive their network identity through:

- node security group approach
- Security Groups for Pods
- hybrid SG plus Kubernetes NetworkPolicy approach

For the lab, the practical path is likely:

- AWS security groups for the wider AWS boundary
- Kubernetes NetworkPolicy for pod and namespace-level control

## KMS And Secrets Manager

People often mix these up.

KMS:

```text
manages encryption keys
```

Secrets Manager:

```text
stores secret values
```

In our lab:

```text
KMS key
  -> encrypts database-related secret data
  -> encrypts RDS storage

Secrets Manager secret
  -> stores username/password/database JSON
```

Simple mental model:

```text
KMS = lock and key system
Secrets Manager = secure locker
```

The secret looks like:

```json
{
  "username": "releaseops_admin",
  "password": "<generated>",
  "database": "releaseops"
}
```

The password is intentionally not shown as a normal Terraform output.

## Important Terraform State Warning

Terraform generated the password using:

```text
random_password.database_master.result
```

That means the value still exists in Terraform state even if it is hidden from
normal output.

This is why backend protection matters:

- state must be encrypted
- state access must be restricted
- secrets should not be exposed casually

Interview line:

> Sensitive output hides display, but it does not guarantee the value never
> touched Terraform state.

## RDS Instance Settings In This Lab

The lab RDS instance is:

```text
module.rds.aws_db_instance.postgres
```

It is configured as:

- PostgreSQL
- private endpoint
- encrypted storage
- DB subnet group in isolated database subnets
- database security group attached
- Single-AZ for lab cost control
- short backup retention
- deletion protection disabled for teardown
- final snapshot skipped for teardown speed

Safe root outputs:

```text
database_endpoint
database_port
database_name
database_secret_arn
database_kms_key_arn
```

## Lab Settings Vs Production Settings

Lab settings are optimized for:

- speed
- lower cost
- easier teardown

Production usually needs more:

- Multi-AZ
- deletion protection
- final snapshot on destroy
- longer backup retention
- PITR expectations
- performance monitoring
- stricter rotation and access rules
- maybe RDS Proxy

## Common Production Issues

### App Cannot Connect To RDS

Possible causes:

- wrong endpoint
- wrong port
- wrong credentials
- SG rule missing
- NetworkPolicy blocking egress
- DNS failure
- DB user/schema issue

Debug path:

1. Check RDS endpoint and port.
2. Check DB status.
3. Check SG inbound rule.
4. Check source identity on node or pod side.
5. Check DNS resolution from the pod.
6. Check credentials.
7. Check application logs.

### RDS Accidentally Exposed Too Broadly

Possible causes:

- CIDR too broad
- public accessibility enabled
- wrong subnet placement

Fix path:

1. confirm isolated subnets
2. confirm `publicly_accessible = false`
3. confirm SG source is narrow

### Secrets Look Hidden But Still Exist In State

Possible cause:

Terraform generated or handled the secret.

Fix path:

1. protect remote state
2. limit backend access
3. avoid unnecessary secret outputs
4. consider stricter secret workflows if needed

## Interview Questions To Practice

### What is a DB subnet group?

An RDS-specific object that lists the subnets where AWS is allowed to place the
database.

### Why put RDS in isolated subnets?

To keep the database private and reachable only through controlled internal VPC
paths.

### Why use a source security group instead of a CIDR?

Because SG-to-SG rules better represent workload identity and are tighter than
broad CIDR-based access.

### What is the difference between KMS and Secrets Manager?

KMS manages keys. Secrets Manager stores secret values.

### Does sensitive output mean the secret never reaches state?

No. Sensitive output hides display, but the value can still exist in Terraform
state.

## Speakable Interview Answers

- "The database lives on RDS in isolated database subnets, not inside
  Kubernetes."
- "I used a DB subnet group across two AZs so the design stays private and
  Multi-AZ-ready."
- "The DB security group allows PostgreSQL only from the application security
  group."
- "App-to-RDS traffic inside the VPC uses the local route, not NAT."
- "KMS manages keys and Secrets Manager stores the credential document."

## Verification Commands

Useful checks from the environment root:

```bash
terraform state list | grep rds
terraform output | grep database
terraform plan | grep "No changes"
```
