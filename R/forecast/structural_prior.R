#' Phase 11 vintage-safe structural sparse-team prior

.structural_prior_required_snapshot_columns <- function() {
  c(
    "country_iso3", "country_name", "indicator_id", "indicator_name",
    "indicator_definition", "source_year", "source_date", "vintage_id",
    "value", "transformation", "source_name", "source_url_or_label",
    "license_class", "retrieved_at_utc", "parent_source_sha256", "row_sha256"
  )
}

.structural_prior_required_metadata_columns <- function() {
  c(
    "vintage_id", "snapshot_year", "source_date", "source_name",
    "source_url_or_label", "license_class", "indicator_definition",
    "transformation_policy", "acquisition_note"
  )
}

.structural_prior_required_checksum_columns <- function() {
  c("artifact_path", "artifact_kind", "sha256", "vintage_id")
}

.structural_prior_path <- function(path) {
  path <- as.character(path)
  if (length(path) != 1L || is.na(path) || !nzchar(path)) {
    stop("Structural prior paths must be one non-empty path", call. = FALSE)
  }
  if (grepl("^(/|[A-Za-z]:[/\\\\])", path)) {
    normalizePath(path, mustWork = FALSE)
  } else {
    root <- if (exists(".phase11_protocol_root", mode = "function")) {
      .phase11_protocol_root(".")
    } else {
      normalizePath(".", mustWork = TRUE)
    }
    file.path(root, path)
  }
}

.structural_prior_sha256_file <- function(path) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for structural source provenance", call. = FALSE)
  }
  digest::digest(path, algo = "sha256", file = TRUE)
}

.structural_prior_sha256_text <- function(value) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for structural prior identities", call. = FALSE)
  }
  digest::digest(value, algo = "sha256", serialize = FALSE)
}

.structural_prior_scalar <- function(value) {
  if (inherits(value, "Date")) value <- format(value, "%Y-%m-%d")
  if (is.logical(value)) value <- ifelse(is.na(value), "", ifelse(value, "true", "false"))
  value <- as.character(value)
  value[is.na(value)] <- ""
  value
}

.structural_prior_row_hash <- function(data, hash_col = "row_sha256") {
  fields <- setdiff(names(data), hash_col)
  vapply(seq_len(nrow(data)), function(index) {
    .structural_prior_sha256_text(paste(
      vapply(data[index, fields, drop = FALSE], .structural_prior_scalar, character(1)),
      collapse = "|"
    ))
  }, character(1))
}

