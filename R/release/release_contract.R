#' Approved Phase 12 release resolver and consumer contract.

phase12_release_contract_source_if_missing <- function() {
  required <- c("validate_phase12_release_bundle", "validate_phase12_complete_release_bundle")
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (!length(missing)) return(invisible(TRUE))
  roots <- c(getwd(), file.path(getwd(), "../.."), file.path(getwd(), "../../.."))
  root <- roots[vapply(roots, function(path) file.exists(file.path(path, "R/release/release_bundle.R")), logical(1))][1L]
  if (is.na(root) || !nzchar(root)) stop("Phase 12 release contract could not locate release_bundle.R", call. = FALSE)
  source(file.path(root, "R/release/release_bundle.R"), local = .GlobalEnv)
  source(file.path(root, "R/release/release_install.R"), local = .GlobalEnv)
  invisible(TRUE)
}

phase12_release_contract_source_if_missing()

phase12_release_trusted_root <- function(trusted_root = "outputs/releases") {
  if (length(trusted_root) != 1L || is.na(trusted_root) || !nzchar(as.character(trusted_root))) {
    stop("Phase 12 trusted release root is invalid", call. = FALSE)
  }
  if (!dir.exists(trusted_root) || nzchar(Sys.readlink(trusted_root))) {
    stop("Phase 12 trusted release root does not exist or is not a real directory", call. = FALSE)
  }
  root <- normalizePath(trusted_root, winslash = "/", mustWork = TRUE)
  if (!isTRUE(file.info(root)$isdir) || nzchar(Sys.readlink(root))) {
    stop("Phase 12 trusted release root does not exist or is not a real directory", call. = FALSE)
  }
  root
}

phase12_release_contract_is_symlink <- function(path) {
  link <- Sys.readlink(path)
  length(link) == 1L && !is.na(link) && nzchar(link)
}

phase12_release_contract_assert_under_root <- function(path, root, label) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  normalized <- normalizePath(path, winslash = "/", mustWork = TRUE)
  if (!identical(normalized, root) && !startsWith(normalized, paste0(root, "/"))) {
    stop("Phase 12 ", label, " escapes the trusted root", call. = FALSE)
  }
  normalized
}

phase12_release_contract_manifest_candidates <- function(trusted_root) {
  root <- phase12_release_trusted_root(trusted_root)
  root_manifest <- file.path(root, "release_manifest.csv")
  if (file.exists(root_manifest) && phase12_release_contract_is_symlink(root_manifest)) {
    stop("Phase 12 root release manifest must not be a symlink", call. = FALSE)
  }
  dirs <- list.files(root, full.names = TRUE, all.files = FALSE, no.. = TRUE)
  dirs <- dirs[vapply(dirs, dir.exists, logical(1))]
  if (any(vapply(dirs, phase12_release_contract_is_symlink, logical(1)))) {
    stop("Phase 12 immediate-child release directory must not be a symlink", call. = FALSE)
  }
  manifests <- file.path(dirs, "release_manifest.csv")
  if (any(vapply(manifests[file.exists(manifests)], phase12_release_contract_is_symlink, logical(1)))) {
    stop("Phase 12 child release manifest must not be a symlink", call. = FALSE)
  }
  candidates <- c(root_manifest[file.exists(root_manifest)], manifests[file.exists(manifests)])
  if (!length(candidates)) return(character())
  normalized <- vapply(candidates, function(path) {
    manifest <- phase12_release_contract_assert_under_root(path, root, "release manifest")
    release_dir <- dirname(manifest)
    if (!isTRUE(file.info(release_dir)$isdir) || phase12_release_contract_is_symlink(release_dir)) {
      stop("Phase 12 release directory is not a trusted real directory", call. = FALSE)
    }
    phase12_release_contract_assert_under_root(release_dir, root, "release directory")
    manifest
  }, character(1))
  sort(normalized)
}

phase12_release_contract_path <- function(root, path) {
  path <- phase12_release_safe_relative_path(path)
  phase12_release_path_under_root(root, path, must_work = TRUE)
}

