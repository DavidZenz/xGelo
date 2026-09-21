#' Immutable Phase 19 club release publication and resolution.
#'
#' The release boundary is intentionally independent of the national release
#' tree.  Metadata is validated before any model or calibrator RDS is read;
#' object identity is checked only after the byte/hash checks have passed.

phase19_club_release_abort <- function(reason_code, message, data = list()) {
  stop(structure(
    c(list(message = as.character(message), call = NULL,
           reason_code = as.character(reason_code)), data),
    class = c("phase19_club_release_error", "error", "condition")
  ))
}

phase19_club_release_source_dependencies <- function() {
  roots <- c(getwd(), file.path(getwd(), "../.."), file.path(getwd(), "../../.."))
  root <- roots[vapply(roots, function(path) file.exists(file.path(path, "R/release/domain_contract.R")), logical(1))][1L]
  if (is.na(root) || !nzchar(root)) return(invisible(FALSE))
  if (!exists("assert_forecast_domain", mode = "function")) {
    source(file.path(root, "R/release/domain_contract.R"), local = .GlobalEnv)
  }
  if (!exists("phase19_validate_club_goal_fit", mode = "function")) {
    dependencies <- c(
      "R/common/phase18_canonical_hash.R", "R/club/history_contract.R",
      "R/club/model_contract.R", "R/evaluation/proper_scores.R",
      "R/evaluation/benchmark_scores.R", "R/club/evaluation_protocol.R",
      "R/club/rating.R", "R/club/goal_model.R", "R/club/calibration.R",
      "R/club/evaluation.R"
    )
    for (dependency in dependencies) {
      path <- file.path(root, dependency)
      if (file.exists(path)) source(path, local = .GlobalEnv)
    }
  }
  invisible(TRUE)
}

phase19_club_release_source_dependencies()

phase19_club_release_schema_version <- function() "phase19-club-release-v1"

phase19_club_release_required_artifacts <- function() {
  c(
    "release_manifest.csv", "model_contract.json", "model/approved_model.rds",
    "model/calibrator.rds", "manifests/history_manifest.csv",
    "manifests/protocol_manifest.csv", "manifests/evaluation_manifest.csv",
    "manifests/promotion_manifest.csv", "manifests/provenance.json",
    "reports/model_card.md", "reports/benchmark_report.md", "limitations.md",
    "reproducibility.json"
  )
}

phase19_club_release_hash <- function(value, domain = "phase19-club-release-value-v1") {
  if (!requireNamespace("digest", quietly = TRUE)) {
    phase19_club_release_abort("release_dependency_missing", "digest is required for club release hashes")
  }
  digest::digest(value, algo = "sha256", serialize = TRUE)
}

phase19_club_release_file_sha256 <- function(path) {
  if (!file.exists(path) || dir.exists(path) || nzchar(Sys.readlink(path))) {
    phase19_club_release_abort("release_artifact_missing", paste0("Club release artifact is missing or symlinked: ", path))
  }
  if (!requireNamespace("digest", quietly = TRUE)) {
    phase19_club_release_abort("release_dependency_missing", "digest is required for club release hashes")
  }
  tolower(digest::digest(path, algo = "sha256", file = TRUE))
}

phase19_club_release_safe_id <- function(value, name = "release identity") {
  if (length(value) != 1L || is.null(value) || is.na(value) || !nzchar(as.character(value)) ||
      grepl("[/\\\\]", as.character(value)) || grepl("(^|/)\\.\\.?(/|$)", as.character(value)) ||
      !grepl("^[A-Za-z0-9][A-Za-z0-9._-]*$", as.character(value))) {
    phase19_club_release_abort("release_path_invalid", paste0("Unsafe club release ", name))
  }
  as.character(value)
}

phase19_club_release_safe_relative_path <- function(path) {
  path <- gsub("\\\\", "/", as.character(path))
  if (length(path) != 1L || is.na(path) || !nzchar(path) || grepl("^/", path) ||
      grepl("(^|/)\\.\\.?(/|$)", path) || identical(path, ".")) {
    phase19_club_release_abort("release_path_invalid", paste0("Unsafe club artifact path: ", path))
  }
  pieces <- strsplit(path, "/", fixed = TRUE)[[1L]]
  if (any(!nzchar(pieces)) || any(pieces %in% c(".", ".."))) {
    phase19_club_release_abort("release_path_invalid", paste0("Unsafe club artifact path: ", path))
  }
  path
}

phase19_club_release_real_root <- function(root, create = FALSE) {
  if (length(root) != 1L || is.na(root) || !nzchar(as.character(root))) {
    phase19_club_release_abort("release_root_invalid", "Club release root is invalid")
  }
  root <- as.character(root)
  if (create && !file.exists(root)) dir.create(root, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(root) || nzchar(Sys.readlink(root))) {
    phase19_club_release_abort("release_root_invalid", "Club release root must be a real directory")
  }
  normalizePath(root, winslash = "/", mustWork = TRUE)
}

phase19_club_release_path_under_root <- function(root, relative_path, must_work = TRUE) {
  root <- phase19_club_release_real_root(root)
  relative_path <- phase19_club_release_safe_relative_path(relative_path)
  candidate <- normalizePath(file.path(root, relative_path), winslash = "/", mustWork = FALSE)
  if (!identical(candidate, root) && !startsWith(candidate, paste0(root, "/"))) {
    phase19_club_release_abort("release_path_escape", paste0("Club release path escapes trusted root: ", relative_path))
  }
  if (must_work && (!file.exists(candidate) || dir.exists(candidate))) {
    phase19_club_release_abort("release_artifact_missing", paste0("Club release artifact is missing: ", relative_path))
  }
  candidate
}

phase19_club_release_is_symlink <- function(path) {
  link <- Sys.readlink(path)
  length(link) == 1L && !is.na(link) && nzchar(link)
}

phase19_club_release_write_text <- function(text, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  staged <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
  on.exit(if (file.exists(staged)) unlink(staged), add = TRUE)
  writeLines(enc2utf8(as.character(text)), staged, useBytes = TRUE)
  if (!file.rename(staged, path)) {
    phase19_club_release_abort("release_publish_failed", paste0("Could not publish club release file: ", path))
  }
  invisible(path)
}

phase19_club_release_write_csv <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  staged <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
  on.exit(if (file.exists(staged)) unlink(staged), add = TRUE)
  utils::write.csv(data, staged, row.names = FALSE, na = "", quote = TRUE)
  if (!file.rename(staged, path)) {
    phase19_club_release_abort("release_publish_failed", paste0("Could not publish club release CSV: ", path))
  }
  invisible(path)
}

phase19_club_release_write_json <- function(value, path) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    phase19_club_release_abort("release_dependency_missing", "jsonlite is required for club release metadata")
  }
  phase19_club_release_write_text(
    jsonlite::toJSON(value, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "string", digits = 17),
    path
  )
}

phase19_club_release_write_rds <- function(value, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  staged <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
  on.exit(if (file.exists(staged)) unlink(staged), add = TRUE)
  saveRDS(value, staged, version = 3L, compress = FALSE)
  if (!file.rename(staged, path)) {
    phase19_club_release_abort("release_publish_failed", paste0("Could not publish club release RDS: ", path))
  }
  invisible(path)
}

