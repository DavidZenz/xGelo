#' Label-free Phase 12 final-evaluation preflight and one-shot boundary.
#'
#' The opener is deliberately the only function in this file that can invoke a
#' label provider.  Plan 12-04 defines the seam and its fail-closed checks; the
#' later approval-gated plan owns copied-label publication and scoring.

phase12_final_evaluation_allowlisted_label_path <- function() {
  "data/benchmark/phase12/wc2026_labels.csv"
}

phase12_final_evaluation_state <- local({
  state <- new.env(parent = emptyenv())
  state$preflight <- NULL
  state$opened <- FALSE
  state$provider_calls <- 0L
  state
})

phase12_reset_final_evaluation_state <- function() {
  phase12_final_evaluation_state$preflight <- NULL
  phase12_final_evaluation_state$opened <- FALSE
  phase12_final_evaluation_state$provider_calls <- 0L
  invisible(TRUE)
}

phase12_final_evaluation_project_root <- function(project_root = ".") {
  if (!identical(project_root, ".")) return(normalizePath(project_root, winslash = "/", mustWork = TRUE))
  candidates <- c(getwd(), file.path(getwd(), "../.."), file.path(getwd(), "../../.."))
  for (candidate in candidates) {
    if (file.exists(file.path(candidate, "data/benchmark/phase12/freeze_manifest.csv"))) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }
  normalizePath(project_root, winslash = "/", mustWork = TRUE)
}

phase12_final_evaluation_resolve_path <- function(path, project_root = ".") {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    stop("Phase 12 final-evaluation path must be one non-empty value", call. = FALSE)
  }
  if (grepl("^/", path)) return(normalizePath(path, winslash = "/", mustWork = FALSE))
  file.path(phase12_final_evaluation_project_root(project_root), path)
}

phase12_final_evaluation_read_table <- function(value, name, project_root = ".") {
  if (is.data.frame(value)) return(value)
  path <- phase12_final_evaluation_resolve_path(value, project_root)
  if (!file.exists(path)) stop(name, " is missing: ", value, call. = FALSE)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
}

phase12_final_evaluation_source_if_missing <- function(relative_path, symbols, project_root = ".") {
  missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function")]
  if (!length(missing)) return(invisible(TRUE))
  path <- phase12_final_evaluation_resolve_path(relative_path, project_root)
  if (!file.exists(path)) stop("Phase 12 final-evaluation dependency is missing: ", relative_path, call. = FALSE)
  source(path, local = .GlobalEnv)
  missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function")]
  if (length(missing)) stop("Phase 12 final-evaluation dependency did not define: ", paste(missing, collapse = ", "), call. = FALSE)
  invisible(TRUE)
}

phase12_final_evaluation_source_if_missing(
  "R/release/final_fit.R",
  c("phase12_final_fit_allowlist", "validate_phase12_final_fit_manifest", "phase12_final_fit_file_hash",
    "phase12_final_fit_expected_active_id"),
  "."
)
phase12_final_evaluation_source_if_missing(
  "R/benchmark/cutoffs.R",
  c("benchmark_holdout_rows", "benchmark_outcome_columns", "guard_benchmark_purpose"),
  "."
)
phase12_final_evaluation_source_if_missing(
  "R/evaluation/proper_scores.R",
  c("validate_scoreline_distribution"),
  "."
)
phase12_final_evaluation_source_if_missing(
  "R/evaluation/benchmark_scores.R",
  c("score_benchmark_fixtures"),
  "."
)

phase12_final_evaluation_sha256 <- function(value, file = FALSE) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Phase 12 final-evaluation hashes", call. = FALSE)
  if (isTRUE(file)) return(digest::digest(value, algo = "sha256", file = TRUE))
  digest::digest(value, algo = "sha256", serialize = FALSE)
}

phase12_final_evaluation_protocol <- function(protocol) {
  if (is.list(protocol)) return(protocol)
  if (!is.character(protocol) || length(protocol) != 1L || !file.exists(protocol)) stop("Phase 12 promotion protocol is missing", call. = FALSE)
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required for the Phase 12 protocol", call. = FALSE)
  jsonlite::fromJSON(protocol, simplifyVector = TRUE, simplifyDataFrame = FALSE)
}

