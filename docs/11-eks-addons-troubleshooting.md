# EKS Add-Ons And Troubleshooting

Last updated: 2026-07-20

## What We Added

After the EKS cluster and node group were running, we added the managed add-ons
that make the cluster usable for real workloads:

```text
vpc-cni
coredns
kube-proxy
aws-ebs-csi-driver
eks-pod-identity-agent
```

Think of the cluster like a new apartment. The EKS control plane and worker node
give you the building and rooms. Add-ons give you electricity, plumbing, name
lookup, and storage wiring.

## What Each Add-On Does

`vpc-cni`

This handles Pod networking on AWS. In EKS, Pods can get IP addresses from the
VPC subnet range. That is different from many local Kubernetes setups where Pod
networking is an overlay. VPC CNI is the reason a Pod can behave like a first
class network citizen inside the AWS VPC.

`coredns`

This is Kubernetes DNS. When one service calls another service by name, CoreDNS
resolves that name. Without it, applications would have to talk using IPs, and
that breaks quickly because Pod IPs are temporary.

`kube-proxy`

This supports Kubernetes Service networking. When traffic goes to a Service,
Kubernetes has to route that traffic to one of the matching Pods. kube-proxy is
part of that traffic steering path.

`aws-ebs-csi-driver`

This lets Kubernetes create and attach EBS volumes for PersistentVolumes. It is
needed when Pods require durable block storage. We may not create EBS volumes
immediately because of cost, but production clusters normally need a working
storage driver.

`eks-pod-identity-agent`

This lets Pods receive AWS credentials through EKS Pod Identity. It is a safer
way to give AWS permissions to a specific Kubernetes workload without putting
all permissions on the EC2 node role.

## Terraform Pattern We Used

We defined the add-ons once in a local map:

```hcl
locals {
  cluster_addons = {
    vpc-cni                = {}
    coredns                = {}
    kube-proxy             = {}
    aws-ebs-csi-driver     = {}
    eks-pod-identity-agent = {}
  }
}
```

Then Terraform loops over the map using `for_each`.

The important interview point:

> `for_each` lets me create one resource per named item. That is better than
> copy-pasting five almost identical add-on resources.

We also used:

```hcl
data "aws_eks_addon_version" "this" {
  for_each = local.cluster_addons

  addon_name         = each.key
  kubernetes_version = aws_eks_cluster.this.version
  most_recent        = true
}
```

That means Terraform asks AWS:

```text
For this Kubernetes version, what is the latest compatible version of this add-on?
```

Then the add-on uses that returned version.

## Bug 1: Unsupported `most_recent`

At first, `most_recent` was placed directly inside `aws_eks_addon`.

That failed because `aws_eks_addon` does not accept `most_recent` as an argument.
The fix was to move `most_recent` into the data source:

```text
aws_eks_addon_version
```

Simple memory hook:

```text
Data source chooses the version.
Resource installs the version.
```

## Bug 2: Apply Timed Out

Terraform apply timed out while creating the EKS add-ons.

This does not always mean AWS failed.

With cloud resources, Terraform is only the waiter. AWS may continue the real
operation in the background after your terminal command times out.

So the first troubleshooting step was not to re-apply blindly. The first step
was to inspect live state:

```bash
aws eks list-addons --cluster-name releaseops-dev-eks --region us-east-1
terraform state list | grep addon
kubectl get pods -n kube-system -o wide
```

## What We Found

The add-ons existed, but the EBS CSI controller was not healthy.

The controller Pods were crashing with a credential-related error:

```text
failed to refresh cached credentials, no EC2 IMDS role found
```

In plain English:

```text
The EBS CSI controller was running as a Kubernetes Pod.
It needed AWS permissions.
But it had no IAM identity attached.
So it could not call EC2 APIs.
```

## Why EBS CSI Needs AWS Permissions

Kubernetes understands this request:

```text
I need persistent storage.
```

AWS understands this action:

```text
Create and attach an EBS volume.
```

The EBS CSI driver is the bridge between those two worlds.

When a Pod needs storage, the driver may need to call AWS APIs like:

```text
DescribeAvailabilityZones
CreateVolume
AttachVolume
DetachVolume
DeleteVolume
```

Those AWS API calls require IAM permissions.

## Why Not Put EBS Permissions On The Node Role?

That would work, but it is broader than needed.

The node role belongs to the EC2 worker node. Many Pods can run on that node.
If we put EBS permissions on the node role, we are saying:

```text
The node has these permissions.
```

With Pod Identity, we say something tighter:

```text
Only this Kubernetes service account gets this IAM role.
```

In our lab:

```text
kube-system/ebs-csi-controller-sa
```

gets:

```text
releaseops-dev-ebs-csi-role
```

That is a cleaner production-style pattern.

## The Recovery

We added a dedicated IAM role trusted by EKS Pod Identity:

```text
releaseops-dev-ebs-csi-role
```

The trust principal is:

```text
pods.eks.amazonaws.com
```

The role has the AWS managed policy:

```text
AmazonEBSCSIDriverPolicy
```

Then we associated that role with the EBS CSI service account:

```text
namespace: kube-system
service account: ebs-csi-controller-sa
```

Terraform resource:

```text
aws_eks_pod_identity_association.ebs_csi
```

We restarted only the EBS CSI controller deployment:

```bash
kubectl rollout restart deployment ebs-csi-controller -n kube-system
kubectl rollout status deployment ebs-csi-controller -n kube-system --timeout=180s
```

After that, both controller Pods became healthy:

```text
ebs-csi-controller ... 6/6 Running
```

## Final Verification

Terraform:

```text
No changes. Your infrastructure matches the configuration.
```

EKS add-ons:

```text
aws-ebs-csi-driver
coredns
eks-pod-identity-agent
kube-proxy
vpc-cni
```

Kubernetes system Pods:

```text
aws-node                 Running
coredns                  Running
ebs-csi-controller       6/6 Running
ebs-csi-node             Running
eks-pod-identity-agent   Running
kube-proxy               Running
```

## Interview Story

You can say:

> While adding EKS managed add-ons, Terraform timed out. I did not immediately
> rerun apply blindly. First I checked Terraform state, AWS add-on status, and
> kube-system Pods. The add-ons existed, but the EBS CSI controller was in
> CrashLoopBackOff because it had no AWS credentials. I fixed it by creating a
> dedicated IAM role for EBS CSI and attaching it to the
> `ebs-csi-controller-sa` service account using EKS Pod Identity. After
> restarting the controller, the Pods became healthy and Terraform showed no
> drift.

That answer shows three senior signals:

- you understand async AWS operations and Terraform timeouts
- you troubleshoot from evidence, not guesswork
- you prefer least-privilege workload identity over broad node permissions

## Production Gotchas

Do not install add-ons blindly without version awareness. Add-on versions must
match the Kubernetes cluster version.

Do not give every workload broad permissions through the node role. Prefer Pod
Identity or IRSA-style workload identity.

Do not ignore `kube-system` Pod health. A cluster can look `ACTIVE` in AWS while
important Kubernetes components are unhealthy.

Do not create PVC smoke tests casually in a cost-sensitive lab. A PVC may create
an actual paid EBS volume.