phase12_release_contract_validate_identity <- function(root, manifest, contract) {
  if (!is.data.frame(manifest) || !nrow(manifest)) stop("Phase 12 release manifest is empty", call. = FALSE)
  if (!is.list(contract)) stop("Phase 12 model contract is not valid JSON", call. = FALSE)
  status <- unique(as.character(manifest$status))
  if (length(status) != 1L || !status %in% c("approved", "incumbent retained")) stop("Phase 12 release has no approved or retained status", call. = FALSE)
  if (length(unique(as.character(manifest$selected_model_id))) != 1L || length(unique(as.character(manifest$track_id))) != 1L) stop("Phase 12 release identity is ambiguous", call. = FALSE)
  if (any(as.integer(manifest$score_support_g) != 40L)) stop("Phase 12 release must use G=40", call. = FALSE)
  if (length(unique(as.character(manifest$panel_id))) != 1L || !identical(as.character(manifest$panel_id[[1L]]), "open_core")) stop("Phase 12 release panel identity is invalid", call. = FALSE)
  if (!as.character(manifest$primary_probability_view[[1L]]) %in% c("raw_1x2", "calibrated_1x2")) stop("Phase 12 release primary view is invalid", call. = FALSE)
  if (!is.logical(contract$labels_embedded) || length(contract$labels_embedded) != 1L || is.na(contract$labels_embedded) || !identical(contract$labels_embedded, FALSE)) stop("Phase 12 consumer contract labels_embedded must be scalar FALSE", call. = FALSE)
  required <- c("release_id", "status", "selected_model_id", "incumbent_id", "track_id", "panel_id", "score_support_g", "primary_probability_view", "decision_sha256", "model_artifact", "calibrator_artifact", "labels_embedded")
  if (any(vapply(required, function(name) is.null(contract[[name]]), logical(1)))) stop("Phase 12 model contract is incomplete", call. = FALSE)
  if (!identical(as.character(contract$release_id), as.character(manifest$release_id[[1L]])) || !identical(as.character(contract$status), status) || !identical(as.character(contract$selected_model_id), as.character(manifest$selected_model_id[[1L]])) || !identical(as.character(contract$incumbent_id), as.character(manifest$incumbent_id[[1L]])) || !identical(as.character(contract$track_id), as.character(manifest$track_id[[1L]])) || !identical(as.character(contract$panel_id), "open_core") || as.integer(contract$score_support_g) != 40L || !identical(as.character(contract$primary_probability_view), as.character(manifest$primary_probability_view[[1L]])) || !identical(as.character(contract$decision_sha256), as.character(manifest$decision_sha256[[1L]]))) stop("Phase 12 model contract identity mismatch", call. = FALSE)
  invisible(TRUE)
}

phase12_release_contract_manifest_path <- function(trusted_root, release_manifest_path) {
  if (length(release_manifest_path) != 1L || is.null(release_manifest_path) || is.na(release_manifest_path) || !nzchar(as.character(release_manifest_path))) {
    stop("Phase 12 release manifest path is invalid", call. = FALSE)
  }
  supplied <- as.character(release_manifest_path)
  if (!grepl("^/", supplied)) {
    supplied <- phase12_release_path_under_root(trusted_root, supplied, must_work = TRUE)
  } else {
    supplied <- normalizePath(supplied, winslash = "/", mustWork = TRUE)
    prefix <- paste0(trusted_root, "/")
    if (!startsWith(supplied, prefix)) stop("Phase 12 release manifest path escapes the trusted root", call. = FALSE)
  }
  supplied
}

phase12_release_contract_assert_selected_topology <- function(trusted_root, manifest_path) {
  trusted_root <- phase12_release_trusted_root(trusted_root)
  manifest_path <- phase12_release_contract_assert_under_root(
    manifest_path,
    trusted_root,
    "release manifest"
  )
  release_dir <- dirname(manifest_path)
  if (!identical(basename(manifest_path), "release_manifest.csv") ||
      !identical(dirname(release_dir), trusted_root)) {
    stop(
      "Phase 12 selected release manifest must use exact immediate-child topology",
      call. = FALSE
    )
  }
  if (phase12_release_contract_is_symlink(release_dir) ||
      phase12_release_contract_is_symlink(manifest_path)) {
    stop("Phase 12 selected release path must not be symlinked", call. = FALSE)
  }
  selected_paths <- list.files(
    release_dir,
    recursive = TRUE,
    full.names = TRUE,
    all.files = TRUE,
    include.dirs = TRUE,
    no.. = TRUE
  )
  if (length(selected_paths) &&
      any(vapply(selected_paths, phase12_release_contract_is_symlink, logical(1)))) {
    stop("Phase 12 selected release tree must not contain symlinks", call. = FALSE)
  }
  invisible(list(release_dir = release_dir, manifest_path = manifest_path))
}

phase14_release_selector_hash <- function(selector) {
  projection <- selector
  projection$row_sha256 <- ""
  phase12_release_table_hash(projection)
}

