# ADR-0004: Dynamic-display capability, bounds, acknowledgement, and protocol extension

- **Status:** Accepted additive protocol contract; implementation blocked on protobuf spike
- **Scope:** Window-matched managed virtual-display resolution

## Decision

Preserve existing `ChangeDisplayResolution`/`ChangeResolution` messages for manual resolution changes and old-peer compatibility. Automatic viewport matching uses an additive, versioned protocol extension because the existing request and `SwitchDisplay` structures do not carry negotiated capability, request generation, or an unambiguous applied-mode result.

The extension adds three logical messages to unused `Misc.oneof` variants; final field numbers are selected against the rebased protobuf at implementation time:

- `ManagedDisplayCapabilities` (host to controller): protocol version, display index, managed-display identity, viewport-matching support, authoritative minimum/maximum even pixel dimensions, and current applied mode;
- `ManagedDisplayResolutionRequest` (controller to host): display index, requested even pixel dimensions, and a non-zero monotonically increasing per-session `uint64` generation; and
- `ManagedDisplayResolutionResult` (host to controller): display index, generation, requested mode, actual applied mode, and an `applied` or `rejected` status with an optional bounded diagnostic.

The host advertises capability only for a RustDesk-managed display that accepts arbitrary even modes throughout the advertised bounds. A discrete-mode-only display does not advertise viewport matching. The controller never sends the new request before receiving compatible capability. Protobuf unknown-field behavior keeps old peers interoperable; an old or unsupported peer receives no automatic request and continues using the manual message path. Results with an unknown display or stale generation are ignored. A rejection disables further automatic requests for that display until capability is refreshed or the user retries.

Client semantics are fixed by the approved requirements: usable remote-canvas logical dimensions × local Flutter view DPR; nearest positive even dimensions; clamp to advertised bounds; 350 ms debounce; cancellation of superseded requests; suppress when both dimensions differ from the last acknowledged mode by less than 8 physical pixels; default off per peer; re-sync after fullscreen, maximise, monitor, and DPI changes; ignore stale generations and echoed modes.

## Evidence from the current tree

- `src/ui_session_interface.rs:1561-1593` sends `ChangeResolution` or `ChangeDisplayResolution`.
- `src/server/connection.rs:3753-3762` receives the existing messages and `4561-4613` routes virtual-display changes.
- `src/virtual_display_manager.rs:352-380` updates RustDesk IDD monitor modes.
- `src/server/video_service.rs:1267-1315` emits `SwitchDisplay` with dimensions, supported resolutions, scale, and original resolution.
- `flutter/lib/desktop/pages/remote_page.dart:986-1041` observes viewport geometry but currently updates local canvas state rather than requesting remote resize.
- `flutter/lib/models/model.dart:2224-2421` tracks viewport, remote dimensions, scale, DPR, and offsets.

These paths establish reusable plumbing; they do not establish that existing messages already carry the required capability, bounds, or acknowledgement contract.

## Alternatives considered

1. **Add a dedicated `ViewportResizeRequest` immediately:** deferred. It increases protobuf/generated-code and compatibility surface before proving reuse insufficient.
2. **Send raw viewport sizes without capability/bounds:** rejected. It risks unsupported peers, invalid modes, and feedback loops.
3. **Use remote display scale as local DPR:** rejected. Remote scale is not the local Flutter view's physical-pixel ratio.
4. **Enable matching by default:** rejected. The requirement makes it opt-in per peer.

## Migration sequence

1. Rebase and inventory current protobuf field allocation and peer-version behavior, then reserve non-conflicting additive `Misc.oneof` fields for the three messages above.
2. Generate Rust/protobuf bindings and add old-peer/new-peer compatibility tests before UI integration.
3. Implement a pure client conversion/controller with generation, debounce, cancellation, tolerance, and acknowledgement tracking.
4. Gate requests on Windows, a managed virtual display, negotiated capability, authoritative bounds, and the per-peer preference.
5. Add re-synchronization hooks for display/DPI/window transitions.
6. Validate remote mode updates and preserve existing fit/scale behavior when matching is unavailable.

## Validation

- Unit tests cover even rounding, clamping, 350 ms debounce, 8-pixel tolerance, cancellation, generation ordering, and stale/echoed acknowledgements.
- Compatibility tests cover older peers ignoring the extension, unsupported capability, missing/invalid bounds, duplicate and stale generations, explicit rejection, clamped/applied mismatch, and a compatible managed virtual display.
- Windows integration verifies actual mode application and re-sync after topology/DPI transitions.
- Runtime logs/evidence show no request loop and distinguish requested, acknowledged, and externally changed modes.

## Rollback

Keep the preference off and disable automatic requests through the capability gate. Existing manual `ChangeDisplayResolution` behavior remains available. If an extension is introduced and interoperability fails, stop advertising the capability and ignore the extension while retaining the old message path.

## Required spike before irreversible decisions

Run a protobuf compatibility spike against representative old/new peers to validate unknown-field handling, reserve concrete non-conflicting field numbers, bound the diagnostic field, and prove the generation/result state machine. Automatic matching implementation remains blocked until that spike passes; the additive-extension decision itself is accepted.
