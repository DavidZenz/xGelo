# Active dashboard improvements

Approved 2026-10-26. Scope: Nations League and EURO qualifying only; World Cup and Phase 21 migration excluded.

## Accepted choices
- All five improvements delivered in independently reversible stages.
- Public tournament forecasts require 100,000 simulations, seed 15017, four workers by default.
- Selected team is highlighted across tabs and filters Fixtures/Results; comparison tables remain visible.
- No payload schema or model/rule changes. Preserve provenance, routes, hashes, size limits and atomic batch rollback.

## Execution
1. Establish baseline inventory and tests; harden nightly release checks, exclusive locking, real browser validation and nonzero test execution.
2. Correct filter visibility/counts, upcoming-versus-results, date/time labels and explicit-only qualification status.
3. Render EURO pre-draw waiting state; clarify legal-draw versus modal tree paths; shared team selection and group navigation with keyboard access.
4. Benchmark 1k/10k/100k; enable the public 100k policy only after full-scale validation. Preserve iteration seeds and numerical semantics if memory improvements are needed.

## Release acceptance
Run Phase 17, Nations League revision, Phase 21 compatibility and relevant outcome/publication suites. Test active/blocked/unavailable/pre-draw/activated-EURO fixtures, duplicate controls, hidden states, search/clear/tab/hash behavior, explicit confirmation versus sampled extremes, payload preservation, candidate failure rollback and byte limits. Verify actual 1440x900 and 390x844 browser viewports and keyboard interaction. Stage both active routes; never hand-edit published HTML or bypass gates. Preserve the World Cup directory hash and unrelated working changes.

## Status
- [x] Release safeguards (implemented and tested; real browser acceptance remains blocked)
- [x] Filter/status correctness
- [x] Waiting state, tree and navigation
- [ ] Full-scale acceptance: 1k benchmark and gated 100k policy implemented; 10k/100k not run
- [x] R regression suites and staged envelope/payload checks
- [ ] Formal desktop/mobile browser acceptance and live promotion

Implementation log and evidence: SUMMARY.md in this directory.
