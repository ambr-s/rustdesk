# ADR-0001: Cargo feature names, defaults, and the host/controller module graph

- **Status:** Accepted for implementation planning
- **Scope:** Rust crate feature topology and compile-time host boundary
- **Decision owner:** Fork maintainers

## Decision

Add two product-level features with stable, explicit names:

- `controller-only`: outgoing controller application and Flutter bridge; it is the feature used by the Linux controller artifact.
- `host-services`: local RustDesk host/service graph, including incoming connections, local capture, local input injection, service IPC, and service startup.

Keep `flutter` as the existing bridge feature and keep existing capability features (`drm`, `drm-wake`, `hwcodec`, `vram`, and codec/audio choices) intact. Do **not** rename `flutter`. Define the product profiles explicitly in build commands:

```text
cargo build --locked --release --lib --no-default-features --features controller-only,flutter,use_dasp
cargo build --locked --release --lib --features host-services,flutter
cargo build --locked --release --bin service --features host-services
```

`controller-only` must not imply `host-services`; `host-services` must not be required by shared outgoing client/session code. The implementation adds `host-services` to the default feature set so ordinary upstream-style `cargo build` commands still select the `service` target after it gains `required-features = ["host-services"]`. The controller command uses `--no-default-features`, so this compatibility default cannot leak host services into the controller closure.

The module graph follows the feature boundary, not runtime flags:

- Gate `src/server.rs` and `src/server/**` behind `host-services`.
- Gate service startup exports and host startup paths in `src/lib.rs`, `src/core_main.rs`, and `src/platform/**` behind `host-services`.
- Keep `src/client/**`, rendezvous/session/UI composition, decode/render, playback, clipboard, and file transfer available to `controller-only`.
- Exclude `src/service.rs` and its binary target from controller builds and packages.
- Move or duplicate only the minimum reusable media traits needed by the client; do not make controller builds depend on the host service registry.

Cargo enforces that boundary rather than relying on packaging discipline:

- add `required-features = ["host-services"]` to the `service` binary target;
- make dependencies used only by host modules optional and include them through `host-services`;
- make `portable-pty` host-only because it implements the remote peer's local PTY service, while retaining the protocol/UI client for controlling a remote terminal;
- audit every `enigo` use before gating it: host-side injection implementations belong to `host-services`, while any controller requirement for read-only local key-state observation must move behind a non-injecting interface rather than retaining injection APIs;
- split `scrap` decode from capture as ADR-0003 specifies;
- classify platform service, privileged startup, and host-service IPC separately from benign single-instance/controller IPC; and
- package an explicit controller target allowlist, never `cargo build --all-targets` output.

The exact dependency list is a follow-up implementation result. Cargo metadata/tree is authoritative; symbol/string scans are supplementary.

## Evidence from the current tree

- The upstream base had `default = ["use_dasp"]`, `flutter`, and individual media/DRM features but no host/controller product boundary.
- `Cargo.toml:55` unconditionally enables `scrap` with `features = ["wayland"]`.
- `src/lib.rs:10-13` unconditionally includes and re-exports `server` for non-iOS targets; `src/lib.rs:5-8` exports `start_os_service`.
- `src/core_main.rs:196-208` starts `crate::start_server(false, no_server)` for the normal desktop path.
- `src/platform/linux.rs` contains the root/system service lifecycle and systemd operations (inventory recorded in `docs/fork/architecture.md`).
- `src/service.rs` is a second Cargo binary entrypoint for service startup on supported platforms.

These observations describe the checked-in source at the Phase 0 base; they are not proof that a controller build currently works.

## Alternatives considered

1. **Runtime `--no-server` or hidden host UI:** rejected. It leaves host code and dependencies compiled and is explicitly insufficient for the requirements.
2. **Make `controller-only` the default immediately:** deferred. It would alter upstream/default build behavior before the graph and downstream packaging are proven.
3. **Use only granular platform features with no product profile:** rejected. It does not provide a reviewable guarantee that every host edge is excluded.
4. **Rename existing `flutter`/media features:** rejected. Unnecessary compatibility churn.

## Migration sequence

1. Add feature declarations without changing `default`.
2. Use `cargo metadata` and `cargo tree` to inventory every host-only edge.
3. Gate `src/lib.rs`, `src/core_main.rs`, platform service startup, and the service binary target.
4. Inventory each non-mobile dependency and each Cargo target, then mark host-only dependencies optional and bind them to `host-services`.
5. Extract any shared outgoing types from `src/server/service.rs` into a neutral module only when compilation proves it necessary.
6. Gate host-only dependencies and test both explicit profiles with `--locked`.
7. Make packaging invoke the controller library target explicitly and reject every undeclared executable; only then consider a default-profile change in a separate reviewed decision.

## Validation

- `cargo metadata --no-deps --format-version 1` shows the intended features, `required-features` on `service`, and the complete target list.
- `cargo tree --locked --no-default-features --features controller-only,flutter,use_dasp -e features` contains no host-only closure after the split, and equivalent target-platform runs cover every supported controller target.
- `cargo check --locked --all-targets` exercises the default host profile, while explicit controller `--lib --no-default-features` checks ensure no incidental service or helper target is selected.
- Controller compilation and host compilation both succeed where toolchains are available.
- Source/AST checks confirm host modules and `src/service.rs` are not in the controller target.
- The packaged controller artifact allowlist contains the controller executable/libraries only and fails if the `service` binary, local PTY implementation, host helper, systemd unit, or privileged installer is present.
- Runtime validation confirms no host listener/service startup; this cannot be inferred from compilation alone.

## Rollback

Remove the new feature gates and return build invocations to the existing `default` profile, preserving the old host graph. Do not delete host modules until a later migration has a tested replacement and upgrade path.

## Required spike before irreversible decisions

A compile-graph spike must first produce the complete Cargo target/dependency inventory and prove that outgoing audio playback, remote-terminal controller functions, and shared session types do not pull `src/server/**`, `portable-pty`, injection implementations, or local capture. If they do, record the smallest extraction boundary before changing feature defaults.
