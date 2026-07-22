# Cleanup Runbook

Do not run this casually. This is the teardown map for when Tan says the lab is
finished.

## Goal

Remove paid AWS resources safely:

- EKS node group and cluster
- NAT Gateway and Elastic IP
- RDS
- ECR repositories
- SQS queues
- KMS key alias/key scheduling
- Secrets Manager secret
- VPC and subnets
- Kubernetes-created load balancers or volumes if any were created

## Before Terraform Destroy

Check Kubernetes-created AWS resources first:

```bash
kubectl get ingress -A
kubectl get svc -A
kubectl get pvc -A
```

Why:

Load balancers and EBS volumes can be created by Kubernetes controllers. If
they exist, delete the Kubernetes objects first and wait for AWS cleanup.

## Terraform Destroy Order

Run from:

```bash
cd /Users/sayantanchowdhury/Documents/Codex/releaseops-platform-lab/infra/envs/dev
```

Commands:

```bash
terraform plan -destroy
terraform destroy
```

Review carefully for:

- RDS final snapshot behavior
- ECR repository force delete behavior
- KMS key deletion schedule
- VPC dependency errors

## Bootstrap Cleanup

The backend bucket contains Terraform state, so do not destroy it first.

After main infra is destroyed and state is no longer needed:

```bash
cd /Users/sayantanchowdhury/Documents/Codex/releaseops-platform-lab/bootstrap
terraform plan -destroy
terraform destroy
```

S3 versioned buckets may need object versions removed before bucket deletion.
If destroy fails, inspect bucket versions and delete them intentionally.

## Interview Phrase

> I treated cleanup as part of the project. In cloud labs, teardown is not an
> afterthought because idle EKS, NAT, RDS, load balancers, and volumes can keep
> generating cost.
