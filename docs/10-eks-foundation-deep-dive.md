# EKS Foundation Deep Dive

Last updated: 2026-07-19

## What We Built

We created the first real Kubernetes platform layer for the ReleaseOps lab.

Terraform module:

```text
infra/modules/eks
```

Root module call:

```text
infra/envs/dev/main.tf
```

Current EKS resources:

```text
module.eks.aws_eks_cluster.this
module.eks.aws_eks_node_group.default
module.eks.aws_iam_role.cluster
module.eks.aws_iam_role.node
module.eks.aws_iam_role_policy_attachment.cluster_policy
module.eks.aws_iam_role_policy_attachment.node_worker_policy
module.eks.aws_iam_role_policy_attachment.node_ecr_policy
module.eks.aws_iam_role_policy_attachment.node_cni_policy
```

Verified live AWS state:

```text
EKS cluster: releaseops-dev-eks
Cluster status: ACTIVE
Kubernetes version: 1.34
Node group: releaseops-dev-default
Node group status: ACTIVE
Node capacity type: ON_DEMAND
Node instance type: t3.small
Node scaling: min 1, desired 1, max 2
```

Verified Kubernetes node:

```text
ip-10-40-2-87.ec2.internal   Ready
```

## EKS In One Simple Picture

EKS has two main parts:

```text
AWS-managed control plane
        |
        | schedules and manages Kubernetes objects
        v
EC2 worker nodes
        |
        | run Pods
        v
Application containers
```

The control plane is the brain.

The worker nodes are the machines.

Pods are the actual running workloads.

## Control Plane

Terraform resource:

```text
aws_eks_cluster.this
```

The EKS control plane is managed by AWS. It includes the Kubernetes API server
and the internal control-plane components needed to run Kubernetes.

You do not SSH into the control plane. You talk to it with:

```bash
kubectl
```

or with AWS APIs.

In this lab, the cluster name is:

```text
releaseops-dev-eks
```

Interview version:

> The EKS control plane is managed by AWS. I create and configure it with
> Terraform, but AWS runs the API server and control-plane components.

## Worker Nodes

Terraform resource:

```text
aws_eks_node_group.default
```

Worker nodes are EC2 instances that join the EKS cluster.

Your application Pods run on worker nodes, not on the control plane.

Our lab node group:

```text
releaseops-dev-default
```

Current scaling:

```text
min     = 1
desired = 1
max     = 2
```

This means one node normally runs. AWS may scale to two nodes only if the node
group desired size is changed by automation or manually.

For the lab, we use:

```text
t3.small
```

That keeps cost controlled while still giving us a real EKS node.

Production version:

> In production I would usually run multiple worker nodes across multiple AZs,
> separate node groups for different workload types, and use stronger capacity
> planning. For this lab, a single small managed node group is a cost-controlled
> starting point.

## Control Plane IAM Role

Terraform resource:

```text
aws_iam_role.cluster
```

This role is trusted by:

```text
eks.amazonaws.com
```

That means AWS EKS service can assume this role.

Attached policy:

```text
AmazonEKSClusterPolicy
```

This gives the EKS control plane the AWS permissions it needs to operate.

Interview version:

> The cluster IAM role is used by the AWS-managed EKS control plane. Its trust
> policy allows the EKS service to assume the role, and the attached cluster
> policy gives EKS the required AWS permissions.

## Node IAM Role

Terraform resource:

```text
aws_iam_role.node
```

This role is trusted by:

```text
ec2.amazonaws.com
```

That means EC2 worker nodes can assume this role.

Attached policies:

```text
AmazonEKSWorkerNodePolicy
AmazonEC2ContainerRegistryReadOnly
AmazonEKS_CNI_Policy
```

What they do:

- `AmazonEKSWorkerNodePolicy`: lets the node work with EKS and join the cluster.
- `AmazonEC2ContainerRegistryReadOnly`: lets the node pull container images
  from ECR.
- `AmazonEKS_CNI_Policy`: lets the VPC CNI manage network interfaces and Pod IPs.

Interview version:

> The node IAM role is used by EC2 worker nodes. It lets nodes register with the
> cluster, pull images from ECR, and support VPC CNI networking.

## Private Subnet Placement

Our node group uses:

```text
module.networking.private_subnet_ids
```

That means worker nodes are launched in private application subnets.

Why?

Worker nodes should not normally be directly public. Public traffic should come
through an Application Load Balancer or another controlled ingress path.

Current private subnet IDs:

```text
subnet-08b1d4ebab9163ac2
subnet-0d0fd526b3b857dbc
```

The node that joined has private IP:

```text
10.40.2.87
```

No public node IP was shown, which matches our private-subnet design.

## EKS API Endpoint Access

The Kubernetes API endpoint is the front door of the cluster.

`kubectl` talks to this endpoint.

Current lab setting:

