#' Core Phase 12 release publisher and fail-closed validator.
#'
#' Plan 06 owns the core release files.  Completion metadata and installation
#' are deliberately kept in R/release/release_install.R so the two publication
#' boundaries remain independently reviewable.

phase12_release_required_artifacts <- function() {
  c(
    "release_manifest.csv",
    "model_contract.json",
    "model/approved_model.rds",
    "model/calibrator.rds",
    "manifests/freeze_manifest.csv",
    "manifests/final_evaluation_manifest.csv",
    "manifests/provenance.json",
    "reports/benchmark_report.md",
    "reports/model_card.md"
  )
}

phase12_release_complete_artifacts <- function() {
  c(phase12_release_required_artifacts(), "limitations.md", "reproducibility.json")
}

phase12_release_project_root <- function(project_root = ".") {
  normalizePath(project_root, winslash = "/", mustWork = TRUE)
}

phase12_release_resolve_path <- function(path, project_root = ".", must_work = FALSE) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    stop("Phase 12 release path must be one non-empty value", call. = FALSE)
  }
  root <- phase12_release_project_root(project_root)
  value <- if (grepl("^/", path)) path else file.path(root, path)
  normalizePath(value, winslash = "/", mustWork = must_work)
}

phase12_release_file_sha256 <- function(path) {
  if (!file.exists(path)) stop("Phase 12 release artifact is missing: ", path, call. = FALSE)
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Phase 12 release hashes", call. = FALSE)
  digest::digest(path, algo = "sha256", file = TRUE)
}

phase12_release_input_table <- function(value, name, project_root = ".") {
  if (is.data.frame(value)) return(value)
  path <- phase12_release_resolve_path(value, project_root, must_work = TRUE)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
}

phase12_release_scalar <- function(value, fallback = "") {
  if (is.null(value) || !length(value) || is.na(value[[1L]])) return(fallback)
  value <- value[[1L]]
  if (is.logical(value)) return(ifelse(isTRUE(value), "TRUE", "FALSE"))
  if (is.numeric(value)) return(format(value, digits = 17, scientific = FALSE, trim = TRUE))
  as.character(value)
}

phase12_release_first_value <- function(data, candidates, fallback = "") {
  for (column in candidates) {
    if (column %in% names(data)) {
      values <- as.character(data[[column]])
      values <- values[!is.na(values) & nzchar(values)]
      if (length(values)) return(values[[1L]])
    }
  }
  fallback
}

phase12_release_write_csv <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  staged <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
  on.exit(if (file.exists(staged)) unlink(staged), add = TRUE)
  utils::write.csv(data, staged, row.names = FALSE, na = "", quote = TRUE)
  if (!file.rename(staged, path)) stop("Could not publish Phase 12 release CSV: ", path, call. = FALSE)
  invisible(path)
}

phase12_release_write_text <- function(text, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  staged <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
  on.exit(if (file.exists(staged)) unlink(staged), add = TRUE)
  writeLines(enc2utf8(as.character(text)), staged, useBytes = TRUE)
  if (!file.rename(staged, path)) stop("Could not publish Phase 12 release text: ", path, call. = FALSE)
  invisible(path)
}

phase12_release_write_rds <- function(value, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  staged <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
  on.exit(if (file.exists(staged)) unlink(staged), add = TRUE)
  saveRDS(value, staged, version = 3L, compress = FALSE)
  if (!file.rename(staged, path)) stop("Could not publish Phase 12 release RDS: ", path, call. = FALSE)
  invisible(path)
}

phase12_release_write_json <- function(value, path) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required for Phase 12 release metadata", call. = FALSE)
  phase12_release_write_text(
    jsonlite::toJSON(value, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "string", digits = 17),
    path
  )
}

