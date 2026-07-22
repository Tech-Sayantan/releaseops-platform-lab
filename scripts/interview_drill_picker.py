#!/usr/bin/env python3
"""Pick a quick ReleaseOps interview drill."""

from __future__ import annotations

import random

DRILLS = [
    "EKS node is Ready, but pods are Pending. Walk the troubleshooting path.",
    "Terraform plan wants to replace RDS. What do you check before approval?",
    "Argo CD shows OutOfSync. How do you decide if it is real drift or expected?",
    "A deployment worker processes the same SQS message twice. What design fixes this?",
    "GitHub Actions cannot assume the AWS role. Explain OIDC trust debugging.",
    "RDS is private. How does a pod connect securely without exposing the DB?",
    "CoreDNS is degraded after node pressure. What user symptoms appear?",
    "A new image tag exists in ECR, but EKS still runs the old image. Why?",
]


def main() -> int:
    print(random.choice(DRILLS))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
