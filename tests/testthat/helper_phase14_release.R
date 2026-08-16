phase14_test_project_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/",
  mustWork = TRUE
)

source(file.path(phase14_test_project_root, "R/release/release_bundle.R"), local = .GlobalEnv)
source(file.path(phase14_test_project_root, "R/release/release_install.R"), local = .GlobalEnv)
source(file.path(phase14_test_project_root, "R/release/release_contract.R"), local = .GlobalEnv)

phase14_release_fixture_descriptor <- function(descriptor_dir) {
  descriptor_dir <- normalizePath(descriptor_dir, winslash = "/", mustWork = TRUE)
  contract_path <- file.path(descriptor_dir, "model_contract.json")
  manifest_path <- file.path(descriptor_dir, "release_manifest.csv")
  if (!file.exists(contract_path) || !file.exists(manifest_path)) {
    stop("Phase 14 release fixture descriptor pair is incomplete", call. = FALSE)
  }
  if (nzchar(Sys.readlink(contract_path)) || nzchar(Sys.readlink(manifest_path))) {
    stop("Phase 14 release fixture descriptors must not be symlinks", call. = FALSE)
  }
  contract <- jsonlite::fromJSON(contract_path, simplifyVector = FALSE)
  manifest <- utils::read.csv(
    manifest_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    colClasses = "character",
    na.strings = character()
  )
  required_contract <- c(
    "schema_version", "release_id", "source_release_id", "status",
    "selected_model_id", "model_sha256", "model_data_cutoff", "support_max",
    "raw_probability_view", "primary_probability_view", "calibrator",
    "calibration_gate", "labels_embedded"
  )
  required_calibrator <- c("calibrator_id", "sha256", "fit_status", "calibration_data_cutoff")
  required_gate <- c("gate_id", "sha256", "passed")
  required_manifest <- c(
    "schema_version", "release_id", "release_manifest_path",
    "release_manifest_sha256", "manifest_self_sha256", "selector_path",
    "selector_approved_at_utc", "selector_self_sha256", "model_sha256",
    "calibrator_sha256", "model_data_cutoff", "calibration_data_cutoff",
    "labels_embedded"
  )
  if (length(setdiff(required_contract, names(contract))) ||
      !is.list(contract$calibrator) ||
      length(setdiff(required_calibrator, names(contract$calibrator))) ||
      !is.list(contract$calibration_gate) ||
      length(setdiff(required_gate, names(contract$calibration_gate))) ||
      nrow(manifest) != 1L ||
      length(setdiff(required_manifest, names(manifest)))) {
    stop("Phase 14 release fixture descriptor schema is incomplete", call. = FALSE)
  }
  if (!identical(as.character(contract$schema_version), "phase14-release-fixture-descriptor-v1") ||
      !identical(as.character(manifest$schema_version[[1L]]), "phase14-release-fixture-manifest-v1")) {
    stop("Phase 14 release fixture descriptor schema version is unsupported", call. = FALSE)
  }
  scalar_manifest <- function(name) as.character(manifest[[name]][[1L]])
  if (!identical(as.character(contract$release_id), scalar_manifest("release_id")) ||
      !identical(as.character(contract$model_sha256), scalar_manifest("model_sha256")) ||
      !identical(as.character(contract$calibrator$sha256), scalar_manifest("calibrator_sha256")) ||
      !identical(as.character(contract$model_data_cutoff), scalar_manifest("model_data_cutoff")) ||
      !identical(as.character(contract$calibrator$calibration_data_cutoff), scalar_manifest("calibration_data_cutoff"))) {
    stop("Phase 14 release fixture descriptor identities disagree", call. = FALSE)
  }
  hash_fields <- c(
    as.character(contract$model_sha256), as.character(contract$calibrator$sha256),
    as.character(contract$calibration_gate$sha256),
    scalar_manifest("release_manifest_sha256"), scalar_manifest("manifest_self_sha256"),
    scalar_manifest("selector_self_sha256")
  )
  if (any(!grepl("^[0-9a-f]{64}$", hash_fields))) {
    stop("Phase 14 release fixture descriptor hashes are invalid", call. = FALSE)
  }
  if (!identical(as.integer(contract$support_max), 40L) ||
      !identical(as.character(contract$raw_probability_view), "raw_1x2") ||
      !as.character(contract$primary_probability_view) %in% c("raw_1x2", "calibrated_1x2") ||
      !identical(contract$labels_embedded, FALSE) ||
      !identical(toupper(scalar_manifest("labels_embedded")), "FALSE")) {
    stop("Phase 14 release fixture descriptor probability or label contract is invalid", call. = FALSE)
  }
  lineage <- tolower(unlist(contract, recursive = TRUE, use.names = FALSE))
  forbidden <- "wc2026[^/]*labels|final_evaluation/(labels|predictions|scores)|(^|[/_.-])labels?([/_.-]|$)"
  if (any(grepl(forbidden, lineage, perl = TRUE))) {
    stop("Phase 14 calibration fixture contains forbidden final-label lineage", call. = FALSE)
  }
  list(contract = contract, manifest = manifest, descriptor_dir = descriptor_dir)
}