phase14_release_read_selector <- function(selector_path, trusted_release_root) {
  trusted_release_root <- phase12_release_trusted_root(trusted_release_root)
  if (length(selector_path) != 1L || is.null(selector_path) ||
      is.na(selector_path) || !nzchar(as.character(selector_path))) {
    stop("Phase 14 approved release selector path is invalid", call. = FALSE)
  }
  expected_path <- file.path(trusted_release_root, "approved_release.csv")
  if (!file.exists(selector_path)) {
    stop("Phase 14 approved release selector is missing", call. = FALSE)
  }
  if (phase12_release_contract_is_symlink(selector_path)) {
    stop("Phase 14 approved release selector must not be a symlink", call. = FALSE)
  }
  supplied_path <- normalizePath(selector_path, winslash = "/", mustWork = TRUE)
  if (!identical(supplied_path, expected_path)) {
    stop(
      "Phase 14 approved release selector must be approved_release.csv inside the trusted root",
      call. = FALSE
    )
  }
  if (phase12_release_contract_is_symlink(supplied_path)) {
    stop("Phase 14 approved release selector must not be a symlink", call. = FALSE)
  }
  selector <- utils::read.csv(
    supplied_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    colClasses = "character",
    na.strings = character()
  )
  expected_columns <- c(
    "release_id", "release_manifest_path", "manifest_sha256",
    "approved_at_utc", "row_sha256"
  )
  if (nrow(selector) != 1L || !identical(names(selector), expected_columns)) {
    stop("Phase 14 approved release selector must contain one exact row", call. = FALSE)
  }
  if (any(!nzchar(as.character(selector[1L, expected_columns, drop = TRUE])))) {
    stop("Phase 14 approved release selector contains an empty identity", call. = FALSE)
  }
  expected_self_hash <- phase14_release_selector_hash(selector)
  if (!identical(tolower(as.character(selector$row_sha256[[1L]])), expected_self_hash)) {
    stop("Phase 14 approved release selector self-hash mismatch", call. = FALSE)
  }
  release_id <- as.character(selector$release_id[[1L]])
  if (grepl("[/\\\\]", release_id) || grepl("(^|/)\\.\\.?(/|$)", release_id)) {
    stop("Phase 14 approved release selector release identity is unsafe", call. = FALSE)
  }
  relative_manifest <- phase12_release_safe_relative_path(
    as.character(selector$release_manifest_path[[1L]])
  )
  expected_manifest <- paste0(release_id, "/release_manifest.csv")
  if (!identical(relative_manifest, expected_manifest)) {
    stop("Phase 14 approved release selector topology disagrees with release identity", call. = FALSE)
  }
  if (!grepl("^[0-9a-fA-F]{64}$", as.character(selector$manifest_sha256[[1L]])) ||
      !grepl("^[0-9a-fA-F]{64}$", as.character(selector$row_sha256[[1L]]))) {
    stop("Phase 14 approved release selector hash identity is invalid", call. = FALSE)
  }
  manifest_path <- phase12_release_path_under_root(
    trusted_release_root,
    relative_manifest,
    must_work = TRUE
  )
  topology <- phase12_release_contract_assert_selected_topology(
    trusted_release_root,
    manifest_path
  )
  manifest_sha256 <- phase12_release_file_sha256(manifest_path)
  if (!identical(
    manifest_sha256,
    tolower(as.character(selector$manifest_sha256[[1L]]))
  )) {
    stop("Phase 14 approved release selector manifest hash mismatch", call. = FALSE)
  }
  list(
    selector = selector,
    selector_path = supplied_path,
    selector_self_sha256 = expected_self_hash,
    trusted_release_root = trusted_release_root,
    release_dir = topology$release_dir,
    release_manifest_path = topology$manifest_path,
    manifest_sha256 = manifest_sha256
  )
}

phase12_release_contract_read_benchmark_evidence <- function(release_root) {
  path <- phase12_release_contract_path(release_root, "reports/benchmark_report.md")
  lines <- readLines(path, warn = FALSE)
  header <- which(startsWith(trimws(lines), "\"schema_version\",\"candidate_id\""))
  if (length(header) != 1L || header >= length(lines)) stop("Phase 12 benchmark report candidate evidence is missing", call. = FALSE)
  evidence <- tryCatch(
    utils::read.csv(text = paste(lines[header:length(lines)], collapse = "\n"), stringsAsFactors = FALSE, check.names = FALSE, na.strings = ""),
    error = function(error) stop("Phase 12 benchmark report candidate evidence is invalid: ", conditionMessage(error), call. = FALSE)
  )
  if (!nrow(evidence)) stop("Phase 12 benchmark report candidate evidence is empty", call. = FALSE)
  scalar <- function(pattern, label) {
    matches <- regmatches(lines, regexec(pattern, lines, perl = TRUE))
    values <- vapply(matches, function(value) if (length(value) >= 2L) value[[2L]] else "", character(1))
    values <- values[nzchar(values)]
    if (length(values) != 1L) stop("Phase 12 benchmark report is missing ", label, call. = FALSE)
    values[[1L]]
  }
  decision_line <- lines[startsWith(lines, "- Decision: **")]
  selected_line <- lines[startsWith(lines, "- Selected model: `")]
  identity_line <- lines[startsWith(lines, "- Decision identity: `")]
  if (length(decision_line) != 1L || length(selected_line) != 1L || length(identity_line) != 1L) stop("Phase 12 benchmark report decision summary is invalid", call. = FALSE)
  list(
    evidence = evidence,
    status = sub("^- Decision: \\*\\*", "", sub("\\*\\*$", "", decision_line)),
    selected_id = sub("^- Selected model: `", "", sub("`$", "", selected_line)),
    decision_sha256 = sub("^- Decision identity: `", "", sub("`$", "", identity_line))
  )
}

