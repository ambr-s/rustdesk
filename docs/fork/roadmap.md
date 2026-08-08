# Phased issue and PR roadmap

Each phase should be a small, reviewable issue/PR series. Dependencies are explicit; do not merge later phases on the assumption that an earlier capability works.

## Phase 0 — inventory and decisions

**Issues:** freeze current upstream base; map host/client module edges; inspect IDD cursor callbacks; inventory Flatpak sources/permissions; identify licence and signing owners.

**PR:** documentation and test-plan updates only.

**Exit:** decisions recorded for feature names, controller entrypoint, IDD strategy, Flatpak source pins, and evidence storage. No feature is declared complete from static inspection alone.

## Phase 1 — capability spikes

**Depends on:** Phase 0.

**Issues:** hardware-cursor spike against existing `rustdesk_idd`; viewport sizing/debounce spike; keyboard policy and modifier-release tests; source-built Flatpak proof of concept.

**PRs:** one narrowly scoped spike per capability, each with a reproducible result and rollback note. A failed spike is a useful outcome and must not be hidden.

**Exit:** choose RustDesk IDD extension versus reviewed alternative; choose protocol reuse versus extension; identify minimum Flatpak permissions and build inputs.

## Phase 2 — compile-time controller boundary

**Depends on:** Phase 1 decisions; no dependency on the final Windows driver.

**Issues:** add Rust feature gates; isolate outgoing audio playback from local capture; remove host startup/listeners; add Flutter controller composition; exclude service binary and host dependencies.

**PRs:**

1. Rust feature/module graph and compile checks.
2. Client/media split preserving playback and removing microphone capture.
3. Flutter controller entrypoint and UI boundary.

**Exit:** controller build compiles with host modules absent and has no incoming listener or service startup in a real run.

## Phase 3 — input policy and viewport matching

**Depends on:** Phase 2 controller composition; Phase 1 policy spikes.

**Issues:** pure keyboard policy; idempotent enter/leave cleanup; dialogs/tabs/blur/disposal; GNOME Wayland runtime matrix; viewport-to-physical-pixel conversion; debounced resolution requests and persistence preference.

**PRs:** separate policy/tests, UI lifecycle, and resize controller changes. Do not bundle unrelated UI refactors.

**Exit:** objective GNOME Wayland evidence and Flutter/Rust unit/widget tests pass; unresolved native-grab limitations are documented.

## Phase 4 — Windows IDD and packaging

**Depends on:** Phase 1 IDD decision and Phase 3 resolution contract.

**Issues:** hardware-cursor implementation/driver integration; indexed lifecycle and recovery; dynamic modes; driver package migration/rollback; Windows signing and installation validation.

**PRs:** keep driver changes, Rust integration, packaging/signing, and runtime tests separately reviewable. Do not make the production default until real Windows evidence exists.

**Exit:** Windows runtime matrix passes on `blacksmith-8vcpu-windows-2025` plus a real Windows validation host; driver licence and redistribution review is complete.

## Phase 5 — source-built Flatpak and CI

**Depends on:** Phase 2 controller boundary; Phase 3 runtime behavior; pinned source/build inputs.

**Issues:** source-built manifest with app ID `ch.flourish.RustDeskController`; permission audit; SBOM/checksums/provenance; Blacksmith build jobs; artifact forbidden-module/listener checks.

**PRs:** manifest/build definition, CI validation, and release metadata should be independently reviewed. This roadmap deliberately does not add workflows in the specification commit.

**Exit:** clean build using `blacksmith-8vcpu-ubuntu-2404`; Flatpak sandbox/runtime evidence; artifact contents and permissions match the matrix.

## Phase 6 — prerelease and stable release

**Depends on:** all previous exit criteria.

Create a prerelease with signed/published checksums, SBOM, provenance, source and dependency notices, migration/rollback notes, and links to actual Windows, Ubuntu GNOME Wayland, controller-artifact, Flatpak, and CI evidence. Gather issue feedback, fix release blockers, and repeat the matrix before stable release.

## Reviewed PR workflow

Every implementation PR must include: scope and dependency phase; acceptance criteria; tests and commands; runtime evidence or an explicit reason it is not applicable; security/licence impact; generated-file/source-pin changes; rollback plan; and upstream-sync notes. Require at least one owner for affected Rust/Flutter/platform packaging areas. A reviewer may reject claims based only on compilation when the requirement is runtime or driver behavior.