.structural_prior_canonical_snapshot <- function(data) {
  required <- .structural_prior_required_snapshot_columns()
  missing <- setdiff(required, names(data))
  if (length(missing)) stop("Structural snapshot row-set is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  data <- data[, names(data), drop = FALSE]
  data$source_year <- as.integer(data$source_year)
  data$snapshot_year <- if ("snapshot_year" %in% names(data)) as.integer(data$snapshot_year) else data$source_year
  data$source_date <- as.Date(data$source_date)
  data$value <- suppressWarnings(as.numeric(data$value))
  data
}

.structural_prior_checksum_row_set <- function(data) {
  canonical <- .structural_prior_canonical_snapshot(data)
  digest::digest(canonical, algo = "sha256", serialize = TRUE)
}

.structural_prior_read_csv <- function(path, label) {
  if (!file.exists(path)) stop(label, " is missing: ", path, call. = FALSE)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

.structural_prior_validate_checksum_table <- function(checksums, snapshot_path, metadata_path, checksums_path, vintage_ids) {
  required <- .structural_prior_required_checksum_columns()
  missing <- setdiff(required, names(checksums))
  if (length(missing)) {
    stop("Structural source checksum registry is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  checksums$artifact_path <- as.character(checksums$artifact_path)
  checksums$artifact_kind <- as.character(checksums$artifact_kind)
  checksums$sha256 <- tolower(as.character(checksums$sha256))
  checksums$vintage_id <- as.character(checksums$vintage_id)
  if (any(!grepl("^[0-9a-f]{64}$", checksums$sha256))) {
    stop("Structural source checksum registry contains noncanonical SHA-256 values", call. = FALSE)
  }
  if (anyDuplicated(checksums$artifact_path)) {
    stop("Structural source checksum registry contains duplicate artifact paths", call. = FALSE)
  }
  expected_artifacts <- c(
    "structural_sources.csv", "structural_sources_metadata.csv", "structural_sources_rows"
  )
  if (!all(expected_artifacts %in% checksums$artifact_path)) {
    stop("Structural source checksum registry is missing registered checksum parents", call. = FALSE)
  }
  if (any(!checksums$vintage_id %in% c(vintage_ids, "all"))) {
    stop("Structural source checksum registry references an unregistered vintage", call. = FALSE)
  }
  file_rows <- checksums[checksums$artifact_path %in% expected_artifacts[1:2], , drop = FALSE]
  actual_files <- c(
    structural_sources.csv = .structural_prior_sha256_file(snapshot_path),
    structural_sources_metadata.csv = .structural_prior_sha256_file(metadata_path)
  )
  expected_files <- stats::setNames(as.character(file_rows$sha256), file_rows$artifact_path)
  if (any(actual_files[names(expected_files)] != expected_files)) {
    stop("Structural source snapshot or metadata checksum mismatch", call. = FALSE)
  }
  invisible(checksums)
}

.structural_prior_validate_metadata <- function(snapshot, metadata) {
  required <- .structural_prior_required_metadata_columns()
  missing <- setdiff(required, names(metadata))
  if (length(missing)) {
    stop("Structural source metadata is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  metadata$vintage_id <- as.character(metadata$vintage_id)
  metadata$snapshot_year <- as.integer(metadata$snapshot_year)
  metadata$source_date <- as.Date(metadata$source_date)
  metadata$source_name <- as.character(metadata$source_name)
  metadata$source_url_or_label <- as.character(metadata$source_url_or_label)
  metadata$license_class <- as.character(metadata$license_class)
  if (anyDuplicated(metadata$vintage_id)) {
    stop("Structural source metadata must contain one row per vintage_id", call. = FALSE)
  }
  if (any(!metadata$vintage_id %in% unique(snapshot$vintage_id))) {
    stop("Structural source metadata contains an unregistered vintage", call. = FALSE)
  }
  for (vintage in unique(snapshot$vintage_id)) {
    rows <- snapshot[snapshot$vintage_id == vintage, , drop = FALSE]
    meta <- metadata[metadata$vintage_id == vintage, , drop = FALSE]
    if (nrow(meta) != 1L) stop("Structural source vintage is missing one metadata parent: ", vintage, call. = FALSE)
    metadata_source_label <- as.character(meta$source_url_or_label[[1L]])
    row_source_labels <- as.character(rows$source_url_or_label)
    source_label_matches <- all(row_source_labels == metadata_source_label) ||
      all(nzchar(metadata_source_label) & grepl(metadata_source_label, row_source_labels, fixed = TRUE))
    if (any(as.integer(rows$source_year) != meta$snapshot_year[[1L]]) ||
        any(as.Date(rows$source_date) != meta$source_date[[1L]]) ||
        any(as.character(rows$source_name) != meta$source_name[[1L]]) ||
        !source_label_matches ||
        any(as.character(rows$license_class) != meta$license_class[[1L]])) {
      stop("Structural source rows do not match metadata parent for vintage: ", vintage, call. = FALSE)
    }
  }
  metadata
}

#' Load and validate the committed Phase 11 structural source snapshot.
#'
#' The loader is deliberately checksum-first and point-in-time strict.  It
#' accepts test fixtures only when they carry the same registered artifact
#' names and checksum parents as the production snapshot.
#' @export
load_structural_prior_snapshots <- function(
    snapshot_path = "data/benchmark/phase11/structural_sources.csv",
    metadata_path = "data/benchmark/phase11/structural_sources_metadata.csv",
    checksums_path = "data/benchmark/phase11/structural_sources_checksums.csv",
    evidence_cutoff_exclusive = as.Date("2026-06-05"),
    registered_vintage_id = NULL
) {
  snapshot_path <- .structural_prior_path(snapshot_path)
  metadata_path <- .structural_prior_path(metadata_path)
  checksums_path <- .structural_prior_path(checksums_path)
  registered_paths <- c(
    snapshot = "structural_sources.csv",
    metadata = "structural_sources_metadata.csv",
    checksums = "structural_sources_checksums.csv"
  )
  supplied_paths <- c(
    snapshot = basename(snapshot_path), metadata = basename(metadata_path), checksums = basename(checksums_path)
  )
  if (any(supplied_paths != registered_paths)) {
    stop("Structural prior refuses unregistered/ad hoc snapshot, metadata, or checksum files", call. = FALSE)
  }
  cutoff <- as.Date(evidence_cutoff_exclusive)
  if (length(cutoff) != 1L || is.na(cutoff)) {
    stop("Structural source evidence cutoff must be one valid date", call. = FALSE)
  }
  snapshot <- .structural_prior_read_csv(snapshot_path, "Structural source snapshot")
  metadata <- .structural_prior_read_csv(metadata_path, "Structural source metadata")
  checksums <- .structural_prior_read_csv(checksums_path, "Structural source checksum registry")
  required <- .structural_prior_required_snapshot_columns()
  missing <- setdiff(required, names(snapshot))
  if (length(missing)) stop("Structural source snapshot is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  snapshot <- snapshot[, unique(c(names(snapshot), required)), drop = FALSE]
  snapshot$country_iso3 <- toupper(trimws(as.character(snapshot$country_iso3)))
  snapshot$country_name <- as.character(snapshot$country_name)
  snapshot$indicator_id <- as.character(snapshot$indicator_id)
  snapshot$indicator_name <- as.character(snapshot$indicator_name)
  snapshot$indicator_definition <- as.character(snapshot$indicator_definition)
  snapshot$source_year <- as.integer(snapshot$source_year)
  snapshot$snapshot_year <- if ("snapshot_year" %in% names(snapshot)) as.integer(snapshot$snapshot_year) else snapshot$source_year
  snapshot$source_date <- as.Date(snapshot$source_date)
  snapshot$vintage_id <- as.character(snapshot$vintage_id)
  snapshot$value <- suppressWarnings(as.numeric(snapshot$value))
  snapshot$transformation <- as.character(snapshot$transformation)
  snapshot$source_name <- as.character(snapshot$source_name)
  snapshot$source_url_or_label <- as.character(snapshot$source_url_or_label)
  snapshot$license_class <- as.character(snapshot$license_class)
  snapshot$retrieved_at_utc <- as.character(snapshot$retrieved_at_utc)
  snapshot$parent_source_sha256 <- tolower(as.character(snapshot$parent_source_sha256))
  snapshot$row_sha256 <- tolower(as.character(snapshot$row_sha256))
  if (any(!grepl("^[A-Z]{3}$", snapshot$country_iso3))) stop("Structural source snapshot has malformed ISO3 keys", call. = FALSE)
  if (any(!nzchar(snapshot$country_name) | !nzchar(snapshot$indicator_id) | !nzchar(snapshot$vintage_id))) {
    stop("Structural source snapshot has incomplete identity fields", call. = FALSE)
  }
  if (any(!is.finite(snapshot$value) | snapshot$value <= 0)) stop("Structural source values must be finite and positive", call. = FALSE)
  if (anyNA(snapshot$source_year) || anyNA(snapshot$snapshot_year) || anyNA(snapshot$source_date)) {
    stop("Structural source snapshot has missing source year/date", call. = FALSE)
  }
  if (any(snapshot$source_year != snapshot$snapshot_year)) stop("Structural source source_year and snapshot_year must agree", call. = FALSE)
  if (any(!grepl("^[0-9a-f]{64}$", snapshot$parent_source_sha256)) ||
      any(!grepl("^[0-9a-f]{64}$", snapshot$row_sha256))) {
    stop("Structural source snapshot contains noncanonical provenance hashes", call. = FALSE)
  }
  if (any(snapshot$license_class != "open-or-derived-open")) {
    stop("Structural source snapshot contains an unlicensed or restricted row", call. = FALSE)
  }
  if (any(grepl("current|latest", tolower(paste(snapshot$vintage_id, snapshot$source_url_or_label))))) {
    stop("Structural source snapshot cannot use current/latest values without a frozen vintage", call. = FALSE)
  }
  keys <- snapshot[c("country_iso3", "indicator_id", "source_year", "vintage_id")]
  if (anyDuplicated(keys)) stop("Structural source snapshot contains duplicate country-year-indicator rows", call. = FALSE)
  expected_rows <- .structural_prior_row_hash(snapshot, "row_sha256")
  if (any(snapshot$row_sha256 != expected_rows)) stop("Structural source snapshot row checksum mismatch", call. = FALSE)
  if (any(snapshot$source_date >= cutoff) || any(snapshot$source_year >= as.integer(format(cutoff, "%Y")))) {
    stop("Structural source snapshot contains source information at or after the evidence cutoff", call. = FALSE)
  }
  if (!is.null(registered_vintage_id) && any(!snapshot$vintage_id %in% as.character(registered_vintage_id))) {
    stop("Structural source snapshot contains a vintage outside the registered prior manifest", call. = FALSE)
  }
  metadata <- .structural_prior_validate_metadata(snapshot, metadata)
  .structural_prior_validate_checksum_table(
    checksums, snapshot_path, metadata_path, checksums_path, unique(snapshot$vintage_id)
  )
  canonical_hash <- .structural_prior_checksum_row_set(snapshot)
  row_parent <- checksums[checksums$artifact_path == "structural_sources_rows", , drop = FALSE]
  if (nrow(row_parent) != 1L || tolower(as.character(row_parent$sha256[[1L]])) != canonical_hash) {
    stop("Structural source canonical row-set checksum mismatch", call. = FALSE)
  }
  attr(snapshot, "structural_snapshot_path") <- snapshot_path
  attr(snapshot, "structural_metadata_path") <- metadata_path
  attr(snapshot, "structural_checksums_path") <- checksums_path
  attr(snapshot, "structural_snapshot_sha256") <- .structural_prior_sha256_file(snapshot_path)
  attr(snapshot, "structural_metadata_sha256") <- .structural_prior_sha256_file(metadata_path)
  attr(snapshot, "structural_rows_sha256") <- canonical_hash
  attr(snapshot, "structural_metadata") <- metadata
  attr(snapshot, "structural_vintage_ids") <- unique(snapshot$vintage_id)
  class(snapshot) <- c("phase11_structural_snapshots", class(snapshot))
  snapshot
}

.structural_prior_team_iso3 <- function(team_ids) {
  ids <- as.character(team_ids)
  result <- toupper(ids)
  result[grepl("^TEAM_[A-Z]{3}$", result)] <- sub("^TEAM_", "", result[grepl("^TEAM_[A-Z]{3}$", result)])
  result
}

#' Compute a derived, registered structural prior for teams at a cutoff.
#' @export
compute_structural_prior_signal <- function(
    snapshots, team_ids, evidence_cutoff_exclusive,
    registered_vintage_id = NULL, prior_scale = 0.15,
    prior_bounds = c(0.65, 1.55)
) {
  if (!is.data.frame(snapshots) || !nrow(snapshots)) stop("Structural snapshots must contain rows", call. = FALSE)
  cutoff <- as.Date(evidence_cutoff_exclusive)
  if (length(cutoff) != 1L || is.na(cutoff)) stop("Structural prior cutoff must be one valid date", call. = FALSE)
  team_ids <- as.character(team_ids)
  if (!length(team_ids) || anyNA(team_ids) || any(!nzchar(team_ids))) stop("Structural prior team_ids must be non-empty", call. = FALSE)
  iso3 <- .structural_prior_team_iso3(team_ids)
  if (any(!grepl("^[A-Z]{3}$", iso3))) stop("Structural prior team IDs must contain ISO3 codes or team_ISO3 IDs", call. = FALSE)
  if (length(prior_scale) != 1L || !is.finite(prior_scale) || prior_scale <= 0) stop("Structural prior scale must be positive", call. = FALSE)
  if (length(prior_bounds) != 2L || any(!is.finite(prior_bounds)) || prior_bounds[[1L]] <= 0 || prior_bounds[[1L]] >= prior_bounds[[2L]]) {
    stop("Structural prior bounds must be two positive ordered values", call. = FALSE)
  }
  data <- snapshots
  data$country_iso3 <- toupper(as.character(data$country_iso3))
  data$source_date <- as.Date(data$source_date)
  data$source_year <- as.integer(data$source_year)
  data$value <- suppressWarnings(as.numeric(data$value))
  data <- data[!is.na(data$source_date) & data$source_date < cutoff & data$source_year < as.integer(format(cutoff, "%Y")), , drop = FALSE]
  if (!is.null(registered_vintage_id)) data <- data[data$vintage_id %in% as.character(registered_vintage_id), , drop = FALSE]
  selected <- lapply(iso3, function(code) {
    rows <- data[data$country_iso3 == code, , drop = FALSE]
    if (!nrow(rows)) stop("Structural prior snapshot is missing team ISO3: ", code, call. = FALSE)
    rows <- rows[order(as.Date(rows$source_date), as.character(rows$vintage_id), decreasing = TRUE), , drop = FALSE]
    rows[!duplicated(rows$indicator_id), , drop = FALSE]
  })
  selected <- do.call(rbind, selected)
  selected$log_value <- log(selected$value)
  indicators <- unique(as.character(selected$indicator_id))
  selected$indicator_z <- 0
  for (indicator in indicators) {
    index <- selected$indicator_id == indicator
    values <- selected$log_value[index]
    center <- mean(values)
    spread <- stats::sd(values)
    selected$indicator_z[index] <- if (!is.finite(spread) || spread <= 0) 0 else (values - center) / spread
  }
  aggregate_z <- stats::aggregate(indicator_z ~ country_iso3, selected, mean)
  aggregate_count <- stats::aggregate(indicator_z ~ country_iso3, selected, length)
  names(aggregate_z)[2L] <- "structural_signal"
  names(aggregate_count)[2L] <- "indicator_count"
  output <- data.frame(
    team_id = team_ids,
    country_iso3 = iso3,
    stringsAsFactors = FALSE
  )
  output <- merge(output, aggregate_z, by = "country_iso3", sort = FALSE)
  output <- merge(output, aggregate_count, by = "country_iso3", sort = FALSE)
  representative <- selected[!duplicated(selected$country_iso3), c(
    "country_iso3", "source_date", "source_year", "vintage_id", "parent_source_sha256", "row_sha256"
  ), drop = FALSE]
  output <- merge(output, representative, by = "country_iso3", sort = FALSE)
  output$structural_prior <- pmin(
    prior_bounds[[2L]],
    pmax(prior_bounds[[1L]], exp(prior_scale * as.numeric(output$structural_signal)))
  )
  output <- output[match(team_ids, output$team_id), , drop = FALSE]
  output$structural_snapshot_sha256 <- attr(snapshots, "structural_snapshot_sha256") %||% ""
  output$structural_rows_sha256 <- attr(snapshots, "structural_rows_sha256") %||% ""
  output$registered_vintage_id <- as.character(registered_vintage_id %||% unique(output$vintage_id)[[1L]])
  rownames(output) <- NULL
  output
}

`%||%` <- function(value, fallback) if (is.null(value) || length(value) == 0L || is.na(value[[1L]])) fallback else value

.structural_prior_history_columns <- function(history) {
  date_col <- intersect(c("actual_completion_date", "date", "match_date", "result_date"), names(history))
  home_col <- intersect(c("home_team_id", "home_team", "home"), names(history))
  away_col <- intersect(c("away_team_id", "away_team", "away"), names(history))
  if (!length(date_col) || !length(home_col) || !length(away_col)) {
    stop("Structural history requires date, home-team, and away-team columns", call. = FALSE)
  }
  list(date = date_col[[1L]], home = home_col[[1L]], away = away_col[[1L]])
}

#' Calculate continuous recency-weighted appearances before a cutoff.
#' @export
effective_recent_match_count <- function(
    history, team_ids = NULL, evidence_cutoff_exclusive = NULL,
    evidence_half_life_days = 730
) {
  if (!is.data.frame(history) || !nrow(history)) stop("Structural history must contain rows", call. = FALSE)
  if (length(evidence_half_life_days) != 1L || !is.finite(evidence_half_life_days) || evidence_half_life_days <= 0) {
    stop("Structural evidence half-life must be positive", call. = FALSE)
  }
  columns <- .structural_prior_history_columns(history)
  dates <- as.Date(history[[columns$date]])
  cutoff <- as.Date(evidence_cutoff_exclusive)
  if (length(cutoff) != 1L || is.na(cutoff)) stop("Structural history requires one exclusive cutoff", call. = FALSE)
  if (anyNA(dates)) stop("Structural history dates must be complete", call. = FALSE)
  eligible <- dates < cutoff
  home <- as.character(history[[columns$home]])
  away <- as.character(history[[columns$away]])
  observed <- unique(c(home[eligible], away[eligible]))
  observed <- observed[!is.na(observed) & nzchar(observed)]
  if (is.null(team_ids)) team_ids <- observed
  team_ids <- as.character(team_ids)
  decay <- exp(-log(2) * as.numeric(cutoff - dates) / evidence_half_life_days)
  output <- lapply(team_ids, function(team) {
    appearance <- eligible & (home == team | away == team)
    data.frame(
      team_id = team,
      history_match_count = sum(appearance),
      effective_match_count = sum(decay[appearance]),
      latest_match_date = if (any(appearance)) max(dates[appearance]) else as.Date(NA),
      evidence_cutoff_exclusive = cutoff,
      evidence_half_life_days = evidence_half_life_days,
      effective_count_formula = "sum(exp(-log(2) * (evidence_cutoff_exclusive - match_date) / evidence_half_life_days))",
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, output)
}

#' Apply continuous evidence-weighted structural shrinkage to goal means.
#' @export
apply_structural_sparse_shrinkage <- function(
    means, prior_strength = 4, evidence_half_life_days = 730,
    registered_vintage_id, bounds = c(0.05, 5)
) {
  required <- c("team_id", "baseline_mean", "structural_prior", "effective_match_count")
  if (!is.data.frame(means) || !nrow(means)) stop("Structural shrinkage means must contain rows", call. = FALSE)
  missing <- setdiff(required, names(means))
  if (length(missing)) stop("Structural shrinkage means are missing: ", paste(missing, collapse = ", "), call. = FALSE)
  if (length(prior_strength) != 1L || !is.finite(prior_strength) || prior_strength <= 0) stop("Structural prior strength must be positive", call. = FALSE)
  if (length(evidence_half_life_days) != 1L || !is.finite(evidence_half_life_days) || evidence_half_life_days <= 0) stop("Structural evidence half-life must be positive", call. = FALSE)
  if (length(registered_vintage_id) != 1L || is.na(registered_vintage_id) || !nzchar(registered_vintage_id)) stop("Structural shrinkage requires a registered vintage ID", call. = FALSE)
  if (length(bounds) != 2L || any(!is.finite(bounds)) || bounds[[1L]] <= 0 || bounds[[1L]] >= bounds[[2L]]) stop("Structural shrinkage bounds are invalid", call. = FALSE)
  baseline <- suppressWarnings(as.numeric(means$baseline_mean))
  prior <- suppressWarnings(as.numeric(means$structural_prior))
  count <- suppressWarnings(as.numeric(means$effective_match_count))
  if (any(!is.finite(baseline) | baseline <= 0 | !is.finite(prior) | prior <= 0 | !is.finite(count) | count < 0)) {
    stop("Structural shrinkage inputs must be finite and positive/non-negative", call. = FALSE)
  }
  prior_weight <- prior_strength / (prior_strength + count)
  post <- (1 - prior_weight) * baseline + prior_weight * prior
  post <- pmin(bounds[[2L]], pmax(bounds[[1L]], post))
  output <- data.frame(
    team_id = as.character(means$team_id),
    prior_weight = prior_weight,
    pre_shrinkage_mean = baseline,
    structural_prior = prior,
    post_shrinkage_mean = post,
    effective_match_count = count,
    prior_strength = prior_strength,
    evidence_half_life_days = evidence_half_life_days,
    registered_vintage_id = as.character(registered_vintage_id),
    effective_count_formula = "sum(exp(-log(2) * (evidence_cutoff_exclusive - match_date) / evidence_half_life_days))",
    lower_bound = bounds[[1L]],
    upper_bound = bounds[[2L]],
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  if ("fixture_id" %in% names(means)) output$fixture_id <- as.character(means$fixture_id)
  output
}