phase12_release_contract_recompute_decision_sha256 <- function(evidence, status, selected_id) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Phase 12 release decision validation", call. = FALSE)
  if (!is.data.frame(evidence) || !nrow(evidence)) stop("Phase 12 decision evidence is empty", call. = FALSE)
  if (length(status) != 1L || !status %in% c("challenger approved", "incumbent retained")) {
    stop("Phase 12 release decision token is invalid", call. = FALSE)
  }
  if (length(selected_id) != 1L || is.na(selected_id) || !nzchar(as.character(selected_id))) {
    stop("Phase 12 selected model identity is invalid", call. = FALSE)
  }
  evidence_csv <- paste(capture.output(utils::write.csv(evidence, stdout(), row.names = FALSE, na = "", quote = TRUE)), collapse = "\n")
  digest::digest(paste(evidence_csv, status, as.character(selected_id), sep = "\n"), algo = "sha256", serialize = FALSE)
}

phase12_release_contract_normalise_report_status <- function(status) {
  if (identical(status, "challenger approved")) "approved" else status
}

phase12_release_contract_validate_candidate_authority <- function(
    release_root, manifest, contract, freeze, final_evaluation, provenance, report
) {
  metadata <- lapply(manifest[1L, c("status", "selected_model_id", "candidate_id", "incumbent_id", "track_id", "freeze_id", "decision_sha256"), drop = FALSE], phase12_release_scalar)
  status <- metadata$status
  selected_id <- metadata$selected_model_id
  candidate_id <- metadata$candidate_id
  incumbent_id <- metadata$incumbent_id
  contract_selected <- as.character(contract$selected_model_id)
  contract_incumbent <- as.character(contract$incumbent_id)
  if (!identical(as.character(contract$status), status) || !identical(contract_selected, selected_id) || !identical(contract_incumbent, incumbent_id)) stop("Phase 12 release candidate identity disagrees with the model contract", call. = FALSE)
  raw_decision <- phase12_release_first_value(report$evidence, c("release_decision"), report$status)
  if (!identical(raw_decision, if (identical(status, "approved")) "challenger approved" else "incumbent retained")) stop("Phase 12 raw release decision token is invalid", call. = FALSE)
  if (!identical(phase12_release_contract_normalise_report_status(report$status), status) || !identical(report$selected_id, selected_id)) stop("Phase 12 bundled benchmark decision identity disagrees with the release", call. = FALSE)
  if (is.null(provenance$decision_evidence_sha256) || !grepl("^[0-9a-fA-F]{64}$", as.character(provenance$decision_evidence_sha256))) stop("Phase 12 release provenance candidate evidence identity is invalid", call. = FALSE)
  recomputed <- phase12_release_contract_recompute_decision_sha256(report$evidence, raw_decision, report$selected_id)
  exact_hash <- identical(tolower(recomputed), tolower(as.character(metadata$decision_sha256))) && identical(tolower(report$decision_sha256), tolower(metadata$decision_sha256)) && identical(tolower(as.character(provenance$decision_sha256)), tolower(as.character(metadata$decision_sha256)))
  legacy_retained <- identical(status, "incumbent retained") && identical(as.character(contract$primary_probability_view), "raw_1x2") && is.null(contract$freeze_self_sha256) && identical(as.character(contract$release_id), "phase12-wc2026-incumbent-retained-v1") && identical(tolower(as.character(provenance$decision_evidence_sha256)), tolower(phase12_release_table_hash(report$evidence)))
  if (!exact_hash && !legacy_retained) stop("Phase 12 embedded promotion decision identity mismatch", call. = FALSE)
  if (!identical(as.character(provenance$decision_sha256), metadata$decision_sha256)) stop("Phase 12 release provenance decision identity mismatch", call. = FALSE)
  if (identical(status, "incumbent retained")) {
    if (!identical(candidate_id, selected_id) || !identical(selected_id, incumbent_id) || !identical(incumbent_id, "open_nb_incumbent")) stop("Phase 12 incumbent-retained candidate identity is invalid", call. = FALSE)
  } else if (identical(status, "approved")) {
    if (!identical(candidate_id, selected_id)) stop("Phase 12 approved candidate identity is invalid", call. = FALSE)
    if (!all(c("candidate_id", "active_status", "score_status", "freeze_id") %in% names(freeze))) stop("Phase 12 freeze candidate authority is incomplete", call. = FALSE)
    freeze_rows <- freeze[as.character(freeze$candidate_id) == selected_id & as.character(freeze$freeze_id) == metadata$freeze_id, , drop = FALSE]
    if (nrow(freeze_rows) != 1L || !isTRUE(as.logical(freeze_rows$active_status[[1L]])) || !identical(tolower(as.character(freeze_rows$score_status[[1L]])), "scored")) stop("Phase 12 approved candidate is not an active scored freeze candidate", call. = FALSE)
    if (!all(c("candidate_id", "track_id", "active_status", "score_status") %in% names(final_evaluation))) stop("Phase 12 final-evaluation candidate authority is incomplete", call. = FALSE)
    final_rows <- final_evaluation[as.character(final_evaluation$candidate_id) == selected_id & as.character(final_evaluation$track_id) == metadata$track_id, , drop = FALSE]
    if (nrow(final_rows) != 1L || !isTRUE(as.logical(final_rows$active_status[[1L]])) || identical(tolower(as.character(final_rows$score_status[[1L]])), "no_score")) stop("Phase 12 approved candidate has no scored final-evaluation evidence", call. = FALSE)
  } else stop("Phase 12 release candidate status is unsupported", call. = FALSE)
  invisible(list(candidate_id = candidate_id, selected_model_id = selected_id, incumbent_id = incumbent_id, status = status, track_id = metadata$track_id, freeze_id = metadata$freeze_id, decision_sha256 = metadata$decision_sha256))
}

