# Real-World Terraform And AWS DevOps Tickets

This note is for interview preparation. It explains what Terraform and AWS work
usually looks like inside a real DevOps, platform, SRE, or cloud infrastructure
team.

The important thing to understand is this: in real companies, DevOps work is
not only "create EKS" or "write Terraform." Most tickets are smaller changes
around access, networking, security, cost, reliability, releases, and fixing
broken automation. The big projects happen too, but they are less frequent.

## How Infrastructure Work Usually Arrives

A DevOps engineer normally receives work through one of these routes:

- A developer team needs infrastructure for a new service.
- A production issue needs debugging.
- A security team raises a finding.
- A cloud cost report shows waste.
- A compliance or audit team needs evidence or policy changes.
- A product team needs a new environment or scaling improvement.
- A CI/CD pipeline fails and blocks delivery.
- A cloud provider or Kubernetes version upgrade becomes due.
- A platform roadmap item needs to be implemented.

So the job is a mix of planned work, ticket work, review work, and incident
work.

## Regular Terraform And AWS Tasks

These are the normal, repeated tickets a DevOps team handles.

### Terraform PR Review

Someone opens a pull request changing Terraform code. The DevOps engineer
checks:

- Does the code follow the module structure?
- Are variables typed properly?
- Are names and tags correct?
- Is the Terraform plan safe?
- Is anything being destroyed or replaced unexpectedly?
- Are secrets accidentally hardcoded?
- Is the change too broad for the ticket?

Interview angle: a senior engineer does not just read the code. They read the
plan like a contract. If the plan says `1 to destroy`, `1 to replace`, or a
critical resource is changing, they slow down and ask why.

### Plan And Apply Workflow

A common ticket is: "Please apply the approved Terraform change in dev/stage."

Typical flow:

1. Pull the latest code.
2. Run `terraform fmt`.
3. Run `terraform validate`.
4. Run `terraform plan`.
5. Review add/change/destroy carefully.
6. Get approval if required.
7. Run `terraform apply`.
8. Verify in AWS.
9. Update the ticket with evidence.

Production gotcha: never treat `terraform apply` like a blind command. The
plan can reveal replacements, drift, IAM changes, or accidental deletion.

### State Lock Or Backend Issues

Example ticket: "Terraform is stuck because the state is locked."

Common causes:

- Someone cancelled an apply.
- A CI job failed midway.
- Two people tried to run Terraform at the same time.
- The backend cannot reach S3 or the lock mechanism.

Senior response:

- First check whether another real apply is still running.
- Do not unlock immediately.
- Identify the lock owner and timestamp.
- Only force unlock when you are sure no apply is active.

Interview line: "I treat state unlock as a production-risk action, because two
simultaneous applies can corrupt state or create conflicting infrastructure."

### Drift Detection

Drift means AWS and Terraform code do not match anymore.

Example: Terraform says a security group allows only port 5432 from the app
security group, but someone manually added `0.0.0.0/0` in the AWS console.

What the team does:

- Run a refresh/plan.
- Identify whether drift was intentional or accidental.
- If intentional, bring the change into code.
- If accidental, let Terraform revert it.
- Add guardrails if the drift keeps happening.

Production gotcha: not all drift is bad. During an incident, someone may make
a temporary manual change. The problem is leaving that change undocumented.

### IAM Permission Requests

Example ticket: "GitHub Actions needs permission to push images to ECR."

The DevOps engineer checks:

- Which workload needs access?
- Which AWS account and region?
- Which exact actions are required?
- Can we scope the permissions to one repository or one resource?
- Can we use OIDC or IRSA instead of long-lived access keys?

Good pattern:

- Use least privilege.
- Prefer role assumption.
- Avoid static AWS keys.
- Add clear IAM policy names and tags.

Interview gotcha: `AdministratorAccess` may unblock a pipeline quickly, but it
creates a security problem. A senior engineer scopes the permission.

### Security Group Changes

Example ticket: "Allow the application to connect to PostgreSQL."

Bad solution:

- Open RDS port 5432 from `0.0.0.0/0`.

Good solution:

