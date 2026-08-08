# Verification matrix

The matrix distinguishes static checks from real runtime evidence. “Pass” requires recorded output, artifact identifiers, environment details, and date; “not run” or “not reproducible” is unresolved.

| Area | Environment | Checks | Required evidence / acceptance |
|---|---|---|---|
| Rust controller compile | Ubuntu runner `blacksmith-8vcpu-ubuntu-2404` | locked metadata/tree/build; forbidden host modules/dependencies | controller feature compiles; host/service binary and host-only dependency closure are absent |
| Controller runtime | Ubuntu 24.04 Wayland sandbox and unsandboxed comparison | process tree, `bind`/`listen`, systemd, device and IPC observation | no incoming RustDesk listener, `--server`, systemd/service IPC, uinput, evdev, DRM/PipeWire capture; outgoing connection, video, playback, clipboard, files, address-book config work |
| GNOME keyboard | Ubuntu GNOME Wayland, `XDG_SESSION_TYPE=wayland`, `XDG_CURRENT_DESKTOP=GNOME` | pointer/canvas, toolbar/dialog, panel/outside, blur, tabs, relative mouse | remote Alt+Tab only in permitted mode; local Alt+Tab outside; all modifiers released on exit/dialog/blur/disposal; no false re-entry |
| Flutter/Rust tests | pinned project toolchains | policy, modifier, transition, widget, keyboard ownership tests | enter/exit idempotence; stale owner cannot release another session; left/right modifiers and AltGr are released |
| Windows build | `blacksmith-8vcpu-windows-2025` | locked build, driver/package validation, artifact metadata | x64 RustDesk and IDD package build; INF/CAT/binaries present; signing/provenance/checksums recorded |
| Windows real runtime | real Windows x64 host/VM, including Windows 11 24H2; Secure Boot where supported | install/update/uninstall, display enumeration, cursor and mode smoke tests | hardware cursor shape/hotspot/position/visibility works; no duplicate or frame-embedded cursor; plug/unplug, indexed monitors, dynamic viewport resolution, restart, sleep/resume, RDP attach/detach, privacy mode, high DPI pass |
| IDD rollback | Windows test host with prior driver | upgrade, rollback, stale-device cleanup | no orphaned monitors; migration does not silently replace an installed hardware ID; failure recovery documented |
| Flatpak build | Ubuntu runner `blacksmith-8vcpu-ubuntu-2404` | source-only `flatpak-builder --force-clean`; pinned source/checksum audit | source-built artifact has app ID `ch.flourish.RustDeskController`; no prebuilt `.deb` extraction; SBOM/checksums/provenance generated |
| Flatpak permissions | installed controller Flatpak | manifest inspection and runtime permission audit | Wayland/IPC/network/PulseAudio and only justified filesystem scope; no X11, Flatpak D-Bus control, PAM, xdotool, or device/DRM permission without approved exception |
| Flatpak runtime | Ubuntu GNOME Wayland | `flatpak run`, process/network/device observation | app opens on Wayland; outgoing functions work; no host listener, systemd contact, `/dev/uinput`, `/dev/input`, `/dev/dri`, or capture/service activity |
| Release | prerelease and stable channels | reproducibility, SBOM, checksum, provenance and licence notices | prerelease contains actual runtime evidence links; stable repeats all required checks and publishes source/third-party notices |

## Evidence record

Store logs, test scripts, artifact SHA-256 values, SBOM, provenance attestations, driver package hashes, Flatpak manifest revision, host OS/session details, and screenshots/video where useful. Evidence must identify the exact commit and artifact; do not substitute a CI compile log for real Windows or Wayland behavior.

## Negative checks

The controller artifact must be checked both by feature/dependency graph and by defense-in-depth process/string inspection. Forbidden indicators include host service modules, `--server`, service startup, `systemctl`, uinput/evdev, capture service IPC, and Flatpak control-bus access. String scans alone are not proof and must not be used to waive runtime checks.