```text
endpoint_private_access = true
endpoint_public_access  = true
public_access_cidrs     = ["203.92.62.70/32"]
```

Meaning:

- private access is enabled from inside the VPC
- public access is enabled so Tan can use `kubectl` from laptop
- public access is restricted to one current public IP

This is better than leaving the endpoint open to the whole internet.

Production comparison:

> In stricter production setups, the public endpoint may be disabled entirely,
> or restricted to VPN, bastion, office CIDR, or a controlled access path.

## Managed Node Group

We used an EKS managed node group instead of self-managed EC2 nodes.

Managed node groups are useful because AWS handles much of the node lifecycle:

- node provisioning
- node bootstrap
- joining the cluster
- health integration with EKS
- rolling updates

Production teams may still use Karpenter, self-managed nodes, Bottlerocket,
custom AMIs, Spot pools, GPU node groups, or workload-specific node groups.

For this lab, managed node group is the right first step.

## Why The Plan Had 8 Resources

The first EKS plan showed:

```text
Plan: 8 to add, 0 to change, 0 to destroy.
```

Those 8 resources were:

```text
1. EKS cluster
2. EKS managed node group
3. EKS cluster IAM role
4. EKS node IAM role
5. Cluster policy attachment
6. Node worker policy attachment
7. Node ECR policy attachment
8. Node CNI policy attachment
```

No existing VPC, RDS, ECR, SQS, or IAM/OIDC resource was replaced.

This is exactly the kind of plan review an interviewer wants to hear:

> I checked that the EKS plan was additive only: 8 to add, 0 to change, 0 to
> destroy. That confirmed Terraform would not replace existing networking or
> database resources.

## Kubeconfig

We configured local `kubectl` access with:

```bash
aws eks update-kubeconfig \
  --name releaseops-dev-eks \
  --region us-east-1 \
  --alias releaseops-dev-eks
```

This updated:

```text
/Users/sayantanchowdhury/.kube/config
```

After that, this worked:

```bash
kubectl get nodes -o wide
```

The node status was:

```text
Ready
```

That proves:

- AWS authentication worked
- the Kubernetes API endpoint was reachable
- the node group joined the cluster
- the node became schedulable

## Common EKS Failure Modes

### Cluster Creates But Nodes Do Not Join

Possible causes:

- node IAM role missing required policies
- worker subnets do not have route to required AWS services
- security group rules block node-to-control-plane traffic
- node AMI/bootstrap issue
- wrong cluster name or node group config

First checks:

```bash
aws eks describe-nodegroup \
  --cluster-name releaseops-dev-eks \
  --nodegroup-name releaseops-dev-default \
  --region us-east-1
```

```bash
kubectl get nodes
```

### Nodes Are NotReady

Possible causes:

- VPC CNI issue
- kubelet issue
- insufficient IAM permissions
- node cannot reach API server
- IP exhaustion in subnet

First checks:

```bash
kubectl describe node <node-name>
kubectl get pods -n kube-system
```

### Pods Stay Pending

Possible causes:

- not enough CPU/memory
- no matching node selector/taint toleration
- volume cannot attach
- image pull issue
- scheduling constraints too strict

First checks:

```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl get events -A --sort-by=.metadata.creationTimestamp
```

### ImagePullBackOff From ECR

Possible causes:

- image tag does not exist
- node role cannot read ECR
- wrong ECR repo URL
- image architecture mismatch
- private registry auth issue

In our lab, the node role has:

```text
AmazonEC2ContainerRegistryReadOnly
```

That is required for pulling from ECR.

### Cannot Reach Kubernetes API From Laptop

Possible causes:

- public endpoint disabled
- current laptop public IP changed
- public access CIDR no longer matches
- AWS auth/kubeconfig issue

If your home IP changes, update:

```text
eks_cluster_endpoint_public_access_cidrs
```

Then run Terraform plan/apply.

## Cost Warning

EKS is now one of the major bill contributors in this lab.

Current paid EKS-related resources:

- EKS control plane
- one `t3.small` EC2 worker node
- EBS root volume for the node

Other existing paid resources:

- NAT Gateway
- RDS PostgreSQL
- KMS key
- Secrets Manager secret

Cost-control rule:

> Do not leave this cluster idle for days. Continue the lab or tear it down.

## Interview Story

Use this:

> I created an EKS cluster with Terraform using a custom module. The EKS control
> plane uses its own IAM role and runs as an AWS-managed Kubernetes control
> plane. Worker nodes run in private application subnets through an EKS managed
> node group with a separate EC2 node IAM role. The node role has permissions to
> join EKS, pull from ECR, and support VPC CNI networking. For lab access, the
> public API endpoint is enabled but restricted to my current `/32` public IP.
> I verified the cluster and node group were ACTIVE and confirmed with
> `kubectl get nodes` that the node was Ready.

