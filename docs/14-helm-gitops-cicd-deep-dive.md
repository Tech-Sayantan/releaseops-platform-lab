# Helm, GitOps, And CI/CD Deep Dive

This note explains the reference delivery layer added for interview prep.

Use this chapter for Helm and repository-specific GitOps details. For the full
release pipeline, GitHub Actions, Jenkins, Shared Library, security, promotion,
rollback, and troubleshooting treatment, continue with:

- [Production CI/CD, Release, And GitOps Deep Dive](24-cicd-release-gitops-deep-dive.md)
- [CI/CD And GitOps Troubleshooting Playbook](25-cicd-troubleshooting-playbook.md)

## Why Helm Exists Here

Kubernetes YAML gets repetitive very quickly. Four Spring Boot services need
the same basic shape:

- Deployment
- Service
- ConfigMap
- probes
- resource requests and limits
- service account
- NetworkPolicy
- HorizontalPodAutoscaler
- PodDisruptionBudget
- optional Ingress
- optional Role and RoleBinding
- rolling-update controls and topology spreading

Without Helm, you copy-paste those manifests four times and then slowly drift.
One service gets a probe fix, another service misses it, and production becomes
inconsistent.

Helm solves that by turning the repeated pattern into a chart.

Think of the chart as a template:

- `charts/releaseops-service/templates/deployment.yaml` is the Deployment
  blueprint.
- `charts/releaseops-service/values.yaml` is the default configuration.
- `gitops/environments/dev/services/*.yaml` overrides values for each service.

Interview phrase:

> I used a reusable Helm chart because the services have a common runtime
> pattern. Service-specific values control image, environment variables, service
> account, and autoscaling, while the security and reliability defaults stay
> consistent.

### Important controller-ownership decisions

When HPA is enabled, the chart omits `Deployment.spec.replicas`. HPA owns the
replica count at runtime. Keeping a fixed replica value in Git can cause the
GitOps controller and HPA to repeatedly overwrite each other.

The chart also renders non-secret environment values into a ConfigMap and puts a
checksum of that ConfigMap in the Pod template. A configuration change therefore
creates a new Deployment revision instead of leaving old Pods with stale
environment variables.

Ingress and application RBAC are disabled by default:

- Ingress needs a controller and can create a paid cloud load balancer.
- Most application Pods do not need Kubernetes API permissions.

This is least privilege and cost control expressed in chart defaults.

## Why GitOps Exists Here

Terraform owns AWS infrastructure. Argo CD owns Kubernetes application desired
state.

That separation matters.

Terraform is good at AWS resources:

- VPC
- subnets
- IAM
- RDS
- ECR
- SQS
- EKS

Argo CD is good at Kubernetes reconciliation:

- Deployments
- Services
- NetworkPolicies
- HPAs
- app sync
- drift correction

If Terraform manages every app manifest, app releases become infrastructure
applies. That is usually too slow and risky. If Argo CD manages AWS resources,
it is the wrong tool.

Interview phrase:

> I separated infra and app delivery. Terraform creates the platform. Argo CD
> continuously reconciles Kubernetes application state from Git. This gives a
> clear ownership boundary and makes application promotion auditable.

## What The Argo CD Files Do

`gitops/argocd/releaseops-project.yaml`

This defines an Argo CD project. A project is a boundary. It says:

- which Git repos are allowed
- which clusters/namespaces are allowed
- which resource types can be deployed

In production, you would make this stricter. For example, you might not allow
all namespace resources. You would limit what the app team can deploy.

`gitops/argocd/releaseops-applicationset.yaml`

This is an ApplicationSet. It creates multiple Argo CD Applications from one
template. In our lab, the generator lists:

- `release-service`
- `deployment-worker`

The idea is simple: one reusable Helm chart, multiple service value files.

## CI Pipeline Design

There are three pipeline lanes.

### 1. Infrastructure Validation And Plan Pipelines