phase12_final_evaluation_flag <- function(value, name) {
  parsed <- if (is.logical(value)) value else {
    lowered <- tolower(trimws(as.character(value)))
    ifelse(lowered %in% c("true", "1", "yes"), TRUE,
      ifelse(lowered %in% c("false", "0", "no", ""), FALSE, NA))
  }
  if (length(parsed) != 1L || is.na(parsed)) stop(name, " must be TRUE or FALSE", call. = FALSE)
  isTRUE(parsed)
}

phase12_final_evaluation_preflight_fail <- function(code, message) {
  stop(paste0("phase12_preflight_", code, ": ", message), call. = FALSE)
}

phase12_final_evaluation_validate_gate <- function(gate, expected_ids) {
  required <- c("candidate_id", "track_id", "score_status", "primary_probability_view", "score_support_g")
  missing <- setdiff(required, names(gate))
  if (length(missing)) phase12_final_evaluation_preflight_fail("calibration_gate_drift", paste("missing", paste(missing, collapse = ", ")))
  if (nrow(gate) != 9L || anyDuplicated(paste(gate$candidate_id, gate$track_id, sep = "\r"))) phase12_final_evaluation_preflight_fail("candidate_activation", "calibration gate rows are not the nine unique identities")
  if (!identical(sort(as.character(gate$candidate_id)), sort(as.character(expected_ids)))) phase12_final_evaluation_preflight_fail("candidate_activation", "calibration gate candidate identities drifted")
  if (any(as.character(gate$track_id) != "updating")) phase12_final_evaluation_preflight_fail("track_identity", "final calibration gate must use updating track")
  if (any(as.integer(gate$score_support_g) != 40L)) phase12_final_evaluation_preflight_fail("score_support", "calibration gate G is not 40")
  if (sum(as.character(gate$score_status) == "scored") != 1L || !identical(as.character(gate$candidate_id[gate$score_status == "scored"]), phase12_final_fit_expected_active_id())) phase12_final_evaluation_preflight_fail("candidate_activation", "calibration gate active identity is not allowlisted")
  if (any(!as.character(gate$primary_probability_view) %in% c("calibrated_1x2", "raw_1x2"))) phase12_final_evaluation_preflight_fail("calibration_gate_drift", "calibration probability view is invalid")
  invisible(TRUE)
}

phase12_final_evaluation_validate_unopened_state <- function(final_state) {
  if (is.null(final_state)) final_state <- list()
  if (!is.list(final_state)) phase12_final_evaluation_preflight_fail("state", "final state must be a list")
  approval <- as.character(final_state$approval_state %||% "pending")
  if (length(approval) != 1L || !approval %in% c("pending", "approved")) phase12_final_evaluation_preflight_fail("approval_state", "approval state must be pending or approved")
  holdout <- as.character(final_state$holdout_state %||% "unopened")
  if (!identical(holdout, "unopened")) phase12_final_evaluation_preflight_fail("holdout_consumed", "holdout state is not unopened")
  markers <- c("labels_opened", "label_opened", "holdout_opened", "holdout_consumed", "final_labels_opened", "label_consumed", "labels_consumed", "consumed")
  for (field in intersect(markers, names(final_state))) {
    if (phase12_final_evaluation_flag(final_state[[field]], field)) phase12_final_evaluation_preflight_fail("holdout_consumed", paste("consumed marker is set:", field))
  }
  hash_markers <- intersect(c("label_sha256", "consumed_label_sha256", "final_label_sha256", "label_source_sha256", "consumed_label_hash"), names(final_state))
  if (length(hash_markers) && any(nzchar(vapply(final_state[hash_markers], function(x) if (length(x) && !is.na(x[[1L]])) as.character(x[[1L]]) else "", character(1))))) phase12_final_evaluation_preflight_fail("holdout_consumed", "label hash marker is present")
  if (!is.null(final_state$label_path) && !identical(gsub("\\\\", "/", as.character(final_state$label_path)), phase12_final_evaluation_allowlisted_label_path())) phase12_final_evaluation_preflight_fail("path", "label path is not the exact allowlisted seam")
  list(approval_state = approval, holdout_state = holdout)
}

