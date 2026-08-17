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
phase14_calibration_revision_source_if_missing(
  "R/release/release_contract.R",
  c(
    "phase12_release_contract_assert_selected_topology",
    "phase12_release_file_sha256",
    "phase12_release_path_under_root",
    "phase12_release_safe_relative_path",
    "phase12_release_trusted_root",
    "phase14_release_selector_hash",
    "preflight_phase12_approved_release"
  )
)
phase14_calibration_revision_source_if_missing(
  "R/competition/edition_registry.R",
  c(
    "phase13_competition_edition_ids",
    "phase13_registry_row_hash",
    "phase14_repin_both_competition_releases",
    "phase14_validate_dual_repin_candidate"
  )
)

phase14_release_selector_schema <- function() {
  c(
    "release_id", "release_manifest_path", "manifest_sha256",
    "approved_at_utc", "row_sha256"
  )
}

phase14_release_selector_allowed_release_ids <- function() {
  "phase14-open-nb-incumbent-calibrated-v1"
}

phase14_release_selector_validate_approved_at <- function(approved_at_utc) {
  value <- as.character(approved_at_utc)
  if (length(value) != 1L || is.na(value) ||
      !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", value)) {
    stop("Phase 14 selector approved_at_utc must be one canonical UTC timestamp", call. = FALSE)
  }
  parsed <- suppressWarnings(as.POSIXct(
    value,
    format = "%Y-%m-%dT%H:%M:%SZ",
    tz = "UTC"
  ))
  if (is.na(parsed) || !identical(format(parsed, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), value)) {
    stop("Phase 14 selector approved_at_utc is not a valid UTC timestamp", call. = FALSE)
  }
  value
}

phase14_release_selector_validate_release_id <- function(release_id) {
  value <- as.character(release_id)
  if (length(value) != 1L || is.na(value) || !nzchar(value) ||
      grepl("[/\\\\]", value) || grepl("(^|/)\\.\\.?(/|$)", value)) {
    stop("Phase 14 selector release identity is unsafe", call. = FALSE)
  }
  if (!value %in% phase14_release_selector_allowed_release_ids()) {
    stop("Phase 14 selector release identity is not in the explicit allowlist", call. = FALSE)
  }
  value
}

phase14_release_selector_manifest_path <- function(
    release_id, release_manifest_path, trusted_root
) {
  release_id <- phase14_release_selector_validate_release_id(release_id)
  relative_manifest <- phase12_release_safe_relative_path(release_manifest_path)
  expected_manifest <- paste0(release_id, "/release_manifest.csv")
  if (!identical(relative_manifest, expected_manifest)) {
    stop("Phase 14 selector manifest topology disagrees with release identity", call. = FALSE)
  }
  trusted_root <- phase12_release_trusted_root(trusted_root)
  manifest_path <- phase12_release_path_under_root(
    trusted_root,
    relative_manifest,
    must_work = TRUE
  )
  topology <- phase12_release_contract_assert_selected_topology(
    trusted_root,
    manifest_path
  )
  list(
    trusted_root = trusted_root,
    relative_manifest = relative_manifest,
    manifest_path = topology$manifest_path,
    release_dir = topology$release_dir
  )
}

