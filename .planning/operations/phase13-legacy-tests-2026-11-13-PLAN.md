# Repair legacy Phase 13 regressions and isolated recovery

## Scope and baseline

The source-contract, publication-hash and publication-manifest suites fail
because their setup predates the current publisher contracts. Hash tests
reverse-convert the live normalized schedule using removed columns; CLI tests
request accepted publication without its required edition/identity registries.
Some assertions still expect the CLI's former Phase 13 output schema rather
than the current normalized Phase 14 handoff.

## Plan

The broader regression run also exposed a real isolation defect: source-registry
hash migration ignored the explicit accepted-output root during blocked recovery
and read canonical bytes from the checkout. Forward that root through migration
and cover it with decoy-checkout evidence, without changing validation rules.

1. Build complete synthetic test sandboxes from committed Phase 13 JSON fixtures
   and the real registry/capture APIs. Keep production source data out of setup.
2. Update the three affected suites to use those sandboxes and the CLI's current
   schemas. Resolve child Rscript from the running R installation.
3. Preserve negative assertions for forged hashes, unresolved identity, missing
   registry context, empty pre-draw data, no-write dry runs and durable rollback.
4. Run each affected suite alone and the Phase 13 group together. Investigate
   adjacent failures when they share the same stale fixture setup; do not relax
   production validators or run a production refresh for test-only changes.
5. Verify production data/pages/services are unchanged, then commit and push
   only the fixture repair, accepted-root forwarding fix, and verification notes.

Baseline log: `/private/tmp/xgelo-legacy-phase13-before.log`; structured results:
`/private/tmp/xgelo-legacy-phase13-before.rds`. Sixteen cases fail across the three
files before repairs (the baseline contains 18 failing/error expectations).

The adjacent baseline additionally found six failed cases in registry,
publication integration and blocked recovery. Its evidence is
`/private/tmp/xgelo-phase13-adjacent.log` and
`/private/tmp/xgelo-phase13-adjacent.rds`.

## Implementation

- Added one shared synthetic sandbox builder using the committed NL and EURO
  JSON captures and real capture, identity, edition and manifest APIs. The
  helper reads the approved model selector, but creates no model authority.
- Replaced live-data reverse conversions and live schedule copies in the
  publication/hash/manifest/refresh fixture setup. Frozen fixture clocks and
  per-sandbox cleanup keep repeated runs deterministic and contained.
- Updated CLI expectations to Phase 14 normalized schemas and resolved child
  Rscript from the active R installation. Missing edition authority still
  rejects accepted publication; exact raw candidate capture remains reviewable.
- Bound registry validation to the genuine active approved selector and compared
  live lifecycle state with the checked edition registry. Forgery, empty
  pre-draw, no-write dry-run and all 14 rollback-step assertions remain active.
- Fixed recovery/capture registry migration to honor the explicitly selected
  accepted root. The focused regression places different bytes under a decoy
  checkout and proves every canonical hash comes from the chosen accepted tree.
- Strengthened single-file snapshots so registry and refresh-marker byte checks
  inspect the files rather than an empty directory-only inventory.

## Verification

Individual fresh-process checks:

- Source contracts: 176 original assertions passed; the added missing-authority
  case separately passed all five assertions after matching the documented raw
  capture behavior.
- Hash and manifest suites passed with synthetic seeds.
- Registry: 28 cases, 162 assertions, zero failures/errors/warnings/skips.
- Publication integration: four cases, 175 assertions, including all 14 injected
  promotion failures, zero failures/errors/warnings/skips.
- Refresh failure/recovery: four cases, 42 assertions, zero failures/errors/
  warnings/skips, including the decoy-root regression and explicit recovery.

The combined fresh-process run passed all seven suites: **82 cases, 852
assertions, zero failures, errors, warnings or skips**.

| Suite | Cases | Assertions |
|---|---:|---:|
| competition_registry | 28 | 162 |
| publication_hashes | 6 | 107 |
| publication_integration | 4 | 175 |
| publication_manifests | 6 | 68 |
| publication_transaction | 4 | 117 |
| refresh_failure | 4 | 42 |
| source_contracts | 30 | 181 |
| **Total** | **82** | **852** |

Final evidence: `/private/tmp/xgelo-phase13-final.log`,
`/private/tmp/xgelo-phase13-final.rds`, and
`/private/tmp/xgelo-phase13-final-summary.csv`.

At 2026-11-13T11:18:15.264013+00:00, the complete 609-file managed dashboard,
competition-data, processed-data and release inventory matched its pre-test
snapshot. All 86 protected WC/global/release/LaunchAgent files also matched.
No additions, deletions or byte changes occurred in either checked inventory.
The managed inventory SHA-256 is
`963bf142eef2b829171e1115fe48930386257be0028a169fa9125f902cd436ae`.
Detailed comparison: `/private/tmp/xgelo-phase13-final-preservation.json`.

No production refresh, model fit,
simulation or dashboard publication is part of this repair.

Reproduce the combined check from the project root:

```sh
rtk proxy /opt/homebrew/opt/r/bin/Rscript --vanilla -e 'testthat::test_dir("tests/testthat", filter = "^phase13_", reporter = "summary")'
```

The final run uses R 4.6.2 with no PATH workaround, test skips, model fitting,
forecast simulation, production refresh or publication.
