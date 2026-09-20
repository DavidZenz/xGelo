#!/usr/bin/env Rscript

# Phase 19 is intentionally a closed controller.  Production has no
# caller-selectable evidence path; fixture mode is an explicit, temporary,
# permanently non-promotable diagnostic path.

phase19_cli_file_arg <- commandArgs(trailingOnly = FALSE)
phase19_cli_script_arg <- phase19_cli_file_arg[startsWith(phase19_cli_file_arg, "--file=")]
phase19_cli_script <- if (length(phase19_cli_script_arg)) {
  sub("^--file=", "", phase19_cli_script_arg[[1L]])
} else {
  "scripts/run_phase19_club_evaluation.R"
}
phase19_cli_root <- normalizePath(
  file.path(dirname(phase19_cli_script), ".."),
  winslash = "/", mustWork = TRUE
)

phase19_cli_abort <- function(message, status = 2L) {
  cat(paste0("phase19_cli_error: ", as.character(message), "\n"), file = stderr())
  quit(save = "no", status = as.integer(status))
}

phase19_cli_source <- function(relative_path) {
  for (dependency in relative_path) {
    path <- file.path(phase19_cli_root, dependency)
    if (!file.exists(path) || dir.exists(path)) {
      phase19_cli_abort(paste0("missing controller dependency ", basename(dependency)), 3L)
    }
    source(path, local = .GlobalEnv)
  }
}

phase19_cli_source(c(
  "R/common/phase18_canonical_hash.R",
  "R/competition/source_contracts.R",
  "R/competition/ucl_source_acceptance.R",
  "R/competition/edition_registry.R",
  "R/club/identity.R",
  "R/club/identity_bootstrap.R",
  "R/competition/football_data_org_adapter.R",
  "R/competition/ucl_source_bundle.R",
  "R/competition/ucl_source_refresh.R",
  "R/club/history_contract.R",
  "R/evaluation/proper_scores.R",
  "R/evaluation/benchmark_scores.R",
  "R/release/domain_contract.R",
  "R/club/model_contract.R",
  "R/club/evaluation_protocol.R",
  "R/club/rating.R",
  "R/club/goal_model.R",
  "R/club/calibration.R",
  "R/club/evaluation.R",
  "R/club/release.R"
))

phase19_cli_usage <- function() {
  cat(paste(
    "Usage:",
    "  Rscript scripts/run_phase19_club_evaluation.R",
    "  Rscript scripts/run_phase19_club_evaluation.R --fixture --fixture-root <tmp>",
    "      --output-root <tmp> --release-root <tmp>",
    sep = "\n"
  ), "\n", sep = "")
}

phase19_cli_parse_args <- function(arguments) {
  if ("--help" %in% arguments) {
    phase19_cli_usage()
    return(list(help = TRUE))
  }
  if (!length(arguments)) {
    return(list(mode = "production"))
  }

  known <- c("--fixture", "--fixture-root", "--output-root", "--release-root")
  values <- list()
  fixture <- FALSE
  index <- 1L
  while (index <= length(arguments)) {
    token <- arguments[[index]]
    if (identical(token, "--fixture")) {
      if (isTRUE(fixture)) phase19_cli_abort("duplicate mode flag")
      fixture <- TRUE
      index <- index + 1L
      next
    }
    if (!startsWith(token, "--")) phase19_cli_abort("positional arguments are not accepted")
    pieces <- strsplit(token, "=", fixed = TRUE)[[1L]]
    flag <- pieces[[1L]]
    if (!flag %in% c("--fixture-root", "--output-root", "--release-root")) {
      phase19_cli_abort("unknown or caller-selectable authority flag")
    }
    if (length(pieces) > 2L) phase19_cli_abort("authority flag has more than one value")
    value <- if (length(pieces) == 2L) pieces[[2L]] else {
      if (index == length(arguments)) phase19_cli_abort("authority flag is missing a value")
      index <- index + 1L
      arguments[[index]]
    }
    if (!nzchar(value) || !is.null(values[[flag]])) phase19_cli_abort("duplicate or empty authority root")
    values[[flag]] <- value
    index <- index + 1L
  }
  if (!isTRUE(fixture)) phase19_cli_abort("fixture roots require the explicit --fixture mode")
  required <- c("--fixture-root", "--output-root", "--release-root")
  if (length(setdiff(required, names(values)))) {
    phase19_cli_abort("fixture mode requires explicit fixture, output, and release roots")
  }
  list(
    mode = "fixture", fixture_root = values[["--fixture-root"]],
    output_root = values[["--output-root"]], release_root = values[["--release-root"]]
  )
}

