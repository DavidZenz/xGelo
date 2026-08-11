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
  if (file.exists(file.path(root, "release_manifest.csv"))) return(file.path(root, "release_manifest.csv"))
  dirs <- list.dirs(root, recursive = FALSE, full.names = TRUE)
  manifests <- file.path(dirs, "release_manifest.csv")
  manifests[file.exists(manifests)]
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
  if (isTRUE(contract$labels_embedded)) stop("Phase 12 consumer contract embeds labels", call. = FALSE)
  required <- c("release_id", "status", "selected_model_id", "track_id", "panel_id", "score_support_g", "primary_probability_view", "decision_sha256")
  if (any(vapply(required, function(name) is.null(contract[[name]]), logical(1)))) stop("Phase 12 model contract is incomplete", call. = FALSE)
  if (!identical(as.character(contract$release_id), as.character(manifest$release_id[[1L]])) || !identical(as.character(contract$status), status) || !identical(as.character(contract$selected_model_id), as.character(manifest$selected_model_id[[1L]])) || !identical(as.character(contract$track_id), as.character(manifest$track_id[[1L]])) || !identical(as.character(contract$panel_id), "open_core") || as.integer(contract$score_support_g) != 40L || !identical(as.character(contract$primary_probability_view), as.character(manifest$primary_probability_view[[1L]]))) stop("Phase 12 model contract identity mismatch", call. = FALSE)
  invisible(TRUE)
}

#' Validate a resolved release contract, including all hashes, before loading RDS.
#' @export
validate_phase12_release_contract <- function(release_root, release_manifest = NULL, model_contract = NULL) {
  phase12_release_contract_source_if_missing()
  release_root <- normalizePath(release_root, winslash = "/", mustWork = TRUE)
  if (is.null(release_manifest)) release_manifest <- utils::read.csv(file.path(release_root, "release_manifest.csv"), stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  if (is.null(model_contract)) model_contract <- phase12_release_read_contract(file.path(release_root, "model_contract.json"))
  validate_phase12_complete_release_bundle(release_root)
  phase12_release_contract_validate_identity(release_root, release_manifest, model_contract)
  invisible(list(release_root = release_root, release_manifest = release_manifest, model_contract = model_contract))
}

#' Resolve exactly one approved or incumbent-retained release.
#' @export
resolve_phase12_approved_release <- function(trusted_root = "outputs/releases", release_manifest_path = NULL) {
  phase12_release_contract_source_if_missing()
  trusted_root <- phase12_release_trusted_root(trusted_root)
  candidates <- if (is.null(release_manifest_path)) {
    phase12_release_contract_manifest_candidates(trusted_root)
  } else {
    supplied <- as.character(release_manifest_path)
    if (length(supplied) != 1L || is.na(supplied) || !nzchar(supplied)) stop("Phase 12 release manifest path is invalid", call. = FALSE)
    if (!grepl("^/", supplied)) supplied <- file.path(trusted_root, supplied)
    supplied <- normalizePath(supplied, winslash = "/", mustWork = TRUE)
    prefix <- paste0(trusted_root, "/")
    if (!startsWith(supplied, prefix) && !identical(dirname(supplied), trusted_root)) stop("Phase 12 release manifest path escapes the trusted root", call. = FALSE)
    supplied
  }
  if (length(candidates) != 1L) stop("Phase 12 release resolution is ambiguous or missing", call. = FALSE)
  manifest_path <- normalizePath(candidates[[1L]], winslash = "/", mustWork = TRUE)
  release_root <- dirname(manifest_path)
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  contract_path <- phase12_release_contract_path(release_root, "model_contract.json")
  contract <- phase12_release_read_contract(contract_path)
  validate_phase12_release_contract(release_root, manifest, contract)
  model_path <- phase12_release_contract_path(release_root, "model/approved_model.rds")
  calibrator_path <- phase12_release_contract_path(release_root, "model/calibrator.rds")
  model_object <- readRDS(model_path)
  calibrator <- readRDS(calibrator_path)
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
    selected_model_id = as.character(contract$selected_model_id), track_id = as.character(contract$track_id),
    panel_id = as.character(contract$panel_id), score_support_g = as.integer(contract$score_support_g),
    primary_probability_view = as.character(contract$primary_probability_view),
    raw_fallback_status = as.character(manifest$raw_fallback_status[[1L]]),
    decision_sha256 = as.character(contract$decision_sha256),
    manifest_self_sha256 = if (nrow(self)) as.character(self$manifest_self_sha256[[1L]]) else "",
    release_root = as.character(release$release_root)
  )
}