phase19_club_release_table_hash <- function(data, schema_tag = "phase19-club-release-table-v1") {
  path <- tempfile("phase19-club-release-table-", fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  utils::write.csv(data, path, row.names = FALSE, na = "", quote = TRUE)
  phase19_club_release_file_sha256(path)
}

phase19_club_release_scalar <- function(value, fallback = "") {
  if (is.null(value) || !length(value) || is.na(value[[1L]])) return(fallback)
  value <- value[[1L]]
  if (is.logical(value)) return(ifelse(isTRUE(value), "TRUE", "FALSE"))
  if (is.numeric(value)) return(format(value, digits = 17, scientific = FALSE, trim = TRUE))
  as.character(value)
}

phase19_club_release_first <- function(value, fields, fallback = "") {
  if (is.null(value)) return(fallback)
  for (field in fields) {
    candidate <- if (is.data.frame(value) && field %in% names(value) && nrow(value)) value[[field]][[1L]] else if (is.list(value) && !is.null(value[[field]])) value[[field]] else NULL
    if (!is.null(candidate) && length(candidate) && !is.na(candidate[[1L]]) && nzchar(as.character(candidate[[1L]]))) return(as.character(candidate[[1L]]))
  }
  fallback
}

phase19_club_release_hash_or_blank <- function(value, fields, fallback = "") {
  if (length(fallback) != 1L || is.na(fallback)) fallback <- ""
  candidate <- phase19_club_release_first(value, fields, fallback)
  if (length(candidate) != 1L || is.na(candidate) || !nzchar(candidate)) return("")
  if (!grepl("^[0-9a-fA-F]{64}$", candidate)) {
    phase19_club_release_abort("release_parent_invalid", paste0("Invalid parent hash for ", fields[[1L]]))
  }
  tolower(candidate)
}

phase19_club_release_manifest_body_hash <- function(manifest) {
  body <- manifest[as.character(manifest$artifact) != "release_manifest.csv", , drop = FALSE]
  body <- body[order(as.character(body$artifact), method = "radix"), , drop = FALSE]
  if ("manifest_self_sha256" %in% names(body)) body$manifest_self_sha256 <- ""
  body[] <- lapply(body, function(value) { value <- as.character(value); value[is.na(value)] <- ""; value })
  path <- tempfile("phase19-club-release-manifest-", fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  utils::write.csv(body, path, row.names = FALSE, na = "", quote = TRUE)
  phase19_club_release_file_sha256(path)
}

phase19_club_release_selector_hash <- function(selector) {
  projection <- selector
  projection$row_sha256 <- ""
  phase19_club_release_table_hash(projection, "phase19-club-selector-v1")
}

phase19_club_release_selector_columns <- function() {
  c("forecast_domain", "release_id", "release_manifest_path", "manifest_sha256", "approved_at_utc", "row_sha256")
}

phase19_club_release_recursive_files <- function(root) {
  root <- phase19_club_release_real_root(root)
  entries <- list.files(root, full.names = TRUE, recursive = TRUE, all.files = TRUE, include.dirs = TRUE, no.. = TRUE)
  if (!length(entries)) return(character())
  root_prefix <- paste0(root, "/")
  normalized <- vapply(entries, function(path) {
    if (phase19_club_release_is_symlink(path)) {
      phase19_club_release_abort("release_symlink", paste0("Club release tree contains a symlink: ", path))
    }
    normalizePath(path, winslash = "/", mustWork = TRUE)
  }, character(1))
  normalized <- normalized[file.info(normalized)$isdir %in% FALSE]
  if (!length(normalized)) return(character())
  relative <- substring(unname(normalized), nchar(root_prefix) + 1L)
  unname(relative)
}

phase19_club_release_inventory <- function(root) {
  files <- phase19_club_release_recursive_files(root)
  unname(sort(files, method = "radix"))
}

phase19_club_release_is_temporary_root <- function(root) {
  root <- normalizePath(root, winslash = "/", mustWork = FALSE)
  temporary <- normalizePath(tempdir(), winslash = "/", mustWork = TRUE)
  identical(root, temporary) || startsWith(root, paste0(temporary, "/"))
}

phase19_club_release_production_root <- function() {
  candidate <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  repeat {
    if (dir.exists(file.path(candidate, ".planning")) &&
        file.exists(file.path(candidate, "R/club/release.R"))) {
      return(normalizePath(file.path(candidate, "outputs/releases/club"),
                          winslash = "/", mustWork = FALSE))
    }
    parent <- dirname(candidate)
    if (identical(parent, candidate)) break
    candidate <- parent
  }
  phase19_club_release_abort("release_root_invalid", "Could not resolve the fixed production club release root")
}

phase19_club_release_assert_parent_evidence <- function(
    decision, model, calibrator, history_snapshot, current_snapshot,
    protocol, evaluation, authority, replay, integrity, source_evidence = NULL
) {
  required <- list(
    history_snapshot = history_snapshot, current_snapshot = current_snapshot,
    protocol = protocol, evaluation = evaluation, authority = authority,
    replay = replay, integrity = integrity
  )
  missing <- names(required)[vapply(required, is.null, logical(1))]
  if (length(missing)) {
    phase19_club_release_abort(
      "release_parent_invalid",
      paste0("Fixture release requires typed parent evidence: ", paste(missing, collapse = ", "))
    )
  }
  validators <- c(
    "phase19_validate_club_training_snapshot",
    "phase19_validate_current_ucl_club_snapshot",
    "phase19_validate_club_goal_fit",
    "phase19_validate_club_calibrator",
    "phase19_validate_club_evaluation_set",
    "phase19_club_validate_authority",
    "phase19_validate_club_integrity_evidence",
    "phase19_validate_club_promotion_decision"
  )
  if (any(!vapply(validators, exists, logical(1), mode = "function"))) {
    phase19_club_release_abort(
      "release_dependency_missing",
      "Fixture release parent validators must be loaded before publication"
    )
  }
  checked <- tryCatch({
    phase19_validate_club_training_snapshot(history_snapshot, "fixture")
    phase19_validate_current_ucl_club_snapshot(current_snapshot, "fixture")
    phase19_validate_club_goal_fit(model)
    phase19_validate_club_calibrator(calibrator, require_fitted = TRUE)
    phase19_validate_club_evaluation_set(evaluation, protocol, source_evidence)
    phase19_club_validate_authority(authority, evaluation, protocol, source_evidence)
    phase19_validate_club_integrity_evidence(
      integrity, evaluation, protocol, replay, authority, source_evidence
    )
    phase19_validate_club_promotion_decision(
      decision, evaluation, protocol, replay, integrity, authority, source_evidence
    )
    TRUE
  }, error = function(error) error)
  if (inherits(checked, "error")) {
    phase19_club_release_abort(
      "release_parent_invalid", paste0("Fixture release parent validation failed: ", conditionMessage(checked))
    )
  }
  invisible(TRUE)
}

phase19_club_release_production_parent_schema <- function() {
  c(
    "history_snapshot", "current_snapshot", "protocol", "evaluation",
    "authority", "fold_protocol", "rating_replay", "integrity", "decision",
    "fold_source_evidence"
  )
}

phase19_club_release_validate_evaluated_model_support <- function(
    source_authority, model, calibrator, decision
) {
  selected <- as.character(decision$selected_model_id)
  if (!identical(selected, "club_elo_nb")) {
    phase19_club_release_abort(
      "production_authority_invalid",
      "Production release selection must use the evaluated club_elo_nb support row"
    )
  }
  evaluations <- source_authority$evaluation$fold_evaluations
  source_folds <- source_authority$fold_source_evidence
  fold_ids <- sort(vapply(evaluations, `[[`, character(1), "fold_id"), method = "radix")
  if (!length(fold_ids) || !is.list(source_folds) ||
      !identical(sort(names(source_folds), method = "radix"), fold_ids)) {
    phase19_club_release_abort(
      "production_authority_invalid",
      "Production release is missing the complete evaluated fold source graph"
    )
  }
  canonical_id <- fold_ids[[1L]]
  canonical_evaluation <- evaluations[[match(canonical_id, vapply(
    evaluations, `[[`, character(1), "fold_id"
  ))]]
  canonical_source <- source_folds[[canonical_id]]
  artifacts <- tryCatch(
    phase19_validate_club_fold_source_artifacts(
      canonical_source, canonical_source$fold, source_authority$protocol,
      canonical_source$outcomes
    ),
    error = function(error) error
  )
  if (inherits(artifacts, "error")) {
    phase19_club_release_abort(
      "production_authority_invalid",
      paste0("Canonical evaluated model support could not be regenerated: ",
             conditionMessage(artifacts))
    )
  }
  selected_artifacts <- artifacts$candidate
  support <- canonical_source$model_support
  if (!is.data.frame(support) ||
      !identical(names(support), phase19_club_evaluation_support_schema()) ||
      nrow(support) != 2L) {
    phase19_club_release_abort(
      "production_authority_invalid",
      "Canonical evaluated model support is not the exact typed support table"
    )
  }
  support <- support[support$model_id == selected, , drop = FALSE]
  expected <- c(
    model_id = selected,
    fit_status = "converged", fallback_status = as.character(selected_artifacts$fit$fallback_status),
    fit_sha256 = as.character(selected_artifacts$fit$fit_sha256),
    calibrator_status = "fitted",
    primary_probability_view = as.character(selected_artifacts$calibration_decision$primary_probability_view),
    calibrator_sha256 = as.character(selected_artifacts$calibrator$calibrator_sha256),
    calibration_evidence_sha256 = as.character(selected_artifacts$calibration_evidence$evidence_sha256),
    calibration_decision_sha256 = as.character(selected_artifacts$calibration_decision$decision_sha256)
  )
  if (nrow(support) != 1L ||
      !identical(as.character(unlist(support[1L, names(expected)], use.names = FALSE)),
                 unname(expected)) ||
      !identical(model, selected_artifacts$fit) ||
      !identical(calibrator, selected_artifacts$calibrator) ||
      !identical(as.character(canonical_evaluation$convergence$fit_sha256[
        canonical_evaluation$convergence$model_id == selected
      ]), as.character(model$fit_sha256)) ||
      !identical(as.character(canonical_evaluation$convergence$calibrator_sha256[
        canonical_evaluation$convergence$model_id == selected
      ]), as.character(calibrator$calibrator_sha256)) ||
      !identical(as.character(canonical_evaluation$convergence$calibration_evidence_sha256[
        canonical_evaluation$convergence$model_id == selected
      ]), as.character(selected_artifacts$calibration_evidence$evidence_sha256)) ||
      !identical(as.character(canonical_evaluation$convergence$calibration_decision_sha256[
        canonical_evaluation$convergence$model_id == selected
      ]), as.character(selected_artifacts$calibration_decision$decision_sha256))) {
    phase19_club_release_abort(
      "production_authority_invalid",
      "Release model/calibrator identities do not equal the canonical evaluated model support"
    )
  }
  invisible(TRUE)
}

#' Validate the complete typed authority graph before production installation.
#'
#' A release directory is only a serialized transport.  Its self-hashes and
#' contract strings cannot establish Phase 18/19 authority, so production
#' installation requires the accepted source graph in memory before any
#' rename or selector write is permitted.
phase19_club_release_validate_production_parent_graph <- function(
    source_authority, model, calibrator
) {
  phase19_club_release_source_dependencies()
  schema <- phase19_club_release_production_parent_schema()
  if (!is.list(source_authority) || !identical(names(source_authority), schema)) {
    phase19_club_release_abort(
      "production_authority_invalid",
      "Production installation requires the complete typed Phase 18/19 parent graph"
    )
  }
  required <- c(
    "phase19_validate_club_training_snapshot",
    "phase19_validate_current_ucl_club_snapshot",
    "phase19_validate_club_rating_replay",
    "phase19_validate_club_evaluation_set",
    "phase19_validate_club_fold_source_artifacts",
    "phase19_club_validate_authority",
    "phase19_validate_club_integrity_evidence",
    "phase19_validate_club_promotion_decision",
    "phase19_validate_club_goal_fit",
    "phase19_validate_club_calibrator"
  )
  if (any(!vapply(required, exists, logical(1), mode = "function"))) {
    phase19_club_release_abort(
      "release_dependency_missing",
      "Production authority validators must be loaded before installation"
    )
  }
  history <- source_authority$history_snapshot
  current <- source_authority$current_snapshot
  protocol <- source_authority$protocol
  evaluation <- source_authority$evaluation
  authority <- source_authority$authority
  folds <- source_authority$fold_protocol
  replay <- source_authority$rating_replay
  integrity <- source_authority$integrity
  decision <- source_authority$decision
  source_folds <- source_authority$fold_source_evidence
  checked <- tryCatch({
    phase19_validate_club_training_snapshot(history, "production")
    phase19_validate_current_ucl_club_snapshot(current, "production")
    if (!inherits(protocol, "phase19_club_evaluation_protocol") ||
        !identical(protocol$authority_mode, "production") ||
        isTRUE(protocol$fixture_authority) || !isTRUE(protocol$production_eligible)) {
      phase19_club_release_abort(
        "production_authority_invalid",
        "Production installation requires the accepted production protocol"
      )
    }
    phase19_assert_production_fold_protocol(folds)
    phase19_validate_club_rating_replay(
      replay, history, current_snapshot = current,
      parameters = replay$parameters, cutoff_utc = replay$cutoff_utc
    )
    phase19_validate_club_evaluation_set(
      evaluation, protocol, source_folds, folds
    )
    phase19_club_validate_authority(
      authority, evaluation, protocol, source_folds
    )
    phase19_validate_club_integrity_evidence(
      integrity, evaluation, protocol, replay, authority, source_folds
    )
    phase19_club_release_decision_check(decision, "production")
    phase19_validate_club_promotion_decision(
      decision, evaluation, protocol, replay, integrity, authority, source_folds
    )
    phase19_validate_club_goal_fit(model)
    phase19_validate_club_calibrator(calibrator, require_fitted = TRUE)
    phase19_club_release_validate_evaluated_model_support(
      source_authority, model, calibrator, decision
    )
    if (!isTRUE(model$production_eligible) ||
        !isTRUE(calibrator$production_eligible) ||
        isTRUE(model$fixture_authority) || isTRUE(calibrator$fixture_authority) ||
        !identical(model$authority_mode, "production") ||
        !identical(calibrator$authority_mode, "production") ||
        !identical(as.character(model$model_id), as.character(decision$selected_model_id)) ||
        !identical(as.character(calibrator$candidate_id), as.character(decision$selected_model_id)) ||
        !identical(as.character(model$training_snapshot_sha256),
                   as.character(history$snapshot_sha256)) ||
        !identical(as.character(model$current_snapshot_sha256),
                   as.character(current$snapshot_sha256)) ||
        !identical(as.character(model$protocol_sha256),
                   as.character(protocol$protocol_sha256)) ||
        !identical(as.character(calibrator$protocol_sha256),
                   as.character(protocol$protocol_sha256))) {
      phase19_club_release_abort(
        "production_authority_invalid",
        "Production model and calibrator must be source-backed and production-eligible"
      )
    }
    TRUE
  }, error = function(error) error)
  if (inherits(checked, "error")) {
    phase19_club_release_abort(
      "production_authority_invalid",
      paste0("Production authority graph validation failed: ", conditionMessage(checked))
    )
  }
  invisible(TRUE)
}

phase19_club_release_decision_check <- function(decision, mode = c("fixture", "production")) {
  mode <- match.arg(mode)
  if (!is.list(decision)) phase19_club_release_abort("release_decision_invalid", "Club release decision is not a list")
  actual_domain <- if (!is.null(decision$forecast_domain)) as.character(decision$forecast_domain[[1L]]) else ""
  if (!identical(actual_domain, "club")) phase19_club_release_abort("domain_mismatch", "Club release decision is not in the club domain")
  required <- c("candidate_id", "incumbent_id", "selected_model_id", "diagnostic_gate_outcome", "authority_eligibility", "promotion_status", "decision_sha256")
  if (length(setdiff(required, names(decision)))) phase19_club_release_abort("release_decision_invalid", "Club release decision schema is incomplete")
  if (!identical(as.character(decision$candidate_id), "club_elo_nb") || !identical(as.character(decision$incumbent_id), "club_venue_nb")) {
    phase19_club_release_abort("release_decision_invalid", "Club release candidate/incumbent identity is invalid")
  }
  if (!grepl("^[0-9a-fA-F]{64}$", as.character(decision$decision_sha256))) phase19_club_release_abort("release_decision_invalid", "Club release decision hash is invalid")
  if (mode == "fixture") {
    if (!identical(as.character(decision$authority_mode), "fixture") || !isTRUE(decision$fixture_authority) ||
        !as.character(decision$diagnostic_gate_outcome) %in% c("pass", "fail") ||
        !identical(as.character(decision$authority_eligibility), "fixture_ineligible") ||
        !as.character(decision$promotion_status) %in% c("ineligible_fixture", "retained")) {
      phase19_club_release_abort("fixture_authority_invalid", "Fixture release requires fixture_ineligible authority and a closed non-production promotion status")
    }
  } else if (!identical(as.character(decision$authority_mode), "production") ||
             isTRUE(decision$fixture_authority) ||
             !identical(as.character(decision$diagnostic_gate_outcome), "pass") ||
             !identical(as.character(decision$authority_eligibility), "production") ||
             !identical(as.character(decision$promotion_status), "promoted")) {
    phase19_club_release_abort("production_authority_invalid", "Production club release requires a promoted non-fixture decision")
  }
  invisible(TRUE)
}

phase19_club_release_snapshot_fields <- function(history_snapshot = NULL, current_snapshot = NULL, model = NULL) {
  history_snapshot <- history_snapshot %||% list()
  current_snapshot <- current_snapshot %||% list()
  model <- model %||% list()
  hash <- function(value, fields) phase19_club_release_hash_or_blank(value, fields, "")
  list(
    history_generation_id = phase19_club_release_first(history_snapshot, c("accepted_generation_id", "generation_id", "history_generation_id"), ""),
    history_snapshot_sha256 = hash(history_snapshot, c("snapshot_sha256", "history_snapshot_sha256")),
    corpus_manifest_sha256 = hash(history_snapshot, c("corpus_manifest_sha256", "corpus_sha256")),
    club_registry_sha256 = hash(history_snapshot, c("club_registry_sha256", "registry_sha256")),
    current_ucl_generation_id = phase19_club_release_first(current_snapshot, c("generation_id", "accepted_generation_id", "current_ucl_generation_id", "source_generation_id"), ""),
    current_ucl_snapshot_sha256 = hash(current_snapshot, c("snapshot_sha256", "current_snapshot_sha256")),
    current_ucl_bundle_sha256 = hash(current_snapshot, c("bundle_sha256", "source_bundle_sha256")),
    current_ucl_source_authority = phase19_club_release_first(current_snapshot, c("source_authority", "authority_type", "source_authority_type"), ""),
    current_ucl_identity_generation_id = phase19_club_release_first(current_snapshot, c("identity_generation_id", "registry_generation_id", "identity_generation"), ""),
    current_ucl_roster_sha256 = hash(current_snapshot, c("roster_sha256", "club_roster_sha256")),
    model_data_cutoff_utc = phase19_club_release_first(model, c("cutoff_utc", "model_data_cutoff_utc"), ""),
    calibration_data_cutoff_utc = phase19_club_release_first(model, c("calibration_data_cutoff", "calibration_data_cutoff_utc"), "")
  )
}

`%||%` <- function(left, right) if (is.null(left)) right else left

phase19_club_release_manifest_row <- function(path, relative_path, metadata, artifact_role) {
  row_count <- if (grepl("\\.csv$", relative_path)) {
    nrow(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = ""))
  } else ""
  hash <- phase19_club_release_file_sha256(path)
  data.frame(
    schema_version = phase19_club_release_schema_version(),
    forecast_domain = "club", authority_mode = metadata$authority_mode,
    fixture_authority = if (isTRUE(metadata$fixture_authority)) "TRUE" else "FALSE",
    production_eligible = if (isTRUE(metadata$production_eligible)) "TRUE" else "FALSE",
    release_id = metadata$release_id, selected_model_id = metadata$selected_model_id,
    artifact = relative_path, relative_path = relative_path,
    artifact_role = artifact_role, sha256 = hash, bytes = as.character(file.info(path)$size),
    rows = as.character(row_count), manifest_self_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase19_club_release_write_manifest <- function(staged_root, metadata) {
  required <- phase19_club_release_required_artifacts()
  rows <- lapply(required[required != "release_manifest.csv"], function(relative_path) {
    role <- if (grepl("^model/", relative_path)) "model" else if (grepl("^manifests/", relative_path)) "manifest" else if (grepl("^reports/", relative_path)) "report" else "metadata"
    phase19_club_release_manifest_row(
      phase19_club_release_path_under_root(staged_root, relative_path, must_work = TRUE),
      relative_path, metadata, role
    )
  })
  body <- do.call(rbind, rows)
  self_hash <- phase19_club_release_manifest_body_hash(rbind(body, data.frame(
    schema_version = "", forecast_domain = "", authority_mode = "", fixture_authority = "", production_eligible = "", release_id = "", selected_model_id = "", artifact = "release_manifest.csv", relative_path = "release_manifest.csv", artifact_role = "self", sha256 = "", bytes = "", rows = "", manifest_self_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )))
  self <- body[1L, , drop = FALSE]
  self[,] <- ""
  self$schema_version <- phase19_club_release_schema_version()
  self$forecast_domain <- "club"
  self$authority_mode <- metadata$authority_mode
  self$fixture_authority <- if (isTRUE(metadata$fixture_authority)) "TRUE" else "FALSE"
  self$production_eligible <- if (isTRUE(metadata$production_eligible)) "TRUE" else "FALSE"
  self$release_id <- metadata$release_id
  self$selected_model_id <- metadata$selected_model_id
  self$artifact <- "release_manifest.csv"
  self$relative_path <- "release_manifest.csv"
  self$artifact_role <- "self"
  self$sha256 <- self_hash
  self$manifest_self_sha256 <- self_hash
  manifest <- rbind(body, self)
  manifest <- manifest[order(as.character(manifest$artifact), method = "radix"), , drop = FALSE]
  rownames(manifest) <- NULL
  phase19_club_release_write_csv(manifest, file.path(staged_root, "release_manifest.csv"))
  invisible(manifest)
}

phase19_club_release_manifest_record <- function(value, metadata, name) {
  if (is.null(value)) value <- list()
  scalar <- function(fields, fallback = "") phase19_club_release_first(value, fields, fallback)
  data.frame(
    schema_version = phase19_club_release_schema_version(), manifest_name = name,
    forecast_domain = "club", authority_mode = metadata$authority_mode,
    fixture_authority = if (isTRUE(metadata$fixture_authority)) "TRUE" else "FALSE",
    production_eligible = if (isTRUE(metadata$production_eligible)) "TRUE" else "FALSE",
    release_id = metadata$release_id,
    selected_model_id = scalar(c("selected_model_id")),
    diagnostic_gate_outcome = scalar(c("diagnostic_gate_outcome")),
    authority_eligibility = scalar(c("authority_eligibility")),
    promotion_status = scalar(c("promotion_status")),
    history_generation_id = scalar(c("history_generation_id", "accepted_generation_id")),
    history_snapshot_sha256 = scalar(c("history_snapshot_sha256", "snapshot_sha256")),
    current_generation_id = scalar(c("current_ucl_generation_id", "generation_id")),
    current_snapshot_sha256 = scalar(c("current_ucl_snapshot_sha256", "snapshot_sha256")),
    protocol_sha256 = scalar(c("protocol_sha256")), policy_review_sha256 = scalar(c("policy_review_sha256")),
    fold_registry_sha256 = scalar(c("fold_registry_sha256")), fold_review_sha256 = scalar(c("fold_review_sha256")),
    gate_registry_sha256 = scalar(c("gate_registry_sha256")), seed_registry_sha256 = scalar(c("seed_registry_sha256")),
    evaluation_set_sha256 = scalar(c("evaluation_set_sha256")), decision_sha256 = scalar(c("decision_sha256", "promotion_decision_sha256")),
    gate_results_sha256 = scalar(c("gate_results_sha256")),
    manifest_self_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase19_club_release_write_manifest_record <- function(value, metadata, path, name) {
  row <- phase19_club_release_manifest_record(value, metadata, name)
  hash <- phase19_club_release_table_hash(row, paste0("phase19-club-", name, "-v1"))
  row$manifest_self_sha256 <- hash
  phase19_club_release_write_csv(row, path)
  invisible(row)
}

phase19_club_release_contract_fields <- function(
    decision, metadata, parents, model_path, calibrator_path, model_card_path,
    protocol = NULL, evaluation = NULL, authority = NULL
) {
  protocol <- protocol %||% list()
  evaluation <- evaluation %||% list()
  authority <- authority %||% list()
  candidate <- function(value, fields, fallback = "") phase19_club_release_first(value, fields, fallback)
  hash <- function(value, fields, fallback = "") phase19_club_release_hash_or_blank(value, fields, fallback)
  feature_hash <- hash(protocol, c("feature_contract_sha256"), "")
  unavailable <- candidate(protocol, c("unavailable_feature_ids"), "current_xg|injury|lineup|suspension|player")
  list(
    schema_version = phase19_club_release_schema_version(), forecast_domain = "club", entity_kind = "club",
    authority_mode = metadata$authority_mode, fixture_authority = isTRUE(metadata$fixture_authority),
    production_eligible = isTRUE(metadata$production_eligible), release_id = metadata$release_id,
    selected_model_id = metadata$selected_model_id, candidate_id = as.character(decision$candidate_id),
    incumbent_id = as.character(decision$incumbent_id),
    diagnostic_gate_outcome = as.character(decision$diagnostic_gate_outcome),
    authority_eligibility = as.character(decision$authority_eligibility), promotion_status = as.character(decision$promotion_status),
    history_generation_id = parents$history_generation_id,
    history_snapshot_sha256 = parents$history_snapshot_sha256,
    corpus_manifest_sha256 = parents$corpus_manifest_sha256,
    club_registry_sha256 = parents$club_registry_sha256,
    current_ucl_generation_id = parents$current_ucl_generation_id,
    current_ucl_snapshot_sha256 = parents$current_ucl_snapshot_sha256,
    current_ucl_bundle_sha256 = parents$current_ucl_bundle_sha256,
    current_ucl_source_authority = parents$current_ucl_source_authority,
    current_ucl_identity_generation_id = parents$current_ucl_identity_generation_id,
    current_ucl_roster_sha256 = parents$current_ucl_roster_sha256,
    protocol_sha256 = hash(protocol, c("protocol_sha256"), as.character(decision$protocol_sha256)),
    policy_review_sha256 = hash(protocol, c("policy_review_sha256"), as.character(decision$policy_review_sha256)),
    fold_registry_sha256 = hash(protocol, c("fold_registry_sha256"), as.character(decision$fold_registry_sha256)),
    fold_review_sha256 = hash(protocol, c("fold_review_sha256"), ""),
    gate_registry_sha256 = hash(protocol, c("gate_registry_sha256"), as.character(decision$gate_registry_sha256)),
    seed_registry_sha256 = hash(protocol, c("seed_registry_sha256"), as.character(decision$seed_registry_sha256)),
    evaluation_set_sha256 = hash(evaluation, c("evaluation_set_sha256"), as.character(decision$evaluation_set_sha256)),
    reproducibility_evidence_sha256 = as.character(decision$reproducibility_evidence_sha256),
    promotion_decision_sha256 = as.character(decision$decision_sha256),
    metrics_sha256 = as.character(decision$metrics_sha256), integrity_sha256 = as.character(decision$integrity_sha256),
    gate_results_sha256 = as.character(decision$gate_results_sha256),
    model_artifact = "model/approved_model.rds", model_sha256 = phase19_club_release_file_sha256(model_path),
    calibrator_artifact = "model/calibrator.rds", calibrator_sha256 = phase19_club_release_file_sha256(calibrator_path),
    model_data_cutoff_utc = parents$model_data_cutoff_utc,
    calibration_data_cutoff_utc = parents$calibration_data_cutoff_utc,
    score_support_g = 40L, primary_probability_view = candidate(decision, c("primary_probability_view"), "calibrated_1x2"),
    feature_contract_sha256 = feature_hash, unavailable_feature_ids = unavailable,
    model_card_artifact = "reports/model_card.md", model_card_sha256 = if (file.exists(model_card_path)) phase19_club_release_file_sha256(model_card_path) else "",
    benchmark_report_artifact = "reports/benchmark_report.md", labels_embedded = FALSE,
    code_commit = candidate(protocol, c("code_commit"), ""), decision_sha256 = as.character(decision$decision_sha256),
    manifest_self_sha256 = ""
  )
}

phase19_club_release_model_card_fields <- function() {
  c(
    "forecast_domain", "entity_kind", "authority_mode", "fixture_authority", "production_eligible",
    "release_id", "selected_model_id", "candidate_id", "incumbent_id", "history_generation_id",
    "history_snapshot_sha256", "current_ucl_generation_id", "current_ucl_snapshot_sha256",
    "protocol_sha256", "fold_registry_sha256", "gate_registry_sha256", "evaluation_set_sha256",
    "promotion_decision_sha256", "model_sha256", "calibrator_sha256", "model_data_cutoff_utc",
    "calibration_data_cutoff_utc", "score_support_g", "primary_probability_view", "feature_contract_sha256",
    "unavailable_feature_ids", "labels_embedded"
  )
}

phase19_club_release_model_card_value <- function(value) {
  if (is.logical(value) && length(value) == 1L) {
    ifelse(isTRUE(value), "TRUE", "FALSE")
  } else {
    as.character(value)
  }
}

phase19_club_release_model_card <- function(contract) {
  fields <- phase19_club_release_model_card_fields()
  c(
    "# Phase 19 Club Model Card", "",
    vapply(fields, function(field) paste0(
      "- ", field, ": ", phase19_club_release_model_card_value(contract[[field]])
    ), character(1)),
    "", "This card is generated from the validated club release contract.",
    "Fixture authority is diagnostic-only and cannot become production authority.",
    "All unavailable enrichment features remain value-less and non-imputable.", ""
  )
}

phase19_club_release_benchmark_report <- function(decision, evaluation = NULL) {
  metrics <- if (!is.null(evaluation) && is.list(evaluation)) evaluation$metrics else list()
  metric_lines <- if (length(metrics)) vapply(names(metrics), function(name) paste0("- metric_", name, ": ", as.character(metrics[[name]])), character(1)) else "- metric_source: promotion decision evidence"
  c(
    "# Phase 19 Club Benchmark Report", "",
    paste0("- forecast_domain: club"), paste0("- selected_model_id: ", decision$selected_model_id),
    paste0("- diagnostic_gate_outcome: ", decision$diagnostic_gate_outcome),
    paste0("- authority_eligibility: ", decision$authority_eligibility),
    paste0("- promotion_status: ", decision$promotion_status),
    paste0("- promotion_decision_sha256: ", decision$decision_sha256), "",
    metric_lines
  )
}

#' Stage a fixture-only club release below a temporary root.
#'
#' The staged generation is never written beneath the production club root.
#' Its selector is created only by `phase19_install_club_release()` and is
#' intentionally accepted by the fixture resolver only.
#' @export
phase19_stage_fixture_club_release <- function(
    decision, model, calibrator, output_root, release_id = NULL,
    history_snapshot = NULL, current_snapshot = NULL, protocol = NULL,
    evaluation = NULL, authority = NULL, replay = NULL, integrity = NULL,
    source_evidence = NULL, model_card = NULL
) {
  phase19_club_release_decision_check(decision, "fixture")
  phase19_club_release_source_dependencies()
  if (!isTRUE(phase19_club_release_is_temporary_root(output_root))) {
    phase19_club_release_abort(
      "fixture_root_invalid",
      "Fixture club release output must be below a process-temporary root"
    )
  }
  phase19_club_release_assert_parent_evidence(
    decision, model, calibrator, history_snapshot, current_snapshot,
    protocol, evaluation, authority, replay, integrity, source_evidence
  )
  assert_forecast_domain(model, "club")
  assert_forecast_domain(calibrator, "club")
  if (!identical(as.character(model$model_id), as.character(decision$selected_model_id)) ||
      !identical(as.character(calibrator$candidate_id), as.character(decision$selected_model_id))) {
    phase19_club_release_abort("release_object_invalid", "Fixture model/calibrator IDs do not match promotion decision")
  }
  release_id <- phase19_club_release_safe_id(
    if (is.null(release_id)) paste0("fixture-club-", format(Sys.time(), "%Y%m%d%H%M%S")) else release_id
  )
  output_root <- phase19_club_release_real_root(output_root, create = TRUE)
  if (identical(normalizePath(output_root, winslash = "/", mustWork = TRUE),
                normalizePath(file.path(getwd(), "outputs/releases/club"), winslash = "/", mustWork = FALSE))) {
    phase19_club_release_abort("fixture_root_invalid", "Fixture release cannot use the production club root")
  }
  staged_root <- tempfile(paste0(".", release_id, "-stage-"), tmpdir = output_root)
  dir.create(staged_root, recursive = TRUE, showWarnings = FALSE)
  on.exit(if (dir.exists(staged_root)) unlink(staged_root, recursive = TRUE), add = TRUE)

  metadata <- list(
    release_id = release_id, selected_model_id = as.character(decision$selected_model_id),
    authority_mode = "fixture", fixture_authority = TRUE, production_eligible = FALSE
  )
  parents <- phase19_club_release_snapshot_fields(history_snapshot, current_snapshot, model)
  if (any(!nzchar(vapply(parents[c(
    "history_generation_id", "history_snapshot_sha256", "corpus_manifest_sha256",
    "club_registry_sha256", "current_ucl_generation_id", "current_ucl_snapshot_sha256",
    "current_ucl_bundle_sha256", "current_ucl_source_authority",
    "current_ucl_identity_generation_id", "current_ucl_roster_sha256"
  )], as.character, character(1))))) {
    phase19_club_release_abort(
      "release_parent_invalid", "Fixture release parent identities cannot be blank"
    )
  }
  parents$protocol_sha256 <- phase19_club_release_hash_or_blank(protocol, c("protocol_sha256"), as.character(decision$protocol_sha256))
  parents$policy_review_sha256 <- phase19_club_release_hash_or_blank(protocol, c("policy_review_sha256"), as.character(decision$policy_review_sha256))
  parents$fold_registry_sha256 <- phase19_club_release_hash_or_blank(protocol, c("fold_registry_sha256"), "")
  parents$fold_review_sha256 <- phase19_club_release_hash_or_blank(protocol, c("fold_review_sha256"), "")
  parents$gate_registry_sha256 <- phase19_club_release_hash_or_blank(protocol, c("gate_registry_sha256"), as.character(decision$gate_registry_sha256))
  parents$seed_registry_sha256 <- phase19_club_release_hash_or_blank(protocol, c("seed_registry_sha256"), as.character(decision$seed_registry_sha256))
  parents$evaluation_set_sha256 <- phase19_club_release_hash_or_blank(evaluation, c("evaluation_set_sha256"), as.character(decision$evaluation_set_sha256))
  phase19_club_release_write_rds(model, file.path(staged_root, "model/approved_model.rds"))
  phase19_club_release_write_rds(calibrator, file.path(staged_root, "model/calibrator.rds"))

  history_record <- c(parents, list(
    corpus_manifest_sha256 = parents$corpus_manifest_sha256,
    club_registry_sha256 = parents$club_registry_sha256
  ))
  protocol_record <- c(parents, list(
    feature_contract_sha256 = phase19_club_release_hash_or_blank(protocol, c("feature_contract_sha256"), ""),
    unavailable_feature_ids = phase19_club_release_first(protocol, c("unavailable_feature_ids"), "current_xg|injury|lineup|suspension|player"),
    score_support_g = 40L
  ))
  evaluation_record <- c(parents, list(
    reproducibility_evidence_sha256 = as.character(decision$reproducibility_evidence_sha256),
    metrics_sha256 = as.character(decision$metrics_sha256), integrity_sha256 = as.character(decision$integrity_sha256)
  ))
  promotion_record <- c(parents, list(
    decision_sha256 = as.character(decision$decision_sha256), selected_model_id = as.character(decision$selected_model_id),
    diagnostic_gate_outcome = as.character(decision$diagnostic_gate_outcome), authority_eligibility = as.character(decision$authority_eligibility),
    promotion_status = as.character(decision$promotion_status), gate_results_sha256 = as.character(decision$gate_results_sha256)
  ))
  phase19_club_release_write_manifest_record(history_record, metadata, file.path(staged_root, "manifests/history_manifest.csv"), "history")
  phase19_club_release_write_manifest_record(protocol_record, metadata, file.path(staged_root, "manifests/protocol_manifest.csv"), "protocol")
  phase19_club_release_write_manifest_record(evaluation_record, metadata, file.path(staged_root, "manifests/evaluation_manifest.csv"), "evaluation")
  phase19_club_release_write_manifest_record(promotion_record, metadata, file.path(staged_root, "manifests/promotion_manifest.csv"), "promotion")

  contract <- phase19_club_release_contract_fields(
    decision, metadata, parents,
    file.path(staged_root, "model/approved_model.rds"),
    file.path(staged_root, "model/calibrator.rds"),
    file.path(staged_root, "reports/model_card.md"),
    protocol = protocol, evaluation = evaluation, authority = authority
  )
  # The model card is generated from the contract projection.  Its hash is
  # then bound into the contract and the release manifest.
  card_without_hash <- phase19_club_release_model_card(contract)
  phase19_club_release_write_text(card_without_hash, file.path(staged_root, "reports/model_card.md"))
  contract$model_card_sha256 <- phase19_club_release_file_sha256(file.path(staged_root, "reports/model_card.md"))
  contract$history_manifest_sha256 <- phase19_club_release_file_sha256(file.path(staged_root, "manifests/history_manifest.csv"))
  contract$protocol_manifest_sha256 <- phase19_club_release_file_sha256(file.path(staged_root, "manifests/protocol_manifest.csv"))
  contract$evaluation_manifest_sha256 <- phase19_club_release_file_sha256(file.path(staged_root, "manifests/evaluation_manifest.csv"))
  contract$promotion_manifest_sha256 <- phase19_club_release_file_sha256(file.path(staged_root, "manifests/promotion_manifest.csv"))
  contract$provenance_artifact <- "manifests/provenance.json"
  contract$provenance_sha256 <- ""
  contract$release_manifest_artifact <- "release_manifest.csv"
  contract$release_manifest_sha256 <- ""
  phase19_club_release_write_json(contract, file.path(staged_root, "model_contract.json"))
  phase19_club_release_write_text(
    phase19_club_release_benchmark_report(decision, evaluation),
    file.path(staged_root, "reports/benchmark_report.md")
  )
  phase19_club_release_write_text(c(
    "# Phase 19 Club Release Limitations", "",
    paste0("- authority_mode: ", metadata$authority_mode),
    "- Fixture releases are diagnostic-only and cannot authorize production forecasting.",
    "- Current xG, injury, lineup, suspension, and player evidence is unavailable and non-imputable.",
    "- Goal support is frozen at G=40; no match labels are embedded."
  ), file.path(staged_root, "limitations.md"))
  phase19_club_release_write_json(list(
    schema_version = "phase19-club-release-reproducibility-v1", forecast_domain = "club",
    authority_mode = metadata$authority_mode, fixture_authority = TRUE, production_eligible = FALSE,
    release_id = release_id, protocol_sha256 = parents$protocol_sha256,
    evaluation_set_sha256 = parents$evaluation_set_sha256,
    promotion_decision_sha256 = as.character(decision$decision_sha256),
    seed_registry_sha256 = parents$seed_registry_sha256, labels_embedded = FALSE
  ), file.path(staged_root, "reproducibility.json"))
  provenance <- list(
    schema_version = "phase19-club-release-provenance-v1", forecast_domain = "club",
    authority_mode = metadata$authority_mode, fixture_authority = TRUE, production_eligible = FALSE,
    release_id = release_id, selected_model_id = as.character(decision$selected_model_id),
    history_generation_id = parents$history_generation_id, history_snapshot_sha256 = parents$history_snapshot_sha256,
    current_ucl_generation_id = parents$current_ucl_generation_id, current_ucl_snapshot_sha256 = parents$current_ucl_snapshot_sha256,
    protocol_sha256 = parents$protocol_sha256, evaluation_set_sha256 = parents$evaluation_set_sha256,
    promotion_decision_sha256 = as.character(decision$decision_sha256), code_commit = phase19_club_release_first(protocol, c("code_commit"), ""),
    labels_embedded = FALSE
  )
  phase19_club_release_write_json(provenance, file.path(staged_root, "manifests/provenance.json"))
  contract <- phase19_club_release_contract_fields(
    decision, metadata, parents,
    file.path(staged_root, "model/approved_model.rds"),
    file.path(staged_root, "model/calibrator.rds"),
    file.path(staged_root, "reports/model_card.md"), protocol, evaluation, authority
  )
  contract$model_card_sha256 <- phase19_club_release_file_sha256(file.path(staged_root, "reports/model_card.md"))
  contract$history_manifest_sha256 <- phase19_club_release_file_sha256(file.path(staged_root, "manifests/history_manifest.csv"))
  contract$protocol_manifest_sha256 <- phase19_club_release_file_sha256(file.path(staged_root, "manifests/protocol_manifest.csv"))
  contract$evaluation_manifest_sha256 <- phase19_club_release_file_sha256(file.path(staged_root, "manifests/evaluation_manifest.csv"))
  contract$promotion_manifest_sha256 <- phase19_club_release_file_sha256(file.path(staged_root, "manifests/promotion_manifest.csv"))
  contract$provenance_sha256 <- phase19_club_release_file_sha256(file.path(staged_root, "manifests/provenance.json"))
  phase19_club_release_write_json(contract, file.path(staged_root, "model_contract.json"))
  contract$model_contract_sha256 <- phase19_club_release_file_sha256(file.path(staged_root, "model_contract.json"))
  phase19_club_release_write_manifest(staged_root, metadata)
  # The final manifest self-hash is now immutable.  Contract and card hashes
  # are checked by the validator; release_manifest_sha256 is set after the
  # manifest exists and therefore remains an explicit projection, not a
  # circular input to the manifest itself.
  validated <- phase19_validate_club_release(staged_root, load_models = FALSE, expected_domain = "club")
  on.exit(NULL)
  structure(list(
    release_root = staged_root, release_id = release_id,
    release_manifest_path = file.path(staged_root, "release_manifest.csv"),
    model_contract = validated$model_contract, manifest = validated$release_manifest,
    authority_mode = "fixture", fixture_authority = TRUE, production_eligible = FALSE
  ), class = c("phase19_club_staged_release", "list"))
}

# Short aliases used by the Phase 19 controller and tests.
stage_phase19_fixture_release <- phase19_stage_fixture_club_release

phase19_club_release_manifest_identity_hash <- function(manifest) {
  projection <- manifest[as.character(manifest$artifact) != "release_manifest.csv", , drop = FALSE]
  projection <- projection[order(as.character(projection$artifact), method = "radix"), , drop = FALSE]
  contract <- which(as.character(projection$artifact) == "model_contract.json")
  if (length(contract)) {
    projection$sha256[contract] <- ""
    projection$bytes[contract] <- ""
  }
  if ("manifest_self_sha256" %in% names(projection)) projection$manifest_self_sha256 <- ""
  phase19_club_release_table_hash(projection, "phase19-club-release-manifest-identity-v1")
}

phase19_club_release_refresh_manifest <- function(root, metadata) {
  manifest_path <- phase19_club_release_path_under_root(root, "release_manifest.csv", must_work = TRUE)
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE, colClasses = "character", na.strings = character())
  for (index in seq_len(nrow(manifest))) {
    relative <- as.character(manifest$relative_path[[index]])
    if (!identical(relative, "release_manifest.csv")) {
      path <- phase19_club_release_path_under_root(root, relative, must_work = TRUE)
      manifest$sha256[[index]] <- phase19_club_release_file_sha256(path)
      manifest$bytes[[index]] <- as.character(file.info(path)$size)
      if (grepl("\\.csv$", relative)) manifest$rows[[index]] <- as.character(nrow(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")))
    }
  }
  body <- manifest[manifest$artifact != "release_manifest.csv", , drop = FALSE]
  manifest$manifest_self_sha256[manifest$artifact == "release_manifest.csv"] <- phase19_club_release_manifest_body_hash(manifest)
  manifest$sha256[manifest$artifact == "release_manifest.csv"] <- manifest$manifest_self_sha256[manifest$artifact == "release_manifest.csv"]
  phase19_club_release_write_csv(manifest, manifest_path)
  invisible(manifest)
}

phase19_club_release_parse_model_card <- function(path) {
  lines <- readLines(path, warn = FALSE)
  entries <- lines[grepl("^- [A-Za-z0-9_]+: ", lines)]
  if (!length(entries)) phase19_club_release_abort("release_model_card_invalid", "Club model card has no machine-readable identity projection")
  keys <- sub("^- ([A-Za-z0-9_]+): .*$", "\\1", entries)
  values <- sub("^- [A-Za-z0-9_]+: ", "", entries)
  if (anyDuplicated(keys)) phase19_club_release_abort("release_model_card_invalid", "Club model card identity contains duplicate fields")
  result <- as.list(values); names(result) <- keys
  result
}

phase19_club_release_bool <- function(value) {
  identical(toupper(as.character(value)), "TRUE")
}

phase19_club_release_validate_model_card <- function(path, contract) {
  card <- phase19_club_release_parse_model_card(path)
  fields <- phase19_club_release_model_card_fields()
  if (!identical(names(card), fields)) {
    phase19_club_release_abort(
      "release_model_card_invalid",
      "Club model card must contain the exact complete contract projection"
    )
  }
  for (field in fields) {
    expected <- phase19_club_release_model_card_value(contract[[field]])
    if (!identical(as.character(card[[field]]), expected)) {
      phase19_club_release_abort(
        "release_model_card_invalid",
        paste0("Club model card field drifted: ", field)
      )
    }
  }
  assert_forecast_domain(card, "club")
  invisible(card)
}

phase19_club_release_contract_required <- function() {
  c(
    "schema_version", "forecast_domain", "entity_kind", "authority_mode", "fixture_authority",
    "production_eligible", "release_id", "selected_model_id", "candidate_id", "incumbent_id",
    "diagnostic_gate_outcome", "authority_eligibility", "promotion_status", "history_generation_id",
    "history_snapshot_sha256", "current_ucl_generation_id", "current_ucl_snapshot_sha256",
    "protocol_sha256", "policy_review_sha256", "fold_registry_sha256", "gate_registry_sha256",
    "seed_registry_sha256", "evaluation_set_sha256", "promotion_decision_sha256", "model_artifact",
    "model_sha256", "calibrator_artifact", "calibrator_sha256", "score_support_g",
    "primary_probability_view", "feature_contract_sha256", "unavailable_feature_ids",
    "model_card_artifact", "model_card_sha256", "labels_embedded", "decision_sha256"
  )
}

#' Metadata-first validation of one immutable club release generation.
#'
#' `load_models = FALSE` is the preflight path and never calls `readRDS()`.
#' @export
phase19_validate_club_release <- function(
    root, load_models = TRUE, expected_domain = "club",
    expected_authority_mode = c("fixture", "production")
) {
  phase19_club_release_source_dependencies()
  root <- phase19_club_release_real_root(root)
  if (length(load_models) != 1L || !is.logical(load_models) || is.na(load_models)) phase19_club_release_abort("release_argument_invalid", "load_models must be one logical value")
  if (!identical(expected_domain, "club")) phase19_club_release_abort("domain_mismatch", "Club release validator requires expected_domain=club")
  expected_authority_mode <- match.arg(expected_authority_mode)
  inventory <- phase19_club_release_inventory(root)
  expected_inventory <- sort(phase19_club_release_required_artifacts(), method = "radix")
  if (!identical(inventory, expected_inventory)) {
    phase19_club_release_abort("release_inventory_mismatch", "Club release recursive inventory is not exact")
  }
  manifest_path <- phase19_club_release_path_under_root(root, "release_manifest.csv", must_work = TRUE)
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE, colClasses = "character", na.strings = character())
  manifest_columns <- c("schema_version", "forecast_domain", "authority_mode", "fixture_authority", "production_eligible", "release_id", "selected_model_id", "artifact", "relative_path", "artifact_role", "sha256", "bytes", "rows", "manifest_self_sha256")
  if (!identical(names(manifest), manifest_columns) || nrow(manifest) != length(expected_inventory) || anyDuplicated(manifest$artifact) || anyDuplicated(manifest$relative_path)) phase19_club_release_abort("release_manifest_invalid", "Club release manifest schema or exact inventory is invalid")
  if (!setequal(as.character(manifest$artifact), expected_inventory) || !setequal(as.character(manifest$relative_path), expected_inventory)) phase19_club_release_abort("release_inventory_mismatch", "Club release manifest does not enumerate exact inventory")
  if (any(as.character(manifest$forecast_domain) != "club") || any(as.character(manifest$schema_version) != phase19_club_release_schema_version())) phase19_club_release_abort("domain_mismatch", "Club release manifest domain or schema drifted")
  self <- manifest[manifest$artifact == "release_manifest.csv", , drop = FALSE]
  if (nrow(self) != 1L || !identical(as.character(self$artifact_role[[1L]]), "self") || !identical(as.character(self$relative_path[[1L]]), "release_manifest.csv") || !identical(tolower(as.character(self$manifest_self_sha256[[1L]])), phase19_club_release_manifest_body_hash(manifest))) phase19_club_release_abort("release_manifest_hash_mismatch", "Club release manifest self-hash mismatch")
  if (!grepl("^[0-9a-fA-F]{64}$", as.character(self$sha256[[1L]])) || !identical(tolower(as.character(self$sha256[[1L]])), tolower(as.character(self$manifest_self_sha256[[1L]])))) phase19_club_release_abort("release_manifest_hash_mismatch", "Club release manifest self identity is invalid")
  for (index in seq_len(nrow(manifest))) {
    row <- manifest[index, , drop = FALSE]
    relative <- phase19_club_release_safe_relative_path(row$relative_path[[1L]])
    if (!identical(relative, as.character(row$artifact[[1L]]))) phase19_club_release_abort("release_manifest_invalid", "Club release artifact/path identity drifted")
    path <- phase19_club_release_path_under_root(root, relative, must_work = TRUE)
    if (!identical(relative, "release_manifest.csv")) {
      actual <- phase19_club_release_file_sha256(path)
      if (!identical(tolower(as.character(row$sha256[[1L]])), actual) || !identical(as.character(row$bytes[[1L]]), as.character(file.info(path)$size))) phase19_club_release_abort("release_hash_mismatch", paste0("Club release artifact hash/size mismatch: ", relative))
    }
  }
  contract <- jsonlite::fromJSON(phase19_club_release_path_under_root(root, "model_contract.json", must_work = TRUE), simplifyVector = FALSE)
  required_contract <- phase19_club_release_contract_required()
  if (length(setdiff(required_contract, names(contract)))) phase19_club_release_abort("release_contract_invalid", "Club release model contract is incomplete")
  assert_forecast_domain(contract, expected_domain)
  if (!identical(as.character(contract$entity_kind), "club") || !identical(as.character(contract$schema_version), phase19_club_release_schema_version())) phase19_club_release_abort("domain_mismatch", "Club release model contract entity/schema is invalid")
  if (any(as.character(manifest$authority_mode) != as.character(contract$authority_mode)) ||
      any(as.character(manifest$fixture_authority) != if (isTRUE(contract$fixture_authority)) "TRUE" else "FALSE") ||
      any(as.character(manifest$production_eligible) != if (isTRUE(contract$production_eligible)) "TRUE" else "FALSE")) {
    phase19_club_release_abort("release_contract_invalid", "Club release authority projection drifted across manifest and contract")
  }
  if (identical(expected_authority_mode, "fixture")) {
    if (!identical(as.character(contract$authority_mode), "fixture") ||
        !isTRUE(contract$fixture_authority) || isTRUE(contract$production_eligible) ||
        !as.character(contract$diagnostic_gate_outcome) %in% c("pass", "fail") ||
        !identical(as.character(contract$authority_eligibility), "fixture_ineligible") ||
        !as.character(contract$promotion_status) %in% c("ineligible_fixture", "retained")) {
      phase19_club_release_abort("fixture_authority_invalid", "Fixture release contract is not permanently fixture-ineligible")
    }
  } else if (!identical(as.character(contract$authority_mode), "production") ||
             isTRUE(contract$fixture_authority) || !isTRUE(contract$production_eligible) ||
             !identical(as.character(contract$diagnostic_gate_outcome), "pass") ||
             !identical(as.character(contract$authority_eligibility), "production") ||
             !identical(as.character(contract$promotion_status), "promoted")) {
    phase19_club_release_abort("production_authority_invalid", "Production release contract is not a promoted production authority")
  }
  contract_values <- c("release_id", "selected_model_id", "model_artifact", "calibrator_artifact", "model_card_artifact")
  if (!identical(as.character(contract$release_id), as.character(self$release_id[[1L]])) || !identical(as.character(contract$selected_model_id), as.character(self$selected_model_id[[1L]])) || !identical(as.character(contract$model_artifact), "model/approved_model.rds") || !identical(as.character(contract$calibrator_artifact), "model/calibrator.rds") || !identical(as.character(contract$model_card_artifact), "reports/model_card.md")) phase19_club_release_abort("release_contract_invalid", "Club release contract identity/topology is invalid")
  if (!isTRUE(phase19_club_release_bool(contract$labels_embedded)) && !identical(contract$labels_embedded, FALSE)) phase19_club_release_abort("release_contract_invalid", "Club release labels_embedded must be FALSE")
  for (field in c("model_sha256", "calibrator_sha256", "promotion_decision_sha256", "decision_sha256")) if (!grepl("^[0-9a-fA-F]{64}$", as.character(contract[[field]]))) phase19_club_release_abort("release_contract_invalid", paste0("Club release contract hash is invalid: ", field))
  model_path <- phase19_club_release_path_under_root(root, contract$model_artifact, must_work = TRUE)
  calibrator_path <- phase19_club_release_path_under_root(root, contract$calibrator_artifact, must_work = TRUE)
  model_card_path <- phase19_club_release_path_under_root(root, contract$model_card_artifact, must_work = TRUE)
  if (!identical(tolower(as.character(contract$model_sha256)), phase19_club_release_file_sha256(model_path)) || !identical(tolower(as.character(contract$calibrator_sha256)), phase19_club_release_file_sha256(calibrator_path))) phase19_club_release_abort("release_hash_mismatch", "Club release model object hash identity drifted")
  model_card_row <- manifest[manifest$artifact == contract$model_card_artifact, , drop = FALSE]
  if (nrow(model_card_row) != 1L || !identical(tolower(as.character(contract$model_card_sha256)), phase19_club_release_file_sha256(model_card_path))) phase19_club_release_abort("release_model_card_invalid", "Club model-card hash identity drifted")
  phase19_club_release_validate_model_card(model_card_path, contract)
  promotion_path <- phase19_club_release_path_under_root(root, "manifests/promotion_manifest.csv", must_work = TRUE)
  promotion <- utils::read.csv(promotion_path, stringsAsFactors = FALSE, check.names = FALSE, colClasses = "character", na.strings = character())
  expected_promotion <- if (identical(expected_authority_mode, "fixture")) {
    c(diagnostic_gate_outcome = as.character(contract$diagnostic_gate_outcome),
      authority_eligibility = as.character(contract$authority_eligibility),
      promotion_status = as.character(contract$promotion_status))
  } else {
    c(diagnostic_gate_outcome = "pass", authority_eligibility = "production",
      promotion_status = "promoted")
  }
  if (nrow(promotion) != 1L || !identical(as.character(promotion$forecast_domain[[1L]]), "club") ||
      !identical(as.character(promotion$decision_sha256[[1L]]), as.character(contract$promotion_decision_sha256)) ||
      any(as.character(promotion[names(expected_promotion)][1L, ]) != expected_promotion)) {
    phase19_club_release_abort(
      if (identical(expected_authority_mode, "fixture")) "fixture_authority_invalid" else "production_authority_invalid",
      "Club promotion manifest is not bound to the expected authority decision"
    )
  }
  for (artifact_field in c("history_manifest_sha256", "protocol_manifest_sha256", "evaluation_manifest_sha256", "promotion_manifest_sha256", "provenance_sha256")) {
    if (!is.null(contract[[artifact_field]]) && nzchar(as.character(contract[[artifact_field]]))) {
      relative <- switch(artifact_field, history_manifest_sha256 = "manifests/history_manifest.csv", protocol_manifest_sha256 = "manifests/protocol_manifest.csv", evaluation_manifest_sha256 = "manifests/evaluation_manifest.csv", promotion_manifest_sha256 = "manifests/promotion_manifest.csv", provenance_sha256 = "manifests/provenance.json")
      if (!identical(tolower(as.character(contract[[artifact_field]])), phase19_club_release_file_sha256(phase19_club_release_path_under_root(root, relative, must_work = TRUE)))) phase19_club_release_abort("release_hash_mismatch", paste0("Club release parent artifact hash drifted: ", artifact_field))
    }
  }
  result <- list(release_root = root, release_manifest = manifest, model_contract = contract, release_id = as.character(contract$release_id), forecast_domain = "club")
  if (isTRUE(load_models)) {
    model <- readRDS(model_path)
    calibrator <- readRDS(calibrator_path)
    assert_forecast_domain(model, expected_domain)
    assert_forecast_domain(calibrator, expected_domain)
    validators <- c("phase19_validate_club_goal_fit", "phase19_validate_club_calibrator")
    if (any(!vapply(validators, exists, logical(1), mode = "function"))) {
      phase19_club_release_abort(
        "release_dependency_missing",
        "Club release model validation dependencies must be loaded before object resolution"
      )
    }
    tryCatch(
      phase19_validate_club_goal_fit(model),
      error = function(error) phase19_club_release_abort(
        "release_object_invalid", paste0("Club release goal fit is invalid: ", conditionMessage(error))
      )
    )
    tryCatch(
      phase19_validate_club_calibrator(calibrator, require_fitted = TRUE),
      error = function(error) phase19_club_release_abort(
        "release_object_invalid", paste0("Club release calibrator is invalid: ", conditionMessage(error))
      )
    )
    if (identical(expected_authority_mode, "production") &&
        (!isTRUE(model$production_eligible) ||
         !isTRUE(calibrator$production_eligible) ||
         isTRUE(model$fixture_authority) || isTRUE(calibrator$fixture_authority))) {
      phase19_club_release_abort(
        "production_authority_invalid",
        "Production release objects must both claim validated production eligibility"
      )
    }
    if (!identical(as.character(model$model_id), as.character(contract$selected_model_id)) || !identical(as.character(calibrator$candidate_id), as.character(contract$selected_model_id))) phase19_club_release_abort("release_object_identity_mismatch", "Club release model/calibrator object identity drifted")
    if (!identical(as.character(model$authority_mode), as.character(contract$authority_mode)) || !identical(isTRUE(model$fixture_authority), isTRUE(contract$fixture_authority)) || !identical(as.character(calibrator$authority_mode), as.character(contract$authority_mode))) phase19_club_release_abort("release_object_identity_mismatch", "Club release object authority identity drifted")
    result$model <- model; result$calibrator <- calibrator
  }
  class(result) <- c("phase19_club_release_validation", "list")
  result
}

validate_phase19_club_release <- phase19_validate_club_release
validate_phase19_club_release_bundle <- phase19_validate_club_release

phase19_club_release_acquire_lock <- function(root) {
  root <- phase19_club_release_real_root(root, create = TRUE)
  lock <- file.path(root, ".approved_release.lock")
  if (file.exists(lock)) phase19_club_release_abort("selector_locked", "Club release selector is locked by another publisher")
  if (!file.create(lock, showWarnings = FALSE)) phase19_club_release_abort("selector_locked", "Club release selector lock could not be acquired")
  lock
}

phase19_club_release_write_selector <- function(root, release_id, manifest_path, manifest_sha256) {
  root <- phase19_club_release_real_root(root, create = TRUE)
  release_id <- phase19_club_release_safe_id(release_id)
  manifest_path <- phase19_club_release_safe_relative_path(manifest_path)
  expected <- paste0(release_id, "/release_manifest.csv")
  if (!identical(manifest_path, expected)) phase19_club_release_abort("selector_topology_invalid", "Club selector manifest path disagrees with release identity")
  if (!grepl("^[0-9a-fA-F]{64}$", as.character(manifest_sha256))) phase19_club_release_abort("selector_identity_invalid", "Club selector manifest hash is invalid")
  selector <- data.frame(
    forecast_domain = "club", release_id = release_id, release_manifest_path = manifest_path,
    manifest_sha256 = tolower(as.character(manifest_sha256)), approved_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  selector$row_sha256 <- phase19_club_release_selector_hash(selector)
  path <- file.path(root, "approved_release.csv")
  phase19_club_release_write_csv(selector, path)
  invisible(path)
}

#' Atomically install a staged club generation and replace the local selector.
#' @export
phase19_install_club_release <- function(
    staged_root, output_root, validator = NULL,
    authority_mode = c("fixture", "production"), source_authority = NULL
) {
  staged_root <- phase19_club_release_real_root(staged_root)
  authority_mode <- match.arg(authority_mode)
  if (!is.null(validator)) {
    phase19_club_release_abort(
      "release_argument_invalid",
      "Club release publication does not accept caller-supplied validators"
    )
  }
  if (identical(authority_mode, "production") && is.null(source_authority)) {
    phase19_club_release_abort(
      "production_authority_invalid",
      "Production installation requires the complete accepted Phase 18/19 parent graph"
    )
  }
  if (identical(authority_mode, "fixture") && !is.null(source_authority)) {
    phase19_club_release_abort(
      "release_argument_invalid",
      "Fixture installation cannot accept production authority parents"
    )
  }
  if (identical(authority_mode, "fixture")) {
    output_root <- phase19_club_release_real_root(output_root, create = TRUE)
    if (!isTRUE(phase19_club_release_is_temporary_root(output_root))) {
      phase19_club_release_abort(
        "fixture_root_invalid",
        "Fixture installation must target a process-temporary root"
      )
    }
  } else {
    # Do not create the production root until the source-backed staged bundle
    # has passed metadata, object, and parent-graph validation.
    output_root <- normalizePath(
      as.character(output_root), winslash = "/", mustWork = FALSE
    )
    if (!identical(output_root, phase19_club_release_production_root())) {
      phase19_club_release_abort(
        "production_root_invalid",
        "Production installation must target the fixed production club root"
      )
    }
  }
  # Metadata preflight is deliberately performed before any rename or RDS load.
  preflight <- phase19_validate_club_release(
    staged_root, load_models = FALSE, expected_domain = "club",
    expected_authority_mode = authority_mode
  )
  staged_full <- if (identical(authority_mode, "production")) {
    phase19_validate_club_release(
      staged_root, load_models = TRUE, expected_domain = "club",
      expected_authority_mode = authority_mode
    )
  } else NULL
  if (identical(authority_mode, "production")) {
    phase19_club_release_validate_production_parent_graph(
      source_authority, staged_full$model, staged_full$calibrator
    )
    output_root <- phase19_club_release_real_root(output_root, create = TRUE)
  }
  release_id <- phase19_club_release_safe_id(preflight$model_contract$release_id)
  target <- file.path(output_root, release_id)
  if (file.exists(target)) phase19_club_release_abort("release_immutable", paste0("Club release target already exists: ", release_id))
  lock <- phase19_club_release_acquire_lock(output_root)
  on.exit(if (file.exists(lock)) unlink(lock), add = TRUE)
  if (!file.rename(staged_root, target)) phase19_club_release_abort("release_publish_failed", "Could not atomically install staged club release")
  installed <- FALSE
  on.exit(if (!installed && dir.exists(target)) unlink(target, recursive = TRUE), add = TRUE)
  installed_preflight <- phase19_validate_club_release(
    target, load_models = FALSE, expected_domain = "club",
    expected_authority_mode = authority_mode
  )
  # Loading occurs only after installed metadata and all hashes are trusted.
  installed_full <- phase19_validate_club_release(
    target, load_models = TRUE, expected_domain = "club",
    expected_authority_mode = authority_mode
  )
  if (identical(authority_mode, "production")) {
    # Re-resolve and validate the fixed source graph immediately before the
    # selector write; staged/install-time checks must not become a stale
    # authority window.
    phase19_club_release_validate_production_parent_graph(
      source_authority, installed_full$model, installed_full$calibrator
    )
  }
  manifest_hash <- phase19_club_release_file_sha256(file.path(target, "release_manifest.csv"))
  selector_path <- phase19_club_release_write_selector(output_root, release_id, paste0(release_id, "/release_manifest.csv"), manifest_hash)
  installed <- TRUE
  structure(list(
    release_root = target, release_id = release_id,
    selector_path = selector_path, release_manifest_path = file.path(target, "release_manifest.csv"),
    model_contract = installed_full$model_contract, validation = installed_full,
    preflight = installed_preflight, forecast_domain = "club"
  ), class = c("phase19_club_installed_release", "list"))
}

phase19_install_fixture_club_release <- function(staged_root, output_root) {
  phase19_install_club_release(staged_root, output_root, authority_mode = "fixture")
}

phase19_install_production_club_release <- function(
    staged_root, output_root = phase19_club_release_production_root(),
    source_authority = NULL
) {
  phase19_install_club_release(
    staged_root, output_root, authority_mode = "production",
    source_authority = source_authority
  )
}

install_phase19_club_release <- phase19_install_club_release
install_phase19_club_release_bundle <- phase19_install_club_release

#' Read and validate the self-hashed fixture/club selector without loading RDS.
#' @export
phase19_read_club_selector <- function(selector_path, trusted_root, expected_domain = "club") {
  if (!identical(expected_domain, "club")) phase19_club_release_abort("domain_mismatch", "Club selector requires expected_domain=club")
  trusted_root <- phase19_club_release_real_root(trusted_root)
  expected_path <- file.path(trusted_root, "approved_release.csv")
  if (!file.exists(selector_path) || dir.exists(selector_path) || phase19_club_release_is_symlink(selector_path)) phase19_club_release_abort("selector_missing", "Club selector is missing or symlinked")
  supplied <- normalizePath(selector_path, winslash = "/", mustWork = TRUE)
  if (!identical(supplied, expected_path)) phase19_club_release_abort("selector_path_invalid", "Club selector must be approved_release.csv inside its trusted root")
  selector <- utils::read.csv(supplied, stringsAsFactors = FALSE, check.names = FALSE, colClasses = "character", na.strings = character())
  if (!identical(names(selector), phase19_club_release_selector_columns()) || nrow(selector) != 1L) phase19_club_release_abort("selector_schema_invalid", "Club selector must contain one exact row")
  if (any(!nzchar(as.character(selector[1L, , drop = TRUE])))) phase19_club_release_abort("selector_identity_invalid", "Club selector contains an empty identity")
  assert_forecast_domain(selector, expected_domain)
  if (!identical(tolower(as.character(selector$row_sha256[[1L]])), phase19_club_release_selector_hash(selector))) phase19_club_release_abort("selector_hash_mismatch", "Club selector self-hash mismatch")
  release_id <- phase19_club_release_safe_id(selector$release_id[[1L]])
  relative <- phase19_club_release_safe_relative_path(selector$release_manifest_path[[1L]])
  if (!identical(relative, paste0(release_id, "/release_manifest.csv"))) phase19_club_release_abort("selector_topology_invalid", "Club selector topology disagrees with release identity")
  manifest_path <- phase19_club_release_path_under_root(trusted_root, relative, must_work = TRUE)
  manifest_hash <- phase19_club_release_file_sha256(manifest_path)
  if (!identical(manifest_hash, tolower(as.character(selector$manifest_sha256[[1L]])))) phase19_club_release_abort("selector_manifest_hash_mismatch", "Club selector manifest hash mismatch")
  list(
    selector = selector, selector_path = supplied, selector_self_sha256 = phase19_club_release_selector_hash(selector),
    trusted_root = trusted_root, release_id = release_id, release_root = dirname(manifest_path),
    release_manifest_path = manifest_path, manifest_sha256 = manifest_hash, forecast_domain = "club"
  )
}

read_phase19_club_selector <- phase19_read_club_selector

#' Resolve the selector-authorized club release and close the selector reread window.
#' @export
phase19_resolve_club_release <- function(
    trusted_root = phase19_club_release_production_root(), selector_path = NULL,
    validated_preflight = NULL, expected_domain = "club",
    authority_mode = NULL
) {
  if (!identical(expected_domain, "club")) phase19_club_release_abort("domain_mismatch", "Club resolver requires expected_domain=club")
  trusted_root <- phase19_club_release_real_root(trusted_root)
  if (is.null(authority_mode)) {
    authority_mode <- if (identical(trusted_root, phase19_club_release_production_root())) {
      "production"
    } else {
      "fixture"
    }
  }
  authority_mode <- match.arg(authority_mode, c("fixture", "production"))
  if (identical(authority_mode, "fixture") &&
      !isTRUE(phase19_club_release_is_temporary_root(trusted_root))) {
    phase19_club_release_abort("fixture_root_invalid", "Fixture resolver requires a process-temporary trusted root")
  }
  if (identical(authority_mode, "production") &&
      !identical(trusted_root, phase19_club_release_production_root())) {
    phase19_club_release_abort("production_root_invalid", "Production resolver requires the fixed production trusted root")
  }
  selector_path <- selector_path %||% file.path(trusted_root, "approved_release.csv")
  selected <- phase19_read_club_selector(selector_path, trusted_root, expected_domain)
  preflight <- phase19_validate_club_release(
    selected$release_root, load_models = FALSE, expected_domain = expected_domain,
    expected_authority_mode = authority_mode
  )
  if (!is.null(validated_preflight)) {
    if (!is.list(validated_preflight) || !identical(normalizePath(validated_preflight$release_root, winslash = "/", mustWork = TRUE), selected$release_root) || !identical(as.character(validated_preflight$model_contract$release_id), as.character(preflight$model_contract$release_id))) phase19_club_release_abort("release_preflight_stale", "Club resolver preflight handoff is stale or forged")
  }
  resolved <- phase19_validate_club_release(
    selected$release_root, load_models = TRUE, expected_domain = expected_domain,
    expected_authority_mode = authority_mode
  )
  fresh <- phase19_read_club_selector(selector_path, trusted_root, expected_domain)
  if (!identical(c(selected$selector_self_sha256, selected$manifest_sha256, selected$release_manifest_path), c(fresh$selector_self_sha256, fresh$manifest_sha256, fresh$release_manifest_path))) phase19_club_release_abort("selector_changed_during_resolution", "Club selector changed during resolution")
  list(
    release_root = selected$release_root, release_manifest_path = selected$release_manifest_path,
    release_id = selected$release_id, selector = fresh$selector,
    model_contract = resolved$model_contract, release_manifest = resolved$release_manifest,
    model = resolved$model, calibrator = resolved$calibrator, metadata = resolved$model_contract,
    forecast_domain = "club", preflight = preflight
  )
}

phase19_resolve_fixture_club_release <- function(trusted_root, selector_path = NULL,
                                                 validated_preflight = NULL) {
  phase19_resolve_club_release(
    trusted_root, selector_path, validated_preflight,
    authority_mode = "fixture"
  )
}

phase19_resolve_production_club_release <- function(
    trusted_root = phase19_club_release_production_root(), selector_path = NULL,
    validated_preflight = NULL
) {
  phase19_resolve_club_release(
    trusted_root, selector_path, validated_preflight,
    authority_mode = "production"
  )
}

resolve_phase19_approved_club_release <- phase19_resolve_club_release
resolve_phase19_club_release <- phase19_resolve_club_release

preflight_phase19_club_release <- function(
    trusted_root, release_manifest_path = NULL, authority_mode
) {
  if (missing(authority_mode) || is.null(authority_mode) ||
      length(authority_mode) != 1L || is.na(authority_mode) ||
      !nzchar(as.character(authority_mode))) {
    phase19_club_release_abort(
      "release_authority_invalid",
      "Club release preflight requires an explicit authority_mode"
    )
  }
  authority_mode <- match.arg(authority_mode, c("fixture", "production"))
  trusted_root <- phase19_club_release_real_root(trusted_root)
  if (is.null(release_manifest_path)) {
    selected <- phase19_read_club_selector(file.path(trusted_root, "approved_release.csv"), trusted_root, "club")
    release_manifest_path <- selected$release_manifest_path
  }
  phase19_validate_club_release(
    dirname(release_manifest_path), load_models = FALSE,
    expected_domain = "club", expected_authority_mode = authority_mode
  )
}

phase19_preflight_club_release <- preflight_phase19_club_release

phase19_preflight_fixture_club_release <- function(
    trusted_root, release_manifest_path = NULL
) {
  preflight_phase19_club_release(
    trusted_root, release_manifest_path, authority_mode = "fixture"
  )
}

phase19_preflight_production_club_release <- function(
    trusted_root = phase19_club_release_production_root(), release_manifest_path = NULL
) {
  preflight_phase19_club_release(
    trusted_root, release_manifest_path, authority_mode = "production"
  )
}

#' Validate the production publication gate before touching any output root.
#'
#' The current repository intentionally has no accepted Phase 18 production
#' parents.  This entry point therefore fails closed until all source-backed
#' authority objects are supplied; fixture fields or rehashed decisions are
#' never sufficient.
#' @export
phase19_stage_production_club_release <- function(
    decision, model, calibrator, output_root = file.path("outputs", "releases", "club"),
    history_snapshot = NULL, current_snapshot = NULL, protocol = NULL,
    evaluation = NULL, authority = NULL, fold_protocol = NULL, rating_replay = NULL,
    release_id = NULL
) {
  phase19_club_release_decision_check(decision, "production")
  required <- list(
    history_snapshot = history_snapshot, current_snapshot = current_snapshot,
    protocol = protocol, evaluation = evaluation, authority = authority,
    fold_protocol = fold_protocol, rating_replay = rating_replay
  )
  missing <- names(required)[vapply(required, is.null, logical(1))]
  if (length(missing)) {
    phase19_club_release_abort(
      "production_authority_invalid",
      paste0("Production club release requires source-backed authority: ", paste(missing, collapse = ", "))
    )
  }
  if (!is.list(authority) || !identical(as.character(authority$authority_mode), "production") ||
      isTRUE(authority$fixture_authority) || !isTRUE(authority$production_eligible) ||
      !identical(as.character(authority$status), "ready")) {
    phase19_club_release_abort("production_authority_invalid", "Production source authority is not accepted")
  }
  if (!is.list(history_snapshot) || !is.list(current_snapshot) ||
      !identical(as.character(history_snapshot$authority_mode), "production") ||
      !identical(as.character(current_snapshot$authority_mode), "production") ||
      isTRUE(history_snapshot$fixture_authority) || isTRUE(current_snapshot$fixture_authority) ||
      isTRUE(history_snapshot$promotion_eligible == FALSE) || isTRUE(current_snapshot$promotion_eligible == FALSE)) {
    phase19_club_release_abort("production_authority_invalid", "Fixture or unaccepted snapshots cannot become production release parents")
  }
  if (exists("phase19_validate_club_training_snapshot", mode = "function")) {
    tryCatch(
      phase19_validate_club_training_snapshot(history_snapshot, "production"),
      error = function(error) phase19_club_release_abort("production_authority_invalid", conditionMessage(error))
    )
  }
  if (exists("phase19_validate_current_ucl_club_snapshot", mode = "function")) {
    tryCatch(
      phase19_validate_current_ucl_club_snapshot(current_snapshot, "production"),
      error = function(error) phase19_club_release_abort("production_authority_invalid", conditionMessage(error))
    )
  }
  if (!isTRUE(authority$source_evidence$history_snapshot$promotion_eligible %||% TRUE) ||
      !identical(authority$source_evidence$history_snapshot$snapshot_sha256, history_snapshot$snapshot_sha256) ||
      !identical(authority$source_evidence$current_snapshot$snapshot_sha256, current_snapshot$snapshot_sha256)) {
    phase19_club_release_abort("production_authority_invalid", "Production authority is not independently bound to supplied snapshots")
  }
  phase19_club_release_abort(
    "production_authority_invalid",
    "No genuine accepted Phase 18 history/current-UCL and owner-reviewed Phase 19 protocol are available for production publication"
  )
}

stage_phase19_production_release <- phase19_stage_production_club_release
