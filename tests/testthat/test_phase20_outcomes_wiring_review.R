library(testthat)

phase20_outcomes_review_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/", mustWork = TRUE
)
if (!exists("phase20_fixture_graph_36x144", envir = .GlobalEnv, mode = "function")) {
  source(file.path(phase20_outcomes_review_root, "tests/testthat/helper_uefa_champions_league.R"), local = .GlobalEnv)
}
for (relative in c(
  "R/competition/uefa_champions_league_rules.R",
  "R/competition/uefa_champions_league_state.R",
  "R/competition/uefa_champions_league_simulation.R",
  "R/competition/uefa_champions_league_outcomes.R"
)) {
  source(file.path(phase20_outcomes_review_root, relative), local = .GlobalEnv)
}

test_that("Phase 20 parser binds a real cutoff and rejects unsafe mode/seed inputs", {
  expect_error(ucl20_parse_args(c("--write", "--dry-run")), "cannot be combined")
  expect_error(ucl20_parse_args("--seed=-1"), "non-negative|outside")
  expect_error(ucl20_parse_args("--information-cutoff-utc=2099-12-31T23:59:59Z"), "sentinel")
  parsed <- ucl20_parse_args(c(
    "--simulations=1", "--seed=0",
    "--information-cutoff-utc=2026-09-21T00:00:00Z"
  ))
  expect_identical(parsed$information_cutoff_utc, phase20_test_information_cutoff_utc)
})

test_that("Phase 20 result contracts preserve real artifact hashes and fail closed", {
  unexpected <- phase20_result_contract(status = "unexpected_failure")
  expect_true(unexpected$exit_code > 0L)
  expect_true(length(unexpected$unexpected_failures) > 0L)
  forged_unexpected <- unexpected
  forged_unexpected$exit_code <- 0L
  forged_unexpected$unexpected_failures <- character()
  expect_false(phase20_verify_contracts(forged_unexpected))
  unsafe <- phase20_result_contract(
    status = "mechanics_complete", production_eligible = TRUE,
    selector_changed = TRUE, incumbent_changed = TRUE
  )
  expect_false(unsafe$production_eligible)
  expect_false(unsafe$selector_changed)
  expect_false(unsafe$incumbent_changed)
})

test_that("fixture outcome builder executes the strict artifact boundary", {
  graph <- phase20_fixture_graph_36x144()
  release <- phase20_approved_release_fixture(graph)
  release$forecast_rows$score_grid <- lapply(
    as.character(release$forecast_rows$fixture_id), phase20_fixture_score_grid
  )
  result <- ucl20_build_outcomes(
    graph = graph, release = release, simulations = 1L, seed = 20260921L,
    information_cutoff_utc = phase20_test_information_cutoff_utc, write = FALSE
  )
  expect_identical(result$status, "unresolved_draw_procedure")
  expect_true(isTRUE(phase20_verify_contracts(result)))
  expect_length(result$artifact_hashes, 10L)
  expect_true(all(grepl("^[0-9a-f]{64}$", result$artifact_hashes)))
  actual <- vapply(result$artifacts, .ucl_out_artifact_hash, character(1))
  expect_identical(unname(result$artifact_hashes), unname(actual))
  expect_identical(
    as.character(result$artifacts$outcomes_manifest$artifact_sha256[seq_len(9L)]),
    as.character(result$artifact_hashes[seq_len(9L)])
  )
})

test_that("caller artifacts and incomplete stage events cannot replace computed outcomes", {
  graph <- phase20_fixture_graph_36x144()
  rules <- .ucl_rule_contract()
  release <- phase20_approved_release_fixture(graph)
  release$forecast_rows$score_grid <- lapply(
    as.character(release$forecast_rows$fixture_id), phase20_fixture_score_grid
  )
  state <- ucl_build_state(graph, rules = rules, state_cutoff_utc = phase20_test_information_cutoff_utc)
  ledger <- ucl_build_forecast_ledger(state, release = release, state_cutoff_utc = phase20_test_information_cutoff_utc)
  ledger <- .ucl_out_prepare_simulation_ledger(ledger, state$graph, release, phase20_test_information_cutoff_utc)
  simulation <- ucl_run_simulation(
    state, ledger = ledger, rules = rules, simulations = 1L, seed = 20260921L,
    information_cutoff_utc = phase20_test_information_cutoff_utc
  )
  baseline <- ucl_validate_outcome_candidate(
    list(state = state, ledger = ledger, simulation = simulation),
    rules = rules, information_cutoff_utc = phase20_test_information_cutoff_utc
  )
  forged <- baseline$artifacts
  forged$projected_rankings$club_id[[1L]] <- paste0(forged$projected_rankings$club_id[[1L]], "-forged")
  rejected <- ucl_validate_outcome_candidate(
    list(state = state, ledger = ledger, simulation = simulation, artifacts = forged),
    rules = rules, information_cutoff_utc = phase20_test_information_cutoff_utc
  )
  expect_false(rejected$valid)
  expect_true(any(grepl("artifact_mismatch:projected_rankings", rejected$failures, fixed = TRUE)))
  incomplete <- simulation
  incomplete$stage_events <- incomplete$stage_events[-1L, , drop = FALSE]
  incomplete_result <- ucl_validate_outcome_candidate(
    list(state = state, ledger = ledger, simulation = incomplete),
    rules = rules, information_cutoff_utc = phase20_test_information_cutoff_utc
  )
  expect_false(incomplete_result$valid)
  expect_true(any(grepl("stage_inventory_incomplete|stage_events_missing", incomplete_result$failures)))
})

test_that("production entry point rejects caller graph injection and remains non-promotable", {
  graph <- phase20_fixture_graph_36x144()
  graph$authority_mode <- "production"
  blocked <- ucl20_build_outcomes(
    graph = graph, release = phase20_approved_release_fixture(phase20_fixture_graph_36x144()),
    information_cutoff_utc = phase20_test_information_cutoff_utc
  )
  expect_identical(blocked$status, "production_blocked")
  expect_identical(blocked$production_blocked_reason, "graph_injection_requires_fixture_authority")
  expect_false(blocked$production_eligible)
  expect_identical(blocked$information_cutoff_utc, phase20_test_information_cutoff_utc)
})