phase14_release_fixture_gate_hash <- function(contract) {
  material <- c(
    as.character(contract$calibration_gate$gate_id),
    as.character(contract$calibration_gate$passed),
    as.character(contract$calibrator$fit_status),
    as.character(contract$primary_probability_view),
    as.character(contract$model_data_cutoff),
    as.character(contract$calibrator$calibration_data_cutoff),
    as.character(contract$labels_embedded)
  )
  digest::digest(paste(material, collapse = "\n"), algo = "sha256", serialize = FALSE)
}

phase14_release_fixture_selector_hash <- function(selector) {
  projection <- selector
  projection$row_sha256 <- ""
  phase12_release_table_hash(projection)
}

phase14_release_fixture_refresh_manifest <- function(release_root) {
  manifest_path <- file.path(release_root, "release_manifest.csv")
  manifest <- utils::read.csv(
    manifest_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    colClasses = "character",
    na.strings = character()
  )
  body_rows <- which(as.character(manifest$artifact) != "release_manifest.csv")
  for (index in body_rows) {
    path <- phase12_release_path_under_root(
      release_root,
      as.character(manifest$relative_path[[index]]),
      must_work = TRUE
    )
    hash <- phase12_release_file_sha256(path)
    manifest$sha256[[index]] <- hash
    manifest$canonical_content_sha256[[index]] <- hash
    manifest$bytes[[index]] <- as.character(file.info(path)$size)
    if (endsWith(as.character(manifest$relative_path[[index]]), ".csv")) {
      manifest$rows[[index]] <- as.character(nrow(utils::read.csv(
        path,
        stringsAsFactors = FALSE,
        check.names = FALSE,
        colClasses = "character",
        na.strings = character()
      )))
    }
  }
  self <- as.character(manifest$artifact) == "release_manifest.csv"
  manifest$rows[self] <- ""
  manifest$bytes[self] <- ""
  manifest$manifest_self_sha256[self] <- ""
  manifest$sha256[self] <- ""
  manifest$canonical_content_sha256[self] <- ""
  self_hash <- phase12_release_manifest_body_hash(manifest)
  manifest$manifest_self_sha256[self] <- self_hash
  manifest$sha256[self] <- self_hash
  manifest$canonical_content_sha256[self] <- self_hash
  manifest <- manifest[order(as.character(manifest$artifact), method = "radix"), , drop = FALSE]
  phase12_release_write_csv(manifest, manifest_path)
  invisible(manifest)
}

