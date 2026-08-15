---
status: complete
phase: 13-source-contracts-and-competition-registry
source: 13-01-SUMMARY.md, 13-02-SUMMARY.md, 13-03-SUMMARY.md, 13-04-SUMMARY.md, 13-05-SUMMARY.md, 13-06-SUMMARY.md, 13-07-SUMMARY.md, 13-08-SUMMARY.md, 13-09-SUMMARY.md, 13-10-SUMMARY.md, 13-11-SUMMARY.md, 13-12-SUMMARY.md
started: 2026-08-15T13:39:27Z
updated: 2026-08-15T13:42:22Z
---

## Current Test

[testing complete]

## Tests

### 1. Accepted edition-scoped source bundle
expected: A compact structured UEFA resource set becomes an accepted edition-scoped source bundle with artifact provenance and stable hashes.
result: pass
source: automated
coverage_id: D1

### 2. Stable team identity resolution
expected: Fixture rows resolve to stable xGelo team IDs while preserving UEFA display names and recording fallback warnings.
result: pass
source: automated
coverage_id: D2

### 3. Competition edition invariants
expected: Competition editions retain lifecycle, blocked-overlay, source-bundle, model-release, and output-slot invariants.
result: pass
source: automated
coverage_id: D3

### 4. Required structured resources and provenance
expected: All five required structured resource classes, schema drift checks, stable row hashes, and manifest self-hashes validate.
result: pass
source: automated
coverage_id: D1

### 5. Bounded fixture and live acquisition
expected: Bounded acquisition replays compact fixtures or captures explicit HTTPS resources and publishes compact accepted snapshots and registries for both editions.
result: pass
source: automated
coverage_id: D2

### 6. Reviewed fallback acceptance
expected: A reviewed fallback bundle is accepted only when complete, edition-wide, and provenance-consistent, while a blocked candidate retains the prior accepted bundle.
result: pass
source: automated
coverage_id: D3

### 7. Source boundary protection
expected: Rendered HTML and PDF masquerades are rejected, and exact local raw bytes remain outside Git tracking.
result: pass
source: automated
coverage_id: D4

### 8. Durable identity normalization
expected: Stable team identity normalization preserves source and display values, aliases, provenance, warning metadata, and hashes while rejecting ambiguous or duplicate mappings.
result: pass
source: automated
coverage_id: D1

### 9. Two-edition registry validation
expected: Both UEFA competition editions validate with lifecycle, blocked retention, source-bundle linkage, trusted Phase 12 release pins, explicit output targets, and truthful EURO pre-draw state.
result: pass
source: automated
coverage_id: D2

### 10. Normalized fixture publication
expected: Accepted fixture rows retain UEFA source IDs, display names, edition, mapping metadata, and row hashes through durable identity normalization.
result: pass
source: automated
coverage_id: D1

### 11. Normalized result contract
expected: Accepted result rows use the exact fixture source key, preserve source status and scores, carry both artifact links, and emit the normalized result contract.
result: pass
source: automated
coverage_id: D2

### 12. Truthful EURO pre-draw results
expected: EURO pre-draw accepted fixtures and results remain schema-complete and empty, with no fabricated competition rows.
result: pass
source: automated
coverage_id: D3

### 13. Fail-closed result validation
expected: Duplicate, unknown, invalid, or mismatched result inputs fail closed, while later-row append, reorder, and score-only changes preserve baseline identity and edition assignments.
result: pass
source: automated
coverage_id: D4

### 14. Production edition loading
expected: Production edition loading validates both accepted edition directories, their five resource tables, manifests, registries, hashes, and normalized result lineage.
result: pass
source: automated
coverage_id: D1

### 15. Default team identity loading
expected: Default team identity loading validates adjacent source-bundle provenance, and EURO remains an explicit schema-valid empty pre-draw snapshot.
result: pass
source: automated
coverage_id: D2

### 16. Loader tamper detection
expected: Missing directories, recomputed-row tampering, stale canonical hashes, forged manifest links, and forged identity foreign keys fail closed.
result: pass
source: automated
coverage_id: D3

### 17. Bounded structured capture and status provenance
expected: Bounded HTTPS structured capture assembles five resource classes and supports explicit or derived status provenance.
result: pass
source: automated
coverage_id: D1

