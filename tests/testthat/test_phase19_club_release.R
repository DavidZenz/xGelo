library(testthat)

phase19_release_test_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/", mustWork = TRUE
)

phase19_release_test_source <- function(relative_path, required = TRUE) {
  path <- file.path(phase19_release_test_root, relative_path)
  if (!file.exists(path)) {
    if (isTRUE(required)) stop("RED: missing Phase 19 release dependency: ", relative_path, call. = FALSE)
    return(invisible(FALSE))
  }
  source(path, local = .GlobalEnv)
  invisible(TRUE)
}

phase19_release_test_load <- function(require_release = TRUE) {
  phase19_release_test_source("R/common/phase18_canonical_hash.R")
  phase19_release_test_source("R/club/history_contract.R")
  phase19_release_test_source("R/club/model_contract.R")
  phase19_release_test_source("R/evaluation/proper_scores.R")
  phase19_release_test_source("R/evaluation/benchmark_scores.R")
  phase19_release_test_source("R/club/evaluation_protocol.R")
  phase19_release_test_source("R/club/rating.R")
  phase19_release_test_source("R/club/goal_model.R")
  phase19_release_test_source("R/club/calibration.R")
  phase19_release_test_source("R/club/evaluation.R")
  phase19_release_test_source("R/release/domain_contract.R", required = require_release)
  phase19_release_test_source("R/release/release_contract.R", required = require_release)
  phase19_release_test_source("R/club/release.R", required = require_release)
  phase19_release_test_source("tests/testthat/helper_phase19_club_fixture.R")
  phase19_test_load()
  invisible(TRUE)
}

phase19_release_test_require <- function(names) {
  missing <- names[!vapply(names, exists, logical(1), mode = "function")]
  if (length(missing)) stop("RED: missing Phase 19 release API: ", paste(missing, collapse = ", "), call. = FALSE)
  invisible(TRUE)
}

phase19_release_test_minimal_decision <- function() {
  structure(list(
    schema_version = "phase19-club-promotion-decision-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    forecast_domain = "club", authority_mode = "fixture", fixture_authority = TRUE,
    candidate_id = "club_elo_nb", incumbent_id = "club_venue_nb",
    selected_model_id = "club_elo_nb", diagnostic_gate_outcome = "pass",
    authority_eligibility = "fixture_ineligible", promotion_status = "ineligible_fixture",
    reason_codes = "", authority_reason_code = "fixture_ineligible",
    evaluation_set_sha256 = strrep("a", 64L),
    reproducibility_evidence_sha256 = strrep("b", 64L),
    authority_sha256 = strrep("c", 64L), protocol_sha256 = strrep("d", 64L),
    policy_review_sha256 = strrep("e", 64L), gate_registry_sha256 = strrep("f", 64L),
    seed_registry_sha256 = strrep("1", 64L), metrics_sha256 = strrep("2", 64L),
    integrity_sha256 = strrep("3", 64L), gate_results_sha256 = strrep("4", 64L),
    gate_results = data.frame(gate_order = integer(), gate_id = character(),
                              stringsAsFactors = FALSE), decision_sha256 = strrep("5", 64L)
  ), class = c("phase19_club_promotion_decision", "list"))
}

phase19_release_test_model <- function() {
  structure(list(
    schema_version = "phase19-club-goal-fit-v1", forecast_domain = "club",
    authority_mode = "fixture", fixture_authority = TRUE, promotion_eligible = FALSE,
    model_id = "club_elo_nb", model_family = "negative_binomial",
    fit_status = "converged", fallback_status = "none", fit_sha256 = strrep("6", 64L),
    training_snapshot_sha256 = strrep("7", 64L), current_snapshot_sha256 = strrep("8", 64L),
    protocol_sha256 = strrep("d", 64L), cutoff_utc = "2025-01-01T00:00:00Z",
    support_max = 40L, active_features = c("elo_difference_for_team", "venue_role")
  ), class = c("phase19_club_goal_fit", "list"))
}

phase19_release_test_calibrator <- function() {
  structure(list(
    schema_version = "phase19-club-calibrator-v1", forecast_domain = "club",
    authority_mode = "fixture", fixture_authority = TRUE, promotion_eligible = FALSE,
    model_id = "club_elo_nb", candidate_id = "club_elo_nb", calibrator_id = "fixture-calibrator",
    fit_status = "fitted", distribution_unchanged = TRUE, calibrator_sha256 = strrep("9", 64L),
    protocol_sha256 = strrep("d", 64L), calibration_data_cutoff = "2025-01-01T00:00:00Z"
  ), class = c("phase19_club_calibrator", "list"))
}

