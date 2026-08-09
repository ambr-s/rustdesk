# Linux Controller-Only Build Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Produce a Linux Flutter controller artifact whose compile-time Rust, Dart, dependency, and package closures exclude every controlled-host capability while retaining outgoing RustDesk controller functions.

**Architecture:** One `build.py --controller-only` profile owns the Rust feature set, Dart entrypoint/define, profile record, and artifact allowlist. Cargo gates the host graph behind `host-services`; `scrap` exposes decode separately from capture; Flutter starts from a controller-specific import root. Metadata, negative builds, dependency-tree checks, import-closure checks, artifact checks, and Blacksmith builds prove the boundary.

**Tech stack:** Rust/Cargo, Flutter/Dart, Python `unittest`, GitHub Actions on Blacksmith Ubuntu 24.04.

---

## Task 1: Establish the product-profile contract

**Files:**
- Modify: `Cargo.toml`
- Modify: `build.py`
- Create: `tests/test_controller_profile.py`

**TDD sequence:**
1. Test that `python3 build.py --controller-only --print-features` returns exactly `controller-only,flutter,use_dasp`; run it and observe the missing-argument failure.
2. Add the parser/profile selection; rerun and observe PASS.
3. Test Cargo metadata for `controller-only`, `host-services`, no controller→host edge, and `service.required-features=[host-services]`; run and observe failure.
4. Add the features and target requirement; rerun and observe PASS.
5. Add negative tests for non-Linux use, contradictory capability flags, and controller `--skip-cargo` without a matching profile record; implement fail-closed validation.
6. Add a test for the canonical controller Cargo and Flutter commands, including `--no-default-features`, `--lib`, `-t lib/controller_main.dart`, and `--dart-define=RUSTDESK_CONTROLLER_ONLY=true`.
7. Run `python3 -m unittest -v tests/test_controller_profile.py` and `git diff --check`.
8. Commit `feat: define controller-only build profile`.

## Task 2: Gate the root host graph and startup

**Files:**
- Modify: `src/lib.rs`
- Modify: `src/core_main.rs`
- Modify: `src/platform/mod.rs`
- Modify host-only Linux platform modules as compilation identifies them
- Test: `tests/test_controller_profile.py`

**TDD sequence:**
1. Add a negative service-target test and run it to prove it currently selects incorrectly.
2. Add a controller compile test: `cargo check --locked --lib --no-default-features --features controller-only,flutter,use_dasp`.
3. Gate `server` exports, `start_os_service`, `start_server`, `--server`, tray/service startup, root service IPC, and host-only platform modules with `host-services`.
4. Iterate only on compiler-proven shared edges; do not gate outgoing client/session functions.
5. Verify the controller compile passes and `cargo check --locked --bin service --no-default-features --features controller-only,flutter,use_dasp` fails for missing `host-services`.
6. Verify host library/service checks pass with `host-services`.
7. Commit `feat: exclude host startup from controller profile`.

## Task 3: Separate local microphone capture from playback

**Files:**
- Modify: `src/client/io_loop.rs`
- Modify: `src/flutter_ffi.rs`
- Modify: `src/ipc.rs`
- Modify: `src/ui_interface.rs`
- Modify related voice-call UI imports only where compiler/import tests require

**TDD sequence:**
1. Add compile/import tests proving controller code cannot reference `audio_service::NAME`, local recorder subscription, or voice-call input-device setters.
2. Observe failures.
3. Gate the microphone/voice-call capture API behind `host-services` while retaining received remote-audio decode/playback.
4. Run controller and host checks.
5. Commit `feat: remove local audio capture from controller`.

## Task 4: Make host-only dependencies optional

**Files:**
- Modify: `Cargo.toml`
- Modify: `Cargo.lock`
- Modify compiler-identified call sites
- Test: `tests/test_controller_profile.py`

