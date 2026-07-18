# RDS Networking Notes

Last updated: 2026-07-18

## What We Built

We added a dedicated Terraform module:

```text
infra/modules/rds
```

This module currently creates RDS networking, security, encryption, secrets, and
database resources:

- DB subnet group
- database security group
- application security group
- PostgreSQL ingress rule from application SG to database SG
- KMS key and alias
- Secrets Manager secret and secret version
- generated PostgreSQL master password
- private encrypted PostgreSQL RDS instance

The actual PostgreSQL database now exists.

## DB Subnet Group

RDS uses a DB subnet group to know where database resources are allowed to live.

Simple mental model:

```text
VPC = city
Subnets = neighborhoods
DB subnet group = approved database neighborhoods
RDS instance = actual database house
```

For this lab:

```text
releaseops-dev-db-subnet-group
  -> isolated database subnet in us-east-1a
  -> isolated database subnet in us-east-1b
```

Even if we initially create a small Single-AZ lab database, the subnet group is
ready for a multi-AZ database placement model.

Interview phrasing:

> "A DB subnet group is an RDS-specific object that defines which subnets RDS may
> use. I keep it pointed at isolated database subnets across at least two AZs, so
> the database stays private and multi-AZ-ready."

## Security Groups

We created two security groups:

```text
application security group
database security group
```

The database security group has an ingress rule:

```text
source: application security group
target: database security group
port:   TCP 5432
```

This means:

```text
Only AWS resources associated with the application SG can connect to the DB SG
on PostgreSQL port 5432.
```

It does not mean every resource in the VPC can connect.

## How Application Traffic Will Flow Later

Later, the Java service will receive database connection settings:

```text
DB_HOST=<rds-private-endpoint>
DB_PORT=5432
DB_NAME=releaseops
DB_USER=<from secret>
DB_PASSWORD=<from secret>
```

The network path will be:

```text
Java pod
  -> EKS node or pod network interface
  -> private VPC local route
  -> RDS private endpoint
  -> database security group
  -> PostgreSQL
```

This traffic does not need the Internet Gateway.
This traffic does not need NAT.

NAT is for outbound internet access from private subnets. App-to-RDS traffic
inside the same VPC uses the VPC local route.

## EKS Design Choice Still Pending

The `application` security group exists, but EKS is not created yet.

Later we must decide how app workloads receive the application network identity:

- node security group approach
- Security Groups for Pods
- hybrid SG plus Kubernetes NetworkPolicy approach

For the lab, the practical path is likely:

- use AWS security groups for the broad AWS boundary
- use Kubernetes NetworkPolicy for pod and namespace level control

## Production Gotchas

- Do not put RDS in public subnets.
- Do not make RDS publicly accessible unless there is a rare, documented reason.
- Avoid `0.0.0.0/0` ingress to PostgreSQL.
- Avoid broad VPC CIDR rules when a source security group is possible.
- Remember that a security group attaches to network interfaces, not directly to
  Java code.
- For EKS, be honest about whether the source SG belongs to nodes or pods.
- NetworkPolicy does not replace security groups; it complements them.

## Troubleshooting Checklist

If the app cannot connect to RDS later, check:

- RDS endpoint and port
- RDS status
- DB subnet group subnets
- route tables use local VPC route
- database security group inbound rule
- source security group on EKS node or pod ENI
- Kubernetes NetworkPolicy egress
- DNS resolution from the pod
- credentials and database/user/schema existence
- PostgreSQL connection pool limits

## KMS And Secrets Manager

KMS manages encryption keys. Secrets Manager stores secret values.

In this lab:

```text
KMS key
  -> encrypts database-related secret data
  -> encrypts RDS storage

Secrets Manager secret
  -> stores username/password/database JSON
```

The secret contains a JSON document shaped like:

```json
{
  "username": "releaseops_admin",
  "password": "<generated>",
  "database": "releaseops"
}
```

The password is not exposed as a Terraform output.

Important Terraform state warning:

```text
random_password.database_master.result
```

is stored in Terraform state because Terraform generated it. The output hides
the value, but state still contains it. This is why remote state must be
encrypted, access-controlled, and treated as sensitive.

## RDS Instance

The lab RDS instance is:

```text
module.rds.aws_db_instance.postgres
```

It is configured as:

- PostgreSQL
- private endpoint
- encrypted storage
- database subnet group in isolated DB subnets
- database security group attached
- Single-AZ for lab cost control
- short backup retention
- deletion protection disabled for teardown
- final snapshot skipped for teardown speed

Safe connection metadata is exposed through Terraform outputs:

```text
database_endpoint
database_port
database_name
```

The password is intentionally not exposed.

Production comparison:

- enable Multi-AZ
- enable deletion protection
- keep a final snapshot on destroy
- longer backup retention/PITR
- consider RDS Proxy for connection pooling
- monitor CPU, memory, storage, connections, and latency
- use stricter secret rotation and access policies
