# ADR-0004: Dynamic-display capability, bounds, acknowledgement, and protocol reuse

- **Status:** Accepted for implementation planning
- **Scope:** Window-matched managed virtual-display resolution

## Decision

Reuse the existing display-resolution protocol for the first implementation, subject to a capability/bounds contract. Do not add a new wire message until a spike demonstrates that existing `ChangeDisplayResolution`/`ChangeResolution` dispatch cannot provide reliable capability gating and acknowledgement semantics.

A host that supports automatic matching must advertise:

- that the peer has a compatible RustDesk-managed virtual display;
- authoritative per-display minimum and maximum bounds;
- support for automatic viewport matching;
- the current/applied mode used as the acknowledgement baseline.

The representation should reuse existing display information and resolution-change responses where they are authoritative. If those structures cannot carry capability, bounds, and an unambiguous generation/applied-mode acknowledgement without breaking older peers, define a versioned additive extension (for example, a capability bit plus a request generation and applied mode). Do not invent a wire field in this ADR.

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

1. Inventory current display-info and resolution-change protobuf/types and peer-version behavior.
2. Add capability/bounds exposure using existing structures if possible; otherwise design an additive extension with compatibility tests.
3. Implement a pure client conversion/controller with generation, debounce, cancellation, tolerance, and acknowledgement tracking.
4. Gate requests on Windows, a managed virtual display, negotiated capability, authoritative bounds, and the per-peer preference.
5. Add re-synchronization hooks for display/DPI/window transitions.
6. Validate remote mode updates and preserve existing fit/scale behavior when matching is unavailable.

## Validation

- Unit tests cover even rounding, clamping, 350 ms debounce, 8-pixel tolerance, cancellation, generation ordering, and stale/echoed acknowledgements.
- Compatibility tests cover an older peer, unsupported capability, missing bounds, and a managed virtual display.
- Windows integration verifies actual mode application and re-sync after topology/DPI transitions.
- Runtime logs/evidence show no request loop and distinguish requested, acknowledged, and externally changed modes.

## Rollback

Keep the preference off and disable automatic requests through the capability gate. Existing manual `ChangeDisplayResolution` behavior remains available. If an extension is introduced and interoperability fails, stop advertising the capability and ignore the extension while retaining the old message path.

## Required spike before irreversible decisions

Run a protocol spike against representative old/new peers to determine whether current display structures can represent capability, authoritative bounds, and applied-mode acknowledgement. The result must include protobuf/type changes, compatibility behavior, and a decision between reuse and additive extension.
