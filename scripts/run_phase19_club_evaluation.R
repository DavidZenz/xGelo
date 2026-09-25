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
  "R/club/clubelo.R",
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
  current$source_clubs <- clubs
  current$club_count <- as.integer(nrow(clubs))
  current$roster_sha256 <- phase18_hash_table_v2(
    clubs, key = "club_id", schema_tag = "phase19-current-ucl-club-roster-v1"
  )
  current$source_club_table_sha256 <- phase19_current_ucl_source_clubs_sha256(clubs)
  current$snapshot_sha256 <- phase19_current_snapshot_sha256(current)
  phase19_validate_current_ucl_club_snapshot(current, "fixture")
  current
}

phase19_cli_smoke_prediction_set <- function(fit, rating, fold) {
  ids <- phase19_fold_parse_id_text(
    fold$declared_fixture_ids[[1L]], "declared_fixture_ids"
  )
  fixtures <- rating$predictions[
    match(ids, as.character(rating$predictions$fixture_id)), , drop = FALSE
  ]
  if (anyNA(fixtures$fixture_id)) {
    phase19_cli_abort("fixture rating replay does not cover the declared assessment")
  }
  # The goal-model API owns all score-grid and market calculations.  The
  # fixture controller uses a final local fit only for a diagnostic smoke
  # path; its prediction rows are explicitly rebound to the frozen fold
  # assessment cutoff before scoring and can never become production evidence.
  fixtures$evidence_cutoff_exclusive <- fit$cutoff_utc
  result <- phase19_predict_club_goal_model(fit, fixtures, ids)
  result$predictions$evidence_cutoff_exclusive <- fold$calibration_cutoff_exclusive
  result$predictions$prediction_sha256 <- phase19_club_goal_prediction_row_hash(
    result$predictions
  )
  result$prediction_table_sha256 <- phase18_hash_table_v2(
    result$predictions, key = "fixture_id",
    schema_tag = "phase19-club-goal-predictions-v1"
  )
  phase19_validate_club_goal_predictions(result, ids, require_goal_grid = TRUE)
  result
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

phase19_cli_smoke_calibration_fold <- function(fold, model_id, row_count = 60L) {
  assessment_ids <- sprintf(
    "phase19-smoke-assessment-%s-%03d", model_id, seq_len(row_count)
  )
  calibration_ids <- sprintf(
    "phase19-smoke-calibration-%s-%03d", model_id, seq_len(row_count)
  )
  result <- fold
  result$declared_fixture_ids <- paste(assessment_ids, collapse = "|")
  result$declared_fixture_count <- as.integer(row_count)
  result$calibration_fixture_ids <- paste(calibration_ids, collapse = "|")
  result$calibration_fixture_count <- as.integer(row_count)
  result$calibration_fixture_sha256 <- phase19_fold_id_sha256(calibration_ids, "calibration")
  result$row_sha256 <- phase19_fold_row_sha256(result)
  result
}

phase19_cli_smoke_calibration_rows <- function(predictions, fold, model_id) {
  row_count <- 60L
  ids <- phase19_fold_parse_id_text(
    fold$calibration_fixture_ids[[1L]], "calibration_fixture_ids"
  )
  source <- predictions$predictions[
    ((seq_len(row_count) - 1L) %% nrow(predictions$predictions)) + 1L, , drop = FALSE
  ]
  lower <- as.POSIXct(fold$training_cutoff_exclusive[[1L]],
                      format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  upper <- as.POSIXct(fold$calibration_cutoff_exclusive[[1L]],
                      format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  instant <- lower + (upper - lower) / 2
  kickoff <- format(instant, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  completion <- format(instant + 3600, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  observed <- rep(c("home", "draw", "away"), length.out = row_count)
  rows <- data.frame(
    fixture_id = ids, candidate_id = model_id,
    outer_fold_id = as.character(fold$fold_id),
    inner_fold_id = rep(c("inner_01", "inner_02", "inner_03"), length.out = row_count),
    evidence_role = "inner_out_of_fold", competition_id = "phase19-fixture-smoke",
    event_date = substr(kickoff, 1L, 10L), kickoff_utc = kickoff,
    kickoff_precision = "instant", completion_not_before_utc = completion,
    evidence_available_at_utc = completion, counts_for_model = TRUE,
    p_home_raw = as.numeric(source$p_home), p_draw_raw = as.numeric(source$p_draw),
    p_away_raw = as.numeric(source$p_away), observed_class = observed,
    source_grid_sha256 = as.character(source$distribution_sha256),
    source_prediction_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  rows$source_prediction_sha256 <- phase19_club_calibration_source_row_sha256(rows)
  rows
}

phase19_cli_smoke_calibrator <- function(model_id, registration, protocol, fold,
                                          predictions) {
  calibration_fold <- phase19_cli_smoke_calibration_fold(fold, model_id)
  rows <- phase19_cli_smoke_calibration_rows(predictions, calibration_fold, model_id)
  calibrator <- phase19_fit_club_calibrator(
    rows, calibration_fold, registration, protocol
  )
  phase19_validate_club_calibrator(calibrator, require_fitted = TRUE)
  ids <- phase19_fold_parse_id_text(
    calibration_fold$declared_fixture_ids[[1L]], "declared_fixture_ids"
  )
  assessment <- predictions$predictions[
    ((seq_along(ids) - 1L) %% nrow(predictions$predictions)) + 1L, , drop = FALSE
  ]
  assessment$fixture_id <- ids
  assessment$candidate_id <- model_id
  assessment$evidence_cutoff_exclusive <- calibration_fold$calibration_cutoff_exclusive
  view <- phase19_apply_club_calibrator(calibrator, assessment, calibration_fold)
  phase19_validate_club_calibrated_view(view, calibration_fold)
  list(calibrator = calibrator, fold = calibration_fold, source = rows, view = view)
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
  if (identical(fits$club_venue_nb$fit_sha256, fits$club_elo_nb$fit_sha256)) {
    phase19_cli_abort("registered club models produced identical fit identities")
  }
  folds <- phase19_build_fixture_club_fold_registry(training, protocol)
  fold_runs <- lapply(seq_len(nrow(folds)), function(index) {
    fold <- folds[index, , drop = FALSE]
    outcomes <- phase19_cli_outcomes(training, fold)
    candidate <- phase19_cli_smoke_prediction_set(fits$club_elo_nb, rating, fold)
    incumbent <- phase19_cli_smoke_prediction_set(fits$club_venue_nb, rating, fold)
    list(fold = fold, outcomes = outcomes, candidate = candidate, incumbent = incumbent)
  })
  candidate_registration <- registrations[
    registrations$model_id == "club_elo_nb", , drop = FALSE
  ]
  incumbent_registration <- registrations[
    registrations$model_id == "club_venue_nb", , drop = FALSE
  ]
  candidate_calibrator <- phase19_cli_smoke_calibrator(
    "club_elo_nb", candidate_registration, protocol, fold_runs[[1L]]$fold,
    fold_runs[[1L]]$candidate
  )
  incumbent_calibrator <- phase19_cli_smoke_calibrator(
    "club_venue_nb", incumbent_registration, protocol, fold_runs[[1L]]$fold,
    fold_runs[[1L]]$incumbent
  )
  calibrators <- list(
    club_elo_nb = candidate_calibrator$calibrator,
    club_venue_nb = incumbent_calibrator$calibrator
  )
  evaluations <- lapply(fold_runs, function(run) {
    fold <- run$fold
    support_hash <- function(calibrator) {
      phase19_club_calibration_hash_values(
        list(
          calibrator_sha256 = calibrator$calibrator_sha256,
          source_predictions_sha256 = calibrator$source_predictions_sha256
        ),
        "phase19-club-fixture-smoke-calibration-decision-v1"
      )
    }
    support <- data.frame(
      model_id = c("club_venue_nb", "club_elo_nb"), fit_status = "converged",
      fallback_status = "none", fit_sha256 = c(fits$club_venue_nb$fit_sha256, fits$club_elo_nb$fit_sha256),
      calibrator_status = "fitted", primary_probability_view = "raw_1x2",
      calibrator_sha256 = c(
        calibrators$club_venue_nb$calibrator_sha256,
        calibrators$club_elo_nb$calibrator_sha256
      ), calibration_evidence_sha256 = c(
        calibrators$club_venue_nb$source_predictions_sha256,
        calibrators$club_elo_nb$source_predictions_sha256
      ), calibration_decision_sha256 = c(
        support_hash(calibrators$club_venue_nb),
        support_hash(calibrators$club_elo_nb)
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
    phase19_score_club_fold(
      run$candidate, run$incumbent, run$outcomes, fold, protocol, support, provenance
    )
  })
  aggregate <- phase19_aggregate_club_evaluations(evaluations, protocol)
  replay <- phase19_club_reproducibility_evidence(aggregate, aggregate, protocol)
  authority <- phase19_fixture_evaluation_authority(aggregate, protocol)
  integrity <- phase19_derive_club_integrity_evidence(
    aggregate, protocol, replay, authority
  )
  decision <- phase19_evaluate_club_promotion(
    aggregate, protocol, replay = replay, integrity = integrity, authority = authority
  )
  phase19_validate_club_promotion_decision(
    decision, aggregate, protocol, replay = replay, integrity = integrity,
    authority = authority
  )
  protocol_release <- protocol
  protocol_release$fold_registry_sha256 <- phase19_fold_registry_sha256(folds, training, protocol, "fixture")
  protocol_release$fold_review_sha256 <- ""
  protocol_release$unavailable_feature_ids <- paste(phase19_feature_ids(), collapse = "|")
  model <- fits[[as.character(decision$selected_model_id)]]
  calibrator <- calibrators[[as.character(decision$selected_model_id)]]
  staged <- phase19_stage_fixture_club_release(
    decision, model, calibrator, paths$output_root, release_id = "fixture-club-phase19",
    history_snapshot = training, current_snapshot = current, protocol = protocol_release,
    evaluation = aggregate, authority = authority, replay = replay, integrity = integrity
  )
  installed <- phase19_install_fixture_club_release(staged$release_root, paths$release_root)
  resolved <- phase19_resolve_fixture_club_release(paths$release_root)
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
    evaluation_mode = "fixture_smoke", full_evaluation_gate = FALSE,
    production_eligible = FALSE, calibration_mode = "fixture_smoke",
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
