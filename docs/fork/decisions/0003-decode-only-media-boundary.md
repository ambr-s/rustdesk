# ADR-0003: Decode-only separation from capture, scrap, and media dependencies

- **Status:** Accepted for implementation planning
- **Scope:** Controller dependency closure and `libs/scrap` capability split

## Decision

Create an explicit decode/render boundary for the controller. The controller may use codec and remote-frame decode types, but it must not compile local screen/camera capture, PipeWire/Wayland capture, DRM/KMS capture, X11 capture, uinput, or local microphone capture.

Prefer adding a `decode` feature to `libs/scrap` and making capture backends opt-in (`capture`, `wayland`, `drm`, and platform-specific capture features). The exact feature names are subordinate to the invariant: controller dependency resolution must select decode-only functionality and no capture backend. If `scrap` cannot cleanly provide that boundary, move the minimum shared decode types into a neutral crate/module rather than retaining `scrap` wholesale.

Remote audio playback remains in the outgoing client path. Local microphone/voice-call capture must be gated out of the controller profile. Do not remove playback or remote-display screenshot/recording functionality, which operates on the remote stream.

`src/audio_service.rs` and its native input-device dependency closure are host/local-capture capability. The `start_voice_call()` path in `src/client/io_loop.rs` currently subscribes to `audio_service::NAME`, configures a local input device, and forwards captured audio. The controller profile must not compile that recorder/subscription path or expose voice-call input controls. Incoming remote audio-frame decode and playback stay in a neutral outgoing-client playback path and must not depend on `audio_service` capture startup.

## Evidence from the current tree

- `Cargo.toml:55` unconditionally requests `scrap` with `features = ["wayland"]`.
- `libs/scrap/Cargo.toml:12-27` exposes `wayland`, `drm`, codec, and hardware features but no decode-only feature; `wayland` enables GStreamer, D-Bus, tracing, and zbus.
- `libs/scrap/Cargo.toml:64-70` has Linux capture dependencies including D-Bus/GStreamer.
- `src/client/io_loop.rs` contains outgoing playback and also microphone/voice-call capture paths (inventory finding; exact split must be confirmed during implementation).
- Existing architecture inventory identifies `src/server/video_service.rs`, `src/server/wayland.rs`, `src/server/drm_capturer.rs`, `src/server/input_service.rs`, `src/server/uinput.rs`, and `src/server/rdp_input.rs` as host-side capture/input edges.

The source inventory does not prove which individual codec symbols can be extracted without compilation; that is the purpose of the spike below.

## Alternatives considered

1. **Keep all `scrap` features and rely on Flatpak permissions:** rejected. Sandboxing does not provide compile-time exclusion and may still ship capture dependencies.
2. **Delete `scrap` from the controller:** rejected until decode/render ownership is proven; it risks breaking remote video.
3. **Copy the entire decoder into the root crate:** rejected as duplication and upstream-sync debt.
4. **Split every media subsystem immediately:** deferred. Start with the smallest boundary proven by dependency analysis.

## Migration sequence

1. Produce a feature/dependency map for `scrap`, `src/client`, and media crates.
2. Add the smallest decode-only feature/module boundary with capture features opt-in.
3. Gate `audio_service`, `start_voice_call()`, voice-call input configuration, and their native recorder dependencies separately from remote audio-frame decode/playback.
4. Gate host capture/input modules through `host-services`.
5. Build the controller with `--no-default-features --features controller-only,flutter,use_dasp` and inspect `cargo tree`.
6. Remove or narrow any remaining capture dependency edges, then update packaging.

## Validation

- `cargo tree --locked` for the controller contains no PipeWire/GStreamer/DRM/X11 capture or local input-injection closure unless a dependency is demonstrably decode-only.
- Compile-time/source checks reject host capture modules and the local microphone path.
- A controller compile test rejects references to `audio_service::NAME`, `set_voice_call_input_device`, and recorder startup, while focused playback tests still decode and play received remote audio frames.
- Controller runtime exercises remote video decode/render, remote audio playback, remote-display screenshot/recording, and file transfer.
- Host profile still compiles and retains local host capabilities.
- Artifact inspection is defense-in-depth; Cargo feature/module graphs remain authoritative.

## Rollback

Keep the prior `scrap` feature selection and host profile available while the decode split is validated. If the split breaks remote playback/decode, revert the controller dependency selection and refine the boundary before removing any old path.

## Required spike before irreversible decisions

Build a minimal controller target and produce `cargo tree -e features` plus a symbol/import inventory for remote video decode, playback, `src/audio_service.rs`, and `start_voice_call()`. The spike must identify whether decode lives in `scrap`, `src/client`, or another crate, and enumerate the native recorder dependencies that disappear, before naming a final public feature API.
