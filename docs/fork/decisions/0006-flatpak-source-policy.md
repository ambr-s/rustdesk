# ADR-0006: Source-pinned Flatpak policy and evidence schema

- **Status:** Accepted for implementation planning
- **Scope:** Source-built controller Flatpak, reproducibility, and evidence storage

## Decision

Create a dedicated source-built manifest for app ID `ch.flourish.RustDeskController`. Do not mutate the existing prebuilt-deb manifest into a source-build by implication. Every source, toolchain/module, generated input, and patch must be pinned by immutable revision or archive checksum, with update ownership recorded.

The manifest/build definition must invoke the matched Rust and Flutter controller profiles, install only the controller bundle and metadata, and omit host helpers, service binaries, systemd units, installer scripts, PAM, xdotool, local input-injection dependencies, and capture helpers. Baseline permissions are Wayland, network, PulseAudio, and narrowly justified DRI decode/render access. No X11, home/host filesystem, ScreenCast/RemoteDesktop permissions, Flatpak-management D-Bus access, unrestricted system bus, uinput/evdev, or local capture. User-selected imports/exports, screenshots, recordings, and file transfer use document/file-picker portals; any session-bus permission is limited to demonstrated portal-mediated needs.

Use a checked-in evidence directory with one machine-readable record per source/build/permission/runtime result:

```text
docs/fork/evidence/
  README.md
  sources.json
  permissions.json
  builds/<build-id>.json
  runtime/<run-id>.json
  schemas/evidence.schema.json
```

The schema must require: evidence `id`, `kind`, `status` (`pass`, `fail`, `blocked`, or `not-run`), UTC `recorded_at`, commit/source revision, command or test procedure, environment/runner, artifact or log paths, checksums where applicable, reviewer/owner, and notes. A result may be `blocked` or `not-run`; it must never be represented as a pass by omission. Do not add fabricated evidence in Phase 0; add only the schema/policy or leave records absent until a real run exists.

## Evidence from the current tree

- `flatpak/rustdesk.json:2` uses app ID `com.rustdesk.RustDesk`, not the controller ID.
- `flatpak/rustdesk.json:13-35` builds xdotool and PAM.
- `flatpak/rustdesk.json:37-53` extracts a local `rustdesk.deb`; it does not compile RustDesk/Flutter from source.
- `flatpak/rustdesk.json:56-64` grants X11, home filesystem, DRI, PulseAudio, and unrestricted Flatpak D-Bus access in addition to Wayland/network/IPC.
- Approved requirements require the controller app ID, source reproducibility, portals, and least privilege. These are target decisions, not claims about the existing manifest.

## Alternatives considered

1. **Reuse the existing `com.rustdesk.RustDesk` prebuilt-deb manifest:** rejected; it violates source-build and controller-boundary requirements.
2. **Use floating git branches/tags:** rejected; not reproducible enough for release evidence.
3. **Grant home filesystem access to avoid portal work:** rejected; contrary to the approved sandbox requirement.
4. **Store evidence only in PR prose:** rejected; it is not machine-checkable or durable across releases.
5. **Commit generated logs/artifacts:** rejected unless small, reviewable, and accompanied by provenance; store large outputs externally and record immutable references/checksums.

## Migration sequence

1. Define the manifest identity, source pin format, update owner, and evidence schema.
2. Build a source-only proof of concept with the matched Rust/Flutter controller selections.
3. Add portal-backed file operations and verify screenshots/recordings refer to remote display data only.
4. Reduce permissions and test software/GPU decode variants; retain DRI only when evidence demonstrates need.
5. Add reproducible build, SBOM, checksum, provenance, artifact-forbidden-content, and sandbox runtime checks.
6. Expand from Phase 0 baseline CI to the full Flatpak/release matrix only after the controller graph exists.

## Validation

- `flatpak-builder --force-clean` builds from pinned sources without local `.deb` inputs.
- Repeated builds have matching version metadata and recorded checksums where reproducibility is applicable.
- Manifest inspection confirms app ID and no forbidden permissions/modules.
- Sandbox runtime checks confirm Wayland window, networking, PulseAudio playback, portal file access, and absence of host service, local capture, input injection, X11, and unrestricted bus activity.
- Evidence records validate against `schemas/evidence.schema.json` and link to actual logs/artifacts.

## Rollback

Keep the existing manifest untouched as a historical/upstream package definition while the dedicated controller manifest is experimental. If source build or permissions fail, do not promote the controller app; revert the new manifest/build invocation and retain the last known package only as a non-controller fallback, clearly labeled as such.

## Required spike before irreversible decisions

A source-build/permission spike must prove Flutter/Rust toolchain pinning, portal APIs used by file transfer and remote-display capture/recording, and whether DRI is required for decode/render. Its output must populate real evidence records before any permission or manifest identity is declared final.
