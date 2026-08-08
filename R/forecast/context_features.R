#' Deterministic open tournament-context features for Phase 11

.phase11_context_root <- function(path = ".") {
  if (exists(".phase11_protocol_root", mode = "function")) {
    return(.phase11_protocol_root(path))
  }
  candidate <- normalizePath(path, mustWork = TRUE)
  repeat {
    if (dir.exists(file.path(candidate, ".git")) || file.exists(file.path(candidate, ".git"))) {
      return(candidate)
    }
    parent <- dirname(candidate)
    if (identical(parent, candidate)) stop("Could not locate the xGelo project root", call. = FALSE)
    candidate <- parent
  }
}

.phase11_context_hash <- function(value, serialize = FALSE, file = FALSE) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("digest is required for Phase 11 context provenance", call. = FALSE)
  }
  if (isTRUE(file)) return(digest::digest(value, algo = "sha256", file = TRUE))
  digest::digest(value, algo = "sha256", serialize = serialize)
}

.phase11_context_scalar <- function(value) {
  if (inherits(value, "Date")) value <- format(value, "%Y-%m-%d")
  if (is.logical(value)) value <- ifelse(is.na(value), "", ifelse(value, "true", "false"))
  value <- as.character(value)
  value[is.na(value)] <- ""
  value[value == "TRUE"] <- "true"
  value[value == "FALSE"] <- "false"
  value
}

.phase11_context_row_hash <- function(data, hash_col = "row_sha256") {
  fields <- setdiff(names(data), hash_col)
  vapply(seq_len(nrow(data)), function(index) {
    .phase11_context_hash(
      paste(vapply(data[index, fields, drop = FALSE], .phase11_context_scalar, character(1)), collapse = "|"),
      serialize = FALSE
    )
  }, character(1))
}

.phase11_context_resolve_path <- function(path, must_work = TRUE) {
  root <- .phase11_context_root(".")
  if (grepl("^(/|[A-Za-z]:[/\\\\])", path)) {
    normalizePath(path, mustWork = must_work)
  } else {
    normalizePath(file.path(root, path), mustWork = must_work)
  }
}

#' Return the named Phase 11 open-context feature IDs.
#' @export
phase11_context_feature_names <- function() {
  c("host", "neutral", "rest_days", "travel_km", "stage_id")
}

#' Return fixture columns required to derive the open-context feature set.
#' @export
phase11_context_required_columns <- function() {
  c("fixture_id", "date", "home_team_id", "away_team_id", "venue_country", "stage_id")
}

.phase11_context_centroid_columns <- function() {
  c(
    "country_iso3", "country_name", "latitude", "longitude", "coordinate_role",
    "source_name", "source_url_or_label", "source_vintage", "license_class",
    "derivation_rule", "parent_source_sha256", "row_sha256"
  )
}

.phase11_context_metadata_columns <- function() {
  c(
    "schema_version", "registry_id", "source_name", "source_url_or_label",
    "source_vintage", "license_class", "coordinate_crs", "derivation_rule",
    "normalization_rule", "country_count", "parent_source_sha256",
    "registry_rows_sha256", "row_sha256"
  )
}

