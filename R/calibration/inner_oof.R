#' Phase 12 chronology-safe candidate/track inner out-of-fold assembly.
#'
#' This service is deliberately label-free.  It consumes prediction rows that
#' already carry their point-in-time boundary and retains enough provenance to
#' audit the calibration fit without reopening a benchmark runner.

phase12_calibration_source_if_missing <- function(relative_path, symbols) {
  missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function")]
  if (!length(missing)) return(invisible(TRUE))
  root <- if (exists("project_root", inherits = TRUE) && dir.exists(get("project_root", inherits = TRUE))) {
    normalizePath(get("project_root", inherits = TRUE), winslash = "/", mustWork = TRUE)
  } else normalizePath(".", winslash = "/", mustWork = TRUE)
  while (!file.exists(file.path(root, relative_path))) {
    parent <- dirname(root)
    if (identical(parent, root)) break
    root <- parent
  }
  path <- file.path(root, relative_path)
  if (!file.exists(path)) stop("Phase 12 calibration dependency is missing: ", relative_path, call. = FALSE)
  source(path, local = .GlobalEnv)
  missing <- missing[!vapply(missing, exists, logical(1), mode = "function")]
  if (length(missing)) stop("Phase 12 calibration dependency did not define: ", paste(missing, collapse = ", "), call. = FALSE)
  invisible(TRUE)
}

phase12_calibration_project_root <- function() {
  root <- if (exists("project_root", inherits = TRUE) && dir.exists(get("project_root", inherits = TRUE))) {
    normalizePath(get("project_root", inherits = TRUE), winslash = "/", mustWork = TRUE)
  } else normalizePath(".", winslash = "/", mustWork = TRUE)
  while (!dir.exists(file.path(root, "R")) && !file.exists(file.path(root, ".planning", "STATE.md"))) {
    parent <- dirname(root)
    if (identical(parent, root)) break
    root <- parent
  }
  root
}

phase12_calibration_resolve_path <- function(path) {
  path <- as.character(path)
  if (length(path) != 1L || is.na(path) || !nzchar(path)) stop("Phase 12 calibration path must be one non-empty value", call. = FALSE)
  if (grepl("^/", path)) return(path)
  file.path(phase12_calibration_project_root(), path)
}

phase12_calibration_source_if_missing(
  "R/release/freeze_manifest.R",
  c("validate_phase12_freeze_manifest", "phase12_freeze_self_hash")
)
phase12_calibration_source_if_missing(
  "R/benchmark/cutoffs.R",
  c("assert_benchmark_cutoffs", "benchmark_holdout_rows", "guard_benchmark_purpose")
)
phase12_calibration_source_if_missing(
  "R/evaluation/proper_scores.R",
  c("validate_probability_vector")
)

phase12_inner_oof_required <- c(
  "candidate_id", "track_id", "outer_edition_id", "inner_edition_id",
  "fixture_id", "boundary_id", "evidence_cutoff_exclusive",
  "observed_class", "p_home_raw", "p_draw_raw", "p_away_raw",
  "source_prediction_sha256", "max_evidence_date"
)

phase12_inner_oof_hash <- function(data) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Phase 12 calibration provenance", call. = FALSE)
  if (!is.data.frame(data)) stop("inner-OOF hash input must be a data frame", call. = FALSE)
  columns <- sort(names(data), method = "radix")
  values <- lapply(data[columns], function(value) {
    if (inherits(value, "Date")) value <- format(value, "%Y-%m-%d")
    value <- as.character(value)
    value[is.na(value)] <- "<NA>"
    value
  })
  rows <- if (nrow(data)) {
    vapply(seq_len(nrow(data)), function(i) paste(vapply(values, `[[`, character(1), i), collapse = "\u001f"), character(1))
  } else character()
  digest::digest(paste(c(columns, rows), collapse = "\u001e"), algo = "sha256", serialize = FALSE)
}

phase12_inner_oof_prediction_hash <- function(row, fallback_columns = names(row)) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Phase 12 calibration provenance", call. = FALSE)
  values <- vapply(row[fallback_columns], function(value) {
    if (inherits(value, "Date")) value <- format(value, "%Y-%m-%d")
    value <- as.character(value)
    ifelse(length(value) && !is.na(value[[1L]]), value[[1L]], "")
  }, character(1))
  digest::digest(paste(values, collapse = "|"), algo = "sha256", serialize = FALSE)
}

phase12_inner_oof_edition_key <- function(ids) {
  ids <- as.character(ids)
  years <- suppressWarnings(as.integer(sub(".*?([0-9]{4}).*", "\\1", ids)))
  years[!grepl("[0-9]{4}", ids)] <- NA_integer_
  data.frame(id = ids, year = years, stringsAsFactors = FALSE)
}