#' Build one explicit non-authoritative approved-release selector row.
#' @export
phase14_build_release_selector_row <- function(
    release_id,
    release_manifest_path,
    approved_at_utc,
    trusted_root = "outputs/releases"
) {
  selected <- phase14_release_selector_manifest_path(
    release_id,
    release_manifest_path,
    trusted_root
  )
  selector <- data.frame(
    release_id = phase14_release_selector_validate_release_id(release_id),
    release_manifest_path = selected$relative_manifest,
    manifest_sha256 = phase12_release_file_sha256(selected$manifest_path),
    approved_at_utc = phase14_release_selector_validate_approved_at(approved_at_utc),
    row_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  selector$row_sha256 <- phase14_release_selector_hash(selector)
  phase14_validate_release_selector(selector, trusted_root = selected$trusted_root)
  selector
}

#' Validate one selector candidate without granting runtime authority.
#' @export
phase14_validate_release_selector <- function(
    selector,
    trusted_root = "outputs/releases"
) {
  expected_schema <- phase14_release_selector_schema()
  if (!is.data.frame(selector) || nrow(selector) != 1L ||
      !identical(names(selector), expected_schema)) {
    stop("Phase 14 selector candidate must contain one exact row", call. = FALSE)
  }
  values <- vapply(selector[1L, expected_schema, drop = FALSE], as.character, character(1))
  if (anyNA(values) || any(!nzchar(values))) {
    stop("Phase 14 selector candidate contains an empty identity", call. = FALSE)
  }
  if (!grepl("^[0-9a-fA-F]{64}$", values[["manifest_sha256"]]) ||
      !grepl("^[0-9a-fA-F]{64}$", values[["row_sha256"]])) {
    stop("Phase 14 selector candidate hash identity is invalid", call. = FALSE)
  }
  expected_self_hash <- phase14_release_selector_hash(selector)
  if (!identical(tolower(values[["row_sha256"]]), expected_self_hash)) {
    stop("Phase 14 selector candidate self-hash mismatch", call. = FALSE)
  }

  release_id <- phase14_release_selector_validate_release_id(values[["release_id"]])
  phase14_release_selector_validate_approved_at(values[["approved_at_utc"]])
  selected <- phase14_release_selector_manifest_path(
    release_id,
    values[["release_manifest_path"]],
    trusted_root
  )
  manifest_sha256 <- phase12_release_file_sha256(selected$manifest_path)
  if (!identical(manifest_sha256, tolower(values[["manifest_sha256"]]))) {
    stop("Phase 14 selector candidate manifest hash mismatch", call. = FALSE)
  }

  preflight <- preflight_phase12_approved_release(
    trusted_root = selected$trusted_root,
    release_manifest_path = selected$manifest_path
  )
  if (!identical(as.character(preflight$release_id), release_id) ||
      !identical(basename(preflight$release_root), release_id) ||
      !identical(as.character(preflight$metadata$primary_probability_view), "calibrated_1x2") ||
      !identical(as.character(preflight$model_contract$calibrator_fit_status), "fitted") ||
      !isTRUE(preflight$model_contract$calibration_gate_passed)) {
    stop("Phase 14 selector candidate release authority is invalid", call. = FALSE)
  }
  invisible(TRUE)
}

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
  panel$score_eligible <- as.logical(matched_fixtures$score_eligible)
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
      "regulation_home_goals", "regulation_away_goals", "score_eligible",
      "fixture_row_sha256"
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

phase14_calibration_revision_output_paths <- function(output_root) {
  root <- phase14_calibration_revision_resolve_path(output_root)
  c(
    calibrator = file.path(root, "calibrator.rds"),
    calibrated_predictions = file.path(root, "calibrated_predictions.csv"),
    calibration_gate = file.path(root, "calibration_gate.csv"),
    revision_manifest = file.path(root, "calibration_revision_manifest.csv")
  )
}

phase14_calibration_revision_score_view <- function(predictions, fixtures, model_id) {
  fixture_index <- match(as.character(predictions$fixture_id), as.character(fixtures$fixture_id))
  if (anyNA(fixture_index)) stop("Phase 14 calibration scoring fixtures are incomplete", call. = FALSE)
  output <- lapply(seq_len(nrow(predictions)), function(i) {
    prediction <- predictions[i, , drop = FALSE]
    prediction$model_id <- as.character(model_id)
    fixture <- fixtures[fixture_index[[i]], , drop = FALSE]
    observed <- phase14_calibration_revision_observed_class(
      fixture$regulation_home_goals[[1L]], fixture$regulation_away_goals[[1L]]
    )
    probabilities <- setNames(
      as.numeric(prediction[1L, c("p_home", "p_draw", "p_away")]),
      c("home", "draw", "away")
    )
    values <- c(
      rps = ranked_probability_score(probabilities, observed),
      brier = multiclass_brier(probabilities, observed),
      log_loss = log_score(probabilities, observed)
    )
    do.call(rbind, lapply(names(values), function(metric) {
      benchmark_metric_row(prediction, fixture, metric, values[[metric]], "regulation_1x2")
    }))
  })
  result <- do.call(rbind, output)
  rownames(result) <- NULL
  result
}

phase14_calibration_revision_comparison <- function(calibration_result, protocol = NULL) {
  if (!is.list(calibration_result) || !is.data.frame(calibration_result$panel) ||
      !is.data.frame(calibration_result$calibrated_predictions) ||
      !is.list(calibration_result$calibrator)) {
    stop("Phase 14 calibration comparison requires fitted panel evidence", call. = FALSE)
  }
  panel <- calibration_result$panel
  calibrated_rows <- calibration_result$calibrated_predictions
  calibrator <- calibration_result$calibrator
  if (nrow(panel) != 630L || nrow(calibrated_rows) != 630L ||
      anyDuplicated(as.character(calibrated_rows$fixture_id)) ||
      !setequal(as.character(panel$fixture_id), as.character(calibrated_rows$fixture_id))) {
    stop("Phase 14 calibration comparison requires identical 630-fixture views", call. = FALSE)
  }
  calibrated_rows <- calibrated_rows[
    match(as.character(panel$fixture_id), as.character(calibrated_rows$fixture_id)),
    ,
    drop = FALSE
  ]
  identity_columns <- phase12_selection_expected_identity()
  phase14_calibration_revision_require_columns(
    calibrated_rows,
    c(identity_columns, "p_home", "p_draw", "p_away", "p_home_calibrated", "p_draw_calibrated", "p_away_calibrated"),
    "Phase 14 calibrated prediction evidence"
  )
  raw <- calibrated_rows[, c(identity_columns, "p_home", "p_draw", "p_away"), drop = FALSE]
  calibrated <- raw
  calibrated$p_home <- as.numeric(calibrated_rows$p_home_calibrated)
  calibrated$p_draw <- as.numeric(calibrated_rows$p_draw_calibrated)
  calibrated$p_away <- as.numeric(calibrated_rows$p_away_calibrated)
  identity <- phase12_selection_identity(raw, calibrated, as.character(panel$fixture_id))
  raw_scores <- phase14_calibration_revision_score_view(raw, panel, "raw_1x2")
  calibrated_scores <- phase14_calibration_revision_score_view(
    calibrated, panel, "calibrated_1x2"
  )
  editions <- unique(as.character(panel$edition_id[order(panel$edition_sequence)]))
  if (length(editions) != 12L) {
    stop("Phase 14 calibration comparison requires 12 registered editions", call. = FALSE)
  }
  raw_summaries <- aggregate_benchmark_scores(raw_scores, editions)
  calibrated_summaries <- aggregate_benchmark_scores(calibrated_scores, editions)
  raw_calibration <- fixed_benchmark_calibration(raw, panel, as.character(panel$fixture_id))
  calibrated_calibration <- fixed_benchmark_calibration(
    calibrated, panel, as.character(panel$fixture_id)
  )
  raw_pair <- raw_scores
  calibrated_pair <- calibrated_scores
  paired <- make_paired_fold_comparisons(
    rbind(raw_pair, calibrated_pair),
    "calibrated_1x2",
    "raw_1x2",
    phase12_selection_tournaments(editions),
    as.character(panel$fixture_id),
    metric = "rps",
    target = "regulation_1x2"
  )
  unchanged_columns <- c(
    "fixture_id", "edition_id", "track_id", "score_distribution_id",
    "p_over_2_5", "p_under_2_5", "p_btts", "prediction_status"
  )
  distribution_unchanged <- identical(
    lapply(raw[unchanged_columns], as.character),
    lapply(calibrated[unchanged_columns], as.character)
  )
  raw_headline <- stats::setNames(
    vapply(
      c("rps", "brier", "log_loss"),
      function(metric) phase12_selection_metric_headline(raw_summaries, metric),
      numeric(1)
    ),
    c("rps", "brier", "log_loss")
  )
  calibrated_headline <- stats::setNames(
    vapply(
      c("rps", "brier", "log_loss"),
      function(metric) phase12_selection_metric_headline(calibrated_summaries, metric),
      numeric(1)
    ),
    c("rps", "brier", "log_loss")
  )
  list(
    candidate_id = "open_nb_incumbent",
    track_id = "updating",
    run_id = as.character(raw$run_id[[1L]]),
    panel_id = "open_core",
    raw_predictions = raw,
    calibrated_predictions = calibrated,
    raw_scores = raw_scores,
    calibrated_scores = calibrated_scores,
    raw_summaries = raw_summaries,
    calibrated_summaries = calibrated_summaries,
    raw_calibration = raw_calibration,
    calibrated_calibration = calibrated_calibration,
    raw_headline = raw_headline,
    calibrated_headline = calibrated_headline,
    raw_tournament_metrics = stats::setNames(
      lapply(c("rps", "brier", "log_loss"), function(metric) {
        phase12_selection_tournament_metric(raw_summaries, metric)
      }),
      c("rps", "brier", "log_loss")
    ),
    calibrated_tournament_metrics = stats::setNames(
      lapply(c("rps", "brier", "log_loss"), function(metric) {
        phase12_selection_tournament_metric(calibrated_summaries, metric)
      }),
      c("rps", "brier", "log_loss")
    ),
    raw_calibration_values = phase12_selection_calibration_values(raw_calibration),
    calibrated_calibration_values = phase12_selection_calibration_values(calibrated_calibration),
    paired_rps = paired,
    expected_fixture_ids = as.character(panel$fixture_id),
    expected_editions = editions,
    coverage_numerator = length(unique(calibrated$fixture_id)),
    coverage_denominator = nrow(panel),
    coverage_valid = length(unique(calibrated$fixture_id)) == nrow(panel),
    calibration_support_valid = identical(as.character(calibrator$fit_status), "fitted"),
    distribution_unchanged = isTRUE(distribution_unchanged),
    identity = identity
  )
}

phase14_calibration_revision_or <- function(value, fallback) {
  if (is.null(value) || !length(value)) fallback else value
}

phase14_calibration_revision_reason_string <- function(reasons) {
  if (!length(reasons)) "" else paste(as.character(reasons), collapse = "|")
}

phase14_calibration_revision_gate_row <- function(
    comparison, calibrator = NULL, chronology_valid = TRUE, protocol = NULL
) {
  decision <- phase12_selection_decision(comparison, protocol = protocol)
  reasons <- as.character(decision$reason_codes)
  has_reason <- function(reason) reason %in% reasons
  expected_count <- as.integer(phase14_calibration_revision_or(
    comparison$coverage_denominator, 0L
  ))
  observed_count <- as.integer(phase14_calibration_revision_or(
    comparison$coverage_numerator, 0L
  ))
  fixture_count <- if (!is.null(comparison$expected_fixture_ids)) {
    length(unique(as.character(comparison$expected_fixture_ids)))
  } else observed_count
  fit_status <- if (is.list(calibrator)) as.character(calibrator$fit_status) else "not_supplied"
  model_data_cutoff <- if (is.list(calibrator)) {
    as.character(phase14_calibration_revision_or(calibrator$model_data_cutoff, ""))
  } else ""
  calibration_evidence_cutoff <- if (is.list(calibrator)) {
    as.character(phase14_calibration_revision_or(calibrator$calibration_evidence_cutoff, ""))
  } else ""
  row <- data.frame(
    schema_version = "phase14-calibration-gate-v1",
    disposition = if (isTRUE(decision$calibration_promoted)) {
      "CALIBRATION_RELEASE_APPROVED"
    } else "CALIBRATION_RELEASE_BLOCKED",
    model_id = "open_nb_incumbent",
    track_id = "updating",
    panel_id = "open_core",
    expected_row_count = expected_count,
    observed_row_count = observed_count,
    unique_fixture_count = as.integer(fixture_count),
    chronology_valid = isTRUE(chronology_valid),
    calibration_support_valid = !has_reason("calibration_support_insufficient"),
    coverage_valid = !has_reason("fixture_coverage_veto"),
    score_identity_valid = !has_reason("score_identity_veto"),
    rps_valid = !has_reason("rps_veto"),
    brier_valid = !has_reason("brier_veto"),
    log_loss_valid = !has_reason("log_loss_veto"),
    fold_stability_valid = !has_reason("fold_stability_veto"),
    calibration_improvement_valid = !has_reason("calibration_not_improved"),
    raw_headline_rps = as.numeric(decision$raw_headline[["rps"]]),
    calibrated_headline_rps = as.numeric(decision$calibrated_headline[["rps"]]),
    rps_delta = as.numeric(decision$rps_delta),
    raw_headline_brier = as.numeric(decision$raw_headline[["brier"]]),
    calibrated_headline_brier = as.numeric(decision$calibrated_headline[["brier"]]),
    brier_relative_change = as.numeric(decision$brier_relative_change),
    raw_headline_log_loss = as.numeric(decision$raw_headline[["log_loss"]]),
    calibrated_headline_log_loss = as.numeric(decision$calibrated_headline[["log_loss"]]),
    log_loss_relative_change = as.numeric(decision$log_loss_relative_change),
    fold_stability_max_regression = as.numeric(decision$max_fold_regression),
    raw_calibration_error = as.numeric(comparison$raw_calibration_values$calibration_error),
    calibrated_calibration_error = as.numeric(
      comparison$calibrated_calibration_values$calibration_error
    ),
    calibration_error_delta = as.numeric(decision$calibration_delta),
    reason_codes = phase14_calibration_revision_reason_string(reasons),
    reason_count = length(reasons),
    fit_status = fit_status,
    primary_probability_view = as.character(decision$primary_probability_view),
    calibration_promoted = isTRUE(decision$calibration_promoted),
    model_data_cutoff = model_data_cutoff,
    calibration_evidence_cutoff = calibration_evidence_cutoff,
    score_support_g = 40L,
    holdout_labels_used = FALSE,
    authority_mutated = FALSE,
    protocol_sha256 = if (is.list(calibrator)) {
      as.character(phase14_calibration_revision_or(calibrator$protocol_sha256, ""))
    } else "",
    code_commit = phase14_calibration_revision_git_commit(),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  row$row_sha256 <- phase14_calibration_revision_table_sha256(row)
  row
}

phase14_calibration_revision_write_csv <- function(data, path) {
  utils::write.csv(data, path, row.names = FALSE, na = "", quote = TRUE)
  invisible(path)
}

phase14_calibration_revision_manifest_self_hash <- function(manifest) {
  phase14_calibration_revision_table_sha256(
    manifest[, setdiff(names(manifest), "manifest_self_sha256"), drop = FALSE]
  )
}

phase14_calibration_revision_manifest <- function(output_root, gate, calibrator) {
  paths <- phase14_calibration_revision_output_paths(output_root)
  required <- paths[c("calibrator", "calibrated_predictions", "calibration_gate")]
  if (any(!file.exists(required))) {
    stop("Phase 14 calibration manifest requires all fitted and gate artifacts", call. = FALSE)
  }
  source_predictions_path <- phase14_calibration_revision_resolve_path(
    "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/predictions/fixture_predictions.csv"
  )
  fixtures_path <- phase14_calibration_revision_resolve_path("data/benchmark/phase09/fixtures.csv")
  model_path <- phase14_calibration_revision_resolve_path(
    "outputs/releases/phase12-wc2026-incumbent-retained-v1/model/approved_model.rds"
  )
  freeze_path <- phase14_calibration_revision_resolve_path(
    "data/benchmark/phase12/freeze_manifest.csv"
  )
  recipe_path <- phase14_calibration_revision_resolve_path(
    "data/benchmark/phase12/calibration_recipe.json"
  )
  protocol_path <- phase14_calibration_revision_resolve_path(
    "data/benchmark/phase09/promotion_protocol.json"
  )
  manifest <- data.frame(
    schema_version = "phase14-calibration-revision-manifest-v1",
    model_id = "open_nb_incumbent",
    track_id = "updating",
    panel_id = "open_core",
    disposition = as.character(gate$disposition[[1L]]),
    reason_codes = as.character(gate$reason_codes[[1L]]),
    development_row_count = 630L,
    unique_fixture_count = 630L,
    model_data_cutoff = as.character(calibrator$model_data_cutoff),
    calibration_evidence_cutoff = as.character(calibrator$calibration_evidence_cutoff),
    score_support_g = 40L,
    model_sha256 = phase14_calibration_revision_file_sha256(model_path),
    source_predictions_file_sha256 = phase14_calibration_revision_file_sha256(
      source_predictions_path
    ),
    source_predictions_slice_sha256 = as.character(calibrator$source_predictions_sha256),
    fixtures_file_sha256 = phase14_calibration_revision_file_sha256(fixtures_path),
    fixtures_sha256 = as.character(calibrator$fixtures_sha256),
    freeze_manifest_sha256 = phase14_calibration_revision_file_sha256(freeze_path),
    recipe_sha256 = phase14_calibration_revision_file_sha256(recipe_path),
    protocol_sha256 = phase14_calibration_revision_file_sha256(protocol_path),
    code_commit = phase14_calibration_revision_git_commit(),
    code_sha256 = phase14_calibration_revision_file_sha256(
      "R/release/calibration_revision.R"
    ),
    calibrator_sha256 = phase14_calibration_revision_file_sha256(paths[["calibrator"]]),
    calibrated_predictions_sha256 = phase14_calibration_revision_file_sha256(
      paths[["calibrated_predictions"]]
    ),
    calibration_gate_sha256 = phase14_calibration_revision_file_sha256(
      paths[["calibration_gate"]]
    ),
    calibration_promoted = isTRUE(gate$calibration_promoted[[1L]]),
    primary_probability_view = as.character(gate$primary_probability_view[[1L]]),
    fit_status = as.character(calibrator$fit_status),
    chronology_valid = isTRUE(gate$chronology_valid[[1L]]),
    holdout_labels_used = FALSE,
    authority_mutated = FALSE,
    manifest_self_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  manifest$manifest_self_sha256 <- phase14_calibration_revision_manifest_self_hash(manifest)
  manifest
}

phase14_calibration_revision_load_result <- function(output_root) {
  paths <- phase14_calibration_revision_output_paths(output_root)
  if (any(!file.exists(paths[c("calibrator", "calibrated_predictions")]))) {
    stop("Phase 14 fitted calibration evidence is missing", call. = FALSE)
  }
  list(
    calibrator = readRDS(paths[["calibrator"]]),
    calibrated_predictions = utils::read.csv(
      paths[["calibrated_predictions"]],
      stringsAsFactors = FALSE,
      check.names = FALSE,
      na.strings = character()
    ),
    panel = phase14_build_incumbent_development_panel(),
    calibrator_path = paths[["calibrator"]],
    calibrated_predictions_path = paths[["calibrated_predictions"]]
  )
}

#' Apply the unchanged Phase 12 vetoes and persist one pass-or-block gate.
#' @export
phase14_evaluate_incumbent_calibration <- function(
    comparison = NULL,
    calibration_result = NULL,
    output_root = "outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-revision",
    protocol = "data/benchmark/phase09/promotion_protocol.json"
) {
  if (is.null(calibration_result) && is.null(comparison)) {
    calibration_result <- phase14_calibration_revision_load_result(output_root)
  }
  if (is.null(comparison)) {
    comparison <- phase14_calibration_revision_comparison(calibration_result, protocol)
  }
  calibrator <- if (is.list(calibration_result)) calibration_result$calibrator else NULL
  chronology_valid <- if (is.list(calibration_result) &&
      is.data.frame(calibration_result$calibrated_predictions)) {
    rows <- calibration_result$calibrated_predictions
    prior_rows <- rows$calibration_training_row_count > 0L
    isTRUE(all(
      !prior_rows |
        as.Date(rows$calibration_max_evidence_date) < as.Date(rows$edition_open_date)
    ))
  } else TRUE
  gate <- phase14_calibration_revision_gate_row(
    comparison,
    calibrator = calibrator,
    chronology_valid = chronology_valid,
    protocol = protocol
  )
  output_root <- phase14_calibration_revision_resolve_path(output_root)
  dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
  paths <- phase14_calibration_revision_output_paths(output_root)
  phase14_calibration_revision_write_csv(gate, paths[["calibration_gate"]])
  manifest <- NULL
  if (!is.null(calibrator) && all(file.exists(paths[c("calibrator", "calibrated_predictions")]))) {
    manifest <- phase14_calibration_revision_manifest(output_root, gate, calibrator)
    phase14_calibration_revision_write_csv(manifest, paths[["revision_manifest"]])
  }
  list(
    comparison = comparison,
    decision = phase12_selection_decision(comparison, protocol = protocol),
    gate = gate,
    manifest = manifest,
    paths = paths
  )
}

phase14_calibration_revision_read_character_csv <- function(path, name) {
  if (!file.exists(path)) stop(name, " is missing", call. = FALSE)
  utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    colClasses = "character",
    na.strings = character()
  )
}

phase14_calibration_revision_as_logical <- function(value) {
  identical(toupper(as.character(value)), "TRUE")
}

#' Validate complete empirical calibration evidence without requiring promotion.
#' @export
phase14_validate_calibration_revision <- function(
    output_root = "outputs/benchmarks/rolling_tournaments/phase14-incumbent-calibration-revision",
    require_promoted = FALSE
) {
  paths <- phase14_calibration_revision_output_paths(output_root)
  if (any(!file.exists(paths))) {
    stop("Phase 14 calibration revision artifact set is incomplete", call. = FALSE)
  }
  gate <- phase14_calibration_revision_read_character_csv(
    paths[["calibration_gate"]], "Phase 14 calibration gate"
  )
  manifest <- phase14_calibration_revision_read_character_csv(
    paths[["revision_manifest"]], "Phase 14 calibration revision manifest"
  )
  if (nrow(gate) != 1L || nrow(manifest) != 1L) {
    stop("Phase 14 calibration revision requires one gate and one manifest row", call. = FALSE)
  }
  required_gate <- c(
    "disposition", "reason_codes", "calibration_promoted", "primary_probability_view",
    "fit_status", "chronology_valid", "holdout_labels_used", "authority_mutated",
    "row_sha256"
  )
  required_manifest <- c(
    "model_sha256", "source_predictions_file_sha256", "source_predictions_slice_sha256",
    "fixtures_file_sha256", "fixtures_sha256", "freeze_manifest_sha256", "recipe_sha256",
    "protocol_sha256", "code_sha256", "calibrator_sha256",
    "calibrated_predictions_sha256", "calibration_gate_sha256",
    "manifest_self_sha256"
  )
  phase14_calibration_revision_require_columns(gate, required_gate, "Phase 14 calibration gate")
  phase14_calibration_revision_require_columns(
    manifest, required_manifest, "Phase 14 calibration revision manifest"
  )
  gate_hash <- phase14_calibration_revision_table_sha256(
    gate[, setdiff(names(gate), "row_sha256"), drop = FALSE]
  )
  if (!identical(tolower(gate$row_sha256[[1L]]), tolower(gate_hash))) {
    stop("Phase 14 calibration gate row hash mismatch", call. = FALSE)
  }
  manifest_hash <- phase14_calibration_revision_manifest_self_hash(manifest)
  if (!identical(
    tolower(manifest$manifest_self_sha256[[1L]]),
    tolower(manifest_hash)
  )) {
    stop("Phase 14 calibration revision manifest self-hash mismatch", call. = FALSE)
  }
  expected_file_hashes <- c(
    calibrator_sha256 = phase14_calibration_revision_file_sha256(paths[["calibrator"]]),
    calibrated_predictions_sha256 = phase14_calibration_revision_file_sha256(
      paths[["calibrated_predictions"]]
    ),
    calibration_gate_sha256 = phase14_calibration_revision_file_sha256(
      paths[["calibration_gate"]]
    ),
    source_predictions_file_sha256 = phase14_calibration_revision_file_sha256(
      "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/predictions/fixture_predictions.csv"
    ),
    fixtures_file_sha256 = phase14_calibration_revision_file_sha256(
      "data/benchmark/phase09/fixtures.csv"
    ),
    freeze_manifest_sha256 = phase14_calibration_revision_file_sha256(
      "data/benchmark/phase12/freeze_manifest.csv"
    ),
    recipe_sha256 = phase14_calibration_revision_file_sha256(
      "data/benchmark/phase12/calibration_recipe.json"
    ),
    protocol_sha256 = phase14_calibration_revision_file_sha256(
      "data/benchmark/phase09/promotion_protocol.json"
    ),
    code_sha256 = phase14_calibration_revision_file_sha256(
      "R/release/calibration_revision.R"
    ),
    model_sha256 = phase14_calibration_revision_file_sha256(
      "outputs/releases/phase12-wc2026-incumbent-retained-v1/model/approved_model.rds"
    )
  )
  for (field in names(expected_file_hashes)) {
    if (!identical(tolower(manifest[[field]][[1L]]), tolower(expected_file_hashes[[field]]))) {
      stop("Phase 14 calibration revision artifact hash mismatch: ", field, call. = FALSE)
    }
  }
  calibrator <- readRDS(paths[["calibrator"]])
  if (!is.list(calibrator) || !identical(as.character(calibrator$fit_status), "fitted") ||
      !identical(as.character(calibrator$model_id), "open_nb_incumbent") ||
      !identical(as.character(calibrator$track_id), "updating") ||
      !identical(as.character(calibrator$panel_id), "open_core") ||
      !identical(as.integer(calibrator$development_row_count), 630L) ||
      !identical(as.integer(calibrator$development_fixture_count), 630L) ||
      !identical(as.integer(calibrator$score_support), 40L) ||
      isTRUE(calibrator$holdout_labels_used)) {
    stop("Phase 14 fitted calibrator identity is invalid", call. = FALSE)
  }
  if (!identical(
    tolower(as.character(calibrator$source_predictions_sha256)),
    tolower(manifest$source_predictions_slice_sha256[[1L]])
  ) || !identical(
    tolower(as.character(calibrator$fixtures_sha256)),
    tolower(manifest$fixtures_sha256[[1L]])
  )) {
    stop("Phase 14 fitted calibrator source hash mismatch", call. = FALSE)
  }
  calibrated_predictions <- utils::read.csv(
    paths[["calibrated_predictions"]],
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = character()
  )
  panel <- phase14_build_incumbent_development_panel()
  if (nrow(calibrated_predictions) != 630L ||
      anyDuplicated(as.character(calibrated_predictions$fixture_id)) ||
      !identical(as.character(calibrated_predictions$fixture_id), as.character(panel$fixture_id)) ||
      phase14_calibration_revision_has_holdout_identity(calibrated_predictions)) {
    stop("Phase 14 calibrated prediction identity is invalid", call. = FALSE)
  }
  for (column in c("p_home", "p_draw", "p_away", "score_distribution_id")) {
    if (!identical(as.character(calibrated_predictions[[column]]), as.character(panel[[column]]))) {
      stop("Phase 14 calibrated prediction raw or score identity drifted", call. = FALSE)
    }
  }
  calibrated_matrix <- as.matrix(
    calibrated_predictions[, c("p_home_calibrated", "p_draw_calibrated", "p_away_calibrated")]
  )
  storage.mode(calibrated_matrix) <- "double"
  if (anyNA(calibrated_matrix) || any(!is.finite(calibrated_matrix)) ||
      any(calibrated_matrix < 0 | calibrated_matrix > 1) ||
      any(abs(rowSums(calibrated_matrix) - 1) > 1e-10)) {
    stop("Phase 14 calibrated prediction simplex is invalid", call. = FALSE)
  }
  chronology_valid <- all(
    calibrated_predictions$calibration_training_row_count == 0L |
      as.Date(calibrated_predictions$calibration_max_evidence_date) <
        as.Date(calibrated_predictions$edition_open_date)
  ) && as.Date(calibrator$calibration_evidence_cutoff) < as.Date(calibrator$model_data_cutoff)
  if (!isTRUE(chronology_valid)) {
    stop("Phase 14 calibration chronology is invalid", call. = FALSE)
  }
  calibration_result <- list(
    calibrator = calibrator,
    calibrated_predictions = calibrated_predictions,
    panel = panel
  )
  comparison <- phase14_calibration_revision_comparison(calibration_result)
  expected_gate <- phase14_calibration_revision_gate_row(
    comparison,
    calibrator = calibrator,
    chronology_valid = chronology_valid,
    protocol = "data/benchmark/phase09/promotion_protocol.json"
  )
  decision_fields <- setdiff(names(expected_gate), c("code_commit", "row_sha256"))
  numeric_decision_fields <- c(
    "expected_row_count", "observed_row_count", "unique_fixture_count",
    "raw_headline_rps", "calibrated_headline_rps", "rps_delta",
    "raw_headline_brier", "calibrated_headline_brier", "brier_relative_change",
    "raw_headline_log_loss", "calibrated_headline_log_loss",
    "log_loss_relative_change", "fold_stability_max_regression",
    "raw_calibration_error", "calibrated_calibration_error",
    "calibration_error_delta", "reason_count", "score_support_g"
  )
  for (field in decision_fields) {
    matches <- if (field %in% numeric_decision_fields) {
      isTRUE(all.equal(
        as.numeric(gate[[field]]),
        as.numeric(expected_gate[[field]]),
        tolerance = 1e-12
      ))
    } else {
      identical(as.character(gate[[field]]), as.character(expected_gate[[field]]))
    }
    if (!matches) {
      stop("Phase 14 calibration gate decision drifted: ", field, call. = FALSE)
    }
  }
  if (phase14_calibration_revision_as_logical(gate$calibration_promoted[[1L]])) {
    if (!identical(as.character(gate$disposition[[1L]]), "CALIBRATION_RELEASE_APPROVED") ||
        nzchar(as.character(gate$reason_codes[[1L]])) ||
        !identical(as.character(gate$primary_probability_view[[1L]]), "calibrated_1x2")) {
      stop("Phase 14 calibration promoted gate is internally inconsistent", call. = FALSE)
    }
  } else if (!identical(
    as.character(gate$disposition[[1L]]), "CALIBRATION_RELEASE_BLOCKED"
  ) || !nzchar(as.character(gate$reason_codes[[1L]])) ||
      !identical(as.character(gate$primary_probability_view[[1L]]), "raw_1x2")) {
    stop("Phase 14 calibration blocked gate is internally inconsistent", call. = FALSE)
  }
  if (phase14_calibration_revision_as_logical(gate$holdout_labels_used[[1L]]) ||
      phase14_calibration_revision_as_logical(gate$authority_mutated[[1L]])) {
    stop("Phase 14 calibration evidence claims forbidden holdout or authority mutation", call. = FALSE)
  }
  if (isTRUE(require_promoted) &&
      !phase14_calibration_revision_as_logical(gate$calibration_promoted[[1L]])) {
    stop("Phase 14 calibration release is blocked and not promoted", call. = FALSE)
  }
  invisible(TRUE)
}

phase14_authority_file_sha256 <- function(path) {
  if (!file.exists(path) || dir.exists(path)) {
    stop("Phase 14 authority file is missing: ", path, call. = FALSE)
  }
  digest::digest(file = path, algo = "sha256", serialize = FALSE)
}

phase14_authority_read_bytes <- function(path) {
  if (!file.exists(path) || dir.exists(path)) {
    stop("Phase 14 authority file is missing: ", path, call. = FALSE)
  }
  readBin(path, what = "raw", n = file.info(path)$size)
}

phase14_authority_write_bytes <- function(path, bytes) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  connection <- file(path, open = "wb")
  on.exit(close(connection), add = TRUE)
  writeBin(bytes, connection)
  invisible(path)
}

phase14_authority_normalize_path <- function(path, project_root, name, must_work = FALSE) {
  value <- as.character(path)
  if (length(value) != 1L || is.na(value) || !nzchar(value)) {
    stop("Phase 14 ", name, " must be one non-empty path", call. = FALSE)
  }
  if (!grepl("^/", value)) value <- file.path(project_root, value)
  if (!must_work && !file.exists(value)) {
    return(file.path(
      normalizePath(dirname(value), winslash = "/", mustWork = TRUE),
      basename(value)
    ))
  }
  normalizePath(value, winslash = "/", mustWork = must_work)
}

phase14_authority_assert_under_root <- function(path, root, name) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (!identical(path, root) && !startsWith(path, paste0(root, "/"))) {
    stop("Phase 14 ", name, " escapes the transaction root", call. = FALSE)
  }
  link_target <- Sys.readlink(path)
  if (!is.na(link_target) && nzchar(link_target)) {
    stop("Phase 14 ", name, " must not be a symlink", call. = FALSE)
  }
  path
}

