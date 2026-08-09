import os
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
    build_support::enforce_controller_feature_exclusivity();
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
            guard_binary = str(Path(directory) / "guard")
            clean_environment = dict(os.environ)
            clean_environment.pop("CARGO_FEATURE_CONTROLLER_ONLY", None)
            clean_environment.pop("CARGO_FEATURE_HOST_SERVICES", None)
            self.assertEqual(
                subprocess.run([guard_binary], env=clean_environment, check=False).returncode,
                0,
            )
            conflict_environment = dict(clean_environment)
            conflict_environment["CARGO_FEATURE_CONTROLLER_ONLY"] = "1"
            conflict_environment["CARGO_FEATURE_HOST_SERVICES"] = "1"
            conflict = subprocess.run(
                [guard_binary],
                env=conflict_environment,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
            self.assertNotEqual(conflict.returncode, 0)
            self.assertIn(
                "controller-only cannot be combined with host-services; use --no-default-features",
                conflict.stderr,
            )

        build_script = (REPO_ROOT / "build.rs").read_text()
        self.assertIn('#[path = "build_support.rs"]', build_script)
        guard_call = build_script.index("build_support::enforce_controller_feature_exclusivity();")
        first_build_side_effect = build_script.index("hbb_common::gen_version();")
        self.assertLess(guard_call, first_build_side_effect)
        self.assertIn("CARGO_FEATURE_CONTROLLER_ONLY", build_script)
        self.assertIn("CARGO_FEATURE_HOST_SERVICES", build_script)
        support_source = (REPO_ROOT / "build_support.rs").read_text()
        self.assertIn(
            "controller-only cannot be combined with host-services; use --no-default-features",
            support_source,
        )

        library = (REPO_ROOT / "src/lib.rs").read_text()
        self.assertIn(
            '#[cfg(all(feature = "controller-only", feature = "host-services"))]',
            library,
        )
        self.assertIn("compile_error!", library[:500])
        self.assertIn("--no-default-features", library[:500])


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

    def test_root_library_gates_host_modules_and_service_exports(self) -> None:
        source = (REPO_ROOT / "src/lib.rs").read_text()

        self.assertIn('#[cfg(feature = "host-services")]\npub use platform::start_os_service;', source)
        self.assertIn(
            '#[cfg(all(\n'
            '    not(target_os = "ios"),\n'
            '    feature = "host-services"\n'
            '))]\n'
            '/// cbindgen:ignore\n'
            'mod server;',
            source,
        )
        self.assertIn(
            '#[cfg(all(\n'
            '    not(target_os = "ios"),\n'
            '    feature = "host-services"\n'
            '))]\n'
            'pub use self::server::*;',
            source,
        )
        for module in ("tray", "whiteboard"):
            self.assertIn(
                '#[cfg(all(\n'
                '    not(any(target_os = "android", target_os = "ios")),\n'
                '    feature = "host-services"\n'
                '))]\n'
                f"mod {module};",
                source,
            )

    def test_core_main_keeps_outgoing_cli_branch_compiled(self) -> None:
        source = (REPO_ROOT / "src/core_main.rs").read_text()
        start = source.index("if args.is_empty() || crate::common::is_empty_uni_link(&args[0]) {")
        body = source[start:source.index("\n    //_async_logger_holder", start)]
        else_marker = "\n    } else {\n"
        self.assertIn(else_marker, body)
        server_branch, outgoing_branch = body.split(else_marker, 1)
        self.assertIn("std::thread::spawn(move || crate::start_server(false, no_server));", server_branch)
        self.assertIn("crate::ui_interface::start_option_status_sync();", outgoing_branch)

        invoke_start = source.index("fn core_main_invoke_new_connection(")
        invoke_end = source.index("\n}\n\n#[cfg(all(target_os = \"linux\", feature = \"flutter\"))]", invoke_start)
        invoke_body = source[invoke_start:invoke_end]
        for outgoing_cli in ("--connect", "--file-transfer", "--terminal", "--port-forward"):
            self.assertIn(outgoing_cli, invoke_body)
        self.assertIn("return core_main_invoke_new_connection(std::env::args());", source)

        lines = source.splitlines()
        if_index = next(index for index, line in enumerate(lines) if "if args.is_empty() || crate::common::is_empty_uni_link(&args[0])" in line)
        previous_nonblank = next(line for line in reversed(lines[:if_index]) if line.strip())
        self.assertNotIn('feature = "host-services"', previous_nonblank)

    def test_core_main_gates_every_host_startup_edge(self) -> None:
        source = (REPO_ROOT / "src/core_main.rs").read_text()

        self.assertIn(
            '    #[cfg(feature = "host-services")]\n'
            '    #[cfg(any(target_os = "linux", target_os = "windows"))]\n'
            '    if args.is_empty() {',
            source,
        )
        for startup_branch in (
            '        if args[0] == "--tray" {',
            '        if args[0] == "--install-service" {',
            '        if args[0] == "--uninstall-service" {',
            '        if args[0] == "--service" {',
            '        if args[0] == "--server" {',
            '        if args[0] == "--whiteboard" {',
            '        if args[0] == "-gtk-sudo" {',
        ):
            gated_branch = f'        #[cfg(feature = "host-services")]\n{startup_branch}'
            self.assertIn(gated_branch, source, startup_branch)

        self.assertIn(
            '            std::thread::spawn(move || crate::start_server(false, no_server));',
            source,
        )
        self.assertIn('            crate::start_server(true, false);', source)
        self.assertIn('            crate::start_os_service();', source)
        self.assertIn('                crate::tray::start_tray();', source)

    def test_host_gates_do_not_fallback_to_controller_feature_negation(self) -> None:
        for path in (
            "src/common.rs",
            "src/core_main.rs",
            "src/lib.rs",
            "src/platform/linux.rs",
            "src/platform/mod.rs",
            "src/rendezvous_mediator.rs",
            "src/ui_interface.rs",
        ):
            source = (REPO_ROOT / path).read_text()
            self.assertNotIn(
                'any(not(feature = "controller-only"), feature = "host-services")',
                source,
                path,
            )

    def test_linux_platform_host_startup_modules_are_feature_gated(self) -> None:
        source = (REPO_ROOT / "src/platform/mod.rs").read_text()

        for module in ("linux_desktop_manager", "gtk_sudo"):
            self.assertIn(
                '#[cfg(all(target_os = "linux", feature = "host-services"))]\n'
                f"pub mod {module};",
                source,
            )

    def test_neutral_dbus_routing_is_outside_the_host_server_module(self) -> None:
        library = (REPO_ROOT / "src/lib.rs").read_text()
        server = (REPO_ROOT / "src/server.rs").read_text()

        self.assertIn(
            '#[cfg(target_os = "linux")]\n#[path = "server/dbus.rs"]\npub mod dbus;',
            library,
        )
        self.assertNotIn("pub mod dbus;", server)

    def test_controller_io_loop_gates_local_capture_imports(self) -> None:
        source = (REPO_ROOT / "src/client/io_loop.rs").read_text()

        self.assertIn(
            '#[cfg(feature = "host-services")]\nuse crate::common::get_default_sound_input;',
            source,
        )
        self.assertIn(
            '#[cfg(all(not(target_os = "ios"), feature = "host-services"))]\nuse hbb_common::tokio::sync::mpsc::error::TryRecvError;',
            source,
        )
        self.assertNotIn("    common::get_default_sound_input,", source)
        self.assertNotIn(
            '#[cfg(not(target_os = "ios"))]\nuse hbb_common::tokio::sync::mpsc::error::TryRecvError;',
            source,
        )

    def test_controller_io_loop_excludes_the_local_recorder_boundary(self) -> None:
        source = (REPO_ROOT / "src/client/io_loop.rs").read_text()
        self.assertIn(
            '#[cfg(feature = "host-services")]\n    fn start_voice_call(',
            source,
        )
        self.assertIn(
            '#[cfg(feature = "host-services")]\n    fn stop_voice_call(',
            source,
        )
        self.assertIn(
            '#[cfg(feature = "host-services")]\n                                {\n                                    self.stop_voice_call_sender = self.start_voice_call();\n                                }',
            source,
        )

    def test_controller_io_loop_keeps_remote_playback_and_voice_call_protocol(self) -> None:
        source = (REPO_ROOT / "src/client/io_loop.rs").read_text()
        playback_start = source.rindex("Some(message::Union::AudioFrame(frame))")
        playback = source[playback_start:source.index("\n                }", playback_start)]
        voice_start = source.index("            Data::NewVoiceCall => {")
        voice = source[voice_start:source.index("            Data::CloseVoiceCall => {", voice_start)]

        self.assertIn("self.audio_sender", playback)
        self.assertIn("new_voice_call_request(true)", voice)
        self.assertIn("peer.send(&msg).await", voice)
        self.assertIn("on_voice_call_waiting", voice)


if __name__ == "__main__":
    unittest.main()