phase14_release_contract_validate_calibration_authority <- function(manifest, contract) {
  required <- c(
    "source_release_id", "model_sha256", "calibrator_id", "calibrator_sha256",
    "calibrator_fit_status", "raw_probability_view", "model_data_cutoff",
    "calibration_data_cutoff", "calibration_gate_id",
    "calibration_gate_sha256", "calibration_gate_passed"
  )
  if (length(setdiff(required, names(contract)))) {
    stop("Phase 14 calibrated release authority is incomplete", call. = FALSE)
  }
  metadata <- lapply(
    manifest[1L, c(
      "status", "selected_model_id", "candidate_id", "incumbent_id",
      "track_id", "panel_id", "score_support_g", "primary_probability_view",
      "freeze_id", "decision_sha256"
    ), drop = FALSE],
    phase12_release_scalar
  )
  hash_fields <- c(
    as.character(contract$model_sha256),
    as.character(contract$calibrator_sha256),
    as.character(contract$calibration_gate_sha256)
  )
  model_cutoff <- suppressWarnings(as.Date(as.character(contract$model_data_cutoff)))
  calibration_cutoff <- suppressWarnings(as.Date(as.character(contract$calibration_data_cutoff)))
  if (!identical(metadata$status, "approved") ||
      !identical(metadata$selected_model_id, "open_nb_incumbent") ||
      !identical(metadata$candidate_id, metadata$selected_model_id) ||
      !identical(metadata$incumbent_id, metadata$selected_model_id) ||
      !identical(metadata$track_id, "updating") ||
      !identical(metadata$panel_id, "open_core") ||
      !identical(as.integer(metadata$score_support_g), 40L) ||
      !identical(metadata$primary_probability_view, "calibrated_1x2") ||
      !identical(as.character(contract$raw_probability_view), "raw_1x2") ||
      !identical(as.character(contract$calibrator_fit_status), "fitted") ||
      !isTRUE(contract$calibration_gate_passed) ||
      any(!grepl("^[0-9a-fA-F]{64}$", hash_fields)) ||
      is.na(model_cutoff) || is.na(calibration_cutoff) ||
      calibration_cutoff > model_cutoff) {
    stop("Phase 14 calibrated release authority identity is invalid", call. = FALSE)
  }
  invisible(list(
    candidate_id = metadata$candidate_id,
    selected_model_id = metadata$selected_model_id,
    incumbent_id = metadata$incumbent_id,
    status = metadata$status,
    track_id = metadata$track_id,
    freeze_id = metadata$freeze_id,
    decision_sha256 = metadata$decision_sha256,
    calibration_gate_id = as.character(contract$calibration_gate_id),
    calibration_gate_sha256 = tolower(as.character(contract$calibration_gate_sha256))
  ))
}