phase14_authority_snapshot <- function(path) {
  exists <- file.exists(path)
  if (exists && dir.exists(path)) {
    stop("Phase 14 authority path must be a regular file: ", path, call. = FALSE)
  }
  bytes <- if (exists) phase14_authority_read_bytes(path) else raw()
  list(
    exists = exists,
    bytes = bytes,
    sha256 = if (exists) digest::digest(bytes, algo = "sha256", serialize = FALSE) else ""
  )
}

phase14_authority_restore_snapshot <- function(path, snapshot, scratch_root) {
  if (!isTRUE(snapshot$exists)) {
    if (file.exists(path)) {
      unlink(path, force = TRUE)
      if (file.exists(path)) {
        stop("Phase 14 rollback could not restore absent authority: ", path, call. = FALSE)
      }
    }
    return(invisible(TRUE))
  }
  restore_path <- tempfile("restore-", tmpdir = scratch_root)
  phase14_authority_write_bytes(restore_path, snapshot$bytes)
  if (file.exists(path)) {
    unlink(path, force = TRUE)
    if (file.exists(path)) {
      stop("Phase 14 rollback could not remove changed authority: ", path, call. = FALSE)
    }
  }
  if (!file.rename(restore_path, path)) {
    stop("Phase 14 rollback could not restore authority: ", path, call. = FALSE)
  }
  invisible(TRUE)
}

