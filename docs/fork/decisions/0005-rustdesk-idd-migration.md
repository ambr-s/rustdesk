# ADR-0005: RustDesk IDD first, Amyuni rollback, and licence/signing gates

- **Status:** Accepted for implementation planning
- **Scope:** Windows virtual-display implementation and migration

## Decision

Evaluate and extend the checked-in RustDesk IDD path first. Do not adopt Amyuni as the long-term strategy, and do not replace it in production merely by changing a Rust constant. Keep Amyuni available as an explicit rollback path until RustDesk IDD lifecycle, cursor capability, migration, packaging, and Windows runtime evidence pass.

The durable target is `rustdesk_idd` with indexed monitor allocation, plug-in/out, and per-monitor mode updates. Hardware-cursor support is an unresolved capability gate: inspect the actual driver source and IddCx callbacks, then implement the minimum missing path or record a reviewed alternative. No licence, redistribution right, signing status, or hardware-cursor behavior may be inferred from names or adjacent repositories.

The migration must define device cleanup, hardware IDs, INF/catalog versioning, installed-driver upgrade behavior, downgrade/rollback, and privacy-mode restoration before changing the production default. The executable signature is not a driver-package signature.

## Evidence from the current tree

- `src/virtual_display_manager.rs:8-10` selects `IDD_IMPL_AMYUNI` while defining both RustDesk and Amyuni implementations.
- `src/virtual_display_manager.rs:72-120` shows RustDesk supports indexed plug-in/out dispatch while Amyuni uses a different monitor-count/IOCTL path.
- `src/virtual_display_manager.rs:131-381` contains RustDesk IDD device creation, indexed allocation, mode updates, and peer bookkeeping.
- `src/virtual_display_manager.rs:384-420` contains Amyuni-specific installer/IOCTL/count behavior.
- `src/core_main.rs:294-313` exposes RustDesk IDD install and Amyuni uninstall commands.
- `libs/virtual_display/src/lib.rs` and `libs/virtual_display/dylib/src/win10/` provide the RustDesk control/FFI path.
- Existing fork requirements explicitly require cursor correctness and a rollback path; repository inventory does not prove the current driver has hardware-cursor callbacks.

## Alternatives considered

1. **Switch the constant to RustDesk IDD now:** rejected as insufficient evidence and unsafe migration.
2. **Keep Amyuni permanently:** rejected because its lifecycle/global-count limitations do not satisfy the durable strategy without a separate acceptance case.
3. **Adopt an external driver such as Parsec VDD:** deferred unless RustDesk IDD cannot satisfy the cursor contract and source, redistribution, trademark, signing, and maintenance review passes.
4. **Remove Amyuni immediately:** rejected until rollback and stale-device cleanup are tested.

## Migration sequence

1. Inspect the checked-in RustDesk IDD source, cursor callbacks, INF/CAT, notices, and provenance.
2. Run a hardware-cursor capability spike and a lifecycle matrix without changing the default.
3. Add an explicit selection gate/configuration for RustDesk IDD; retain Amyuni fallback.
4. Validate indexed plug/unplug, mode updates, restart/recovery, privacy mode, RDP, and Windows 24H2 behavior.
5. Define migration/uninstall/rollback and versioned signed package handling.
6. Obtain licence/redistribution and signing-owner approvals.
7. Switch the production default only after real Windows evidence and package validation.

## Validation

- Real Windows x64 tests cover cursor shape/hotspot/visibility/position/update ordering, no duplicate/embedded cursor, plug/unplug, modes, recovery, privacy mode, DPI, Secure Boot, and installed/portable builds.
- Driver package validation separately checks INF, catalog, binaries, signatures, installation, update, uninstall, and rollback.
- Licence review records exact covered files, notices, source revisions, redistribution terms, and ownership; it must not claim unverified terms.
- Upgrade tests prove no stale Amyuni monitors/devices remain and no silent hardware-ID replacement occurs.

## Rollback

Keep the previous Amyuni package and selection path documented and installable. On failed RustDesk IDD rollout, stop selecting it, restore the prior package/driver mapping, clean only devices proven to belong to the attempted migration, and preserve logs/package hashes. Rollback must not leave a mixed or stale virtual-display topology.

## Required spike before irreversible decisions

The hardware-cursor and provenance spike is mandatory. It must answer whether the checked-in RustDesk IDD implements the required IddCx callbacks, identify the minimum driver change, and produce verified licence/signing/redistribution evidence. Until then, the final driver and production-default decision remains open.
