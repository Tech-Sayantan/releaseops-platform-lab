# Jenkins Reference Pipeline

This directory is a studyable production-shaped Jenkins reference. It is not
connected to a running Jenkins controller in this lab.

## Files

- `Jenkinsfile.reference` is the tiny pipeline entry point owned by one service.
- `shared-library/vars/releaseOpsServicePipeline.groovy` contains the standard
  CI and release stages shared by many Java services.
- `shared-library/vars/openGitOpsPromotion.groovy` proposes a GitOps pull
  request. It does not deploy directly to Kubernetes.

## Required Jenkins Capabilities

The reference expects:

- ephemeral Linux agents with Java, Maven, Docker, Trivy, Syft, AWS CLI,
  GitHub CLI, and Python;
- Pipeline, Git, Credentials Binding, JUnit, SonarQube Scanner, Pipeline AWS,
  AnsiColor, and Workspace Cleanup plugins;
- a configured SonarQube installation named `sonarqube`;
- an AWS role with narrowly scoped ECR permissions;
- a GitHub App installation token stored as a Jenkins string credential;
- a Global Trusted Pipeline Library named `releaseops-shared`.

Production Jenkins should run its controller separately from build agents.
Builds execute on disposable agents so one build cannot contaminate another
with an old workspace, Docker layer, credential, or process.

## Why The Jenkinsfile Is Small

Copying 150 pipeline lines into 40 repositories creates 40 drifting pipelines.
The Jenkinsfile therefore supplies only service-specific values. The Shared
Library owns the reusable implementation. Updating a security scan or release
rule once can then improve every opted-in service.

The trade-off is blast radius. A broken Shared Library can break many teams at
once. Pin library versions, test changes, publish release notes, and roll out
major versions gradually.

## Approval Boundary

The pipeline publishes a candidate image and opens a GitOps pull request.
Protected-branch reviewers approve the desired-state change. Argo CD performs
the reconciliation after merge.

A Jenkins `input` step can provide a manual gate, but it is not a substitute
for protected branches, separation of duties, an auditable change record, and
restricted production credentials.
