# Product requirements and objective acceptance criteria

## Objective

Deliver a controller-only RustDesk distribution that connects to and controls remote peers while not compiling, packaging, starting, or listening as a local RustDesk host on Linux. Improve Windows virtual-display behavior and make keyboard routing safe and predictable on GNOME Wayland.

The fork must preserve upstream documentation and remain recognizable as a RustDesk derivative. This document specifies desired behavior; it does not claim any requirement is currently satisfied.

## Functional requirements

### Windows virtual display

1. Prefer evaluating the existing `libs/virtual_display` and `rustdesk_idd` implementation before adopting another driver.
2. The selected Windows IDD must support a hardware cursor, including cursor shape, hotspot, position, visibility, updates, and correct ordering. Switching a RustDesk constant alone is not acceptance evidence.
3. Provide indexed monitor allocation, automatic plug-in/plug-out, and per-monitor mode updates.
4. Provide Remmina-style dynamic resolution matching: the usable remote-canvas logical size multiplied by the local device-pixel ratio (DPR) is the requested remote managed-virtual-display pixel size. Clamp to the driver/protocol bounds, use positive even dimensions, debounce and cancel superseded requests, and suppress requests below a documented no-op threshold. Re-synchronize after fullscreen, maximise, monitor, or DPI changes; make the preference default off per peer, gate it on a compatible managed virtual display and negotiated capability, and prevent feedback loops or stale responses from issuing or applying redundant updates. The viewer must preserve the existing scale/fit behavior (including aspect-ratio handling) when matching is disabled or unavailable.
5. Preserve a documented rollback path while the driver implementation and package/signing migration are validated.

### Keyboard routing

Support explicitly selected modes rather than conflating transport with routing policy:

- **Pointer-over-canvas:** route remote keyboard input only while the pointer is over the active remote canvas and the window is usable/focused.
- **Focused-window:** route while the RustDesk window is focused, subject to view-only, dialog, and permission checks.
- **Explicit grab:** route only while an explicit grab is active.

For pointer-over-canvas mode, moving to the toolbar, a dialog, the GNOME panel, or outside the window must stop remote routing and release all held remote modifiers exactly once. Window blur, dialog opening, session disposal, tab switching, and missing pointer-exit fallbacks must fail closed. Relative-mouse recentering must not create a false re-entry.

### Controller-only Linux artifact

The Linux controller must be a true compile-time product boundary:

- no incoming host connection listener;
- no `--server` child or local host service registry;
- no systemd/service installation or service IPC;
- no local microphone capture, local controlled-host screen capture, DRM/KMS or PipeWire capture, uinput, evdev, local PTY/host terminal service or host-side terminal listener, printer, or host permission controls;
- retain outgoing video decode/render, remote audio playback, clipboard, file transfer, remote keyboard/mouse commands, address book, self-hosted-server configuration, controller-side screenshots and recording of the remote display, multimonitor support, and other existing outgoing controller capabilities;
- retain outgoing remote-terminal controller functionality if supported by upstream, while prohibiting any local PTY or host terminal service;
- exclude the host/service binary from build and package outputs.

Runtime flags, hidden widgets, and Flatpak sandboxing are not substitutes for compile-time exclusion.

### Minimal source-built Wayland Flatpak

Produce a source-built controller Flatpak with app ID `ch.flourish.RustDeskController`. If a technical constraint requires a different ID, record the constraint and decision before changing it.

The baseline sandbox should be Wayland-only and least-privilege: Wayland, network, and PulseAudio, plus narrowly scoped DRI GPU device access only when required for controller-side decode/render. DRI access must not include DRM/KMS capture, screen-capture backends, or local capture. Do not grant home or host filesystem access: user-selected imports/exports, screenshots, recordings, and file-transfer file access must use document/file-picker portals. Explicitly prohibit X11, ScreenCast and RemoteDesktop portal/session permissions, Flatpak D-Bus control, the system bus, host/service permissions, PAM, xdotool, local input-injection functionality or dependencies, and any uinput/evdev access. `/dev/dri` presence alone is not a failure; forbidden runtime indicators are DRM/KMS or PipeWire capture and unauthorized device use. The existing prebuilt-deb manifest is not sufficient.

## Objective acceptance criteria

A release candidate is acceptable only when all applicable evidence is attached to the reviewed PR or release record:

1. **Windows runtime:** real Windows x64 runtime evidence demonstrates cursor correctness, dynamic resolution, plug/unplug, mode updates, restart/recovery, privacy mode, DPI, and no duplicate/embedded cursor.
2. **GNOME Wayland:** real Ubuntu GNOME Wayland evidence demonstrates local Alt+Tab outside the canvas, remote Alt+Tab inside it, modifier release on exit/dialog/blur, and safe tab/session transitions.
3. **Controller artifact:** feature/build checks and artifact inspection prove host modules, listeners, service startup, local capture, local PTY/host terminal service, local input injection, and host-only dependencies are absent; retained outgoing functions listed above work, including remote-display screenshots/recording, multimonitor, and any upstream-supported outgoing remote terminal.
4. **Flatpak:** source build is reproducible from pinned sources; app ID is correct; permissions are reviewed; narrowly required DRI decode/render access is allowed but home/host filesystem grants, ScreenCast/RemoteDesktop portal or session permissions, system/Flatpak bus control, PAM, xdotool, local input injection, DRM/KMS or PipeWire capture, and host service activity are absent. User-selected file access uses document/file-picker portals.
5. **CI/release:** required Blacksmith jobs run on `blacksmith-8vcpu-ubuntu-2404` and `blacksmith-8vcpu-windows-2025`; artifacts have SBOMs, checksums, provenance, and reproducible version metadata; prerelease and actual runtime evidence exist before stable release.
6. **Governance:** every implementation PR has reviewed scope, tests, dependency/licence review, rollback notes, and upstream-sync impact assessment.

A missing runtime result is an unresolved requirement, not a pass.
