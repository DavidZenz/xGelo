#' Label-free Phase 12 candidate freeze and calibration-recipe contract.
#'
#' This file deliberately contains no calibration or final-fit entry points.  It
#' creates the immutable control-plane artifact that those later services must
#' validate before doing any work.

phase12_require_freeze_dependencies <- function() {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for the Phase 12 freeze", call. = FALSE)
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("jsonlite is required for the Phase 12 freeze", call. = FALSE)
  }
  invisible(TRUE)
}

phase12_project_root <- function(project_root = ".") {
  normalizePath(project_root, winslash = "/", mustWork = TRUE)
}

phase12_file_sha256 <- function(path) {
  phase12_require_freeze_dependencies()
  if (!file.exists(path)) stop("Phase 12 artifact is missing: ", path, call. = FALSE)
  digest::digest(path, algo = "sha256", file = TRUE)
}

phase12_scalar <- function(value) {
  if (length(value) == 0L || is.null(value) || is.na(value[[1L]])) return("")
  value <- value[[1L]]
  if (inherits(value, "Date")) return(format(value, "%Y-%m-%d"))
  if (is.logical(value)) return(if (isTRUE(value)) "true" else "false")
  as.character(value)
}

phase12_table_sha256 <- function(data) {
  phase12_require_freeze_dependencies()
  if (!is.data.frame(data)) stop("Phase 12 hash input must be a data frame", call. = FALSE)
  if (!ncol(data)) return(digest::digest("", algo = "sha256", serialize = FALSE))
  columns <- sort(names(data), method = "radix")
  normalized <- data[columns]
  if (nrow(normalized)) {
    keys <- lapply(normalized, function(value) vapply(value, phase12_scalar, character(1)))
    order_args <- c(keys, list(na.last = TRUE, method = "radix"))
    normalized <- normalized[do.call(order, order_args), , drop = FALSE]
  }
  values <- lapply(normalized, function(value) vapply(value, phase12_scalar, character(1)))
  payload <- paste(c(columns, unlist(values, use.names = FALSE)), collapse = "\u001f")
  digest::digest(payload, algo = "sha256", serialize = FALSE)
}

phase12_canonicalize_json <- function(value) {
  if (!is.list(value)) return(value)
  if (!is.null(names(value)) && all(nzchar(names(value)))) {
    value <- value[sort(names(value), method = "radix")]
  }
  lapply(value, phase12_canonicalize_json)
}

phase12_json_bytes <- function(value) {
  phase12_require_freeze_dependencies()
  paste0(
    as.character(jsonlite::toJSON(
      phase12_canonicalize_json(value), auto_unbox = TRUE,
      null = "null", na = "null", digits = 17, pretty = TRUE, force = TRUE
    )),
    "\n"
  )
}

phase12_recipe_spec <- function() {
  list(
    schema_version = "1.0",
    recipe_id = "phase12_multiclass_temperature",
    method = "base-R one-parameter temperature scaling",
    probability_view = "log-derived 1X2 probabilities",
    optimizer = "stats::optim-L-BFGS-B",
    initial_temperature = 1.0,
    temperature_bounds = c(0.25, 4.0),
    epsilon = 1e-15,
    minimum_history_rows = 60L,
    minimum_class_count = 10L,
    seed = 920012L,
    score_support = 40L
  )
}

phase12_write_recipe <- function(path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  recipe <- phase12_recipe_spec()
  writeLines(phase12_json_bytes(recipe), path, useBytes = TRUE)
  list(recipe = recipe, sha256 = phase12_file_sha256(path))
}

phase12_read_json <- function(value, name) {
  phase12_require_freeze_dependencies()
  if (is.character(value) && length(value) == 1L) {
    if (!file.exists(value)) stop(name, " file does not exist", call. = FALSE)
    return(jsonlite::fromJSON(value, simplifyVector = TRUE, simplifyDataFrame = FALSE))
  }
  if (!is.list(value)) stop(name, " must be a JSON path or list", call. = FALSE)
  value
}

