# Phase 18 Deferred Items

- `.planning/WINDOWS.md` has inconsistent frontmatter counts versus its entries (`23/0/5/28` declared, `22/0/6/28` observed). The best-effort deviation append for Plan 18-02 was rejected without modifying the ledger. Repair belongs to GSD planning-ledger maintenance, not the club identity implementation.
- `tests/testthat/test_phase18_refresh_failure.R` has 10+ pre-existing fixture errors after Plan 18-10 because `phase18_ucl_hash()` now correctly accepts raw bytes only while the older refresh fixtures still pass character strings. Canonical, identity, adapter, bundle, and Plan 18-12 history suites pass; refresh-fixture migration belongs to Plan 18-13's final adversarial regression sweep.