phase12_release_table_hash <- function(data) {
  path <- tempfile("phase12-release-table-", fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  phase12_release_write_csv(data, path)
  phase12_release_file_sha256(path)
}

phase12_release_safe_relative_path <- function(path) {
  path <- gsub("\\\\", "/", as.character(path))
  if (length(path) != 1L || is.na(path) || !nzchar(path) || grepl("^/", path) || grepl("(^|/)\\.\\.?(/|$)", path)) {
    stop("Phase 12 release artifact path is unsafe: ", path, call. = FALSE)
  }
  normalized <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (identical(normalized, ".") || grepl("^/", normalized) || !identical(normalized, path)) {
    stop("Phase 12 release artifact path is not a trusted relative path: ", path, call. = FALSE)
  }
  path
}

phase12_release_path_under_root <- function(root, relative_path, must_work = TRUE) {
  relative_path <- phase12_release_safe_relative_path(relative_path)
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  candidate <- normalizePath(file.path(root, relative_path), winslash = "/", mustWork = FALSE)
  prefix <- paste0(root, "/")
  if (!startsWith(candidate, prefix)) stop("Phase 12 release path escapes the trusted root", call. = FALSE)
  if (must_work && !file.exists(candidate)) stop("Phase 12 release artifact is missing: ", relative_path, call. = FALSE)
  candidate
}

phase12_release_decision_rows <- function(final_decision) {
  if (is.character(final_decision) && length(final_decision) == 1L) {
    final_decision <- phase12_release_input_table(final_decision, "final decision")
  }
  if (is.list(final_decision) && !is.data.frame(final_decision) && !is.null(final_decision$candidate_evaluations)) {
    return(final_decision$candidate_evaluations)
  }
  if (is.data.frame(final_decision)) return(final_decision)
  stop("Phase 12 final decision must be a promotion data frame, path, or evaluator result", call. = FALSE)
}

phase12_release_normalize_decision <- function(final_decision) {
  rows <- phase12_release_decision_rows(final_decision)
  if (!nrow(rows)) stop("Phase 12 final decision is empty", call. = FALSE)
  status <- phase12_release_first_value(rows, c("release_decision", "status"))
  selected <- phase12_release_first_value(rows, c("selected_id", "selected_model_id"))
  incumbent <- phase12_release_first_value(rows, c("incumbent_id"), "open_nb_incumbent")
  if (!nzchar(selected)) {
    selected <- if (identical(status, "incumbent retained")) incumbent else phase12_release_first_value(rows, c("candidate_id"))
  }
  if (!identical(status, "approved") && !identical(status, "challenger approved") && !identical(status, "incumbent retained")) {
    stop("Phase 12 release decision has unsupported status: ", status, call. = FALSE)
  }
  if (identical(status, "challenger approved")) status <- "approved"
  if (!nzchar(selected)) stop("Phase 12 release decision has no selected model identity", call. = FALSE)
  decision_hash <- phase12_release_first_value(rows, c("decision_sha256", "promotion_decision_sha256"))
  if (!grepl("^[0-9a-fA-F]{64}$", decision_hash)) {
    material <- rows[, setdiff(names(rows), c("decision_sha256", "promotion_decision_sha256")), drop = FALSE]
    decision_hash <- digest::digest(paste(capture.output(utils::write.csv(material, stdout(), row.names = FALSE, na = "", quote = TRUE)), status, selected, sep = "\n"), algo = "sha256", serialize = FALSE)
  }
  list(
    status = status, selected_id = selected, incumbent_id = incumbent,
    decision_sha256 = tolower(decision_hash), rows = rows
  )
}

phase12_release_contract_identity <- function(decision, freeze, final_evaluation) {
  selected <- decision$selected_id
  freeze_row <- if ("candidate_id" %in% names(freeze)) freeze[as.character(freeze$candidate_id) == selected, , drop = FALSE] else freeze[0, , drop = FALSE]
  final_row <- if ("candidate_id" %in% names(final_evaluation)) final_evaluation[as.character(final_evaluation$candidate_id) == selected, , drop = FALSE] else final_evaluation[0, , drop = FALSE]
  if (!nrow(freeze_row)) freeze_row <- freeze[1L, , drop = FALSE]
  if (!nrow(final_row)) final_row <- final_evaluation[1L, , drop = FALSE]
  list(
    track_id = phase12_release_first_value(final_row, c("track_id"), phase12_release_first_value(freeze_row, c("track_id"), "updating")),
    panel_id = phase12_release_first_value(freeze_row, c("panel_id", "native_panel_id", "panel"), "open_core"),
    feature_set_id = phase12_release_first_value(freeze_row, c("feature_set_id", "rf_feature_set_id"), "baseline_goal_predictors_v1"),
    settings_sha256 = phase12_release_first_value(freeze_row, c("settings_sha256")),
    registration_sha256 = phase12_release_first_value(freeze_row, c("registration_sha256", "candidate_registration_sha256")),
    freeze_id = phase12_release_first_value(freeze_row, c("freeze_id"), "phase12_freeze_v1"),
    score_support_g = as.integer(phase12_release_first_value(freeze_row, c("score_support_g", "score_support"), "40")),
    primary_probability_view = if (identical(decision$status, "incumbent retained")) "raw_1x2" else phase12_release_first_value(final_row, c("primary_probability_view"), "calibrated_1x2")
  )
}

phase12_release_manifest_body_hash <- function(manifest) {
  body <- manifest
  if ("artifact" %in% names(body)) body <- body[body$artifact != "release_manifest.csv", , drop = FALSE]
  if ("artifact" %in% names(body)) body <- body[order(body$artifact, method = "radix"), , drop = FALSE]
  if ("manifest_self_sha256" %in% names(body)) body$manifest_self_sha256 <- ""
  body[] <- lapply(body, function(value) {
    value <- as.character(value)
    value[is.na(value)] <- ""
    value
  })
  path <- tempfile("phase12-release-manifest-", fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  utils::write.csv(body, path, row.names = FALSE, na = "", quote = TRUE)
  phase12_release_file_sha256(path)
}

phase12_release_artifact_rows <- function(staged_root, metadata) {
  paths <- phase12_release_required_artifacts()
  paths <- setdiff(paths, "release_manifest.csv")
  rows <- lapply(paths, function(relative_path) {
    path <- phase12_release_path_under_root(staged_root, relative_path, must_work = TRUE)
    row_count <- if (grepl("\\.csv$", relative_path)) nrow(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)) else NA_integer_
    hash <- phase12_release_file_sha256(path)
    data.frame(
      schema_version = "phase12-release-manifest-v1",
      release_id = metadata$release_id, status = metadata$status,
      selected_model_id = metadata$selected_model_id, candidate_id = metadata$candidate_id,
      incumbent_id = metadata$incumbent_id, track_id = metadata$track_id,
      panel_id = metadata$panel_id, score_support_g = as.character(metadata$score_support_g),
      primary_probability_view = metadata$primary_probability_view,
      raw_fallback_status = metadata$raw_fallback_status,
      decision_sha256 = metadata$decision_sha256, freeze_id = metadata$freeze_id,
      artifact = relative_path, relative_path = relative_path,
      artifact_role = if (grepl("^model/", relative_path)) "model" else if (grepl("^manifests/", relative_path)) "manifest" else if (grepl("^reports/", relative_path)) "report" else "contract",
      sha256 = hash, canonical_content_sha256 = hash,
      rows = as.character(row_count), bytes = as.character(file.info(path)$size),
      labels_embedded = "FALSE", manifest_self_sha256 = "",
      stringsAsFactors = FALSE, check.names = FALSE
    )
  })
  do.call(rbind, rows)
}

phase12_release_write_manifest <- function(staged_root, metadata) {
  body <- phase12_release_artifact_rows(staged_root, metadata)
  self_hash <- phase12_release_manifest_body_hash(body)
  self <- body[1L, , drop = FALSE]
  self[,] <- ""
  self$schema_version <- "phase12-release-manifest-v1"
  self$release_id <- metadata$release_id
  self$status <- metadata$status
  self$selected_model_id <- metadata$selected_model_id
  self$candidate_id <- metadata$candidate_id
  self$incumbent_id <- metadata$incumbent_id
  self$track_id <- metadata$track_id
  self$panel_id <- metadata$panel_id
  self$score_support_g <- as.character(metadata$score_support_g)
  self$primary_probability_view <- metadata$primary_probability_view
  self$raw_fallback_status <- metadata$raw_fallback_status
  self$decision_sha256 <- metadata$decision_sha256
  self$freeze_id <- metadata$freeze_id
  self$artifact <- "release_manifest.csv"
  self$relative_path <- "release_manifest.csv"
  self$artifact_role <- "self"
  self$sha256 <- self_hash
  self$canonical_content_sha256 <- self_hash
  self$rows <- ""
  self$bytes <- ""
  self$labels_embedded <- "FALSE"
  self$manifest_self_sha256 <- self_hash
  manifest <- rbind(body, self)
  manifest <- manifest[order(manifest$artifact, method = "radix"), , drop = FALSE]
  phase12_release_write_csv(manifest, file.path(staged_root, "release_manifest.csv"))
  invisible(manifest)
}

phase12_release_no_label_content <- function(path, relative_path) {
  lower_path <- tolower(relative_path)
  if (grepl("(^|/)labels?\\.csv$|wc2026_labels|fixture_results", lower_path)) {
    stop("Phase 12 release contains a forbidden label artifact: ", relative_path, call. = FALSE)
  }
  if (grepl("\\.csv$", lower_path)) {
    data <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
    outcome_columns <- intersect(names(data), c("home_goals", "away_goals", "regulation_home_goals", "regulation_away_goals", "winner", "result_type"))
    if (length(outcome_columns)) {
      populated <- vapply(data[outcome_columns], function(value) any(!is.na(value) & nzchar(as.character(value))), logical(1))
      if (any(populated)) stop("Phase 12 release contains label-bearing CSV content: ", relative_path, call. = FALSE)
    }
  }
  if (!grepl("\\.rds$", lower_path)) {
    raw <- rawToChar(readBin(path, what = "raw", n = file.info(path)$size))
    if (grepl("wc2026_labels\\.csv|regulation_home_goals|regulation_away_goals", tolower(raw), fixed = FALSE)) {
      stop("Phase 12 release contains label-bearing text content: ", relative_path, call. = FALSE)
    }
  } else {
    # RDS is validated by readRDS() after the path and file hash checks.  It
    # may legitimately contain historical response vectors, so binary text
    # scanning would both be unsafe and over-broad at this boundary.
    invisible(TRUE)
  }
  invisible(TRUE)
}

phase12_release_read_contract <- function(path) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required for Phase 12 release validation", call. = FALSE)
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}

