library(testthat)

phase20_final_boundary_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/", mustWork = TRUE
)
if (!exists("phase20_fixture_graph_36x144", envir = .GlobalEnv, mode = "function")) {
  source(file.path(phase20_final_boundary_root, "tests/testthat/helper_uefa_champions_league.R"), local = .GlobalEnv)
}
for (relative in c(
  "R/competition/uefa_champions_league_rules.R",
  "R/competition/uefa_champions_league_state.R",
  "R/competition/uefa_champions_league_simulation.R",
  "R/competition/uefa_champions_league_outcomes.R"
)) {
  source(file.path(phase20_final_boundary_root, relative), local = .GlobalEnv)
}

phase20_final_boundary_fixture <- function() {
  graph <- phase20_fixture_graph_36x144()
  cutoff <- phase20_test_information_cutoff_utc
  state <- ucl_build_state(graph, state_cutoff_utc = cutoff)
  release <- phase20_approved_release_fixture(graph)
  ledger <- ucl_build_forecast_ledger(state, release = release, state_cutoff_utc = cutoff)
  ledger <- phase20_fixture_strict_ledger(ledger, graph = state$graph, cutoff = cutoff)
  simulation <- ucl_run_simulation(
    state, ledger = ledger, simulations = 1L, seed = 20260921L,
    information_cutoff_utc = cutoff
  )
  list(state = state, ledger = ledger, simulation = simulation, cutoff = cutoff)
}

test_that("production draw validation requires accepted source evidence and a trusted token", {
  rules <- .ucl_rule_contract()
  draw <- phase20_fixture_accepted_draw()
  unresolved <- ucl_validate_draw_artifact(
    draw, rules = rules, source_bundle_id = phase20_test_source_bundle_id,
    authority_mode = "production"
  )
  expect_identical(unresolved$status, "unresolved")
  expect_identical(unresolved$reason, "missing_edition_draw_procedure")

  accepted_rules <- rules
  draw_row <- which(as.character(accepted_rules$evidence$document_id) == "draw_procedure_2026_27")
  accepted_rules$evidence$accepted[[draw_row]] <- TRUE
  accepted_rules$evidence$complete[[draw_row]] <- TRUE
  forged <- ucl_validate_draw_artifact(
    draw, rules = accepted_rules, source_bundle_id = phase20_test_source_bundle_id,
    authority_mode = "production"
  )
  expect_identical(forged$status, "unresolved")
  expect_identical(forged$reason, "trusted_draw_authority_missing")

  trusted <- .ucl_resolve_trusted_draw_artifact(
    draw, rules = accepted_rules, source_bundle_id = phase20_test_source_bundle_id
  )
  expect_s3_class(trusted, "ucl_trusted_draw_artifact")
  expect_identical(
    ucl_validate_draw_artifact(
      trusted, rules = accepted_rules, source_bundle_id = phase20_test_source_bundle_id,
      authority_mode = "production"
    )$status,
    "accepted"
  )
})

test_that("candidate validation binds graph, simulation components, and unresolved probabilities", {
  fixture <- phase20_final_boundary_fixture()
  raw <- list(state = fixture$state, ledger = fixture$ledger, simulation = fixture$simulation)
  baseline <- ucl_validate_outcome_candidate(raw, information_cutoff_utc = fixture$cutoff)
  expect_true(isTRUE(baseline$valid))

  graph_tampered <- raw
  graph_tampered$state$graph$clubs$canonical_name[[1L]] <- "forged-club-name"
  graph_result <- ucl_validate_outcome_candidate(graph_tampered, information_cutoff_utc = fixture$cutoff)
  expect_false(isTRUE(graph_result$valid))
  expect_true(any(grepl("component_graph_hash_mismatch|simulation_graph_identity_mismatch", graph_result$failures)))

  component_tampered <- raw
  component_tampered$simulation$component_hashes$progression_sha256 <- "forged"
  component_result <- ucl_validate_outcome_candidate(component_tampered, information_cutoff_utc = fixture$cutoff)
  expect_false(isTRUE(component_result$valid))
  expect_true(any(grepl("progression_component_hash_mismatch", component_result$failures)))

  unresolved <- raw
  unresolved_row <- which(as.character(unresolved$simulation$progression_probabilities$status) != "resolved")[[1L]]
  unresolved$simulation$progression_probabilities$probability[[unresolved_row]] <- 0.5
  unresolved_result <- ucl_validate_outcome_candidate(unresolved, information_cutoff_utc = fixture$cutoff)
  expect_false(isTRUE(unresolved_result$valid))
  expect_true(any(grepl("unresolved_probability_must_be_na", unresolved_result$failures)))
})
