---
phase: 12-calibration-promotion-and-model-release
plan: 06
subsystem: release
tags: [phase12, release, hashes, model-card, incumbent-retained]
requires:
  - Phase 12 final evaluation manifest
  - Phase 12 freeze manifest
  - exact incumbent-retained promotion decision
provides:
  - hash-validated core release publisher
  - fail-closed release bundle validator
  - versioned incumbent-retained release root
affects: [phase12-release-install, phase12-consumers]
status: complete
completed: 2026-08-11
---

# Phase 12 Plan 06: Core Release Bundle Summary

## Outcome

Published and validated the core versioned release for the exact 'incumbent retained'
decision. The selected consumer identity is 'open_nb_incumbent', track 'updating',
panel 'open_core', score support 'G=40', with 'raw_1x2' as the primary view.

## Implementation

- Added R/release/release_bundle.R with staged publication, trusted relative
  paths, SHA-256 manifest rows, model contract, provenance, benchmark report,
  model card, identity checks, and label-content rejection.
- Core artifacts are staged under
  outputs/releases/phase12-wc2026-incumbent-retained-v1.
- Challenger failures remain audit evidence; they do not become consumer authority.

## Verification

- Core stage: PHASE12_CORE_RELEASE_OK.
- Complete bundle read-back passed in a fresh R process.
- Manifest self-hash, model/calibrator identity, status, panel, track, and G=40
  checks passed.
- A tampered model contract was rejected before the accepted release changed.

The large binary model artifact remains a local release output rather than being
added to the source commit; the publisher and all hash-bearing manifests are
versioned in code.

## Commit

- 03adb2c — feat(12-07): publish approved release consumer boundary

---
*Phase: 12-calibration-promotion-and-model-release*
*Plan: 06*
