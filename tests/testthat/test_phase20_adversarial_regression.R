library(testthat)

if (!exists("phase20_fixture_graph_36x144", envir = .GlobalEnv, mode = "function")) {
  source(file.path(
    normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
                 winslash = "/", mustWork = TRUE),
    "tests/testthat/helper_uefa_champions_league.R"
  ), local = .GlobalEnv)
}

test_that("the adversarial contract closes the exact EDGE-01 through EDGE-19 inventory", {
  inventory <- phase20_expected_edge_probe_inventory()

  expect_identical(nrow(inventory), 19L)
  expect_identical(inventory$edge_id, sprintf("EDGE-%02d", seq_len(19L)))
  expect_true(all(nzchar(inventory$test_symbol)))
  expect_true(all(nzchar(inventory$verifier_symbol)))
  expect_true(all(nzchar(inventory$required_entrypoint)))
  expect_true(all(vapply(
    inventory$test_symbol,
    exists,
    logical(1),
    envir = .GlobalEnv,
    mode = "function",
    inherits = TRUE
  )))
  expect_true(all(vapply(
    inventory$verifier_symbol,
    exists,
    logical(1),
    envir = .GlobalEnv,
    mode = "function",
    inherits = TRUE
  )))
  expect_false(any(grepl("\\*", inventory$required_entrypoint)))
})

test_that("the target graph and ten-file output registry are exact", {
  expect_identical(phase20_expected_target_names, c(
    "ucl20_accepted_source", "ucl20_rules_evidence", "ucl20_state",
    "ucl20_forecast_ledger", "ucl20_league_simulation",
    "ucl20_knockout_paths", "ucl20_stage_events",
    "ucl20_outcome_candidate", "ucl20_outcome_manifest",
    "ucl20_build_status"
  ))
  expect_identical(dim(phase20_expected_target_edges), c(15L, 2L))
  expect_true(all(nzchar(phase20_expected_target_edges)))
  expect_false(any(grepl("\\*", phase20_expected_target_edges)))

  expected_paths <- c(
    "competition_topology.csv", "league_schedule.csv",
    "tie_break_trace.csv", "projected_standings.csv",
    "projected_rankings.csv", "knockout_paths.csv",
    "progression_probabilities.csv", "fixture_forecast_ledger.csv",
    "simulation_metadata.csv", "outcomes_manifest.csv"
  )
  expect_identical(names(phase20_expected_output_schemas), sub(
    "\\.csv$", "", expected_paths
  ))
  expect_identical(length(phase20_expected_output_schemas), 10L)
  expect_true(all(vapply(
    phase20_expected_output_schemas, function(columns) {
      length(columns) > 0L && all(nzchar(columns)) &&
        !anyDuplicated(columns)
    },
    logical(1)
  )))
})

test_that("the public symbol and typed result registries remain closed", {
  expect_identical(length(phase20_expected_public_symbols), 19L)
  expect_identical(phase20_expected_result_statuses, c(
    "mechanics_complete", "production_human_needed", "production_blocked",
    "unresolved_draw_procedure", "unexpected_failure"
  ))
  expect_true(all(grepl("^(ucl_|ucl20_|phase20_)", phase20_expected_public_symbols)))
  expect_identical(anyDuplicated(phase20_expected_public_symbols), 0L)

  # This is the intentional RED boundary: the aggregate result contract is
  # not present until a later implementation wave.
  phase20_test_require_ucl_entrypoints(
    c("phase20_result_contract", "phase20_verify_contracts"),
    "public-symbol-and-result-contract"
  )
})

test_that("CLI and targets cannot bypass fixed-root or typed-result contracts", {
  expect_identical(
    phase20_test_fixed_root,
    "outputs/competition/ucl_2026_27/outcomes"
  )
  expect_false(any(grepl("\\*", phase20_expected_target_names)))
  expect_false(any(grepl("\\*", phase20_expected_output_schemas)))

  # The fixed CLI entrypoints are intentionally absent in Wave 0.
  phase20_test_require_ucl_entrypoints(
    c("ucl20_parse_args", "ucl20_build_outcomes"),
    "cli-target-wiring"
  )
})

test_that("critical and high Phase 20 threats map to test and verifier symbols", {
  critical_high <- c(
    "T20-00-01", "T20-00-02",
    "T20-01-01", "T20-01-02", "T20-01-03",
    "T20-02-01", "T20-02-02", "T20-02-03", "T20-02-04",
    "T20-03-01", "T20-03-02", "T20-03-03", "T20-03-04",
    "T20-04-01", "T20-04-02", "T20-04-03",
    "T20-05-01", "T20-05-02", "T20-05-03", "T20-05-04", "T20-05-05"
  )
  mapping <- phase20_expected_threat_mapping()

  expect_identical(nrow(mapping), length(critical_high))
  expect_setequal(mapping$threat_id, critical_high)
  expect_true(all(nzchar(mapping$test_symbol)))
  expect_true(all(nzchar(mapping$verifier_symbol)))
  expect_true(all(vapply(
    mapping$test_symbol,
    exists,
    logical(1),
    envir = .GlobalEnv,
    mode = "function",
    inherits = TRUE
  )))
  expect_true(all(vapply(
    mapping$verifier_symbol,
    exists,
    logical(1),
    envir = .GlobalEnv,
    mode = "function",
    inherits = TRUE
  )))
})

