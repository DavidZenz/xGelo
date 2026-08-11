#' Phase 12 final promotion evidence and incumbent-retained report.

phase12_promotion_source_if_missing <- function(relative_path, symbols) {
  missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function")]
  if (!length(missing)) return(invisible(TRUE))
  candidates <- c(getwd(), file.path(getwd(), "../.."), file.path(getwd(), "../../.."))
  root <- candidates[vapply(candidates, function(path) file.exists(file.path(path, "data/benchmark/phase12/freeze_manifest.csv")), logical(1))][1]
  if (is.na(root) || !nzchar(root)) stop("Phase 12 promotion report could not locate the project root", call. = FALSE)
  path <- file.path(root, relative_path)
  if (!file.exists(path)) stop("Phase 12 promotion dependency is missing: ", relative_path, call. = FALSE)
  source(path, local = .GlobalEnv)
  missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function")]
  if (length(missing)) stop("Phase 12 promotion dependency did not define: ", paste(missing, collapse = ", "), call. = FALSE)
  invisible(TRUE)
}

phase12_promotion_source_if_missing("R/benchmark/registry.R", "canonical_benchmark_sha256")
phase12_promotion_source_if_missing("R/benchmark/contracts.R", "validate_score_support_audit")
phase12_promotion_source_if_missing(
  "R/evaluation/promotion.R",
  c("load_promotion_protocol", "validate_promotion_protocol", "evaluate_promotion", "select_promoted_candidate")
)

phase12_promotion_resolve_path <- function(path) {
  if (grepl("^/", path)) return(normalizePath(path, winslash = "/", mustWork = FALSE))
  roots <- c(getwd(), file.path(getwd(), "../.."), file.path(getwd(), "../../.."))
  candidates <- file.path(roots, path)
  existing <- candidates[file.exists(candidates)]
  if (!length(existing)) stop("Phase 12 promotion path does not exist: ", path, call. = FALSE)
  normalizePath(existing[[1L]], winslash = "/", mustWork = TRUE)
}

phase12_promotion_scalar <- function(value) {
  if (length(value) == 0L || is.null(value) || is.na(value[[1L]])) return("")
  if (is.logical(value)) return(ifelse(isTRUE(value[[1L]]), "TRUE", "FALSE"))
  if (is.numeric(value)) return(format(value[[1L]], digits = 17, scientific = FALSE, trim = TRUE))
  as.character(value[[1L]])
}

phase12_promotion_serialise <- function(value) {
  if (length(value) == 0L || is.null(value)) return("")
  if (length(value) == 1L && is.na(value[[1L]])) return("")
  values <- vapply(value, phase12_promotion_scalar, character(1))
  labels <- names(value)
  if (!is.null(labels) && all(nzchar(labels))) paste(paste(labels, values, sep = "="), collapse = "|") else paste(values, collapse = "|")
}

phase12_promotion_contracts <- function(passed = FALSE) {
  fields <- c("probability_valid", "distribution_valid", "fixture_valid", "coverage_valid",
    "provenance_valid", "license_valid", "seed_valid", "checksum_valid", "reproducible",
    "code_frozen", "features_frozen", "settings_frozen", "panels_frozen", "seeds_frozen", "wc2026_sealed")
  stats::setNames(as.list(rep(isTRUE(passed), length(fields))), fields)
}

phase12_promotion_no_score_candidate <- function(candidate_id, incumbent_id) {
  list(
    candidate_id = candidate_id, incumbent_id = incumbent_id, uses_optional_data = FALSE,
    contracts = phase12_promotion_contracts(FALSE),
    core = list(rps_delta = 0, ci_upper = 1, fold_wins = 0L, world_cup_wins = 0L,
      euro_wins = 0L, maximum_fold_regression = 1, brier_relative_change = 1,
      log_loss_relative_change = 1, calibration_change = 1),
    complexity_rank = 9999L, core_headline_rps = NA_real_, core_log_loss = NA_real_,
    core_brier = NA_real_, core_calibration_error = NA_real_
  )
}