#' Validate every label-free prerequisite before any provider can be invoked.
#' @export
phase12_preflight_final_evaluation <- function(
    freeze_manifest = "data/benchmark/phase12/freeze_manifest.csv",
    calibration_gate = "outputs/benchmarks/rolling_tournaments/phase12-calibration-release/calibration/calibration_gate.csv",
    final_state = NULL,
    protocol = "data/benchmark/phase09/promotion_protocol.json"
) {
  state <- phase12_final_evaluation_validate_unopened_state(final_state)
  freeze_value <- if (is.character(freeze_manifest)) phase12_final_evaluation_resolve_path(freeze_manifest) else freeze_manifest
  gate_value <- if (is.character(calibration_gate)) phase12_final_evaluation_resolve_path(calibration_gate) else calibration_gate
  protocol_value <- if (is.character(protocol)) phase12_final_evaluation_resolve_path(protocol) else protocol
  if (is.character(freeze_manifest)) {
    tryCatch(
      validate_phase12_freeze_manifest(freeze_value, project_root = phase12_final_evaluation_project_root()),
      error = function(error) phase12_final_evaluation_preflight_fail("freeze_drift", conditionMessage(error))
    )
  }
  freeze <- phase12_final_evaluation_read_table(freeze_value, "Phase 12 freeze manifest")
  required_freeze <- c("freeze_id", "freeze_self_sha256", "recipe_sha256", "promotion_protocol_sha256", "selected_g", "candidate_id", "code_frozen", "features_frozen", "settings_frozen", "panels_frozen", "seeds_frozen", "sealed_before_final_labels", "clean_worktree", "network_free", "wc2026_sealed", "phase12_decision_authority")
  missing <- setdiff(required_freeze, names(freeze))
  if (length(missing)) phase12_final_evaluation_preflight_fail("freeze_drift", paste("freeze missing", paste(missing, collapse = ", ")))
  if (nrow(freeze) != 9L || any(as.integer(freeze$selected_g) != 40L)) phase12_final_evaluation_preflight_fail("score_support", "freeze is not nine candidates at G=40")
  for (field in c("code_frozen", "features_frozen", "settings_frozen", "panels_frozen", "seeds_frozen", "sealed_before_final_labels", "clean_worktree", "network_free", "wc2026_sealed")) {
    if (any(!vapply(freeze[[field]], phase12_final_evaluation_flag, logical(1), name = field))) phase12_final_evaluation_preflight_fail("contract_flags", paste("freeze flag failed:", field))
  }
  if (any(vapply(freeze$phase12_decision_authority, phase12_final_evaluation_flag, logical(1), name = "phase12_decision_authority"))) phase12_final_evaluation_preflight_fail("candidate_activation", "Phase 11/12 authority flag is already active")
  protocol_object <- phase12_final_evaluation_protocol(protocol_value)
  if (!is.null(protocol_object$protocol_sha256) && !identical(as.character(freeze$promotion_protocol_sha256[[1L]]), as.character(protocol_object$protocol_sha256))) phase12_final_evaluation_preflight_fail("protocol_identity", "promotion protocol identity drifted")
  gate <- phase12_final_evaluation_read_table(gate_value, "Phase 12 calibration gate")
  phase12_final_evaluation_validate_gate(gate, freeze$candidate_id)
  if (is.character(gate_value)) {
    gate_hash <- phase12_final_evaluation_sha256(gate_value, file = TRUE)
  } else {
    gate_hash <- phase12_final_evaluation_sha256(paste(capture.output(utils::write.csv(gate, stdout(), row.names = FALSE)), collapse = "\n"))
  }
  final_fit_path <- "outputs/benchmarks/rolling_tournaments/phase12-calibration-release/final_evaluation/final_fit/final_fit_manifest.csv"
  final_fit_value <- phase12_final_evaluation_resolve_path(final_fit_path)
  if (!file.exists(final_fit_value)) phase12_final_evaluation_preflight_fail("final_fit_missing", "final-fit manifest is missing")
  tryCatch(
    validate_phase12_final_fit_manifest(final_fit_value, freeze_value, gate_value, project_root = phase12_final_evaluation_project_root()),
    error = function(error) phase12_final_evaluation_preflight_fail("final_fit_drift", conditionMessage(error))
  )
  final_fit_hash <- phase12_final_evaluation_sha256(final_fit_value, file = TRUE)
  result <- list(
    schema_version = "phase12-final-preflight-v1", preflight_status = "passed",
    approval_state = state$approval_state, holdout_state = "unopened", can_open = identical(state$approval_state, "approved"),
    freeze_id = as.character(freeze$freeze_id[[1L]]), freeze_self_sha256 = as.character(freeze$freeze_self_sha256[[1L]]),
    calibration_gate_sha256 = gate_hash, final_fit_manifest_sha256 = final_fit_hash,
    protocol_sha256 = as.character(freeze$promotion_protocol_sha256[[1L]]), score_support_g = 40L,
    candidate_count = 9L, active_candidate_id = phase12_final_fit_expected_active_id(),
    reason_codes = character(), label_source_path = phase12_final_evaluation_allowlisted_label_path(),
    labels_opened = FALSE
  )
  phase12_final_evaluation_state$preflight <- result
  phase12_final_evaluation_state$opened <- FALSE
  result
}

