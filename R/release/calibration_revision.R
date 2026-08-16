#' Phase 14 chronology-safe calibration revision for the retained incumbent.
#'
#' This module is deliberately development-only. It never resolves final
#' evaluation labels and it owns no release selector or competition registry
#' mutation path.

phase14_calibration_revision_project_root <- function() {
  candidates <- c(getwd(), file.path(getwd(), "../.."), file.path(getwd(), "../../.."))
  for (candidate in candidates) {
    if (file.exists(file.path(candidate, "data/benchmark/phase09/fixtures.csv"))) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }
  stop("Phase 14 calibration revision could not locate the project root", call. = FALSE)
}

phase14_calibration_revision_resolve_path <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    stop("Phase 14 calibration path must be one non-empty value", call. = FALSE)
  }
  if (grepl("^/", path)) path else file.path(phase14_calibration_revision_project_root(), path)
}

phase14_calibration_revision_source_if_missing <- function(relative_path, symbols) {
  missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function")]
  if (!length(missing)) return(invisible(TRUE))
  path <- phase14_calibration_revision_resolve_path(relative_path)
  if (!file.exists(path)) {
    stop("Phase 14 calibration dependency is missing: ", relative_path, call. = FALSE)
  }
  source(path, local = .GlobalEnv)
  missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop(
      "Phase 14 calibration dependency did not define: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

phase14_calibration_revision_source_if_missing(
  "R/calibration/probability_calibration.R",
  c(
    "fit_phase12_1x2_calibrator",
    "phase12_apply_vector",
    "phase12_inner_oof_prediction_hash",
    "validate_phase12_calibrator"
  )
)
phase14_calibration_revision_source_if_missing(
  "R/calibration/calibration_selection.R",
  c("phase12_selection_freeze")
)

phase14_calibration_revision_file_sha256 <- function(path) {
  path <- phase14_calibration_revision_resolve_path(path)
  if (!file.exists(path) || dir.exists(path)) {
    stop("Phase 14 calibration hash input is missing: ", path, call. = FALSE)
  }
  digest::digest(file = path, algo = "sha256", serialize = FALSE)
}

phase14_calibration_revision_table_sha256 <- function(data, order_by = character()) {
  if (!is.data.frame(data)) stop("Phase 14 calibration hash input must be a data frame", call. = FALSE)
  if (length(order_by)) {
    missing <- setdiff(order_by, names(data))
    if (length(missing)) stop("Phase 14 calibration hash ordering column is missing", call. = FALSE)
    ordering <- do.call(order, c(lapply(data[order_by], as.character), list(method = "radix")))
    data <- data[ordering, , drop = FALSE]
  }
  values <- lapply(data, function(value) {
    if (inherits(value, "Date")) value <- format(value, "%Y-%m-%d")
    if (inherits(value, "POSIXt")) value <- format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    value <- as.character(value)
    value[is.na(value)] <- "<NA>"
    value
  })
  rows <- if (nrow(data)) {
    vapply(
      seq_len(nrow(data)),
      function(i) paste(vapply(values, `[[`, character(1), i), collapse = "\u001f"),
      character(1)
    )
  } else character()
  digest::digest(
    paste(c(names(data), rows), collapse = "\u001e"),
    algo = "sha256",
    serialize = FALSE
  )
}

phase14_calibration_revision_assert_label_safe_path <- function(path, name) {
  if (!is.character(path)) return(invisible(TRUE))
  lowered <- tolower(gsub("\\\\", "/", path))
  if (grepl("wc2026|final_evaluation|(^|/)labels\\.csv$", lowered, perl = TRUE)) {
    stop(
      "Phase 14 calibration rejects WC2026 and final-label lineage in ", name,
      call. = FALSE
    )
  }
  invisible(TRUE)
}

phase14_calibration_revision_read_table <- function(value, name) {
  if (is.data.frame(value)) return(value)
  phase14_calibration_revision_assert_label_safe_path(value, name)
  path <- phase14_calibration_revision_resolve_path(value)
  if (!file.exists(path)) stop("Phase 14 ", name, " input is missing", call. = FALSE)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

phase14_calibration_revision_require_columns <- function(data, required, name) {
  if (!is.data.frame(data)) stop(name, " must be a data frame", call. = FALSE)
  missing <- setdiff(required, names(data))
  if (length(missing)) {
    stop(name, " missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

phase14_calibration_revision_has_holdout_identity <- function(data) {
  columns <- intersect(c("edition_id", "fixture_id", "source_match_id"), names(data))
  if (!length(columns) || !nrow(data)) return(FALSE)
  any(vapply(columns, function(column) {
    any(grepl("wc2026", tolower(as.character(data[[column]])), fixed = TRUE))
  }, logical(1)))
}

phase14_calibration_revision_observed_class <- function(home_goals, away_goals) {
  ifelse(home_goals > away_goals, "home", ifelse(home_goals < away_goals, "away", "draw"))
}

#' Build the exact development-only retained-incumbent calibration panel.
#' @export
phase14_build_incumbent_development_panel <- function(
    predictions = "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/predictions/fixture_predictions.csv",
    fixtures = "data/benchmark/phase09/fixtures.csv"
) {
  phase14_calibration_revision_assert_label_safe_path(predictions, "prediction")
  phase14_calibration_revision_assert_label_safe_path(fixtures, "fixture")
  prediction_rows <- phase14_calibration_revision_read_table(predictions, "prediction")
  fixture_rows <- phase14_calibration_revision_read_table(fixtures, "fixture")
  prediction_required <- c(
    "run_id", "model_id", "panel_id", "edition_id", "track_id", "fixture_id",
    "boundary_id", "evidence_cutoff_exclusive", "score_distribution_id",
    "p_home", "p_draw", "p_away", "p_over_2_5", "p_under_2_5", "p_btts",
    "prediction_status"
  )
  fixture_required <- c(
    "edition_id", "fixture_id", "scheduled_date", "actual_completion_date",
    "regulation_home_goals", "regulation_away_goals", "score_eligible", "row_sha256"
  )
  phase14_calibration_revision_require_columns(
    prediction_rows, prediction_required, "Phase 14 source predictions"
  )
  phase14_calibration_revision_require_columns(
    fixture_rows, fixture_required, "Phase 14 fixtures"
  )
  if (phase14_calibration_revision_has_holdout_identity(prediction_rows) ||
      phase14_calibration_revision_has_holdout_identity(fixture_rows)) {
    stop("Phase 14 calibration rejects WC2026 holdout identities", call. = FALSE)
  }

  incumbent <- prediction_rows[
    as.character(prediction_rows$model_id) == "open_nb_incumbent",
    ,
    drop = FALSE
  ]
  if (nrow(incumbent) != 1260L) {
    stop("Phase 14 calibration requires exactly 1,260 open_nb_incumbent source rows", call. = FALSE)
  }
  selected <- incumbent[
    as.character(incumbent$track_id) == "updating" &
      as.character(incumbent$panel_id) == "open_core",
    ,
    drop = FALSE
  ]
  if (nrow(selected) != 630L) {
    stop("Phase 14 calibration requires exactly 630 updating/open_core rows", call. = FALSE)
  }
  if (anyNA(selected$fixture_id) || any(!nzchar(as.character(selected$fixture_id))) ||
      anyDuplicated(as.character(selected$fixture_id))) {
    stop("Phase 14 calibration requires 630 unique fixture IDs", call. = FALSE)
  }
  if (any(is.na(selected$prediction_status) | selected$prediction_status != "ok")) {
    stop("Phase 14 calibration requires complete incumbent predictions", call. = FALSE)
  }
  probabilities <- as.matrix(selected[, c("p_home", "p_draw", "p_away")])
  storage.mode(probabilities) <- "double"
  if (anyNA(probabilities) || any(!is.finite(probabilities)) ||
      any(probabilities < 0 | probabilities > 1) ||
      any(abs(rowSums(probabilities) - 1) > 1e-10)) {
    stop("Phase 14 calibration source probabilities are invalid", call. = FALSE)
  }

  if (nrow(fixture_rows) != 630L || anyDuplicated(as.character(fixture_rows$fixture_id)) ||
      !setequal(as.character(selected$fixture_id), as.character(fixture_rows$fixture_id))) {
    stop("Phase 14 calibration fixtures must match the exact 630 prediction IDs", call. = FALSE)
  }
  fixture_index <- match(as.character(selected$fixture_id), as.character(fixture_rows$fixture_id))
  matched_fixtures <- fixture_rows[fixture_index, , drop = FALSE]
  if (any(as.character(selected$edition_id) != as.character(matched_fixtures$edition_id)) ||
      any(is.na(matched_fixtures$score_eligible) | !matched_fixtures$score_eligible)) {
    stop("Phase 14 calibration fixture edition or score eligibility is invalid", call. = FALSE)
  }
  scheduled_date <- as.Date(matched_fixtures$scheduled_date)
  completion_date <- as.Date(matched_fixtures$actual_completion_date)
  if (anyNA(scheduled_date) || anyNA(completion_date)) {
    stop("Phase 14 calibration fixtures require complete chronology", call. = FALSE)
  }

  panel <- selected
  panel$scheduled_date <- scheduled_date
  panel$actual_completion_date <- completion_date
  panel$regulation_home_goals <- as.integer(matched_fixtures$regulation_home_goals)
  panel$regulation_away_goals <- as.integer(matched_fixtures$regulation_away_goals)
  panel$observed_class <- phase14_calibration_revision_observed_class(
    panel$regulation_home_goals, panel$regulation_away_goals
  )
  panel$fixture_row_sha256 <- as.character(matched_fixtures$row_sha256)
  source_columns <- names(selected)
  panel$source_prediction_row_sha256 <- vapply(seq_len(nrow(selected)), function(i) {
    phase12_inner_oof_prediction_hash(selected[i, source_columns, drop = FALSE], source_columns)
  }, character(1))
  edition_open <- tapply(panel$scheduled_date, panel$edition_id, min)
  edition_order <- names(sort(as.Date(edition_open, origin = "1970-01-01"), method = "radix"))
  if (length(edition_order) != 12L || anyDuplicated(edition_order)) {
    stop("Phase 14 calibration requires exactly 12 registered development editions", call. = FALSE)
  }
  panel$edition_open_date <- as.Date(edition_open[as.character(panel$edition_id)], origin = "1970-01-01")
  panel$edition_sequence <- match(as.character(panel$edition_id), edition_order)
  panel <- panel[order(panel$edition_sequence, panel$scheduled_date, panel$fixture_id, method = "radix"), , drop = FALSE]
  rownames(panel) <- NULL
  attr(panel, "source_predictions_sha256") <- phase14_calibration_revision_table_sha256(
    selected, c("edition_id", "fixture_id")
  )
  attr(panel, "fixtures_sha256") <- phase14_calibration_revision_table_sha256(
    matched_fixtures, c("edition_id", "fixture_id")
  )
  attr(panel, "edition_order") <- edition_order
  panel
}

phase14_calibration_revision_model_identity <- function(
    model_path = "outputs/releases/phase12-wc2026-incumbent-retained-v1/model/approved_model.rds"
) {
  resolved <- phase14_calibration_revision_resolve_path(model_path)
  model <- readRDS(resolved)
  if (!is.list(model) || !identical(as.character(model$model_id), "open_nb_incumbent") ||
      !length(model$training_dates)) {
    stop("Phase 14 calibration incumbent model identity is invalid", call. = FALSE)
  }
  list(
    model_sha256 = phase14_calibration_revision_file_sha256(resolved),
    model_data_cutoff = format(max(as.Date(model$training_dates)), "%Y-%m-%d")
  )
}

phase14_calibration_revision_git_commit <- function() {
  commit <- tryCatch(
    system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE),
    error = function(error) character()
  )
  commit <- if (length(commit)) trimws(commit[[1L]]) else ""
  if (!grepl("^[0-9a-f]{40}$", commit)) {
    stop("Phase 14 calibration requires an exact Git commit identity", call. = FALSE)
  }
  commit
}

phase14_calibration_revision_inner_oof <- function(training, outer_edition_id, cutoff) {
  if (!nrow(training)) {
    result <- data.frame(
      candidate_id = character(), track_id = character(), outer_edition_id = character(),
      inner_edition_id = character(), fixture_id = character(), boundary_id = character(),
      evidence_cutoff_exclusive = as.Date(character()), observed_class = character(),
      p_home_raw = numeric(), p_draw_raw = numeric(), p_away_raw = numeric(),
      source_prediction_sha256 = character(), max_evidence_date = as.Date(character()),
      stringsAsFactors = FALSE
    )
    return(result)
  }
  data.frame(
    candidate_id = "open_nb_incumbent",
    track_id = "updating",
    outer_edition_id = as.character(outer_edition_id),
    inner_edition_id = as.character(training$edition_id),
    fixture_id = as.character(training$fixture_id),
    boundary_id = as.character(training$boundary_id),
    evidence_cutoff_exclusive = rep(as.Date(cutoff), nrow(training)),
    observed_class = as.character(training$observed_class),
    p_home_raw = as.numeric(training$p_home),
    p_draw_raw = as.numeric(training$p_draw),
    p_away_raw = as.numeric(training$p_away),
    source_prediction_sha256 = as.character(training$source_prediction_row_sha256),
    max_evidence_date = as.Date(training$actual_completion_date),
    stringsAsFactors = FALSE
  )
}

phase14_calibration_revision_write_predictions <- function(data, path) {
  persisted <- data
  for (column in intersect(
    c("scheduled_date", "actual_completion_date", "edition_open_date"),
    names(persisted)
  )) {
    persisted[[column]] <- format(as.Date(persisted[[column]]), "%Y-%m-%d")
  }
  utils::write.csv(persisted, path, row.names = FALSE, na = "", quote = TRUE)
  invisible(path)
}

#' Fit strictly-prior rolling calibrators and the final development calibrator.
#' @export
phase14_fit_rolling_incumbent_calibration <- function(
    panel = phase14_build_incumbent_development_panel(),
    output_root = "outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-revision",
    freeze_manifest = "data/benchmark/phase12/freeze_manifest.csv",
    protocol_path = "data/benchmark/phase09/promotion_protocol.json",
    model_path = "outputs/releases/phase12-wc2026-incumbent-retained-v1/model/approved_model.rds"
) {
  phase14_calibration_revision_require_columns(
    panel,
    c(
      "model_id", "track_id", "panel_id", "edition_id", "fixture_id", "boundary_id",
      "scheduled_date", "actual_completion_date", "edition_open_date", "observed_class",
      "p_home", "p_draw", "p_away", "score_distribution_id",
      "source_prediction_row_sha256", "fixture_row_sha256"
    ),
    "Phase 14 calibration panel"
  )
  if (nrow(panel) != 630L || anyDuplicated(as.character(panel$fixture_id)) ||
      any(as.character(panel$model_id) != "open_nb_incumbent") ||
      any(as.character(panel$track_id) != "updating") ||
      any(as.character(panel$panel_id) != "open_core") ||
      phase14_calibration_revision_has_holdout_identity(panel)) {
    stop("Phase 14 rolling calibration requires the exact label-safe 630-row panel", call. = FALSE)
  }
  panel$scheduled_date <- as.Date(panel$scheduled_date)
  panel$actual_completion_date <- as.Date(panel$actual_completion_date)
  panel$edition_open_date <- as.Date(panel$edition_open_date)
  edition_open <- tapply(panel$edition_open_date, panel$edition_id, min)
  editions <- names(sort(as.Date(edition_open, origin = "1970-01-01"), method = "radix"))
  if (length(editions) != 12L) {
    stop("Phase 14 rolling calibration requires 12 chronological editions", call. = FALSE)
  }
  boundaries <- data.frame(
    edition_id = editions,
    assessment_date = as.Date(edition_open[editions], origin = "1970-01-01"),
    stringsAsFactors = FALSE
  )
  freeze <- phase12_selection_freeze(freeze_manifest)
  model_identity <- phase14_calibration_revision_model_identity(model_path)
  source_predictions_sha256 <- phase14_calibration_revision_table_sha256(
    panel[, setdiff(names(panel), c("edition_open_date", "edition_sequence")), drop = FALSE],
    c("edition_id", "fixture_id")
  )
  fixtures_sha256 <- phase14_calibration_revision_table_sha256(
    panel[, c(
      "edition_id", "fixture_id", "scheduled_date", "actual_completion_date",
      "regulation_home_goals", "regulation_away_goals", "fixture_row_sha256"
    ), drop = FALSE],
    c("edition_id", "fixture_id")
  )
  calibrated_parts <- vector("list", length(editions))
  rolling_calibrators <- vector("list", length(editions))
  names(rolling_calibrators) <- editions
  for (edition_index in seq_along(editions)) {
    outer <- editions[[edition_index]]
    outer_open <- as.Date(edition_open[[outer]], origin = "1970-01-01")
    prior <- if (edition_index == 1L) character() else editions[seq_len(edition_index - 1L)]
    training <- panel[as.character(panel$edition_id) %in% prior, , drop = FALSE]
    if (nrow(training) && any(as.Date(training$actual_completion_date) >= outer_open)) {
      stop("Phase 14 rolling calibration evidence must strictly precede the outer edition", call. = FALSE)
    }
    inner_oof <- phase14_calibration_revision_inner_oof(training, outer, outer_open - 1L)
    calibrator <- fit_phase12_1x2_calibrator(
      inner_oof = inner_oof,
      candidate_id = "open_nb_incumbent",
      track_id = "updating",
      outer_edition_id = outer,
      freeze_manifest = freeze,
      boundaries = boundaries
    )
    validate_phase12_calibrator(calibrator, freeze_manifest = freeze)
    assessment <- panel[as.character(panel$edition_id) == outer, , drop = FALSE]
    calibrated <- t(vapply(seq_len(nrow(assessment)), function(i) {
      unname(phase12_apply_vector(
        calibrator,
        setNames(
          as.numeric(assessment[i, c("p_home", "p_draw", "p_away")]),
          c("home", "draw", "away")
        )
      ))
    }, numeric(3)))
    assessment$p_home_calibrated <- calibrated[, 1L]
    assessment$p_draw_calibrated <- calibrated[, 2L]
    assessment$p_away_calibrated <- calibrated[, 3L]
    assessment$calibration_fit_status <- as.character(calibrator$fit_status)
    assessment$rolling_probability_view <- if (
      identical(as.character(calibrator$fit_status), "fitted")
    ) "calibrated_1x2" else "raw_1x2"
    assessment$calibration_training_row_count <- nrow(training)
    assessment$calibration_training_editions <- paste(prior, collapse = "|")
    assessment$calibration_max_evidence_date <- if (nrow(training)) {
      format(max(as.Date(training$actual_completion_date)), "%Y-%m-%d")
    } else ""
    assessment$calibration_outer_edition_id <- outer
    assessment$calibration_temperature <- as.numeric(calibrator$temperature)
    calibrated_parts[[edition_index]] <- assessment
    rolling_calibrators[[edition_index]] <- calibrator
  }
  calibrated_predictions <- do.call(rbind, calibrated_parts)
  calibrated_predictions <- calibrated_predictions[
    order(
      calibrated_predictions$edition_sequence,
      calibrated_predictions$scheduled_date,
      calibrated_predictions$fixture_id,
      method = "radix"
    ),
    ,
    drop = FALSE
  ]
  rownames(calibrated_predictions) <- NULL

  final_cutoff <- as.Date(model_identity$model_data_cutoff)
  if (any(as.Date(panel$actual_completion_date) >= final_cutoff)) {
    stop("Phase 14 final calibration evidence must precede the model data cutoff", call. = FALSE)
  }
  final_outer <- "phase14_development_2026"
  final_boundaries <- rbind(
    boundaries,
    data.frame(
      edition_id = final_outer,
      assessment_date = final_cutoff + 1L,
      stringsAsFactors = FALSE
    )
  )
  final_inner_oof <- phase14_calibration_revision_inner_oof(panel, final_outer, final_cutoff)
  final_calibrator <- fit_phase12_1x2_calibrator(
    inner_oof = final_inner_oof,
    candidate_id = "open_nb_incumbent",
    track_id = "updating",
    outer_edition_id = final_outer,
    freeze_manifest = freeze,
    boundaries = final_boundaries
  )
  validate_phase12_calibrator(final_calibrator, freeze_manifest = freeze)
  final_calibrator$phase14_schema_version <- "phase14-incumbent-calibrator-v1"
  final_calibrator$model_id <- "open_nb_incumbent"
  final_calibrator$panel_id <- "open_core"
  final_calibrator$development_row_count <- nrow(panel)
  final_calibrator$development_fixture_count <- length(unique(panel$fixture_id))
  final_calibrator$development_editions <- editions
  final_calibrator$model_sha256 <- model_identity$model_sha256
  final_calibrator$model_data_cutoff <- model_identity$model_data_cutoff
  final_calibrator$calibration_evidence_cutoff <- format(
    max(as.Date(panel$actual_completion_date)), "%Y-%m-%d"
  )
  final_calibrator$source_predictions_sha256 <- source_predictions_sha256
  final_calibrator$fixtures_sha256 <- fixtures_sha256
  final_calibrator$protocol_sha256 <- phase14_calibration_revision_file_sha256(protocol_path)
  final_calibrator$code_commit <- phase14_calibration_revision_git_commit()
  final_calibrator$code_sha256 <- phase14_calibration_revision_file_sha256(
    "R/release/calibration_revision.R"
  )
  final_calibrator$rolling_evaluation_complete <- TRUE
  final_calibrator$holdout_labels_used <- FALSE

  output_root <- phase14_calibration_revision_resolve_path(output_root)
  dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
  calibrator_path <- file.path(output_root, "calibrator.rds")
  predictions_path <- file.path(output_root, "calibrated_predictions.csv")
  saveRDS(final_calibrator, calibrator_path, version = 3L, compress = "xz")
  phase14_calibration_revision_write_predictions(calibrated_predictions, predictions_path)
  list(
    calibrator = final_calibrator,
    rolling_calibrators = rolling_calibrators,
    calibrated_predictions = calibrated_predictions,
    panel = panel,
    calibrator_path = calibrator_path,
    calibrated_predictions_path = predictions_path
  )
}
