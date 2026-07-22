#!/usr/bin/env python3
"""Small interview-friendly EKS health reporter.

This script shows a realistic Python angle for DevOps interviews: call CLIs,
parse JSON, summarize health, and fail with a useful exit code.
"""

from __future__ import annotations

import json
import subprocess
import sys
from typing import Any


def run_json(command: list[str]) -> dict[str, Any]:
    completed = subprocess.run(command, text=True, capture_output=True, check=False)
    if completed.returncode != 0:
        print(completed.stderr.strip(), file=sys.stderr)
        raise SystemExit(completed.returncode)
    return json.loads(completed.stdout)


def main() -> int:
    nodes = run_json(["kubectl", "get", "nodes", "-o", "json"])
    pods = run_json(["kubectl", "get", "pods", "-A", "-o", "json"])

    not_ready_nodes: list[str] = []
    for node in nodes["items"]:
        conditions = {c["type"]: c["status"] for c in node["status"]["conditions"]}
        if conditions.get("Ready") != "True":
            not_ready_nodes.append(node["metadata"]["name"])

    bad_pods: list[str] = []
    for pod in pods["items"]:
        phase = pod["status"].get("phase")
        if phase not in {"Running", "Succeeded"}:
            ns = pod["metadata"]["namespace"]
            name = pod["metadata"]["name"]
            bad_pods.append(f"{ns}/{name}:{phase}")

    print("EKS health summary")
    print(f"- nodes: {len(nodes['items'])}")
    print(f"- pods: {len(pods['items'])}")
    print(f"- not-ready nodes: {not_ready_nodes or 'none'}")
    print(f"- unhealthy pods: {bad_pods or 'none'}")

    return 1 if not_ready_nodes or bad_pods else 0


if __name__ == "__main__":
    raise SystemExit(main())
