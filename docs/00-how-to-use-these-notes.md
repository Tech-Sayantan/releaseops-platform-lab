# How To Use These Notes

Last updated: 2026-07-24

These notes are not only project documentation. They are interview revision
notes.

The goal is:

```text
read the note later
remember what we built
understand why we built it
answer interview questions clearly
debug production-style issues
```

## The Study Rule

For every topic, learn in this order:

1. What is it?
2. Why do real teams use it?
3. What did we build in this lab?
4. What Terraform resources created it?
5. What can go wrong in production?
6. How would I troubleshoot it?
7. How would I explain it in an interview?

Do not start by memorizing Terraform syntax. First understand the system
behavior.

## Sleepy Revision Method

If you are tired or revising quickly, read only these sections first:

- `What We Built`
- `What <service> Is`
- `One-Minute Mental Model`
- `Common Production Issues`
- `Interview Questions To Practice`
- `Verification Commands`

Then come back to the Terraform details.

## How Each Note Should Be Written Going Forward

Each deep-dive note should contain:

- beginner explanation
- real-world reason
- diagram or flow
- exact Terraform files touched
- explanation of every important variable
- explanation of every important resource argument
- expected plan/apply result
- production gotchas
- troubleshooting checklist
- interview-ready answers

This keeps the notes useful even when the hands-on work was done quickly or
while tired.

## Current Deep-Dive Notes

Recommended order:

1. [Production CI/CD, Release, And GitOps Deep Dive](24-cicd-release-gitops-deep-dive.md)
2. [CI/CD And GitOps Troubleshooting Playbook](25-cicd-troubleshooting-playbook.md)
3. [Helm, GitOps, And CI/CD Deep Dive](14-helm-gitops-cicd-deep-dive.md)
4. [Kubernetes Core Concepts Deep Dive](22-kubernetes-core-deep-dive.md)
5. [Kubernetes Troubleshooting Playbook](23-kubernetes-troubleshooting-playbook.md)
6. [Kubernetes Platform Guardrails](12-kubernetes-platform-guardrails.md)
7. [Terraform Backend Notes](02-terraform-backend-notes.md)
8. [Networking Deep Dive](03-networking-deep-dive.md)
9. [RDS Networking Notes](05-rds-networking-notes.md)
10. [ECR Deep Dive](07-ecr-deep-dive.md)
11. [SQS And DLQ Deep Dive](08-sqs-dlq-deep-dive.md)
12. [Real-World DevOps Tickets](06-real-world-devops-tickets.md)
13. [Interview Cheatsheet](04-interview-cheatsheet.md)

## Important Promise

If a note feels too short, too expert-level, or too fast, expand it. The notes
should not assume that the reader already knows AWS, Terraform, Kubernetes, or
production operations.

The best note is the one future-you can understand without reopening the chat.