phase12_final_evaluation_normalize_provider_result <- function(value, expected_source_sha256) {
  source_sha256 <- NULL
  data <- value
  if (is.list(value) && !is.data.frame(value) && !is.null(value$data)) {
    data <- value$data
    source_sha256 <- value$source_sha256
  }
  if (!is.data.frame(data)) stop("Phase 12 final label provider must return a data frame", call. = FALSE)
  if (is.null(source_sha256)) source_sha256 <- attr(data, "phase12_source_sha256", exact = TRUE)
  if (is.null(source_sha256)) stop("Phase 12 synthetic label provider must declare source_sha256", call. = FALSE)
  if (!identical(tolower(as.character(source_sha256)), tolower(as.character(expected_source_sha256)))) stop("Phase 12 final label source checksum drifted", call. = FALSE)
  if (!"edition_id" %in% names(data) || any(tolower(as.character(data$edition_id)) != "wc2026")) stop("Phase 12 final label provider returned non-wc2026 rows", call. = FALSE)
  list(data = data, source_sha256 = as.character(source_sha256))
}

#' Sole allowlisted production label seam; Plan 12-05 owns the real invocation.
#' @export
phase12_open_final_labels <- function(label_path, expected_source_sha256, approval_state) {
  if (!identical(gsub("\\\\", "/", as.character(label_path)), phase12_final_evaluation_allowlisted_label_path())) stop("Phase 12 final label path is not the exact allowlisted source", call. = FALSE)
  if (length(expected_source_sha256) != 1L || !grepl("^[0-9a-fA-F]{64}$", as.character(expected_source_sha256))) stop("Phase 12 final label source SHA-256 is invalid", call. = FALSE)
  if (!identical(as.character(approval_state), "approved")) stop("Phase 12 final labels require explicit approved state", call. = FALSE)
  preflight <- phase12_final_evaluation_state$preflight
  if (is.null(preflight) || !identical(preflight$preflight_status, "passed") || !identical(preflight$holdout_state, "unopened")) stop("Phase 12 final labels require a passed unopened preflight", call. = FALSE)
  if (isTRUE(phase12_final_evaluation_state$opened)) stop("Phase 12 final labels may be opened only once", call. = FALSE)
  provider <- getOption("xgelo.phase12_final_label_provider", NULL)
  phase12_final_evaluation_state$provider_calls <- phase12_final_evaluation_state$provider_calls + 1L
  payload <- if (is.function(provider)) {
    provider(label_path)
  } else {
    utils::read.csv(label_path, stringsAsFactors = FALSE, check.names = FALSE)
  }
  normalized <- phase12_final_evaluation_normalize_provider_result(payload, expected_source_sha256)
  phase12_final_evaluation_state$opened <- TRUE
  list(
    schema_version = "phase12-final-label-provider-v1", label_path = label_path,
    source_sha256 = normalized$source_sha256, data = normalized$data,
    copied = FALSE, scoring_reporting_only = TRUE, opened_once = TRUE
  )
}