phase14_authority_verify_snapshot <- function(path, snapshot) {
  if (!identical(file.exists(path), isTRUE(snapshot$exists))) return(FALSE)
  if (!isTRUE(snapshot$exists)) return(TRUE)
  identical(phase14_authority_read_bytes(path), snapshot$bytes)
}

phase14_authority_link_release_tree <- function(source_root, target_root) {
  source_root <- normalizePath(source_root, winslash = "/", mustWork = TRUE)
  dir.create(target_root, recursive = TRUE, showWarnings = FALSE)
  entries <- list.files(
    source_root,
    recursive = TRUE,
    full.names = TRUE,
    all.files = TRUE,
    include.dirs = TRUE,
    no.. = TRUE
  )
  if (!length(entries)) return(invisible(target_root))
  information <- file.info(entries)
  directories <- entries[!is.na(information$isdir) & information$isdir]
  for (directory in directories) {
    relative <- substring(directory, nchar(source_root) + 2L)
    dir.create(file.path(target_root, relative), recursive = TRUE, showWarnings = FALSE)
  }
  files <- entries[!is.na(information$isdir) & !information$isdir]
  for (source_path in files) {
    relative <- substring(source_path, nchar(source_root) + 2L)
    target_path <- file.path(target_root, relative)
    dir.create(dirname(target_path), recursive = TRUE, showWarnings = FALSE)
    linked <- suppressWarnings(file.link(source_path, target_path))
    if (!isTRUE(linked) && !file.copy(source_path, target_path, overwrite = FALSE)) {
      stop("Phase 14 could not stage release artifact: ", relative, call. = FALSE)
    }
  }
  invisible(target_root)
}

