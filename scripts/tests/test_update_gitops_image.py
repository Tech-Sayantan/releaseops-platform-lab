from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import yaml


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPOSITORY_ROOT / "scripts" / "update_gitops_image.py"
IMAGE_REPOSITORY = (
    "923988301700.dkr.ecr.us-east-1.amazonaws.com/releaseops-dev/api"
)
IMAGE_DIGEST = (
    "sha256:0123456789abcdef0123456789abcdef"
    "0123456789abcdef0123456789abcdef"
)


class UpdateGitOpsImageTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_directory.cleanup)
        self.values_file = Path(self.temp_directory.name) / "values.yaml"
        self.values_file.write_text(
            yaml.safe_dump(
                {
                    "fullnameOverride": "release-service",
                    "image": {
                        "repository": "example.invalid/old",
                        "tag": "old-tag",
                    },
                },
                sort_keys=False,
            ),
            encoding="utf-8",
        )

    def run_script(
        self,
        *,
        repository: str = IMAGE_REPOSITORY,
        digest: str = IMAGE_DIGEST,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--file",
                str(self.values_file),
                "--repository",
                repository,
                "--digest",
                digest,
            ],
            check=False,
            capture_output=True,
            text=True,
        )

    def test_updates_repository_and_digest_and_removes_tag(self) -> None:
        result = self.run_script()

        self.assertEqual(result.returncode, 0, result.stderr)
        values = yaml.safe_load(self.values_file.read_text(encoding="utf-8"))
        self.assertEqual(values["image"]["repository"], IMAGE_REPOSITORY)
        self.assertEqual(values["image"]["digest"], IMAGE_DIGEST)
        self.assertNotIn("tag", values["image"])

    def test_second_run_is_idempotent(self) -> None:
        first = self.run_script()
        second = self.run_script()

        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertIn("No change required", second.stdout)

    def test_rejects_repository_with_mutable_tag(self) -> None:
        result = self.run_script(repository=f"{IMAGE_REPOSITORY}:latest")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("do not include a tag", result.stderr)


if __name__ == "__main__":
    unittest.main()
