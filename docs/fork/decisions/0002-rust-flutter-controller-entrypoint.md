# ADR-0002: Rust/Flutter controller entrypoint and build-selection coupling

- **Status:** Accepted for implementation planning
- **Scope:** Controller application composition and Rust/Flutter profile matching

## Decision

Use a controller-specific composition at compile/build time. Do not make the controller a normal host application with pages hidden at runtime.

The Rust build selects `controller-only,flutter`. The Flutter build selects a controller entrypoint/profile using one canonical build variable, initially `RUSTDESK_CONTROLLER_ONLY=true`. The packaging/build driver owns both selections and must reject a mismatch before compiling or packaging. The first implementation may use a dedicated Dart entrypoint such as `flutter/lib/controller_main.dart`; conditional imports are preferred over importing host pages and branching after startup.

The controller composition must not import or instantiate `ServerModel`, incoming-client/server pages, install/service pages, host permission controls, or host startup code. It must retain outgoing connection management, remote desktop, remote keyboard/mouse commands, file transfer, clipboard, address-book/self-hosted configuration, remote terminal controller functionality where supported, and remote audio playback.

Rust-side `core_main` must not call `start_server`, service startup, or host setup in the controller profile. The Flutter controller startup must not call `gFFI.serverModel.startService()` or an equivalent host-service path.

## Evidence from the current tree

- `flutter/lib/main.dart:10-18` imports install, server, and desktop composition pages.
- `flutter/lib/main.dart:110-112` handles `--install` and `flutter/lib/main.dart:136-149` starts `serverModel` service in the normal app path.
- `src/core_main.rs:196-208` starts the Rust host server on the normal desktop path.
- `src/lib.rs:10-13` exports the server module for desktop targets without a product feature gate.
- Existing docs identify `flutter/lib/models/server_model.dart`, `flutter/lib/desktop/pages/server_page.dart`, and `flutter/lib/desktop/pages/install_page.dart` as host-side composition edges.

The current imports/startup behavior is evidence of coupling, not evidence that the proposed controller composition exists.

## Alternatives considered

1. **Hide host widgets with a Dart boolean:** rejected. Imports, generated bindings, initialization, and accidental service calls remain possible.
2. **Use only a runtime CLI flag:** rejected. The requirement is compile-time absence, and Rust startup would still be present.
3. **Maintain separate forks of all UI:** rejected. A shared outgoing composition with explicit host/controller roots is more maintainable.
4. **Let packagers manually pass independent flags:** rejected. It invites Rust/Flutter mismatch and unreviewable artifacts.

## Migration sequence

1. Define one build-profile contract mapping `controller-only,flutter` to `RUSTDESK_CONTROLLER_ONLY=true` and document it in the build driver.
2. Add a small controller root/entrypoint that composes only outgoing screens and shared initialization.
3. Gate Rust host startup and exports on `host-services`.
4. Remove host imports from the controller import closure; keep host root available for the host profile.
5. Add a preflight check that fails unless exactly one Rust product profile and matching Dart profile are selected.
6. Package and inspect the controller artifact before changing any default app entrypoint.

## Validation

- Build the Rust and Flutter sides through one command and inspect the recorded profile values.
- Deliberately pair controller Rust with host Flutter and host Rust with controller Flutter; both must fail before packaging.
- Use Dart import/dependency inspection to prove host pages are outside the controller closure.
- Verify controller startup does not create a local service, incoming listener, or `--server` child.
- Verify retained outgoing flows with focused tests and a real controller run.

## Rollback

Keep the existing host entrypoint and package as the fallback profile. Revert only the controller profile selection and packaging invocation if composition or startup validation fails; do not remove shared outgoing pages or host entrypoints during the first rollout.

## Required spike before irreversible decisions

A Flutter composition spike must build the smallest Linux controller root and enumerate generated bridge/import dependencies. It must establish whether a separate Dart entrypoint or conditional imports gives a clean closure without copying the full application.
