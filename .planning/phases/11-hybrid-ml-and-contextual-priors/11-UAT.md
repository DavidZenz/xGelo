---
status: human_needed
phase: 11-hybrid-ml-and-contextual-priors
source: [11-01-SUMMARY.md, 11-02-SUMMARY.md, 11-03-SUMMARY.md, 11-04-SUMMARY.md, 11-05-SUMMARY.md, 11-06-SUMMARY.md, 11-07-SUMMARY.md, 11-VERIFICATION.md]
started: 2026-08-09T20:16:53Z
updated: 2026-08-10T07:35:57Z
---

## Current Test

[automated testing complete; substantive structural-prior review pending]

## Tests

### 1. Open RF tracer reaches the common score service
expected: The open RF tracer traverses registry, fold-local evidence, ranger fit/predict, NB G=40 distributions, market reconciliation, feature coverage, and the common score service.
result: pass
source: automated
coverage_id: D1

### 2. RF tuning and ranger provenance are deterministic
expected: Registered RF tuning and ranger provenance are deterministic, hashed, persisted, and fail closed on unregistered settings or runtime drift.
result: pass
source: automated
coverage_id: D2

### 3. Context evidence is point-in-time and provenance-tracked
expected: Point-in-time host, neutral, rest, travel, and tournament-stage evidence is built with explicit companions and no silent imputation.
result: pass
source: automated
coverage_id: D1

### 4. Context parent data validates offline
expected: Country-centroid rows and metadata validate offline with source, vintage, license, derivation, and parent SHA-256 provenance.
result: pass
source: automated
coverage_id: D2

### 5. Context ablations preserve the benchmark denominator
expected: The full context bundle and five named drop-one ablations are registry-backed on the unchanged open_core denominator.
result: pass
source: automated
coverage_id: D3

### 6. Context candidates use the common score schema
expected: Context candidates dispatch through the common adapter, proper-score runner, and sealed G=40 score-distribution schema.
result: pass
source: automated
coverage_id: D4

### 7. xG coverage gate remains explicitly inactive
expected: The D-12 xG coverage, variance, and provenance gate stays explicitly inactive under current repository evidence.
result: pass
source: automated
coverage_id: D1

### 8. Structural evidence rejects unsafe inputs
expected: Vintage-safe structural sources and continuous shrinkage reject unregistered, current, post-cutoff, or checksum-mismatched evidence.
result: pass
source: automated
coverage_id: D2

### 9. Structural adapter applies continuous shrinkage
expected: The registered structural adapter applies prior diagnostics to inherited RF means and emits the sealed G=40 schema.
result: pass
source: automated
coverage_id: D3

### 10. Structural candidate is wired into the common runner
expected: The structural candidate reaches predictions, proper-score metrics, comparison inputs, and the common 630/609/G=40 runner manifest when its evidence gate passes.
result: pass
source: automated
coverage_id: D4

### 11. Mode registry separates open, enriched, and external paths
expected: Open, enriched squad, and external market modes are separately labelled, licensed, panel-bound, and promotion-boundary validated.
result: pass
source: automated
coverage_id: D1

### 12. Manual market mode fails closed
expected: The optional manual market path validates frozen licensed 1X2 probabilities and fails closed without blocking open mode.
result: pass
source: automated
coverage_id: D2

### 13. Phase 11 target DAG stays downstream-only
expected: The six-node Phase 11 targets DAG runs downstream from Phase 09/10 and local Phase 11 registries.
result: pass
source: automated
coverage_id: D1

### 14. Bundle preserves exact panel and score-support contracts
expected: The canonical hybrid bundle contains exact 630 open, 609 rich, and G=40 evidence with checksums.
result: pass
source: automated
coverage_id: D2

### 15. Optional modes publish explicit inactive reasons
expected: Optional xG, context, structural, enriched, and external modes are separated and fail closed with explicit reasons when evidence is unavailable.
result: pass
source: automated
coverage_id: D3

### 16. Comparisons and shortlist remain research-only
expected: Research-only comparisons and a non-exclusive evidence-linked shortlist are ready for Phase 12 without promotion authority.
result: pass
source: automated
coverage_id: D4

### 17. WC2026 and Phase 12 authority remain protected
expected: Protected-path flags seal WC2026 and keep Phase 12 as the only decision authority.
result: pass
source: automated
coverage_id: D5

### 18. Ranger archive and installed runtime are checksum-backed
expected: Official CRAN ranger 0.18.0 is captured, checksum-verified, installed locally, and loaded by the target manifest.
result: pass
source: automated
coverage_id: D1

### 19. Offline ranger replay fails closed on tampering
expected: Offline replay validates provenance, archive, dependency inventory, installed contents, exact version, and .libPaths() wiring.
result: pass
source: automated
coverage_id: D2

### 20. Project-local Phase 11 library is wired before targets
expected: The project-local Phase 11 library contains only ranger and is wired before target package loading.
result: pass
source: automated
coverage_id: D3

### 21. Review the RF challenger evidence
expected: Open the Phase 11 challenger bundle and confirm that the open RF candidate has independent home/away goal means, fold-local dynamic/Elo evidence, complete G=40 score distributions, reconciled 1X2 markets, and scored rows in the common panel.
result: pass
source: self-verified

### 22. Review fail-closed optional-family evidence
expected: In candidate_evidence.csv and the supporting manifests, xG, context, structural, enriched, and external paths are either scored from valid evidence or visibly marked inactive with an explicit reason; no inactive path contributes misleading score rows.
result: pass
reported: "The corrected outcome amendment separates the stale inactive-reason text from the accepted temporal eligibility result: the current snapshot contains all 72 panel codes, but its 2024-07-15 publication date follows the historical fold cutoffs."
source: self-verified

### 23. Review the durable bundle and shortlist boundary
expected: The run manifest and shortlist show the exact open/rich denominators, G=40 support, checksums, WC2026 sealing, research-only status, non-exclusive selection, and phase12_decision_authority=FALSE.
result: pass
source: self-verified

### 24. Review the OWID/Maddison structural mapping
expected: The committed 2000 OWID Maddison GDP-per-capita and OWID UN WPP population snapshots, explicit FIFA-code mapping, transformations, and continuous sparse-team shrinkage are substantively appropriate for the intended structural-prior rationale; all required panel teams have usable source rows or a clearly documented exclusion.
result: pending
source: human-needed

### 25. Review the Phase 11 regression state
expected: The focused Phase 11 suites pass, and the complete test suite has no unaccounted failures or stale candidate-registry expectations after the merged nine-candidate registry.
result: pass
source: automated

## Summary

total: 25
passed: 24
issues: 0
pending: 1
skipped: 0
blocked: 0

## Gaps

<!-- YAML format for plan-phase --gaps consumption -->
- gap_id: G-11-24
  truth: "The selected structural prior mapping is substantively appropriate for the intended HGR-inspired research rationale."
  status: human_needed
  reason: "Automated checks establish source identity, chronology, FIFA-code coverage, transformations, and shrinkage behavior, but cannot approve the literature/domain interpretation."
  severity: human
  test: 24
  missing:
    - "Developer review of the two selected 2000 indicators, explicit FIFA-code mapping, log/z transformation, and continuous sparse-team shrinkage rationale."