- Create an application security group.
- Create a database security group.
- Allow PostgreSQL only from the application security group to the database
  security group.

This is exactly the pattern we built in this lab.

Production gotcha: security group rules should describe application flow, not
random IP guessing. Source security group rules are cleaner inside the same
VPC.

### VPC, Subnet, Route Table, NAT, And Endpoint Work

Regular tickets include:

- Add private subnets for a new environment.
- Add database subnets for RDS.
- Fix a route table association.
- Add a VPC endpoint for S3, ECR, CloudWatch, or Secrets Manager.
- Reduce NAT Gateway cost.
- Check why a private workload cannot reach AWS APIs.

Common debugging question:

"A pod in a private subnet cannot pull an image or read a secret. What do you
check?"

Answer path:

1. Does the subnet have a route to NAT or the required VPC endpoints?
2. Does DNS resolution work?
3. Does the node or pod IAM role have permission?
4. Does the security group or network policy block traffic?
5. Is the endpoint policy too restrictive?

### RDS Tickets

Common RDS work:

- Create a DB subnet group.
- Create or update database security groups.
- Enable encryption with KMS.
- Store credentials in Secrets Manager.
- Increase storage.
- Enable backup retention.
- Tune parameters.
- Investigate connection errors.
- Check CPU, memory, connections, locks, and slow queries.

Important idea: RDS is usually outside Kubernetes but inside the same VPC. The
application runs in EKS, and the database runs as an AWS-managed service. This
is more realistic than running a production database as a Kubernetes
StatefulSet for most teams.

### ECR And Image Lifecycle Tickets

Common tasks:

- Create ECR repositories.
- Add lifecycle policies to delete old images.
- Allow CI to push images.
- Allow EKS nodes or pods to pull images.
- Debug image pull errors.

Production gotcha: old images can quietly cost money and make rollbacks messy.
Lifecycle policy is not fancy work, but it is very real platform work.

### CI/CD Pipeline Issues

Common tickets:

- GitHub Actions cannot assume the AWS role.
- Terraform plan fails in CI.
- Docker build fails.
- Maven test or SonarQube stage fails.
- Helm chart template fails.
- Argo CD is out of sync.
- Deployment succeeded but pods are crash-looping.

Senior debugging approach:

- First identify which stage failed.
- Separate code failure, build failure, infra failure, deployment failure, and
  runtime failure.
- Check logs and permissions.
- Fix the smallest layer that explains the failure.

### Cost Review Tickets

Common cost tickets:

- NAT Gateway cost is high.
- RDS is oversized.
- EKS nodes are idle.
- Unused EBS volumes exist.
- CloudWatch logs are retained forever.
- Old ECR images are piling up.
- Data transfer is unexpectedly high.

Cost-aware DevOps is very interview-friendly because it shows production
maturity. Building something is one skill. Keeping it reliable and affordable
is the senior skill.

## Occasional Bigger Projects And Change Requests

These do not happen every day, but they are important and often senior-level.

### New Environment Build

Example: "Create a new staging environment."

Work involved:

- New Terraform workspace or environment folder.
- New backend state key.
- New VPC or shared VPC decision.
- Subnets, routes, endpoints, NAT.
- RDS, EKS, ECR, IAM roles.
- CI/CD environment mapping.
- Monitoring and alerts.
- Cost and access controls.

Interview gotcha: environment separation is not only naming. State, IAM,
networking, secrets, and blast radius must be separated carefully.

### Import Manual Infrastructure Into Terraform

Example: "This RDS instance was created manually. Bring it under Terraform."

Work involved:

- Write matching Terraform code.
- Run import.
- Compare state and plan.
- Fix differences until plan is safe.
- Avoid accidental replacement.

Senior warning: Terraform import is not magic. It imports state, not code.
You still need correct Terraform configuration.

### EKS Version Upgrade

Example: "Upgrade EKS from one minor version to the next."

Work involved:

- Check Kubernetes API deprecations.
- Upgrade control plane.
- Upgrade node groups.
- Upgrade add-ons.
- Test workloads.
- Check ingress, autoscaling, CSI drivers, and observability.