### 18. Raw-byte and registry lineage
expected: Exact local raw bytes and compact source registries retain URL lineage, raw and canonical hashes, parser identity, and stable row hashes.
result: pass
source: automated
coverage_id: D2

### 19. Fallback provenance isolation
expected: Reviewed fallback provenance remains complete and edition-wide without mixing official and fallback artifacts.
result: pass
source: automated
coverage_id: D3

### 20. Historical source-match identity
expected: Preprocessing retains and validates stable non-score source-match IDs, including explicit reviewed IDs for the duplicate historical projection.
result: pass
source: automated
coverage_id: D1

### 21. Complete historical identity map
expected: Complete martj42 history has a one-to-one identity map, edition lookup, and normalized artifact with stable IDs, provenance, and row hashes.
result: pass
source: automated
coverage_id: D2

### 22. Targets graph history output
expected: The targets graph exposes normalized history as a file target downstream of elo_matches and the production loader.
result: pass
source: automated
coverage_id: D3

### 23. Complete staged publication
expected: Generic accepted-directory publication stages and validates one complete manifest plus fixtures, groups, standings, results, and status before promotion.
result: pass
source: automated
coverage_id: D1

### 24. Nations League source-shaped handoff
expected: The Nations League handoff carries edition IDs, source artifact lineage, row hashes, canonical content hashes, and explicit status provenance without tracked raw bodies.
result: pass
source: automated
coverage_id: D2

### 25. Refresh record stability
expected: Registry-side blocked refresh records, the blocked_refresh_batch_id pointer, and status history remain byte-stable while the accepted edition is replaced.
result: pass
source: automated
coverage_id: D3

### 26. EURO accepted output contract
expected: EURO 2028 qualifying accepted output contains the manifest and five schema-complete source-shaped tables with compact provenance and parser-aligned hashes.
result: pass
source: automated
coverage_id: D1

### 27. Truthful EURO pre-draw state
expected: EURO fixtures, groups, standings, and results remain empty in pre_draw while status is explicit pre_draw and source-artifact linked.
result: pass
source: automated
coverage_id: D2

### 28. Raw response exclusion
expected: No raw response bodies are tracked in Git, and local raw retention remains ignored.
result: pass
source: automated
coverage_id: D3

### 29. Deterministic canonical resource hashes
expected: Ten normalized accepted resource tables receive deterministic row hashes and complete CSV-content hashes, with matching source-artifact canonical projections.
result: pass
source: automated
coverage_id: D1

### 30. Accepted manifest hash graph
expected: Both five-artifact accepted manifests and source-bundle derived hashes are regenerated deterministically, including manifest self-hashes.
result: pass
source: automated
coverage_id: D2

### 31. Fail-closed publication hash validation
expected: Stale, forged, duplicate, cross-edition, incomplete, and mixed-fallback graphs fail closed while EURO pre_draw empties and provenance remain truthful.
result: pass
source: automated
coverage_id: D3

### 32. Locked normalized publication
expected: The fourteen-target normalized publication is locked, validated, and rolled back byte-for-byte on failure.
result: pass
source: automated
coverage_id: D1

### 33. Stable dual-edition normalization
expected: Both source-shaped editions normalize to stable identity-bearing fixtures and results while EURO remains truthful pre_draw.
result: pass
source: automated
coverage_id: D2

### 34. Confirm failed refresh blocking and lineage
expected: Replay an invalid replacement for one edition. The refresh should reject it, leave the prior accepted output intact, and create one blocked status record linked to the same refresh batch as the edition row and status history.
result: pass

### 35. Confirm accepted output preservation
expected: After a failed refresh publication, accepted output and immutable source registries should remain byte- and hash-stable, including exact rollback of sidecar writes.
result: pass

### 36. Confirm reviewed fallback provenance
expected: A reviewed fallback should remain edition-wide, approved, and fully represented in source provenance without mixing official and fallback artifacts.
result: pass

## Coverage Notes

- `13-06-SUMMARY.md` contains three human-judgment entries whose metadata uses unsupported `human-check` verification kinds/statuses and omits the required rationale field. Those entries are retained as manual UAT checks 34-36 rather than treated as automated passes.

## Summary

total: 36
passed: 36
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

[none yet]