.phase11_context_normalize_centroid_metadata <- function(metadata) {
  if (!is.data.frame(metadata) || nrow(metadata) != 1L) {
    stop("Phase 11 country-centroid metadata must contain exactly one row", call. = FALSE)
  }
  required <- .phase11_context_metadata_columns()
  missing <- setdiff(required, names(metadata))
  if (length(missing)) {
    stop("Country-centroid metadata is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  metadata
}

#' Validate the committed Phase 11 country-centroid registry and its parent.
#'
#' @param country_centroids Country proxy rows.
#' @param metadata One-row source and registry metadata table.
#' @param strict_hash Require row and canonical-parent hashes to reconcile.
#' @return Invisibly returns the validated centroid table.
#' @export
validate_phase11_country_centroids <- function(
    country_centroids, metadata = NULL, strict_hash = TRUE
) {
  if (!is.data.frame(country_centroids) || !nrow(country_centroids)) {
    stop("Phase 11 country-centroid registry must contain rows", call. = FALSE)
  }
  required <- .phase11_context_centroid_columns()
  missing <- setdiff(required, names(country_centroids))
  if (length(missing)) {
    stop("Country-centroid registry is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  if (anyDuplicated(as.character(country_centroids$country_iso3))) {
    stop("Country-centroid registry contains duplicate ISO3 rows", call. = FALSE)
  }
  iso3 <- toupper(trimws(as.character(country_centroids$country_iso3)))
  if (any(is.na(iso3) | !grepl("^[A-Z]{3}$", iso3))) {
    stop("Country-centroid registry requires canonical three-letter ISO3 keys", call. = FALSE)
  }
  latitude <- suppressWarnings(as.numeric(country_centroids$latitude))
  longitude <- suppressWarnings(as.numeric(country_centroids$longitude))
  if (any(!is.finite(latitude) | latitude < -90 | latitude > 90) ||
      any(!is.finite(longitude) | longitude < -180 | longitude > 180)) {
    stop("Country-centroid coordinates must be finite WGS84 latitude/longitude values", call. = FALSE)
  }
  if (any(!as.character(country_centroids$coordinate_role) %in% c("admin0_centroid", "country_proxy"))) {
    stop("Country-centroid coordinate_role is not registered", call. = FALSE)
  }
  parent <- tolower(as.character(country_centroids$parent_source_sha256))
  if (any(is.na(parent) | !grepl("^[0-9a-f]{64}$", parent))) {
    stop("Country-centroid parent source hashes must be canonical SHA-256", call. = FALSE)
  }
  if (any(as.character(country_centroids$license_class) != "open-or-derived-open")) {
    stop("Country-centroid rows must use the open-or-derived-open license class", call. = FALSE)
  }
  row_hash <- tolower(as.character(country_centroids$row_sha256))
  if (any(is.na(row_hash) | !grepl("^[0-9a-f]{64}$", row_hash))) {
    stop("Country-centroid row hashes must be canonical SHA-256", call. = FALSE)
  }
  if (isTRUE(strict_hash)) {
    expected <- .phase11_context_row_hash(country_centroids, "row_sha256")
    if (any(row_hash != expected)) stop("Country-centroid row SHA-256 mismatch", call. = FALSE)
  }

  if (!is.null(metadata)) {
    metadata <- .phase11_context_normalize_centroid_metadata(metadata)
    metadata_parent <- tolower(as.character(metadata$parent_source_sha256[[1L]]))
    if (!grepl("^[0-9a-f]{64}$", metadata_parent) || any(parent != metadata_parent)) {
      stop("Country-centroid rows do not share the registered source parent hash", call. = FALSE)
    }
    metadata_hash <- tolower(as.character(metadata$row_sha256[[1L]]))
    if (!grepl("^[0-9a-f]{64}$", metadata_hash)) {
      stop("Country-centroid metadata row hash is not canonical SHA-256", call. = FALSE)
    }
    if (isTRUE(strict_hash)) {
      expected_metadata_hash <- .phase11_context_row_hash(metadata, "row_sha256")
      if (!identical(metadata_hash, expected_metadata_hash[[1L]])) {
        stop("Country-centroid metadata row SHA-256 mismatch", call. = FALSE)
      }
      registry_for_hash <- country_centroids[, names(country_centroids), drop = FALSE]
      expected_rows_hash <- .phase11_context_hash(registry_for_hash, serialize = TRUE)
      if (!identical(
        tolower(as.character(metadata$registry_rows_sha256[[1L]])),
        tolower(expected_rows_hash)
      )) {
        stop("Country-centroid metadata parent row-set hash mismatch", call. = FALSE)
      }
    }
    if (as.integer(metadata$country_count[[1L]]) != nrow(country_centroids)) {
      stop("Country-centroid metadata country_count does not match registry", call. = FALSE)
    }
  }
  invisible(country_centroids)
}

#' Load and validate the committed country-centroid and metadata artifacts.
#'
#' This loader performs no network access.  The package-derived Natural Earth
#' source is represented only by the committed proxy rows and their hashes.
#' @export
load_phase11_country_centroids <- function(
    path = "data/benchmark/phase11/country_centroids.csv",
    metadata_path = "data/benchmark/phase11/country_centroids_metadata.csv"
) {
  centroid_path <- .phase11_context_resolve_path(path, must_work = TRUE)
  metadata_file <- .phase11_context_resolve_path(metadata_path, must_work = TRUE)
  country_centroids <- utils::read.csv(
    centroid_path, stringsAsFactors = FALSE, check.names = FALSE, colClasses = "character"
  )
  metadata <- utils::read.csv(
    metadata_file, stringsAsFactors = FALSE, check.names = FALSE, colClasses = "character"
  )
  validate_phase11_country_centroids(country_centroids, metadata = metadata, strict_hash = TRUE)
  attr(country_centroids, "phase11_context_metadata") <- metadata
  attr(country_centroids, "phase11_context_registry_path") <- centroid_path
  attr(country_centroids, "phase11_context_metadata_path") <- metadata_file
  attr(country_centroids, "phase11_context_registry_sha256") <- .phase11_context_hash(centroid_path, file = TRUE)
  attr(country_centroids, "phase11_context_metadata_sha256") <- .phase11_context_hash(metadata_file, file = TRUE)
  country_centroids
}

.phase11_context_country_aliases <- function() {
  c(
    "South Korea" = "KOR", "Republic of Korea" = "KOR", "Korea Republic" = "KOR",
    "Russia" = "RUS", "Russian Federation" = "RUS",
    "England" = "GBR", "Scotland" = "GBR", "Wales" = "GBR", "United Kingdom" = "GBR",
    "Türkiye" = "TUR", "Turkiye" = "TUR", "Czechia" = "CZE",
    "Czech Republic" = "CZE", "Slovakia" = "SVK", "Netherlands" = "NLD"
  )
}

.phase11_context_country_iso3 <- function(value) {
  value <- trimws(as.character(value))
  if (length(value) != 1L || is.na(value) || !nzchar(value)) return(NA_character_)
  if (grepl("^[A-Za-z]{3}$", value)) return(toupper(value))
  aliases <- .phase11_context_country_aliases()
  if (value %in% names(aliases)) return(unname(aliases[[value]]))
  if (!requireNamespace("countrycode", quietly = TRUE)) {
    stop("countrycode is required for Phase 11 country normalization", call. = FALSE)
  }
  normalized <- countrycode::countrycode(
    value, origin = "country.name", destination = "iso3c",
    custom_match = aliases, warn = FALSE
  )
  ifelse(is.na(normalized), NA_character_, toupper(as.character(normalized)))
}

.phase11_context_date_column <- function(data, label) {
  candidates <- c("date", "actual_completion_date", "scheduled_date", "match_date", "result_date")
  available <- intersect(candidates, names(data))
  if (!length(available)) stop(label, " requires a match date column", call. = FALSE)
  available[[1L]]
}

.phase11_context_team_columns <- function(data, label) {
  if (all(c("home_team_id", "away_team_id") %in% names(data))) {
    return(c(home = "home_team_id", away = "away_team_id"))
  }
  if (all(c("home_team", "away_team") %in% names(data))) {
    return(c(home = "home_team", away = "away_team"))
  }
  stop(label, " requires home and away team columns", call. = FALSE)
}

.phase11_context_history_row <- function(history, team, current_date) {
  date_col <- .phase11_context_date_column(history, "Context history")
  teams <- .phase11_context_team_columns(history, "Context history")
  dates <- as.Date(history[[date_col]])
  team_values <- as.character(history[[teams[["home"]]]]) == team |
    as.character(history[[teams[["away"]]]]) == team
  eligible <- which(team_values & !is.na(dates) & dates < current_date)
  if (!length(eligible)) return(NULL)
  fixture_key <- if ("fixture_id" %in% names(history)) as.character(history$fixture_id) else seq_len(nrow(history))
  eligible <- eligible[order(dates[eligible], fixture_key[eligible], method = "radix")]
  history[eligible[[length(eligible)]], , drop = FALSE]
}

.phase11_context_row_value <- function(value, value_present, source_present, source_date, reason,
                                        source_id, source_vintage, derivation_rule, parent_hashes,
                                        license_class = "open-or-derived-open") {
  list(
    value = value,
    value_present = isTRUE(value_present),
    source_present = isTRUE(source_present),
    source_date = as.Date(source_date),
    imputed = !isTRUE(value_present),
    imputation_reason = if (isTRUE(value_present)) "" else as.character(reason),
    source_id = as.character(source_id),
    source_vintage = as.character(source_vintage),
    derivation_rule = as.character(derivation_rule),
    parent_hashes = as.character(parent_hashes),
    license_class = as.character(license_class)
  )
}

.phase11_context_add_evidence <- function(row, feature_id, evidence) {
  row[[feature_id]] <- evidence$value
  row[[paste0(feature_id, "__value_present")]] <- isTRUE(evidence$value_present)
  row[[paste0(feature_id, "__source_present")]] <- isTRUE(evidence$source_present)
  row[[paste0(feature_id, "__source_date")]] <- as.Date(evidence$source_date)
  row[[paste0(feature_id, "__imputed")]] <- isTRUE(evidence$imputed)
  row[[paste0(feature_id, "__imputation_reason")]] <- as.character(evidence$imputation_reason)
  row[[paste0(feature_id, "__source_id")]] <- as.character(evidence$source_id)
  row[[paste0(feature_id, "__source_vintage")]] <- as.character(evidence$source_vintage)
  row[[paste0(feature_id, "__derivation_rule")]] <- as.character(evidence$derivation_rule)
  row[[paste0(feature_id, "__parent_hashes")]] <- as.character(evidence$parent_hashes)
  row[[paste0(feature_id, "__license_class")]] <- as.character(evidence$license_class)
  row
}

.phase11_context_centroid_lookup <- function(country_centroids) {
  index <- seq_len(nrow(country_centroids))
  index <- stats::setNames(index, toupper(as.character(country_centroids$country_iso3)))
  function(country, label) {
    iso3 <- .phase11_context_country_iso3(country)
    if (is.na(iso3) || !iso3 %in% names(index)) {
      stop(label, " country is absent from the committed centroid registry: ", as.character(country), call. = FALSE)
    }
    country_centroids[index[[iso3]], , drop = FALSE]
  }
}

.phase11_context_country_from_row <- function(row, venue = TRUE) {
  primary <- if (venue) "venue_country" else "host_country"
  fallback <- if (venue) "host_country" else "venue_country"
  for (column in c(primary, fallback)) {
    if (column %in% names(row)) {
      value <- trimws(as.character(row[[column]][[1L]]))
      if (!is.na(value) && nzchar(value)) return(value)
    }
  }
  NA_character_
}

.phase11_context_history_location <- function(row) {
  if ("venue_country" %in% names(row)) {
    value <- trimws(as.character(row$venue_country[[1L]]))
    if (!is.na(value) && nzchar(value)) return(list(value = value, fallback = FALSE))
  }
  if ("host_country" %in% names(row)) {
    value <- trimws(as.character(row$host_country[[1L]]))
    if (!is.na(value) && nzchar(value)) return(list(value = value, fallback = TRUE))
  }
  list(value = NA_character_, fallback = TRUE)
}

.phase11_context_host_value <- function(fixture, teams) {
  if ("host_team_id" %in% names(fixture)) {
    host <- trimws(as.character(fixture$host_team_id[[1L]]))
    if (!is.na(host) && nzchar(host)) {
      return(.phase11_context_row_value(
        if (host == as.character(fixture[[teams[["home"]]]])) 1 else if (host == as.character(fixture[[teams[["away"]]]])) -1 else 0,
        TRUE, FALSE, as.Date(NA), "", "phase09_fixture_registry", "phase09-fixture-v1",
        "signed host-team indicator: home=1, away=-1, non-playing host=0", "fixture_registry"
      ))
    }
  }
  if (all(c("home_is_host", "away_is_host") %in% names(fixture))) {
    home <- fixture$home_is_host[[1L]]
    away <- fixture$away_is_host[[1L]]
    if (!is.na(home) && !is.na(away)) {
      home <- isTRUE(as.logical(home)); away <- isTRUE(as.logical(away))
      if (home && away) stop("Context fixture cannot declare both teams as host", call. = FALSE)
      return(.phase11_context_row_value(
        if (home) 1 else if (away) -1 else 0,
        TRUE, FALSE, as.Date(NA), "", "phase09_fixture_registry", "phase09-fixture-v1",
        "signed host-team indicator derived from checked home_is_host/away_is_host flags", "fixture_registry"
      ))
    }
  }
  .phase11_context_row_value(
    NA_real_, FALSE, FALSE, as.Date(NA), "missing_host_team_declaration",
    "phase09_fixture_registry", "phase09-fixture-v1",
    "host-team indicator requires host_team_id or checked home/away host flags", "fixture_registry"
  )
}

.phase11_context_neutral_value <- function(fixture) {
  if ("neutral" %in% names(fixture) && !is.na(fixture$neutral[[1L]])) {
    value <- tolower(trimws(as.character(fixture$neutral[[1L]])))
    value <- if (value %in% c("true", "1")) TRUE else if (value %in% c("false", "0")) FALSE else NA
    if (!is.na(value)) {
      return(.phase11_context_row_value(
        as.numeric(value), TRUE, FALSE, as.Date(NA), "", "phase09_fixture_registry", "phase09-fixture-v1",
        "neutral venue indicator from checked fixture metadata", "fixture_registry"
      ))
    }
  }
  if ("venue_role" %in% names(fixture)) {
    role <- tolower(trimws(as.character(fixture$venue_role[[1L]])))
    if (role %in% c("home", "away", "neutral")) {
      return(.phase11_context_row_value(
        as.numeric(role == "neutral"), TRUE, FALSE, as.Date(NA), "", "phase09_fixture_registry", "phase09-fixture-v1",
        "neutral venue indicator derived from checked venue_role metadata", "fixture_registry"
      ))
    }
  }
  .phase11_context_row_value(
    NA_real_, FALSE, FALSE, as.Date(NA), "missing_neutral_venue_declaration",
    "phase09_fixture_registry", "phase09-fixture-v1",
    "neutral venue indicator requires checked neutral or venue_role metadata", "fixture_registry"
  )
}

.phase11_context_stage_value <- function(fixture) {
  if ("stage_id" %in% names(fixture)) {
    value <- trimws(as.character(fixture$stage_id[[1L]]))
    if (!is.na(value) && nzchar(value)) {
      return(.phase11_context_row_value(
        value, TRUE, FALSE, as.Date(NA), "", "phase09_fixture_registry", "phase09-fixture-v1",
        "tournament stage copied from checked fixture metadata", "fixture_registry"
      ))
    }
  }
  .phase11_context_row_value(
    NA_character_, FALSE, FALSE, as.Date(NA), "missing_checked_stage_metadata",
    "phase09_fixture_registry", "phase09-fixture-v1",
    "tournament stage requires the checked fixture stage_id", "fixture_registry"
  )
}

.phase11_context_validate_one <- function(data, feature_id, date_values, strict_common_panel) {
  companions <- paste0(feature_id, c(
    "__value_present", "__source_present", "__source_date", "__imputed",
    "__imputation_reason", "__source_id", "__source_vintage", "__derivation_rule",
    "__parent_hashes", "__license_class"
  ))
  missing <- setdiff(c(feature_id, companions), names(data))
  if (length(missing)) stop("Context feature evidence is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  value_present <- as.logical(data[[paste0(feature_id, "__value_present")]])
  source_present <- as.logical(data[[paste0(feature_id, "__source_present")]])
  imputed <- as.logical(data[[paste0(feature_id, "__imputed")]])
  if (anyNA(value_present) || anyNA(source_present) || anyNA(imputed)) {
    stop("Context feature evidence presence flags must be explicit for ", feature_id, call. = FALSE)
  }
  if (any(imputed != !value_present)) stop("Context feature imputation semantics disagree for ", feature_id, call. = FALSE)
  source_date <- as.Date(data[[paste0(feature_id, "__source_date")]])
  invalid_date <- source_present & (is.na(source_date) | source_date >= date_values)
  if (any(invalid_date)) stop("Context feature source date is not strictly before the fixture date for ", feature_id, call. = FALSE)
  if (any(!source_present & !is.na(source_date))) stop("Source-absent context evidence fabricates a source date for ", feature_id, call. = FALSE)
  if (isTRUE(strict_common_panel) && any(!value_present | imputed)) {
    stop("Open common panel has missing or imputed context values for ", feature_id, call. = FALSE)
  }
  if (feature_id != "stage_id") {
    values <- suppressWarnings(as.numeric(data[[feature_id]]))
    if (any(value_present & (!is.finite(values) | is.na(values)))) {
      stop("Context feature contains a non-finite observed value for ", feature_id, call. = FALSE)
    }
  } else if (any(value_present & (is.na(data[[feature_id]]) | !nzchar(as.character(data[[feature_id]]))))) {
    stop("Observed stage context values must be non-empty", call. = FALSE)
  }
  invisible(TRUE)
}

#' Validate all context feature evidence and chronology companions.
#' @export
validate_open_context_feature_evidence <- function(
    data, strict_common_panel = TRUE, date_col = NULL
) {
  if (!is.data.frame(data) || !nrow(data)) stop("Open-context features must contain rows", call. = FALSE)
  if (is.null(date_col)) date_col <- .phase11_context_date_column(data, "Open-context features")
  dates <- as.Date(data[[date_col]])
  if (anyNA(dates)) stop("Open-context fixture dates must be complete", call. = FALSE)
  for (feature in phase11_context_feature_names()) {
    .phase11_context_validate_one(data, feature, dates, strict_common_panel)
  }
  if ("rest_days" %in% names(data)) {
    rest <- suppressWarnings(as.numeric(data$rest_days))
    if (any(is.finite(rest) & rest <= 0)) stop("rest_days must be strictly positive when observed", call. = FALSE)
  }
  if ("travel_km" %in% names(data)) {
    travel <- suppressWarnings(as.numeric(data$travel_km))
    if (any(is.finite(travel) & travel < 0)) stop("travel_km cannot be negative", call. = FALSE)
  }
  invisible(data)
}

.phase11_context_centroid_parent_hashes <- function(country_centroids) {
  registry_hash <- attr(country_centroids, "phase11_context_registry_sha256")
  metadata_hash <- attr(country_centroids, "phase11_context_metadata_sha256")
  if (is.null(registry_hash)) registry_hash <- .phase11_context_hash(country_centroids, serialize = TRUE)
  if (is.null(metadata_hash)) {
    metadata <- attr(country_centroids, "phase11_context_metadata")
    metadata_hash <- if (is.null(metadata)) .phase11_context_hash(character(), serialize = FALSE) else {
      .phase11_context_hash(metadata, serialize = TRUE)
    }
  }
  c(
    centroid_registry_sha256 = as.character(registry_hash),
    centroid_metadata_sha256 = as.character(metadata_hash)
  )
}

#' Build host, neutral, rest, travel, and stage context evidence.
#'
#' Travel is a country-centroid proxy: for each team it measures the geodesic
#' distance from its latest prior venue-country centroid (or prior host-country
#' centroid when the prior venue country is absent) to the current venue-country
#' centroid, then sums both team distances.  It is not stadium-level travel.
#' @export
build_open_context_features <- function(
    fixtures, history, country_centroids = NULL, strict_common_panel = FALSE,
    centroid_path = "data/benchmark/phase11/country_centroids.csv",
    metadata_path = "data/benchmark/phase11/country_centroids_metadata.csv"
) {
  if (!is.data.frame(fixtures) || !nrow(fixtures)) stop("Context fixtures must contain rows", call. = FALSE)
  if (!is.data.frame(history) || !nrow(history)) stop("Context history must contain rows", call. = FALSE)
  if (!requireNamespace("geosphere", quietly = TRUE)) {
    stop("geosphere is required for deterministic travel_km", call. = FALSE)
  }
  date_col <- .phase11_context_date_column(fixtures, "Context fixtures")
  teams <- .phase11_context_team_columns(fixtures, "Context fixtures")
  dates <- as.Date(fixtures[[date_col]])
  if (anyNA(dates)) stop("Context fixture dates must be complete", call. = FALSE)
  if ("fixture_id" %in% names(fixtures) && anyDuplicated(as.character(fixtures$fixture_id))) {
    stop("Context fixture IDs must be unique", call. = FALSE)
  }
  if (is.null(country_centroids)) {
    country_centroids <- load_phase11_country_centroids(centroid_path, metadata_path)
  } else {
    synthetic_fixture <- any(grepl("^synthetic-", as.character(country_centroids$source_name)))
    metadata <- attr(country_centroids, "phase11_context_metadata")
    validate_phase11_country_centroids(
      country_centroids, metadata = metadata,
      strict_hash = !synthetic_fixture
    )
  }
  lookup_centroid <- .phase11_context_centroid_lookup(country_centroids)
  parent_hashes <- .phase11_context_centroid_parent_hashes(country_centroids)
  history_dates <- as.Date(history[[.phase11_context_date_column(history, "Context history")]])
  if (anyNA(history_dates)) stop("Context history dates must be complete", call. = FALSE)
  history_hash <- .phase11_context_hash(history, serialize = TRUE)
  output <- fixtures
  output[[date_col]] <- dates
  if (!"date" %in% names(output)) output$date <- dates
  if (!"fixture_id" %in% names(output)) output$fixture_id <- paste0("context_fixture__", seq_len(nrow(output)))
  rows <- vector("list", nrow(output))

  for (i in seq_len(nrow(output))) {
    fixture <- output[i, , drop = FALSE]
    current_date <- dates[[i]]
    home_team <- as.character(fixture[[teams[["home"]]]][[1L]])
    away_team <- as.character(fixture[[teams[["away"]]]][[1L]])
    if (is.na(home_team) || is.na(away_team) || !nzchar(home_team) || !nzchar(away_team)) {
      stop("Context fixture team identity is incomplete", call. = FALSE)
    }
    current_country <- .phase11_context_country_from_row(fixture, venue = TRUE)
    if (is.na(current_country) || !nzchar(current_country)) {
      if (isTRUE(strict_common_panel)) {
        stop("Open common panel is missing the current venue or host country", call. = FALSE)
      }
    } else {
      current_centroid <- lookup_centroid(current_country, "Current venue/host")
    }

    host <- .phase11_context_host_value(fixture, teams)
    neutral <- .phase11_context_neutral_value(fixture)
    stage <- .phase11_context_stage_value(fixture)

    prior_home <- .phase11_context_history_row(history, home_team, current_date)
    prior_away <- .phase11_context_history_row(history, away_team, current_date)
    prior_dates <- c(
      if (is.null(prior_home)) as.Date(NA) else as.Date(prior_home[[.phase11_context_date_column(history, "Context history")]][[1L]]),
      if (is.null(prior_away)) as.Date(NA) else as.Date(prior_away[[.phase11_context_date_column(history, "Context history")]][[1L]])
    )
    rest_value <- if (all(!is.na(prior_dates))) min(as.numeric(current_date - prior_dates)) else NA_real_
    rest_evidence <- .phase11_context_row_value(
      rest_value, is.finite(rest_value) && rest_value > 0, all(!is.na(prior_dates)),
      if (all(!is.na(prior_dates))) max(prior_dates) else as.Date(NA),
      "missing_prior_match_date", "phase09_fixture_history", "point-in-time prior-match-v1",
      "minimum days since the latest prior match of either team; same-day rows excluded",
      history_hash
    )

    travel_values <- numeric(2L)
    travel_present <- TRUE
    travel_dates <- as.Date(NA)
    fallback_used <- logical(2L)
    prior_rows <- list(prior_home, prior_away)
    for (j in seq_along(prior_rows)) {
      prior <- prior_rows[[j]]
      if (is.null(prior) || is.na(current_country) || !nzchar(current_country)) {
        travel_present <- FALSE
        next
      }
      prior_location <- .phase11_context_history_location(prior)
      fallback_used[[j]] <- prior_location$fallback
      if (is.na(prior_location$value) || !nzchar(prior_location$value)) {
        travel_present <- FALSE
        next
      }
      previous_centroid <- lookup_centroid(prior_location$value, "Prior venue/host")
      travel_values[[j]] <- geosphere::distGeo(
        c(as.numeric(previous_centroid$longitude[[1L]]), as.numeric(previous_centroid$latitude[[1L]])),
        c(as.numeric(current_centroid$longitude[[1L]]), as.numeric(current_centroid$latitude[[1L]]))
      ) / 1000
      if (!is.finite(travel_values[[j]])) travel_present <- FALSE
      if (!is.na(prior_dates[[j]])) travel_dates <- c(travel_dates, prior_dates[[j]])
    }
    travel_dates <- travel_dates[!is.na(travel_dates)]
    travel_value <- if (travel_present) sum(travel_values) else NA_real_
    travel_evidence <- .phase11_context_row_value(
      travel_value, travel_present && is.finite(travel_value), travel_present,
      if (travel_present && length(travel_dates)) max(travel_dates) else as.Date(NA),
      "missing_prior_location_or_country_centroid", "phase09_fixture_history+natural_earth_centroids",
      "point-in-time context-history-v1",
      "point-in-time country-centroid proxy; prior venue country preferred and prior host-country centroid is fallback",
      paste(c(history_hash, parent_hashes), collapse = "#")
    )
    travel_evidence$derivation_rule <- paste0(
      travel_evidence$derivation_rule,
      if (any(fallback_used)) "; prior_host_country_fallback_used" else "; prior_venue_country_used"
    )

    row <- fixture
    row <- .phase11_context_add_evidence(row, "host", host)
    row <- .phase11_context_add_evidence(row, "neutral", neutral)
    row <- .phase11_context_add_evidence(row, "rest_days", rest_evidence)
    row <- .phase11_context_add_evidence(row, "travel_km", travel_evidence)
    row <- .phase11_context_add_evidence(row, "stage_id", stage)
    rows[[i]] <- row
  }
  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  validate_open_context_feature_evidence(result, strict_common_panel = strict_common_panel, date_col = "date")
  attr(result, "phase11_context_parent_hashes") <- parent_hashes
  attr(result, "phase11_context_history_sha256") <- history_hash
  attr(result, "phase11_context_centroid_metadata") <- attr(country_centroids, "phase11_context_metadata")
  attr(result, "phase11_context_strict_common_panel") <- isTRUE(strict_common_panel)
  result
}