phase19_release_test_fold <- function(protocol, family, ordinal) {
  ids <- sprintf("release_%02d_%s", ordinal, c("a", "b", "c"))
  heldout <- if (identical(family, "heldout_league_transport")) "league-z" else ""
  row <- data.frame(
    schema_version = "phase19-club-fold-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    forecast_domain = "club", authority_mode = "fixture", fixture_authority = TRUE,
    fold_id = sprintf("club__%s__league-z__2025-%02d", family, ordinal),
    fold_family = family, assessment_competition_id = "league-z",
    assessment_season_id = sprintf("2025-%02d", ordinal),
    assessment_start_utc = "2025-04-01T00:00:00Z",
    assessment_end_utc = "2025-04-30T23:59:59Z",
    training_cutoff_exclusive = "2025-02-01T00:00:00Z",
    calibration_cutoff_exclusive = "2025-04-01T00:00:00Z",
    declared_fixture_ids = paste(ids, collapse = "|"),
    declared_fixture_count = 3L,
    declared_fixture_sha256 = phase19_fold_id_sha256(ids, "declared"),
    training_fixture_ids = "fit_a|fit_b", training_fixture_count = 2L,
    training_fixture_sha256 = phase19_fold_id_sha256(c("fit_a", "fit_b"), "training"),
    calibration_fixture_ids = "cal_a|cal_b", calibration_fixture_count = 2L,
    calibration_fixture_sha256 = phase19_fold_id_sha256(c("cal_a", "cal_b"), "calibration"),
    held_out_competition_id = heldout, fit_excluded_competition_id = heldout,
    tuning_excluded_competition_id = heldout, calibration_excluded_competition_id = heldout,
    eligibility_status = "eligible", support_reason_code = "",
    accepted_generation_id = "phase19-release-fixture",
    corpus_manifest_sha256 = strrep("a", 64L), snapshot_sha256 = strrep("b", 64L),
    protocol_sha256 = protocol$protocol_sha256,
    policy_review_sha256 = protocol$policy_review$review_sha256,
    calibration_recipe_sha256 = phase19_expected_calibration_recipe()$recipe_sha256,
    row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  row$row_sha256 <- phase19_fold_row_sha256(row)
  row
}

phase19_release_test_grid <- function(fixture_id, model_id, home_mean, away_mean) {
  goals <- 0:40
  probability <- as.vector(outer(dpois(goals, home_mean), dpois(goals, away_mean)))
  probability <- probability / sum(probability)
  grid <- expand.grid(home_goals = goals, away_goals = goals,
                      KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  data.frame(
    fixture_id = fixture_id,
    score_distribution_id = paste0(fixture_id, "__", model_id, "__score"),
    model_id = model_id, home_goals = grid$home_goals, away_goals = grid$away_goals,
    probability = probability, support_max_home = 40L, support_max_away = 40L,
    raw_tail_mass = 0, normalized = TRUE,
    tail_policy = "truncate_0_40_then_joint_renormalize_once",
    fit_sha256 = digest::digest(paste0("fit-", model_id), algo = "sha256", serialize = FALSE),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase19_release_test_predictions <- function(fold, model_id, strong = FALSE) {
  ids <- strsplit(fold$declared_fixture_ids, "|", fixed = TRUE)[[1L]]
  means <- if (isTRUE(strong)) {
    rep(list(c(1.15, 1.15)), length(ids))
  } else {
    rep(list(c(3, 0.1)), length(ids))
  }
  grids <- lapply(seq_along(ids), function(index) {
    phase19_release_test_grid(ids[[index]], model_id, means[[index]][[1L]], means[[index]][[2L]])
  })
  distributions <- do.call(rbind, grids)
  rows <- lapply(seq_along(ids), function(index) {
    grid <- grids[[index]]
    market <- phase19_club_goal_grid_markets(grid)
    data.frame(
      fixture_id = ids[[index]], forecast_domain = "club", authority_mode = "fixture",
      fixture_authority = TRUE, promotion_eligible = FALSE, promotion_comparable = TRUE,
      model_id = model_id, model_family = "negative_binomial",
      output_capability = "complete_score_distribution_and_derived_markets",
      goal_distribution_declared = TRUE, prediction_status = "ready_goal_distribution",
      boundary_id = paste0("boundary-", ids[[index]]),
      evidence_cutoff_exclusive = fold$calibration_cutoff_exclusive,
      home_club_id = c("club_alpha", "club_gamma", "club_alpha")[[index]],
      away_club_id = c("club_beta", "club_delta", "club_gamma")[[index]],
      score_distribution_id = unique(grid$score_distribution_id),
      p_home = market$p_home, p_draw = market$p_draw, p_away = market$p_away,
      p_over_2_5 = market$p_over_2_5, p_btts = market$p_btts,
      expected_home_goals = market$expected_home_goals,
      expected_away_goals = market$expected_away_goals,
      likely_home_goals = market$likely_home_goals,
      likely_away_goals = market$likely_away_goals, raw_tail_mass = 0, support_max = 40L,
      fit_sha256 = unique(grid$fit_sha256), rating_evidence_sha256 = strrep("c", 64L),
      training_snapshot_sha256 = fold$snapshot_sha256,
      current_snapshot_sha256 = strrep("d", 64L), protocol_sha256 = fold$protocol_sha256,
      fallback_status = "none", distribution_sha256 = phase18_hash_table_v2(
        grid, key = c("fixture_id", "home_goals", "away_goals"),
        schema_tag = "phase19-club-goal-distribution-v1"
      ), prediction_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
    )
  })
  predictions <- do.call(rbind, rows)
  predictions$prediction_sha256 <- phase19_club_goal_prediction_row_hash(predictions)
  structure(list(
    schema_version = "phase19-club-goal-prediction-set-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(), forecast_domain = "club",
    authority_mode = "fixture", fixture_authority = TRUE, promotion_eligible = FALSE,
    promotion_comparable = TRUE, model_id = model_id,
    output_capability = "complete_score_distribution_and_derived_markets",
    goal_distribution_declared = TRUE, declared_fixture_ids = ids,
    fit_sha256 = unique(predictions$fit_sha256), predictions = predictions,
    distributions = distributions,
    prediction_table_sha256 = phase18_hash_table_v2(
      predictions, key = "fixture_id", schema_tag = "phase19-club-goal-predictions-v1"
    ), distribution_table_sha256 = phase18_hash_table_v2(
      distributions, key = c("fixture_id", "home_goals", "away_goals"),
      schema_tag = "phase19-club-goal-distributions-v1"
    )
  ), class = c("phase19_club_goal_predictions", "list"))
}

phase19_release_test_outcomes <- function(fold) {
  ids <- strsplit(fold$declared_fixture_ids, "|", fixed = TRUE)[[1L]]
  data.frame(
    fixture_id = ids, forecast_domain = "club",
    competition_id = fold$assessment_competition_id, season_id = fold$assessment_season_id,
    kickoff_utc = c("2025-04-10T18:00:00Z", "2025-04-20T18:00:00Z", "2025-04-25T18:00:00Z"),
    completion_not_before_utc = c("2025-04-10T20:00:00Z", "2025-04-20T20:00:00Z", "2025-04-25T20:00:00Z"),
    evidence_available_at_utc = c("2025-04-10T20:05:00Z", "2025-04-20T20:05:00Z", "2025-04-25T20:05:00Z"),
    home_club_id = c("club_alpha", "club_gamma", "club_alpha"),
    away_club_id = c("club_beta", "club_delta", "club_gamma"),
    regulation_home_goals = c(2L, 0L, 1L), regulation_away_goals = c(0L, 2L, 1L),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase19_release_test_support <- function() {
  data.frame(
    model_id = c("club_venue_nb", "club_elo_nb"), fit_status = "converged",
    fallback_status = "none",
    fit_sha256 = vapply(c("club_venue_nb", "club_elo_nb"), function(id)
      digest::digest(paste0("fit-", id), algo = "sha256", serialize = FALSE), character(1)),
    calibrator_status = "fitted", primary_probability_view = "raw_1x2",
    calibrator_sha256 = vapply(c("club_venue_nb", "club_elo_nb"), function(id)
      digest::digest(paste0("calibrator-", id), algo = "sha256", serialize = FALSE), character(1)),
    calibration_evidence_sha256 = vapply(c("club_venue_nb", "club_elo_nb"), function(id)
      digest::digest(paste0("cal-evidence-", id), algo = "sha256", serialize = FALSE), character(1)),
    calibration_decision_sha256 = vapply(c("club_venue_nb", "club_elo_nb"), function(id)
      digest::digest(paste0("cal-decision-", id), algo = "sha256", serialize = FALSE), character(1)),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase19_release_test_provenance <- function(fold) {
  data.frame(
    role = c("fit", "tuning", "calibration"),
    cutoff_exclusive = c(fold$training_cutoff_exclusive, fold$training_cutoff_exclusive,
                         fold$calibration_cutoff_exclusive),
    excluded_competition_id = rep(fold$held_out_competition_id, 3L),
    declared_fixture_sha256 = c(fold$training_fixture_sha256, fold$training_fixture_sha256,
                                fold$calibration_fixture_sha256),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase19_release_test_evaluations <- function(protocol) {
  families <- rep(c("rolling_origin_league_season", "heldout_league_transport"), each = 3L)
  base <- NULL
  lapply(seq_along(families), function(index) {
    fold <- phase19_release_test_fold(protocol, families[[index]], index)
    if (is.null(base)) {
      candidate <- phase19_release_test_predictions(fold, "club_elo_nb", TRUE)
      incumbent <- phase19_release_test_predictions(fold, "club_venue_nb", FALSE)
      base <<- phase19_score_club_fold(
        candidate, incumbent, phase19_release_test_outcomes(fold), fold, protocol,
        phase19_release_test_support(), phase19_release_test_provenance(fold)
      )
      return(base)
    }
    clone <- base
    clone$fold_id <- fold$fold_id; clone$fold_family <- fold$fold_family
    clone$assessment_competition_id <- fold$assessment_competition_id
    clone$assessment_season_id <- fold$assessment_season_id
    clone$fold_row_sha256 <- fold$row_sha256
    clone$fixture_scores$fold_id <- fold$fold_id
    clone$fixture_scores$fold_family <- fold$fold_family
    clone$fixture_scores$competition_id <- fold$assessment_competition_id
    clone$fixture_scores$season_id <- fold$assessment_season_id
    clone$fold_summary$fold_id <- fold$fold_id
    clone$fold_summary$fold_family <- fold$fold_family
    clone$fold_summary$competition_id <- fold$assessment_competition_id
    clone$fold_summary$season_id <- fold$assessment_season_id
    clone$fixture_scores_sha256 <- phase18_hash_table_v2(
      clone$fixture_scores, key = c("model_id", "fixture_id", "metric"),
      schema_tag = "phase19-club-evaluation-fixture-scores-v1"
    )
    clone$fold_summary_sha256 <- phase18_hash_table_v2(
      clone$fold_summary, key = "fold_id",
      schema_tag = "phase19-club-evaluation-fold-summary-v1"
    )
    clone$evaluation_sha256 <- phase19_club_fold_evaluation_sha256(clone)
    clone
  })
}

phase19_release_test_calibration_fold <- function(protocol) {
  ids <- sprintf("release_cal_%03d", seq_len(60L))
  row <- data.frame(
    schema_version = "phase19-club-fold-v1", hash_encoding_version = phase18_canonical_encoding_v2(),
    forecast_domain = "club", authority_mode = "fixture", fixture_authority = TRUE,
    fold_id = "club__heldout_league_transport__league-z__2025-26",
    fold_family = "heldout_league_transport", assessment_competition_id = "league-z",
    assessment_season_id = "2025-26", assessment_start_utc = "2025-03-01T00:00:00Z",
    assessment_end_utc = "2025-05-31T00:00:00Z", training_cutoff_exclusive = "2025-01-01T00:00:00Z",
    calibration_cutoff_exclusive = "2025-03-01T00:00:00Z", declared_fixture_ids = "assessment_a|assessment_b",
    declared_fixture_count = 2L, declared_fixture_sha256 = phase19_fold_id_sha256(c("assessment_a", "assessment_b"), "declared"),
    training_fixture_ids = "fit_a|fit_b", training_fixture_count = 2L,
    training_fixture_sha256 = phase19_fold_id_sha256(c("fit_a", "fit_b"), "training"),
    calibration_fixture_ids = paste(sort(ids), collapse = "|"), calibration_fixture_count = 60L,
    calibration_fixture_sha256 = phase19_fold_id_sha256(sort(ids), "calibration"),
    held_out_competition_id = "league-z", fit_excluded_competition_id = "league-z",
    tuning_excluded_competition_id = "league-z", calibration_excluded_competition_id = "league-z",
    eligibility_status = "eligible", support_reason_code = "", accepted_generation_id = "phase19-release-fixture",
    corpus_manifest_sha256 = strrep("a", 64L), snapshot_sha256 = strrep("b", 64L),
    protocol_sha256 = protocol$protocol_sha256, policy_review_sha256 = protocol$policy_review$review_sha256,
    calibration_recipe_sha256 = phase19_expected_calibration_recipe()$recipe_sha256,
    row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  row$row_sha256 <- phase19_fold_row_sha256(row)
  row
}

phase19_release_test_calibration_rows <- function(fold) {
  ids <- strsplit(fold$calibration_fixture_ids, "|", fixed = TRUE)[[1L]]
  observed <- rep(c("home", "draw", "away"), length.out = length(ids))
  probability <- rbind(home = c(.58, .24, .18), draw = c(.37, .39, .24), away = c(.25, .25, .50))[observed, , drop = FALSE]
  rows <- data.frame(
    fixture_id = ids, candidate_id = "club_elo_nb", outer_fold_id = fold$fold_id,
    inner_fold_id = rep(c("inner_01", "inner_02", "inner_03"), length.out = length(ids)),
    evidence_role = "inner_out_of_fold", competition_id = "league-a", event_date = "2025-02-01",
    kickoff_utc = "2025-02-01T18:00:00Z", kickoff_precision = "instant",
    completion_not_before_utc = "2025-02-01T20:00:00Z", evidence_available_at_utc = "2025-02-01T20:00:00Z",
    counts_for_model = TRUE, p_home_raw = probability[, 1L], p_draw_raw = probability[, 2L],
    p_away_raw = probability[, 3L], observed_class = observed,
    source_grid_sha256 = vapply(ids, function(id) digest::digest(paste0("grid-", id), algo = "sha256", serialize = FALSE), character(1)),
    source_prediction_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  rows$source_prediction_sha256 <- phase19_club_calibration_source_row_sha256(rows)
  rows
}

phase19_release_test_bundle <- local({
  value <- NULL
  function() {
    if (is.null(value)) {
      phase19_release_test_load()
      root <- phase19_test_fixture_root("release")
      training <- phase19_load_fixture_club_training_snapshot(root)
      current <- phase19_load_fixture_current_ucl_club_snapshot(root)
      club_ids <- c("club_alpha", "club_beta", "club_gamma", "club_delta")
      current$clubs <- current$clubs[seq_along(club_ids), , drop = FALSE]
      current$clubs$provider_club_id <- as.character(9000L + seq_along(club_ids))
      current$clubs$club_id <- club_ids
      current$clubs$display_name <- paste("Release", club_ids)
      current$clubs$canonical_name <- current$clubs$display_name
      current$clubs$row_sha256 <- ""
      current$clubs$row_sha256 <- phase18_ucl_projected_row_hash(current$clubs)
      current$clubs <- current$clubs[order(current$clubs$club_id, method = "radix"), , drop = FALSE]
      rownames(current$clubs) <- NULL
      current$club_count <- as.integer(nrow(current$clubs))
      current$roster_sha256 <- phase18_hash_table_v2(
        current$clubs, key = "club_id", schema_tag = "phase19-current-ucl-club-roster-v1"
      )
      current$snapshot_sha256 <- phase19_current_snapshot_sha256(current)
      phase19_validate_current_ucl_club_snapshot(current, "fixture")
      protocol <- phase19_load_fixture_club_evaluation_protocol()
      parameters <- phase19_club_rating_parameters(base_rating = 1500, home_advantage = 60,
                                                    k_factor = 20, inactivity_factor = .995)
      rating <- phase19_replay_club_ratings(training, current, parameters,
                                            cutoff_utc = training$cutoff_utc)
      registration <- protocol$candidate_registry[protocol$candidate_registry$model_id == "club_elo_nb", , drop = FALSE]
      model <- phase19_fit_club_goal_model(registration, training, rating, protocol,
                                            cutoff_utc = "2025-06-01T18:00:00Z")
      calibration_fold <- phase19_release_test_calibration_fold(protocol)
      candidate <- protocol$candidate_registry[protocol$candidate_registry$model_id == "club_elo_nb", , drop = FALSE]
      calibrator <- phase19_fit_club_calibrator(
        phase19_release_test_calibration_rows(calibration_fold), calibration_fold,
        candidate, protocol
      )
      evaluations <- phase19_release_test_evaluations(protocol)
      aggregate <- phase19_aggregate_club_evaluations(evaluations, protocol)
      replay <- phase19_club_reproducibility_evidence(evaluations, rev(evaluations), protocol)
      authority <- phase19_fixture_evaluation_authority(aggregate, protocol)
      integrity <- phase19_derive_club_integrity_evidence(aggregate, protocol, replay, authority)
      decision <- phase19_evaluate_club_promotion(aggregate, protocol, replay, integrity, authority)
      value <<- list(root = root, training = training, current = current, protocol = protocol,
                     model = model, calibrator = calibrator, evaluations = evaluations,
                     aggregate = aggregate, replay = replay, authority = authority,
                     integrity = integrity, decision = decision)
    }
    value
  }
})

phase19_release_test_stage <- function(label = "fixture") {
  root <- tempfile(paste0("phase19-release-", label, "-"))
  dir.create(root, recursive = TRUE)
  bundle <- phase19_release_test_bundle()
  staged <- phase19_stage_fixture_club_release(
    decision = bundle$decision, model = bundle$model, calibrator = bundle$calibrator,
    output_root = root, release_id = paste0("fixture-", label),
    history_snapshot = bundle$training, current_snapshot = bundle$current,
    protocol = bundle$protocol, evaluation = bundle$aggregate, authority = bundle$authority,
    replay = bundle$replay, integrity = bundle$integrity
  )
  list(root = root, staged = staged)
}

test_that("fixture club release APIs are present and the shared guard is strict", {
  phase19_release_test_load(require_release = TRUE)
  phase19_release_test_require(c(
    "assert_forecast_domain", "phase19_club_release_required_artifacts",
    "stage_phase19_fixture_release", "validate_phase19_club_release",
    "install_phase19_club_release", "read_phase19_club_selector",
    "resolve_phase19_club_release"
  ))
  expect_silent(assert_forecast_domain(list(forecast_domain = "club"), "club"))
  expect_error(assert_forecast_domain(list(forecast_domain = "national_team"), "club"),
               class = "phase19_domain_error")
})

test_that("fixture publication rejects untyped parents, missing authority, and custom gates", {
  phase19_release_test_load(require_release = TRUE)
  bundle <- phase19_release_test_bundle()
  output <- tempfile("phase19-release-typed-")
  dir.create(output, recursive = TRUE)
  expect_error(
    phase19_stage_fixture_club_release(
      decision = bundle$decision, model = phase19_release_test_model(),
      calibrator = bundle$calibrator, output_root = output,
      history_snapshot = bundle$training, current_snapshot = bundle$current,
      protocol = bundle$protocol, evaluation = bundle$aggregate,
      authority = bundle$authority
    ), class = "phase19_club_release_error"
  )
  expect_error(
    phase19_stage_fixture_club_release(
      decision = bundle$decision, model = bundle$model, calibrator = bundle$calibrator,
      output_root = output, history_snapshot = bundle$training,
      current_snapshot = bundle$current, protocol = bundle$protocol,
      evaluation = bundle$aggregate
    ), class = "phase19_club_release_error"
  )
  staged <- phase19_stage_fixture_club_release(
    decision = bundle$decision, model = bundle$model, calibrator = bundle$calibrator,
    output_root = output, release_id = "typed-parents", history_snapshot = bundle$training,
    current_snapshot = bundle$current, protocol = bundle$protocol,
    evaluation = bundle$aggregate, authority = bundle$authority,
    replay = bundle$replay, integrity = bundle$integrity
  )
  card_path <- file.path(staged$release_root, "reports/model_card.md")
  card_before <- readLines(card_path, warn = FALSE)
  card_tampered <- sub(
    "^- authority_mode: fixture$", "- authority_mode: production",
    card_before
  )
  writeLines(card_tampered, card_path, useBytes = TRUE)
  expect_error(
    phase19_club_release_validate_model_card(card_path, staged$model_contract),
    class = "phase19_club_release_error"
  )
  writeLines(card_before, card_path, useBytes = TRUE)
  tampered <- bundle$decision
  tampered$metrics_sha256 <- strrep("0", 64L)
  tampered$decision_sha256 <- phase19_club_promotion_decision_sha256(tampered)
  expect_error(
    phase19_stage_fixture_club_release(
      decision = tampered, model = bundle$model, calibrator = bundle$calibrator,
      output_root = output, release_id = "tampered-decision",
      history_snapshot = bundle$training, current_snapshot = bundle$current,
      protocol = bundle$protocol, evaluation = bundle$aggregate,
      authority = bundle$authority, replay = bundle$replay,
      integrity = bundle$integrity
    ), class = "phase19_club_release_error"
  )
  expect_error(
    phase19_install_club_release(
      staged$release_root, file.path(output, "approved"),
      validator = function(...) stop("must never be called")
    ), class = "phase19_club_release_error"
  )
})

test_that("fixture release round trip validates before and after object load", {
  phase19_release_test_load(require_release = TRUE)
  phase19_release_test_require(c(
    "phase19_stage_fixture_club_release", "phase19_validate_club_release",
    "phase19_install_club_release", "phase19_read_club_selector",
    "phase19_resolve_club_release"
  ))
  fixture <- phase19_release_test_stage("round-trip")
  root <- fixture$root
  staged <- fixture$staged
  expect_true(dir.exists(staged$release_root))
  expect_silent(phase19_validate_club_release(staged$release_root, load_models = FALSE,
                                              expected_domain = "club"))
  installed <- phase19_install_club_release(staged$release_root,
                                            file.path(root, "approved"))
  selector <- phase19_read_club_selector(installed$selector_path,
                                         file.path(root, "approved"))
  expect_identical(selector$forecast_domain, "club")
  resolved <- phase19_resolve_club_release(file.path(root, "approved"))
  expect_identical(resolved$model$model_id, "club_elo_nb")
  expect_identical(resolved$calibrator$candidate_id, "club_elo_nb")
})

test_that("fixture authority cannot be staged through the production writer", {
  phase19_release_test_load(require_release = TRUE)
  phase19_release_test_require("phase19_stage_production_club_release")
  expect_error(
    phase19_stage_production_club_release(
      decision = phase19_release_test_minimal_decision(),
      model = phase19_release_test_model(), calibrator = phase19_release_test_calibrator(),
      output_root = tempfile("phase19-production-release-")
    ),
    class = "phase19_club_release_error"
  )
})

test_that("fixture release rejects traversal, surplus, missing, symlink, and hash attacks", {
  phase19_release_test_load(require_release = TRUE)
  fixture <- phase19_release_test_stage("attacks")
  extra <- file.path(fixture$staged$release_root, "extra.txt")
  writeLines("extra", extra)
  expect_error(phase19_validate_club_release(fixture$staged$release_root, FALSE),
               class = "phase19_club_release_error")

  fixture <- phase19_release_test_stage("missing")
  unlink(file.path(fixture$staged$release_root, "limitations.md"))
  expect_error(phase19_validate_club_release(fixture$staged$release_root, FALSE),
               class = "phase19_club_release_error")

  fixture <- phase19_release_test_stage("hash")
  writeLines(c("tampered"), file.path(fixture$staged$release_root, "reports/model_card.md"))
  expect_error(phase19_validate_club_release(fixture$staged$release_root, FALSE),
               class = "phase19_club_release_error")

  fixture <- phase19_release_test_stage("traversal")
  manifest <- utils::read.csv(file.path(fixture$staged$release_root, "release_manifest.csv"),
                              stringsAsFactors = FALSE, check.names = FALSE,
                              colClasses = "character", na.strings = character())
  manifest$relative_path[manifest$artifact == "limitations.md"] <- "../limitations.md"
  utils::write.csv(manifest, file.path(fixture$staged$release_root, "release_manifest.csv"),
                   row.names = FALSE, na = "", quote = TRUE)
  expect_error(phase19_validate_club_release(fixture$staged$release_root, FALSE),
               class = "phase19_club_release_error")

  fixture <- phase19_release_test_stage("symlink")
  link <- file.path(fixture$staged$release_root, "reports/link.md")
  expect_true(file.symlink("model_card.md", link))
  expect_error(phase19_validate_club_release(fixture$staged$release_root, FALSE),
               class = "phase19_club_release_error")
})

test_that("preflight is metadata-first and object/selector identities are checked", {
  phase19_release_test_load(require_release = TRUE)
  fixture <- phase19_release_test_stage("identity")
  expect_silent(phase19_validate_club_release(fixture$staged$release_root, FALSE))
  installed <- phase19_install_club_release(fixture$staged$release_root,
                                            file.path(fixture$root, "approved"))
  before <- readBin(installed$selector_path, "raw", file.info(installed$selector_path)$size)
  selector <- utils::read.csv(installed$selector_path, stringsAsFactors = FALSE,
                              check.names = FALSE, colClasses = "character",
                              na.strings = character())
  selector$release_id <- "fixture-other"
  utils::write.csv(selector, installed$selector_path, row.names = FALSE, na = "", quote = TRUE)
  expect_error(phase19_read_club_selector(installed$selector_path,
                                           file.path(fixture$root, "approved")),
               class = "phase19_club_release_error")
  writeBin(before, installed$selector_path)
  expect_silent(phase19_read_club_selector(installed$selector_path,
                                           file.path(fixture$root, "approved")))

  # A corrupt RDS is rejected by the metadata/hash preflight without a readRDS call.
  writeBin(charToRaw("not-an-rds"), file.path(installed$release_root, "model/approved_model.rds"))
  expect_error(phase19_validate_club_release(installed$release_root, FALSE),
               class = "phase19_club_release_error")
})

test_that("lock and validation failures preserve the prior selector and bytes", {
  phase19_release_test_load(require_release = TRUE)
  fixture <- phase19_release_test_stage("rollback")
  installed <- phase19_install_club_release(fixture$staged$release_root,
                                            file.path(fixture$root, "approved"))
  selector_before <- readBin(installed$selector_path, "raw", file.info(installed$selector_path)$size)
  second <- phase19_release_test_stage("rollback-second")
  lock <- file.path(fixture$root, "approved", ".approved_release.lock")
  file.create(lock)
  expect_error(phase19_install_club_release(second$staged$release_root,
                                             file.path(fixture$root, "approved")),
               class = "phase19_club_release_error")
  unlink(lock)
  expect_identical(readBin(installed$selector_path, "raw", file.info(installed$selector_path)$size), selector_before)

  third <- phase19_release_test_stage("rollback-third")
  calls <- 0L
  failing_validator <- function(root, load_models = TRUE, expected_domain = "club") {
    calls <<- calls + 1L
    if (isTRUE(load_models)) stop("injected load failure", call. = FALSE)
    phase19_validate_club_release(root, load_models = load_models, expected_domain = expected_domain)
  }
  expect_error(phase19_install_club_release(third$staged$release_root,
                                             file.path(fixture$root, "approved"),
                                             validator = failing_validator),
               class = "phase19_club_release_error")
  expect_identical(calls, 0L)
  expect_identical(readBin(installed$selector_path, "raw", file.info(installed$selector_path)$size), selector_before)
})

test_that("national boundaries project national_team and reject club authority", {
  phase19_release_test_load(require_release = TRUE)
  phase19_release_test_source("R/release/release_bundle.R")
  phase19_release_test_source("R/release/release_install.R")
  phase19_release_test_source("R/release/release_contract.R")
  phase19_release_test_source("R/competition/forecast_layer.R")
  phase19_release_test_require(c(
    "phase12_release_assert_expected_domain", "phase12_release_project_domain",
    "phase14_forecast_assert_expected_domain"
  ))
  expect_identical(
    phase12_release_project_domain(list(release_id = "national"))$forecast_domain,
    "national_team"
  )
  expect_silent(phase12_release_assert_expected_domain(list(forecast_domain = "national_team")))
  expect_error(
    phase12_release_assert_expected_domain(list(forecast_domain = "club")),
    class = "phase19_domain_error"
  )
  expect_silent(phase14_forecast_assert_expected_domain(list(forecast_domain = "national_team")))
  expect_error(
    phase14_forecast_assert_expected_domain(list(forecast_domain = "club")),
    class = "phase19_domain_error"
  )
})

test_that("club production publication stays blocked before root creation", {
  phase19_release_test_load(require_release = TRUE)
  production <- phase19_release_test_minimal_decision()
  production$authority_mode <- "production"
  production$fixture_authority <- FALSE
  production$authority_eligibility <- "production"
  production$promotion_status <- "promoted"
  production$decision_sha256 <- paste0(substr(production$decision_sha256, 1L, 63L), "6")
  output_root <- file.path(tempdir(), paste0("phase19-production-blocked-", Sys.getpid()))
  if (dir.exists(output_root)) unlink(output_root, recursive = TRUE)
  expect_error(
    phase19_stage_production_club_release(
      decision = production, model = phase19_release_test_model(),
      calibrator = phase19_release_test_calibrator(), output_root = output_root
    ),
    class = "phase19_club_release_error"
  )
  expect_false(dir.exists(output_root))
  expect_identical(
    phase19_club_production_block_reason("blocked", "blocked", "blocked", "blocked"),
    "no_accepted_club_history"
  )
})