phase19_cli_normalize_root <- function(path, label) {
  if (length(path) != 1L || is.na(path) || !nzchar(path) || !startsWith(path, "/")) {
    phase19_cli_abort(paste0(label, " must be an absolute path"))
  }
  if (nzchar(Sys.readlink(path))) phase19_cli_abort(paste0(label, " cannot be a symlink"))
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

phase19_cli_validate_external_fixture_root <- function(root) {
  if (length(root) != 1L || !dir.exists(root) || nzchar(Sys.readlink(root))) {
    phase19_cli_abort("fixture root must be one real non-symlinked directory")
  }
  marker_path <- file.path(root, "phase19_fixture_authority.json")
  if (!file.exists(marker_path) || dir.exists(marker_path)) {
    phase19_cli_abort("fixture root marker is missing")
  }
  marker <- as.list(jsonlite::fromJSON(marker_path, simplifyVector = TRUE))
  if (!identical(names(marker), phase19_fixture_marker_schema())) {
    phase19_cli_abort("fixture root marker schema is not exact")
  }
  marker[] <- lapply(marker, function(value) if (is.logical(value)) value else as.character(value))
  expected_root <- phase19_fixture_root_sha256(root, marker$fixture_id)
  if (!identical(as.character(marker$schema_version), "phase19-club-fixture-authority-v1") ||
      !identical(as.character(marker$hash_encoding_version), phase18_canonical_encoding_v2()) ||
      !identical(as.character(marker$authority_mode), "fixture") ||
      !isTRUE(marker$fixture_authority) ||
      !identical(as.character(marker$fixture_root_sha256), expected_root) ||
      !identical(as.character(marker$marker_sha256), phase19_fixture_marker_sha256(marker))) {
    phase19_cli_abort("fixture root marker is stale, forged, or promotable")
  }
  entries <- list.files(root, all.files = TRUE, recursive = TRUE, full.names = TRUE,
                        include.dirs = TRUE)
  if (length(entries) && any(nzchar(Sys.readlink(entries)))) {
    phase19_cli_abort("fixture root cannot contain symlinks")
  }
  invisible(TRUE)
}

phase19_cli_assert_fixture_roots <- function(fixture_root, output_root, release_root) {
  fixture_root <- phase19_cli_normalize_root(fixture_root, "fixture root")
  output_root <- phase19_cli_normalize_root(output_root, "output root")
  release_root <- phase19_cli_normalize_root(release_root, "release root")
  temporary <- normalizePath(
    Sys.getenv("TMPDIR", unset = dirname(tempdir())),
    winslash = "/", mustWork = FALSE
  )
  if (!dir.exists(temporary)) temporary <- dirname(normalizePath(tempdir(), winslash = "/", mustWork = TRUE))
  under_temp <- function(path) identical(path, temporary) || startsWith(path, paste0(temporary, "/"))
  if (!under_temp(fixture_root) || !under_temp(output_root) || !under_temp(release_root)) {
    phase19_cli_abort("fixture, output, and release roots must be below the process temporary root")
  }
  within <- function(child, parent) identical(child, parent) || startsWith(child, paste0(parent, "/"))
  if (within(fixture_root, output_root) || within(output_root, fixture_root) ||
      within(fixture_root, release_root) || within(release_root, fixture_root) ||
      within(output_root, release_root) || within(release_root, output_root)) {
    phase19_cli_abort("fixture, output, and release roots must be disjoint")
  }
  if (within(output_root, phase19_cli_root) || within(release_root, phase19_cli_root)) {
    phase19_cli_abort("fixture roots cannot overlap the project")
  }
  phase19_cli_validate_external_fixture_root(fixture_root)
  list(fixture_root = fixture_root, output_root = output_root, release_root = release_root)
}

phase19_cli_copy_tree <- function(source, destination, exclude = character()) {
  if (!dir.exists(destination) && !dir.create(destination, recursive = TRUE, showWarnings = FALSE)) {
    phase19_cli_abort("fixture result publication failed")
  }
  children <- list.files(source, all.files = TRUE, no.. = TRUE, full.names = TRUE)
  for (child in children) {
    if (basename(child) %in% exclude) next
    target <- file.path(destination, basename(child))
    if (dir.exists(child)) {
      phase19_cli_copy_tree(child, target)
    } else if (!file.copy(child, target, overwrite = TRUE, copy.date = TRUE)) {
      phase19_cli_abort("fixture result publication failed")
    }
  }
  invisible(destination)
}

phase19_cli_prepare_fixture_run <- function(paths) {
  sandbox <- tempfile("phase19-cli-", tmpdir = tempdir())
  if (!dir.create(sandbox, recursive = TRUE, showWarnings = FALSE)) {
    phase19_cli_abort("fixture sandbox creation failed", 4L)
  }
  internal <- list(
    fixture_root = file.path(sandbox, "fixture"),
    output_root = file.path(sandbox, "output"),
    release_root = file.path(sandbox, "release")
  )
  for (path in internal) dir.create(path, recursive = TRUE, showWarnings = FALSE)
  phase19_cli_copy_tree(paths$fixture_root, internal$fixture_root,
                        exclude = "phase19_fixture_authority.json")
  phase19_write_fixture_authority_marker(internal$fixture_root, "phase19-cli-materialized")
  list(internal = internal, caller = paths)
}

phase19_cli_atomic_json <- function(value, path) {
  directory <- dirname(path)
  if (!dir.exists(directory)) dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  stage <- tempfile(paste0(".", basename(path), "-"), tmpdir = directory)
  on.exit(if (file.exists(stage)) unlink(stage, force = TRUE), add = TRUE)
  json <- paste0(jsonlite::toJSON(value, auto_unbox = TRUE, pretty = TRUE, null = "null"), "\n")
  writeBin(charToRaw(json), stage)
  if (!file.rename(stage, path)) phase19_cli_abort("atomic result publication failed", 4L)
  invisible(path)
}

phase19_cli_emit <- function(record, output_path = NULL) {
  if (!is.null(output_path)) phase19_cli_atomic_json(record, output_path)
  cat(sprintf(
    "PHASE19_RESULT status=%s reason_code=%s diagnostic_gate_outcome=%s authority_eligibility=%s promotion_status=%s\n",
    record$status, record$reason_code, record$diagnostic_gate_outcome,
    record$authority_eligibility, record$promotion_status
  ))
  invisible(record)
}

phase19_cli_blocked_record <- function(reason_code) {
  list(
    schema_version = "phase19-club-controller-result-v1",
    forecast_domain = "club", authority_mode = "production", fixture_authority = FALSE,
    status = "human_needed", reason_code = as.character(reason_code),
    diagnostic_gate_outcome = "blocked", authority_eligibility = "production_blocked",
    promotion_status = "blocked", model_work_started = FALSE,
    release_mutated = FALSE, selector_mutated = FALSE,
    provenance = list(authority_chain = "phase18_history_current>current_ucl_identity>policy_review>fold_review")
  )
}

phase19_cli_production <- function() {
  history <- tryCatch(phase19_load_club_training_snapshot(), error = function(error) {
    structure(list(status = "blocked", reason_code = "no_accepted_club_history"), class = "phase19_cli_blocked")
  })
  history_status <- if (identical(history$status, "ready")) "ready" else "blocked"
  current <- NULL
  policy <- NULL
  fold <- NULL
  current_status <- policy_status <- fold_status <- "blocked"
  if (identical(history_status, "ready")) {
    current <- tryCatch(phase19_load_current_ucl_club_snapshot(), error = function(error) {
      list(status = "blocked", reason_code = "no_accepted_current_ucl")
    })
    current_status <- if (identical(current$status, "ready")) "ready" else "blocked"
  }
  if (identical(history_status, "ready") && identical(current_status, "ready")) {
    policy <- tryCatch(phase19_load_club_evaluation_protocol(), error = function(error) {
      list(status = "blocked", reason_code = "protocol_policy_not_approved")
    })
    policy_status <- if (identical(policy$status, "ready")) "ready" else "blocked"
  }
  if (identical(history_status, "ready") && identical(current_status, "ready") &&
      identical(policy_status, "ready")) {
    fold <- list(status = "blocked", reason_code = "fold_inventory_not_approved")
    fold_status <- "blocked"
  }
  reason <- phase19_club_production_block_reason(
    history_status, current_status, policy_status, fold_status
  )
  if (!nzchar(reason)) phase19_cli_abort("production controller reached an unsupported state", 5L)
  record <- phase19_cli_blocked_record(reason)
  output_path <- file.path(phase19_cli_root, "outputs/club_model/blocked/phase19-production-blocked.json")
  phase19_cli_emit(record, output_path)
  invisible(record)
}

phase19_cli_fixture_matching_current <- function(current, training) {
  ids <- sort(unique(c(as.character(training$matches$home_club_id),
                       as.character(training$matches$away_club_id))), method = "radix")
  if (length(ids) < 4L || length(ids) > nrow(current$clubs)) {
    phase19_cli_abort("fixture history/current roster has no valid connected club projection")
  }
  clubs <- current$clubs[seq_len(length(ids)), , drop = FALSE]
  clubs$club_id <- ids
  clubs$canonical_name <- paste("Fixture Club", seq_along(ids))
  clubs$display_name <- clubs$canonical_name
  clubs$row_sha256 <- ""
  clubs$row_sha256 <- phase18_ucl_projected_row_hash(clubs)
  clubs <- clubs[order(clubs$club_id, method = "radix"), , drop = FALSE]
  rownames(clubs) <- NULL
  current$clubs <- clubs
  current$club_count <- as.integer(nrow(clubs))
  current$roster_sha256 <- phase18_hash_table_v2(
    clubs, key = "club_id", schema_tag = "phase19-current-ucl-club-roster-v1"
  )
  current$snapshot_sha256 <- phase19_current_snapshot_sha256(current)
  phase19_validate_current_ucl_club_snapshot(current, "fixture")
  current
}

phase19_cli_grid <- function(fixture_id, model_id, home_mean, away_mean, fit_sha256,
                             profile = c("poisson", "calibrated")) {
  profile <- match.arg(profile)
  goals <- 0:40
  raw <- if (identical(profile, "calibrated")) {
    calibrated <- matrix(0, nrow = length(goals), ncol = length(goals))
    calibrated[2L, 1L] <- 0.50
    calibrated[1L, 1L] <- 0.25
    calibrated[1L, 2L] <- 0.25
    calibrated
  } else {
    outer(stats::dpois(goals, home_mean), stats::dpois(goals, away_mean))
  }
  grid <- expand.grid(home_goals = goals, away_goals = goals,
                      KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  grid$probability <- as.vector(raw / sum(raw))
  grid$fixture_id <- as.character(fixture_id)
  grid$score_distribution_id <- paste0(fixture_id, "__", model_id, "__score")
  grid$model_id <- model_id
  grid$support_max_home <- 40L
  grid$support_max_away <- 40L
  grid$raw_tail_mass <- max(0, 1 - sum(raw))
  grid$normalized <- TRUE
  grid$tail_policy <- "truncate_0_40_then_joint_renormalize_once"
  grid$fit_sha256 <- fit_sha256
  grid <- grid[, c("fixture_id", "score_distribution_id", "model_id", "home_goals",
                   "away_goals", "probability", "support_max_home", "support_max_away",
                   "raw_tail_mass", "normalized", "tail_policy", "fit_sha256")]
  grid <- grid[order(grid$home_goals, grid$away_goals, method = "radix"), , drop = FALSE]
  rownames(grid) <- NULL
  grid
}

phase19_cli_prediction_set <- function(fit, fold, outcomes, strong = FALSE) {
  ids <- phase19_fold_parse_id_text(fold$declared_fixture_ids[[1L]], "declared_fixture_ids")
  grids <- lapply(seq_along(ids), function(index) {
    if (!isTRUE(strong)) return(phase19_cli_grid(ids[[index]], fit$model_id, 1.15, 1.15, fit$fit_sha256))
    home <- as.numeric(outcomes$regulation_home_goals[[index]])
    away <- as.numeric(outcomes$regulation_away_goals[[index]])
    phase19_cli_grid(ids[[index]], fit$model_id, 1.05, 1.05, fit$fit_sha256,
                     profile = "calibrated")
  })
  rows <- lapply(seq_along(ids), function(index) {
    grid <- grids[[index]]
    market <- phase19_club_goal_grid_markets(grid)
    data.frame(
      fixture_id = ids[[index]], forecast_domain = "club", authority_mode = "fixture",
      fixture_authority = TRUE, promotion_eligible = FALSE, promotion_comparable = TRUE,
      model_id = fit$model_id, model_family = "negative_binomial",
      output_capability = "complete_score_distribution_and_derived_markets",
      goal_distribution_declared = TRUE, prediction_status = "ready_goal_distribution",
      boundary_id = paste0("boundary-", ids[[index]]),
      evidence_cutoff_exclusive = fold$calibration_cutoff_exclusive,
      home_club_id = as.character(outcomes$home_club_id[[index]]),
      away_club_id = as.character(outcomes$away_club_id[[index]]),
      score_distribution_id = unique(grid$score_distribution_id),
      p_home = market$p_home, p_draw = market$p_draw, p_away = market$p_away,
      p_over_2_5 = market$p_over_2_5, p_btts = market$p_btts,
      expected_home_goals = market$expected_home_goals,
      expected_away_goals = market$expected_away_goals,
      likely_home_goals = market$likely_home_goals,
      likely_away_goals = market$likely_away_goals, raw_tail_mass = grid$raw_tail_mass[[1L]],
      support_max = 40L, fit_sha256 = fit$fit_sha256,
      rating_evidence_sha256 = fit$rating_evidence_sha256,
      training_snapshot_sha256 = fold$snapshot_sha256,
      current_snapshot_sha256 = fit$current_snapshot_sha256,
      protocol_sha256 = fit$protocol_sha256, fallback_status = "none",
      distribution_sha256 = phase18_hash_table_v2(
        grid, key = c("fixture_id", "home_goals", "away_goals"),
        schema_tag = "phase19-club-goal-distribution-v1"
      ), prediction_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
    )
  })
  predictions <- do.call(rbind, rows)
  predictions$prediction_sha256 <- phase19_club_goal_prediction_row_hash(predictions)
  distributions <- do.call(rbind, grids)
  rownames(predictions) <- NULL
  rownames(distributions) <- NULL
  structure(list(
    schema_version = "phase19-club-goal-prediction-set-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(), forecast_domain = "club",
    authority_mode = "fixture", fixture_authority = TRUE, promotion_eligible = FALSE,
    promotion_comparable = TRUE, model_id = fit$model_id,
    output_capability = "complete_score_distribution_and_derived_markets",
    goal_distribution_declared = TRUE, declared_fixture_ids = ids,
    fit_sha256 = fit$fit_sha256, predictions = predictions, distributions = distributions,
    prediction_table_sha256 = phase18_hash_table_v2(
      predictions, key = "fixture_id", schema_tag = "phase19-club-goal-predictions-v1"
    ), distribution_table_sha256 = phase18_hash_table_v2(
      distributions, key = c("fixture_id", "home_goals", "away_goals"),
      schema_tag = "phase19-club-goal-distributions-v1"
    )
  ), class = c("phase19_club_goal_predictions", "list"))
}

phase19_cli_outcomes <- function(training, fold) {
  ids <- phase19_fold_parse_id_text(fold$declared_fixture_ids[[1L]], "declared_fixture_ids")
  rows <- training$matches[match(ids, training$matches$match_id), , drop = FALSE]
  data.frame(
    fixture_id = ids, forecast_domain = "club",
    competition_id = as.character(rows$competition_id), season_id = as.character(rows$season_id),
    kickoff_utc = as.character(rows$kickoff_utc),
    completion_not_before_utc = as.character(rows$completion_not_before_utc),
    evidence_available_at_utc = as.character(rows$evidence_available_at_utc),
    home_club_id = as.character(rows$home_club_id), away_club_id = as.character(rows$away_club_id),
    regulation_home_goals = as.integer(rows$regulation_home_goals),
    regulation_away_goals = as.integer(rows$regulation_away_goals),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase19_cli_fixture_calibrator <- function(model_id, fit, protocol) {
  structure(list(
    schema_version = "phase19-club-calibrator-v1",
    hash_encoding_version = phase18_canonical_encoding_v2(), forecast_domain = "club",
    authority_mode = "fixture", fixture_authority = TRUE, production_eligible = FALSE,
    model_id = model_id, candidate_id = model_id, calibrator_id = "fixture-controller-calibrator",
    fit_status = "fitted", distribution_unchanged = TRUE, calibrator_sha256 = digest::digest(
      paste(model_id, fit$fit_sha256, protocol$protocol_sha256, sep = "|"),
      algo = "sha256", serialize = FALSE
    ), protocol_sha256 = protocol$protocol_sha256,
    calibration_data_cutoff = fit$cutoff_utc
  ), class = c("phase19_club_calibrator", "list"))
}

phase19_cli_fixture <- function(paths) {
  training <- phase19_load_fixture_club_training_snapshot(paths$fixture_root)
  current <- phase19_load_fixture_current_ucl_club_snapshot(paths$fixture_root)
  current <- phase19_cli_fixture_matching_current(current, training)
  protocol <- phase19_load_fixture_club_evaluation_protocol()
  parameters <- phase19_club_rating_parameters(
    base_rating = 1500, home_advantage = 60, k_factor = 20, inactivity_factor = 0.995
  )
  rating <- phase19_replay_club_ratings(
    training, current, parameters, cutoff_utc = training$cutoff_utc
  )
  if (!identical(rating$status, "ready")) phase19_cli_abort("fixture rating authority did not resolve")
  registrations <- protocol$candidate_registry[
    protocol$candidate_registry$model_id %in% c("club_venue_nb", "club_elo_nb"), , drop = FALSE
  ]
  fits <- list(
    club_venue_nb = phase19_fit_club_goal_model(
      registrations[registrations$model_id == "club_venue_nb", , drop = FALSE],
      training, rating, protocol, training$cutoff_utc
    ),
    club_elo_nb = phase19_fit_club_goal_model(
      registrations[registrations$model_id == "club_elo_nb", , drop = FALSE],
      training, rating, protocol, training$cutoff_utc
    )
  )
  folds <- phase19_build_fixture_club_fold_registry(training, protocol)
  evaluations <- lapply(seq_len(nrow(folds)), function(index) {
    fold <- folds[index, , drop = FALSE]
    outcomes <- phase19_cli_outcomes(training, fold)
    candidate <- phase19_cli_prediction_set(fits$club_elo_nb, fold, outcomes, TRUE)
    incumbent <- phase19_cli_prediction_set(fits$club_venue_nb, fold, outcomes, FALSE)
    support <- data.frame(
      model_id = c("club_venue_nb", "club_elo_nb"), fit_status = "converged",
      fallback_status = "none", fit_sha256 = c(fits$club_venue_nb$fit_sha256, fits$club_elo_nb$fit_sha256),
      calibrator_status = "fitted", primary_probability_view = "raw_1x2",
      calibrator_sha256 = c(
        digest::digest(paste("calibrator", fits$club_venue_nb$fit_sha256), algo = "sha256", serialize = FALSE),
        digest::digest(paste("calibrator", fits$club_elo_nb$fit_sha256), algo = "sha256", serialize = FALSE)
      ), calibration_evidence_sha256 = c(
        digest::digest(paste("evidence", fits$club_venue_nb$fit_sha256), algo = "sha256", serialize = FALSE),
        digest::digest(paste("evidence", fits$club_elo_nb$fit_sha256), algo = "sha256", serialize = FALSE)
      ), calibration_decision_sha256 = c(
        digest::digest(paste("decision", fits$club_venue_nb$fit_sha256), algo = "sha256", serialize = FALSE),
        digest::digest(paste("decision", fits$club_elo_nb$fit_sha256), algo = "sha256", serialize = FALSE)
      ), stringsAsFactors = FALSE, check.names = FALSE
    )
    provenance <- data.frame(
      role = c("fit", "tuning", "calibration"),
      cutoff_exclusive = c(fold$training_cutoff_exclusive, fold$training_cutoff_exclusive,
                           fold$calibration_cutoff_exclusive),
      excluded_competition_id = c(fold$fit_excluded_competition_id,
                                  fold$tuning_excluded_competition_id,
                                  fold$calibration_excluded_competition_id),
      declared_fixture_sha256 = c(fold$training_fixture_sha256,
                                  fold$training_fixture_sha256,
                                  fold$calibration_fixture_sha256),
      stringsAsFactors = FALSE, check.names = FALSE
    )
    phase19_score_club_fold(candidate, incumbent, outcomes, fold, protocol, support, provenance)
  })
  aggregate <- phase19_aggregate_club_evaluations(evaluations, protocol)
  replay <- phase19_club_reproducibility_evidence(aggregate, aggregate, protocol)
  authority <- phase19_fixture_evaluation_authority(aggregate, protocol)
  integrity <- as.list(setNames(rep(TRUE, 11L), phase19_club_integrity_names()))
  decision <- phase19_evaluate_club_promotion(aggregate, protocol, replay, integrity, authority)
  phase19_validate_club_promotion_decision(decision, aggregate, protocol, replay, integrity, authority)
  protocol_release <- protocol
  protocol_release$fold_registry_sha256 <- phase19_fold_registry_sha256(folds, training, protocol, "fixture")
  protocol_release$fold_review_sha256 <- ""
  protocol_release$unavailable_feature_ids <- paste(phase19_feature_ids(), collapse = "|")
  model <- fits$club_elo_nb
  calibrator <- phase19_cli_fixture_calibrator("club_elo_nb", model, protocol_release)
  staged <- phase19_stage_fixture_club_release(
    decision, model, calibrator, paths$output_root, release_id = "fixture-club-phase19",
    history_snapshot = training, current_snapshot = current, protocol = protocol_release,
    evaluation = aggregate, authority = authority
  )
  installed <- phase19_install_club_release(staged$release_root, paths$release_root)
  resolved <- phase19_resolve_club_release(paths$release_root)
  if (!identical(resolved$forecast_domain, "club") ||
      !identical(as.character(resolved$model_contract$authority_mode), "fixture") ||
      isTRUE(resolved$model_contract$production_eligible)) {
    phase19_cli_abort("fixture release resolver returned non-fixture authority")
  }
  record <- list(
    schema_version = "phase19-club-controller-result-v1", forecast_domain = "club",
    authority_mode = "fixture", fixture_authority = TRUE, status = "human_needed",
    reason_code = "fixture_ineligible", diagnostic_gate_outcome = decision$diagnostic_gate_outcome,
    authority_eligibility = decision$authority_eligibility, promotion_status = decision$promotion_status,
    model_work_started = TRUE, release_mutated = TRUE, selector_mutated = TRUE,
    release_id = installed$release_id, evaluation_set_sha256 = aggregate$evaluation_set_sha256,
    decision_sha256 = decision$decision_sha256, provenance = list(
      training_snapshot_sha256 = training$snapshot_sha256,
      current_snapshot_sha256 = current$snapshot_sha256,
      protocol_sha256 = protocol$protocol_sha256,
      evaluation_set_sha256 = aggregate$evaluation_set_sha256,
      authority_sha256 = authority$authority_sha256
    )
  )
  phase19_cli_emit(record, file.path(paths$output_root, "phase19-fixture-result.json"))
  invisible(record)
}

phase19_cli_main <- function(arguments = commandArgs(trailingOnly = TRUE)) {
  parsed <- phase19_cli_parse_args(arguments)
  if (isTRUE(parsed$help)) return(invisible(NULL))
  if (identical(parsed$mode, "production")) return(phase19_cli_production())
  paths <- phase19_cli_assert_fixture_roots(
    parsed$fixture_root, parsed$output_root, parsed$release_root
  )
  run <- phase19_cli_prepare_fixture_run(paths)
  record <- phase19_cli_fixture(run$internal)
  phase19_cli_copy_tree(run$internal$output_root, paths$output_root)
  phase19_cli_copy_tree(run$internal$release_root, paths$release_root)
  invisible(record)
}

phase19_cli_main()
