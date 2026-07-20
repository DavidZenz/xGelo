#' Frozen benchmark registry loading and validation
#'
#' The Phase 09 benchmark starts from checked, project-local registries. This
#' module treats every CSV as untrusted until its schema, foreign keys,
#' provenance, and canonical hashes have been validated.

benchmark_required_registry_files <- function() {
  c(
    tournaments = "tournaments.csv",
    fixtures = "fixtures.csv",
    teams = "teams.csv",
    formats = "formats.csv",
    route_rules = "route_rules.csv",
    corrections = "corrections.csv",
    boundaries = "boundaries.csv"
  )
}

benchmark_find_project_root <- function(path = ".") {
  candidate <- normalizePath(path, mustWork = FALSE)
  if (file.exists(candidate) && !dir.exists(candidate)) candidate <- dirname(candidate)
  repeat {
    if (dir.exists(file.path(candidate, ".git")) || file.exists(file.path(candidate, ".git"))) return(candidate)
    parent <- dirname(candidate)
    if (identical(parent, candidate)) break
    candidate <- parent
  }
  normalizePath(".", mustWork = TRUE)
}

benchmark_path_within <- function(path, root) {
  path <- normalizePath(path, mustWork = FALSE)
  root <- normalizePath(root, mustWork = FALSE)
  identical(path, root) || startsWith(path, paste0(root, .Platform$file.sep))
}

#' Validate a benchmark registry root or named registry paths
#'
#' @param paths Registry directory or named paths.
#' @param project_root Project root used to resolve relative paths.
#' @return Normalized paths, invisibly.
#' @export
validate_benchmark_registry_paths <- function(paths, project_root = ".") {
  project_root <- benchmark_find_project_root(project_root)
  approved_root <- normalizePath(file.path(project_root, "data/benchmark/phase09"), mustWork = FALSE)
  raw_paths <- as.character(paths)
  if (!length(raw_paths) || any(is.na(raw_paths) | !nzchar(raw_paths))) {
    stop("Benchmark registry path must not be empty", call. = FALSE)
  }
  resolved <- vapply(raw_paths, function(path) {
    candidate <- if (grepl("^(/|[A-Za-z]:[/\\\\])", path)) path else file.path(project_root, path)
    normalizePath(candidate, mustWork = FALSE)
  }, character(1))
  if (any(!vapply(resolved, benchmark_path_within, logical(1), root = approved_root))) {
    stop("Benchmark registry path must stay inside the registered project-relative root data/benchmark/phase09", call. = FALSE)
  }
  invisible(resolved)
}

#' Return the registered Phase 09 registry paths
#'
#' @param registry_dir Project-relative or approved absolute registry directory.
#' @param project_root Project root.
#' @return Named character vector of registry paths.
#' @export
benchmark_registry_paths <- function(registry_dir = "data/benchmark/phase09", project_root = ".") {
  project_root <- benchmark_find_project_root(project_root)
  resolved_dir <- validate_benchmark_registry_paths(registry_dir, project_root)
  paths <- file.path(resolved_dir, benchmark_required_registry_files())
  names(paths) <- names(benchmark_required_registry_files())
  validate_benchmark_registry_paths(paths, project_root)
  paths
}

benchmark_canonical_scalar <- function(x) {
  if (inherits(x, "Date")) x <- format(x, "%Y-%m-%d")
  if (is.logical(x)) x <- ifelse(is.na(x), "", ifelse(x, "true", "false"))
  x <- as.character(x)
  x[is.na(x)] <- ""
  x
}

benchmark_row_sha256 <- function(data, hash_col = "row_sha256") {
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for benchmark SHA-256", call. = FALSE)
  fields <- setdiff(names(data), hash_col)
  vapply(seq_len(nrow(data)), function(i) {
    values <- vapply(data[i, fields, drop = FALSE], benchmark_canonical_scalar, character(1))
    digest::digest(paste(values, collapse = "|"), algo = "sha256", serialize = FALSE)
  }, character(1))
}