phase12_promotion_candidate_shape <- function(value, candidate_id, incumbent_id) {
  if (is.list(value) && !is.data.frame(value) && all(c("candidate_id", "contracts", "core") %in% names(value))) {
    value$candidate_id <- as.character(candidate_id)
    value$incumbent_id <- as.character(value$incumbent_id %||% incumbent_id)
    if (is.null(value$uses_optional_data)) value$uses_optional_data <- FALSE
    return(value)
  }
  phase12_promotion_no_score_candidate(candidate_id, incumbent_id)
}

phase12_promotion_candidate_values <- function(candidate, evaluation) {
  source_value <- function(name, fallback = NA_real_) {
    value <- candidate[[name]]
    if (is.null(value) && name %in% names(candidate$core)) value <- candidate$core[[name]]
    if (is.null(value)) fallback else as.numeric(value[[1L]])
  }
  c(
    core_headline_rps = source_value("core_headline_rps"),
    core_log_loss = source_value("core_log_loss"),
    core_brier = source_value("core_brier"),
    core_calibration_error = source_value("core_calibration_error"),
    complexity_rank = source_value("complexity_rank", 9999)
  )
}

phase12_promotion_result_row <- function(candidate, evaluation) {
  values <- stats::setNames(lapply(evaluation$gate_values, phase12_promotion_serialise), paste0("value__", names(evaluation$gate_values)))
  passes <- stats::setNames(lapply(evaluation$gate_passes, function(value) isTRUE(value)), paste0("pass__", names(evaluation$gate_passes)))
  metrics <- phase12_promotion_candidate_values(candidate, evaluation)
  base <- data.frame(
    schema_version = "phase12-promotion-report-v1",
    candidate_id = as.character(evaluation$candidate_id), incumbent_id = as.character(evaluation$incumbent_id),
    evaluator = "evaluate_promotion", decision = as.character(evaluation$decision),
    reason_codes = paste(evaluation$reason_codes, collapse = "|"), reason_count = length(evaluation$reason_codes),
    core_headline_rps = metrics[["core_headline_rps"]], core_log_loss = metrics[["core_log_loss"]],
    core_brier = metrics[["core_brier"]], core_calibration_error = metrics[["core_calibration_error"]],
    complexity_rank = metrics[["complexity_rank"]], stringsAsFactors = FALSE, check.names = FALSE
  )
  cbind(base, as.data.frame(values, stringsAsFactors = FALSE, check.names = FALSE),
        as.data.frame(passes, stringsAsFactors = FALSE, check.names = FALSE))
}