#' Validate a release's metadata and candidate authority without reading model RDS files.
#' @export
preflight_phase12_approved_release <- function(trusted_root = NULL, release_manifest_path = NULL) {
  phase12_release_contract_source_if_missing()
  if (is.null(trusted_root)) stop("Phase 12 dashboard release root is required", call. = FALSE)
  trusted_root <- phase12_release_trusted_root(trusted_root)
  if (is.null(release_manifest_path)) {
    candidates <- phase12_release_contract_manifest_candidates(trusted_root)
    if (length(candidates) != 1L) stop("Phase 12 release resolution is ambiguous or missing", call. = FALSE)
    pinned <- phase12_release_contract_assert_under_root(candidates[[1L]], trusted_root, "release manifest")
  } else {
    pinned <- phase12_release_contract_manifest_path(trusted_root, release_manifest_path)
    phase12_release_contract_assert_selected_topology(trusted_root, pinned)
  }
  release_root <- dirname(pinned)
  validated <- validate_phase12_complete_release_bundle(release_root, load_models = FALSE)
  manifest <- validated$release_manifest
  contract <- validated$model_contract
  provenance <- phase12_release_read_contract(phase12_release_contract_path(release_root, "manifests/provenance.json"))
  report <- phase12_release_contract_read_benchmark_evidence(release_root)
  authority <- if (identical(as.character(contract$primary_probability_view), "calibrated_1x2") &&
      !is.null(contract$calibration_gate_id)) {
    phase14_release_contract_validate_calibration_authority(manifest, contract)
  } else {
    phase12_release_contract_validate_candidate_authority(
      release_root, manifest, contract, validated$freeze_manifest,
      validated$final_evaluation_manifest, provenance, report
    )
  }
  result <- list(
    trusted_root = trusted_root, release_root = release_root, release_manifest_path = pinned,
    release_manifest = manifest, model_contract = contract,
    freeze_manifest = validated$freeze_manifest, final_evaluation_manifest = validated$final_evaluation_manifest,
    provenance = provenance, benchmark_report = report, candidate_authority = authority,
    metadata = phase12_release_metadata(list(release_root = release_root, release_manifest = manifest, model_contract = contract))
  )
  result$metadata$candidate_id <- authority$candidate_id
  result$metadata$incumbent_id <- authority$incumbent_id
  result$metadata$freeze_id <- authority$freeze_id
  result
}