phase12_parent_paths <- function() {
  c(
    phase09_promotion_protocol = "data/benchmark/phase09/promotion_protocol.json",
    phase09_run_manifest = "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/run_manifest.csv",
    phase10_run_manifest = "outputs/benchmarks/rolling_tournaments/phase10-statistical-challengers/run_manifest.csv",
    phase11_model_registry = "data/benchmark/phase11/model_registry.csv",
    phase11_run_manifest = "outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers/run_manifest.csv"
  )
}

phase12_freeze_reason_codes <- function() {
  c(
    "holdout_consumed", "candidate_membership_drift", "candidate_order_drift",
    "activation_drift", "candidate_hash_drift", "recipe_drift",
    "support_drift", "threshold_drift", "parent_path_drift",
    "parent_checksum_drift", "code_dirty", "flag_drift"
  )
}

phase12_freeze_fail <- function(code, message) {
  if (!code %in% phase12_freeze_reason_codes()) stop("Unknown Phase 12 freeze reason code", call. = FALSE)
  stop(paste0("phase12_", code, ": ", message), call. = FALSE)
}

phase12_resolve_relative_parent <- function(path, root) {
  path <- as.character(path)
  if (length(path) != 1L || is.na(path) || !nzchar(path)) {
    phase12_freeze_fail("parent_path_drift", "parent paths must be non-empty relative paths")
  }
  if (grepl("^(/|[A-Za-z]:[/\\\\])", path) || grepl("(^|[/\\\\])\\.\\.([/\\\\]|$)", path)) {
    phase12_freeze_fail("parent_path_drift", "parent paths must be relative and cannot escape the project root")
  }
  resolved <- normalizePath(file.path(root, path), winslash = "/", mustWork = FALSE)
  prefix <- paste0(root, "/")
  if (!startsWith(paste0(resolved, "/"), prefix)) {
    phase12_freeze_fail("parent_path_drift", "parent path escapes the project root")
  }
  gsub("\\\\", "/", path)
}

phase12_freeze_parent_graph <- function(
    parent_paths = phase12_parent_paths(), project_root = "."
) {
  phase12_require_freeze_dependencies()
  root <- phase12_project_root(project_root)
  if (is.null(names(parent_paths)) || any(!nzchar(names(parent_paths))) || anyDuplicated(names(parent_paths))) {
    phase12_freeze_fail("parent_path_drift", "parent paths must have unique stable identities")
  }
  paths <- vapply(parent_paths, phase12_resolve_relative_parent, character(1), root = root)
  ids <- names(paths)
  order_index <- order(ids, method = "radix")
  ids <- ids[order_index]
  paths <- paths[order_index]
  hashes <- vapply(seq_along(paths), function(index) {
    absolute <- file.path(root, paths[[index]])
    if (file.exists(absolute)) return(phase12_file_sha256(absolute))
    digest::digest(
      paste("phase12-parent-absent", ids[[index]], paths[[index]], sep = "|"),
      algo = "sha256", serialize = FALSE
    )
  }, character(1))
  parents <- data.frame(
    parent_id = ids, relative_path = paths, sha256 = hashes,
    stringsAsFactors = FALSE
  )
  graph_payload <- paste(
    paste(parents$parent_id, parents$relative_path, parents$sha256, sep = "|"),
    collapse = "\u001f"
  )
  list(
    parents = parents,
    parent_graph_sha256 = digest::digest(graph_payload, algo = "sha256", serialize = FALSE)
  )
}

phase12_as_flag <- function(value, name) {
  parsed <- if (is.logical(value)) value else {
    lowered <- tolower(trimws(as.character(value)))
    ifelse(lowered %in% c("true", "1", "yes"), TRUE,
      ifelse(lowered %in% c("false", "0", "no", ""), FALSE, NA))
  }
  if (length(parsed) != 1L || is.na(parsed)) stop(name, " must be TRUE or FALSE", call. = FALSE)
  isTRUE(parsed)
}