phase14_authority_inject_failure <- function(failure_injector, point, transaction) {
  if (is.null(failure_injector)) return(invisible(FALSE))
  if (!is.function(failure_injector)) {
    stop("Phase 14 failure injector must be a function", call. = FALSE)
  }
  if (isTRUE(failure_injector(point, transaction))) {
    stop("injected failure at ", point, call. = FALSE)
  }
  invisible(FALSE)
}

#' Atomically promote the calibrated selector and both registry pins.
#' @export
phase14_promote_calibrated_release <- function(
    candidate_selector_path,
    selector_path = "outputs/releases/approved_release.csv",
    registry_path = "data/competition/registries/competition_editions.csv",
    trusted_release_root = "outputs/releases",
    project_root = ".",
    audit_at_utc,
    operator,
    operator_action,
    expected_selector_sha256 = "",
    expected_registry_sha256,
    failure_injector = NULL) {
  project_root <- normalizePath(project_root, winslash = "/", mustWork = TRUE)
  candidate_selector_path <- phase14_authority_normalize_path(
    candidate_selector_path, project_root, "candidate selector", must_work = TRUE
  )
  selector_path <- phase14_authority_normalize_path(
    selector_path, project_root, "durable selector", must_work = FALSE
  )
  registry_path <- phase14_authority_normalize_path(
    registry_path, project_root, "competition registry", must_work = TRUE
  )
  trusted_release_root <- phase14_authority_normalize_path(
    trusted_release_root, project_root, "trusted release root", must_work = TRUE
  )
  candidate_selector_path <- phase14_authority_assert_under_root(
    candidate_selector_path, project_root, "candidate selector"
  )
  selector_path <- phase14_authority_assert_under_root(
    selector_path, project_root, "durable selector"
  )
  registry_path <- phase14_authority_assert_under_root(
    registry_path, project_root, "competition registry"
  )
  trusted_release_root <- phase14_authority_assert_under_root(
    trusted_release_root, project_root, "trusted release root"
  )
  if (!identical(dirname(selector_path), trusted_release_root) ||
      !identical(basename(selector_path), "approved_release.csv")) {
    stop("Phase 14 durable selector must be approved_release.csv in the trusted release root", call. = FALSE)
  }
  if (!identical(basename(registry_path), "competition_editions.csv")) {
    stop("Phase 14 registry path must name competition_editions.csv", call. = FALSE)
  }
  source_bundles_path <- file.path(dirname(registry_path), "source_bundles.csv")
  if (!file.exists(source_bundles_path)) {
    stop("Phase 14 source bundle registry is missing", call. = FALSE)
  }
  expected_selector_sha256 <- tolower(as.character(expected_selector_sha256))
  expected_registry_sha256 <- tolower(as.character(expected_registry_sha256))
  if (length(expected_selector_sha256) != 1L || is.na(expected_selector_sha256) ||
      (nzchar(expected_selector_sha256) && !grepl("^[0-9a-f]{64}$", expected_selector_sha256))) {
    stop("Phase 14 expected selector SHA-256 is invalid", call. = FALSE)
  }
  if (length(expected_registry_sha256) != 1L || is.na(expected_registry_sha256) ||
      !grepl("^[0-9a-f]{64}$", expected_registry_sha256)) {
    stop("Phase 14 expected registry SHA-256 is invalid", call. = FALSE)
  }

  selector_snapshot <- phase14_authority_snapshot(selector_path)
  registry_snapshot <- phase14_authority_snapshot(registry_path)
  selector_matches <- if (nzchar(expected_selector_sha256)) {
    selector_snapshot$exists && identical(selector_snapshot$sha256, expected_selector_sha256)
  } else {
    !selector_snapshot$exists
  }
  if (!selector_matches || !identical(registry_snapshot$sha256, expected_registry_sha256)) {
    stop(
      "prior-authority-changed: expected prior bytes do not match; inspect and reconcile before retry",
      call. = FALSE
    )
  }

  lock_path <- file.path(project_root, ".phase14-authority-promotion.lock")
  if (!dir.create(lock_path, showWarnings = FALSE)) {
    stop("Phase 14 authority promotion lock is already held", call. = FALSE)
  }
  stage_root <- tempfile(".phase14-authority-stage-", tmpdir = project_root)
  backup_root <- tempfile(".phase14-authority-backup-", tmpdir = project_root)
  dir.create(stage_root, recursive = FALSE)
  dir.create(backup_root, recursive = FALSE)
  cleanup <- function() {
    if (dir.exists(stage_root)) unlink(stage_root, recursive = TRUE, force = TRUE)
    if (dir.exists(backup_root)) unlink(backup_root, recursive = TRUE, force = TRUE)
    if (dir.exists(lock_path)) unlink(lock_path, recursive = TRUE, force = TRUE)
  }
  on.exit(cleanup(), add = TRUE)

  candidate_selector <- utils::read.csv(
    candidate_selector_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    colClasses = "character",
    na.strings = character()
  )
  phase14_validate_release_selector(candidate_selector, trusted_root = trusted_release_root)
  release_id <- as.character(candidate_selector$release_id[[1L]])
  staged_release_root <- file.path(stage_root, "releases")
  phase14_authority_link_release_tree(
    file.path(trusted_release_root, release_id),
    file.path(staged_release_root, release_id)
  )
  staged_selector_path <- file.path(staged_release_root, "approved_release.csv")
  phase14_authority_write_bytes(
    staged_selector_path,
    phase14_authority_read_bytes(candidate_selector_path)
  )
  staged_resolved <- phase14_resolve_approved_release(
    selector_path = staged_selector_path,
    trusted_release_root = staged_release_root
  )
  prior_registries <- utils::read.csv(
    registry_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
  source_bundles <- utils::read.csv(
    source_bundles_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
  candidate_registries <- phase14_repin_both_competition_releases(
    prior_registries,
    staged_resolved,
    source_bundles,
    audit_at_utc,
    operator,
    operator_action
  )
  staged_registry_path <- file.path(stage_root, "competition_editions.csv")
  utils::write.csv(
    candidate_registries,
    staged_registry_path,
    row.names = FALSE,
    na = "",
    quote = TRUE
  )
  staged_registry <- utils::read.csv(
    staged_registry_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
  phase14_validate_dual_repin_candidate(
    prior_registries,
    staged_registry,
    staged_resolved,
    source_bundles
  )

  transaction <- list(
    selector_path = selector_path,
    registry_path = registry_path,
    release_id = release_id,
    stage_root = stage_root,
    backup_root = backup_root
  )
  selector_backup <- file.path(backup_root, "approved_release.csv")
  registry_backup <- file.path(backup_root, "competition_editions.csv")
  promotion <- tryCatch({
    if (selector_snapshot$exists) {
      phase14_authority_inject_failure(failure_injector, "before_selector_backup", transaction)
      if (!file.rename(selector_path, selector_backup)) {
        stop("Phase 14 selector backup rename failed", call. = FALSE)
      }
      phase14_authority_inject_failure(failure_injector, "after_selector_backup", transaction)
    }
    phase14_authority_inject_failure(failure_injector, "before_selector_promote", transaction)
    if (!file.rename(staged_selector_path, selector_path)) {
      stop("Phase 14 selector promotion rename failed", call. = FALSE)
    }
    phase14_authority_inject_failure(failure_injector, "after_selector_promote", transaction)
    phase14_authority_inject_failure(failure_injector, "before_registry_backup", transaction)
    if (!file.rename(registry_path, registry_backup)) {
      stop("Phase 14 registry backup rename failed", call. = FALSE)
    }
    phase14_authority_inject_failure(failure_injector, "after_registry_backup", transaction)
    phase14_authority_inject_failure(failure_injector, "before_registry_promote", transaction)
    if (!file.rename(staged_registry_path, registry_path)) {
      stop("Phase 14 registry promotion rename failed", call. = FALSE)
    }
    phase14_authority_inject_failure(failure_injector, "after_registry_promote", transaction)
    phase14_authority_inject_failure(failure_injector, "before_post_validate", transaction)
    durable_resolved <- phase14_resolve_approved_release(
      selector_path = selector_path,
      trusted_release_root = trusted_release_root
    )
    durable_registries <- utils::read.csv(
      registry_path,
      stringsAsFactors = FALSE,
      check.names = FALSE,
      na.strings = ""
    )
    phase14_validate_dual_repin_candidate(
      prior_registries,
      durable_registries,
      durable_resolved,
      source_bundles
    )
    list(resolved = durable_resolved, registries = durable_registries)
  }, error = function(error) error)

  if (inherits(promotion, "error")) {
    rollback_error <- tryCatch({
      phase14_authority_restore_snapshot(selector_path, selector_snapshot, backup_root)
      phase14_authority_restore_snapshot(registry_path, registry_snapshot, backup_root)
      if (!phase14_authority_verify_snapshot(selector_path, selector_snapshot) ||
          !phase14_authority_verify_snapshot(registry_path, registry_snapshot)) {
        stop("restored authority bytes do not match the snapshot", call. = FALSE)
      }
      NULL
    }, error = function(error) error)
    if (inherits(rollback_error, "error")) {
      stop(
        "Phase 14 authority rollback failed after '", conditionMessage(promotion),
        "': ", conditionMessage(rollback_error),
        call. = FALSE
      )
    }
    stop("rollback-restored: ", conditionMessage(promotion), call. = FALSE)
  }

  candidate_bytes <- phase14_authority_read_bytes(candidate_selector_path)
  if (!identical(phase14_authority_read_bytes(selector_path), candidate_bytes)) {
    stop("Phase 14 durable selector bytes differ from the validated candidate", call. = FALSE)
  }
  list(
    status = "promoted",
    release_id = release_id,
    prior_identity = list(
      selector_exists = selector_snapshot$exists,
      selector_sha256 = selector_snapshot$sha256,
      registry_sha256 = registry_snapshot$sha256
    ),
    post_identity = list(
      selector_sha256 = phase14_authority_file_sha256(selector_path),
      registry_sha256 = phase14_authority_file_sha256(registry_path),
      model_data_cutoff = promotion$resolved$model_data_cutoff,
      registry_revisions = as.integer(promotion$registries$registry_revision)
    )
  )
}
