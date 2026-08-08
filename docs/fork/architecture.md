# Architecture and capability boundaries

## Boundary model

The fork should make capabilities explicit in the Rust and Flutter graphs. The current repository inventory shows host code is deeply connected through `src/server.rs`, `src/server/*`, Linux service startup, and unconditional startup calls. The implementation must split these edges rather than rely on `--no-server` or sandbox permissions.

### Rust feature boundary

Introduce a reviewed feature topology with a controller-only feature and host-service features. The exact names are an implementation decision, but the invariant is fixed:

- controller builds include outgoing client/session, decode/render, playback, clipboard, file transfer, rendezvous, and UI code;
- host-service builds alone include `src/server`, local service startup, capture, input injection, service IPC, and host-only dependencies;
- `src/service.rs` is not built or packaged for controller artifacts;
- `core_main` and platform startup cannot call host service functions in controller builds.

The dependency graph, not string scanning, is the authoritative proof. Existing `scrap` functionality may need a decode-only boundary so controller builds do not compile capture backends, PipeWire, DRM/KMS capture, X11, or uinput.

### Flutter boundary

Use a controller-specific compile-time entrypoint/composition, paired with the Rust feature selection. A Dart define may select the entrypoint, but hiding host pages at runtime is insufficient. Controller composition must not import or instantiate `ServerModel`, service/install pages, incoming-client tabs, or host permission controls. The build system must reject mismatched Rust and Flutter selections.

## Windows display path

First evaluate the existing `libs/virtual_display` / `rustdesk_idd` path. It already exposes device creation, connector plug-in/out, and monitor mode updates, but hardware-cursor support is not established by repository inventory and must be verified in the actual driver. If callbacks are absent, implement the minimum IddCx hardware-cursor path or select another driver only after source, redistribution, signing, and maintenance review.

Keep monitor indexing and per-monitor mode updates stable. Treat Amyuni migration as an explicit compatibility problem: preserve rollback during rollout, define stale-device cleanup, and version INF/catalog updates. Do not silently replace installed hardware IDs.

## Dynamic viewport resolution

Reuse the existing display-resolution protocol initially, with Remmina-style semantics. When enabled for a peer, the usable remote-canvas logical width and height multiplied by the local view DPR are the requested remote managed-virtual-display pixel width and height. Round to positive even dimensions, clamp to negotiated/driver bounds, and preserve the normal scale/fit policy when matching is disabled or unsupported. Keep the preference default off per peer and gate it on a compatible managed virtual display plus a negotiated capability.

The resize controller must debounce viewport, DPR, fullscreen, maximise, monitor, and DPI changes; resynchronize after each such transition; and suppress requests whose dimensions are within the documented no-op threshold or equal to the acknowledged size. Track request generations, ignore stale acknowledgements, and do not treat an echoed remote mode as a new viewport request. This prevents resize feedback loops and redundant updates. Add a protocol capability/ack only if existing `ChangeDisplayResolution` behavior cannot provide reliable generation and acknowledgement semantics.

## Keyboard routing

Keep input transport (Flutter events versus native grab) separate from routing policy. Use a pure policy state with pointer-over-canvas, focused-window, explicit-grab, dialog, and disposal state. Route transitions through the existing enter/leave cleanup so tracked left/right modifiers and remote key state are released exactly once. Do not independently manipulate global native-grab ownership from Flutter; the Rust owner remains authoritative.

On GNOME Wayland, treat native global-grab behavior as a runtime capability to verify. The supported fallback must be Flutter pointer-gated routing, not compositor-specific assumptions or fake global pointer-position queries.

## Flatpak boundary

Create a dedicated source-built manifest for `ch.flourish.RustDeskController`. Pin source revisions and checksums, build Rust and Flutter from source, install only the controller bundle and metadata, and omit host helpers, systemd units, installer scripts, PAM, xdotool, local input-injection functionality/dependencies, and capture helpers. Start with Wayland, IPC, network, PulseAudio, and narrowly required DRI GPU access for decode/render only. Do not grant home/host filesystem permissions; use document/file-picker portals for user-selected imports/exports, screenshots, recordings, and file transfer. Prohibit X11, ScreenCast and RemoteDesktop portal/session permissions, the system bus, Flatpak control, DRM/KMS or PipeWire capture, and uinput/evdev. Controller-side screenshots and recordings refer to the remote display and remain supported; no local host capture is allowed. Any additional permission requires a demonstrated runtime need and review.

## Deliberate non-claims

This architecture does not assert that the current IDD has hardware cursors, that Wayland native grabs work, that the current dependency graph already permits controller-only compilation, or that the existing Flatpak is minimal/source-built. Those are verification tasks.
