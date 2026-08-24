# Deferred Items

## Phase 14 regression

- **Discovered during:** Plan 16-00 plan-level regression verification.
- **Scope:** Out of scope for Plan 16-00; no Phase 16 production code is involved.
- **Issue:** `tests/testthat/test_phase14_state_bundle.R` test `state candidate keeps NL forecastable and EURO pre_draw structurally empty` cannot find `phase14_build_competition_state_candidate` in the current test environment.
- **Evidence:** The targeted test exited nonzero after reporting the missing function; the broad Phase 14 file was interrupted after a long dot-only run (`exit 130`) to avoid leaving a stalled process.
- **Next action:** Reconcile the Phase 14 test loader/entrypoint in its owning phase before relying on the broad regression as a green gate.
