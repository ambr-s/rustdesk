# Controller fork specification

This directory defines the proposed controller-focused RustDesk fork. It is a specification and delivery roadmap, not evidence that the proposed capabilities are implemented.

- [Product requirements and acceptance](requirements.md)
- [Architecture and capability boundaries](architecture.md)
- [Phased issue/PR roadmap](roadmap.md)
- [Verification matrix](verification.md)
- [Upstream maintenance, licensing, and signing policy](maintenance-and-licensing.md)

## Phase 0 architecture decisions

- [ADR-0001: Cargo features and host/controller module graph](decisions/0001-cargo-features-and-module-graph.md)
- [ADR-0002: Rust/Flutter controller entrypoint and build coupling](decisions/0002-rust-flutter-controller-entrypoint.md)
- [ADR-0003: Decode-only media boundary](decisions/0003-decode-only-media-boundary.md)
- [ADR-0004: Dynamic-display protocol and acknowledgement](decisions/0004-dynamic-display-protocol.md)
- [ADR-0005: RustDesk IDD migration and rollback](decisions/0005-rustdesk-idd-migration.md)
- [ADR-0006: Source-pinned Flatpak policy and evidence schema](decisions/0006-flatpak-source-policy.md)

These records capture Phase 0 decisions and unresolved spikes; they do not claim implementation completion.

## Non-goals of this change

This documentation change does not add implementation code, CI workflows, Flatpak manifests, driver binaries, or release artifacts. Each claim about current RustDesk behavior is marked as an inventory/finding from the repository and must be re-verified when implementation begins.
