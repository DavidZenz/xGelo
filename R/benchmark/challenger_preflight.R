#' Fail-closed dependency and parent-bundle preflight for Phase 10 challengers

.challenger_sha256 <- function(value = NULL, file = FALSE) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for challenger provenance", call. = FALSE)
  }
  if (isTRUE(file)) {
    if (!file.exists(value)) stop("Provenance artifact is missing: ", value, call. = FALSE)
    return(digest::digest(value, algo = "sha256", file = TRUE))
  }
  digest::digest(value, algo = "sha256", serialize = FALSE)
}

.challenger_project_root <- function(path = ".") {
  path <- normalizePath(path, mustWork = TRUE)
  repeat {
    if (dir.exists(file.path(path, ".git")) || file.exists(file.path(path, ".git"))) return(path)
    parent <- dirname(path)
    if (identical(parent, path)) stop("Could not locate the xGelo project root", call. = FALSE)
    path <- parent
  }
}

.challenger_within <- function(path, root) {
  path <- normalizePath(path, mustWork = FALSE)
  root <- normalizePath(root, mustWork = FALSE)
  identical(path, root) || startsWith(path, paste0(root, .Platform$file.sep))
}

.challenger_resolve <- function(path, root, approved_root, must_work = FALSE) {
  resolved <- if (grepl("^(/|[A-Za-z]:[/\\\\])", path)) path else file.path(root, path)
  resolved <- normalizePath(resolved, mustWork = must_work)
  if (!.challenger_within(resolved, approved_root)) {
    stop("Challenger provenance path escapes its approved project root: ", path, call. = FALSE)
  }
  resolved
}

.challenger_canonical_scalar <- function(x) {
  if (inherits(x, "Date")) x <- format(x, "%Y-%m-%d")
  if (is.logical(x)) x <- ifelse(is.na(x), "", ifelse(x, "true", "false"))
  x <- as.character(x)
  x[is.na(x)] <- ""
  x
}

.challenger_canonical_table_sha256 <- function(data, key) {
  if (!is.data.frame(data)) stop("Canonical provenance hashing requires a data frame", call. = FALSE)
  missing <- setdiff(key, names(data))
  if (length(missing)) stop("Canonical provenance key is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  if (nrow(data)) {
    ordering <- lapply(data[key], .challenger_canonical_scalar)
    data <- data[do.call(order, c(ordering, list(na.last = TRUE, method = "radix"))), , drop = FALSE]
  }
  rows <- vapply(seq_len(nrow(data)), function(i) {
    paste(vapply(data[i, , drop = FALSE], .challenger_canonical_scalar, character(1)), collapse = "\x1f")
  }, character(1))
  .challenger_sha256(paste(c(paste(names(data), collapse = "\x1f"), rows), collapse = "\x1e"))
}

.challenger_metadata_sha256 <- function(metadata) {
  fields <- sort(names(metadata), method = "radix")
  values <- vapply(fields, function(field) {
    value <- metadata[[field]]
    if (is.na(value)) value <- ""
    paste0(field, "=", value)
  }, character(1))
  .challenger_sha256(paste(values, collapse = "\x1f"))
}

.challenger_read_index <- function(path) {
  connection <- gzfile(path, open = "rt")
  on.exit(close(connection), add = TRUE)
  as.data.frame(read.dcf(connection, all = TRUE), stringsAsFactors = FALSE, check.names = FALSE)
}

.challenger_archive_description <- function(path, package) {
  expected <- file.path(package, "DESCRIPTION")
  members <- utils::untar(path, list = TRUE)
  if (!identical(members[members == expected], expected)) {
    stop("Verified CRAN archive does not contain exactly one package DESCRIPTION", call. = FALSE)
  }
  extraction_root <- tempfile("cran-description-")
  dir.create(extraction_root)
  on.exit(unlink(extraction_root, recursive = TRUE, force = TRUE), add = TRUE)
  utils::untar(path, files = expected, exdir = extraction_root)
  as.list(as.data.frame(read.dcf(file.path(extraction_root, expected), all = TRUE), stringsAsFactors = FALSE, check.names = FALSE)[1, , drop = TRUE])
}