#' Validate a resolved release contract, including all hashes, before loading RDS.
#' @export
validate_phase12_release_contract <- function(release_root, release_manifest = NULL, model_contract = NULL, load_models = TRUE) {
  phase12_release_contract_source_if_missing()
  release_root <- normalizePath(release_root, winslash = "/", mustWork = TRUE)
  if (is.null(release_manifest)) release_manifest <- utils::read.csv(file.path(release_root, "release_manifest.csv"), stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  if (is.null(model_contract)) model_contract <- phase12_release_read_contract(file.path(release_root, "model_contract.json"))
  validate_phase12_complete_release_bundle(release_root, load_models = load_models)
  phase12_release_contract_validate_identity(release_root, release_manifest, model_contract)
  invisible(list(release_root = release_root, release_manifest = release_manifest, model_contract = model_contract))
}

#' Resolve exactly one approved or incumbent-retained release.
#' @export
resolve_phase12_approved_release <- function(trusted_root = "outputs/releases", release_manifest_path = NULL, validated_preflight = NULL) {
  phase12_release_contract_source_if_missing()
  fresh_preflight <- preflight_phase12_approved_release(trusted_root, release_manifest_path)
  if (!is.null(validated_preflight)) {
    if (!is.list(validated_preflight) || is.null(validated_preflight$trusted_root) || is.null(validated_preflight$release_root) || is.null(validated_preflight$release_manifest_path) || is.null(validated_preflight$metadata)) {
      stop("Phase 12 validated preflight is invalid", call. = FALSE)
    }
    supplied_paths <- c(
      trusted_root = normalizePath(validated_preflight$trusted_root, winslash = "/", mustWork = TRUE),
      release_root = normalizePath(validated_preflight$release_root, winslash = "/", mustWork = TRUE),
      release_manifest_path = normalizePath(validated_preflight$release_manifest_path, winslash = "/", mustWork = TRUE)
    )
    fresh_paths <- c(
      trusted_root = fresh_preflight$trusted_root,
      release_root = fresh_preflight$release_root,
      release_manifest_path = fresh_preflight$release_manifest_path
    )
    if (!identical(supplied_paths, fresh_paths)) stop("Phase 12 validated preflight handoff is stale or forged", call. = FALSE)
    identity_fields <- c("release_id", "status", "selected_model_id", "candidate_id", "incumbent_id", "track_id", "panel_id", "score_support_g", "primary_probability_view", "decision_sha256", "freeze_id")
    if (!is.list(validated_preflight$metadata) || any(!vapply(identity_fields, function(field) identical(as.character(validated_preflight$metadata[[field]]), as.character(fresh_preflight$metadata[[field]])), logical(1)))) {
      stop("Phase 12 validated preflight authority identity drifted", call. = FALSE)
    }
  }
  release_root <- fresh_preflight$release_root
  manifest_path <- fresh_preflight$release_manifest_path
  full <- validate_phase12_complete_release_bundle(release_root, load_models = TRUE)
  manifest <- full$release_manifest
  contract <- full$model_contract
  model_object <- full$model_object
  calibrator <- full$calibrator
  if (is.null(model_object$model_id) || !identical(as.character(model_object$model_id), as.character(contract$selected_model_id))) stop("Phase 12 resolved model identity drifted", call. = FALSE)
  if (is.null(calibrator$candidate_id) || !identical(as.character(calibrator$candidate_id), as.character(contract$selected_model_id))) stop("Phase 12 resolved calibrator identity drifted", call. = FALSE)
  list(
    release_root = release_root, release_manifest_path = manifest_path,
    release_manifest = manifest, model_contract = contract,
    model = model_object, calibrator = calibrator,
    metadata = phase12_release_metadata(list(
      release_root = release_root, release_manifest = manifest, model_contract = contract
    ))
  )
}

#' Resolve the one calibrated release named by an explicit approved selector.
#' @export
phase14_resolve_approved_release <- function(selector_path, trusted_release_root) {
  phase12_release_contract_source_if_missing()
  selected <- phase14_release_read_selector(selector_path, trusted_release_root)
  selected_metadata <- validate_phase12_complete_release_bundle(
    selected$release_dir,
    load_models = FALSE
  )
  if (!identical(
    as.character(selected_metadata$model_contract$primary_probability_view),
    "calibrated_1x2"
  ) || !identical(
    as.character(selected_metadata$model_contract$calibrator_fit_status),
    "fitted"
  ) || !isTRUE(selected_metadata$model_contract$calibration_gate_passed)) {
    stop(
      "Phase 14 runtime release requires fitted calibrated authority; raw fallback is audit-only",
      call. = FALSE
    )
  }
  preflight <- preflight_phase12_approved_release(
    trusted_root = selected$trusted_release_root,
    release_manifest_path = selected$release_manifest_path
  )
  release_id <- as.character(selected$selector$release_id[[1L]])
  if (!identical(as.character(preflight$metadata$release_id), release_id) ||
      !identical(basename(preflight$release_root), release_id)) {
    stop("Phase 14 selector and release identity disagree", call. = FALSE)
  }
  resolved <- resolve_phase12_approved_release(
    trusted_root = selected$trusted_release_root,
    release_manifest_path = selected$release_manifest_path,
    validated_preflight = preflight
  )
  selected_fresh <- phase14_release_read_selector(selector_path, trusted_release_root)
  selector_identity <- c(
    selected$selector_self_sha256,
    selected$manifest_sha256,
    selected$release_manifest_path
  )
  fresh_identity <- c(
    selected_fresh$selector_self_sha256,
    selected_fresh$manifest_sha256,
    selected_fresh$release_manifest_path
  )
  if (!identical(selector_identity, fresh_identity)) {
    stop("Phase 14 approved release selector changed during resolution", call. = FALSE)
  }

  contract <- resolved$model_contract
  manifest <- resolved$release_manifest
  model <- resolved$model
  calibrator <- resolved$calibrator
  required_contract <- c(
    "model_sha256", "calibrator_id", "calibrator_sha256",
    "calibrator_fit_status", "model_data_cutoff", "calibration_data_cutoff",
    "calibration_gate_id", "calibration_gate_sha256", "calibration_gate_passed",
    "labels_embedded"
  )
  if (length(setdiff(required_contract, names(contract)))) {
    stop("Phase 14 calibrated release contract is incomplete", call. = FALSE)
  }
  if (!identical(as.character(contract$primary_probability_view), "calibrated_1x2") ||
      !identical(as.character(contract$calibrator_fit_status), "fitted") ||
      !isTRUE(contract$calibration_gate_passed) ||
      !identical(contract$labels_embedded, FALSE) ||
      !identical(as.integer(contract$score_support_g), 40L)) {
    stop("Phase 14 runtime release requires fitted calibrated G=40 authority", call. = FALSE)
  }
  if (!identical(as.character(calibrator$fit_status), "fitted") ||
      !isTRUE(calibrator$calibration_gate_passed) ||
      !isTRUE(calibrator$distribution_unchanged) ||
      !identical(calibrator$labels_embedded, FALSE) ||
      !identical(as.character(calibrator$primary_probability_view), "calibrated_1x2")) {
    stop("Phase 14 runtime release fitted calibrator identity is invalid", call. = FALSE)
  }
  model_path <- file.path(selected$release_dir, as.character(contract$model_artifact))
  calibrator_path <- file.path(selected$release_dir, as.character(contract$calibrator_artifact))
  actual_model_sha256 <- phase12_release_file_sha256(model_path)
  actual_calibrator_sha256 <- phase12_release_file_sha256(calibrator_path)
  if (!identical(actual_model_sha256, tolower(as.character(contract$model_sha256))) ||
      !identical(actual_calibrator_sha256, tolower(as.character(contract$calibrator_sha256)))) {
    stop("Phase 14 runtime release object hash identity drifted", call. = FALSE)
  }
  if (is.null(model$model_id) ||
      !identical(as.character(model$model_id), as.character(contract$selected_model_id)) ||
      is.null(calibrator$candidate_id) ||
      !identical(as.character(calibrator$candidate_id), as.character(contract$selected_model_id)) ||
      is.null(calibrator$calibrator_id) ||
      !identical(as.character(calibrator$calibrator_id), as.character(contract$calibrator_id))) {
    stop("Phase 14 runtime release model or calibrator identity drifted", call. = FALSE)
  }
  model_cutoff <- if (!is.null(model$training_dates)) {
    format(max(as.Date(model$training_dates)), "%Y-%m-%d")
  } else {
    ""
  }
  if (!identical(model_cutoff, as.character(contract$model_data_cutoff)) ||
      !identical(as.character(calibrator$model_data_cutoff), as.character(contract$model_data_cutoff)) ||
      !identical(as.character(calibrator$calibration_data_cutoff), as.character(contract$calibration_data_cutoff)) ||
      !identical(as.character(calibrator$model_sha256), actual_model_sha256) ||
      !identical(as.character(calibrator$calibration_gate_id), as.character(contract$calibration_gate_id)) ||
      !identical(as.character(calibrator$calibration_gate_sha256), as.character(contract$calibration_gate_sha256))) {
    stop("Phase 14 runtime release cutoff or calibration identity drifted", call. = FALSE)
  }
  self <- manifest[as.character(manifest$artifact) == "release_manifest.csv", , drop = FALSE]
  if (nrow(self) != 1L) stop("Phase 14 release manifest self identity is invalid", call. = FALSE)
  list(
    release_dir = selected$release_dir,
    release_manifest_path = selected$release_manifest_path,
    release_identity = list(
      release_id = release_id,
      status = as.character(contract$status),
      manifest_sha256 = selected$manifest_sha256,
      manifest_self_sha256 = as.character(self$manifest_self_sha256[[1L]]),
      selector_self_sha256 = selected$selector_self_sha256
    ),
    model_identity = list(
      model_id = as.character(contract$selected_model_id),
      sha256 = actual_model_sha256
    ),
    calibrator_identity = list(
      calibrator_id = as.character(contract$calibrator_id),
      sha256 = actual_calibrator_sha256,
      fit_status = as.character(contract$calibrator_fit_status),
      calibration_gate_id = as.character(contract$calibration_gate_id),
      calibration_gate_sha256 = as.character(contract$calibration_gate_sha256)
    ),
    model_data_cutoff = as.character(contract$model_data_cutoff),
    calibration_data_cutoff = as.character(contract$calibration_data_cutoff),
    support_max = as.integer(contract$score_support_g),
    primary_probability_view = as.character(contract$primary_probability_view),
    model = model,
    calibrator = calibrator
  )
}

#' Project the one release identity used by dashboard and export consumers.
#' @export
phase12_release_metadata <- function(release = NULL, trusted_root = "outputs/releases") {
  if (is.null(release)) release <- resolve_phase12_approved_release(trusted_root)
  manifest <- release$release_manifest
  contract <- release$model_contract
  self <- manifest[manifest$artifact == "release_manifest.csv", , drop = FALSE]
  list(
    release_id = as.character(contract$release_id), status = as.character(contract$status),
    selected_model_id = as.character(contract$selected_model_id), candidate_id = as.character(manifest$candidate_id[[1L]]),
    incumbent_id = as.character(manifest$incumbent_id[[1L]]), track_id = as.character(contract$track_id),
    panel_id = as.character(contract$panel_id), score_support_g = as.integer(contract$score_support_g),
    primary_probability_view = as.character(contract$primary_probability_view),
    raw_fallback_status = as.character(manifest$raw_fallback_status[[1L]]),
    decision_sha256 = as.character(contract$decision_sha256),
    freeze_id = as.character(manifest$freeze_id[[1L]]),
    manifest_self_sha256 = if (nrow(self)) as.character(self$manifest_self_sha256[[1L]]) else "",
    release_root = as.character(release$release_root)
  )
}
