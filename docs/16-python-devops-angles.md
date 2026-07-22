# Python For DevOps Angles

You asked how Python fits into this project. The honest answer is: Python is
not the main application language here; Java is the application language. But
Python is extremely useful in DevOps for automation, guardrails, reporting, and
glue scripts.

This repo includes three Python reference scripts:

- `scripts/eks_health_report.py`
- `scripts/terraform_plan_guard.py`
- `scripts/interview_drill_picker.py`

## Python Angle 1: Cluster Health Reporting

Script:

```bash
python scripts/eks_health_report.py
```

What it does:

- calls `kubectl get nodes -o json`
- calls `kubectl get pods -A -o json`
- parses JSON
- reports not-ready nodes
- reports unhealthy pods
- exits non-zero if something looks unhealthy

Why this is useful:

In real teams, small Python scripts often become operational helpers. For
example:

- pre-deployment checks
- daily health summaries
- incident triage helpers
- release readiness gates

Interview phrase:

> I used Python for automation around the platform. One example is a small EKS
> health reporter that calls `kubectl`, parses JSON, summarizes unhealthy pods
> or nodes, and returns a CI-friendly exit code.

## Python Angle 2: Terraform Plan Guard

Script:

```bash
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json
python scripts/terraform_plan_guard.py tfplan.json
```

What it does:

- reads Terraform plan JSON
- checks for high-risk resource types
- fails if the plan wants to delete or replace critical infrastructure

High-risk examples:

- RDS
- EKS cluster
- EKS node group
- VPC
- subnet
- NAT Gateway

Why this matters:

Terraform can be dangerous if the plan is not reviewed. A script can enforce
basic safety before a human approves.

Interview phrase:

> I wrote a Python guard that inspects Terraform plan JSON and blocks dangerous
> deletes or replacements for critical resources. It is not a replacement for
> review, but it is a useful automated safety net.

## Python Angle 3: Interview Drill Picker

Script:

```bash
python scripts/interview_drill_picker.py
```

This is a study helper. It randomly prints one scenario to practice.

It is intentionally simple, but it shows:

- Python CLI scripting
- clean structure
- fast local automation

## Production Python Ideas

If the interviewer asks where Python could be extended, say:

- query AWS Cost Explorer and flag rising lab cost
- compare Terraform state with live AWS resources for drift hints
- generate deployment reports from Argo CD and Kubernetes
- check ECR images for missing tags or old vulnerable images
- validate Helm values against team policy
- collect failed pod events into a Slack incident summary

## Common Python Interview Follow-Up

Question:

> Why not write everything in Bash?

Answer:

> Bash is fine for simple command chaining. I prefer Python when I need JSON
> parsing, structured logic, error handling, reusable functions, tests, or
> cleaner CI exit behavior. For DevOps, Python is useful when scripts grow from
> one-liners into maintainable tools.