.challenger_dependency_names <- function(value) {
  if (is.null(value) || is.na(value) || !nzchar(value)) return(character())
  entries <- trimws(strsplit(value, ",", fixed = TRUE)[[1]])
  names <- trimws(sub("\\s*\\(.*$", "", entries))
  setdiff(names[nzchar(names)], "R")
}

.challenger_dependency_inventory <- function(metadata, index) {
  fields <- c("Depends", "Imports", "LinkingTo")
  dependencies <- unique(unlist(lapply(fields, function(field) {
    .challenger_dependency_names(metadata[[field]])
  }), use.names = FALSE))
  approved <- c("Matrix", "methods", "utils", "foreach", "shape", "survival", "Rcpp", "RcppEigen")
  inventory <- do.call(rbind, lapply(sort(dependencies, method = "radix"), function(package) {
    installed <- suppressWarnings(tryCatch(utils::packageDescription(package), error = function(e) NULL))
    index_row <- index[index$Package == package, , drop = FALSE]
    priority <- if (is.null(installed$Priority)) "" else as.character(installed$Priority)
    resolution <- if (priority %in% c("base", "recommended")) {
      "base_or_recommended"
    } else if (!is.null(installed)) {
      "existing_library"
    } else if (nrow(index_row) == 1L) {
      "approved_repository"
    } else {
      "unresolved"
    }
    data.frame(
      package = package,
      fields = paste(fields[vapply(fields, function(field) package %in% .challenger_dependency_names(metadata[[field]]), logical(1))], collapse = "+"),
      resolution = resolution,
      installed_version = if (is.null(installed$Version)) "" else as.character(installed$Version),
      repository_version = if (nrow(index_row) == 1L) as.character(index_row$Version) else "",
      system_requirements = if (is.null(installed$SystemRequirements)) "" else as.character(installed$SystemRequirements),
      stringsAsFactors = FALSE
    )
  }))
  if (is.null(inventory)) {
    inventory <- data.frame(
      package = character(), fields = character(), resolution = character(),
      installed_version = character(), repository_version = character(),
      system_requirements = character(), stringsAsFactors = FALSE
    )
  }
  unexpected <- c(
    paste0("dependency_not_approved:", setdiff(inventory$package, approved)),
    paste0("dependency_unresolved:", inventory$package[inventory$resolution == "unresolved"]),
    paste0("dependency_not_preinstalled:", inventory$package[inventory$resolution == "approved_repository"])
  )
  unexpected <- unexpected[nzchar(sub("^[^:]+:", "", unexpected))]
  serialized <- if (nrow(inventory)) {
    apply(inventory, 1L, function(row) paste(row, collapse = "|"))
  } else {
    character()
  }
  list(
    inventory = inventory,
    serialized = paste(serialized, collapse = "\n"),
    sha256 = .challenger_sha256(paste(serialized, collapse = "\n")),
    unexpected = unexpected
  )
}

.challenger_inventory_from_record <- function(record) {
  serialized <- as.character(record$dependency_inventory)
  lines <- if (is.na(serialized) || !nzchar(serialized)) character() else strsplit(serialized, "\n", fixed = TRUE)[[1]]
  values <- lapply(lines, function(line) {
    parts <- strsplit(paste0(line, "\x1d"), "|", fixed = TRUE)[[1]]
    parts[length(parts)] <- sub("\x1d$", "", parts[length(parts)])
    parts
  })
  if (length(values) && any(lengths(values) != 6L)) {
    stop("Persisted dependency inventory is malformed", call. = FALSE)
  }
  inventory <- if (length(values)) {
    data.frame(do.call(rbind, values), stringsAsFactors = FALSE)
  } else {
    data.frame(matrix(character(), nrow = 0L, ncol = 6L), stringsAsFactors = FALSE)
  }
  names(inventory) <- c("package", "fields", "resolution", "installed_version", "repository_version", "system_requirements")
  actual <- .challenger_sha256(paste(lines, collapse = "\n"))
  if (!identical(actual, tolower(as.character(record$dependency_inventory_sha256)))) {
    stop("Persisted dependency inventory SHA-256 mismatch", call. = FALSE)
  }
  approved <- c("Matrix", "methods", "utils", "foreach", "shape", "survival", "Rcpp", "RcppEigen")
  unexpected <- c(
    paste0("dependency_not_approved:", setdiff(inventory$package, approved)),
    paste0("dependency_unresolved:", inventory$package[inventory$resolution == "unresolved"]),
    paste0("dependency_not_preinstalled:", inventory$package[inventory$resolution == "approved_repository"])
  )
  unexpected <- unexpected[nzchar(sub("^[^:]+:", "", unexpected))]
  list(inventory = inventory, serialized = paste(lines, collapse = "\n"), sha256 = actual, unexpected = unexpected)
}

