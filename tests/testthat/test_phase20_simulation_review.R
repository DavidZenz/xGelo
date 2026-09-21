library(testthat)

phase20_sim_review_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/", mustWork = TRUE
)

if (!exists("phase20_fixture_graph_36x144", envir = .GlobalEnv, mode = "function")) {
  source(file.path(phase20_sim_review_root, "tests/testthat/helper_uefa_champions_league.R"), local = .GlobalEnv)
}
for (relative in c(
  "R/competition/uefa_champions_league_rules.R",
  "R/competition/uefa_champions_league_state.R",
  "R/competition/uefa_champions_league_simulation.R"
)) {
  source(file.path(phase20_sim_review_root, relative), local = .GlobalEnv)
}

phase20_sim_review_ledger <- function(graph, cutoff = "2026-09-01T00:00:00Z") {
  state <- ucl_build_state(graph, state_cutoff_utc = cutoff)
  release <- phase20_approved_release_fixture(graph)
  ledger <- ucl_build_forecast_ledger(state, release = release, state_cutoff_utc = cutoff)
  ledger$ledger$feature_cutoff_utc <- "2026-08-31T00:00:00Z"
  ledger$ledger$score_grid <- lapply(seq_len(nrow(ledger$ledger)), function(index) {
    data.frame(home_goals = c(0L, 1L), away_goals = c(0L, 0L), probability = c(0.4, 0.6), stringsAsFactors = FALSE)
  })
  ledger$ledger$row_sha256 <- vapply(seq_len(nrow(ledger$ledger)), function(index) {
    .ucl_sim_canonical_row_hash(ledger$ledger[index, , drop = FALSE], schema_tag = "ucl20-forecast-ledger-row-v1")
  }, character(1))
  ledger$table_sha256 <- .ucl_sim_canonical_table_hash(ledger$ledger, key = "fixture_id", schema_tag = "ucl20-forecast-ledger-v1")
  ledger$canonical_hash_version <- "phase18-canonical-v2"
  ledger$state_cutoff_utc <- cutoff
  ledger$graph_sha256 <- .ucl_sim_graph_content_hash(state$graph)
  ledger$model_release_id <- unique(as.character(ledger$ledger$model_release_id))[[1L]]
  ledger$model_sha256 <- unique(as.character(ledger$ledger$model_sha256))[[1L]]
  ledger$calibrator_sha256 <- unique(as.character(ledger$ledger$calibrator_sha256))[[1L]]
  ledger
}

