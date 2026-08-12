---
status: complete
phase: 12-calibration-promotion-and-model-release
source: [12-00-SUMMARY.md, 12-01-SUMMARY.md, 12-02-SUMMARY.md, 12-03-SUMMARY.md, 12-04-SUMMARY.md, 12-05-SUMMARY.md, 12-06-SUMMARY.md, 12-07-SUMMARY.md, 12-08-SUMMARY.md, 12-UI-SPEC.md]
started: 2026-08-11T20:04:39Z
updated: 2026-08-12T07:34:51Z
---

## Current Test

[testing complete]

## Tests

### 1. Inspect the release-backed dashboard UI
expected: The release-backed dashboard shows the retained release summary, explicit primary probability and fitted-scoreline labels, provenance disclosure, release link, preserved tabs, and no page-level horizontal overflow.
result: pass

### 2. Review the five Phase 12 validation files
expected: The five exact `tests/testthat/test_phase12_*.R` files exist, parse, and remain scoped to synthetic contract validation.
result: pass

### 3. Review the sealed-boundary source scan
expected: The Wave 0 source and parsed-call scan enforces the sealed-boundary ownership contract without production sourcing, label access, fitting, or file-writing behavior.
result: pass

### 4. Review the calibration development gate
expected: The gate selects calibrated 1X2 only on strict improvement and all supporting vetoes; otherwise it retains raw 1X2 with ordered fallback reasons and preserves G=40 scoreline evidence.
result: pass

### 5. Review final-fit and unopened preflight
expected: Only `phase11_rf_dynamic_elo_open` is admissible, eight inactive candidates remain explicit no-score rows, and the label-free preflight blocks non-allowlisted or unopened-invalid paths before any provider call.
result: pass

### 6. Review the one-shot WC2026 evaluation and promotion
expected: The approved evaluation covers 104/104 fixtures exactly once, preserves the sealed boundary, records the incumbent-retained decision, and exposes challenger veto evidence without promoting the challenger.
result: pass

### 7. Review the core release bundle
expected: The versioned release root contains the incumbent-retained model, contract, manifests, report, model card, provenance, and matching SHA-256 metadata with G=40; tampered content fails closed.
result: pass

### 8. Review the approved consumer boundary
expected: Dashboard and export consumers resolve one approved or incumbent-retained release, expose release identity and primary-view metadata, keep challengers audit-only, and never expose WC2026 labels or select raw model paths by existence.
result: pass

### 9. Review completion, installation, and rollback
expected: Completed release metadata validates in a fresh process; same-root installation is an immutable no-op; an invalid replacement is rejected and the prior accepted release can be restored.
result: pass

### 10. Freeze identity is durable and self-hashed
expected: A canonical recipe and nine-row self-hashed freeze bind candidates, G=40, thresholds, component identities, and durable parents before fitting.
result: pass
source: automated
coverage_id: D1

### 11. Freeze drift fails closed
expected: Freeze drift, unsafe parent paths, dirty-code flags, threshold/support changes, and consumed-holdout markers fail closed with ordered reason codes.
result: pass
source: automated
coverage_id: D2

### 12. Inner-OOF assembly is chronology-safe
expected: Candidate/track inner-OOF assembly rejects mixed identities, duplicate fixtures, future editions, non-strict evidence dates, and holdout-bearing rows after validating the freeze.
result: pass
source: automated
coverage_id: D1

### 13. Temperature calibration is deterministic
expected: Frozen temperature calibration produces simplex-valid derived 1X2 probabilities, explicit raw fallback, and unchanged G=40 scoreline views.
result: pass
source: automated
coverage_id: D2

### 14. Calibration artifacts reconcile in a fresh process
expected: Durable inner-OOF CSV and calibrator RDS artifacts reconcile to the freeze, recipe, source hashes, row counts, and byte-stable fresh-process read-back.
result: pass
source: automated
coverage_id: D3

### 15. Raw and calibrated views share scoring identity
expected: Raw and calibrated derived 1X2 predictions use identical fixtures and shared proper-score services without changing G=40 scoreline evidence.
result: pass
source: automated
coverage_id: D1

## Summary

total: 15
passed: 15
issues: 0
pending: 0
skipped: 0
blocked: 0

## Verification Notes

- The `12-00` coverage entries use the unsupported verification kind `automated`; they remain manual checkpoints 2 and 3 despite passing underlying checks.
- The `12-03` D2 coverage entry uses the unsupported verification kind `contract`; it remains manual checkpoint 4 despite passing underlying checks.
- Browser verification and user confirmation covered the release-backed dashboard, collapsed bottom release disclosure, explicit raw 1X2 and fitted-scoreline labels, provenance disclosure, release link, five tabs, status/live-region hooks, and no page-level horizontal overflow.
- The approved consumer-boundary checkpoint passed: the incumbent-retained release remains the single consumer identity and challenger evidence remains audit-only.

## Gaps

<!-- YAML format for plan-phase --gaps consumption -->
[none yet]