phase12_release_require_single <- function(value, name) {
  if (length(value) != 1L || is.null(value) || is.na(value) || !nzchar(as.character(value))) stop("Phase 12 release contract requires ", name, call. = FALSE)
  as.character(value)
}

#' Validate the core staged release before completion or installation.
#' @export
validate_phase12_release_bundle <- function(staged_root, load_models = TRUE) {
  if (length(load_models) != 1L || is.na(load_models) || !is.logical(load_models)) {
    stop("Phase 12 release load_models must be one logical value", call. = FALSE)
  }
  staged_root <- normalizePath(staged_root, winslash = "/", mustWork = TRUE)
  manifest_path <- phase12_release_path_under_root(staged_root, "release_manifest.csv", must_work = TRUE)
  contract_path <- phase12_release_path_under_root(staged_root, "model_contract.json", must_work = TRUE)
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  required_columns <- c("schema_version", "release_id", "status", "selected_model_id", "candidate_id", "incumbent_id", "track_id", "panel_id", "score_support_g", "primary_probability_view", "raw_fallback_status", "decision_sha256", "freeze_id", "artifact", "relative_path", "artifact_role", "sha256", "canonical_content_sha256", "labels_embedded", "manifest_self_sha256")
  missing <- setdiff(required_columns, names(manifest))
  if (length(missing)) stop("Phase 12 release manifest is missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (anyDuplicated(manifest$artifact) || anyDuplicated(manifest$relative_path)) stop("Phase 12 release manifest contains duplicate artifacts or paths", call. = FALSE)
  allowed_artifacts <- phase12_release_complete_artifacts()
  if (!setequal(intersect(as.character(manifest$artifact), phase12_release_required_artifacts()), phase12_release_required_artifacts()) || any(!as.character(manifest$artifact) %in% allowed_artifacts)) stop("Phase 12 release manifest core artifact set drifted", call. = FALSE)
  if (nrow(manifest) < length(phase12_release_required_artifacts())) stop("Phase 12 release manifest has an incomplete core artifact set", call. = FALSE)
  if (sum(manifest$artifact_role == "self") != 1L || manifest$artifact[manifest$artifact_role == "self"] != "release_manifest.csv") stop("Phase 12 release self-manifest row is invalid", call. = FALSE)
  if (!identical(phase12_release_manifest_body_hash(manifest), tolower(as.character(manifest$manifest_self_sha256[manifest$artifact == "release_manifest.csv"])))) stop("Phase 12 release manifest self-hash mismatch", call. = FALSE)
  metadata_columns <- c("release_id", "status", "selected_model_id", "candidate_id", "incumbent_id", "track_id", "panel_id", "score_support_g", "primary_probability_view", "raw_fallback_status", "decision_sha256", "freeze_id")
  for (column in metadata_columns) if (length(unique(as.character(manifest[[column]]))) != 1L) stop("Phase 12 release manifest metadata drifted: ", column, call. = FALSE)
  metadata <- as.list(manifest[1L, metadata_columns, drop = FALSE])
  metadata <- lapply(metadata, phase12_release_scalar)
  status <- metadata$status
  if (!status %in% c("approved", "incumbent retained")) stop("Phase 12 release status is not approved or incumbent retained", call. = FALSE)
  if (!grepl("^[0-9a-f]{64}$", tolower(metadata$decision_sha256))) stop("Phase 12 release decision identity is invalid", call. = FALSE)
  if (!identical(metadata$track_id, "updating")) stop("Phase 12 release track must be updating", call. = FALSE)
  if (!identical(metadata$panel_id, "open_core")) stop("Phase 12 release panel must be open_core", call. = FALSE)
  if (!identical(as.integer(metadata$score_support_g), 40L)) stop("Phase 12 release score support must be G=40", call. = FALSE)
  if (!metadata$primary_probability_view %in% c("raw_1x2", "calibrated_1x2")) stop("Phase 12 release primary probability view is unsupported", call. = FALSE)
  if (identical(status, "incumbent retained") && !identical(metadata$selected_model_id, "open_nb_incumbent")) stop("Incumbent-retained release must select open_nb_incumbent", call. = FALSE)
  if (!identical(as.character(manifest$labels_embedded), rep("FALSE", nrow(manifest)))) stop("Phase 12 release label-content flag drifted", call. = FALSE)

  contract <- phase12_release_read_contract(contract_path)
  for (field in c("schema_version", "release_id", "status", "selected_model_id", "incumbent_id", "track_id", "panel_id", "score_support_g", "primary_probability_view", "decision_sha256", "model_artifact", "calibrator_artifact", "labels_embedded")) {
    if (is.null(contract[[field]])) stop("Phase 12 model contract is missing ", field, call. = FALSE)
  }
  if (!is.logical(contract$labels_embedded) || length(contract$labels_embedded) != 1L || is.na(contract$labels_embedded) || !identical(contract$labels_embedded, FALSE)) stop("Phase 12 model contract labels_embedded must be scalar FALSE", call. = FALSE)
  if (!identical(as.character(contract$release_id), metadata$release_id) || !identical(as.character(contract$status), status) || !identical(as.character(contract$selected_model_id), metadata$selected_model_id) || !identical(as.character(contract$incumbent_id), as.character(manifest$incumbent_id[[1L]])) || !identical(as.character(contract$track_id), metadata$track_id) || !identical(as.character(contract$panel_id), metadata$panel_id) || as.integer(contract$score_support_g) != 40L || !identical(as.character(contract$primary_probability_view), metadata$primary_probability_view) || !identical(as.character(contract$decision_sha256), metadata$decision_sha256)) stop("Phase 12 model contract identity drifted", call. = FALSE)
  model_relative_path <- phase12_release_safe_relative_path(contract$model_artifact)
  calibrator_relative_path <- phase12_release_safe_relative_path(contract$calibrator_artifact)
  if (identical(model_relative_path, calibrator_relative_path)) stop("Phase 12 model contract artifact paths must be distinct", call. = FALSE)
  model_path <- phase12_release_path_under_root(staged_root, model_relative_path, must_work = TRUE)
  calibrator_path <- phase12_release_path_under_root(staged_root, calibrator_relative_path, must_work = TRUE)
  model_rows <- manifest[as.character(manifest$relative_path) == model_relative_path, , drop = FALSE]
  calibrator_rows <- manifest[as.character(manifest$relative_path) == calibrator_relative_path, , drop = FALSE]
  if (nrow(model_rows) != 1L || !identical(as.character(model_rows$artifact_role[[1L]]), "model")) stop("Phase 12 model contract model_artifact does not map to one model manifest row", call. = FALSE)
  if (nrow(calibrator_rows) != 1L || !identical(as.character(calibrator_rows$artifact_role[[1L]]), "model")) stop("Phase 12 model contract calibrator_artifact does not map to one model manifest row", call. = FALSE)
  if (!identical(tolower(as.character(model_rows$sha256[[1L]])), phase12_release_file_sha256(model_path)) || !identical(tolower(as.character(model_rows$canonical_content_sha256[[1L]])), phase12_release_file_sha256(model_path))) stop("Phase 12 model artifact hash metadata mismatch", call. = FALSE)
  if (!identical(tolower(as.character(calibrator_rows$sha256[[1L]])), phase12_release_file_sha256(calibrator_path)) || !identical(tolower(as.character(calibrator_rows$canonical_content_sha256[[1L]])), phase12_release_file_sha256(calibrator_path))) stop("Phase 12 calibrator artifact hash metadata mismatch", call. = FALSE)

  for (index in seq_len(nrow(manifest))) {
    row <- manifest[index, , drop = FALSE]
    relative_path <- phase12_release_safe_relative_path(row$relative_path[[1L]])
    if (!identical(as.character(row$artifact[[1L]]), relative_path)) stop("Phase 12 release artifact/path identity drifted", call. = FALSE)
    path <- phase12_release_path_under_root(staged_root, relative_path, must_work = TRUE)
    if (relative_path != "release_manifest.csv") {
      if (!identical(tolower(as.character(row$sha256[[1L]])), phase12_release_file_sha256(path))) stop("Phase 12 release artifact hash mismatch: ", relative_path, call. = FALSE)
      if (!identical(tolower(as.character(row$canonical_content_sha256[[1L]])), phase12_release_file_sha256(path))) stop("Phase 12 release canonical hash mismatch: ", relative_path, call. = FALSE)
      phase12_release_no_label_content(path, relative_path)
    }
  }

  freeze_path <- phase12_release_path_under_root(staged_root, "manifests/freeze_manifest.csv", must_work = TRUE)
  final_path <- phase12_release_path_under_root(staged_root, "manifests/final_evaluation_manifest.csv", must_work = TRUE)
  freeze <- utils::read.csv(freeze_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  final_evaluation <- utils::read.csv(final_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  if (!nrow(freeze) || !nrow(final_evaluation)) stop("Phase 12 release copied manifests must be non-empty", call. = FALSE)
  if ("score_support_g" %in% names(freeze) && any(as.integer(freeze$score_support_g) != 40L)) stop("Phase 12 release freeze G drifted", call. = FALSE)
  if ("score_support_g" %in% names(final_evaluation) && any(as.integer(final_evaluation$score_support_g) != 40L)) stop("Phase 12 release final-evaluation G drifted", call. = FALSE)
  if ("track_id" %in% names(final_evaluation) && any(as.character(final_evaluation$track_id) != "updating")) stop("Phase 12 release final-evaluation track drifted", call. = FALSE)
  if (!"promotion_decision_sha256" %in% names(final_evaluation) || nrow(final_evaluation) != 9L) stop("Phase 12 release promotion report identity is incomplete", call. = FALSE)
  supplied <- as.character(final_evaluation$promotion_decision_sha256)
  if (any(is.na(supplied) | !grepl("^[0-9a-fA-F]{64}$", supplied)) || length(unique(tolower(supplied))) != 1L) stop("Phase 12 release promotion report identity is invalid", call. = FALSE)
  result <- list(
    release_root = staged_root, release_manifest = manifest, model_contract = contract,
    freeze_manifest = freeze, final_evaluation_manifest = final_evaluation,
    status = status,
    selected_model_id = metadata$selected_model_id, primary_probability_view = metadata$primary_probability_view
  )
  if (isTRUE(load_models)) {
    model_object <- readRDS(model_path)
    calibrator <- readRDS(calibrator_path)
    if (!is.null(model_object$model_id) && !identical(as.character(model_object$model_id), metadata$selected_model_id)) stop("Phase 12 approved model identity drifted", call. = FALSE)
    if (!is.null(calibrator$candidate_id) && !identical(as.character(calibrator$candidate_id), metadata$selected_model_id)) stop("Phase 12 calibrator identity drifted", call. = FALSE)
    result$model_object <- model_object
    result$calibrator <- calibrator
  }
  invisible(result)
}

#' Stage and validate the core Phase 12 release bundle.
#' @export
stage_phase12_release_bundle <- function(
    final_decision, final_evaluation_manifest, freeze_manifest,
    model_object, calibrator, release_id, output_root = "outputs/releases"
) {
  release_id <- phase12_release_require_single(release_id, "release_id")
  if (grepl("[/\\\\]", release_id) || grepl("(^|/)\\.\\.?(/|$)", release_id)) stop("Phase 12 release_id must be a single safe directory name", call. = FALSE)
  decision <- phase12_release_normalize_decision(final_decision)
  final_evaluation <- phase12_release_input_table(final_evaluation_manifest, "final evaluation manifest")
  freeze <- phase12_release_input_table(freeze_manifest, "freeze manifest")
  if (!nrow(final_evaluation) || !nrow(freeze)) stop("Phase 12 release evidence manifests must be non-empty", call. = FALSE)
  identity <- phase12_release_contract_identity(decision, freeze, final_evaluation)
  if (identity$score_support_g != 40L) stop("Phase 12 release evidence must use G=40", call. = FALSE)
  if (!identity$track_id %in% c("updating")) stop("Phase 12 release evidence must use the updating track", call. = FALSE)
  root <- phase12_release_resolve_path(output_root, must_work = FALSE)
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  target_root <- file.path(root, release_id)
  if (dir.exists(target_root) || file.exists(target_root)) stop("Phase 12 release target already exists and is immutable: ", target_root, call. = FALSE)
  staged_root <- tempfile(paste0(".", release_id, "-core-"), tmpdir = root)
  dir.create(staged_root, recursive = TRUE, showWarnings = FALSE)
  on.exit(if (dir.exists(staged_root)) unlink(staged_root, recursive = TRUE), add = TRUE)

  phase12_release_write_rds(model_object, file.path(staged_root, "model/approved_model.rds"))
  phase12_release_write_rds(calibrator, file.path(staged_root, "model/calibrator.rds"))
  phase12_release_write_csv(freeze, file.path(staged_root, "manifests/freeze_manifest.csv"))
  phase12_release_write_csv(final_evaluation, file.path(staged_root, "manifests/final_evaluation_manifest.csv"))

  metadata <- list(
    release_id = release_id, status = decision$status,
    selected_model_id = decision$selected_id, candidate_id = decision$selected_id,
    incumbent_id = decision$incumbent_id, track_id = identity$track_id,
    panel_id = identity$panel_id, score_support_g = identity$score_support_g,
    primary_probability_view = identity$primary_probability_view,
    raw_fallback_status = if (identical(identity$primary_probability_view, "raw_1x2")) "available; incumbent retained without a fitted Phase 12 calibrator" else "available",
    decision_sha256 = decision$decision_sha256, freeze_id = identity$freeze_id
  )
  contract <- list(
    schema_version = "phase12-model-contract-v1", release_id = release_id,
    status = decision$status, selected_model_id = decision$selected_id,
    incumbent_id = decision$incumbent_id, challenger_evidence_id = if (identical(decision$status, "incumbent retained")) phase12_release_first_value(decision$rows, c("candidate_id"), "") else "",
    track_id = identity$track_id, panel_id = identity$panel_id,
    feature_set_id = identity$feature_set_id, score_support_g = identity$score_support_g,
    primary_probability_view = identity$primary_probability_view,
    raw_fallback = list(status = metadata$raw_fallback_status, view = "raw_1x2"),
    score_distribution_contract = "fitted G=40 score distribution unchanged",
    decision_sha256 = decision$decision_sha256, freeze_id = identity$freeze_id,
    model_artifact = "model/approved_model.rds", calibrator_artifact = "model/calibrator.rds",
    labels_embedded = FALSE
  )
  phase12_release_write_json(contract, file.path(staged_root, "model_contract.json"))
  provenance <- list(
    schema_version = "phase12-release-provenance-v1", release_id = release_id,
    status = decision$status, selected_model_id = decision$selected_id,
    track_id = identity$track_id, panel_id = identity$panel_id,
    score_support_g = identity$score_support_g, decision_sha256 = decision$decision_sha256,
    freeze_manifest_sha256 = phase12_release_table_hash(freeze),
    final_evaluation_manifest_sha256 = phase12_release_table_hash(final_evaluation),
    decision_evidence_sha256 = phase12_release_table_hash(decision$rows),
    source_boundary = "final decision evidence only; holdout labels are not copied into the release",
    generated_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), labels_embedded = FALSE
  )
  phase12_release_write_json(provenance, file.path(staged_root, "manifests/provenance.json"))
  report_lines <- c(
    "# Phase 12 benchmark report", "", paste0("- Release: `", release_id, "`"),
    paste0("- Decision: **", decision$status, "**"), paste0("- Selected model: `", decision$selected_id, "`"),
    paste0("- Track/panel: `", identity$track_id, "` / `", identity$panel_id, "`"),
    paste0("- Score support: G=", identity$score_support_g),
    paste0("- Primary probability view: `", identity$primary_probability_view, "`"),
    paste0("- Decision identity: `", decision$decision_sha256, "`"), "",
    "The report contains promotion evidence and release metadata only. Match outcome labels are not part of the consumer-facing release bundle.", "",
    "## Candidate evidence", "",
    capture.output(utils::write.csv(decision$rows, stdout(), row.names = FALSE, na = "", quote = TRUE))
  )
  phase12_release_write_text(report_lines, file.path(staged_root, "reports/benchmark_report.md"))
  model_card <- c(
    "# Phase 12 model card", "", paste0("Model identity: `", decision$selected_id, "`"),
    paste0("Release status: `", decision$status, "`"), paste0("Track: `", identity$track_id, "`"),
    paste0("Panel: `", identity$panel_id, "`"), paste0("Scoreline support: G=", identity$score_support_g),
    paste0("Primary view: `", identity$primary_probability_view, "`"), "",
    "The incumbent is retained when challenger evidence fails a registered gate. Challenger failures remain audit evidence and do not control the consumer model.",
    "The release does not embed FIFA match outcome labels. The scoreline distribution and its G=40 support are unchanged from the evaluated model contract.", "",
    paste0("Decision SHA-256: `", decision$decision_sha256, "`")
  )
  phase12_release_write_text(model_card, file.path(staged_root, "reports/model_card.md"))
  phase12_release_write_manifest(staged_root, metadata)
  validate_phase12_release_bundle(staged_root)
  if (!file.rename(staged_root, target_root)) stop("Could not publish Phase 12 core release bundle", call. = FALSE)
  on.exit(NULL, add = TRUE)
  validate_phase12_release_bundle(target_root)
  normalizePath(target_root, winslash = "/", mustWork = TRUE)
}
