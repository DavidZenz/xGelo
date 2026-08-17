#' Phase 12 completion metadata and atomic release installation.

phase12_release_completion_manifest_row <- function(staged_root, relative_path, role) {
  path <- phase12_release_path_under_root(staged_root, relative_path, must_work = TRUE)
  row_count <- if (endsWith(relative_path, ".csv")) nrow(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)) else ""
  hash <- phase12_release_file_sha256(path)
  data.frame(
    artifact = relative_path, relative_path = relative_path, artifact_role = role,
    sha256 = hash, canonical_content_sha256 = hash,
    rows = as.character(row_count), bytes = as.character(file.info(path)$size),
    labels_embedded = "FALSE", stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase12_release_update_manifest_with_metadata <- function(staged_root) {
  manifest_path <- phase12_release_path_under_root(staged_root, "release_manifest.csv", must_work = TRUE)
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  if (any(c("limitations.md", "reproducibility.json") %in% as.character(manifest$artifact))) {
    stop("Phase 12 release completion metadata is already published", call. = FALSE)
  }
  self <- manifest[manifest$artifact == "release_manifest.csv", , drop = FALSE]
  body <- manifest[manifest$artifact != "release_manifest.csv", , drop = FALSE]
  for (index in seq_len(nrow(body))) {
    relative_path <- as.character(body$relative_path[[index]])
    artifact <- phase12_release_completion_manifest_row(
      staged_root,
      relative_path,
      as.character(body$artifact_role[[index]])
    )
    for (column in intersect(names(body), names(artifact))) {
      body[[column]][[index]] <- as.character(artifact[[column]][[1L]])
    }
  }
  template <- body[1L, , drop = FALSE]
  metadata_rows <- lapply(c("limitations.md", "reproducibility.json"), function(relative_path) {
    row <- template
    row[,] <- ""
    row$schema_version <- "phase12-release-manifest-v1"
    row$release_id <- as.character(self$release_id[[1L]])
    row$status <- as.character(self$status[[1L]])
    row$selected_model_id <- as.character(self$selected_model_id[[1L]])
    row$candidate_id <- as.character(self$candidate_id[[1L]])
    row$incumbent_id <- as.character(self$incumbent_id[[1L]])
    row$track_id <- as.character(self$track_id[[1L]])
    row$panel_id <- as.character(self$panel_id[[1L]])
    row$score_support_g <- as.character(self$score_support_g[[1L]])
    row$primary_probability_view <- as.character(self$primary_probability_view[[1L]])
    row$raw_fallback_status <- as.character(self$raw_fallback_status[[1L]])
    row$decision_sha256 <- as.character(self$decision_sha256[[1L]])
    row$freeze_id <- as.character(self$freeze_id[[1L]])
    row$artifact <- relative_path
    row$relative_path <- relative_path
    row$artifact_role <- "metadata"
    artifact <- phase12_release_completion_manifest_row(staged_root, relative_path, "metadata")
    for (column in intersect(names(row), names(artifact))) row[[column]] <- as.character(artifact[[column]])
    row$manifest_self_sha256 <- ""
    row
  })
  body <- rbind(body, do.call(rbind, metadata_rows))
  body[] <- lapply(body, function(value) { value <- as.character(value); value[is.na(value)] <- ""; value })
  self[] <- lapply(self, function(value) { value <- as.character(value); value[is.na(value)] <- ""; value })
  self$sha256 <- phase12_release_manifest_body_hash(body)
  self$canonical_content_sha256 <- self$sha256
  self$manifest_self_sha256 <- self$sha256
  manifest <- rbind(body, self)
  manifest <- manifest[order(manifest$artifact, method = "radix"), , drop = FALSE]
  phase12_release_write_csv(manifest, manifest_path)
  invisible(manifest)
}

phase12_release_complete_no_label_content <- function(path) {
  phase12_release_no_label_content(path, basename(path))
  invisible(TRUE)
}

#' Add the Plan 08 metadata to a validated core release.
#' @export
complete_phase12_release_bundle <- function(staged_root, final_decision = NULL, runtime_metadata = list()) {
  staged_root <- normalizePath(staged_root, winslash = "/", mustWork = TRUE)
  core <- validate_phase12_release_bundle(staged_root)
  if (!is.null(final_decision)) {
    decision <- phase12_release_normalize_decision(final_decision)
    if (!identical(decision$status, core$status) || !identical(decision$selected_id, core$selected_model_id) || !identical(decision$decision_sha256, as.character(core$release_manifest$decision_sha256[[1L]]))) {
      stop("Phase 12 completion decision does not match the staged core release", call. = FALSE)
    }
  }
  limitations <- c(
    "# Release limitations", "", paste0("Release: `", core$release_manifest$release_id[[1L]], "`"),
    paste0("Status: `", core$status, "`"),
    "The release is a pre-tournament forecast contract and should not be interpreted as causal evidence.",
    if (identical(core$primary_probability_view, "calibrated_1x2")) {
      paste(
        "The fitted development-only calibrator supplies the primary calibrated 1X2 view;",
        "the incumbent raw 1X2 view remains audit evidence and the score distribution is unchanged."
      )
    } else {
      "The retained incumbent uses the raw 1X2 probability view; the challenger calibration remains audit evidence only."
    },
    "The fitted scoreline support remains capped at G=40, and no match outcome labels are exposed to consumers.",
    "Structural and optional-context inputs are not consumer authority unless a later release explicitly promotes them."
  )
  phase12_release_write_text(limitations, file.path(staged_root, "limitations.md"))
  metadata <- runtime_metadata
  if (!is.list(metadata)) stop("Phase 12 runtime metadata must be a list", call. = FALSE)
  metadata$schema_version <- "phase12-release-reproducibility-v1"
  metadata$release_id <- core$release_manifest$release_id[[1L]]
  metadata$release_status <- core$status
  metadata$selected_model_id <- core$selected_model_id
  metadata$track_id <- as.character(core$release_manifest$track_id[[1L]])
  metadata$score_support_g <- 40L
  metadata$generated_at_utc <- format(Sys.time(), tz = "UTC", usetz = TRUE)
  metadata$labels_embedded <- FALSE
  metadata$r_version <- paste(R.version$major, R.version$minor, sep = ".")
  metadata$platform <- R.version$platform
  contract_path <- file.path(staged_root, "model_contract.json")
  contract <- phase12_release_read_contract(contract_path)
  for (field in c(
    "source_release_id", "source_release_manifest_sha256", "model_sha256",
    "model_data_cutoff", "support_max", "raw_probability_view",
    "primary_probability_view", "calibration_data_cutoff", "calibrator_id",
    "calibrator_sha256", "source_calibrator_sha256", "calibration_gate_id",
    "calibration_gate_sha256", "code_commit", "protocol_sha256",
    "calibration_recipe_sha256"
  )) {
    if (!is.null(contract[[field]])) metadata[[field]] <- contract[[field]]
  }
  phase12_release_write_json(metadata, file.path(staged_root, "reproducibility.json"))
  contract$limitations_artifact <- "limitations.md"
  contract$limitations_sha256 <- phase12_release_file_sha256(
    file.path(staged_root, "limitations.md")
  )
  contract$reproducibility_artifact <- "reproducibility.json"
  contract$reproducibility_sha256 <- phase12_release_file_sha256(
    file.path(staged_root, "reproducibility.json")
  )
  phase12_release_write_json(contract, contract_path)
  phase12_release_update_manifest_with_metadata(staged_root)
  validate_phase12_complete_release_bundle(staged_root)
  normalizePath(staged_root, winslash = "/", mustWork = TRUE)
}

#' Validate a completed core release including Plan 08 metadata.
#' @export
validate_phase12_complete_release_bundle <- function(staged_root, load_models = TRUE) {
  result <- validate_phase12_release_bundle(staged_root, load_models = load_models)
  manifest <- result$release_manifest
  calibrated_revision <- identical(result$primary_probability_view, "calibrated_1x2") &&
    all(phase14_release_calibration_v2_artifacts() %in% as.character(manifest$artifact))
  complete_artifacts <- phase12_release_complete_artifacts(calibrated_revision)
  if (!setequal(as.character(manifest$artifact), complete_artifacts) ||
      nrow(manifest) != length(complete_artifacts)) {
    stop("Phase 12 release completion artifact set is incomplete", call. = FALSE)
  }
  for (relative_path in c("limitations.md", "reproducibility.json")) {
    path <- phase12_release_path_under_root(staged_root, relative_path, must_work = TRUE)
    row <- manifest[manifest$artifact == relative_path, , drop = FALSE]
    if (nrow(row) != 1L || !identical(tolower(as.character(row$sha256)), phase12_release_file_sha256(path))) stop("Phase 12 completion metadata hash mismatch: ", relative_path, call. = FALSE)
    phase12_release_complete_no_label_content(path)
  }
  if (!file.exists(phase12_release_path_under_root(staged_root, "limitations.md", must_work = TRUE))) stop("Phase 12 limitations metadata is missing", call. = FALSE)
  if (!file.exists(phase12_release_path_under_root(staged_root, "reproducibility.json", must_work = TRUE))) stop("Phase 12 reproducibility metadata is missing", call. = FALSE)
  if (isTRUE(calibrated_revision)) {
    contract <- result$model_contract
    required <- c(
      "limitations_artifact", "limitations_sha256",
      "reproducibility_artifact", "reproducibility_sha256"
    )
    if (length(setdiff(required, names(contract))) ||
        !identical(as.character(contract$limitations_artifact), "limitations.md") ||
        !identical(as.character(contract$reproducibility_artifact), "reproducibility.json") ||
        !identical(
          tolower(as.character(contract$limitations_sha256)),
          phase12_release_file_sha256(file.path(staged_root, "limitations.md"))
        ) ||
        !identical(
          tolower(as.character(contract$reproducibility_sha256)),
          phase12_release_file_sha256(file.path(staged_root, "reproducibility.json"))
        )) {
      stop("Phase 14 calibrated release completion metadata identity drifted", call. = FALSE)
    }
  }
  invisible(result)
}

#' Atomically install a completed Phase 12 release, restoring the prior root on failure.
#' @export
install_phase12_release_bundle <- function(
    staged_root, output_dir, validator = validate_phase12_complete_release_bundle
) {
  staged_root <- normalizePath(staged_root, winslash = "/", mustWork = TRUE)
  output_dir <- normalizePath(output_dir, winslash = "/", mustWork = FALSE)
  if (!is.function(validator)) stop("Phase 12 release validator must be a function", call. = FALSE)
  invisible(validator(staged_root))
  if (identical(staged_root, output_dir)) return(invisible(staged_root))
  dir.create(dirname(output_dir), recursive = TRUE, showWarnings = FALSE)
  had_existing <- dir.exists(output_dir)
  backup_root <- NULL
  if (had_existing) {
    backup_root <- tempfile(paste0(".", basename(output_dir), "-backup-"), tmpdir = dirname(output_dir))
    if (!file.rename(output_dir, backup_root)) stop("Could not stage the existing Phase 12 release for replacement", call. = FALSE)
  }
  if (!file.rename(staged_root, output_dir)) {
    if (had_existing) file.rename(backup_root, output_dir)
    stop("Could not install the Phase 12 release bundle", call. = FALSE)
  }
  tryCatch({
    invisible(validator(output_dir))
    if (had_existing && dir.exists(backup_root)) unlink(backup_root, recursive = TRUE)
    invisible(output_dir)
  }, error = function(error) {
    if (dir.exists(output_dir)) unlink(output_dir, recursive = TRUE)
    restored <- !had_existing || file.rename(backup_root, output_dir)
    if (!restored) stop("Phase 12 release validation failed and the accepted release could not be restored: ", conditionMessage(error), call. = FALSE)
    stop(error)
  })
}