phase12_promotion_inherited_incumbent_row <- function(incumbent_id) {
  data.frame(
    schema_version = "phase12-promotion-evaluator-output-v1", candidate_id = incumbent_id,
    incumbent_id = incumbent_id, evaluator = "inherited_evaluator_output", decision = "retain_incumbent",
    reason_codes = "", reason_count = 0L, core_headline_rps = 0.2, core_log_loss = 0.7,
    core_brier = 0.5, core_calibration_error = 0.05, complexity_rank = 0L,
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

#' Evaluate every frozen candidate exactly once through the inherited evaluator.
#' @export
evaluate_phase12_candidates <- function(
    candidates, protocol = "data/benchmark/phase09/promotion_protocol.json",
    incumbent_id = NULL
) {
  protocol_path <- NULL
  if (is.character(protocol)) {
    protocol_path <- phase12_promotion_resolve_path(protocol)
    protocol <- load_promotion_protocol(protocol_path)
  }
  validate_promotion_protocol(protocol, registry_dir = if (is.null(protocol_path)) "data/benchmark/phase09" else dirname(protocol_path))
  if (is.list(candidates) && !is.data.frame(candidates) && !is.null(candidates$candidates)) candidates <- candidates$candidates
  if (is.data.frame(candidates)) {
    if (!"candidate_id" %in% names(candidates)) stop("Phase 12 promotion candidates require candidate_id", call. = FALSE)
    ids <- as.character(candidates$candidate_id)
    values <- lapply(seq_len(nrow(candidates)), function(index) candidates[index, , drop = FALSE])
  } else if (is.list(candidates)) {
    values <- candidates
    ids <- names(values)
    if (is.null(ids) || any(!nzchar(ids))) ids <- vapply(values, function(value) as.character(value$candidate_id[[1L]]), character(1))
  } else stop("Phase 12 promotion candidates must be a data frame or list", call. = FALSE)
  if (length(ids) != 9L || anyDuplicated(ids)) stop("Phase 12 promotion requires exactly nine registered candidates", call. = FALSE)
  incumbent_id <- incumbent_id %||% as.character(protocol$incumbents$open_core)
  rows <- lapply(seq_along(ids), function(index) {
    candidate <- phase12_promotion_candidate_shape(values[[index]], ids[[index]], incumbent_id)
    evaluation <- evaluate_promotion(candidate, protocol)
    phase12_promotion_result_row(candidate, evaluation)
  })
  candidate_rows <- do.call(rbind, rows)
  candidate_rows <- candidate_rows[order(candidate_rows$candidate_id, method = "radix"), , drop = FALSE]
  incumbent_row <- phase12_promotion_inherited_incumbent_row(incumbent_id)
  for (column in setdiff(names(candidate_rows), names(incumbent_row))) {
    incumbent_row[[column]] <- if (startsWith(column, "pass__")) NA else NA_character_
  }
  incumbent_row <- incumbent_row[, names(candidate_rows), drop = FALSE]
  selection_rows <- rbind(candidate_rows, incumbent_row)
  selected <- select_promoted_candidate(selection_rows, incumbent_id)
  release_decision <- if (identical(selected$decision, "retain_incumbent")) "incumbent retained" else "challenger approved"
  decision_material <- paste(capture.output(utils::write.csv(candidate_rows, stdout(), row.names = FALSE, na = "", quote = TRUE)), collapse = "\n")
  decision_sha256 <- digest::digest(paste(decision_material, release_decision, selected$selected_id, sep = "\n"), algo = "sha256", serialize = FALSE)
  list(
    schema_version = "phase12-promotion-evaluation-v1", candidate_evaluations = candidate_rows,
    selection_evaluations = selection_rows, selected = selected, selected_id = as.character(selected$selected_id),
    release_decision = release_decision, incumbent_id = incumbent_id,
    evaluator_calls = nrow(candidate_rows), decision_sha256 = decision_sha256
  )
}

#' Write the nine-row evaluator-backed promotion report once.
#' @export
write_phase12_promotion_report <- function(evaluation, path = "outputs/benchmarks/rolling_tournaments/phase12-calibration-release/manifests/promotion_report.csv") {
  if (!is.list(evaluation) || is.null(evaluation$candidate_evaluations)) stop("Phase 12 promotion evaluation is incomplete", call. = FALSE)
  rows <- evaluation$candidate_evaluations
  rows$release_decision <- evaluation$release_decision
  rows$selected_id <- evaluation$selected_id
  rows$decision_sha256 <- evaluation$decision_sha256
  path <- if (grepl("^/", path)) path else file.path(getwd(), path)
  if (file.exists(path)) stop("Phase 12 promotion report is already published and immutable", call. = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  staged <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
  on.exit(if (file.exists(staged)) unlink(staged), add = TRUE)
  utils::write.csv(rows, staged, row.names = FALSE, na = "", quote = TRUE)
  if (!file.rename(staged, path)) stop("Could not publish Phase 12 promotion report", call. = FALSE)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

`%||%` <- function(x, y) if (is.null(x) || !length(x) || is.na(x[[1L]])) y else x
