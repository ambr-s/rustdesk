# Upstream sync, maintenance, licensing, and signing policy

## Upstream sync policy

- Rebase or merge from the selected upstream base on a scheduled cadence and before each prerelease.
- Keep fork-specific changes additive and isolated behind named features where practical.
- Record upstream commit, conflict resolutions, generated-file refreshes, and behavior changes in each sync PR.
- Re-run the controller forbidden-module/dependency checks after upstream sync; new host services must not enter the controller closure silently.
- Re-run the Windows IDD, GNOME Wayland, Flatpak permission, and release evidence matrix after changes affecting those boundaries.
- Never claim upstream parity when a fork-specific patch changes protocol, driver, packaging, or permissions; document compatibility and rollback.
- Retain upstream notices and documentation. Fork documentation may add a notice, but must not replace the upstream README or licence text.

## AGPL obligations

RustDesk is distributed under AGPL-3.0-only as reflected by the repository metadata. A distributed modified binary or network-served modified program must preserve applicable licence and source-offer obligations. Releases must include the licence, copyright/attribution notices, corresponding source or a compliant source offer, build instructions, and a record of fork patches. Do not present proprietary driver or build inputs as part of the AGPL project without a separate legal review.

This is an engineering policy, not legal advice. The release owner must obtain legal review for any changed distribution model, hosted service, or bundled non-AGPL component.

## Third-party driver risks

- Verify the checked-in RustDesk IDD source's licence, exact covered files, notices, patent terms, provenance, and redistribution obligations before packaging; do not infer its licence from adjacent project metadata.
- Amyuni/`usbmmidd_v2` rights and redistribution terms must be verified before retaining or migrating its package.
- An alternative such as `parsec-vdd` may have permissive source metadata, but signed binaries, bundled components, trademarks, and source/build provenance require independent review.
- Every driver release needs a machine-readable third-party inventory, licence notices, source revisions, checksums, and an ownership decision for updates.

## Windows signing and upgrade risks

The RustDesk executable signature does not sign the driver package. The IDD INF, catalog, and driver binaries have separate Windows signing, installation, Secure Boot, and update requirements. Decide whether the release uses attestation, WHQL, or another supported path; record certificate ownership, timestamping, revocation/renewal, and test-signing restrictions. Do not distribute unsigned production drivers as if executable signing were sufficient.

Driver updates must be versioned, installable, rollback-capable, and tested against existing devices. Define uninstall/migration behavior before changing hardware IDs or replacing Amyuni. Keep signed-package hashes and provenance with the release record.

## Release controls

A release cannot be promoted if licence review, source notices, SBOM, checksums, provenance, or required runtime evidence is missing. Prereleases are the proving ground for actual Windows and GNOME Wayland evidence; stable releases repeat the checks rather than inheriting an unverified prerelease result.