.challenger_record <- function(provenance) {
  if (is.character(provenance) && length(provenance) == 1L) {
    provenance <- utils::read.csv(
      provenance, stringsAsFactors = FALSE, check.names = FALSE,
      colClasses = "character"
    )
  }
  if (is.data.frame(provenance)) {
    if (nrow(provenance) != 1L) stop("glmnet provenance must contain exactly one row", call. = FALSE)
    return(provenance[1, , drop = FALSE])
  }
  if (is.list(provenance) && !is.null(provenance$record)) return(provenance$record)
  if (is.list(provenance)) return(as.data.frame(provenance, stringsAsFactors = FALSE, check.names = FALSE))
  stop("Unsupported glmnet provenance object", call. = FALSE)
}

#' Canonically hash every installed file in an R package
#'
#' @param package Installed package name.
#' @param lib.loc Optional library containing the package.
#' @return Lowercase SHA-256 over relative paths and file SHA-256 values.
#' @export
hash_installed_package_contents <- function(package, lib.loc = NULL) {
  path <- find.package(package, lib.loc = lib.loc, quiet = TRUE)
  if (!nzchar(path)) stop("Required package is not installed: ", package, call. = FALSE)
  files <- list.files(path, recursive = TRUE, all.files = TRUE, full.names = TRUE, no.. = TRUE)
  files <- files[file.exists(files) & !file.info(files)$isdir]
  relative <- substring(files, nchar(path) + 2L)
  ordering <- order(relative, method = "radix")
  relative <- relative[ordering]
  files <- files[ordering]
  hashes <- vapply(files, .challenger_sha256, character(1), file = TRUE)
  .challenger_sha256(paste(paste(relative, hashes, sep = "\x1f"), collapse = "\x1e"))
}

#' Inventory glmnet Depends, Imports, and LinkingTo packages
#'
#' @param provenance A capture result, one-row provenance data frame, or CSV path.
#' @return Inventory, canonical hash, and any fail-closed findings.
#' @export
inventory_cran_dependencies <- function(provenance) {
  record <- .challenger_record(provenance)
  .challenger_inventory_from_record(record)
}

#' Verify the locally cached archive and official repository metadata
#'
#' This function is intentionally offline: network access is confined to
#' `capture_cran_package_provenance()` before installation.
#'
#' @param provenance A capture result, one-row provenance data frame, or CSV path.
#' @return `TRUE`, invisibly, or an error on any drift.
#' @export
verify_cran_package_archive <- function(provenance) {
  record <- .challenger_record(provenance)
  root <- .challenger_project_root(".")
  cache_root <- file.path(root, "data", "cache", "phase10-cran")
  archive <- .challenger_resolve(as.character(record$archive_path), root, cache_root, must_work = TRUE)
  index <- .challenger_resolve(as.character(record$index_cache_path), root, cache_root, must_work = TRUE)
  if (!identical(.challenger_sha256(index, file = TRUE), tolower(as.character(record$index_sha256)))) {
    stop("Official CRAN index SHA-256 mismatch", call. = FALSE)
  }
  metadata <- .challenger_read_index(index)
  selected <- metadata[metadata$Package == as.character(record$package) & metadata$Version == as.character(record$version), , drop = FALSE]
  if (nrow(selected) != 1L || !identical(.challenger_metadata_sha256(as.list(selected[1, , drop = TRUE])), tolower(as.character(record$package_metadata_sha256)))) {
    stop("Official CRAN package metadata drift", call. = FALSE)
  }
  official_md5 <- tolower(as.character(record$official_checksum))
  actual_md5 <- tolower(unname(tools::md5sum(archive)))
  if (!identical(actual_md5, official_md5)) stop("glmnet archive does not match the official CRAN checksum", call. = FALSE)
  if (!identical(.challenger_sha256(archive, file = TRUE), tolower(as.character(record$archive_sha256)))) {
    stop("glmnet archive SHA-256 mismatch", call. = FALSE)
  }
  if (as.numeric(file.info(archive)$size) != as.numeric(record$archive_bytes)) {
    stop("glmnet archive byte count mismatch", call. = FALSE)
  }
  description <- .challenger_archive_description(archive, as.character(record$package))
  if (!identical(as.character(description$Package), as.character(record$package)) ||
      !identical(as.character(description$Version), as.character(record$version)) ||
      !identical(as.character(description$SystemRequirements), as.character(record$system_requirements))) {
    stop("Verified glmnet DESCRIPTION metadata drift", call. = FALSE)
  }
  invisible(TRUE)
}