phase12_final_evaluation_provider_calls <- function() {
  phase12_final_evaluation_state$provider_calls
}

phase12_final_evaluation_artifact_paths <- function(
    output_dir = "outputs/benchmarks/rolling_tournaments/phase12-calibration-release"
) {
  output_dir <- phase12_final_evaluation_resolve_path(output_dir)
  c(
    labels = file.path(output_dir, "final_evaluation/labels.csv"),
    predictions = file.path(output_dir, "final_evaluation/predictions.csv"),
    scores = file.path(output_dir, "final_evaluation/scores.csv"),
    manifest = file.path(output_dir, "manifests/final_evaluation_manifest.csv")
  )
}

phase12_final_evaluation_write_once <- function(data, path, name) {
  if (file.exists(path)) stop(name, " is already published and immutable", call. = FALSE)
  if (!is.data.frame(data) || !nrow(data)) stop(name, " must contain rows", call. = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  staged <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
  on.exit(if (file.exists(staged)) unlink(staged), add = TRUE)
  utils::write.csv(data, staged, row.names = FALSE, na = "", quote = TRUE)
  if (!file.rename(staged, path)) stop("Could not publish immutable ", name, call. = FALSE)
  invisible(path)
}

phase12_final_evaluation_assert_label_free <- function(data, name) {
  if (!is.data.frame(data)) stop(name, " must be a data frame", call. = FALSE)
  outcome_columns <- benchmark_outcome_columns(data)
  if (length(outcome_columns)) {
    present <- vapply(outcome_columns, function(column) {
      values <- data[[column]]
      any(!is.na(values) & nzchar(as.character(values)))
    }, logical(1))
    if (any(present)) stop(name, " contains label-bearing outcome rows", call. = FALSE)
  }
  invisible(TRUE)
}

phase12_final_evaluation_prediction_bundle <- function(value) {
  if (!is.list(value) || is.data.frame(value)) {
    stop("Phase 12 prediction provider must return a list", call. = FALSE)
  }
  required <- c("predictions", "fixtures", "distributions")
  missing <- setdiff(required, names(value))
  if (length(missing)) stop("Phase 12 prediction provider is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  phase12_final_evaluation_assert_label_free(value$predictions, "Phase 12 predictions")
  phase12_final_evaluation_assert_label_free(value$fixtures, "Phase 12 fixture identities")
  phase12_final_evaluation_assert_label_free(value$distributions, "Phase 12 distributions")
  prediction_required <- c(
    "run_id", "model_id", "panel_id", "edition_id", "track_id", "fixture_id",
    "score_distribution_id", "p_home", "p_draw", "p_away", "p_over_2_5",
    "p_under_2_5", "p_btts", "prediction_status"
  )
  missing <- setdiff(prediction_required, names(value$predictions))
  if (length(missing)) stop("Phase 12 predictions are missing: ", paste(missing, collapse = ", "), call. = FALSE)
  fixture_required <- c("edition_id", "fixture_id", "score_eligible")
  missing <- setdiff(fixture_required, names(value$fixtures))
  if (length(missing)) stop("Phase 12 fixture identities are missing: ", paste(missing, collapse = ", "), call. = FALSE)
  if (anyDuplicated(value$fixtures$fixture_id) || anyDuplicated(value$predictions$fixture_id)) {
    stop("Phase 12 synthetic scoring inputs contain duplicate fixture IDs", call. = FALSE)
  }
  if (any(tolower(as.character(value$fixtures$edition_id)) != "wc2026")) {
    stop("Phase 12 final scoring fixtures must be wc2026 identities", call. = FALSE)
  }
  value
}

phase12_final_evaluation_merge_labels_for_scoring <- function(fixtures, labels) {
  required <- c("fixture_id", "edition_id", "regulation_home_goals", "regulation_away_goals")
  missing <- setdiff(required, names(labels))
  if (length(missing)) stop("Phase 12 final labels are missing: ", paste(missing, collapse = ", "), call. = FALSE)
  if (anyDuplicated(labels$fixture_id)) stop("Phase 12 final labels contain duplicate fixture IDs", call. = FALSE)
  index <- match(as.character(fixtures$fixture_id), as.character(labels$fixture_id))
  if (anyNA(index)) stop("Phase 12 final labels do not cover every declared fixture", call. = FALSE)
  if (any(as.character(fixtures$edition_id) != as.character(labels$edition_id[index]))) {
    stop("Phase 12 final label edition identity drifted", call. = FALSE)
  }
  result <- fixtures
  result$regulation_home_goals <- as.integer(labels$regulation_home_goals[index])
  result$regulation_away_goals <- as.integer(labels$regulation_away_goals[index])
  result
}

phase12_final_evaluation_candidate_registry <- function(
    final_fit_manifest = "outputs/benchmarks/rolling_tournaments/phase12-calibration-release/final_evaluation/final_fit/final_fit_manifest.csv"
) {
  rows <- phase12_final_evaluation_read_table(final_fit_manifest, "Phase 12 final-fit manifest")
  required <- c("candidate_id", "track_id", "admissible", "score_status", "primary_probability_view", "no_score_reason")
  missing <- setdiff(required, names(rows))
  if (length(missing)) stop("Phase 12 final-fit manifest is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  if (nrow(rows) != 9L || anyDuplicated(paste(rows$candidate_id, rows$track_id, sep = "\r"))) {
    stop("Phase 12 final-evaluation registry must contain nine unique candidate/track rows", call. = FALSE)
  }
  rows[order(as.character(rows$candidate_id), as.character(rows$track_id), method = "radix"), , drop = FALSE]
}

phase12_final_evaluation_registry_rows <- function(
    registry, predictions, scores, paths, preflight, label_source_sha256,
    label_sha256, promotion_decision_sha256 = "", run_timestamp
) {
  prediction_ids <- unique(as.character(predictions$model_id))
  score_rows <- scores[scores$target == "regulation_1x2" & scores$metric == "rps", , drop = FALSE]
  rows <- lapply(seq_len(nrow(registry)), function(index) {
    candidate <- as.character(registry$candidate_id[[index]])
    candidate_predictions <- predictions[as.character(predictions$model_id) == candidate, , drop = FALSE]
    candidate_scores <- score_rows[as.character(score_rows$model_id) == candidate, , drop = FALSE]
    active <- isTRUE(as.logical(registry$admissible[[index]]))
    expected <- if (active) length(registry$fixture_ids[[index]]) else 0L
    observed <- if (active) nrow(candidate_scores) else 0L
    data.frame(
      schema_version = "phase12-final-evaluation-manifest-v1",
      candidate_id = candidate, track_id = as.character(registry$track_id[[index]]),
      active_status = active, score_status = if (active) "scored" else "no_score",
      no_score_reason = if (active) "" else as.character(registry$no_score_reason[[index]]),
      primary_probability_view = as.character(registry$primary_probability_view[[index]]),
      expected_fixture_count = expected, observed_fixture_count = observed,
      coverage_numerator = observed, coverage_denominator = expected,
      coverage_complete = active && observed == expected,
      predictions_sha256 = if (active) phase12_final_evaluation_sha256(paths[["predictions"]], file = TRUE) else "",
      scores_sha256 = if (active) phase12_final_evaluation_sha256(paths[["scores"]], file = TRUE) else "",
      prediction_row_count = nrow(candidate_predictions), score_row_count = nrow(candidate_scores),
      freeze_id = as.character(preflight$freeze_id),
      freeze_self_sha256 = as.character(preflight$freeze_self_sha256),
      calibration_gate_sha256 = as.character(preflight$calibration_gate_sha256),
      final_fit_manifest_sha256 = as.character(preflight$final_fit_manifest_sha256),
      protocol_sha256 = as.character(preflight$protocol_sha256),
      label_source_sha256 = as.character(label_source_sha256), label_sha256 = as.character(label_sha256),
      promotion_decision_sha256 = as.character(promotion_decision_sha256),
      labels_consumed = TRUE, holdout_state = "consumed", run_timestamp = as.character(run_timestamp),
      stringsAsFactors = FALSE, check.names = FALSE
    )
  })
  do.call(rbind, rows)
}

run_phase12_final_evaluation_once <- function(
    expected_source_sha256,
    approval_state = "approved",
    label_path = phase12_final_evaluation_allowlisted_label_path(),
    label_provider = getOption("xgelo.phase12_final_label_provider", NULL),
    prediction_provider,
    output_dir = "outputs/benchmarks/rolling_tournaments/phase12-calibration-release",
    final_state = NULL,
    freeze_manifest = "data/benchmark/phase12/freeze_manifest.csv",
    calibration_gate = "outputs/benchmarks/rolling_tournaments/phase12-calibration-release/calibration/calibration_gate.csv",
    protocol = "data/benchmark/phase09/promotion_protocol.json",
    final_fit_manifest = "outputs/benchmarks/rolling_tournaments/phase12-calibration-release/final_evaluation/final_fit/final_fit_manifest.csv",
    promotion_candidates = NULL,
    promotion_report_path = NULL
) {
  if (!is.function(prediction_provider)) stop("Phase 12 final evaluation requires a label-free prediction provider", call. = FALSE)
  if (length(expected_source_sha256) != 1L || !grepl("^[0-9a-fA-F]{64}$", expected_source_sha256)) {
    stop("Phase 12 final evaluation expected source SHA-256 is invalid", call. = FALSE)
  }
  state <- final_state %||% list(approval_state = approval_state, holdout_state = "unopened")
  state$approval_state <- approval_state
  preflight <- phase12_preflight_final_evaluation(
    freeze_manifest = freeze_manifest, calibration_gate = calibration_gate,
    final_state = state, protocol = protocol
  )
  registry <- phase12_final_evaluation_candidate_registry(final_fit_manifest)
  prediction_input <- prediction_provider(registry[, c("candidate_id", "track_id", "admissible", "primary_probability_view"), drop = FALSE], preflight)
  bundle <- phase12_final_evaluation_prediction_bundle(prediction_input)
  old_provider <- getOption("xgelo.phase12_final_label_provider", NULL)
  options(xgelo.phase12_final_label_provider = label_provider)
  on.exit(options(xgelo.phase12_final_label_provider = old_provider), add = TRUE)
  opened <- phase12_open_final_labels(label_path, expected_source_sha256, approval_state)
  label_path_out <- phase12_final_evaluation_artifact_paths(output_dir)[["labels"]]
  phase12_final_evaluation_write_once(opened$data, label_path_out, "Phase 12 copied labels")
  label_sha256 <- phase12_final_evaluation_sha256(label_path_out, file = TRUE)
  scoring_fixtures <- phase12_final_evaluation_merge_labels_for_scoring(bundle$fixtures, opened$data)
  scores <- score_benchmark_fixtures(
    bundle$predictions, scoring_fixtures, bundle$distributions,
    as.character(bundle$fixtures$fixture_id)
  )
  paths <- phase12_final_evaluation_artifact_paths(output_dir)
  phase12_final_evaluation_write_once(bundle$predictions, paths[["predictions"]], "Phase 12 predictions")
  phase12_final_evaluation_write_once(scores, paths[["scores"]], "Phase 12 scores")
  promotion <- NULL
  if (!is.null(promotion_candidates)) {
    promotion_report_path <- promotion_report_path %||% file.path(dirname(paths[["manifest"]]), "promotion_report.csv")
    if (!exists("evaluate_phase12_candidates", mode = "function")) {
      source(phase12_final_evaluation_resolve_path("R/release/promotion_report.R"), local = .GlobalEnv)
    }
    promotion <- evaluate_phase12_candidates(promotion_candidates, protocol = protocol)
    promotion$report_path <- write_phase12_promotion_report(promotion, promotion_report_path)
  }
  decision_hash <- if (is.null(promotion)) "" else phase12_final_evaluation_sha256(promotion$report_path, file = TRUE)
  registry$fixture_ids <- rep(list(as.character(bundle$fixtures$fixture_id)), nrow(registry))
  rows <- phase12_final_evaluation_registry_rows(
    registry, bundle$predictions, scores, paths, preflight,
    expected_source_sha256, label_sha256, decision_hash,
    format(Sys.time(), tz = "UTC", usetz = TRUE)
  )
  manifest_path <- write_phase12_final_evaluation_manifest(rows, paths[["manifest"]])
  list(
    schema_version = "phase12-final-evaluation-v1", preflight = preflight,
    label_state = list(opened_once = opened$opened_once, copied = TRUE, scoring_reporting_only = TRUE,
                       source_sha256 = opened$source_sha256, label_sha256 = label_sha256),
    paths = c(paths, promotion_report = if (is.null(promotion)) "" else promotion$report_path),
    manifest_path = manifest_path, manifest_rows = rows, scores = scores,
    promotion = promotion, provider_calls = phase12_final_evaluation_provider_calls()
  )
}

write_phase12_final_evaluation_manifest <- function(rows, path = NULL) {
  if (is.list(rows) && !is.data.frame(rows)) {
    if (is.null(rows$manifest_rows)) stop("Phase 12 final-evaluation result has no manifest rows", call. = FALSE)
    if (is.null(path)) path <- rows$paths[["manifest"]]
    rows <- rows$manifest_rows
  }
  if (!is.data.frame(rows) || !nrow(rows)) stop("Phase 12 final-evaluation manifest rows must be non-empty", call. = FALSE)
  required <- c("candidate_id", "track_id", "score_status", "coverage_numerator", "coverage_denominator",
    "freeze_self_sha256", "calibration_gate_sha256", "final_fit_manifest_sha256", "protocol_sha256",
    "label_source_sha256", "label_sha256", "promotion_decision_sha256", "labels_consumed", "holdout_state")
  missing <- setdiff(required, names(rows))
  if (length(missing)) stop("Phase 12 final-evaluation manifest is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  if (nrow(rows) != 9L || anyDuplicated(paste(rows$candidate_id, rows$track_id, sep = "\r"))) {
    stop("Phase 12 final-evaluation manifest must retain nine unique candidate/track rows", call. = FALSE)
  }
  if (is.null(path) || !is.character(path) || length(path) != 1L || !nzchar(path)) stop("Phase 12 final-evaluation manifest path is required", call. = FALSE)
  path <- phase12_final_evaluation_resolve_path(path)
  phase12_final_evaluation_write_once(rows[order(rows$candidate_id, rows$track_id, method = "radix"), , drop = FALSE], path, "Phase 12 final-evaluation manifest")
  invisible(path)
}

validate_phase12_final_evaluation_manifest <- function(
    manifest = "outputs/benchmarks/rolling_tournaments/phase12-calibration-release/manifests/final_evaluation_manifest.csv"
) {
  path <- phase12_final_evaluation_resolve_path(manifest)
  if (!file.exists(path)) stop("Phase 12 final-evaluation manifest is missing", call. = FALSE)
  rows <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  required <- c("candidate_id", "track_id", "score_status", "coverage_numerator", "coverage_denominator",
    "freeze_self_sha256", "calibration_gate_sha256", "final_fit_manifest_sha256", "protocol_sha256",
    "label_source_sha256", "label_sha256", "promotion_decision_sha256", "labels_consumed", "holdout_state")
  missing <- setdiff(required, names(rows))
  if (length(missing)) stop("Phase 12 final-evaluation manifest is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  if (nrow(rows) != 9L || anyDuplicated(paste(rows$candidate_id, rows$track_id, sep = "\r"))) stop("Phase 12 final-evaluation manifest identity drifted", call. = FALSE)
  if (any(as.character(rows$holdout_state) != "consumed") || any(!as.logical(rows$labels_consumed))) stop("Phase 12 final-evaluation manifest is not consumed exactly once", call. = FALSE)
  if (any(!grepl("^[0-9a-fA-F]{64}$", rows$label_source_sha256)) || any(!grepl("^[0-9a-fA-F]{64}$", rows$label_sha256))) stop("Phase 12 final-evaluation label hashes are invalid", call. = FALSE)
  if (any(as.integer(rows$coverage_numerator) > as.integer(rows$coverage_denominator))) stop("Phase 12 final-evaluation coverage drifted", call. = FALSE)
  invisible(TRUE)
}
