#' Label-free Phase 12 final-fit identity and admissibility contract.
#'
#' This module records which frozen candidate may be rehydrated for the later
#' one-shot evaluation.  It does not read labels, fit from label-bearing rows,
#' or write a model object.  The active candidate is admitted only through the
#' registered Phase 11 model/provenance identity.

phase12_final_fit_project_root <- function(project_root = ".") {
  if (!identical(project_root, ".")) return(normalizePath(project_root, winslash = "/", mustWork = TRUE))
  candidates <- c(getwd(), file.path(getwd(), "../.."), file.path(getwd(), "../../.."))
  for (candidate in candidates) {
    if (file.exists(file.path(candidate, "data/benchmark/phase12/freeze_manifest.csv"))) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }
  normalizePath(project_root, winslash = "/", mustWork = TRUE)
}

phase12_final_fit_resolve_path <- function(path, project_root = ".") {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    stop("Phase 12 final-fit path must be one non-empty value", call. = FALSE)
  }
  if (grepl("^/", path)) return(normalizePath(path, winslash = "/", mustWork = FALSE))
  file.path(phase12_final_fit_project_root(project_root), path)
}

phase12_final_fit_read_table <- function(value, name, project_root = ".") {
  if (is.data.frame(value)) return(value)
  path <- phase12_final_fit_resolve_path(value, project_root)
  if (!file.exists(path)) stop(name, " is missing: ", value, call. = FALSE)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
}

phase12_final_fit_source_if_missing <- function(relative_path, symbols, project_root = ".") {
  missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function")]
  if (!length(missing)) return(invisible(TRUE))
  path <- phase12_final_fit_resolve_path(relative_path, project_root)
  if (!file.exists(path)) stop("Phase 12 final-fit dependency is missing: ", relative_path, call. = FALSE)
  source(path, local = .GlobalEnv)
  missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function")]
  if (length(missing)) stop("Phase 12 final-fit dependency did not define: ", paste(missing, collapse = ", "), call. = FALSE)
  invisible(TRUE)
}

phase12_final_fit_source_if_missing(
  "R/release/freeze_manifest.R",
  c("phase12_table_sha256", "phase12_file_sha256", "phase12_freeze_reason_codes",
    "phase12_read_table", "validate_phase12_freeze_manifest")
)

phase12_final_fit_expected_active_id <- function() {
  "phase11_rf_dynamic_elo_open"
}

phase12_final_fit_default_paths <- function() {
  c(
    registry = "data/benchmark/phase11/model_registry.csv",
    model_manifests = "outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers/manifests/model_manifests.csv",
    candidate_evidence = "outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers/selection/candidate_evidence.csv",
    ranger_provenance = "data/benchmark/phase11/ranger_provenance.csv",
    calibrators = "outputs/benchmarks/rolling_tournaments/phase12-calibration-release/calibration/calibrators.rds",
    calibration_gate = "outputs/benchmarks/rolling_tournaments/phase12-calibration-release/calibration/calibration_gate.csv",
    protocol = "data/benchmark/phase09/promotion_protocol.json"
  )
}

phase12_final_fit_file_hash <- function(path, project_root = ".") {
  path <- phase12_final_fit_resolve_path(path, project_root)
  if (!file.exists(path)) stop("Phase 12 final-fit artifact is missing: ", path, call. = FALSE)
  phase12_file_sha256(path)
}

phase12_final_fit_normalize_flag <- function(value, name) {
  parsed <- if (is.logical(value)) value else {
    lowered <- tolower(trimws(as.character(value)))
    ifelse(lowered %in% c("true", "1", "yes"), TRUE,
      ifelse(lowered %in% c("false", "0", "no", ""), FALSE, NA))
  }
  if (length(parsed) != 1L || is.na(parsed)) stop(name, " must be TRUE or FALSE", call. = FALSE)
  isTRUE(parsed)
}

phase12_final_fit_present <- function(value) {
  !is.na(value) && nzchar(as.character(value))
}

phase12_final_fit_compare_values <- function(value) {
  if (is.logical(value)) return(ifelse(is.na(value), "", ifelse(value, "TRUE", "FALSE")))
  if (is.numeric(value)) return(ifelse(is.na(value), "", format(value, scientific = FALSE, trim = TRUE)))
  if (is.factor(value)) value <- as.character(value)
  value <- as.character(value)
  value[is.na(value)] <- ""
  value
}

