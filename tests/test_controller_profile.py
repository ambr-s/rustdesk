import subprocess
import unittest
from argparse import Namespace
from unittest import mock
from pathlib import Path

import build


REPO_ROOT = Path(__file__).resolve().parents[1]


class ControllerBuildProfileTests(unittest.TestCase):
    def run_build(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["python3", "build.py", *args],
            cwd=REPO_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )

    def test_controller_profile_selects_the_exact_rust_features(self) -> None:
        result = self.run_build("--controller-only", "--print-features")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "controller-only,flutter,use_dasp")

    def test_cargo_metadata_enforces_the_product_boundary(self) -> None:
        import json

        result = subprocess.run(
            ["cargo", "metadata", "--no-deps", "--format-version", "1"],
            cwd=REPO_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        metadata = json.loads(result.stdout)
        package = next(p for p in metadata["packages"] if p["name"] == "rustdesk")

        self.assertIn("controller-only", package["features"])
        self.assertIn("host-services", package["features"])
        self.assertNotIn("host-services", package["features"]["controller-only"])
        service = next(target for target in package["targets"] if target["name"] == "service")
        self.assertEqual(service["required-features"], ["host-services"])

    def test_controller_profile_is_linux_only(self) -> None:
        args = Namespace(controller_only=True, flutter=False, hwcodec=False, vram=False,
                         unix_file_copy_paste=False, drm=False)

        with mock.patch.object(build, "windows", True), mock.patch.object(build, "osx", False):
            with self.assertRaisesRegex(Exception, "Linux only"):
                build.resolve_profile(args)

    def test_controller_profile_rejects_host_capability_flags(self) -> None:
        for flag in ("drm", "unix_file_copy_paste", "vram"):
            values = dict(controller_only=True, flutter=False, hwcodec=False, vram=False,
                          unix_file_copy_paste=False, drm=False)
            values[flag] = True
            with self.subTest(flag=flag):
                with self.assertRaisesRegex(ValueError, "controller-only"):
                    build.resolve_profile(Namespace(**values))

    def test_controller_skip_cargo_requires_a_matching_profile_record(self) -> None:
        args = Namespace(controller_only=True, flutter=False, hwcodec=False, vram=False,
                         unix_file_copy_paste=False, drm=False, skip_cargo=True)

        with self.assertRaisesRegex(ValueError, "profile record"):
            build.resolve_profile(args)

        profile = build.CONTROLLER_PROFILE_RECORD.copy()
        self.assertEqual(build.resolve_profile(args, profile), profile)

    def test_controller_commands_are_canonical_and_profile_coupled(self) -> None:
        profile = build.resolve_profile(
            Namespace(controller_only=True, flutter=False, hwcodec=False, vram=False,
                      unix_file_copy_paste=False, drm=False)
        )

        self.assertEqual(build.controller_cargo_command(profile),
                         "cargo build --locked --release --lib --no-default-features "
                         "--features controller-only,flutter,use_dasp")
        self.assertEqual(build.controller_flutter_command(profile),
                         "flutter build linux --release -t lib/controller_main.dart "
                         "--dart-define=RUSTDESK_CONTROLLER_ONLY=true")


if __name__ == "__main__":
    unittest.main()