phase12_inner_oof_edition_order <- function(ids, boundaries = NULL) {
  ids <- unique(as.character(ids))
  if (!length(ids)) return(setNames(integer(), character()))
  if (!is.null(boundaries) && is.data.frame(boundaries) && all(c("edition_id", "assessment_date") %in% names(boundaries))) {
    dates <- as.Date(boundaries$assessment_date)
    first <- vapply(ids, function(id) {
      value <- dates[as.character(boundaries$edition_id) == id]
      if (!length(value) || all(is.na(value))) NA_real_ else as.numeric(min(value, na.rm = TRUE))
    }, numeric(1))
    if (all(is.finite(first))) {
      ordering <- order(first, ids, method = "radix")
      return(setNames(seq_along(ids)[match(seq_along(ids), ordering)], ids))
    }
  }
  keys <- phase12_inner_oof_edition_key(ids)
  if (all(is.finite(keys$year))) {
    ordering <- order(keys$year, ids, method = "radix")
    return(setNames(seq_along(ids)[match(seq_along(ids), ordering)], ids))
  }
  ordering <- order(ids, method = "radix")
  setNames(seq_along(ids)[match(seq_along(ids), ordering)], ids)
}

phase12_inner_oof_freeze <- function(freeze_manifest) {
  if (is.null(freeze_manifest)) freeze_manifest <- "data/benchmark/phase12/freeze_manifest.csv"
  if (is.character(freeze_manifest) && length(freeze_manifest) == 1L) {
    freeze_path <- phase12_calibration_resolve_path(freeze_manifest)
    validate_phase12_freeze_manifest(freeze_path, project_root = phase12_calibration_project_root())
    return(utils::read.csv(freeze_path, stringsAsFactors = FALSE, check.names = FALSE))
  }
  if (is.data.frame(freeze_manifest)) {
    validated <- isTRUE(attr(freeze_manifest, "phase12_validated"))
    if (!validated) stop("Phase 12 freeze must be validated from its authoritative manifest path", call. = FALSE)
    return(freeze_manifest)
  }
  stop("freeze_manifest must be an authoritative path or validated data frame", call. = FALSE)
}

phase12_inner_oof_outer_date <- function(outer_edition_id, boundaries) {
  if (!is.data.frame(boundaries) || !all(c("edition_id", "assessment_date") %in% names(boundaries))) return(as.Date(NA))
  dates <- as.Date(boundaries$assessment_date[as.character(boundaries$edition_id) == outer_edition_id])
  if (!length(dates) || all(is.na(dates))) return(as.Date(NA))
  as.Date(min(dates, na.rm = TRUE), origin = "1970-01-01")
}

