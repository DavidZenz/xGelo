# Deferred Phase 11 Issues

- **Out of scope / pre-existing:** `tests/testthat/test_hybrid_context_features.R` still asserts the pre-11-04 context-only candidate registry. The current merged registry also contains `phase11_rf_dynamic_elo_context_xg_gated_open` and `phase11_structural_sparse_prior_open`, so that suite reports two candidate-set failures. Plan 11-05 did not modify the context test or prior-wave model registry rows; a future phase should reconcile the expectation with the merged Phase 11 registry.