.challenger_phase09_identity <- function(bundle_root, expected_bundle_sha256) {
  root <- .challenger_project_root(".")
  approved <- file.path(root, "outputs", "benchmarks", "rolling_tournaments")
  bundle_root <- .challenger_resolve(bundle_root, root, approved, must_work = TRUE)
  manifest_path <- file.path(bundle_root, "manifests", "checksum_manifest.csv")
  if (!file.exists(manifest_path)) stop("Phase 9 checksum manifest is missing", call. = FALSE)
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
  required_columns <- c("artifact", "relative_path", "artifact_role", "sha256", "canonical_content_sha256", "rows", "parent_hashes", "selected_g")
  missing <- setdiff(required_columns, names(manifest))
  if (length(missing)) stop("Phase 9 checksum manifest is missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (anyDuplicated(manifest$artifact)) stop("Phase 9 checksum manifest contains duplicate artifacts", call. = FALSE)
  required <- c(
    "model_manifests", "feature_coverage", "fixture_predictions", "score_distributions",
    "stage_probabilities", "fixture_scores", "benchmark_summaries", "paired_comparisons",
    "promotion_decisions", "run_manifest"
  )
  output <- manifest[manifest$artifact %in% required, , drop = FALSE]
  if (!setequal(output$artifact, required)) stop("Phase 9 checksum manifest is incomplete", call. = FALSE)
  for (i in seq_len(nrow(output))) {
    path <- .challenger_resolve(output$relative_path[i], bundle_root, bundle_root, must_work = TRUE)
    if (!identical(.challenger_sha256(path, file = TRUE), tolower(output$sha256[i]))) {
      stop("Phase 9 output checksum mismatch: ", output$artifact[i], call. = FALSE)
    }
    if (as.numeric(file.info(path)$size) != as.numeric(output$bytes[i])) {
      stop("Phase 9 output byte count mismatch: ", output$artifact[i], call. = FALSE)
    }
  }
  self <- manifest[manifest$artifact == "checksum_manifest", , drop = FALSE]
  body <- manifest[manifest$artifact != "checksum_manifest", , drop = FALSE]
  if (nrow(self) != 1L) stop("Phase 9 checksum self row is missing", call. = FALSE)
  self_hash <- .challenger_canonical_table_sha256(body, c("artifact", "relative_path"))
  if (!identical(self_hash, tolower(self$canonical_content_sha256))) {
    stop("Phase 9 checksum manifest self-hash mismatch", call. = FALSE)
  }
  input <- manifest[manifest$artifact_role == "input", , drop = FALSE]
  input <- input[order(input$artifact, method = "radix"), , drop = FALSE]
  parent_graph <- .challenger_sha256(paste(input$canonical_content_sha256, collapse = "|"))
  if (any(tolower(output$parent_hashes) != parent_graph)) {
    stop("Phase 9 output parent graph mismatch", call. = FALSE)
  }
  content <- output$canonical_content_sha256
  names(content) <- output$artifact
  content <- content[sort(names(content), method = "radix")]
  bundle_sha256 <- .challenger_sha256(paste(content, collapse = "|"))
  if (!identical(bundle_sha256, tolower(expected_bundle_sha256))) {
    stop("Phase 9 bundle identity mismatch", call. = FALSE)
  }
  run <- utils::read.csv(file.path(bundle_root, "run_manifest.csv"), stringsAsFactors = FALSE, check.names = FALSE)
  flags <- c("reproducible", "wc2026_sealed", "network_free", "score_support_audit_valid", "registration_settings_stable", "output_coverage_reconciled")
  if (nrow(run) != 1L || any(!vapply(run[flags], function(value) isTRUE(as.logical(value[[1]])), logical(1)))) {
    stop("Phase 9 run manifest is not accepted and sealed", call. = FALSE)
  }
  if (!identical(as.integer(run$selected_g), 40L)) stop("Phase 9 score support is not the accepted G=40", call. = FALSE)
  list(
    bundle_sha256 = bundle_sha256,
    checksum_self_sha256 = self_hash,
    parent_graph_sha256 = parent_graph,
    manifest_path = manifest_path
  )
}

#' Capture official CRAN metadata, verify, and optionally install glmnet 5.0
#'
#' @param package Must be `glmnet`.
#' @param version Must be `5.0`.
#' @param install Install the verified local source archive when `TRUE`.
#' @param output_path Durable one-row provenance CSV.
#' @param repository Approved canonical CRAN repository.
#' @return A capture result with `valid = TRUE` after all checks pass.
#' @export
capture_cran_package_provenance <- function(
    package = "glmnet", version = "5.0", install = FALSE,
    output_path = "data/benchmark/phase10/glmnet_provenance.csv",
    repository = "https://cran.r-project.org"
) {
  if (!identical(package, "glmnet") || !identical(version, "5.0")) {
    stop("Phase 10 permits only the audited glmnet 5.0 package", call. = FALSE)
  }
  if (!identical(sub("/+$", "", repository), "https://cran.r-project.org")) {
    stop("Phase 10 permits only the canonical official CRAN repository", call. = FALSE)
  }
  root <- .challenger_project_root(".")
  cache_root <- file.path(root, "data", "cache", "phase10-cran")
  library_root <- file.path(root, "data", "cache", "phase10-library")
  dir.create(cache_root, recursive = TRUE, showWarnings = FALSE)
  dir.create(library_root, recursive = TRUE, showWarnings = FALSE)
  index_path <- file.path(cache_root, "PACKAGES.gz")
  index_url <- paste0(repository, "/src/contrib/PACKAGES.gz")
  utils::download.file(index_url, index_path, mode = "wb", quiet = TRUE)
  index_sha256 <- .challenger_sha256(index_path, file = TRUE)
  index <- .challenger_read_index(index_path)
  selected <- index[index$Package == package & index$Version == version, , drop = FALSE]
  if (nrow(selected) != 1L) stop("Official CRAN index does not contain exactly glmnet 5.0", call. = FALSE)
  metadata <- as.list(selected[1, , drop = TRUE])
  dependencies <- .challenger_dependency_inventory(metadata, index)
  if (length(dependencies$unexpected)) {
    stop("Unexpected glmnet dependency inventory: ", paste(dependencies$unexpected, collapse = ", "), call. = FALSE)
  }
  artifact_name <- paste0(package, "_", version, ".tar.gz")
  archive_path <- file.path(cache_root, artifact_name)
  artifact_url <- paste0(repository, "/src/contrib/", artifact_name)
  official_checksum <- tolower(as.character(metadata$MD5sum))
  if (!grepl("^[0-9a-f]{32}$", official_checksum)) {
    stop("Official CRAN metadata lacks a canonical glmnet MD5 checksum", call. = FALSE)
  }
  utils::download.file(artifact_url, archive_path, mode = "wb", quiet = TRUE)
  if (!identical(tolower(unname(tools::md5sum(archive_path))), official_checksum)) {
    stop("glmnet archive does not match the official CRAN checksum", call. = FALSE)
  }
  description <- .challenger_archive_description(archive_path, package)
  if (!identical(as.character(description$Package), package) ||
      !identical(as.character(description$Version), version) ||
      !identical(as.character(description$SystemRequirements), "C++17")) {
    stop("Unexpected glmnet package identity or system requirement in verified archive", call. = FALSE)
  }
  record <- data.frame(
    schema_version = "phase10-glmnet-provenance-v1",
    package = package,
    version = version,
    repository_url = repository,
    index_url = index_url,
    repository_index_identity = paste(index_url, index_sha256, sep = "#sha256="),
    index_cache_path = file.path("data", "cache", "phase10-cran", "PACKAGES.gz"),
    index_sha256 = index_sha256,
    index_bytes = as.numeric(file.info(index_path)$size),
    index_captured_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    package_metadata_sha256 = .challenger_metadata_sha256(metadata),
    published = as.character(metadata$Published),
    license = as.character(metadata$License),
    needs_compilation = as.character(metadata$NeedsCompilation),
    system_requirements = as.character(description$SystemRequirements),
    artifact_name = artifact_name,
    artifact_type = "source",
    artifact_url = artifact_url,
    official_checksum_algorithm = "md5",
    official_checksum = official_checksum,
    archive_path = file.path("data", "cache", "phase10-cran", artifact_name),
    archive_sha256 = .challenger_sha256(archive_path, file = TRUE),
    archive_bytes = as.numeric(file.info(archive_path)$size),
    dependency_inventory = dependencies$serialized,
    dependency_inventory_sha256 = dependencies$sha256,
    glmnet_library_path = file.path("data", "cache", "phase10-library"),
    installed_version = "",
    installed_content_sha256 = "",
    matrix_version = as.character(utils::packageVersion("Matrix")),
    matrix_library_path = find.package("Matrix"),
    matrix_installed_content_sha256 = hash_installed_package_contents("Matrix"),
    phase09_bundle_path = "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen",
    phase09_bundle_sha256 = "977e119dd17e1212d2bfc57da2e676b6ee9d16bfba8b6c9bdbf1a97d302db069",
    phase09_checksum_self_sha256 = "4fe638ab49014c9dbac98fe389709d7668715a9ac99840f52847d0297998c309",
    phase09_parent_graph_sha256 = "19263239c52ceab8b9c2a345646a6475d103f38137ec5deebbc0993525701584",
    offline_after_install = TRUE,
    valid = FALSE,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  verify_cran_package_archive(record)
  if (isTRUE(install)) {
    before <- list.files(library_root, all.files = FALSE, no.. = TRUE)
    utils::install.packages(
      archive_path, repos = NULL, type = "source", lib = library_root,
      dependencies = FALSE, INSTALL_opts = "--no-multiarch"
    )
    after <- list.files(library_root, all.files = FALSE, no.. = TRUE)
    added <- setdiff(after, before)
    if (length(setdiff(added, package))) {
      stop("Local installation changed packages other than glmnet", call. = FALSE)
    }
  }
  .libPaths(unique(c(library_root, .libPaths())))
  installed <- find.package(package, lib.loc = library_root, quiet = TRUE)
  if (!nzchar(installed) || !identical(as.character(utils::packageVersion(package, lib.loc = library_root)), version)) {
    stop("Exact glmnet 5.0 is not installed in the constrained Phase 10 library", call. = FALSE)
  }
  record$installed_version <- as.character(utils::packageVersion(package, lib.loc = library_root))
  record$installed_content_sha256 <- hash_installed_package_contents(package, lib.loc = library_root)
  record$valid <- TRUE
  output <- .challenger_resolve(output_path, root, file.path(root, "data", "benchmark", "phase10"), must_work = FALSE)
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
  temporary <- tempfile("glmnet-provenance-", tmpdir = dirname(output), fileext = ".csv")
  utils::write.csv(record, temporary, row.names = FALSE, na = "", quote = TRUE)
  if (!file.rename(temporary, output)) stop("Could not atomically publish glmnet provenance", call. = FALSE)
  validation <- require_challenger_environment(output)
  list(valid = isTRUE(validation$valid), record = record, dependencies = dependencies, environment = validation)
}

#' Require the exact offline Phase 10 optimizer and immutable Phase 9 parent
#'
#' @param provenance_path Durable provenance CSV created by the capture function.
#' @return Validated environment facts and immutable hashes.
#' @export
require_challenger_environment <- function(
    provenance_path = "data/benchmark/phase10/glmnet_provenance.csv"
) {
  root <- .challenger_project_root(".")
  provenance_path <- .challenger_resolve(
    provenance_path, root, file.path(root, "data", "benchmark", "phase10"), must_work = TRUE
  )
  record <- .challenger_record(provenance_path)
  required <- c(
    "package", "version", "repository_url", "index_sha256", "package_metadata_sha256",
    "official_checksum", "archive_sha256", "dependency_inventory_sha256",
    "installed_version", "installed_content_sha256", "matrix_version",
    "matrix_installed_content_sha256", "phase09_bundle_path", "phase09_bundle_sha256",
    "phase09_checksum_self_sha256", "phase09_parent_graph_sha256", "offline_after_install", "valid"
  )
  missing <- setdiff(required, names(record))
  if (length(missing)) stop("glmnet provenance is missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (!identical(as.character(record$package), "glmnet") ||
      !identical(as.character(record$version), "5.0") ||
      !identical(as.character(record$repository_url), "https://cran.r-project.org") ||
      !isTRUE(as.logical(record$offline_after_install)) || !isTRUE(as.logical(record$valid))) {
    stop("glmnet provenance is not the approved offline Phase 10 environment", call. = FALSE)
  }
  verify_cran_package_archive(record)
  inventory <- inventory_cran_dependencies(record)
  if (length(inventory$unexpected)) stop("glmnet dependency inventory is no longer valid", call. = FALSE)
  library_root <- .challenger_resolve(
    as.character(record$glmnet_library_path), root, file.path(root, "data", "cache", "phase10-library"), must_work = TRUE
  )
  .libPaths(unique(c(library_root, .libPaths())))
  if (!identical(as.character(utils::packageVersion("glmnet", lib.loc = library_root)), "5.0") ||
      !identical(as.character(utils::packageVersion("glmnet", lib.loc = library_root)), as.character(record$installed_version))) {
    stop("Installed glmnet version drift", call. = FALSE)
  }
  if (!identical(hash_installed_package_contents("glmnet", lib.loc = library_root), tolower(as.character(record$installed_content_sha256)))) {
    stop("Installed glmnet content drift", call. = FALSE)
  }
  if (!identical(as.character(utils::packageVersion("Matrix")), as.character(record$matrix_version)) ||
      !identical(hash_installed_package_contents("Matrix"), tolower(as.character(record$matrix_installed_content_sha256)))) {
    stop("Installed Matrix environment drift", call. = FALSE)
  }
  phase09 <- .challenger_phase09_identity(
    as.character(record$phase09_bundle_path), as.character(record$phase09_bundle_sha256)
  )
  if (!identical(phase09$checksum_self_sha256, tolower(as.character(record$phase09_checksum_self_sha256))) ||
      !identical(phase09$parent_graph_sha256, tolower(as.character(record$phase09_parent_graph_sha256)))) {
    stop("Phase 9 immutable parent provenance drift", call. = FALSE)
  }
  list(
    valid = TRUE,
    package = "glmnet",
    package_version = "5.0",
    matrix_version = as.character(record$matrix_version),
    index_sha256 = as.character(record$index_sha256),
    metadata_sha256 = as.character(record$package_metadata_sha256),
    dependency_inventory_sha256 = as.character(record$dependency_inventory_sha256),
    archive_sha256 = as.character(record$archive_sha256),
    installed_content_sha256 = as.character(record$installed_content_sha256),
    matrix_installed_content_sha256 = as.character(record$matrix_installed_content_sha256),
    phase09_bundle_sha256 = phase09$bundle_sha256,
    phase09_checksum_self_sha256 = phase09$checksum_self_sha256,
    phase09_parent_graph_sha256 = phase09$parent_graph_sha256,
    offline_after_install = TRUE
  )
}