#' Validate the nested chronology and identity of one candidate/track OOF table.
#' @export
validate_phase12_inner_oof_chronology <- function(
    inner_oof, candidate_id, track_id, outer_edition_id, boundaries = NULL
) {
  if (!is.data.frame(inner_oof)) stop("Phase 12 inner OOF must be a data frame", call. = FALSE)
  missing <- setdiff(phase12_inner_oof_required, names(inner_oof))
  if (length(missing)) stop("Phase 12 inner OOF missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (length(candidate_id) != 1L || length(track_id) != 1L || length(outer_edition_id) != 1L ||
      !nzchar(as.character(candidate_id)) || !nzchar(as.character(track_id)) || !nzchar(as.character(outer_edition_id))) {
    stop("Phase 12 calibration identity must be one non-empty candidate, track, and outer edition", call. = FALSE)
  }
  if (nrow(inner_oof) == 0L) return(invisible(TRUE))
  if (any(as.character(inner_oof$candidate_id) != as.character(candidate_id)) ||
      any(as.character(inner_oof$track_id) != as.character(track_id)) ||
      any(as.character(inner_oof$outer_edition_id) != as.character(outer_edition_id))) {
    stop("Phase 12 inner OOF contains mixed candidate, track, or outer-edition identities", call. = FALSE)
  }
  if (anyDuplicated(as.character(inner_oof$fixture_id))) stop("Phase 12 inner OOF contains duplicate fixture rows", call. = FALSE)
  if (anyNA(inner_oof$inner_edition_id) || any(!nzchar(as.character(inner_oof$inner_edition_id))) ||
      any(tolower(as.character(inner_oof$inner_edition_id)) == "wc2026") ||
      tolower(as.character(outer_edition_id)) == "wc2026" ||
      any(grepl("^wc2026", tolower(as.character(inner_oof$fixture_id))))) {
    stop("Phase 12 calibration rejects WC2026 holdout rows", call. = FALSE)
  }
  phase12_calibration_source_if_missing("R/benchmark/cutoffs.R", c("guard_benchmark_purpose"))
  guard_benchmark_purpose(inner_oof, purpose = "calibration")
  cutoffs <- as.Date(inner_oof$evidence_cutoff_exclusive)
  max_evidence <- as.Date(inner_oof$max_evidence_date)
  if (anyNA(cutoffs) || anyNA(max_evidence)) stop("Phase 12 inner OOF requires complete evidence dates", call. = FALSE)
  if (any(max_evidence >= cutoffs)) stop("Phase 12 inner OOF evidence must precede its exclusive cutoff", call. = FALSE)
  if (any(!vapply(seq_len(nrow(inner_oof)), function(i) {
    validate_probability_vector(as.numeric(inner_oof[i, c("p_home_raw", "p_draw_raw", "p_away_raw")]), name = "raw 1X2 probabilities")
    TRUE
  }, logical(1)))) stop("Phase 12 inner OOF contains invalid probabilities", call. = FALSE)
  if (any(!as.character(inner_oof$observed_class) %in% c("home", "draw", "away"))) {
    stop("Phase 12 inner OOF contains an invalid observed class", call. = FALSE)
  }
  order_map <- phase12_inner_oof_edition_order(c(as.character(inner_oof$inner_edition_id), outer_edition_id), boundaries)
  outer_order <- unname(order_map[[as.character(outer_edition_id)]])
  inner_order <- unname(order_map[as.character(inner_oof$inner_edition_id)])
  if (is.na(outer_order) || any(is.na(inner_order)) || any(inner_order >= outer_order)) {
    stop("Phase 12 inner OOF must contain only strictly prior tournament editions", call. = FALSE)
  }
  outer_date <- phase12_inner_oof_outer_date(as.character(outer_edition_id), boundaries)
  if (!is.na(outer_date) && any(cutoffs >= outer_date)) {
    stop("Phase 12 inner OOF cutoff is not strictly before the outer tournament opener", call. = FALSE)
  }
  invisible(TRUE)
}