phase14_release_fixture_write_selector <- function(trusted_root, descriptor, manifest_sha256) {
  selector <- data.frame(
    release_id = as.character(descriptor$contract$release_id),
    release_manifest_path = as.character(descriptor$manifest$release_manifest_path[[1L]]),
    manifest_sha256 = manifest_sha256,
    approved_at_utc = as.character(descriptor$manifest$selector_approved_at_utc[[1L]]),
    row_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  selector$row_sha256 <- phase14_release_fixture_selector_hash(selector)
  selector_path <- phase12_release_path_under_root(
    trusted_root,
    as.character(descriptor$manifest$selector_path[[1L]]),
    must_work = FALSE
  )
  phase12_release_write_csv(selector, selector_path)
  list(selector = selector, selector_path = selector_path)
}

phase14_release_fixture_assert_descriptor_hashes <- function(descriptor, identities) {
  expected <- c(
    model_sha256 = as.character(descriptor$contract$model_sha256),
    calibrator_sha256 = as.character(descriptor$contract$calibrator$sha256),
    calibration_gate_sha256 = as.character(descriptor$contract$calibration_gate$sha256),
    release_manifest_sha256 = as.character(descriptor$manifest$release_manifest_sha256[[1L]]),
    manifest_self_sha256 = as.character(descriptor$manifest$manifest_self_sha256[[1L]]),
    selector_self_sha256 = as.character(descriptor$manifest$selector_self_sha256[[1L]])
  )
  actual <- identities[names(expected)]
  if (!identical(unname(expected), unname(actual))) {
    mismatch <- names(expected)[expected != actual]
    stop(
      "Phase 14 materialized release fixture hash mismatch: ",
      paste(mismatch, collapse = ", "),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' Materialize a descriptor-only Phase 14 release fixture under a temporary trusted root.
phase14_materialize_release_fixture_root <- function(descriptor_dir, trusted_root) {
  descriptor <- phase14_release_fixture_descriptor(descriptor_dir)
  contract_descriptor <- descriptor$contract
  trusted_root <- normalizePath(trusted_root, winslash = "/", mustWork = FALSE)
  dir.create(trusted_root, recursive = TRUE, showWarnings = FALSE)
  trusted_root <- normalizePath(trusted_root, winslash = "/", mustWork = TRUE)
  if (nzchar(Sys.readlink(trusted_root))) {
    stop("Phase 14 trusted fixture root must not be a symlink", call. = FALSE)
  }
  release_root <- file.path(trusted_root, as.character(contract_descriptor$release_id))
  selector_path <- file.path(trusted_root, as.character(descriptor$manifest$selector_path[[1L]]))
  if (file.exists(release_root) || dir.exists(release_root) || file.exists(selector_path)) {
    stop("Phase 14 release fixture target already exists", call. = FALSE)
  }
  source_root <- file.path(
    phase14_test_project_root,
    "outputs/releases",
    as.character(contract_descriptor$source_release_id)
  )
  source_root <- normalizePath(source_root, winslash = "/", mustWork = TRUE)
  source_model <- file.path(source_root, "model/approved_model.rds")
  if (!identical(phase12_release_file_sha256(source_model), as.character(contract_descriptor$model_sha256))) {
    stop("Phase 14 release fixture source model hash drifted", call. = FALSE)
  }
  dir.create(release_root, recursive = TRUE, showWarnings = FALSE)
  entries <- list.files(source_root, full.names = TRUE, all.files = TRUE, no.. = TRUE)
  copied <- file.copy(entries, release_root, recursive = TRUE, copy.date = TRUE)
  if (!length(copied) || any(!copied)) {
    stop("Phase 14 release fixture could not copy the incumbent release", call. = FALSE)
  }

  model_path <- file.path(release_root, "model/approved_model.rds")
  calibrator_path <- file.path(release_root, "model/calibrator.rds")
  model <- readRDS(model_path)
  model_cutoff <- format(max(as.Date(model$training_dates)), "%Y-%m-%d")
  if (!identical(model_cutoff, as.character(contract_descriptor$model_data_cutoff))) {
    stop("Phase 14 release fixture model cutoff drifted", call. = FALSE)
  }
  calibrator <- list(
    schema_version = "phase14-calibrator-fixture-v1",
    calibrator_id = as.character(contract_descriptor$calibrator$calibrator_id),
    candidate_id = as.character(contract_descriptor$selected_model_id),
    track_id = "updating",
    fit_status = as.character(contract_descriptor$calibrator$fit_status),
    primary_probability_view = as.character(contract_descriptor$primary_probability_view),
    distribution_unchanged = TRUE,
    model_sha256 = as.character(contract_descriptor$model_sha256),
    model_data_cutoff = as.character(contract_descriptor$model_data_cutoff),
    calibration_data_cutoff = as.character(contract_descriptor$calibrator$calibration_data_cutoff),
    calibration_gate_id = as.character(contract_descriptor$calibration_gate$gate_id),
    calibration_gate_sha256 = as.character(contract_descriptor$calibration_gate$sha256),
    calibration_gate_passed = isTRUE(contract_descriptor$calibration_gate$passed),
    labels_embedded = FALSE
  )
  if (identical(calibrator$fit_status, "fitted")) {
    calibrator$temperature <- 1.125
    calibrator$method <- "multiclass_temperature_scaling"
  } else {
    calibrator$reason <- "synthetic raw fallback fixture; calibration gate did not pass"
  }
  phase12_release_write_rds(calibrator, calibrator_path)
  calibrator_sha256 <- phase12_release_file_sha256(calibrator_path)

  contract_path <- file.path(release_root, "model_contract.json")
  contract <- phase12_release_read_contract(contract_path)
  contract$release_id <- as.character(contract_descriptor$release_id)
  contract$status <- as.character(contract_descriptor$status)
  contract$selected_model_id <- as.character(contract_descriptor$selected_model_id)
  contract$score_support_g <- as.integer(contract_descriptor$support_max)
  contract$primary_probability_view <- as.character(contract_descriptor$primary_probability_view)
  contract$raw_fallback <- list(
    status = if (identical(contract$primary_probability_view, "raw_1x2")) {
      "available; calibration fixture gate blocked"
    } else {
      "available for audit; fitted calibration is primary"
    },
    view = "raw_1x2"
  )
  contract$source_release_id <- as.character(contract_descriptor$source_release_id)
  contract$model_sha256 <- as.character(contract_descriptor$model_sha256)
  contract$calibrator_id <- as.character(contract_descriptor$calibrator$calibrator_id)
  contract$calibrator_sha256 <- calibrator_sha256
  contract$calibrator_fit_status <- as.character(contract_descriptor$calibrator$fit_status)
  contract$raw_probability_view <- "raw_1x2"
  contract$model_data_cutoff <- as.character(contract_descriptor$model_data_cutoff)
  contract$calibration_data_cutoff <- as.character(contract_descriptor$calibrator$calibration_data_cutoff)
  contract$calibration_gate_id <- as.character(contract_descriptor$calibration_gate$gate_id)
  contract$calibration_gate_sha256 <- as.character(contract_descriptor$calibration_gate$sha256)
  contract$calibration_gate_passed <- isTRUE(contract_descriptor$calibration_gate$passed)
  contract$labels_embedded <- FALSE
  if (identical(contract$primary_probability_view, "calibrated_1x2")) {
    freeze <- utils::read.csv(
      file.path(release_root, "manifests/freeze_manifest.csv"),
      stringsAsFactors = FALSE,
      check.names = FALSE,
      colClasses = "character",
      na.strings = character()
    )
    contract$freeze_self_sha256 <- unique(as.character(freeze$freeze_self_sha256))[[1L]]
  }
  phase12_release_write_json(contract, contract_path)

  manifest_path <- file.path(release_root, "release_manifest.csv")
  manifest <- utils::read.csv(
    manifest_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    colClasses = "character",
    na.strings = character()
  )
  metadata <- list(
    release_id = as.character(contract_descriptor$release_id),
    status = as.character(contract_descriptor$status),
    selected_model_id = as.character(contract_descriptor$selected_model_id),
    candidate_id = as.character(contract_descriptor$selected_model_id),
    incumbent_id = as.character(contract_descriptor$selected_model_id),
    track_id = "updating",
    panel_id = "open_core",
    score_support_g = "40",
    primary_probability_view = as.character(contract_descriptor$primary_probability_view),
    raw_fallback_status = as.character(contract$raw_fallback$status)
  )
  for (name in intersect(names(metadata), names(manifest))) {
    manifest[[name]] <- rep(metadata[[name]], nrow(manifest))
  }
  phase12_release_write_csv(manifest, manifest_path)
  manifest <- phase14_release_fixture_refresh_manifest(release_root)
  manifest_sha256 <- phase12_release_file_sha256(manifest_path)
  manifest_self_sha256 <- as.character(
    manifest$manifest_self_sha256[as.character(manifest$artifact) == "release_manifest.csv"][[1L]]
  )
  selector_result <- phase14_release_fixture_write_selector(
    trusted_root,
    descriptor,
    manifest_sha256
  )
  selector_self_sha256 <- as.character(selector_result$selector$row_sha256[[1L]])
  identities <- c(
    model_sha256 = phase12_release_file_sha256(model_path),
    calibrator_sha256 = calibrator_sha256,
    calibration_gate_sha256 = phase14_release_fixture_gate_hash(contract_descriptor),
    release_manifest_sha256 = manifest_sha256,
    manifest_self_sha256 = manifest_self_sha256,
    selector_self_sha256 = selector_self_sha256
  )
  phase14_release_fixture_assert_descriptor_hashes(descriptor, identities)
  phase14_validate_release_fixture_root(trusted_root)
  list(
    trusted_root = trusted_root,
    release_root = release_root,
    release_id = as.character(contract_descriptor$release_id),
    release_manifest_path = manifest_path,
    release_manifest_sha256 = manifest_sha256,
    manifest_self_sha256 = manifest_self_sha256,
    selector_path = selector_result$selector_path,
    selector_self_sha256 = selector_self_sha256,
    model_sha256 = identities[["model_sha256"]],
    calibrator_id = as.character(contract_descriptor$calibrator$calibrator_id),
    calibrator_sha256 = calibrator_sha256,
    fit_status = as.character(contract_descriptor$calibrator$fit_status),
    primary_probability_view = as.character(contract_descriptor$primary_probability_view),
    calibration_gate_id = as.character(contract_descriptor$calibration_gate$gate_id),
    calibration_gate_sha256 = identities[["calibration_gate_sha256"]],
    model_data_cutoff = as.character(contract_descriptor$model_data_cutoff),
    calibration_data_cutoff = as.character(contract_descriptor$calibrator$calibration_data_cutoff)
  )
}

#' Validate the selector-selected release without directory-recency discovery.
phase14_validate_release_fixture_root <- function(trusted_root) {
  trusted_root <- phase12_release_trusted_root(trusted_root)
  selector_path <- file.path(trusted_root, "approved_release.csv")
  if (!file.exists(selector_path) || nzchar(Sys.readlink(selector_path))) {
    stop("Phase 14 release fixture selector is missing or symlinked", call. = FALSE)
  }
  selector <- utils::read.csv(
    selector_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    colClasses = "character",
    na.strings = character()
  )
  expected_selector_columns <- c(
    "release_id", "release_manifest_path", "manifest_sha256",
    "approved_at_utc", "row_sha256"
  )
  if (nrow(selector) != 1L || !identical(names(selector), expected_selector_columns)) {
    stop("Phase 14 release fixture selector must contain one exact row", call. = FALSE)
  }
  if (!identical(
    as.character(selector$row_sha256[[1L]]),
    phase14_release_fixture_selector_hash(selector)
  )) {
    stop("Phase 14 release fixture selector self-hash mismatch", call. = FALSE)
  }
  relative_manifest <- phase12_release_safe_relative_path(
    as.character(selector$release_manifest_path[[1L]])
  )
  manifest_path <- phase12_release_path_under_root(
    trusted_root,
    relative_manifest,
    must_work = TRUE
  )
  release_root <- dirname(manifest_path)
  if (nzchar(Sys.readlink(release_root)) || nzchar(Sys.readlink(manifest_path))) {
    stop("Phase 14 selected release path must not be symlinked", call. = FALSE)
  }
  if (!identical(
    phase12_release_file_sha256(manifest_path),
    as.character(selector$manifest_sha256[[1L]])
  )) {
    stop("Phase 14 selected release manifest hash mismatch", call. = FALSE)
  }
  validated <- validate_phase12_complete_release_bundle(release_root, load_models = TRUE)
  contract <- validated$model_contract
  manifest <- validated$release_manifest
  calibrator <- validated$calibrator
  if (!identical(as.character(contract$release_id), as.character(selector$release_id[[1L]])) ||
      !identical(basename(release_root), as.character(selector$release_id[[1L]]))) {
    stop("Phase 14 selector and release identity disagree", call. = FALSE)
  }
  required_contract <- c(
    "model_sha256", "calibrator_id", "calibrator_sha256", "calibrator_fit_status",
    "raw_probability_view", "model_data_cutoff", "calibration_data_cutoff",
    "calibration_gate_id", "calibration_gate_sha256", "calibration_gate_passed"
  )
  if (length(setdiff(required_contract, names(contract)))) {
    stop("Phase 14 materialized release contract is incomplete", call. = FALSE)
  }
  model_path <- file.path(release_root, as.character(contract$model_artifact))
  calibrator_path <- file.path(release_root, as.character(contract$calibrator_artifact))
  if (!identical(phase12_release_file_sha256(model_path), as.character(contract$model_sha256)) ||
      !identical(phase12_release_file_sha256(calibrator_path), as.character(contract$calibrator_sha256)) ||
      !identical(as.character(calibrator$calibrator_id), as.character(contract$calibrator_id)) ||
      !identical(as.character(calibrator$fit_status), as.character(contract$calibrator_fit_status)) ||
      !identical(as.character(calibrator$calibration_gate_sha256), as.character(contract$calibration_gate_sha256)) ||
      !identical(as.character(calibrator$model_data_cutoff), as.character(contract$model_data_cutoff)) ||
      !identical(as.character(calibrator$calibration_data_cutoff), as.character(contract$calibration_data_cutoff))) {
    stop("Phase 14 materialized release model or calibrator identity drifted", call. = FALSE)
  }
  calibrated <- identical(as.character(contract$primary_probability_view), "calibrated_1x2")
  if (calibrated) {
    if (!identical(as.character(contract$calibrator_fit_status), "fitted") ||
        !isTRUE(contract$calibration_gate_passed) ||
        !isTRUE(calibrator$calibration_gate_passed) ||
        is.null(calibrator$temperature) ||
        !is.finite(as.numeric(calibrator$temperature))) {
      stop("Phase 14 calibrated release requires fitted calibrator and passing gate", call. = FALSE)
    }
  } else if (!identical(as.character(contract$primary_probability_view), "raw_1x2") ||
             !identical(as.character(contract$calibrator_fit_status), "raw_fallback") ||
             isTRUE(contract$calibration_gate_passed) ||
             isTRUE(calibrator$calibration_gate_passed)) {
    stop("Phase 14 raw fallback release identity is invalid", call. = FALSE)
  }
  if (!identical(as.character(contract$raw_probability_view), "raw_1x2") ||
      !identical(as.integer(contract$score_support_g), 40L) ||
      !identical(contract$labels_embedded, FALSE) ||
      !identical(calibrator$labels_embedded, FALSE)) {
    stop("Phase 14 probability, support, or label boundary drifted", call. = FALSE)
  }
  forbidden_paths <- "(^|/)(labels?|wc2026_labels)([._/]|$)|final_evaluation/(labels|predictions|scores)"
  if (any(grepl(forbidden_paths, tolower(as.character(manifest$relative_path)), perl = TRUE))) {
    stop("Phase 14 materialized release contains final-label artifacts", call. = FALSE)
  }
  invisible(TRUE)
}

#' Prove that committed Phase 14 fixtures contain descriptors only.
phase14_assert_no_binary_release_fixtures <- function(fixture_root) {
  fixture_root <- normalizePath(fixture_root, winslash = "/", mustWork = TRUE)
  paths <- list.files(fixture_root, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE)
  paths <- paths[file.exists(paths) & !isTRUE(file.info(paths)$isdir)]
  forbidden_extensions <- "\\.(rds|rda|rdata|qs|fst|feather|parquet)$"
  if (any(grepl(forbidden_extensions, tolower(paths), perl = TRUE))) {
    stop("Phase 14 release fixtures must not commit binary artifacts", call. = FALSE)
  }
  release_descriptor_paths <- paths[grepl("/(raw_release|calibrated_release)/", paths)]
  allowed <- c("model_contract.json", "release_manifest.csv")
  if (length(release_descriptor_paths) != 4L ||
      any(!basename(release_descriptor_paths) %in% allowed) ||
      any(file.info(release_descriptor_paths)$size > 100000L)) {
    stop("Phase 14 release fixtures must contain exactly four compact descriptors", call. = FALSE)
  }
  invisible(TRUE)
}
