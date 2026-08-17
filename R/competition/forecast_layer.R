#' Phase 14 release-active competition forecast tracer.
#'
#' This file is intentionally a small production boundary around the existing
#' benchmark, feature, form, and release contracts.  It adapts canonical
#' competition fixtures into the legacy feature-table contract, keeps the
#' approved selector authoritative, and returns honest suppression rows when a
#' predictor declared active by the immutable model manifest is unavailable.

phase14_forecast_project_root <- function(path = ".") {
  candidate <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (file.exists(candidate) && !dir.exists(candidate)) candidate <- dirname(candidate)
  repeat {
    if (dir.exists(file.path(candidate, ".git")) || file.exists(file.path(candidate, ".git"))) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
    parent <- dirname(candidate)
    if (identical(parent, candidate)) break
    candidate <- parent
  }
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

phase14_forecast_source_if_missing <- function(relative_path, symbols) {
  missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function")]
  if (!length(missing)) return(invisible(TRUE))
  root <- phase14_forecast_project_root()
  path <- file.path(root, relative_path)
  if (!file.exists(path)) {
    stop("Phase 14 forecast dependency is missing: ", relative_path, call. = FALSE)
  }
  source(path, local = .GlobalEnv)
  missing <- symbols[!vapply(symbols, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop("Phase 14 forecast dependency did not define: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

phase14_forecast_source_if_missing(
  "R/competition/team_identity.R",
  c("phase13_validate_team_identity_registry")
)
phase14_forecast_source_if_missing(
  "R/competition/form.R",
  c("phase14_build_model_form", "phase14_national_team_xg_registry_read")
)
phase14_forecast_source_if_missing(
  "R/forecast/features.R",
  c("build_forecast_feature_table", "validate_forecast_feature_evidence")
)
phase14_forecast_source_if_missing(
  "R/benchmark/contracts.R",
  c("derive_benchmark_markets", "validate_benchmark_score_distributions")
)
phase14_forecast_source_if_missing(
  "R/benchmark/baselines.R",
  c("predict_registered_baseline")
)
phase14_forecast_source_if_missing(
  "R/release/release_contract.R",
  c("phase14_resolve_approved_release")
)

phase14_forecast_text <- function(value, default = NA_character_) {
  if (length(value) == 0L || is.null(value) || is.na(value[[1L]])) return(default)
  value <- trimws(as.character(value[[1L]]))
  if (!nzchar(value)) default else value
}

phase14_forecast_logical <- function(value, default = FALSE) {
  if (length(value) == 0L || is.null(value) || is.na(value[[1L]])) return(default)
  if (is.logical(value)) return(isTRUE(value[[1L]]))
  token <- tolower(trimws(as.character(value[[1L]])))
  if (token %in% c("true", "t", "1", "yes")) TRUE else if (token %in% c("false", "f", "0", "no")) FALSE else default
}

phase14_forecast_column <- function(data, candidates, default = NA_character_) {
  found <- candidates[candidates %in% names(data)]
  if (!length(found)) return(rep(default, nrow(data)))
  as.character(data[[found[[1L]]]])
}

phase14_forecast_parse_utc <- function(value, field = "UTC timestamp") {
  value <- phase14_forecast_text(value)
  if (is.na(value)) stop("Phase 14 ", field, " is missing", call. = FALSE)
  parsed <- as.POSIXct(value, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  if (is.na(parsed)) parsed <- as.POSIXct(value, tz = "UTC")
  if (is.na(parsed)) stop("Phase 14 ", field, " is not an RFC3339 UTC timestamp: ", value, call. = FALSE)
  parsed
}

phase14_forecast_format_utc <- function(value) {
  format(as.POSIXct(value, origin = "1970-01-01", tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

phase14_forecast_parse_set <- function(value) {
  if (length(value) == 0L || is.null(value) || is.na(value[[1L]])) return(character())
  value <- trimws(as.character(value[[1L]]))
  if (!nzchar(value)) return(character())
  values <- unlist(strsplit(value, "[|,]", perl = TRUE), use.names = FALSE)
  values <- trimws(values)
  unique(values[nzchar(values)])
}

phase14_forecast_hash_data <- function(data) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Phase 14 forecast lineage", call. = FALSE)
  if (is.data.frame(data)) {
    data <- data[order(do.call(order, lapply(data, as.character))), , drop = FALSE]
    bytes <- paste(capture.output(utils::write.csv(data, stdout(), row.names = FALSE, na = "", quote = TRUE)), collapse = "\n")
  } else {
    values <- as.character(data)
    values[is.na(values)] <- ""
    bytes <- paste(values, collapse = "|")
  }
  digest::digest(bytes, algo = "sha256", serialize = FALSE)
}

phase14_forecast_file_hash <- function(path) {
  if (!file.exists(path)) stop("Phase 14 forecast lineage file is missing: ", path, call. = FALSE)
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for Phase 14 forecast lineage", call. = FALSE)
  tolower(digest::digest(file = path, algo = "sha256"))
}

phase14_forecast_team_registry <- function(team_registry) {
  if (is.character(team_registry) && length(team_registry) == 1L) {
    if (!file.exists(team_registry)) stop("Phase 14 forecast team registry is missing: ", team_registry, call. = FALSE)
    team_registry <- utils::read.csv(team_registry, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  }
  if (!is.data.frame(team_registry)) stop("Phase 14 forecast team registry must be a data frame or CSV path", call. = FALSE)
  required <- c("team_id", "canonical_name")
  missing <- setdiff(required, names(team_registry))
  if (length(missing)) stop("Phase 14 forecast team registry is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  team_registry$team_id <- as.character(team_registry$team_id)
  team_registry$canonical_name <- as.character(team_registry$canonical_name)
  if (!nrow(team_registry) || any(is.na(team_registry$team_id) | !nzchar(team_registry$team_id)) ||
      any(is.na(team_registry$canonical_name) | !nzchar(team_registry$canonical_name))) {
    stop("Phase 14 forecast team registry contains incomplete stable identity", call. = FALSE)
  }
  if (anyDuplicated(team_registry$team_id) || anyDuplicated(team_registry$canonical_name)) {
    stop("Phase 14 forecast team registry contains ambiguous identity", call. = FALSE)
  }
  if ("row_sha256" %in% names(team_registry) && exists("phase13_validate_team_identity_registry", mode = "function")) {
    source_bundles_path <- file.path(dirname(attr(team_registry, "path") %||% ""), "source_bundles.csv")
    if (file.exists(source_bundles_path)) {
      phase13_validate_team_identity_registry(
        team_registry,
        source_bundles = utils::read.csv(source_bundles_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
      )
    }
  }
  team_registry
}

`%||%` <- function(left, right) if (is.null(left) || !length(left)) right else left

phase14_forecast_manifest_path <- function(path) {
  root <- phase14_forecast_project_root()
  path <- as.character(path[[1L]])
  if (!grepl("^/", path)) path <- file.path(root, path)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

phase14_forecast_model_manifest <- function(
    release,
    model_manifest = NULL,
    model_manifest_path = "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/manifests/model_manifests.csv") {
  if (is.null(model_manifest)) {
    path <- phase14_forecast_manifest_path(model_manifest_path)
    model_manifest <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
    manifest_hash <- phase14_forecast_file_hash(path)
  } else {
    if (!is.data.frame(model_manifest)) stop("Phase 14 model manifest must be a data frame or CSV path", call. = FALSE)
    manifest_hash <- attr(model_manifest, "immutable_manifest_sha256") %||% phase14_forecast_hash_data(model_manifest)
  }
  if (!is.data.frame(model_manifest) || !nrow(model_manifest)) stop("Phase 14 model manifest is empty", call. = FALSE)
  model_id <- if (!is.null(release$model_identity$model_id)) {
    as.character(release$model_identity$model_id)
  } else if (!is.null(release$model$model_id)) {
    as.character(release$model$model_id)
  } else if (!is.null(release$release_identity$selected_model_id)) {
    as.character(release$release_identity$selected_model_id)
  } else {
    "open_nb_incumbent"
  }
  if ("model_id" %in% names(model_manifest)) {
    rows <- model_manifest[as.character(model_manifest$model_id) == model_id, , drop = FALSE]
  } else {
    rows <- model_manifest
  }
  if (!nrow(rows)) stop("Phase 14 model manifest has no row for selected model: ", model_id, call. = FALSE)
  if (nrow(rows) > 1L) {
    # All boundaries of the frozen incumbent must agree on active predictors.
    active_values <- unique(vapply(rows$active_predictors, phase14_forecast_text, character(1)))
    dropped_values <- unique(vapply(rows$dropped_predictors_with_reason, phase14_forecast_text, character(1)))
    if (length(active_values) != 1L || length(dropped_values) != 1L) {
      stop("Phase 14 selected model manifest has drifting active predictor declarations", call. = FALSE)
    }
    rows <- rows[1L, , drop = FALSE]
  }
  if (!all(c("active_predictors", "dropped_predictors_with_reason") %in% names(rows))) {
    stop("Phase 14 model manifest must declare active_predictors and dropped_predictors_with_reason", call. = FALSE)
  }
  active <- phase14_forecast_parse_set(rows$active_predictors[[1L]])
  dropped <- phase14_forecast_parse_set(rows$dropped_predictors_with_reason[[1L]])
  if (!length(active)) stop("Phase 14 selected model manifest declares no active predictors", call. = FALSE)
  if (!grepl("^[0-9a-fA-F]{64}$", as.character(manifest_hash))) {
    stop("Phase 14 model manifest identity is not a SHA-256 hash", call. = FALSE)
  }
  list(
    row = rows,
    model_id = model_id,
    active_predictors = active,
    dropped_predictors_with_reason = dropped,
    manifest_sha256 = tolower(as.character(manifest_hash))
  )
}

phase14_forecast_team_name_lookup <- function(team_registry) {
  setNames(as.character(team_registry$canonical_name), as.character(team_registry$team_id))
}

phase14_forecast_row_value <- function(data, row, candidates, default = NA_character_) {
  found <- candidates[candidates %in% names(data)]
  if (!length(found)) return(default)
  value <- data[[found[[1L]]]][row]
  if (length(value) == 0L || is.na(value)) default else as.character(value)
}

phase14_forecast_status_token <- function(data, row) {
  phase14_forecast_row_value(data, row, c("match_status", "status", "source_status"), "scheduled")
}

phase14_forecast_match_kickoff <- function(data, row) {
  confirmed <- phase14_forecast_logical(
    phase14_forecast_row_value(data, row, c("kickoff_confirmed"), NA_character_),
    default = FALSE
  )
  if (!confirmed) stop("kickoff_unconfirmed", call. = FALSE)
  value <- phase14_forecast_row_value(
    data, row,
    c("confirmed_kickoff_at_utc", "kickoff_utc", "scheduled_at_utc"),
    NA_character_
  )
  if (is.na(value)) stop("kickoff_unconfirmed", call. = FALSE)
  phase14_forecast_parse_utc(value, "confirmed kickoff")
}

phase14_forecast_cutoff_for_row <- function(data, row, kickoff, feature_cutoff_utc = NULL) {
  value <- if (!is.null(feature_cutoff_utc)) {
    if (length(feature_cutoff_utc) == 1L) as.character(feature_cutoff_utc[[1L]]) else as.character(feature_cutoff_utc[[row]])
  } else {
    phase14_forecast_row_value(data, row, c("feature_cutoff_utc", "forecast_cutoff_utc"), NA_character_)
  }
  if (is.na(value) || !nzchar(value)) value <- phase14_forecast_format_utc(kickoff - 1)
  cutoff <- phase14_forecast_parse_utc(value, "feature cutoff")
  if (cutoff >= kickoff) stop("feature_cutoff_after_kickoff", call. = FALSE)
  phase14_forecast_format_utc(cutoff)
}

#' Adapt canonical competition matches to the existing forecast feature table.
#'
#' Stable team IDs are resolved only through the accepted team registry.  The
#' adapter never infers teams from display labels and never turns a scheduled
#' score into zero.
phase14_adapt_matches_for_forecast <- function(
    canonical_matches,
    team_registry,
    feature_cutoff_utc = NULL) {
  if (!is.data.frame(canonical_matches)) stop("Phase 14 forecast canonical matches must be a data frame", call. = FALSE)
  if (!nrow(canonical_matches)) {
    return(data.frame(
      edition_id = character(0), match_id = character(0), fixture_id = character(0),
      home_team_id = character(0), away_team_id = character(0), date = as.Date(character(0)),
      home_team_canonical = character(0), away_team_canonical = character(0),
      home_score = numeric(0), away_score = numeric(0), venue = character(0),
      kickoff_utc = character(0), feature_cutoff_utc = character(0),
      kickoff_confirmed = logical(0), stringsAsFactors = FALSE
    ))
  }
  required <- c("home_team_id", "away_team_id")
  missing <- setdiff(required, names(canonical_matches))
  if (length(missing)) stop("Phase 14 forecast canonical matches missing: ", paste(missing, collapse = ", "), call. = FALSE)
  registry <- phase14_forecast_team_registry(team_registry)
  lookup <- phase14_forecast_team_name_lookup(registry)
  match_ids <- phase14_forecast_column(canonical_matches, c("match_id", "fixture_id"), NA_character_)
  fixture_ids <- phase14_forecast_column(canonical_matches, c("fixture_id", "match_id"), NA_character_)
  if (any(is.na(match_ids) | !nzchar(match_ids)) || anyDuplicated(match_ids)) stop("Phase 14 forecast canonical matches require unique match_id", call. = FALSE)
  home_ids <- as.character(canonical_matches$home_team_id)
  away_ids <- as.character(canonical_matches$away_team_id)
  if (any(is.na(home_ids) | !nzchar(home_ids)) || any(is.na(away_ids) | !nzchar(away_ids))) stop("Phase 14 forecast fixture team identity is unresolved", call. = FALSE)
  if (any(!home_ids %in% names(lookup)) || any(!away_ids %in% names(lookup))) stop("Phase 14 forecast fixture team identity is unresolved", call. = FALSE)
  if (any(home_ids == away_ids)) stop("Phase 14 forecast fixture cannot contain the same home and away team", call. = FALSE)

  rows <- lapply(seq_len(nrow(canonical_matches)), function(row) {
    kickoff <- phase14_forecast_match_kickoff(canonical_matches, row)
    cutoff <- phase14_forecast_cutoff_for_row(canonical_matches, row, kickoff, feature_cutoff_utc)
    venue <- phase14_forecast_row_value(canonical_matches, row, c("venue"), NA_character_)
    if (is.na(venue)) {
      neutral <- phase14_forecast_logical(phase14_forecast_row_value(canonical_matches, row, c("neutral"), NA_character_), FALSE)
      venue <- if (neutral) "neutral" else "home"
    }
    venue <- tolower(trimws(venue))
    if (!venue %in% c("home", "away", "neutral")) stop("Phase 14 forecast fixture venue is invalid", call. = FALSE)
    home_score <- if ("home_score" %in% names(canonical_matches)) suppressWarnings(as.numeric(canonical_matches$home_score[[row]])) else NA_real_
    away_score <- if ("away_score" %in% names(canonical_matches)) suppressWarnings(as.numeric(canonical_matches$away_score[[row]])) else NA_real_
    status <- tolower(phase14_forecast_status_token(canonical_matches, row))
    if (status %in% c("scheduled", "postponed", "abandoned") || status == "") {
      home_score <- NA_real_
      away_score <- NA_real_
    }
    data.frame(
      edition_id = phase14_forecast_row_value(canonical_matches, row, c("edition_id"), NA_character_),
      match_id = match_ids[[row]],
      fixture_id = fixture_ids[[row]],
      home_team_id = home_ids[[row]],
      away_team_id = away_ids[[row]],
      date = as.Date(format(kickoff, "%Y-%m-%d", tz = "UTC")),
      home_team_canonical = unname(lookup[[home_ids[[row]]]]),
      away_team_canonical = unname(lookup[[away_ids[[row]]]]),
      home_score = home_score,
      away_score = away_score,
      venue = venue,
      kickoff_utc = phase14_forecast_format_utc(kickoff),
      feature_cutoff_utc = cutoff,
      kickoff_confirmed = TRUE,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  output <- do.call(rbind, rows)
  rownames(output) <- NULL
  output
}

phase14_forecast_elo_rows_before <- function(elo_ratings, team, cutoff_utc) {
  if (!is.data.frame(elo_ratings)) stop("Phase 14 Elo evidence must be a data frame", call. = FALSE)
  team_col <- if ("team" %in% names(elo_ratings)) "team" else if ("team_canonical" %in% names(elo_ratings)) "team_canonical" else ""
  if (!nzchar(team_col) || !"rating" %in% names(elo_ratings)) return(elo_ratings[FALSE, , drop = FALSE])
  date_col <- if ("date" %in% names(elo_ratings)) "date" else if ("evidence_date" %in% names(elo_ratings)) "evidence_date" else ""
  if (!nzchar(date_col)) return(elo_ratings[FALSE, , drop = FALSE])
  rows <- elo_ratings[as.character(elo_ratings[[team_col]]) == as.character(team), , drop = FALSE]
  if (!nrow(rows)) return(rows)
  cutoff <- phase14_forecast_parse_utc(cutoff_utc, "feature cutoff")
  evidence_col <- c("evidence_at_utc", "evidence_completed_at_utc", "updated_at_utc", "timestamp_utc")
  evidence_col <- evidence_col[evidence_col %in% names(rows)]
  if (length(evidence_col)) {
    evidence <- as.POSIXct(as.character(rows[[evidence_col[[1L]]]]), format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    evidence[is.na(evidence)] <- as.POSIXct(paste(as.Date(rows[[date_col]][is.na(evidence)]), "00:00:00"), tz = "UTC")
  } else {
    evidence <- as.POSIXct(paste(as.Date(rows[[date_col]]), "00:00:00"), tz = "UTC")
  }
  rating <- suppressWarnings(as.numeric(rows$rating))
  keep <- !is.na(evidence) & evidence < cutoff & is.finite(rating)
  rows <- rows[keep, , drop = FALSE]
  if (!nrow(rows)) return(rows)
  rows$.__phase14_evidence_at_utc <- evidence[keep]
  rows <- rows[order(rows$.__phase14_evidence_at_utc, method = "radix"), , drop = FALSE]
  rows
}

phase14_forecast_elo_evidence <- function(elo_ratings, home_team, away_team, cutoff_utc, venue, home_advantage = 60) {
  home <- phase14_forecast_elo_rows_before(elo_ratings, home_team, cutoff_utc)
  away <- phase14_forecast_elo_rows_before(elo_ratings, away_team, cutoff_utc)
  if (!nrow(home) || !nrow(away)) {
    return(list(value = NA_real_, available = FALSE, latest = as.POSIXct(NA), source_id = "elo_ratings"))
  }
  home <- home[nrow(home), , drop = FALSE]
  away <- away[nrow(away), , drop = FALSE]
  value <- as.numeric(home$rating[[1L]]) - as.numeric(away$rating[[1L]])
  if (identical(venue, "home")) value <- value + as.numeric(home_advantage)
  if (identical(venue, "away")) value <- value - as.numeric(home_advantage)
  list(
    value = value,
    available = is.finite(value),
    latest = max(home$.__phase14_evidence_at_utc[[1L]], away$.__phase14_evidence_at_utc[[1L]]),
    source_id = "elo_ratings"
  )
}

phase14_forecast_set_missing_xg <- function(features, values = c("xgf_ewma_diff", "xga_ewma_diff", "xgd_ewma_diff", "form_index_diff")) {
  for (value in values) {
    if (value %in% names(features)) features[[value]] <- NA_real_
  }
  features
}

phase14_forecast_model_form_for_teams <- function(
    adapted_matches,
    national_team_xg_history,
    national_team_xg_registry,
    edition_id = NULL) {
  teams <- unique(c(as.character(adapted_matches$home_team_id), as.character(adapted_matches$away_team_id)))
  cutoff <- min(as.POSIXct(adapted_matches$feature_cutoff_utc, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  cutoff_text <- phase14_forecast_format_utc(cutoff)
  if (is.null(national_team_xg_history)) national_team_xg_history <- data.frame(stringsAsFactors = FALSE)
  phase14_build_model_form(
    xg_history = national_team_xg_history,
    teams = teams,
    feature_cutoff_utc = cutoff_text,
    span = 12L,
    registry = national_team_xg_registry,
    edition_id = edition_id,
    project_root = phase14_forecast_project_root()
  )
}

phase14_forecast_model_form_values <- function(model_form, team_id, field) {
  rows <- model_form[as.character(model_form$team_id) == as.character(team_id), , drop = FALSE]
  if (!nrow(rows) || !field %in% names(rows)) return(NA_real_)
  value <- suppressWarnings(as.numeric(rows[[field]][[1L]]))
  if (is.finite(value)) value else NA_real_
}

phase14_forecast_active_feature_id <- function(predictor) {
  aliases <- c(
    elo_difference_for_team = "elo_diff",
    venue_advantage_for_team = "elo_diff",
    elo_diff = "elo_diff",
    xgf_ewma_diff = "xgf_ewma_diff",
    xga_ewma_diff = "xga_ewma_diff",
    xgd_ewma_diff = "xgd_ewma_diff",
    form_index_diff = "form_index_diff"
  )
  if (predictor %in% names(aliases)) unname(aliases[[predictor]]) else predictor
}

phase14_forecast_active_xg <- function(active_predictors) {
  any(vapply(active_predictors, phase14_forecast_active_feature_id, character(1)) %in% c("xgf_ewma_diff", "xga_ewma_diff", "xgd_ewma_diff"))
}

#' Build feature evidence using the immutable active-predictor declaration.
phase14_build_release_features <- function(
    adapted_matches,
    resolved_release = NULL,
    selector_path = NULL,
    trusted_release_root = "outputs/releases",
    elo_ratings,
    team_registry = file.path(phase14_forecast_project_root(), "data/competition/registries/team_identity.csv"),
    national_team_xg_registry = NULL,
    national_team_xg_history = NULL,
    model_manifest = NULL,
    model_manifest_path = "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/manifests/model_manifests.csv",
    rolling_form = NULL,
    home_advantage = 60) {
  if (!is.data.frame(adapted_matches) || !nrow(adapted_matches)) stop("Phase 14 release features require adapted matches", call. = FALSE)
  if (is.null(resolved_release)) {
    if (is.null(selector_path)) selector_path <- file.path(trusted_release_root, "approved_release.csv")
    resolved_release <- phase14_resolve_approved_release(selector_path, trusted_release_root)
  }
  registry <- phase14_forecast_team_registry(team_registry)
  manifest <- phase14_forecast_model_manifest(resolved_release, model_manifest, model_manifest_path)
  if (is.null(national_team_xg_registry)) {
    national_team_xg_registry <- file.path(phase14_forecast_project_root(), "data/competition/registries/national_team_xg_sources.csv")
  }
  if (!is.null(rolling_form)) {
    # The legacy club product is never an implicit national-team xG source.
    if (is.data.frame(rolling_form) && "team" %in% names(rolling_form) &&
        "match_date" %in% names(rolling_form) &&
        !any(c("match_id", "canonical_match_id", "source_match_id") %in% names(rolling_form))) {
      stop("Phase 14 forecast rejects club rolling_form.csv as national-team xG evidence", call. = FALSE)
    }
    if (is.null(national_team_xg_history)) national_team_xg_history <- rolling_form
  }
  model_form <- phase14_forecast_model_form_for_teams(
    adapted_matches,
    national_team_xg_history,
    national_team_xg_registry,
    edition_id = unique(as.character(adapted_matches$edition_id))[[1L]]
  )
  features <- build_forecast_feature_table(
    matches = adapted_matches,
    elo_ratings = elo_ratings,
    rolling_form = NULL,
    cutoff_date = NULL,
    home_advantage = home_advantage
  )
  features <- cbind(
    adapted_matches,
    features[, setdiff(names(features), names(adapted_matches)), drop = FALSE]
  )
  feature_source_dates <- as.POSIXct(rep(NA_character_, nrow(features)), format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  elo_available <- logical(nrow(features))
  for (row in seq_len(nrow(features))) {
    evidence <- phase14_forecast_elo_evidence(
      elo_ratings,
      adapted_matches$home_team_canonical[[row]],
      adapted_matches$away_team_canonical[[row]],
      adapted_matches$feature_cutoff_utc[[row]],
      adapted_matches$venue[[row]],
      home_advantage
    )
    elo_available[[row]] <- evidence$available
    features$elo_diff[[row]] <- evidence$value
    features$elo_diff__value_present[[row]] <- evidence$available
    features$elo_diff__source_present[[row]] <- evidence$available
    features$elo_diff__imputed[[row]] <- !evidence$available
    features$elo_diff__imputation_reason[[row]] <- if (evidence$available) "" else "missing_source_row"
    feature_source_dates[[row]] <- evidence$latest
    features$elo_diff__source_date[[row]] <- as.Date(evidence$latest)
    features$elo_diff__evidence_at_utc[[row]] <- if (evidence$available) phase14_forecast_format_utc(evidence$latest) else NA_character_
  }
  features <- phase14_forecast_set_missing_xg(features)
  active_ids <- unique(vapply(manifest$active_predictors, phase14_forecast_active_feature_id, character(1)))
  xg_available <- rep(FALSE, nrow(features))
  for (row in seq_len(nrow(features))) {
    home_id <- adapted_matches$home_team_id[[row]]
    away_id <- adapted_matches$away_team_id[[row]]
    xgf_home <- phase14_forecast_model_form_values(model_form, home_id, "xgf_ewma")
    xgf_away <- phase14_forecast_model_form_values(model_form, away_id, "xgf_ewma")
    xga_home <- phase14_forecast_model_form_values(model_form, home_id, "xga_ewma")
    xga_away <- phase14_forecast_model_form_values(model_form, away_id, "xga_ewma")
    xgd_home <- phase14_forecast_model_form_values(model_form, home_id, "xgd_ewma")
    xgd_away <- phase14_forecast_model_form_values(model_form, away_id, "xgd_ewma")
    values <- c(xgf_home - xgf_away, xga_home - xga_away, xgd_home - xgd_away)
    xg_available[[row]] <- all(is.finite(values)) &&
      all(as.character(model_form$availability_status[match(c(home_id, away_id), model_form$team_id)]) == "available")
    if (xg_available[[row]]) {
      features$xgf_ewma_diff[[row]] <- values[[1L]]
      features$xga_ewma_diff[[row]] <- values[[2L]]
      features$xgd_ewma_diff[[row]] <- values[[3L]]
      for (field in c("xgf_ewma_diff", "xga_ewma_diff", "xgd_ewma_diff")) {
        features[[paste0(field, "__value_present")]][[row]] <- TRUE
        features[[paste0(field, "__source_present")]][[row]] <- TRUE
        features[[paste0(field, "__imputed")]][[row]] <- FALSE
        features[[paste0(field, "__imputation_reason")]][[row]] <- ""
      }
    }
  }
  missing_active <- active_ids[!vapply(active_ids, function(feature_id) {
    if (!feature_id %in% names(features)) return(FALSE)
    companion <- paste0(feature_id, "__value_present")
    if (companion %in% names(features)) all(as.logical(features[[companion]])) else all(is.finite(as.numeric(features[[feature_id]])))
  }, logical(1))]
  if (length(missing_active)) {
    missing_active <- unique(missing_active)
  }
  feature_evidence_status <- if (!length(missing_active)) "available" else "unavailable"
  xg_status <- if (phase14_forecast_active_xg(manifest$active_predictors)) {
    if (all(xg_available)) "available" else "active_required_missing"
  } else {
    "inactive_optional_unavailable"
  }
  cutoff_dates <- as.POSIXct(adapted_matches$feature_cutoff_utc, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  latest <- if (all(is.na(feature_source_dates))) as.POSIXct(NA) else max(feature_source_dates, na.rm = TRUE)
  if (!is.na(latest) && any(latest >= cutoff_dates)) stop("Phase 14 forecast feature evidence is not strictly before cutoff", call. = FALSE)
  list(
    feature_table = features,
    adapted_matches = adapted_matches,
    active_predictors = manifest$active_predictors,
    dropped_predictors_with_reason = manifest$dropped_predictors_with_reason,
    model_manifest = manifest$row,
    model_manifest_sha256 = manifest$manifest_sha256,
    feature_evidence_status = feature_evidence_status,
    missing_active_predictors = missing_active,
    xg_evidence_status = xg_status,
    national_team_xg_status = xg_status,
    model_form = model_form,
    feature_evidence_source = unique(c("elo_ratings", if (xg_status == "available") "national_team_xg" else character())),
    latest_evidence_at_utc = if (is.na(latest)) NA_character_ else phase14_forecast_format_utc(latest),
    feature_cutoff_utc = as.character(adapted_matches$feature_cutoff_utc),
    cutoff_safe = !length(missing_active) && (is.na(latest) || all(feature_source_dates < cutoff_dates)),
    registry_sha256 = phase14_forecast_hash_data(registry)
  )
}

phase14_forecast_empty_result <- function(reason = "pre_draw") {
  status <- data.frame(
    edition_id = character(0), fixture_id = character(0), match_id = character(0),
    kickoff_utc = character(0), feature_cutoff_utc = character(0),
    forecast_status = character(0), suppression_reason = character(0),
    feature_evidence_status = character(0), release_calibration_status = character(0),
    stringsAsFactors = FALSE
  )
  list(
    forecasts = data.frame(stringsAsFactors = FALSE),
    score_distributions = data.frame(stringsAsFactors = FALSE),
    fixture_status = status,
    status = reason,
    suppression_reason = reason
  )
}

phase14_forecast_lineage_row <- function(
    adapted, feature_result, resolved_release, team_registry, edition_registry = NULL,
    forecast_status = "suppressed", suppression_reason = "none",
    release_calibration_status = "fitted") {
  edition_id <- as.character(adapted$edition_id[[1L]])
  registry_row <- NULL
  if (is.character(edition_registry) && length(edition_registry) == 1L && file.exists(edition_registry)) {
    edition_registry <- utils::read.csv(edition_registry, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  }
  if (is.data.frame(edition_registry) && "edition_id" %in% names(edition_registry)) {
    registry_row <- edition_registry[as.character(edition_registry$edition_id) == edition_id, , drop = FALSE]
    if (nrow(registry_row) > 1L) stop("Phase 14 edition registry has ambiguous edition identity", call. = FALSE)
  }
  has_registry_row <- is.data.frame(registry_row) && nrow(registry_row) == 1L
  source_bundle_id <- if (has_registry_row) phase14_forecast_text(registry_row$source_bundle_id[[1L]], "") else ""
  ruleset_version <- if (has_registry_row) phase14_forecast_text(registry_row$ruleset_version[[1L]], "") else "phase14-state-v1"
  registry_revision <- if (has_registry_row) suppressWarnings(as.integer(registry_row$registry_revision[[1L]])) else NA_integer_
  registry_row_hash <- if (has_registry_row && "row_sha256" %in% names(registry_row)) as.character(registry_row$row_sha256[[1L]]) else phase14_forecast_hash_data(registry_row)
  accepted_state_hash <- if (has_registry_row) phase14_forecast_hash_data(registry_row) else phase14_forecast_hash_data(edition_id)
  release_identity <- resolved_release$release_identity %||% list()
  model_identity <- resolved_release$model_identity %||% list()
  calibrator_identity <- resolved_release$calibrator_identity %||% list()
  team_hash <- phase14_forecast_hash_data(team_registry)
  model_form_hash <- phase14_forecast_hash_data(feature_result$model_form)
  feature_table <- if (is.data.frame(feature_result$feature_table)) feature_result$feature_table else data.frame(stringsAsFactors = FALSE)
  history_hash <- phase14_forecast_hash_data(feature_table[, intersect(c("match_id", "elo_diff", "elo_diff__source_date"), names(feature_table)), drop = FALSE])
  data.frame(
    edition_id = edition_id,
    fixture_id = as.character(adapted$fixture_id[[1L]]),
    match_id = as.character(adapted$match_id[[1L]]),
    kickoff_utc = as.character(adapted$kickoff_utc[[1L]]),
    feature_cutoff_utc = as.character(adapted$feature_cutoff_utc[[1L]]),
    forecast_status = forecast_status,
    suppression_reason = suppression_reason,
    feature_evidence_status = feature_result$feature_evidence_status,
    release_calibration_status = release_calibration_status,
    model_release_id = phase14_forecast_text(release_identity$release_id, ""),
    release_manifest_sha256 = phase14_forecast_text(release_identity$manifest_sha256, ""),
    model_id = phase14_forecast_text(model_identity$model_id, phase14_forecast_text(resolved_release$model$model_id, "")),
    model_sha256 = phase14_forecast_text(model_identity$sha256, ""),
    calibrator_id = phase14_forecast_text(calibrator_identity$calibrator_id, ""),
    calibrator_sha256 = phase14_forecast_text(calibrator_identity$sha256, ""),
    model_data_cutoff = phase14_forecast_text(resolved_release$model_data_cutoff, ""),
    feature_evidence_source = paste(feature_result$feature_evidence_source, collapse = "|"),
    latest_evidence_at_utc = phase14_forecast_text(feature_result$latest_evidence_at_utc, ""),
    source_bundle_id = source_bundle_id,
    accepted_state_sha256 = accepted_state_hash,
    edition_registry_revision = registry_revision,
    edition_registry_row_sha256 = registry_row_hash,
    ruleset_version = ruleset_version,
    team_identity_registry_sha256 = team_hash,
    contributing_form_sha256 = model_form_hash,
    contributing_history_sha256 = history_hash,
    generated_at_utc = phase14_forecast_format_utc(Sys.time()),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase14_forecast_apply_calibrator <- function(calibrator, raw) {
  raw <- as.numeric(raw)
  if (length(raw) != 3L || any(!is.finite(raw)) || any(raw <= 0) || sum(raw) <= 0) stop("Phase 14 raw probability vector is invalid", call. = FALSE)
  raw <- raw / sum(raw)
  if (is.list(calibrator) && all(c("slope_home", "slope_draw", "slope_away", "offset_home", "offset_draw", "offset_away") %in% names(calibrator)) &&
      all(is.finite(as.numeric(unlist(calibrator[c("slope_home", "slope_draw", "slope_away", "offset_home", "offset_draw", "offset_away")]))))) {
    slopes <- as.numeric(unlist(calibrator[c("slope_home", "slope_draw", "slope_away")]))
    offsets <- as.numeric(unlist(calibrator[c("offset_home", "offset_draw", "offset_away")]))
    logits <- log(pmax(raw, 1e-15)) * slopes + offsets
    logits <- logits - max(logits)
    calibrated <- exp(logits)
    calibrated / sum(calibrated)
  } else if (is.list(calibrator) && is.finite(as.numeric(calibrator$temperature %||% NA_real_))) {
    temperature <- as.numeric(calibrator$temperature)
    logits <- log(pmax(raw, 1e-15)) / temperature
    logits <- logits - max(logits)
    calibrated <- exp(logits)
    calibrated / sum(calibrated)
  } else {
    stop("Phase 14 fitted calibrator has no supported 1X2 transform", call. = FALSE)
  }
}

phase14_forecast_order_scorelines <- function(grid) {
  grid[order(-grid$probability, grid$home_goals + grid$away_goals, grid$home_goals, grid$away_goals), , drop = FALSE]
}

phase14_forecast_cdf_quantile <- function(grid, column, threshold) {
  support <- 0:max(grid[[column]])
  marginal <- vapply(support, function(value) sum(grid$probability[grid[[column]] == value]), numeric(1))
  support[which(cumsum(marginal) >= threshold)[[1L]]]
}

phase14_forecast_available_row <- function(
    adapted, features, resolved_release, prediction, grid, edition_registry, team_registry) {
  market <- derive_benchmark_markets(grid)
  raw <- as.numeric(market[c("p_home", "p_draw", "p_away")])
  calibrated <- phase14_forecast_apply_calibrator(resolved_release$calibrator, raw)
  names(calibrated) <- c("home", "draw", "away")
  ordered <- phase14_forecast_order_scorelines(grid)
  top10 <- ordered[seq_len(min(10L, nrow(ordered))), , drop = FALSE]
  consumer_entropy <- -sum(calibrated * log(pmax(calibrated, 1e-15)))
  lineage <- phase14_forecast_lineage_row(
    adapted, features, resolved_release, team_registry, edition_registry,
    forecast_status = "available", suppression_reason = "none"
  )
  row <- cbind(
    lineage,
    data.frame(
      raw_probability_view = "raw_1x2",
      primary_probability_view = "calibrated_1x2",
      p_home_raw = raw[[1L]], p_draw_raw = raw[[2L]], p_away_raw = raw[[3L]],
      p_home = calibrated[[1L]], p_draw = calibrated[[2L]], p_away = calibrated[[3L]],
      expected_home_goals = market$expected_home_goals,
      expected_away_goals = market$expected_away_goals,
      modal_home_goals = market$modal_home_goals,
      modal_away_goals = market$modal_away_goals,
      modal_score_probability = market$modal_score_probability,
      score_distribution_id = as.character(grid$score_distribution_id[[1L]]),
      score_support_min = 0L,
      score_support_max = 40L,
      score_cell_count = nrow(grid),
      raw_tail_mass = unique(as.numeric(grid$raw_tail_mass))[[1L]],
      top10_scoreline_mass = sum(top10$probability),
      top10_omitted_mass = 1 - sum(top10$probability),
      entropy_nats = consumer_entropy,
      max_outcome_probability = max(calibrated),
      home_goals_p10 = phase14_forecast_cdf_quantile(grid, "home_goals", 0.10),
      home_goals_p90 = phase14_forecast_cdf_quantile(grid, "home_goals", 0.90),
      away_goals_p10 = phase14_forecast_cdf_quantile(grid, "away_goals", 0.10),
      away_goals_p90 = phase14_forecast_cdf_quantile(grid, "away_goals", 0.90),
      uncertainty_status = "available",
      calculation_method = "analytic_negative_binomial",
      seed_status = "not_applicable",
      simulation_count_status = "not_applicable",
      monte_carlo_seed = NA_integer_,
      monte_carlo_count = NA_integer_,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
  row$score_support_max <- as.integer(row$score_support_max)
  row$score_cell_count <- as.integer(row$score_cell_count)
  row$edition_registry_revision <- as.integer(row$edition_registry_revision)
  row$modal_home_goals <- as.integer(row$modal_home_goals)
  row$modal_away_goals <- as.integer(row$modal_away_goals)
  row$row_sha256 <- ""
  row$row_sha256 <- phase14_forecast_hash_data(row[, setdiff(names(row), "row_sha256"), drop = FALSE])
  row
}

phase14_forecast_status_for_row <- function(adapted, features, resolved_release, status, reason, team_registry, edition_registry) {
  release_status <- if (!is.null(resolved_release$calibrator)) "fitted" else "unavailable"
  phase14_forecast_lineage_row(
    adapted, features, resolved_release, team_registry, edition_registry,
    forecast_status = status, suppression_reason = reason,
    release_calibration_status = release_status
  )
}

phase14_forecast_legacy_cases <- function(cases) {
  status_cases <- cases[as.integer(cases$expected_status_row_count) == 1L, , drop = FALSE]
  fixture_status <- status_cases[, intersect(c(
    "edition_id", "fixture_id", "kickoff_utc", "feature_cutoff_utc", "forecast_status",
    "suppression_reason", "feature_evidence_status", "release_calibration_status",
    "model_release_id", "release_manifest_sha256", "model_id", "model_sha256",
    "calibrator_id", "calibrator_sha256", "model_data_cutoff", "primary_probability_view"
  ), names(status_cases)), drop = FALSE]
  forecasts <- status_cases[status_cases$forecast_status == "available", , drop = FALSE]
  if (nrow(forecasts)) {
    forecasts <- forecasts[, intersect(c(
      "edition_id", "fixture_id", "kickoff_utc", "feature_cutoff_utc", "forecast_status",
      "suppression_reason", "feature_evidence_status", "release_calibration_status",
      "model_release_id", "release_manifest_sha256", "model_id", "model_sha256",
      "calibrator_id", "calibrator_sha256", "model_data_cutoff", "raw_probability_view",
      "primary_probability_view", "p_home_raw", "p_draw_raw", "p_away_raw", "p_home",
      "p_draw", "p_away", "expected_home_goals", "expected_away_goals", "modal_home_goals",
      "modal_away_goals", "modal_score_probability", "score_distribution_id", "score_support_min",
      "score_support_max", "score_cell_count", "raw_tail_mass", "top10_scoreline_mass",
      "top10_omitted_mass", "entropy_nats", "max_outcome_probability", "home_goals_p10",
      "home_goals_p90", "away_goals_p10", "away_goals_p90", "uncertainty_status",
      "calculation_method", "seed_status", "simulation_count_status", "monte_carlo_seed",
      "monte_carlo_count", "source_bundle_id", "accepted_state_sha256", "edition_registry_revision",
      "edition_registry_row_sha256", "ruleset_version", "team_identity_registry_sha256",
      "contributing_form_sha256", "contributing_history_sha256", "generated_at_utc"
    ), names(forecasts)), drop = FALSE]
    rownames(forecasts) <- NULL
    row <- forecasts[1L, , drop = FALSE]
    support <- seq.int(as.integer(row$score_support_min), as.integer(row$score_support_max))
    home_probability <- stats::dnbinom(support, size = as.numeric(status_cases$grid_home_theta[[1L]]), mu = as.numeric(status_cases$grid_home_mean[[1L]]))
    away_probability <- stats::dnbinom(support, size = as.numeric(status_cases$grid_away_theta[[1L]]), mu = as.numeric(status_cases$grid_away_mean[[1L]]))
    raw <- outer(home_probability, away_probability)
    distribution <- expand.grid(home_goals = support, away_goals = support)
    distribution$score_distribution_id <- as.character(row$score_distribution_id[[1L]])
    distribution$probability <- as.vector(raw / sum(raw))
    distribution$support_max_home <- as.integer(row$score_support_max[[1L]])
    distribution$support_max_away <- as.integer(row$score_support_max[[1L]])
    distribution$raw_tail_mass <- as.numeric(row$raw_tail_mass[[1L]])
    distribution$normalized <- TRUE
  } else {
    forecasts <- data.frame(stringsAsFactors = FALSE)
    distribution <- data.frame(stringsAsFactors = FALSE)
  }
  list(forecasts = forecasts, score_distributions = distribution, fixture_status = fixture_status)
}

phase14_forecast_edition_row <- function(edition_registry, edition_id) {
  if (is.character(edition_registry) && length(edition_registry) == 1L && file.exists(edition_registry)) {
    edition_registry <- utils::read.csv(edition_registry, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  }
  if (!is.data.frame(edition_registry) || !"edition_id" %in% names(edition_registry)) return(NULL)
  rows <- edition_registry[as.character(edition_registry$edition_id) == as.character(edition_id), , drop = FALSE]
  if (nrow(rows) > 1L) stop("Phase 14 edition registry has ambiguous edition identity", call. = FALSE)
  if (nrow(rows)) rows else NULL
}

phase14_forecast_eligibility <- function(matches, row, edition_id) {
  if ("edition_id" %in% names(matches) && !is.na(matches$edition_id[[row]]) &&
      as.character(matches$edition_id[[row]]) != as.character(edition_id)) return("cross_edition")
  home <- phase14_forecast_row_value(matches, row, c("home_team_id"), NA_character_)
  away <- phase14_forecast_row_value(matches, row, c("away_team_id"), NA_character_)
  if (is.na(home) || is.na(away) || !nzchar(home) || !nzchar(away)) return("identity_unresolved")
  status <- tolower(phase14_forecast_status_token(matches, row))
  if (!status %in% c("scheduled", "open", "pending")) return("status_ineligible")
  tryCatch({
    kickoff <- phase14_forecast_match_kickoff(matches, row)
    phase14_forecast_cutoff_for_row(matches, row, kickoff, NULL)
    "eligible"
  }, error = function(error) conditionMessage(error))
}

#' Generate one-fixture (or small canonical batch) forecasts from approved state.
phase14_build_fixture_forecasts <- function(
    canonical_matches,
    team_registry = file.path(phase14_forecast_project_root(), "data/competition/registries/team_identity.csv"),
    resolved_release = NULL,
    selector_path = NULL,
    trusted_release_root = file.path(phase14_forecast_project_root(), "outputs/releases"),
    elo_ratings = NULL,
    national_team_xg_registry = NULL,
    national_team_xg_history = NULL,
    model_manifest = NULL,
    model_manifest_path = "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/manifests/model_manifests.csv",
    edition_registry = file.path(phase14_forecast_project_root(), "data/competition/registries/competition_editions.csv"),
    edition_lifecycle_state = NULL,
    rolling_form = NULL) {
  if (!is.data.frame(canonical_matches)) stop("Phase 14 fixture forecasts require a data frame", call. = FALSE)
  if ("case_id" %in% names(canonical_matches) && "expected_status_row_count" %in% names(canonical_matches)) {
    return(phase14_forecast_legacy_cases(canonical_matches))
  }
  if (!nrow(canonical_matches)) {
    return(phase14_forecast_empty_result(edition_lifecycle_state %||% "pre_draw"))
  }
  edition_id <- if ("edition_id" %in% names(canonical_matches)) unique(as.character(canonical_matches$edition_id)) else character()
  if (!length(edition_id) || any(is.na(edition_id) | !nzchar(edition_id))) stop("Phase 14 fixture forecasts require one edition_id", call. = FALSE)
  if (length(edition_id) != 1L) stop("Phase 14 fixture forecasts require one edition_id per call", call. = FALSE)
  edition_id <- edition_id[[1L]]
  registry_row <- phase14_forecast_edition_row(edition_registry, edition_id)
  lifecycle <- if (!is.null(edition_lifecycle_state)) as.character(edition_lifecycle_state[[1L]]) else if (!is.null(registry_row)) phase14_forecast_text(registry_row$lifecycle_state[[1L]], "scheduled") else "scheduled"
  if (identical(lifecycle, "pre_draw")) return(phase14_forecast_empty_result("pre_draw"))
  eligibility <- vapply(seq_len(nrow(canonical_matches)), phase14_forecast_eligibility, character(1), matches = canonical_matches, edition_id = edition_id)
  eligible_rows <- which(eligibility == "eligible")
  if (!length(eligible_rows)) {
    # Keep one auditable status row per supplied fixture, without fabricating a
    # score grid or probability row.
    resolved_release <- resolved_release %||% phase14_resolve_approved_release(
      selector_path %||% file.path(trusted_release_root, "approved_release.csv"), trusted_release_root
    )
    adapted_status <- lapply(seq_len(nrow(canonical_matches)), function(row) {
      fallback <- data.frame(
        edition_id = edition_id,
        match_id = phase14_forecast_row_value(canonical_matches, row, c("match_id", "fixture_id"), paste0("invalid-", row)),
        fixture_id = phase14_forecast_row_value(canonical_matches, row, c("fixture_id", "match_id"), paste0("invalid-", row)),
        home_team_id = phase14_forecast_row_value(canonical_matches, row, c("home_team_id"), NA_character_),
        away_team_id = phase14_forecast_row_value(canonical_matches, row, c("away_team_id"), NA_character_),
        date = as.Date(NA), home_team_canonical = NA_character_, away_team_canonical = NA_character_,
        home_score = NA_real_, away_score = NA_real_, venue = phase14_forecast_row_value(canonical_matches, row, c("venue"), "home"),
        kickoff_utc = phase14_forecast_row_value(canonical_matches, row, c("kickoff_utc", "scheduled_at_utc"), NA_character_),
        feature_cutoff_utc = phase14_forecast_row_value(canonical_matches, row, c("feature_cutoff_utc"), NA_character_),
        kickoff_confirmed = FALSE, stringsAsFactors = FALSE
      )
      fallback
    })
    features <- list(
      feature_evidence_status = "unavailable", xg_evidence_status = "inactive_optional_unavailable",
      latest_evidence_at_utc = NA_character_, model_form = data.frame(stringsAsFactors = FALSE),
      feature_evidence_source = character()
    )
    status <- do.call(rbind, lapply(seq_along(adapted_status), function(index) {
      phase14_forecast_status_for_row(
        adapted_status[[index]], features, resolved_release,
        "suppressed", eligibility[[index]], phase14_forecast_team_registry(team_registry), edition_registry
      )
    }))
    return(list(forecasts = data.frame(stringsAsFactors = FALSE), score_distributions = data.frame(stringsAsFactors = FALSE), fixture_status = status))
  }
  adapted <- phase14_adapt_matches_for_forecast(canonical_matches[eligible_rows, , drop = FALSE], team_registry)
  if (is.null(elo_ratings)) {
    path <- file.path(phase14_forecast_project_root(), "data/processed/elo_ratings.csv")
    elo_ratings <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  }
  if (is.null(resolved_release)) {
    resolved_release <- phase14_resolve_approved_release(
      selector_path %||% file.path(trusted_release_root, "approved_release.csv"), trusted_release_root
    )
  }
  feature_result <- phase14_build_release_features(
    adapted_matches = adapted,
    resolved_release = resolved_release,
    elo_ratings = elo_ratings,
    team_registry = team_registry,
    national_team_xg_registry = national_team_xg_registry,
    national_team_xg_history = national_team_xg_history,
    model_manifest = model_manifest,
    model_manifest_path = model_manifest_path,
    rolling_form = rolling_form
  )
  team_registry <- phase14_forecast_team_registry(team_registry)
  if (length(feature_result$missing_active_predictors)) {
    status <- do.call(rbind, lapply(seq_len(nrow(adapted)), function(row) {
      phase14_forecast_status_for_row(
        adapted[row, , drop = FALSE], feature_result, resolved_release,
        "suppressed", "feature_evidence_unavailable", team_registry, edition_registry
      )
    }))
    return(list(forecasts = data.frame(stringsAsFactors = FALSE), score_distributions = data.frame(stringsAsFactors = FALSE), fixture_status = status, features = feature_result))
  }
  fit <- resolved_release$model
  if (!inherits(fit, "benchmark_baseline_fit")) stop("Phase 14 approved release model is not a registered baseline fit", call. = FALSE)
  prediction_input <- feature_result$feature_table
  prediction_input$fixture_id <- as.character(adapted$fixture_id)
  prediction_input$venue_role <- as.character(adapted$venue)
  prediction <- predict_registered_baseline(fit, prediction_input, support_max = 40L)
  validate_benchmark_score_distributions(
    prediction$distributions,
    expected_distribution_ids = unique(as.character(prediction$distributions$score_distribution_id)),
    support_max = 40L
  )
  forecast_rows <- lapply(seq_len(nrow(adapted)), function(row) {
    fixture_id <- as.character(adapted$fixture_id[[row]])
    grid <- prediction$distributions[as.character(prediction$distributions$score_distribution_id) == paste0(fixture_id, "__score"), , drop = FALSE]
    phase14_forecast_available_row(
      adapted[row, , drop = FALSE], feature_result, resolved_release,
      prediction$predictions[prediction$predictions$fixture_id == fixture_id, , drop = FALSE],
      grid, edition_registry, team_registry
    )
  })
  forecasts <- do.call(rbind, forecast_rows)
  status <- forecasts[, intersect(c(
    "edition_id", "fixture_id", "match_id", "kickoff_utc", "feature_cutoff_utc",
    "forecast_status", "suppression_reason", "feature_evidence_status", "release_calibration_status",
    "model_release_id", "release_manifest_sha256", "model_id", "model_sha256", "calibrator_id",
    "calibrator_sha256", "model_data_cutoff", "primary_probability_view", "feature_evidence_source",
    "latest_evidence_at_utc"
  ), names(forecasts)), drop = FALSE]
  list(
    forecasts = forecasts,
    score_distributions = prediction$distributions,
    fixture_status = status,
    features = feature_result
  )
}
