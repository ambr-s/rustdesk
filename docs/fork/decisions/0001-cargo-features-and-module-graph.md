# ADR-0001: Cargo feature names, defaults, and the host/controller module graph

- **Status:** Accepted for implementation planning
- **Scope:** Rust crate feature topology and compile-time host boundary
- **Decision owner:** Fork maintainers

## Decision

Add two product-level features with stable, explicit names:

- `controller-only`: outgoing controller application and Flutter bridge; it is the feature used by the Linux controller artifact.
- `host-services`: local RustDesk host/service graph, including incoming connections, local capture, local input injection, service IPC, and service startup.

Keep `flutter` as the existing bridge feature and keep existing capability features (`drm`, `drm-wake`, `hwcodec`, `vram`, and codec/audio choices) intact. Do **not** rename `flutter` or silently change the upstream `default` feature in Phase 0. The first implementation should define the product profiles explicitly in build commands:

```text
cargo build --locked --release --no-default-features --features controller-only,flutter
cargo build --locked --release --features host-services,flutter
```

`controller-only` must not imply `host-services`; `host-services` must not be required by shared outgoing client/session code. If an upstream-compatible default profile is needed, retain the current `default = ["use_dasp"]` until a later release decision explicitly changes it.

The module graph follows the feature boundary, not runtime flags:

- Gate `src/server.rs` and `src/server/**` behind `host-services`.
- Gate service startup exports and host startup paths in `src/lib.rs`, `src/core_main.rs`, and `src/platform/**` behind `host-services`.
- Keep `src/client/**`, rendezvous/session/UI composition, decode/render, playback, clipboard, and file transfer available to `controller-only`.
- Exclude `src/service.rs` and its binary target from controller builds and packages.
- Move or duplicate only the minimum reusable media traits needed by the client; do not make controller builds depend on the host service registry.

The exact dependency list is a follow-up implementation result. Cargo metadata/tree is authoritative; symbol/string scans are supplementary.

## Evidence from the current tree

- `Cargo.toml:23-49` currently has `default = ["use_dasp"]`, `flutter`, and individual media/DRM features but no host/controller product boundary.
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
4. Extract any shared outgoing types from `src/server/service.rs` into a neutral module only when compilation proves it necessary.
5. Gate host-only dependencies and test both explicit profiles with `--locked`.
6. Make packaging invoke the controller profile explicitly; only then consider a default-profile change in a separate reviewed decision.

## Validation

- `cargo metadata --no-deps --format-version 1` shows the intended features and targets.
- `cargo tree --locked --no-default-features --features controller-only,flutter` contains no host-only closure after the split.
- Controller compilation and host compilation both succeed where toolchains are available.
- Source/AST checks confirm host modules and `src/service.rs` are not in the controller target.
- Runtime validation confirms no host listener/service startup; this cannot be inferred from compilation alone.

## Rollback

Remove the new feature gates and return build invocations to the existing `default` profile, preserving the old host graph. Do not delete host modules until a later migration has a tested replacement and upgrade path.

## Required spike before irreversible decisions

A compile-graph spike must first prove that outgoing audio playback, remote-terminal controller functions, and shared session types do not pull `src/server/**` or local capture. If they do, record the smallest extraction boundary before changing feature defaults.