test_that("CR-01 through CR-05 probes and parent normalization are explicit", {
  probe_symbols <- c(
    "phase20_probe_cr01_forged_roster_rejected",
    "phase20_probe_cr02_rating_replay_tamper_rejected",
    "phase20_probe_cr03_forged_fold_rejected",
    "phase20_probe_cr04_forged_probability_calibrator_rejected",
    "phase20_probe_cr05_unbacked_installer_rejected"
  )
  expect_true(all(vapply(
    probe_symbols,
    exists,
    logical(1),
    envir = .GlobalEnv,
    mode = "function",
    inherits = TRUE
  )))

  cases <- phase20_expected_parent_reason_cases()
  expect_identical(nrow(cases), 13L)
  expect_identical(cases$original_parent_reason[2L], "no_accepted_club_history")
  expect_identical(cases$original_parent_reason[5L:9L], c(
    "phase19_cr01_roster_mismatch",
    "phase19_cr02_rating_replay_unverified",
    "phase19_cr03_fold_identity_unverified",
    "phase19_cr04_probability_lineage_unverified",
    "phase19_cr05_unbacked_installer"
  ))
  expect_true(all(cases$normalization_error[11:13]))
  expect_true(all(cases$production_blocked_reason[11:13] ==
                  "unrecognized_parent_reason"))

  phase20_test_require_ucl_entrypoints("phase20_result_contract", "CR-parent-gate")
})

test_that("fixture releases, draw states, and protected roots stay non-promotable", {
  graph <- phase20_fixture_graph_36x144()
  release <- phase20_approved_release_fixture(graph)

  expect_identical(release$authority_mode, "fixture")
  expect_false(isTRUE(release$production_eligible))
  expect_false(isTRUE(release$selector_authorized))
  expect_identical(release$root_scope, "process_temporary")
  expect_true(is.null(release$trusted_release_root))
  expect_true(all(release$forecast_rows$feature_cutoff_utc <
                  release$forecast_rows$kickoff_utc))

  draw_states <- phase20_fixture_draw_evidence_states()
  expect_identical(names(draw_states), c(
    "missing", "stale", "partial", "foreign", "contradictory"
  ))
  expect_true(all(vapply(draw_states, function(state) {
    identical(state$status, "unresolved") && nzchar(state$reason)
  }, logical(1))))

  phase20_test_protected_incumbent_bytes("protected-incumbent-regression")
})

test_that("20-05 RED: CLI rejects every caller-selected authority or output root", {
  phase20_test_require_ucl_entrypoints(
    c("ucl20_parse_args", "ucl20_build_outcomes"),
    "20-05 fixed-root adversarial boundary"
  )
  for (argument in c(
    "--fixture-root=/tmp/fixture", "--output-root=/tmp/output",
    "--selector-path=/tmp/selector", "--trusted-release-root=/tmp/release",
    "--national-root=/tmp/national", "--source-root=/tmp/source"
  )) {
    expect_error(ucl20_parse_args(argument), "does not accept|Unsupported|authority")
  }
  expect_error(ucl20_parse_args("--edition-id=foreign_edition"), "not supported|Unsupported")
  expect_error(ucl20_parse_args(c("--write", "--replay-check", "--edition-id=ucl_2026_27")), "combined|cannot")
})

test_that("20-05 RED: typed production and fixture result contracts preserve bytes", {
  phase20_test_require_ucl_entrypoints(
    c("ucl20_build_outcomes", "phase20_result_contract", "phase20_verify_contracts"),
    "20-05 typed result/protected incumbent boundary"
  )
  before <- phase20_test_protected_root_snapshot()
  production <- ucl20_build_outcomes(simulations = 1L, seed = 20260921L)
  expect_true(production$status %in% c(
    "production_human_needed", "production_blocked", "unresolved_draw_procedure"
  ))
  expect_true(isTRUE(phase20_verify_contracts(production)))
  expect_false(isTRUE(production$production_eligible))
  expect_false(isTRUE(production$selector_changed))
  expect_false(isTRUE(production$incumbent_changed))
  expect_identical(phase20_test_protected_root_snapshot(), before)

  graph <- phase20_fixture_graph_36x144()
  fixture <- ucl20_build_outcomes(
    graph = graph, release = phase20_approved_release_fixture(graph),
    simulations = 1L, seed = 20260921L, write = FALSE
  )
  expect_true(fixture$status %in% c("mechanics_complete", "unresolved_draw_procedure"))
  expect_false(isTRUE(fixture$production_eligible))
  expect_identical(phase20_test_protected_root_snapshot(), before)
})

test_that("20-05 RED: verifier script and exact target graph are executable boundaries", {
  verifier <- file.path(phase20_test_project_root, "scripts", "verify_phase20_contracts.R")
  if (!file.exists(verifier)) {
    stop(phase20_test_missing_entrypoint_condition(
      "scripts/verify_phase20_contracts.R", "20-05 executable aggregate verifier"
    ))
  }
  target_source <- paste(readLines(file.path(phase20_test_project_root, "_targets.R"), warn = FALSE), collapse = "\n")
  expected_edges <- apply(phase20_expected_target_edges, 1L, function(edge) {
    grepl(edge[[1L]], target_source, fixed = TRUE) && grepl(edge[[2L]], target_source, fixed = TRUE)
  })
  expect_true(all(expected_edges))
  expect_false(grepl("phase14_resolve_approved_release|resolve_phase12_approved_release", target_source))
})
