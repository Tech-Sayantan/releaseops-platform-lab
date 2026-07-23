#!/usr/bin/env python3
"""Update one Helm values file with an immutable container image identity."""

from __future__ import annotations

import argparse
import re
from pathlib import Path
from typing import Any

import yaml


DIGEST_PATTERN = re.compile(r"^sha256:[0-9a-f]{64}$")
REPOSITORY_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._/-]*$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Set image.repository and image.digest in a Helm values file."
    )
    parser.add_argument("--file", required=True, type=Path)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--digest", required=True)
    return parser.parse_args()


def load_values(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise SystemExit(f"Values file does not exist: {path}")

    document = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(document, dict):
        raise SystemExit(f"Expected a YAML mapping at the root of {path}")
    return document


def main() -> None:
    args = parse_args()

    if not DIGEST_PATTERN.fullmatch(args.digest):
        raise SystemExit("Digest must have the form sha256:<64 lowercase hex characters>")
    if not REPOSITORY_PATTERN.fullmatch(args.repository):
        raise SystemExit(
            "Repository may contain only letters, numbers, dots, slashes, underscores, "
            "and hyphens; do not include a tag"
        )

    values = load_values(args.file)
    image = values.setdefault("image", {})
    if not isinstance(image, dict):
        raise SystemExit("The existing image field must be a YAML mapping")

    previous = (image.get("repository"), image.get("digest"))
    image["repository"] = args.repository
    image["digest"] = args.digest
    image.pop("tag", None)

    current = (image["repository"], image["digest"])
    if previous == current:
        print(f"No change required in {args.file}")
        return

    args.file.write_text(
        yaml.safe_dump(values, sort_keys=False),
        encoding="utf-8",
    )
    print(f"Updated immutable image identity in {args.file}")


if __name__ == "__main__":
    main()
