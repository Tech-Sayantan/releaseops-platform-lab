#!/usr/bin/env python3
"""Guard Terraform plans from accidental destructive changes.

Usage:
  terraform show -json tfplan > tfplan.json
  python scripts/terraform_plan_guard.py tfplan.json

In CI this can be extended to fail on RDS/EKS replacement unless an approval
label or environment approval exists.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

HIGH_RISK_TYPES = {
    "aws_db_instance",
    "aws_eks_cluster",
    "aws_eks_node_group",
    "aws_vpc",
    "aws_subnet",
    "aws_nat_gateway",
}


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: terraform_plan_guard.py <terraform-plan-json>", file=sys.stderr)
        return 2

    plan = json.loads(Path(sys.argv[1]).read_text())
    dangerous: list[str] = []

    for change in plan.get("resource_changes", []):
        actions = change.get("change", {}).get("actions", [])
        resource_type = change.get("type")
        address = change.get("address")
        if resource_type in HIGH_RISK_TYPES and ("delete" in actions or actions == ["delete", "create"]):
            dangerous.append(f"{address}: actions={actions}")

    if dangerous:
        print("High-risk Terraform changes detected:")
        for item in dangerous:
            print(f"- {item}")
        return 1

    print("Terraform plan guard passed: no high-risk deletes/replacements.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
