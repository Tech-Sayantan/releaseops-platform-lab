# Final Command Walkthrough

This is the compact command list to revise before the interview. You do not
need to run everything now. Use it to understand what each layer proves.

## Terraform State

Run from:

```bash
cd /Users/sayantanchowdhury/Documents/Codex/releaseops-platform-lab/infra/envs/dev
```

Commands:

```bash
terraform fmt -check -recursive
terraform validate
terraform plan
terraform state list
terraform output
```

What to say:

> Terraform is the source of truth for AWS infrastructure. I validate format,
> validate provider/resource syntax, inspect the plan before apply, and use
> state/output to understand what Terraform currently manages.

## EKS Access

```bash
aws eks update-kubeconfig --region us-east-1 --name releaseops-dev-eks
kubectl get nodes
kubectl get pods -A
```

What to say:

> `aws eks update-kubeconfig` writes local Kubernetes access configuration.
> `kubectl get nodes` proves the worker node joined the cluster. `kubectl get
> pods -A` checks system and app namespaces.

## Kubernetes Platform Guardrails

```bash
kubectl get ns releaseops observability argocd
kubectl get serviceaccount -n releaseops
kubectl describe resourcequota -n releaseops
kubectl describe limitrange -n releaseops
```

What to say:

> Namespaces separate workloads, service accounts prepare identity boundaries,
> ResourceQuota prevents namespace-level resource abuse, and LimitRange applies
> default request/limit behavior.

## Helm Reference

Run from repo root:

```bash
helm lint charts/releaseops-service
helm template release-service charts/releaseops-service -f gitops/environments/dev/services/release-service-values.yaml
```

What to say:

> Helm lets me package repeated Kubernetes deployment patterns once and provide
> service-specific values for each app.

## GitOps Reference

Read:

```text
gitops/argocd/releaseops-project.yaml
gitops/argocd/releaseops-applicationset.yaml
```

What to say:

> Argo CD watches Git and reconciles Kubernetes state. ApplicationSet lets one
> template create multiple applications.

## Python Reference

Run from repo root:

```bash
python scripts/interview_drill_picker.py
```

Read:

```text
scripts/terraform_plan_guard.py
scripts/eks_health_report.py
```

What to say:

> I used Python for DevOps automation: health reporting, Terraform plan safety,
> and repeatable interview drills.