#' Assemble one candidate/track's strictly prior inner OOF rows.
#' @export
assemble_phase12_inner_oof <- function(
    predictions, fixtures, boundaries, candidate_id, track_id, outer_edition_id,
    freeze_manifest = "data/benchmark/phase12/freeze_manifest.csv"
) {
  freeze <- phase12_inner_oof_freeze(freeze_manifest)
  if (!is.data.frame(predictions) || !is.data.frame(fixtures) || !is.data.frame(boundaries)) {
    stop("Phase 12 inner OOF inputs must be data frames", call. = FALSE)
  }
  prediction_required <- c("candidate_id", "track_id", "edition_id", "fixture_id")
  fixture_required <- c("edition_id", "fixture_id", "actual_completion_date", "boundary_id")
  boundary_required <- c("boundary_id", "edition_id", "track", "assessment_date", "evidence_cutoff_exclusive")
  for (spec in list(prediction_required, fixture_required, boundary_required)) {
    data <- if (identical(spec, prediction_required)) predictions else if (identical(spec, fixture_required)) fixtures else boundaries
    missing <- setdiff(spec, names(data))
    if (length(missing)) stop("Phase 12 inner OOF input missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  guard_benchmark_purpose(fixtures, purpose = "calibration")
  if (any(benchmark_holdout_rows(predictions)) || any(benchmark_holdout_rows(fixtures)) || any(benchmark_holdout_rows(boundaries))) {
    stop("Phase 12 calibration rejects WC2026 holdout rows", call. = FALSE)
  }
  if (anyDuplicated(as.character(predictions$fixture_id)) || anyDuplicated(as.character(fixtures$fixture_id))) {
    stop("Phase 12 inner OOF inputs require unique fixture identities", call. = FALSE)
  }
  if (any(as.character(predictions$candidate_id) != as.character(candidate_id)) ||
      any(as.character(predictions$track_id) != as.character(track_id))) {
    stop("Phase 12 predictions contain mixed candidate or track identities", call. = FALSE)
  }
  if (!all(as.character(predictions$fixture_id) %in% as.character(fixtures$fixture_id))) {
    stop("Phase 12 predictions reference fixtures outside the supplied registry", call. = FALSE)
  }
  if (any(as.character(fixtures$fixture_id) %in% as.character(predictions$fixture_id) &
          as.character(fixtures$edition_id[match(as.character(fixtures$fixture_id), as.character(predictions$fixture_id))]) !=
          as.character(predictions$edition_id[match(as.character(fixtures$fixture_id), as.character(predictions$fixture_id))]))) {
    stop("Phase 12 prediction and fixture edition identities do not match", call. = FALSE)
  }
  boundary_scope <- boundaries[as.character(boundaries$edition_id) %in% unique(as.character(fixtures$edition_id)), , drop = FALSE]
  assert_benchmark_cutoffs(fixtures, boundary_scope)
  if (!nrow(predictions)) {
    empty <- data.frame(matrix(nrow = 0L, ncol = length(phase12_inner_oof_required)))
    names(empty) <- phase12_inner_oof_required
    return(empty)
  }
  raw_names <- if (all(c("p_home_raw", "p_draw_raw", "p_away_raw") %in% names(predictions))) {
    c("p_home_raw", "p_draw_raw", "p_away_raw")
  } else if (all(c("p_home", "p_draw", "p_away") %in% names(predictions))) {
    c("p_home", "p_draw", "p_away")
  } else stop("Phase 12 predictions require raw 1X2 probability columns", call. = FALSE)
  index <- match(as.character(predictions$fixture_id), as.character(fixtures$fixture_id))
  boundary_index <- match(as.character(fixtures$boundary_id[index]), as.character(boundary_scope$boundary_id))
  if (anyNA(boundary_index) || any(as.character(boundary_scope$track[boundary_index]) != "updating")) {
    stop("Phase 12 inner OOF requires registered updating boundaries", call. = FALSE)
  }
  result <- data.frame(
    candidate_id = as.character(candidate_id), track_id = as.character(track_id),
    outer_edition_id = as.character(outer_edition_id),
    inner_edition_id = as.character(predictions$edition_id),
    fixture_id = as.character(predictions$fixture_id),
    boundary_id = as.character(fixtures$boundary_id[index]),
    evidence_cutoff_exclusive = as.Date(boundary_scope$evidence_cutoff_exclusive[boundary_index]),
    observed_class = if ("observed_class" %in% names(predictions)) as.character(predictions$observed_class) else NA_character_,
    p_home_raw = as.numeric(predictions[[raw_names[[1L]]]]), p_draw_raw = as.numeric(predictions[[raw_names[[2L]]]]),
    p_away_raw = as.numeric(predictions[[raw_names[[3L]]]]),
    source_prediction_sha256 = if ("source_prediction_sha256" %in% names(predictions)) as.character(predictions$source_prediction_sha256) else rep(NA_character_, nrow(predictions)),
    max_evidence_date = if ("max_evidence_date" %in% names(predictions)) as.Date(predictions$max_evidence_date) else rep(as.Date(NA), nrow(predictions)),
    stringsAsFactors = FALSE
  )
  if (anyNA(result$observed_class)) {
    goal_columns <- c("regulation_home_goals", "regulation_away_goals")
    if (!all(goal_columns %in% names(fixtures))) stop("Phase 12 OOF requires observed_class or regulation goal labels", call. = FALSE)
    home <- as.numeric(fixtures[[goal_columns[[1L]]]][index]); away <- as.numeric(fixtures[[goal_columns[[2L]]]][index])
    result$observed_class <- ifelse(home > away, "home", ifelse(home < away, "away", "draw"))
  }
  missing_hash <- is.na(result$source_prediction_sha256) | !grepl("^[0-9a-fA-F]{64}$", result$source_prediction_sha256)
  if (any(missing_hash)) {
    result$source_prediction_sha256[missing_hash] <- vapply(which(missing_hash), function(i) {
      phase12_inner_oof_prediction_hash(predictions[i, , drop = FALSE])
    }, character(1))
  }
  missing_date <- is.na(result$max_evidence_date)
  if (any(missing_date) && "evidence_date" %in% names(predictions)) result$max_evidence_date[missing_date] <- as.Date(predictions$evidence_date[missing_date])
  if (any(is.na(result$max_evidence_date))) stop("Phase 12 predictions require maximum evidence dates", call. = FALSE)
  validate_phase12_inner_oof_chronology(result, candidate_id, track_id, outer_edition_id, boundary_scope)
  result <- result[order(result$inner_edition_id, result$evidence_cutoff_exclusive, result$fixture_id, method = "radix"), , drop = FALSE]
  rownames(result) <- NULL
  attr(result, "phase12_freeze_id") <- as.character(freeze$freeze_id[[1L]])
  attr(result, "phase12_recipe_sha256") <- as.character(freeze$recipe_sha256[[1L]])
  result
}
