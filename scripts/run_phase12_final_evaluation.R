#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
setwd(project_root)
.libPaths(c(file.path(project_root, "data/cache/phase11-library"), .libPaths()))

source("R/benchmark/hybrid_runner.R", local = .GlobalEnv)
source("R/benchmark/hybrid_adapters.R", local = .GlobalEnv)
source("R/benchmark/hybrid_protocol.R", local = .GlobalEnv)
source("R/benchmark/baselines.R", local = .GlobalEnv)
source("R/calibration/probability_calibration.R", local = .GlobalEnv)
source("R/release/final_evaluation.R", local = .GlobalEnv)
source("R/release/promotion_report.R", local = .GlobalEnv)

phase12_final_cutoff <- as.Date("2026-06-11")
phase12_active_id <- "phase11_rf_dynamic_elo_open"
phase12_run_id <- "phase12-final-evaluation-pretournament"
phase12_output_dir <- "outputs/benchmarks/rolling_tournaments/phase12-calibration-release"
phase12_label_sha256 <- "7dd366f457460c435ca3b8bdf9a456cc85903ee639d31f29bbd9c62ff604e1dc"

phase12_real_label_provider <- function(path) {
  list(
    data = utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE),
    source_sha256 = digest::digest(path, algo = "sha256", file = TRUE)
  )
}

phase12_team_id <- function(name) {
  value <- iconv(as.character(name), from = "", to = "ASCII//TRANSLIT")
  value <- tolower(gsub("[^a-z0-9]+", "_", value))
  value <- gsub("^_+|_+$", "", value)
  paste0("team_", value)
}

