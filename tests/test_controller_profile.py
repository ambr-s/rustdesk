import subprocess
import tempfile
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

    def test_cargo_metadata_describes_the_profile_features(self) -> None:
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
        self.assertIn("host-services", package["features"]["default"])
        self.assertNotIn("host-services", package["features"]["controller-only"])
        service = next(target for target in package["targets"] if target["name"] == "service")
        self.assertEqual(service["required-features"], ["host-services"])

    def test_controller_profile_rejects_the_service_binary(self) -> None:
        result = subprocess.run(
            [
                "cargo", "check", "--locked", "--no-default-features",
                "--features", "controller-only,flutter,use_dasp", "--bin", "service",
            ],
            cwd=REPO_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("target `service` in package `rustdesk` requires the features: `host-services`", result.stderr)

    def test_controller_profile_is_linux_only(self) -> None:
        args = Namespace(controller_only=True, flutter=False, hwcodec=False, vram=False,
                         unix_file_copy_paste=False, drm=False)

        with mock.patch.object(build.sys, "platform", "freebsd13"):
            with self.assertRaisesRegex(Exception, "Linux only"):
                build.resolve_profile(args)

        with mock.patch.object(build.sys, "platform", "freebsd13"):
            with self.assertRaisesRegex(Exception, "Linux only"):
                build.get_features(args)

    def test_cargo_rejects_controller_with_default_host_services(self) -> None:
        harness = """
#[path = "{support}"]
mod build_support;

fn main() {{
    assert!(build_support::controller_features_conflict(true, true));
    assert!(!build_support::controller_features_conflict(true, false));
    assert!(!build_support::controller_features_conflict(false, true));
}}
""".format(support=REPO_ROOT / "build_support.rs")
        with tempfile.TemporaryDirectory() as directory:
            harness_path = Path(directory) / "guard.rs"
            harness_path.write_text(harness)
            guard = subprocess.run(
                ["rustc", "--edition", "2021", str(harness_path), "-o", str(Path(directory) / "guard")],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
            self.assertEqual(guard.returncode, 0, guard.stderr)
            self.assertEqual(subprocess.run([str(Path(directory) / "guard")], check=False).returncode, 0)

        result = subprocess.run(
            ["cargo", "check", "--locked", "--lib", "--features", "controller-only"],
            cwd=REPO_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        cargo_output = result.stdout + result.stderr
        self.assertTrue(
            "controller-only cannot be combined with host-services" in cargo_output
            or "pkg-config" in cargo_output,
            cargo_output,
        )

    def test_controller_profile_rejects_host_capability_flags(self) -> None:
        for flag in ("drm", "unix_file_copy_paste", "vram"):
            values = dict(controller_only=True, flutter=False, hwcodec=False, vram=False,
                          unix_file_copy_paste=False, drm=False)
            values[flag] = True
            with self.subTest(flag=flag):
                with self.assertRaisesRegex(ValueError, "controller-only"):
                    build.resolve_profile(Namespace(**values))

    def test_controller_skip_cargo_is_rejected_by_the_cli(self) -> None:
        args = Namespace(controller_only=True, flutter=False, hwcodec=False, vram=False,
                         unix_file_copy_paste=False, drm=False, skip_cargo=True)

        result = self.run_build("--controller-only", "--skip-cargo")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("--controller-only cannot be combined with --skip-cargo", result.stderr)

    def test_controller_build_routes_fail_closed_before_host_packaging(self) -> None:
        for extra_args in ((), ("--package", "bundle")):
            with self.subTest(extra_args=extra_args):
                with mock.patch.object(build, "build_deb_from_folder") as package:
                    with mock.patch.object(build, "system2") as system2:
                        with mock.patch("sys.argv", ["build.py", "--controller-only", *extra_args]):
                            with self.assertRaises(SystemExit) as raised:
                                build.main()
                self.assertIn("dedicated controller artifact path", str(raised.exception))
                package.assert_not_called()
                system2.assert_not_called()

    def test_controller_distro_routes_fail_closed_before_host_packaging(self) -> None:
        with mock.patch.object(build, "linux_packaging_branch", return_value="pacman"):
            with mock.patch.object(build, "build_flutter_arch_manjaro") as package:
                with mock.patch.object(build, "system2") as system2:
                    with mock.patch.object(build, "windows", False), mock.patch.object(build, "osx", False):
                        with mock.patch("sys.argv", ["build.py", "--controller-only"]):
                            with self.assertRaises(SystemExit):
                                build.main()
        package.assert_not_called()
        system2.assert_not_called()

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
