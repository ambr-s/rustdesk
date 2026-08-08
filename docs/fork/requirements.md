# Product requirements and objective acceptance criteria

## Objective

Deliver a controller-only RustDesk distribution that connects to and controls remote peers while not compiling, packaging, starting, or listening as a local RustDesk host on Linux. Improve Windows virtual-display behavior and make keyboard routing safe and predictable on GNOME Wayland.

The fork must preserve upstream documentation and remain recognizable as a RustDesk derivative. This document specifies desired behavior; it does not claim any requirement is currently satisfied.

## Functional requirements

### Windows virtual display

1. Prefer evaluating the existing `libs/virtual_display` and `rustdesk_idd` implementation before adopting another driver.
2. The selected Windows IDD must support a hardware cursor, including cursor shape, hotspot, position, visibility, updates, and correct ordering. Switching a RustDesk constant alone is not acceptance evidence.
3. Provide indexed monitor allocation, automatic plug-in/plug-out, and per-monitor mode updates.
4. Match the managed virtual display to the active remote viewport dynamically, with DPR-aware physical-pixel conversion, bounds, debounce, cancellation, and stale-response protection.
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
- no local microphone capture, screen capture, DRM/PipeWire capture, uinput, evdev, terminal, printer, or host permission controls;
- retain outgoing video decode/render, remote audio playback, clipboard, file transfer, remote keyboard/mouse commands, address book, and self-hosted-server configuration;
- exclude the host/service binary from build and package outputs.

Runtime flags, hidden widgets, and Flatpak sandboxing are not substitutes for compile-time exclusion.

### Minimal source-built Wayland Flatpak

Produce a source-built controller Flatpak with app ID `ch.flourish.RustDeskController`. If a technical constraint requires a different ID, record the constraint and decision before changing it.

The baseline sandbox should be Wayland-only and least-privilege: IPC, Wayland, network, and PulseAudio, plus only the filesystem access proven necessary for current file-transfer behavior. Do not grant X11, Flatpak D-Bus control, host/service permissions, PAM, xdotool, or device/DRM access without a separately reviewed requirement and evidence. The existing prebuilt-deb manifest is not sufficient.

## Objective acceptance criteria

A release candidate is acceptable only when all applicable evidence is attached to the reviewed PR or release record:

1. **Windows runtime:** real Windows x64 runtime evidence demonstrates cursor correctness, dynamic resolution, plug/unplug, mode updates, restart/recovery, privacy mode, DPI, and no duplicate/embedded cursor.
2. **GNOME Wayland:** real Ubuntu GNOME Wayland evidence demonstrates local Alt+Tab outside the canvas, remote Alt+Tab inside it, modifier release on exit/dialog/blur, and safe tab/session transitions.
3. **Controller artifact:** feature/build checks and artifact inspection prove host modules, listeners, service startup, and host-only dependencies are absent; outgoing functions listed above work.
4. **Flatpak:** source build is reproducible from pinned sources; app ID is correct; permissions are reviewed; sandbox runtime shows no incoming listeners, systemd contact, uinput, DRM, or host service activity.
5. **CI/release:** required Blacksmith jobs run on `blacksmith-8vcpu-ubuntu-2404` and `blacksmith-8vcpu-windows-2025`; artifacts have SBOMs, checksums, provenance, and reproducible version metadata; prerelease and actual runtime evidence exist before stable release.
6. **Governance:** every implementation PR has reviewed scope, tests, dependency/licence review, rollback notes, and upstream-sync impact assessment.

A missing runtime result is an unresolved requirement, not a pass.