phase12_target_fixtures <- function(cutoff) {
  group <- utils::read.csv(
    "data/raw/worldcup_2026_group_fixtures.csv",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  group <- group[, c("match_id", "date", "home_team", "away_team", "host_country"), drop = FALSE]
  names(group)[names(group) == "match_id"] <- "fixture_id"
  group$edition_id <- "wc2026"
  group$boundary_id <- "wc2026__pretournament"
  group$actual_completion_date <- as.Date(group$date)
  group$venue_role <- ifelse(
    group$home_team == group$host_country, "home",
    ifelse(group$away_team == group$host_country, "away", "neutral")
  )

  bracket <- utils::read.csv(
    "outputs/dashboard/worldcup_bracket_paths.csv",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  bracket <- bracket[grepl("^M[0-9]+$", as.character(bracket$match_id)), , drop = FALSE]
  bracket <- bracket[, c("match_id", "actual_match_date", "slot1_team", "slot2_team"), drop = FALSE]
  names(bracket) <- c("fixture_id", "actual_completion_date", "home_team", "away_team")
  bracket$edition_id <- "wc2026"
  bracket$boundary_id <- "wc2026__pretournament"
  bracket$actual_completion_date <- as.Date(bracket$actual_completion_date)
  bracket$venue_role <- "neutral"

  result <- rbind(
    group[, c("fixture_id", "edition_id", "boundary_id", "home_team", "away_team", "venue_role", "actual_completion_date"), drop = FALSE],
    bracket[, c("fixture_id", "edition_id", "boundary_id", "home_team", "away_team", "venue_role", "actual_completion_date"), drop = FALSE]
  )
  if (nrow(result) != 104L || anyDuplicated(result$fixture_id) || anyNA(result$actual_completion_date)) {
    stop("Phase 12 target fixture registry is not the expected 104-match identity set", call. = FALSE)
  }
  result$home_team_id <- phase12_team_id(result$home_team)
  result$away_team_id <- phase12_team_id(result$away_team)
  result$track_id <- "updating"
  result$forecast_sequence <- seq_len(nrow(result))
  result$evidence_cutoff_exclusive <- as.Date(cutoff)
  result$result_cutoff_exclusive <- as.Date(cutoff)
  result$score_eligible <- TRUE
  result
}

phase12_training_history <- function(cutoff) {
  history <- utils::read.csv(
    "data/processed/goal_training_features_hybrid.csv",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  history$date <- as.Date(history$date)
  history <- history[!is.na(history$date) & history$date < as.Date(cutoff), , drop = FALSE]
  if (!nrow(history) || anyNA(history$home_goals) || anyNA(history$away_goals)) {
    stop("Phase 12 training history is incomplete before the exclusive cutoff", call. = FALSE)
  }
  history$match_id <- as.character(history$match_id)
  history$home_team_id <- phase12_team_id(history$home_team)
  history$away_team_id <- phase12_team_id(history$away_team)
  if (anyDuplicated(history$match_id)) stop("Phase 12 training history has duplicate match IDs", call. = FALSE)
  history
}

phase12_active_calibrator <- function() {
  payload <- readRDS("outputs/benchmarks/rolling_tournaments/phase12-calibration-release/calibration/calibrators.rds")
  candidates <- Filter(function(value) {
    identical(as.character(value$candidate_id), phase12_active_id) &&
      identical(as.character(value$track_id), "updating")
  }, payload$calibrators)
  if (length(candidates) != 1L) stop("Phase 12 active calibrator is not unique", call. = FALSE)
  candidates[[1L]]
}

phase12_promotion_candidates <- function() {
  registry <- phase12_final_evaluation_candidate_registry()
  comparison <- utils::read.csv(
    "outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers/selection/all_baseline_paired_comparisons.csv",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  frozen <- comparison[
    comparison$candidate_id == phase12_active_id &
      comparison$baseline_id == "open_nb_incumbent" &
      comparison$track_id == "frozen",
    , drop = FALSE
  ]
  folds <- frozen[frozen$diagnostic == "fold" & nzchar(frozen$edition_id), , drop = FALSE]
  headline <- frozen[frozen$diagnostic == "equal_tournament_headline", , drop = FALSE]
  bootstrap <- frozen[frozen$diagnostic == "tournament_bootstrap", , drop = FALSE]
  breadth <- frozen[frozen$diagnostic == "fold_breadth", , drop = FALSE]
  if (nrow(folds) != 12L || nrow(headline) != 1L || nrow(bootstrap) != 1L || nrow(breadth) != 1L) {
    stop("Phase 12 frozen promotion evidence is incomplete for the active candidate", call. = FALSE)
  }
  complexity <- utils::read.csv(
    "outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers/selection/candidate_evidence.csv",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  complexity <- complexity$complexity_rank[complexity$candidate_id == phase12_active_id][1L]
  active <- list(
    candidate_id = phase12_active_id,
    incumbent_id = "open_nb_incumbent",
    uses_optional_data = FALSE,
    contracts = phase12_promotion_contracts(TRUE),
    core = list(
      rps_delta = as.numeric(headline$delta[[1L]]),
      ci_upper = as.numeric(bootstrap$upper[[1L]]),
      fold_wins = as.integer(breadth$fold_wins[[1L]]),
      world_cup_wins = as.integer(breadth$world_cup_wins[[1L]]),
      euro_wins = as.integer(breadth$euro_wins[[1L]]),
      maximum_fold_regression = as.numeric(breadth$maximum_fold_regression[[1L]]),
      # Phase 11 persisted only RPS selection evidence for this challenger.
      # Missing supporting evidence is deliberately represented as NA so the
      # inherited evaluator vetoes promotion instead of treating it as a pass.
      brier_relative_change = NA_real_,
      log_loss_relative_change = NA_real_,
      calibration_change = NA_real_
    ),
    core_headline_rps = as.numeric(headline$candidate_estimate[[1L]]),
    core_log_loss = NA_real_,
    core_brier = NA_real_,
    core_calibration_error = NA_real_,
    complexity_rank = as.integer(complexity)
  )
  inactive_ids <- as.character(registry$candidate_id[!as.logical(registry$admissible)])
  inactive <- lapply(inactive_ids, phase12_promotion_no_score_candidate, incumbent_id = "open_nb_incumbent")
  names(inactive) <- inactive_ids
  result <- c(setNames(list(active), phase12_active_id), inactive)
  result[as.character(registry$candidate_id)]
}

phase12_prediction_provider <- function(registry, preflight) {
  if (!identical(as.character(registry$candidate_id[registry$admissible]), phase12_active_id)) {
    stop("Phase 12 prediction provider received an unexpected active registry identity", call. = FALSE)
  }
  target <- phase12_target_fixtures(phase12_final_cutoff)
  history <- phase12_training_history(phase12_final_cutoff)
  prepared <- hybrid_prepare_dynamic_history_and_fixtures(
    history = history, fixtures = target, pseudo_exposure = 8, half_life_days = 730
  )
  fixtures <- target
  dynamic_features <- setdiff(
    names(prepared$fixtures),
    c("fixture_id", "actual_completion_date", "evidence_cutoff_exclusive", "home_team_id", "away_team_id")
  )
  for (column in dynamic_features) fixtures[[column]] <- prepared$fixtures[[column]]
  fixtures$score_eligible <- TRUE
  seed_registry <- hybrid_default_seed_registry(fixtures, seed = 920001L)
  protocol <- load_and_validate_hybrid_protocol()
  adapter <- run_registered_hybrid_adapter(
    candidate_id = phase12_active_id,
    history = prepared$history,
    fixtures = fixtures,
    seed_registry = seed_registry,
    support_max = 40L,
    run_id = phase12_run_id,
    protocol = protocol
  )
  calibrator <- phase12_active_calibrator()
  predictions <- apply_phase12_1x2_calibrator(calibrator, adapter$predictions)
  predictions$p_home_raw <- adapter$predictions$p_home
  predictions$p_draw_raw <- adapter$predictions$p_draw
  predictions$p_away_raw <- adapter$predictions$p_away
  predictions$p_home <- predictions$p_home_calibrated
  predictions$p_draw <- predictions$p_draw_calibrated
  predictions$p_away <- predictions$p_away_calibrated
  predictions$primary_probability_view <- "calibrated_1x2"
  prediction_columns <- c(
    "run_id", "model_id", "panel_id", "edition_id", "track_id", "fixture_id",
    "score_distribution_id", "p_home", "p_draw", "p_away", "p_over_2_5",
    "p_under_2_5", "p_btts", "prediction_status", "primary_probability_view",
    "p_home_raw", "p_draw_raw", "p_away_raw"
  )
  predictions <- predictions[, intersect(prediction_columns, names(predictions)), drop = FALSE]
  fixture_identities <- fixtures[, c("edition_id", "fixture_id", "score_eligible"), drop = FALSE]
  list(
    predictions = predictions,
    fixtures = fixture_identities,
    distributions = adapter$distributions
  )
}

phase12_reset_final_evaluation_state()
preflight <- phase12_preflight_final_evaluation(
  final_state = list(approval_state = "approved", holdout_state = "unopened", label_path = phase12_final_evaluation_allowlisted_label_path()),
  protocol = "data/benchmark/phase09/promotion_protocol.json"
)
if (!isTRUE(preflight$can_open)) stop("Phase 12 approval state did not authorize the one-shot opener", call. = FALSE)

result <- run_phase12_final_evaluation_once(
  expected_source_sha256 = phase12_label_sha256,
  approval_state = "approved",
  label_path = phase12_final_evaluation_allowlisted_label_path(),
  label_provider = phase12_real_label_provider,
  prediction_provider = phase12_prediction_provider,
  output_dir = phase12_output_dir,
  promotion_candidates = phase12_promotion_candidates(),
  promotion_report_path = file.path(phase12_output_dir, "manifests/promotion_report.csv")
)

validate_phase12_final_evaluation_manifest(result$manifest_path)
cat("PHASE12_FINAL_EVALUATION_OK\n")
cat("provider_calls=", result$provider_calls, "\n", sep = "")
cat("scored_candidates=", sum(result$manifest_rows$score_status == "scored"), "\n", sep = "")
cat("fixture_rows=", sum(result$manifest_rows$observed_fixture_count), "\n", sep = "")
cat("release_decision=", result$promotion$release_decision, "\n", sep = "")
cat("selected_id=", result$promotion$selected_id, "\n", sep = "")
cat("manifest=", result$manifest_path, "\n", sep = "")