phase12_read_table <- function(value, name) {
  if (is.data.frame(value)) return(value)
  if (!is.character(value) || length(value) != 1L || !file.exists(value)) {
    stop(name, " must be an existing CSV path or data frame", call. = FALSE)
  }
  utils::read.csv(value, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
}

phase12_freeze_candidate_rows <- function(registry) {
  registry <- phase12_read_table(registry, "Phase 11 model registry")
  if (!nrow(registry)) phase12_freeze_fail("candidate_membership_drift", "freeze registry cannot be empty")
  if (nrow(registry) != 9L) phase12_freeze_fail("candidate_membership_drift", "freeze requires exactly nine candidates")
  if (!"candidate_id" %in% names(registry)) phase12_freeze_fail("candidate_membership_drift", "registry requires candidate_id")
  registry[] <- lapply(registry, function(value) {
    if (is.factor(value)) as.character(value) else value
  })
  registry$candidate_id <- enc2utf8(as.character(registry$candidate_id))
  if (any(!nzchar(registry$candidate_id)) || anyDuplicated(registry$candidate_id)) {
    phase12_freeze_fail("candidate_membership_drift", "candidate identities must be non-empty and unique")
  }
  registry <- registry[order(registry$candidate_id, method = "radix"), , drop = FALSE]
  rownames(registry) <- NULL

  active <- if ("active_status" %in% names(registry)) registry$active_status else if ("active" %in% names(registry)) registry$active else rep(TRUE, nrow(registry))
  active <- vapply(active, phase12_as_flag, logical(1), name = "active_status")
  score <- if ("score_status" %in% names(registry)) as.character(registry$score_status) else ifelse(active, "scored", "no_score")
  score[is.na(score) | !nzchar(score)] <- ifelse(active[is.na(score) | !nzchar(score)], "scored", "no_score")
  research <- if ("research_only" %in% names(registry)) registry$research_only else rep(FALSE, nrow(registry))
  research <- vapply(research, phase12_as_flag, logical(1), name = "research_only")
  sealed <- if ("wc2026_sealed" %in% names(registry)) registry$wc2026_sealed else if ("sealed" %in% names(registry)) registry$sealed else rep(FALSE, nrow(registry))
  sealed <- vapply(sealed, phase12_as_flag, logical(1), name = "wc2026_sealed")

  registry$active_status <- active
  registry$score_status <- score
  registry$inactive_reason <- if ("inactive_reason" %in% names(registry)) as.character(registry$inactive_reason) else ifelse(active, "", "registered_inactive")
  registry$research_only <- research
  registry$wc2026_sealed <- sealed
  registry$registry_order <- seq_len(nrow(registry))

  base_fields <- setdiff(names(registry), c("candidate_row_sha256", "row_hash"))
  registration <- if ("registration_sha256" %in% names(registry)) as.character(registry$registration_sha256) else rep("", nrow(registry))
  missing_registration <- is.na(registration) | !grepl("^[0-9a-fA-F]{64}$", registration)
  registration[missing_registration] <- vapply(seq_len(nrow(registry)), function(index) {
    phase12_table_sha256(registry[index, base_fields, drop = FALSE])
  }, character(1))[missing_registration]
  registry$candidate_registration_sha256 <- tolower(registration)
  registry$features_sha256 <- vapply(seq_len(nrow(registry)), function(index) {
    fields <- intersect(c("feature_set_id", "rf_feature_set_id", "context_feature_set_id", "feature_rule", "removed_feature_id", "structural_prior_manifest_sha256"), names(registry))
    phase12_table_sha256(registry[index, fields, drop = FALSE])
  }, character(1))
  registry$settings_identity_sha256 <- vapply(seq_len(nrow(registry)), function(index) {
    fields <- intersect(c("settings", "settings_identity", "settings_sha256", "tuning_protocol_id", "tuning_grid_id", "tuning_grid_sha256"), names(registry))
    phase12_table_sha256(registry[index, fields, drop = FALSE])
  }, character(1))
  registry$panels_sha256 <- vapply(seq_len(nrow(registry)), function(index) {
    fields <- intersect(c("native_panel_id", "panel_id", "mode_id", "mode", "open_fixture_count", "rich_fixture_count", "open_mode_compatible"), names(registry))
    phase12_table_sha256(registry[index, fields, drop = FALSE])
  }, character(1))
  registry$seeds_sha256 <- vapply(seq_len(nrow(registry)), function(index) {
    fields <- intersect(c("seed_policy", "seed_id"), names(registry))
    phase12_table_sha256(registry[index, fields, drop = FALSE])
  }, character(1))
  registry$candidate_row_sha256 <- vapply(seq_len(nrow(registry)), function(index) {
    phase12_table_sha256(registry[index, setdiff(names(registry), "candidate_row_sha256"), drop = FALSE])
  }, character(1))
  registry
}

phase12_assert_unopened_holdout <- function(data = NULL, state = NULL, label_path = NULL) {
  if (!is.null(label_path) && grepl("wc2026_labels[.]csv$", basename(as.character(label_path)), ignore.case = TRUE)) {
    stop("Phase 12 freeze cannot receive the sealed holdout label source", call. = FALSE)
  }
  if (!is.null(state)) {
    fields <- c("labels_opened", "label_opened", "holdout_opened", "holdout_consumed", "final_labels_opened", "label_consumed", "labels_consumed", "consumed")
    for (field in intersect(fields, names(state))) {
      value <- state[[field]]
      if (length(value) && !is.na(value[[1L]]) && phase12_as_flag(value, field)) {
        phase12_freeze_fail("holdout_consumed", paste("holdout is already consumed:", field))
      }
    }
    hash_fields <- intersect(c("label_sha256", "consumed_label_sha256", "final_label_sha256", "label_source_sha256", "consumed_label_hash"), names(state))
    if (length(hash_fields) && any(nzchar(vapply(state[hash_fields], phase12_scalar, character(1))))) {
      phase12_freeze_fail("holdout_consumed", "holdout consumption marker is present")
    }
  }
  if (is.null(data)) return(invisible(TRUE))
  if (!is.data.frame(data)) stop("Phase 12 holdout guard data must be a data frame", call. = FALSE)
  holdout <- rep(FALSE, nrow(data))
  if ("edition_id" %in% names(data)) holdout <- holdout | tolower(as.character(data$edition_id)) == "wc2026"
  if ("fixture_id" %in% names(data)) holdout <- holdout | grepl("^wc2026", tolower(as.character(data$fixture_id)))
  label_columns <- intersect(c("actual_home_goals", "actual_away_goals", "home_score", "away_score", "result", "outcome", "observed_outcome"), names(data))
  if (any(holdout) && length(label_columns)) {
    present <- vapply(label_columns, function(column) any(!is.na(data[[column]][holdout]) & nzchar(as.character(data[[column]][holdout]))), logical(1))
    if (any(present)) phase12_freeze_fail("holdout_consumed", "sealed holdout outcomes are present before freeze")
  }
  invisible(TRUE)
}

phase12_git_identity <- function(project_root) {
  sha <- suppressWarnings(system2("git", c("-C", project_root, "rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE))
  status <- suppressWarnings(system2("git", c("-C", project_root, "status", "--porcelain", "--untracked-files=no", "--", "R", "_targets.R"), stdout = TRUE, stderr = FALSE))
  list(
    source_git_sha = if (length(sha) == 1L) trimws(sha) else "",
    clean_worktree = !length(status) || !nzchar(trimws(status)),
    dirty_code = if (length(status)) paste(status, collapse = "|") else ""
  )
}

phase12_protocol_threshold_hash <- function(protocol) {
  phase12_require_freeze_dependencies()
  selected <- protocol[c("core_gate", "supporting_vetoes", "optional_data_gate", "common_vetoes", "score_support", "freeze", "tie_break_order")]
  digest::digest(phase12_json_bytes(selected), algo = "sha256", serialize = FALSE)
}

phase12_run_manifest_checks <- function(run, candidate_ids) {
  if (nrow(run) != 1L) phase12_freeze_fail("parent_checksum_drift", "Phase 11 run manifest must contain exactly one row")
  if ("candidate_count" %in% names(run) && as.integer(run$candidate_count[[1L]]) != 9L) stop("Phase 11 candidate count drifted", call. = FALSE)
  if ("selected_g" %in% names(run) && as.integer(run$selected_g[[1L]]) != 40L) stop("Phase 11 score support drifted", call. = FALSE)
  for (field in c("wc2026_sealed", "network_free", "research_only", "protected_paths_clean")) {
    if (field %in% names(run) && !phase12_as_flag(run[[field]], field)) phase12_freeze_fail("flag_drift", paste("Phase 11 run manifest flag failed:", field))
  }
  if ("phase12_decision_authority" %in% names(run) && phase12_as_flag(run$phase12_decision_authority, "phase12_decision_authority")) {
    phase12_freeze_fail("activation_drift", "Phase 11 run manifest is already a Phase 12 decision authority")
  }
  if ("candidate_ids" %in% names(run)) {
    registered <- strsplit(as.character(run$candidate_ids[[1L]]), "\\|", fixed = FALSE)[[1L]]
    if (!setequal(registered[nzchar(registered)], candidate_ids)) phase12_freeze_fail("candidate_membership_drift", "Phase 11 candidate identities drifted")
  }
  invisible(TRUE)
}

phase12_freeze_self_hash <- function(manifest) {
  manifest <- phase12_read_table(manifest, "Phase 12 freeze manifest")
  excluded <- intersect(c("freeze_self_sha256", "manifest_self_sha256", "self_hash"), names(manifest))
  phase12_table_sha256(manifest[, setdiff(names(manifest), excluded), drop = FALSE])
}

build_phase12_freeze_manifest <- function(
    registry = "data/benchmark/phase11/model_registry.csv",
    protocol = "data/benchmark/phase09/promotion_protocol.json",
    phase11_run_manifest = "outputs/benchmarks/rolling_tournaments/phase11-hybrid-challengers/run_manifest.csv",
    recipe_path = "data/benchmark/phase12/calibration_recipe.json",
    output_path = "data/benchmark/phase12/freeze_manifest.csv",
    project_root = ".", parent_paths = NULL
) {
  phase12_require_freeze_dependencies()
  root <- phase12_project_root(project_root)
  resolve <- function(path) if (is.character(path) && length(path) == 1L && !grepl("^/", path)) file.path(root, path) else path
  registry_path <- if (is.character(registry) && length(registry) == 1L) resolve(registry) else NULL
  protocol_path <- if (is.character(protocol) && length(protocol) == 1L) resolve(protocol) else NULL
  recipe_path <- resolve(recipe_path)
  output_path <- resolve(output_path)
  phase12_assert_unopened_holdout(state = list(labels_opened = FALSE, holdout_consumed = FALSE))
  registry_value <- if (!is.null(registry_path)) registry_path else registry
  protocol_value <- if (!is.null(protocol_path)) protocol_path else protocol
  rows <- phase12_freeze_candidate_rows(registry_value)
  protocol_object <- phase12_read_json(protocol_value, "Promotion protocol")
  if (is.null(parent_paths)) parent_paths <- phase12_parent_paths()
  phase11_id <- names(parent_paths)[names(parent_paths) == "phase11_run_manifest"]
  if (!length(phase11_id)) stop("Phase 12 parent graph must include phase11_run_manifest", call. = FALSE)
  parent_paths[[phase11_id]] <- phase11_run_manifest
  graph <- phase12_freeze_parent_graph(parent_paths, root)
  phase11_path <- file.path(root, graph$parents$relative_path[graph$parents$parent_id == "phase11_run_manifest"])
  run <- phase12_read_table(phase11_path, "Phase 11 run manifest")
  phase12_run_manifest_checks(run, rows$candidate_id)
  recipe <- phase12_write_recipe(recipe_path)
  git <- phase12_git_identity(root)
  threshold_hash <- phase12_protocol_threshold_hash(protocol_object)
  protocol_file_hash <- if (!is.null(protocol_path)) phase12_file_sha256(protocol_path) else digest::digest(phase12_json_bytes(protocol_object), algo = "sha256", serialize = FALSE)
  run_value <- function(field, fallback) if (field %in% names(run)) run[[field]][[1L]] else fallback
  shared <- data.frame(
    freeze_id = "phase12_freeze_v1",
    freeze_status = "sealed_before_final_labels",
    source_git_sha = git$source_git_sha,
    clean_worktree = git$clean_worktree,
    dirty_code = git$dirty_code,
    candidate_count = 9L,
    selected_g = 40L,
    score_support = 40L,
    thresholds_frozen = TRUE,
    code_frozen = TRUE,
    features_frozen = TRUE,
    settings_frozen = TRUE,
    panels_frozen = TRUE,
    seeds_frozen = TRUE,
    sealed_before_final_labels = TRUE,
    wc2026_sealed = phase12_as_flag(run_value("wc2026_sealed", TRUE), "wc2026_sealed"),
    network_free = phase12_as_flag(run_value("network_free", TRUE), "network_free"),
    protected_paths_clean = phase12_as_flag(run_value("protected_paths_clean", TRUE), "protected_paths_clean"),
    phase12_decision_authority = FALSE,
    recipe_id = as.character(recipe$recipe$recipe_id),
    recipe_sha256 = recipe$sha256,
    promotion_protocol_sha256 = if (!is.null(protocol_object$protocol_sha256)) as.character(protocol_object$protocol_sha256) else protocol_file_hash,
    promotion_protocol_file_sha256 = protocol_file_hash,
    thresholds_sha256 = threshold_hash,
    common_vetoes = paste(as.character(unlist(protocol_object$common_vetoes %||% character())), collapse = "|"),
    parent_graph_sha256 = graph$parent_graph_sha256,
    parent_paths = paste(paste(graph$parents$parent_id, graph$parents$relative_path, sep = "="), collapse = "|"),
    parent_hashes = paste(paste(graph$parents$parent_id, graph$parents$sha256, sep = "="), collapse = "|"),
    phase11_run_manifest_sha256 = graph$parents$sha256[match("phase11_run_manifest", graph$parents$parent_id)],
    validation_reason_order = paste(phase12_freeze_reason_codes(), collapse = "|"),
    stringsAsFactors = FALSE
  )
  aggregate_hash <- function(columns) phase12_table_sha256(rows[, intersect(columns, names(rows)), drop = FALSE])
  shared$candidate_registry_sha256 <- phase12_table_sha256(rows[, intersect(c("candidate_id", "active_status", "score_status", "research_only", "wc2026_sealed", "candidate_registration_sha256", "candidate_row_sha256"), names(rows)), drop = FALSE])
  shared$features_sha256 <- aggregate_hash(c("candidate_id", "features_sha256"))
  shared$settings_sha256 <- aggregate_hash(c("candidate_id", "settings_identity_sha256"))
  shared$panels_sha256 <- aggregate_hash(c("candidate_id", "panels_sha256"))
  shared$seeds_sha256 <- aggregate_hash(c("candidate_id", "seeds_sha256"))
  shared$calibration_recipe_sha256 <- recipe$sha256
  shared$threshold_sha256 <- threshold_hash
  shared$parent_graph_hash <- graph$parent_graph_sha256
  manifest <- cbind(shared[rep(1L, nrow(rows)), , drop = FALSE], rows)
  self_hash <- phase12_freeze_self_hash(manifest)
  manifest$freeze_self_sha256 <- self_hash
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(manifest, output_path, row.names = FALSE, na = "", quote = TRUE)
  validate_phase12_freeze_manifest(
    output_path, registry = registry_value, protocol = protocol_value,
    recipe_path = recipe_path, project_root = root, parent_paths = parent_paths
  )
  manifest
}

`%||%` <- function(x, y) if (is.null(x)) y else x

validate_phase12_freeze_manifest <- function(
    manifest = "data/benchmark/phase12/freeze_manifest.csv",
    registry = "data/benchmark/phase11/model_registry.csv",
    protocol = "data/benchmark/phase09/promotion_protocol.json",
    recipe_path = "data/benchmark/phase12/calibration_recipe.json",
    project_root = ".", parent_paths = NULL
) {
  phase12_require_freeze_dependencies()
  root <- phase12_project_root(project_root)
  resolve <- function(path) if (is.character(path) && length(path) == 1L && !grepl("^/", path)) file.path(root, path) else path
  manifest_path <- if (is.character(manifest) && length(manifest) == 1L) resolve(manifest) else NULL
  manifest_value <- if (!is.null(manifest_path)) phase12_read_table(manifest_path, "Phase 12 freeze manifest") else manifest
  required <- c("freeze_id", "candidate_id", "candidate_count", "selected_g", "recipe_sha256", "parent_graph_sha256", "freeze_self_sha256", "thresholds_frozen", "sealed_before_final_labels", "clean_worktree", "network_free", "wc2026_sealed", "validation_reason_order", "candidate_registry_sha256", "features_sha256", "settings_sha256", "panels_sha256", "seeds_sha256")
  missing <- setdiff(required, names(manifest_value))
  if (length(missing)) stop("Phase 12 freeze manifest missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (nrow(manifest_value) != 9L || anyDuplicated(manifest_value$candidate_id)) phase12_freeze_fail("candidate_membership_drift", "freeze must contain exactly nine unique candidates")
  if (!identical(as.character(manifest_value$candidate_id), sort(as.character(manifest_value$candidate_id), method = "radix"))) phase12_freeze_fail("candidate_order_drift", "candidate order drifted")
  if (any(as.integer(manifest_value$candidate_count) != 9L) || any(as.integer(manifest_value$selected_g) != 40L)) phase12_freeze_fail("support_drift", "score support or candidate count drifted")
  if (any(as.character(manifest_value$validation_reason_order) != paste(phase12_freeze_reason_codes(), collapse = "|"))) phase12_freeze_fail("threshold_drift", "freeze reason-code order drifted")
  for (field in c("thresholds_frozen", "sealed_before_final_labels", "clean_worktree", "network_free", "wc2026_sealed")) {
    if (any(!vapply(manifest_value[[field]], phase12_as_flag, logical(1), name = field))) phase12_freeze_fail("flag_drift", paste("freeze flag failed:", field))
  }
  phase12_assert_unopened_holdout(state = manifest_value[1L, , drop = FALSE])
  self_values <- unique(as.character(manifest_value$freeze_self_sha256))
  if (length(self_values) != 1L || !identical(tolower(self_values), tolower(phase12_freeze_self_hash(manifest_value)))) phase12_freeze_fail("candidate_hash_drift", "freeze self-hash mismatch")
  registry_path <- if (is.character(registry) && length(registry) == 1L) resolve(registry) else NULL
  protocol_path <- if (is.character(protocol) && length(protocol) == 1L) resolve(protocol) else NULL
  registry_value <- if (!is.null(registry_path)) registry_path else registry
  protocol_value <- if (!is.null(protocol_path)) protocol_path else protocol
  expected_rows <- phase12_freeze_candidate_rows(registry_value)
  if (!identical(as.character(manifest_value$candidate_id), as.character(expected_rows$candidate_id))) phase12_freeze_fail("candidate_membership_drift", "candidate membership or order drifted")
  for (field in c("active_status", "score_status", "research_only", "wc2026_sealed", "candidate_registration_sha256", "candidate_row_sha256")) {
    if (field %in% names(expected_rows) && field %in% names(manifest_value) && any(as.character(manifest_value[[field]]) != as.character(expected_rows[[field]]))) phase12_freeze_fail(if (field %in% c("active_status", "score_status")) "activation_drift" else "candidate_hash_drift", paste("candidate", field, "drifted"))
  }
  expected_component_hash <- function(columns) phase12_table_sha256(expected_rows[, intersect(columns, names(expected_rows)), drop = FALSE])
  expected_registry_hash <- phase12_table_sha256(expected_rows[, intersect(c("candidate_id", "active_status", "score_status", "research_only", "wc2026_sealed", "candidate_registration_sha256", "candidate_row_sha256"), names(expected_rows)), drop = FALSE])
  if (!identical(as.character(manifest_value$candidate_registry_sha256[[1L]]), expected_registry_hash)) phase12_freeze_fail("candidate_hash_drift", "candidate registry hash drifted")
  component_specs <- list(features_sha256 = c("candidate_id", "features_sha256"), settings_sha256 = c("candidate_id", "settings_identity_sha256"), panels_sha256 = c("candidate_id", "panels_sha256"), seeds_sha256 = c("candidate_id", "seeds_sha256"))
  for (name in names(component_specs)) {
    if (!identical(as.character(manifest_value[[name]][[1L]]), expected_component_hash(component_specs[[name]]))) phase12_freeze_fail("candidate_hash_drift", paste(name, "drifted"))
  }
  protocol_object <- phase12_read_json(protocol_value, "Promotion protocol")
  if (!identical(as.character(manifest_value$thresholds_sha256[[1L]]), phase12_protocol_threshold_hash(protocol_object))) phase12_freeze_fail("threshold_drift", "threshold identity drifted")
  expected_common_vetoes <- paste(as.character(unlist(protocol_object$common_vetoes %||% character())), collapse = "|")
  if (!identical(as.character(manifest_value$common_vetoes[[1L]]), expected_common_vetoes)) phase12_freeze_fail("threshold_drift", "inherited common veto identities drifted")
  if ("score_support" %in% names(protocol_object) && as.integer(protocol_object$score_support$selected_g) != 40L) phase12_freeze_fail("support_drift", "promotion protocol G drifted")
  if ("freeze" %in% names(protocol_object)) {
    if (!is.null(protocol_object$freeze$thresholds_frozen) && !phase12_as_flag(protocol_object$freeze$thresholds_frozen, "thresholds_frozen")) phase12_freeze_fail("threshold_drift", "promotion protocol thresholds are not frozen")
    if (!is.null(protocol_object$freeze$sealed_before_final_labels) && !phase12_as_flag(protocol_object$freeze$sealed_before_final_labels, "sealed_before_final_labels")) phase12_freeze_fail("holdout_consumed", "promotion protocol is not sealed before final labels")
  }
  recipe_path <- resolve(recipe_path)
  if (!file.exists(recipe_path)) phase12_freeze_fail("recipe_drift", "calibration recipe is missing")
  recipe <- phase12_read_json(recipe_path, "Calibration recipe")
  expected_recipe <- phase12_recipe_spec()
  if (!identical(phase12_json_bytes(recipe), phase12_json_bytes(expected_recipe))) phase12_freeze_fail("recipe_drift", "calibration recipe drifted")
  if (!identical(tolower(as.character(manifest_value$recipe_sha256[[1L]])), tolower(phase12_file_sha256(recipe_path)))) phase12_freeze_fail("recipe_drift", "recipe checksum drifted")
  if (is.null(parent_paths)) parent_paths <- phase12_parent_paths()
  graph <- phase12_freeze_parent_graph(parent_paths, root)
  if (!identical(tolower(as.character(manifest_value$parent_graph_sha256[[1L]])), tolower(graph$parent_graph_sha256))) phase12_freeze_fail("parent_checksum_drift", "parent graph checksum drifted")
  phase11 <- graph$parents[graph$parents$parent_id == "phase11_run_manifest", , drop = FALSE]
  if (nrow(phase11) != 1L || !identical(phase11$relative_path[[1L]], phase12_parent_paths()[["phase11_run_manifest"]])) {
    if (identical(parent_paths, phase12_parent_paths())) phase12_freeze_fail("parent_path_drift", "Phase 11 parent path drifted")
  }
  if (!identical(as.character(manifest_value$phase11_run_manifest_sha256[[1L]]), as.character(phase11$sha256[[1L]]))) phase12_freeze_fail("parent_checksum_drift", "Phase 11 parent checksum drifted")
  run <- phase12_read_table(file.path(root, phase11$relative_path[[1L]]), "Phase 11 run manifest")
  phase12_run_manifest_checks(run, expected_rows$candidate_id)
  current_git <- phase12_git_identity(root)
  if (!current_git$clean_worktree) phase12_freeze_fail("code_dirty", "Phase 12 code is dirty")
  invisible(TRUE)
}