phase12_final_fit_gate_rows <- function(
    calibration_gate = phase12_final_fit_default_paths()[["calibration_gate"]],
    project_root = "."
) {
  gate <- phase12_final_fit_read_table(calibration_gate, "Phase 12 calibration gate", project_root)
  required <- c("candidate_id", "track_id", "score_status", "primary_probability_view", "score_support_g", "reason_codes")
  missing <- setdiff(required, names(gate))
  if (length(missing)) stop("Phase 12 calibration gate is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  gate$candidate_id <- as.character(gate$candidate_id)
  gate$track_id <- as.character(gate$track_id)
  if (nrow(gate) != 9L || anyDuplicated(paste(gate$candidate_id, gate$track_id, sep = "\r"))) {
    stop("Phase 12 calibration gate must contain nine unique candidate/track rows", call. = FALSE)
  }
  if (any(as.integer(gate$score_support_g) != 40L)) stop("Phase 12 calibration gate G drifted", call. = FALSE)
  if (any(!gate$primary_probability_view %in% c("calibrated_1x2", "raw_1x2"))) stop("Phase 12 calibration gate probability view drifted", call. = FALSE)
  gate[order(gate$candidate_id, gate$track_id, method = "radix"), , drop = FALSE]
}

phase12_final_fit_registry_inputs <- function(
    frozen_inputs = NULL, project_root = "."
) {
  paths <- phase12_final_fit_default_paths()
  if (is.null(frozen_inputs)) frozen_inputs <- list()
  if (!is.list(frozen_inputs)) stop("frozen_inputs must be a list", call. = FALSE)
  value <- function(name, path_key) {
    if (!is.null(frozen_inputs[[name]])) return(frozen_inputs[[name]])
    phase12_final_fit_read_table(paths[[path_key]], name, project_root)
  }
  list(
    registry = value("registry", "registry"),
    model_manifests = value("model_manifests", "model_manifests"),
    candidate_evidence = value("candidate_evidence", "candidate_evidence"),
    ranger_provenance = value("ranger_provenance", "ranger_provenance"),
    calibrators = frozen_inputs$calibrators,
    calibrators_path = frozen_inputs$calibrators_path %||% paths[["calibrators"]],
    calibration_gate = frozen_inputs$calibration_gate %||% paths[["calibration_gate"]],
    protocol = frozen_inputs$protocol,
    protocol_path = frozen_inputs$protocol_path %||% paths[["protocol"]]
  )
}

phase12_final_fit_allowlist <- function(
    freeze_manifest = "data/benchmark/phase12/freeze_manifest.csv",
    calibration_gate = phase12_final_fit_default_paths()[["calibration_gate"]],
    project_root = "."
) {
  freeze <- phase12_final_fit_read_table(freeze_manifest, "Phase 12 freeze manifest", project_root)
  required <- c("candidate_id", "active_status", "score_status", "candidate_registration_sha256",
    "features_sha256", "settings_identity_sha256", "panels_sha256", "seeds_sha256",
    "score_support_g", "panel_id", "mode_id", "research_only", "wc2026_sealed")
  missing <- setdiff(required, names(freeze))
  if (length(missing)) stop("Phase 12 freeze manifest is missing final-fit columns: ", paste(missing, collapse = ", "), call. = FALSE)
  gate <- phase12_final_fit_gate_rows(calibration_gate, project_root)
  if (!identical(sort(unique(as.character(freeze$candidate_id))), sort(unique(as.character(gate$candidate_id))))) {
    stop("Phase 12 final-fit allowlist candidate membership drifted", call. = FALSE)
  }
  gate <- gate[match(as.character(freeze$candidate_id), as.character(gate$candidate_id)), , drop = FALSE]
  if (anyNA(gate$candidate_id)) stop("Phase 12 final-fit allowlist could not align calibration rows", call. = FALSE)
  active_gate <- gate$score_status == "scored"
  active_ids <- as.character(freeze$candidate_id)[active_gate]
  if (!identical(active_ids, phase12_final_fit_expected_active_id())) {
    stop("Phase 12 final-fit active allowlist is not the exact registered RF identity", call. = FALSE)
  }
  data.frame(
    candidate_id = as.character(freeze$candidate_id),
    track_id = as.character(gate$track_id),
    active_status = active_gate,
    score_status = ifelse(active_gate, "scored", "no_score"),
    admissible = active_gate,
    no_score_reason = ifelse(active_gate, "", ifelse(nzchar(as.character(gate$reason_codes)), as.character(gate$reason_codes), "inactive_candidate")),
    primary_probability_view = as.character(gate$primary_probability_view),
    score_support_g = as.integer(freeze$score_support_g),
    freeze_row = seq_len(nrow(freeze)),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase12_final_fit_contract_flags <- function(freeze_row, registry_row, provenance_row, gate_row) {
  flags <- c(
    freeze_valid = TRUE,
    candidate_allowlisted = identical(as.character(freeze_row$candidate_id), phase12_final_fit_expected_active_id()),
    adapter_contract_valid = identical(as.character(registry_row$adapter_id), "phase11_hybrid_rf") &&
      identical(as.character(registry_row$adapter_version), "phase11-v1"),
    ranger_provenance_valid = nrow(provenance_row) == 1L &&
      identical(as.character(provenance_row$package[[1L]]), "ranger") &&
      identical(as.character(provenance_row$version[[1L]]), as.character(registry_row$ranger_version[[1L]])),
    panel_contract_valid = identical(as.integer(freeze_row$score_support_g), 40L) &&
      identical(as.character(registry_row$panel_id), "open_core"),
    pre_2026_inputs_only = TRUE,
    calibration_gate_valid = identical(as.character(gate_row$score_status), "scored") &&
      identical(as.integer(gate_row$score_support_g), 40L),
    labels_consumed = FALSE,
    holdout_unopened = TRUE,
    phase12_decision_authority = FALSE
  )
  flags
}

phase12_final_fit_candidate_row <- function(
    candidate_id, frozen_inputs, freeze, allowlist_row, gate_row, track_id = "updating",
    project_root = "."
) {
  registry <- frozen_inputs$registry
  registry_row <- registry[as.character(registry$candidate_id) == candidate_id, , drop = FALSE]
  if (nrow(registry_row) != 1L) stop("Phase 12 final-fit candidate is not uniquely registered", call. = FALSE)
  evidence <- frozen_inputs$candidate_evidence
  evidence_row <- evidence[as.character(evidence$candidate_id) == candidate_id, , drop = FALSE]
  if (nrow(evidence_row) != 1L) stop("Phase 12 final-fit candidate evidence is not unique", call. = FALSE)
  provenance <- frozen_inputs$ranger_provenance
  provenance_row <- provenance[as.character(provenance$schema_version) == "phase11-ranger-provenance-v1", , drop = FALSE]
  if (nrow(provenance_row) != 1L) stop("Phase 12 ranger provenance is not uniquely registered", call. = FALSE)
  flags <- phase12_final_fit_contract_flags(
    freeze[freeze$candidate_id == candidate_id, , drop = FALSE],
    registry_row, provenance_row, gate_row
  )
  active <- isTRUE(allowlist_row$admissible)
  model_hash <- ""
  calibrator_hash <- ""
  model_manifest_hash <- ""
  if (active) {
    model_rows <- frozen_inputs$model_manifests[
      as.character(frozen_inputs$model_manifests$model_id) == candidate_id &
        as.character(frozen_inputs$model_manifests$track_id) == track_id, , drop = FALSE
    ]
    if (!nrow(model_rows)) stop("Phase 12 active final-fit model manifest is missing", call. = FALSE)
    model_hash <- phase12_table_sha256(model_rows)
    model_manifest_hash <- phase12_final_fit_file_hash(
      "outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers/manifests/model_manifests.csv", project_root
    )
    calibrator_hash <- phase12_final_fit_file_hash(frozen_inputs$calibrators_path, project_root)
  }
  data.frame(
    schema_version = "phase12-final-fit-manifest-v1",
    candidate_id = candidate_id, track_id = as.character(track_id),
    active_status = active, score_status = as.character(allowlist_row$score_status),
    admissible = active, primary_probability_view = as.character(allowlist_row$primary_probability_view),
    model_sha256 = model_hash, model_manifest_sha256 = model_manifest_hash,
    calibrator_sha256 = calibrator_hash,
    freeze_id = as.character(freeze$freeze_id[[1L]]),
    freeze_self_sha256 = as.character(freeze$freeze_self_sha256[[1L]]),
    calibration_gate_sha256 = phase12_final_fit_file_hash(frozen_inputs$calibration_gate, project_root),
    recipe_sha256 = as.character(freeze$recipe_sha256[[1L]]),
    promotion_protocol_sha256 = as.character(freeze$promotion_protocol_sha256[[1L]]),
    candidate_registration_sha256 = as.character(freeze$candidate_registration_sha256[freeze$candidate_id == candidate_id][[1L]]),
    features_sha256 = as.character(freeze$features_sha256[freeze$candidate_id == candidate_id][[1L]]),
    settings_sha256 = as.character(freeze$settings_identity_sha256[freeze$candidate_id == candidate_id][[1L]]),
    panels_sha256 = as.character(freeze$panels_sha256[freeze$candidate_id == candidate_id][[1L]]),
    seeds_sha256 = as.character(freeze$seeds_sha256[freeze$candidate_id == candidate_id][[1L]]),
    settings_identity = as.character(registry_row$settings_identity[[1L]] %||% ""),
    feature_set_id = as.character(registry_row$feature_set_id[[1L]] %||% ""),
    panel_id = as.character(registry_row$panel_id[[1L]] %||% ""),
    seed_id = as.integer(registry_row$seed_id[[1L]] %||% NA_integer_),
    ranger_package = as.character(registry_row$ranger_package[[1L]] %||% ""),
    ranger_version = as.character(registry_row$ranger_version[[1L]] %||% ""),
    ranger_provenance_id = as.character(registry_row$ranger_provenance_id[[1L]] %||% ""),
    score_support_g = 40L,
    contract_flags = paste(names(flags)[vapply(flags, isTRUE, logical(1))], collapse = "|"),
    contract_flags_sha256 = phase12_table_sha256(as.data.frame(as.list(flags), stringsAsFactors = FALSE)),
    dirty_code = as.character(freeze$dirty_code[[1L]] %||% ""),
    code_frozen = phase12_final_fit_normalize_flag(freeze$code_frozen[[1L]], "code_frozen"),
    labels_consumed = FALSE, consumed_label_sha256 = "", label_source_path = "",
    holdout_state = "unopened", phase12_decision_authority = FALSE,
    no_score_reason = if (active) "" else as.character(allowlist_row$no_score_reason),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase12_final_fit_row_hash <- function(rows) {
  excluded <- intersect(c("final_fit_self_sha256"), names(rows))
  phase12_table_sha256(rows[, setdiff(names(rows), excluded), drop = FALSE])
}

fit_phase12_release_candidate <- function(
    candidate_id = phase12_final_fit_expected_active_id(),
    frozen_inputs = NULL, calibration_gate = NULL,
    freeze_manifest = "data/benchmark/phase12/freeze_manifest.csv",
    track_id = "updating", project_root = "."
) {
  freeze <- phase12_final_fit_read_table(freeze_manifest, "Phase 12 freeze manifest", project_root)
  inputs <- phase12_final_fit_registry_inputs(frozen_inputs, project_root)
  if (!is.null(calibration_gate)) inputs$calibration_gate <- calibration_gate
  allowlist <- phase12_final_fit_allowlist(freeze, inputs$calibration_gate, project_root)
  allowlist_row <- allowlist[allowlist$candidate_id == candidate_id & allowlist$track_id == track_id, , drop = FALSE]
  if (nrow(allowlist_row) != 1L) stop("Phase 12 final-fit candidate/track is not in the frozen allowlist", call. = FALSE)
  gate <- phase12_final_fit_gate_rows(inputs$calibration_gate, project_root)
  gate_row <- gate[gate$candidate_id == candidate_id & gate$track_id == track_id, , drop = FALSE]
  row <- phase12_final_fit_candidate_row(candidate_id, inputs, freeze, allowlist_row, gate_row, track_id, project_root)
  list(
    schema_version = "phase12-final-fit-candidate-v1", candidate_id = candidate_id,
    track_id = track_id, fit_status = if (isTRUE(row$admissible)) "rehydration_admissible" else "no_score",
    label_free = TRUE, model_sha256 = row$model_sha256[[1L]], calibrator_sha256 = row$calibrator_sha256[[1L]],
    manifest_row = row
  )
}

write_phase12_final_fit_manifest <- function(
    freeze_manifest = "data/benchmark/phase12/freeze_manifest.csv",
    calibration_gate = phase12_final_fit_default_paths()[["calibration_gate"]],
    frozen_inputs = NULL,
    path = "outputs/benchmarks/rolling_tournaments/phase12-calibration-release/final_evaluation/final_fit/final_fit_manifest.csv",
    project_root = "."
) {
  freeze <- phase12_final_fit_read_table(freeze_manifest, "Phase 12 freeze manifest", project_root)
  inputs <- phase12_final_fit_registry_inputs(frozen_inputs, project_root)
  inputs$calibration_gate <- calibration_gate
  allowlist <- phase12_final_fit_allowlist(freeze, calibration_gate, project_root)
  rows <- lapply(seq_len(nrow(allowlist)), function(i) {
    candidate <- as.character(allowlist$candidate_id[[i]])
    track <- as.character(allowlist$track_id[[i]])
    fit_phase12_release_candidate(candidate, inputs, calibration_gate, freeze, track, project_root)$manifest_row
  })
  rows <- do.call(rbind, rows)
  rows <- rows[order(rows$candidate_id, rows$track_id, method = "radix"), , drop = FALSE]
  rows$final_fit_self_sha256 <- phase12_final_fit_row_hash(rows)
  output <- phase12_final_fit_resolve_path(path, project_root)
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(rows, output, row.names = FALSE, na = "", quote = TRUE)
  validate_phase12_final_fit_manifest(output, freeze_manifest, calibration_gate, project_root = project_root)
  invisible(output)
}

validate_phase12_final_fit_manifest <- function(
    manifest = "outputs/benchmarks/rolling_tournaments/phase12-calibration-release/final_evaluation/final_fit/final_fit_manifest.csv",
    freeze_manifest = "data/benchmark/phase12/freeze_manifest.csv",
    calibration_gate = phase12_final_fit_default_paths()[["calibration_gate"]],
    project_root = "."
) {
  rows <- phase12_final_fit_read_table(manifest, "Phase 12 final-fit manifest", project_root)
  required <- c("candidate_id", "track_id", "active_status", "score_status", "admissible", "model_sha256", "calibrator_sha256", "freeze_self_sha256", "calibration_gate_sha256", "recipe_sha256", "promotion_protocol_sha256", "score_support_g", "contract_flags", "contract_flags_sha256", "dirty_code", "code_frozen", "labels_consumed", "consumed_label_sha256", "label_source_path", "holdout_state", "phase12_decision_authority", "no_score_reason", "final_fit_self_sha256")
  missing <- setdiff(required, names(rows))
  if (length(missing)) stop("Phase 12 final-fit manifest is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  if (nrow(rows) != 9L || anyDuplicated(paste(rows$candidate_id, rows$track_id, sep = "\r"))) stop("Phase 12 final-fit manifest must contain nine unique candidate/track rows", call. = FALSE)
  if (any(as.integer(rows$score_support_g) != 40L)) stop("phase12_final_fit_support_drift: final-fit G must be 40", call. = FALSE)
  if (any(as.character(rows$track_id) != "updating")) stop("phase12_final_fit_track_drift: final-fit track must be updating", call. = FALSE)
  freeze <- phase12_final_fit_read_table(freeze_manifest, "Phase 12 freeze manifest", project_root)
  gate <- phase12_final_fit_gate_rows(calibration_gate, project_root)
  allowlist <- phase12_final_fit_allowlist(freeze, calibration_gate, project_root)
  if (!identical(as.character(rows$candidate_id), sort(as.character(rows$candidate_id), method = "radix"))) stop("phase12_final_fit_order_drift: candidate order drifted", call. = FALSE)
  if (!identical(as.character(rows$candidate_id), as.character(allowlist$candidate_id))) stop("phase12_final_fit_candidate_drift: candidate membership drifted", call. = FALSE)
  if (any(as.character(rows$freeze_self_sha256) != as.character(freeze$freeze_self_sha256[[1L]]))) stop("phase12_final_fit_freeze_drift: freeze hash drifted", call. = FALSE)
  if (any(as.character(rows$recipe_sha256) != as.character(freeze$recipe_sha256[[1L]]))) stop("phase12_final_fit_recipe_drift: recipe hash drifted", call. = FALSE)
  expected_gate_hash <- phase12_final_fit_file_hash(calibration_gate, project_root)
  if (any(as.character(rows$calibration_gate_sha256) != expected_gate_hash)) stop("phase12_final_fit_calibration_drift: calibration gate hash drifted", call. = FALSE)
  if (any(as.integer(rows$score_support_g) != as.integer(freeze$score_support_g[match(rows$candidate_id, freeze$candidate_id)]))) stop("phase12_final_fit_support_drift: freeze support drifted", call. = FALSE)
  active <- which(as.logical(rows$admissible))
  if (length(active) != 1L || !identical(as.character(rows$candidate_id[active]), phase12_final_fit_expected_active_id())) stop("phase12_final_fit_activation_drift: active allowlist drifted", call. = FALSE)
  if (any(as.logical(rows$admissible) != as.logical(allowlist$admissible))) stop("phase12_final_fit_activation_drift: admissibility drifted", call. = FALSE)
  if (any(as.logical(rows$labels_consumed)) || any(vapply(rows$consumed_label_sha256, phase12_final_fit_present, logical(1))) || any(vapply(rows$label_source_path, phase12_final_fit_present, logical(1))) || any(as.character(rows$holdout_state) != "unopened") || any(as.logical(rows$phase12_decision_authority))) stop("phase12_final_fit_unopened_state: final-fit manifest is not unopened", call. = FALSE)
  if (any(vapply(rows$dirty_code, phase12_final_fit_present, logical(1))) || any(!vapply(rows$code_frozen, phase12_final_fit_normalize_flag, logical(1), name = "code_frozen"))) stop("phase12_final_fit_code_drift: final-fit code is not frozen", call. = FALSE)
  if (any(!vapply(rows$no_score_reason[!as.logical(rows$admissible)], phase12_final_fit_present, logical(1)))) stop("phase12_final_fit_no_score_reason: inactive candidates require reasons", call. = FALSE)
  if (any(!grepl("^[0-9a-f]{64}$", as.character(rows$model_sha256[active]))) || any(!grepl("^[0-9a-f]{64}$", as.character(rows$calibrator_sha256[active])))) stop("phase12_final_fit_hash_drift: active model/calibrator hashes are invalid", call. = FALSE)
  if (any(vapply(rows$model_sha256[!as.logical(rows$admissible)], phase12_final_fit_present, logical(1))) || any(vapply(rows$calibrator_sha256[!as.logical(rows$admissible)], phase12_final_fit_present, logical(1)))) stop("phase12_final_fit_no_score_hash: inactive candidates must not carry model hashes", call. = FALSE)
  if (any(!grepl("freeze_valid|candidate_allowlisted|adapter_contract_valid|ranger_provenance_valid|panel_contract_valid|pre_2026_inputs_only|calibration_gate_valid|holdout_unopened", rows$contract_flags[active]))) stop("phase12_final_fit_contract_drift: active contract flags are incomplete", call. = FALSE)
  if (is.character(freeze_manifest) && length(freeze_manifest) == 1L && is.character(calibration_gate) && length(calibration_gate) == 1L) {
    inputs <- phase12_final_fit_registry_inputs(NULL, project_root)
    inputs$calibration_gate <- calibration_gate
    expected_rows <- lapply(seq_len(nrow(allowlist)), function(i) {
      candidate <- as.character(allowlist$candidate_id[[i]])
      track <- as.character(allowlist$track_id[[i]])
      fit_phase12_release_candidate(candidate, inputs, calibration_gate, freeze_manifest, track, project_root)$manifest_row
    })
    expected_rows <- do.call(rbind, expected_rows)
    for (field in setdiff(names(expected_rows), "final_fit_self_sha256")) {
      actual <- phase12_final_fit_compare_values(rows[[field]])
      expected <- phase12_final_fit_compare_values(expected_rows[[field]])
      if (!identical(actual, expected)) stop("phase12_final_fit_artifact_drift: ", field, " drifted", call. = FALSE)
    }
  }
  if (!identical(unique(as.character(rows$final_fit_self_sha256)), phase12_final_fit_row_hash(rows))) stop("phase12_final_fit_self_hash: final-fit self-hash mismatch", call. = FALSE)
  invisible(TRUE)
}

`%||%` <- function(x, y) if (is.null(x) || !length(x) || is.na(x[[1L]])) y else x
