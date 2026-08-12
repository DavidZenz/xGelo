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
  normalizePath(trusted_root, winslash = "/", mustWork = TRUE)
}

phase12_release_contract_manifest_candidates <- function(trusted_root) {
  root <- phase12_release_trusted_root(trusted_root)
  root_manifest <- file.path(root, "release_manifest.csv")
  dirs <- list.dirs(root, recursive = FALSE, full.names = TRUE)
  manifests <- file.path(dirs, "release_manifest.csv")
  sort(c(root_manifest[file.exists(root_manifest)], manifests[file.exists(manifests)]))
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
  path <- tempfile("phase12-benchmark-evidence-", fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  utils::write.csv(evidence, path, row.names = FALSE, na = "", quote = TRUE)
  digest::digest(path, algo = "sha256", file = TRUE)
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
  if (!identical(phase12_release_contract_normalise_report_status(report$status), status) || !identical(report$selected_id, selected_id)) stop("Phase 12 bundled benchmark decision identity disagrees with the release", call. = FALSE)
  if (is.null(provenance$decision_evidence_sha256) || !grepl("^[0-9a-fA-F]{64}$", as.character(provenance$decision_evidence_sha256))) stop("Phase 12 release provenance candidate evidence identity is invalid", call. = FALSE)
  recomputed <- phase12_release_contract_recompute_decision_sha256(report$evidence, report$status, report$selected_id)
  if (!identical(tolower(recomputed), tolower(as.character(provenance$decision_evidence_sha256))) || !identical(tolower(report$decision_sha256), tolower(metadata$decision_sha256))) stop("Phase 12 embedded promotion decision identity mismatch", call. = FALSE)
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

#' Validate a release's metadata and candidate authority without reading model RDS files.
#' @export
preflight_phase12_approved_release <- function(trusted_root = NULL, release_manifest_path = NULL) {
  phase12_release_contract_source_if_missing()
  if (is.null(trusted_root)) stop("Phase 12 dashboard release root is required", call. = FALSE)
  trusted_root <- phase12_release_trusted_root(trusted_root)
  candidates <- phase12_release_contract_manifest_candidates(trusted_root)
  if (length(candidates) != 1L) stop("Phase 12 release resolution is ambiguous or missing", call. = FALSE)
  pinned <- normalizePath(candidates[[1L]], winslash = "/", mustWork = TRUE)
  if (!is.null(release_manifest_path) && !identical(phase12_release_contract_manifest_path(trusted_root, release_manifest_path), pinned)) stop("Phase 12 supplied release manifest is not the sole trusted candidate", call. = FALSE)
  release_root <- dirname(pinned)
  validated <- validate_phase12_complete_release_bundle(release_root, load_models = FALSE)
  manifest <- validated$release_manifest
  contract <- validated$model_contract
  provenance <- phase12_release_read_contract(phase12_release_contract_path(release_root, "manifests/provenance.json"))
  report <- phase12_release_contract_read_benchmark_evidence(release_root)
  authority <- phase12_release_contract_validate_candidate_authority(
    release_root, manifest, contract, validated$freeze_manifest, validated$final_evaluation_manifest, provenance, report
  )
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
  if (is.null(validated_preflight)) validated_preflight <- preflight_phase12_approved_release(trusted_root, release_manifest_path)
  if (!is.list(validated_preflight) || is.null(validated_preflight$release_root) || is.null(validated_preflight$release_manifest_path)) stop("Phase 12 validated preflight is invalid", call. = FALSE)
  release_root <- normalizePath(validated_preflight$release_root, winslash = "/", mustWork = TRUE)
  manifest_path <- normalizePath(validated_preflight$release_manifest_path, winslash = "/", mustWork = TRUE)
  full <- validate_phase12_complete_release_bundle(release_root, load_models = TRUE)
  manifest <- full$release_manifest
  contract <- full$model_contract
  model_object <- full$model_object
  calibrator <- full$calibrator
  if (!is.null(model_object$model_id) && !identical(as.character(model_object$model_id), as.character(contract$selected_model_id))) stop("Phase 12 resolved model identity drifted", call. = FALSE)
  if (!is.null(calibrator$candidate_id) && !identical(as.character(calibrator$candidate_id), as.character(contract$selected_model_id))) stop("Phase 12 resolved calibrator identity drifted", call. = FALSE)
  list(
    release_root = release_root, release_manifest_path = manifest_path,
    release_manifest = manifest, model_contract = contract,
    model = model_object, calibrator = calibrator,
    metadata = phase12_release_metadata(list(
      release_root = release_root, release_manifest = manifest, model_contract = contract
    ))
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