**TDD sequence:**
1. Add a controller `cargo tree` test that rejects `portable-pty`, `pam`, `evdev`, `enigo`, `libxdo-sys`, local Pulse recorder/control crates, and host PTY dependencies.
2. Observe the dependency failures.
3. Make one dependency optional at a time, add it to `host-services`, gate its host-only call sites, and rerun controller compile/tree after each vertical slice.
4. Preserve remote terminal control while excluding local PTY creation.
5. Verify host profile compilation after every slice.
6. Commit `feat: remove host dependencies from controller closure`.

## Task 5: Split `scrap` decode from capture

**Files:**
- Modify: `libs/scrap/Cargo.toml`
- Modify: `libs/scrap/build.rs`
- Modify: `libs/scrap/src/lib.rs`
- Modify: `libs/scrap/src/common/**`
- Modify platform capture module gates
- Modify: root `Cargo.toml`

**TDD sequence:**
1. Extend the tree test to reject GStreamer, zbus/D-Bus capture, nokhwa, X11/Wayland/DRM capture backends, and capture probes.
2. Observe failure.
3. Add explicit decode and capture features; make Wayland/DRM/camera/platform capturers depend on capture.
4. Make the root controller profile select decode only and host-services select capture/Wayland.
5. Run scrap tests plus controller and host checks.
6. Verify retained remote video decode/render compile paths.
7. Commit `feat: split remote decode from local capture`.

## Task 6: Add a controller-only Flutter root

**Files:**
- Create: `flutter/lib/controller_main.dart`
- Create minimal files under `flutter/lib/controller/` as required
- Modify shared model/bootstrap files only at the smallest proven seam
- Create: `flutter/test/controller_import_closure_test.dart`
- Create: `flutter/test/controller_startup_test.dart`

**TDD sequence:**
1. Add an import-closure test rejecting `ServerModel`, server/install pages, service/deployment pages, and host permission controls; observe failure because no controller entrypoint exists.
2. Add the smallest controller root retaining connection/address-book home, remote desktop, file transfer, clipboard, multimonitor, screenshots/recording, self-host config, and remote terminal.
3. Add a startup test proving no service startup call.
4. Run `flutter analyze`, focused tests, and `flutter build linux --release -t lib/controller_main.dart --dart-define=RUSTDESK_CONTROLLER_ONLY=true`.
5. Verify the host entrypoint still builds.
6. Commit `feat: add controller-only Flutter composition`.

## Task 7: Package and verify the controller bundle

**Files:**
- Modify: `build.py`
- Create: `scripts/verify_controller_artifact.py`
- Create verifier tests under `tests/`
- Add controller desktop metadata using `systems.amber.RustDeskController`

**TDD sequence:**
1. Add failing verifier tests for service binaries, systemd units, PAM, polkit, X11 config, `startwm.sh`, PTY/capture helpers, and undeclared executables.
2. Add `build-profile.json` mismatch tests for Rust features, Dart target/define, commit, and hashes.
3. Implement a dedicated controller staging path that never calls host `.deb` packaging helpers.
4. Build and inspect the bundle; run ELF/dependency, manifest, checksum, and allowlist verification.
5. Commit `feat: package verified controller bundle`.

## Task 8: Add authoritative Blacksmith evidence

**Files:**
- Modify: `.github/workflows/blacksmith-baseline.yml`
- Modify: `docs/fork/verification.md` only with actual evidence semantics

**Steps:**
1. Add a Linux controller job using `blacksmith-8vcpu-ubuntu-2404` and the shared verified bridge artifact.
2. Run profile tests, metadata, negative service build, dependency tree, controller and host checks, Flutter closure/tests/build, and artifact verifier.
3. Upload the controller bundle, profile record, tree evidence, checksums, and manifests. Do not claim runtime or Flatpak evidence.
4. Validate workflow with PowerShell/Bash parsing where applicable, actionlint, and `git diff --check`.
5. Run independent specification review, then code/security quality review; fix and repeat until approved.
6. Push, open a PR closing #6, monitor all checks, and merge only after authoritative green CI.
7. Leave Ubuntu GNOME Wayland runtime observations explicitly pending human execution where automation cannot prove them.
