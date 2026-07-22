# Terraform And EKS Interview Map

This is the "explain the whole thing without getting lost" map.

## Terraform Concepts Used In This Lab

### Providers

Provider means Terraform plugin for an API.

In this lab:

- `aws` provider talks to AWS APIs
- `random` provider generated the database password

Interview phrase:

> Terraform itself does not know AWS. The AWS provider gives Terraform resource
> types and API behavior for AWS.

### Backend

Backend means where Terraform stores state.

This lab uses S3 remote state. The backend matters because Terraform state
contains the mapping between code and real resources.

Why local state is risky:

- easy to lose
- hard for teams to share
- no central locking
- may contain sensitive values

Why remote state is better:

- shared by team/pipeline
- versioned
- encrypted
- safer for CI/CD

### Modules

Module means reusable Terraform package.

This lab uses modules for:

- networking
- RDS
- ECR
- SQS
- IAM/GitHub OIDC
- EKS

Why modules matter:

- reduce repeated code
- create consistent naming/tagging
- hide internal resource details behind inputs/outputs
- make environment roots easier to read

Gotcha:

When you add or change a module source, run:

```bash
terraform init
```

Without init, Terraform may say the module is not installed.

### Variables

Variables are inputs. They make code configurable.

Example:

- VPC CIDR
- subnet CIDRs
- EKS version
- node size
- GitHub repo name

Interview phrase:

> I use variables for values that differ per environment, but I avoid making
> every tiny thing configurable because that creates unnecessary complexity.

### Outputs

Outputs expose useful values from Terraform.

Examples:

- VPC ID
- subnet IDs
- RDS endpoint
- ECR URLs
- EKS cluster name

Important gotcha:

A Terraform plan can show output-only changes. That updates Terraform state
outputs but does not necessarily change real AWS infrastructure.

### Locals

Locals are named expressions inside Terraform.

Use locals when:

- repeating computed names
- building common tags
- simplifying expressions

Do not overuse locals just to hide simple values.

### for_each

`for_each` creates multiple resources from a map or set.

Good use:

- create multiple ECR repositories
- create multiple add-ons
- create repeated rules by name

Why it is better than `count` in many cases:

- addresses are stable by key
- deleting one item does not shift all indexes

Example mental model:

```text
for_each = {
  api = {}
  worker = {}
}
```

Terraform creates:

```text
resource["api"]
resource["worker"]
```

### depends_on

Terraform usually builds dependency order from references.

Use `depends_on` only when Terraform cannot infer the dependency.

In EKS add-ons, explicit dependency can be useful because add-ons should wait
until the node group exists.

Gotcha:

Do not sprinkle `depends_on` everywhere. It can hide design problems and slow
plans.

### lifecycle

Lifecycle customizes resource behavior.

Common examples:

- `prevent_destroy` for critical resources
- `ignore_changes` for fields managed outside Terraform
- `create_before_destroy` for safer replacement when supported

Production gotcha:

`prevent_destroy` is useful for RDS, but it also blocks legitimate destroys.
Use it intentionally, not blindly.

## EKS Concepts Used In This Lab

### Control Plane

The control plane is the brain of Kubernetes.

It includes:

- API server
- scheduler
- controller managers
- etcd, managed by AWS in EKS

In EKS, AWS manages the control plane. You do not SSH into it.

### Worker Nodes

Worker nodes run pods.

In this lab:

- EKS managed node group
- one `t3.small` node for cost control

Production comparison:

- multiple node groups
- multiple AZs
- On-Demand and Spot split
- autoscaling
- stricter upgrade process

### kubelet

`kubelet` runs on each node. It talks to the Kubernetes API server and makes
sure containers are running as requested.

If node is NotReady, kubelet/node/network/bootstrap problems are possible.

### VPC CNI

The AWS VPC CNI gives pods IP addresses from the VPC.

This matters because EKS pods participate in VPC networking. Security groups,
routes, and subnet IP capacity become real Kubernetes concerns.

Gotcha:

Pod density can be limited by ENI/IP limits on the EC2 instance type.

### CoreDNS

CoreDNS resolves Kubernetes service names.

If CoreDNS is broken, symptoms look strange:

- app cannot resolve service names
- pod can ping IP but not DNS name
- internal service discovery fails

### kube-proxy

kube-proxy handles Kubernetes Service routing rules on nodes.

If kube-proxy is unhealthy:

- Service IP routing can break
- pods may be reachable directly but not through Service

### EBS CSI Driver

EBS CSI lets Kubernetes create and attach EBS volumes through PersistentVolumeClaims.

Our lab installed it and fixed IAM permissions through EKS Pod Identity.

Interview phrase:

> Kubernetes storage on AWS needs a bridge between Kubernetes PVC objects and
> AWS EBS APIs. That bridge is the EBS CSI driver.

### EKS Pod Identity

EKS Pod Identity gives AWS permissions to pods without storing AWS keys in
Kubernetes secrets.

It is used here for the EBS CSI controller.

Production use cases:

- app reads SQS
- app reads Secrets Manager
- app writes to S3
- external-dns updates Route53

## EKS Troubleshooting Ladder

Start from the symptom:

```text
User symptom -> Ingress/Service -> Pod -> Node -> Kubernetes system add-ons -> AWS networking/IAM
```

Useful commands:

```bash
kubectl get pods -A
kubectl describe pod <pod> -n <namespace>
kubectl logs <pod> -n <namespace> --previous
kubectl get nodes -o wide
kubectl describe node <node>
kubectl get events -A --sort-by=.lastTimestamp
```

Interview golden line:

> I try to avoid guessing. I start from Kubernetes events and logs, then move
> outward to node capacity, cluster add-ons, IAM, security groups, route tables,
> and AWS service health.