#' Compute an order-stable canonical SHA-256 for a registry table
#'
#' @param data Data frame to serialize.
#' @param key Column or columns defining canonical row order.
#' @return Lowercase SHA-256 string.
#' @export
canonical_benchmark_sha256 <- function(data, key = NULL) {
  if (!is.data.frame(data)) stop("Canonical benchmark hashing requires a data frame", call. = FALSE)
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for benchmark SHA-256", call. = FALSE)
  if (is.null(key)) key <- names(data)[1]
  missing <- setdiff(key, names(data))
  if (length(missing)) stop("Canonical hash key missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (nrow(data)) {
    order_args <- lapply(data[key], benchmark_canonical_scalar)
    data <- data[do.call(order, c(order_args, list(na.last = TRUE, method = "radix"))), , drop = FALSE]
  }
  rows <- vapply(seq_len(nrow(data)), function(i) {
    paste(vapply(data[i, , drop = FALSE], benchmark_canonical_scalar, character(1)), collapse = "\x1f")
  }, character(1))
  payload <- paste(c(paste(names(data), collapse = "\x1f"), rows), collapse = "\x1e")
  digest::digest(payload, algo = "sha256", serialize = FALSE)
}

benchmark_require_columns <- function(data, required, name) {
  missing <- setdiff(required, names(data))
  if (length(missing)) stop(name, " registry missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
}

benchmark_require_unique <- function(data, key, name) {
  if (anyDuplicated(data[key])) stop(name, " registry has duplicate key values: ", paste(key, collapse = ", "), call. = FALSE)
}

benchmark_validate_hash_column <- function(data, hash_col, name) {
  if (!hash_col %in% names(data)) stop(name, " registry missing hash column ", hash_col, call. = FALSE)
  expected <- benchmark_row_sha256(data, hash_col)
  actual <- tolower(as.character(data[[hash_col]]))
  if (any(!grepl("^[0-9a-f]{64}$", actual))) stop(name, " registry contains noncanonical SHA-256 values", call. = FALSE)
  bad <- which(actual != expected)
  if (length(bad)) stop(name, " registry row SHA-256 mismatch at rows: ", paste(head(bad, 10), collapse = ", "), call. = FALSE)
  invisible(TRUE)
}

benchmark_parse_dates <- function(registries) {
  date_columns <- list(
    tournaments = c("opener_date", "final_date"),
    fixtures = c("scheduled_date", "actual_completion_date", "result_source_date"),
    corrections = "access_date",
    boundaries = c("assessment_date", "evidence_cutoff_exclusive")
  )
  for (name in names(date_columns)) {
    for (column in date_columns[[name]]) registries[[name]][[column]] <- as.Date(registries[[name]][[column]])
  }
  for (name in names(registries)) {
    version <- as.character(registries[[name]]$schema_version)
    version[version == "1"] <- "1.0"
    registries[[name]]$schema_version <- version
  }
  registries
}

#' Load all checked Phase 09 benchmark registries
#'
#' @param registry_dir Registry directory.
#' @param project_root Project root.
#' @param validate Whether to validate before returning.
#' @return Named list of data frames.
#' @export
load_benchmark_registries <- function(registry_dir = "data/benchmark/phase09", project_root = ".", validate = TRUE) {
  project_root <- benchmark_find_project_root(project_root)
  paths <- benchmark_registry_paths(registry_dir, project_root)
  missing <- paths[!file.exists(paths)]
  if (length(missing)) stop("Benchmark registry files not found: ", paste(basename(missing), collapse = ", "), call. = FALSE)
  registries <- lapply(paths, utils::read.csv, stringsAsFactors = FALSE, check.names = FALSE)
  registries <- benchmark_parse_dates(registries)
  attr(registries, "project_root") <- project_root
  attr(registries, "paths") <- paths
  if (isTRUE(validate)) validate_benchmark_registries(registries, project_root)
  registries
}

#' Validate the complete benchmark registry graph
#'
#' @param registries Named registry list.
#' @param project_root Project root for local provenance checks.
#' @return Registries, invisibly.
#' @export
validate_benchmark_registries <- function(registries, project_root = attr(registries, "project_root")) {
  required_names <- names(benchmark_required_registry_files())
  missing_registries <- setdiff(required_names, names(registries))
  if (length(missing_registries)) stop("Missing benchmark registries: ", paste(missing_registries, collapse = ", "), call. = FALSE)
  if (is.null(project_root)) project_root <- benchmark_find_project_root(".")
  project_root <- benchmark_find_project_root(project_root)

  t <- registries$tournaments
  f <- registries$fixtures
  tm <- registries$teams
  fmt <- registries$formats
  routes <- registries$route_rules
  corrections <- registries$corrections
  boundaries <- registries$boundaries

  benchmark_require_columns(t, c("schema_version", "edition_id", "competition_id", "edition_year", "played_year", "opener_date", "final_date", "format_id", "headline_weight", "expected_fixture_count", "source_url", "source_license", "source_sha256", "row_sha256"), "Tournament")
  benchmark_require_columns(f, c("schema_version", "edition_id", "fixture_id", "source_match_id", "stage_id", "group_id", "round_id", "home_team_id", "away_team_id", "scheduled_date", "actual_completion_date", "time_precision", "boundary_id", "neutral", "venue_role", "regulation_home_goals", "regulation_away_goals", "final_home_goals", "final_away_goals", "went_extra_time", "went_penalties", "winner_team_id", "status", "fit_eligible", "score_eligible", "exclusion_reason", "result_source", "result_source_date", "source_license", "row_sha256"), "Fixture")
  benchmark_require_columns(tm, c("schema_version", "team_id", "fifa_code", "canonical_name", "aliases", "source_url", "source_license", "source_artifact_sha256", "row_sha256"), "Team")
  benchmark_require_columns(fmt, c("schema_version", "format_id", "team_count", "group_count", "group_stage_fixture_count", "first_knockout_stage", "source_url", "source_license", "source_artifact_sha256", "row_sha256"), "Format")
  benchmark_require_columns(routes, c("schema_version", "format_id", "rule_id", "source_slot", "opponent_slot", "destination_stage", "destination_slot", "source_url", "source_license", "source_artifact_sha256", "row_sha256"), "Route")
  benchmark_require_columns(corrections, c("schema_version", "correction_id", "fixture_id", "field", "original_value", "corrected_value", "source_title", "source_url", "access_date", "license", "rationale", "reviewer", "verification_status", "source_local_path", "source_artifact_sha256", "row_sha256"), "Correction")
  benchmark_require_columns(boundaries, c("schema_version", "boundary_id", "edition_id", "sequence", "track", "assessment_date", "evidence_cutoff_exclusive", "prior_boundary_id", "fixture_count", "completed_input_count", "status", "boundary_sha256"), "Boundary")

  expected_editions <- c(paste0("wc", c(2002, 2006, 2010, 2014, 2018, 2022)), paste0("euro", c(2004, 2008, 2012, 2016, 2020, 2024)))
  if (nrow(t) != 12L || !setequal(t$edition_id, expected_editions)) stop("Tournament registry must contain exactly the fixed 12 editions", call. = FALSE)
  if (nrow(f) != 630L) stop("Fixture registry must contain exactly 630 assessment fixtures", call. = FALSE)
  benchmark_require_unique(t, "edition_id", "Tournament")
  benchmark_require_unique(f, "fixture_id", "Fixture")
  benchmark_require_unique(tm, "team_id", "Team")
  benchmark_require_unique(tm, "fifa_code", "Team FIFA")
  benchmark_require_unique(fmt, "format_id", "Format")
  benchmark_require_unique(routes, "rule_id", "Route")
  benchmark_require_unique(corrections, "correction_id", "Correction")
  benchmark_require_unique(boundaries, "boundary_id", "Boundary")

  if (any(is.na(tm$fifa_code) | !nzchar(tm$fifa_code))) stop("Team registry contains missing FIFA codes", call. = FALSE)
  if (any(!f$edition_id %in% t$edition_id)) stop("Fixture registry contains unknown edition keys", call. = FALSE)
  if (any(!f$home_team_id %in% tm$team_id) || any(!f$away_team_id %in% tm$team_id)) stop("Fixture registry contains unknown team identities", call. = FALSE)
  if (any(f$home_team_id == f$away_team_id)) stop("Fixture registry contains self fixtures", call. = FALSE)
  if (any(!t$format_id %in% fmt$format_id) || any(!routes$format_id %in% fmt$format_id)) stop("Format route foreign key is invalid", call. = FALSE)
  counts <- table(factor(f$edition_id, levels = t$edition_id))
  if (any(as.integer(counts) != as.integer(t$expected_fixture_count))) stop("Fixture edition counts do not match the frozen denominator", call. = FALSE)
  if (any(abs(t$headline_weight - 1 / 12) > 1e-12)) stop("Tournament headline weights must equal 1/12", call. = FALSE)
  euro2020 <- t[t$edition_id == "euro2020", , drop = FALSE]
  if (euro2020$edition_year != 2020L || euro2020$played_year != 2021L) stop("Euro 2020 edition and played years must remain distinct", call. = FALSE)

  allowed_status <- c("completed", "resumed", "replayed", "awarded", "abandoned")
  if (any(!f$status %in% allowed_status)) stop("Fixture registry contains invalid status values", call. = FALSE)
  allowed_venue <- c("home", "away", "neutral")
  if (any(!f$venue_role %in% allowed_venue)) stop("Fixture registry contains invalid venue roles", call. = FALSE)
  if (any(f$score_eligible & (is.na(f$regulation_home_goals) | is.na(f$regulation_away_goals)))) stop("Score-eligible fixtures require verified regulation outcomes", call. = FALSE)
  if (any(f$fit_eligible & f$status %in% c("awarded", "abandoned"))) stop("Non-generative fixture statuses cannot be fit eligible", call. = FALSE)
  if (any(f$went_penalties & (!f$went_extra_time | f$regulation_home_goals != f$regulation_away_goals | is.na(f$winner_team_id) | !nzchar(f$winner_team_id)))) stop("Penalty fixtures must retain a tied regulation score and separate winner", call. = FALSE)
  if (any(f$went_extra_time & f$regulation_home_goals != f$regulation_away_goals)) stop("Extra-time fixtures must be tied after regulation", call. = FALSE)
  if (any(f$score_eligible & (!nzchar(f$result_source) | !nzchar(f$source_license)))) stop("Score-eligible fixtures require result source and license provenance", call. = FALSE)

  if (any(!corrections$fixture_id %in% f$fixture_id)) stop("Correction registry contains unknown fixture keys", call. = FALSE)
  if (any(is.na(corrections$verification_status) | corrections$verification_status != "verified")) stop("All corrections must be verified; unresolved human approval blocks sealing", call. = FALSE)
  if (any(!nzchar(corrections$source_title) | !nzchar(corrections$source_url) | !nzchar(corrections$license) | !nzchar(corrections$reviewer))) stop("Correction registry contains incomplete authoritative provenance", call. = FALSE)
  correction_paths <- file.path(project_root, corrections$source_local_path)
  if (any(!vapply(correction_paths, benchmark_path_within, logical(1), root = project_root)) || any(!file.exists(correction_paths))) stop("Correction source artifact must be a checked project-local file", call. = FALSE)
  source_hashes <- vapply(correction_paths, digest::digest, character(1), algo = "sha256", file = TRUE)
  if (any(source_hashes != corrections$source_artifact_sha256)) stop("Correction source artifact SHA-256 mismatch", call. = FALSE)

  if (sum(boundaries$track == "frozen") != 12L || sum(boundaries$track == "updating") != 272L) stop("Boundary registry must contain 12 frozen and 272 updating boundaries", call. = FALSE)
  if (any(!boundaries$track %in% c("frozen", "updating"))) stop("Boundary registry contains invalid track values", call. = FALSE)
  if (any(!boundaries$edition_id %in% t$edition_id)) stop("Boundary registry contains unknown edition keys", call. = FALSE)
  updating_ids <- boundaries$boundary_id[boundaries$track == "updating"]
  if (any(!f$boundary_id %in% updating_ids)) stop("Fixture registry contains unknown updating boundary keys", call. = FALSE)
  fixture_dates <- setNames(as.Date(f$actual_completion_date), f$fixture_id)
  if (any(is.na(fixture_dates))) stop("Fixture registry contains invalid completion dates", call. = FALSE)

  benchmark_validate_hash_column(t, "row_sha256", "Tournament")
  benchmark_validate_hash_column(f, "row_sha256", "Fixture")
  benchmark_validate_hash_column(tm, "row_sha256", "Team")
  benchmark_validate_hash_column(fmt, "row_sha256", "Format")
  benchmark_validate_hash_column(routes, "row_sha256", "Route")
  benchmark_validate_hash_column(corrections, "row_sha256", "Correction")
  benchmark_validate_hash_column(boundaries, "boundary_sha256", "Boundary")
  invisible(registries)
}

#' Build a canonical manifest for the validated registry graph
#'
#' @param registries Loaded registry list.
#' @return One manifest row per registry.
#' @export
benchmark_registry_manifest <- function(registries) {
  validate_benchmark_registries(registries)
  keys <- list(
    tournaments = "edition_id", fixtures = "fixture_id", teams = "team_id",
    formats = "format_id", route_rules = "rule_id", corrections = "correction_id",
    boundaries = "boundary_id"
  )
  manifest <- do.call(rbind, lapply(names(keys), function(name) data.frame(
    artifact = paste0(name, ".csv"),
    rows = nrow(registries[[name]]),
    canonical_sha256 = canonical_benchmark_sha256(registries[[name]], keys[[name]]),
    schema_version = paste(sort(unique(registries[[name]]$schema_version)), collapse = "|"),
    sealed = TRUE,
    stringsAsFactors = FALSE
  )))
  rownames(manifest) <- NULL
  manifest
}