phase20_sim_review_draw <- function(source_bundle_id = phase20_test_source_bundle_id) {
  rules <- .ucl_rule_contract()
  rankings <- phase20_fixture_resolved_rankings()
  playoff <- data.frame(
    path_id = sprintf("playoff-%02d", 1:8),
    stage_id = "knockout_play_off",
    seed_slot_id = sprintf("playoff-slot-%02d", 1:8),
    bracket_position = c(
      "playoff-family-09-10-v-23-24", "playoff-family-09-10-v-23-24",
      "playoff-family-11-12-v-21-22", "playoff-family-11-12-v-21-22",
      "playoff-family-13-14-v-19-20", "playoff-family-13-14-v-19-20",
      "playoff-family-15-16-v-17-18", "playoff-family-15-16-v-17-18"
    ),
    participant_a = rankings$club_id[c(9, 10, 11, 12, 13, 14, 15, 16)],
    participant_b = rankings$club_id[c(23, 24, 21, 22, 19, 20, 17, 18)],
    seed_rank = 9:16, opponent_rank = c(23L, 24L, 21L, 22L, 19L, 20L, 17L, 18L),
    leg_order = "seeded_return_leg",
    leg_1_venue_id = paste0("venue-", rankings$club_id[c(23, 24, 21, 22, 19, 20, 17, 18)], "-home"),
    leg_2_venue_id = paste0("venue-", rankings$club_id[c(9, 10, 11, 12, 13, 14, 15, 16)], "-home"),
    source_artifact_ids = "phase20-review-draw-source",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  r16 <- data.frame(
    path_id = sprintf("r16-%02d", 1:8), stage_id = "round_of_16",
    seed_slot_id = sprintf("r16-slot-%02d", 1:8),
    bracket_position = c("r16-bracket-a", "r16-bracket-b", "r16-bracket-c", "r16-bracket-d", "r16-bracket-e", "r16-bracket-f", "r16-bracket-g", "r16-bracket-h"),
    participant_a = rankings$club_id[1:8], participant_b = paste0("winner:", playoff$path_id),
    seed_rank = 1:8, opponent_rank = NA_integer_, leg_order = "seeded_return_leg",
    leg_1_venue_id = paste0("winner-", playoff$path_id, "-home"),
    leg_2_venue_id = paste0("venue-", rankings$club_id[1:8], "-home"),
    source_artifact_ids = "phase20-review-draw-source",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  pairings <- rbind(playoff, r16)
  artifact <- list(
    edition_id = rules$edition_id, source_bundle_id = source_bundle_id,
    accepted = TRUE, complete = TRUE, draw_artifact_id = "phase20-review-draw-v1",
    source_artifact_ids = "phase20-review-draw-source", rank_inputs = rankings[, c("club_id", "rank"), drop = FALSE], pairings = pairings
  )
  hashes <- .ucl_sim_draw_hashes(artifact, rules)
  artifact$rank_input_sha256 <- hashes$rank_input_sha256
  artifact$draw_artifact_sha256 <- hashes$draw_artifact_sha256
  artifact
}

test_that("CR-02 accepts only complete same-edition draw content and recomputed hashes", {
  draw <- phase20_sim_review_draw()
  expect_identical(ucl_validate_draw_artifact(draw, source_bundle_id = phase20_test_source_bundle_id)$status, "accepted")

  partial <- draw
  partial$pairings <- partial$pairings[1, , drop = FALSE]
  expect_identical(ucl_validate_draw_artifact(partial, source_bundle_id = phase20_test_source_bundle_id)$status, "unresolved")

  forged <- draw
  forged$draw_artifact_sha256 <- paste(rep("a", 64), collapse = "")
  expect_identical(ucl_validate_draw_artifact(forged, source_bundle_id = phase20_test_source_bundle_id)$reason, "draw_hash_mismatch")

  missing_club <- draw
  missing_club$rank_inputs <- missing_club$rank_inputs[-1, , drop = FALSE]
  expect_identical(ucl_validate_draw_artifact(missing_club, source_bundle_id = phase20_test_source_bundle_id)$reason, "partial_draw_artifact")

  duplicate_rank <- draw
  duplicate_rank$rank_inputs$rank[[2L]] <- duplicate_rank$rank_inputs$rank[[1L]]
  expect_identical(ucl_validate_draw_artifact(duplicate_rank, source_bundle_id = phase20_test_source_bundle_id)$reason, "partial_draw_artifact")
  wrong_slot <- draw
  wrong_slot$pairings$path_id[[1L]] <- "playoff-99"
  expect_identical(ucl_validate_draw_artifact(wrong_slot, source_bundle_id = phase20_test_source_bundle_id)$reason, "partial_draw_artifact")
  foreign_source <- draw
  foreign_source$pairings$source_artifact_ids[[1L]] <- "foreign-draw-source"
  expect_identical(ucl_validate_draw_artifact(foreign_source, source_bundle_id = phase20_test_source_bundle_id)$reason, "foreign_lineage")
})

test_that("CR-02 compares the complete ranking set before consuming an accepted draw", {
  draw <- phase20_sim_review_draw()
  rankings <- phase20_fixture_resolved_rankings()
  missing <- rankings[-1, , drop = FALSE]
  expect_identical(ucl_enumerate_legal_knockout_paths(missing, draw_artifact = draw, source_bundle_id = phase20_test_source_bundle_id)$unresolved_reason, "draw_rank_input_missing")
  foreign <- rankings
  foreign$club_id[[1L]] <- "foreign-club"
  expect_identical(ucl_enumerate_legal_knockout_paths(foreign, draw_artifact = draw, source_bundle_id = phase20_test_source_bundle_id)$unresolved_reason, "draw_rank_input_mismatch")
})

test_that("CR-05 enforces a strict information cutoff at equality and sentinel values", {
  graph <- phase20_fixture_graph_36x144()
  ledger <- phase20_fixture_conditional_ledger(graph, score_grid_ids = graph$fixtures$fixture_id)
  cutoff <- "2026-09-16T19:00:00Z"
  prepared <- .ucl_prepare_iteration_matches(graph$fixtures, cutoff_utc = cutoff)
  sampled <- .ucl_sample_open_fixtures(prepared, ledger = ledger, seed = 20260921L, cutoff_utc = cutoff)
  equality <- sampled$records[sampled$records$fixture_id == "ucl20-fixture-0002", , drop = FALSE]
  expect_identical(equality$suppression_reason, "information_cutoff_violation")
  expect_false("ucl20-fixture-0002" %in% sampled$sampled_fixture_ids)

  sentinel <- .ucl_prepare_iteration_matches(graph$fixtures, cutoff_utc = "2099-12-31T23:59:59Z")
  sentinel_result <- .ucl_sample_open_fixtures(sentinel, ledger = ledger, seed = 20260921L, cutoff_utc = "2099-12-31T23:59:59Z")
  expect_length(sentinel_result$sampled_fixture_ids, 0L)
  expect_true(all(sentinel_result$records$suppression_reason == "information_cutoff_sentinel"))
})

test_that("CR-06 uses framed hashes and binds settled state, ledger, and draw semantics", {
  expect_false(identical(.ucl_sim_hash(c("x|y", "z")), .ucl_sim_hash(c("x", "y|z"))))
  graph <- phase20_fixture_graph_36x144()
  ledger <- phase20_sim_review_ledger(graph)
  state <- ucl_build_state(graph, state_cutoff_utc = "2026-09-01T00:00:00Z")
  expect_identical(ucl_run_simulation(state, ledger = ledger, simulations = 1L, seed = 7L)$reason, "information_cutoff_missing")
  first <- ucl_run_simulation(state, ledger = ledger, simulations = 1L, seed = 7L, information_cutoff_utc = "2026-09-01T00:00:00Z")
  changed_graph <- phase20_test_completed_fixture_graph(graph, index = 1L, home_goals = 4L, away_goals = 0L)
  changed_state <- ucl_build_state(changed_graph, state_cutoff_utc = "2026-09-01T00:00:00Z")
  second <- ucl_run_simulation(changed_state, ledger = ledger, simulations = 1L, seed = 7L, information_cutoff_utc = "2026-09-01T00:00:00Z")
  expect_false(identical(first$run_id, second$run_id))
  expect_identical(first$metadata$graph_sha256, .ucl_sim_graph_content_hash(first$graph))
  expect_identical(first$metadata$state_sha256, first$state_sha256)
})

test_that("CR-07 rejects foreign or unvalidated ledgers before sampling", {
  graph <- phase20_fixture_graph_36x144()
  ledger <- phase20_sim_review_ledger(graph)
  foreign <- ledger
  foreign$ledger$source_bundle_id[[1L]] <- "foreign-source-bundle"
  foreign$ledger$row_sha256[[1L]] <- .ucl_sim_canonical_row_hash(foreign$ledger[1, , drop = FALSE], schema_tag = "ucl20-forecast-ledger-row-v1")
  state <- ucl_build_state(graph, state_cutoff_utc = "2026-09-01T00:00:00Z")
  result <- ucl_run_simulation(state, ledger = foreign, simulations = 1L, seed = 1L, information_cutoff_utc = "2026-09-01T00:00:00Z")
  expect_identical(result$status, "blocked")
  expect_identical(result$reason, "ledger_lineage_mismatch")
  forged_table_hash <- ledger
  forged_table_hash$table_sha256 <- paste(rep("b", 64), collapse = "")
  expect_identical(ucl_run_simulation(state, ledger = forged_table_hash, simulations = 1L, seed = 1L, information_cutoff_utc = "2026-09-01T00:00:00Z")$reason, "ledger_table_hash_mismatch")
  missing_metadata <- ledger
  missing_metadata$model_sha256 <- NULL
  expect_identical(ucl_run_simulation(state, ledger = missing_metadata, simulations = 1L, seed = 1L, information_cutoff_utc = "2026-09-01T00:00:00Z")$reason, "ledger_metadata_incomplete")
  expect_identical(ucl_run_simulation(state, ledger = ledger$ledger, simulations = 1L, seed = 1L, information_cutoff_utc = "2026-09-01T00:00:00Z")$reason, "ledger_contract_invalid")
})

test_that("CR-08 requires the authoritative 36-club rank permutation", {
  clubs <- phase20_test_fixture_club_ids()
  rows <- do.call(rbind, lapply(1:2, function(iteration) data.frame(
    run_id = "review-run", iteration = iteration, edition_id = phase20_test_edition_id,
    club_id = clubs, rank = 1:36, rank_interval_min = 1:36, rank_interval_max = 1:36,
    rank_status = "resolved", qualification_band = c(rep("direct_round_of_16", 8), rep("knockout_play_off", 16), rep("eliminated", 12)),
    stringsAsFactors = FALSE
  )))
  good <- ucl_aggregate_rank_distributions(list(rank_rows = rows, club_ids = clubs, run_id = "review-run"))
  expect_identical(good$status, "ready")
  missing <- rows[!(rows$iteration == 2L & rows$club_id == clubs[[36L]]), , drop = FALSE]
  expect_identical(ucl_aggregate_rank_distributions(list(rank_rows = missing, club_ids = clubs))$status, "unresolved")
  duplicate <- rows
  duplicate$rank[duplicate$iteration == 1L & duplicate$club_id == clubs[[36L]]] <- 35L
  expect_identical(ucl_aggregate_rank_distributions(list(rank_rows = duplicate, club_ids = clubs))$status, "unresolved")
  expect_identical(ucl_aggregate_rank_distributions(list(rank_rows = rows))$reason, "authoritative_club_ids_missing")
})

test_that("CR-09 generates complete typed stage events and progression through champion", {
  graph <- phase20_fixture_graph_36x144()
  ledger <- phase20_sim_review_ledger(graph)
  state <- ucl_build_state(graph, state_cutoff_utc = "2026-09-01T00:00:00Z")
  draw <- phase20_sim_review_draw(source_bundle_id = graph$source_bundle_id)
  result <- ucl_run_simulation(state, ledger = ledger, simulations = 1L, seed = 11L,
                               draw_artifact = draw, information_cutoff_utc = "2026-09-01T00:00:00Z")
  expect_true(all(c("knockout_play_off", "round_of_16", "quarter_final", "semi_final", "final", "champion") %in% unique(result$stage_events$stage_id)))
  expect_identical(nrow(result$stage_events), sum(.ucl_sim_stage_inventory()))
  expect_true(all(c("knockout_play_off", "round_of_16", "quarter_final", "semi_final", "final", "champion") %in% unique(result$progression_probabilities$stage_id)))
  expect_true(isTRUE(attr(result$stage_reconciliation, "valid")))
  expect_true(isTRUE(result$progression_reconciliation$valid))

  missing_status <- result$stage_events[, setdiff(names(result$stage_events), c("status", "path_status")), drop = FALSE]
  expect_false(isTRUE(attr(ucl_aggregate_stage_events(missing_status), "valid")))
  one_row <- result$progression_probabilities[1, c("club_id", "stage_id", "probability"), drop = FALSE]
  expect_false(isTRUE(ucl_validate_progression_reconciliation(one_row)$valid))
})