Files:

- `.github/workflows/infra-pr.yml`
- `.github/workflows/infra-plan-reference.yml`

The PR workflow runs credential-free formatting, initialization without the
remote backend, and validation. The trusted main-branch workflow can use OIDC
to access the real backend, save a plan, convert it to JSON, and run the Python
guard against dangerous deletes or replacements.

Why this matters:

Terraform can destroy real infrastructure. A production PR pipeline should
make the risk visible before merge. The most dangerous changes are replacements
of stateful or foundational resources:

- RDS instance
- EKS cluster
- VPC
- subnets
- NAT Gateway

Interview phrase:

> I do not treat `terraform plan` as decoration. The plan is an approval
> artifact. I also do not expose a write-capable AWS role to untrusted PR code.
> Static PR validation and trusted cloud planning have separate identity
> boundaries. For high-risk resources like RDS or EKS, I would require manual
> approval before applying the exact reviewed plan.

### 2. Application CI Pipeline

Files:

- `.github/workflows/app-ci-reference.yml`
- `.github/workflows/reusable-java-service-ci.yml`
- `.github/actions/release-metadata/action.yml`

The small caller invokes the reusable workflow. The reusable implementation can:

- checkout code
- set up Java
- run Maven checks
- run tests
- wait for a Sonar quality gate
- build image
- use GitHub OIDC for short-lived AWS credentials
- push an immutable candidate to ECR
- generate SBOM and provenance
- scan the candidate and return its digest

This repo includes the reference structure, not the full Java implementation.
For the interview, your explanation matters:

```text
clean -> compile -> unit tests -> integration tests -> quality scan -> image build -> image scan -> push immutable image -> update GitOps values
```

Use image digest promotion when possible.

Why digest is better than tag:

- tag can move
- digest is immutable
- digest gives exact provenance

### 3. GitOps Validation Pipeline

File: `.github/workflows/gitops-validate.yml`

Purpose:

- run `helm lint`
- render manifests with `helm template`
- catch template errors before Argo CD tries to sync

Interview phrase:

> I validate GitOps changes before merge because Argo CD should not be the
> first place we discover broken YAML.

## Common CI/CD Failure Scenarios

### Terraform Plan Fails To Acquire Lock

Likely causes:

- another pipeline is running
- local apply is still active
- stale lock after interrupted run

Fix:

- wait and confirm no active run
- inspect lock owner
- only then use force unlock

Never casually force unlock.

### GitHub Actions Cannot Assume AWS Role

Likely causes:

- OIDC provider missing
- trust policy has wrong repo or branch
- workflow lacks `id-token: write`
- role ARN secret is wrong

Debug:

- check workflow permissions
- check IAM role trust relationship
- check exact `sub` condition
- check branch name

### Argo CD OutOfSync

Do not panic. Ask:

- Did Git change?
- Did someone hotfix the cluster manually?
- Is this expected generated metadata?
- Is a controller mutating the object?

Fix:

- if Git is correct, sync
- if cluster hotfix is correct, commit it back to Git
- if controller mutation is expected, ignore that field carefully

### Pod Running Old Image

Likely causes:

- GitOps values not updated
- image tag reused
- imagePullPolicy issue
- Argo CD sync failed
- rollout paused

Best practice:

- publish immutable image
- deploy by digest
- track build SHA and digest in GitOps

## Production Gotchas

- Do not let every app team edit cluster-wide resources.
- Do not put secrets directly in Helm values.
- Do not use mutable `latest` tags.
- Do not let CI apply Terraform from every branch.
- Do not mix Terraform ownership and Argo CD ownership for the same object.
- Do not auto-prune in a learning lab unless you understand the blast radius.

## Banking Client Angle

For a banking client, speak in controls:

- PR review
- audit trail
- least privilege
- environment approval
- separation of duties
- rollback path
- immutable artifact
- traceability from commit to deployment