Production gotcha: the cluster version is only one part. Add-ons and manifests
can break if deprecated APIs are still used.

### Multi-Account Or Landing Zone Work

Example: "Separate dev, stage, and prod into different AWS accounts."

Work involved:

- AWS Organizations.
- Account vending.
- IAM Identity Center or federation.
- Cross-account roles.
- Central logging.
- Guardrails.
- Network connectivity.
- CI/CD role assumption per account.

This is usually senior platform engineering work.

### GitOps Rollout

Example: "Move Kubernetes deployments from manual Helm commands to Argo CD."

Work involved:

- Define Git repository structure.
- Install and secure Argo CD.
- Create projects and applications.
- Decide promotion flow.
- Manage secrets safely.
- Add sync policies.
- Train teams on GitOps.

Production gotcha: GitOps is powerful only if Git remains the source of truth.
Manual cluster changes create drift again.

### Disaster Recovery And Backup Improvements

Example: "Improve recovery for the database and cluster."

Work involved:

- RDS backup retention.
- Point-in-time recovery.
- Snapshot restore testing.
- Multi-AZ decision.
- Runbooks.
- Recovery time objective and recovery point objective.

Interview angle: do not just say "we enabled backup." Say how restore was
tested. Backup without restore testing is hope, not reliability.

### Observability Platform Rollout

Example: "Add logs, metrics, traces, and alerts for the platform."

Work involved:

- Metrics collection.
- Central logs.
- Distributed tracing.
- Dashboards.
- SLOs and alerts.
- Runbooks for common failures.

Production gotcha: too many alerts become noise. Good alerts are actionable
and tied to user impact.

## How A Senior DevOps Engineer Handles A Ticket

For almost any Terraform or AWS ticket, use this mental checklist:

1. Understand the business reason.
2. Identify the affected environment.
3. Check current Terraform code and current AWS state.
4. Think about blast radius.
5. Make the smallest safe change.
6. Run format, validate, and plan.
7. Review destroy/replace actions carefully.
8. Get approval when needed.
9. Apply in the right environment.
10. Verify using AWS, app logs, metrics, or connectivity tests.
11. Update docs, ticket notes, and runbooks.
12. Clean up temporary access or temporary resources.

This is the difference between "I know Terraform commands" and "I can operate
production infrastructure."

## Interview Story Template

Use this structure when answering scenario questions:

```text
In one project, we had a requirement to <goal>.
The risk was <security/cost/downtime/blast-radius risk>.
I changed <Terraform module/resource/pipeline>.
Before applying, I checked the plan for <destroy/replace/IAM/networking>.
After apply, I verified <AWS state/application behavior/metrics>.
One production gotcha was <real issue>.
The fix was <practical fix>.
```

## Examples From This Lab

The work we have already done maps directly to real tickets:

- Backend bootstrap maps to "set up safe remote Terraform state."
- VPC module maps to "create reusable network foundation."
- Public/private/database subnet split maps to "separate internet-facing,
  application, and data layers."
- NAT Gateway maps to "allow private workloads to reach the internet."
- S3 Gateway VPC Endpoint maps to "reduce NAT usage for S3 traffic."
- RDS DB subnet group maps to "place RDS in isolated database subnets."
- KMS and Secrets Manager map to "encrypt data and avoid hardcoded secrets."
- Application security group to database security group rule maps to "allow
  app-to-database traffic safely."

## Speakable Interview Lines

- "I always review the Terraform plan before apply, especially destroy and
  replace actions."
- "For database access, I prefer security-group-to-security-group rules instead
  of opening CIDR ranges."
- "For private workloads, I check NAT routes, VPC endpoints, DNS, IAM, and
  security policies when debugging AWS API access."
- "I treat Terraform state as production-critical. I avoid manual state changes
  unless the situation is understood and documented."
- "Cost is part of production readiness. NAT Gateway, RDS, EKS nodes, logs, and
  image retention need active review."
- "For secrets, I avoid plaintext values in code and prefer Secrets Manager or
  another approved secret store, with IAM-scoped access."
- "For big changes, I think in terms of blast radius, rollback, verification,
  and ownership."
