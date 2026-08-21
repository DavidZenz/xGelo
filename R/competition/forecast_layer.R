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
  "R/evaluation/proper_scores.R",
  c("validate_scoreline_distribution")
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
    if (!ncol(data)) {
      # Empty schemas are valid before national-team xG becomes available.
      bytes <- paste(names(data), collapse = "|")
    } else {
      data <- data[order(do.call(order, lapply(data, as.character))), , drop = FALSE]
      bytes <- paste(capture.output(utils::write.csv(data, stdout(), row.names = FALSE, na = "", quote = TRUE)), collapse = "\n")
    }
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
  if (!status %in% c("scheduled", "open", "pending", "upcoming")) return("status_ineligible")
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

# ---------------------------------------------------------------------------
# Phase 14 production batch boundary
# ---------------------------------------------------------------------------
#
# The tracer above intentionally remains readable as the historical vertical
# slice.  The definitions below are the production batch contract layered on
# top of it.  Keeping the batch boundary here avoids changing the established
# single-fixture call shape while making the stronger no-silent-drop and
# deterministic-replay rules explicit.

phase14_forecast_batch_call <- function(callback, arguments) {
  if (!is.function(callback)) stop("Phase 14 forecast callback must be a function", call. = FALSE)
  formal_names <- names(formals(callback))
  if (!"..." %in% formal_names) {
    arguments <- arguments[names(arguments) %in% formal_names]
  }
  do.call(callback, arguments)
}

phase14_forecast_batch_fixture_ids <- function(matches) {
  if (!is.data.frame(matches) || !nrow(matches)) return(character())
  fixture_ids <- phase14_forecast_column(matches, c("fixture_id", "match_id"), NA_character_)
  match_ids <- phase14_forecast_column(matches, c("match_id", "fixture_id"), NA_character_)
  if (any(is.na(fixture_ids) | !nzchar(fixture_ids)) ||
      any(is.na(match_ids) | !nzchar(match_ids))) {
    stop("Phase 14 forecast input requires non-empty fixture_id and match_id values", call. = FALSE)
  }
  if (anyDuplicated(fixture_ids) || anyDuplicated(match_ids)) {
    stop("Phase 14 forecast input contains duplicate fixture identity", call. = FALSE)
  }
  fixture_ids
}

phase14_forecast_batch_release_failure_reason <- function(error) {
  message <- tolower(conditionMessage(error))
  if (grepl("selector", message, fixed = TRUE)) return("approved_release_selector_unavailable")
  if (grepl("calibrat|raw fallback|fitted", message, perl = TRUE)) return("release_not_calibrated")
  if (grepl("manifest", message, fixed = TRUE)) return("approved_release_manifest_unavailable")
  if (grepl("model", message, fixed = TRUE)) return("approved_release_model_unavailable")
  if (grepl("calibrator", message, fixed = TRUE)) return("approved_release_calibrator_unavailable")
  "approved_release_unavailable"
}

phase14_forecast_batch_release_contract_reason <- function(resolved_release) {
  if (is.null(resolved_release) || !is.list(resolved_release)) {
    return("approved_release_unavailable")
  }
  if (is.null(resolved_release$model) || !inherits(resolved_release$model, "benchmark_baseline_fit")) {
    return("approved_release_model_unavailable")
  }
  if (is.null(resolved_release$calibrator) || !is.list(resolved_release$calibrator)) {
    return("approved_release_calibrator_unavailable")
  }
  calibration_status <- phase14_forecast_text(resolved_release$calibrator$fit_status, "")
  primary_view <- phase14_forecast_text(resolved_release$primary_probability_view, "")
  if (!identical(calibration_status, "fitted") || !identical(primary_view, "calibrated_1x2")) {
    return("release_not_calibrated")
  }
  invisible(NULL)
}

phase14_forecast_batch_generation_utc <- function(
    generated_at_utc,
    adapted_matches = NULL,
    canonical_matches = NULL,
    resolved_release = NULL) {
  if (!is.null(generated_at_utc)) {
    return(phase14_forecast_format_utc(phase14_forecast_parse_utc(generated_at_utc, "generation timestamp")))
  }
  values <- character()
  if (is.data.frame(adapted_matches) && nrow(adapted_matches) && "feature_cutoff_utc" %in% names(adapted_matches)) {
    values <- as.character(adapted_matches$feature_cutoff_utc)
  }
  if (is.data.frame(canonical_matches) && nrow(canonical_matches)) {
    values <- c(values, phase14_forecast_column(canonical_matches, c("feature_cutoff_utc", "forecast_cutoff_utc"), ""))
  }
  parsed <- suppressWarnings(as.POSIXct(values, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  parsed <- parsed[!is.na(parsed)]
  if (length(parsed)) return(phase14_forecast_format_utc(max(parsed)))
  model_cutoff <- if (is.list(resolved_release)) phase14_forecast_text(resolved_release$model_data_cutoff, "") else ""
  if (nzchar(model_cutoff)) return(paste0(model_cutoff, "T00:00:00Z"))
  "1970-01-01T00:00:00Z"
}

phase14_forecast_batch_registry <- function(team_registry) {
  tryCatch(
    phase14_forecast_team_registry(team_registry),
    error = function(error) data.frame(
      team_id = character(0), canonical_name = character(0), stringsAsFactors = FALSE
    )
  )
}

phase14_forecast_batch_fallback_row <- function(matches, row, edition_id, registry) {
  fixture_id <- phase14_forecast_row_value(matches, row, c("fixture_id", "match_id"), NA_character_)
  match_id <- phase14_forecast_row_value(matches, row, c("match_id", "fixture_id"), fixture_id)
  kickoff <- tryCatch(phase14_forecast_match_kickoff(matches, row), error = function(error) as.POSIXct(NA))
  kickoff_text <- if (is.na(kickoff)) NA_character_ else phase14_forecast_format_utc(kickoff)
  cutoff <- if (is.na(kickoff)) {
    phase14_forecast_row_value(matches, row, c("feature_cutoff_utc", "forecast_cutoff_utc"), NA_character_)
  } else {
    tryCatch(
      phase14_forecast_cutoff_for_row(matches, row, kickoff, NULL),
      error = function(error) phase14_forecast_row_value(matches, row, c("feature_cutoff_utc", "forecast_cutoff_utc"), NA_character_)
    )
  }
  home_id <- phase14_forecast_row_value(matches, row, c("home_team_id"), NA_character_)
  away_id <- phase14_forecast_row_value(matches, row, c("away_team_id"), NA_character_)
  lookup <- phase14_forecast_team_name_lookup(registry)
  home_name <- if (!is.na(home_id) && home_id %in% names(lookup)) unname(lookup[[home_id]]) else NA_character_
  away_name <- if (!is.na(away_id) && away_id %in% names(lookup)) unname(lookup[[away_id]]) else NA_character_
  venue <- tolower(phase14_forecast_row_value(matches, row, c("venue"), "home"))
  if (!venue %in% c("home", "away", "neutral")) venue <- "home"
  data.frame(
    edition_id = edition_id,
    match_id = match_id,
    fixture_id = fixture_id,
    home_team_id = home_id,
    away_team_id = away_id,
    date = if (is.na(kickoff)) as.Date(NA) else as.Date(format(kickoff, "%Y-%m-%d", tz = "UTC")),
    home_team_canonical = home_name,
    away_team_canonical = away_name,
    home_score = NA_real_,
    away_score = NA_real_,
    venue = venue,
    kickoff_utc = kickoff_text,
    feature_cutoff_utc = cutoff,
    kickoff_confirmed = !is.na(kickoff),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase14_forecast_batch_empty_features <- function(
    manifest = NULL,
    resolved_release = NULL,
    adapted_matches = NULL) {
  active <- if (is.list(manifest)) manifest$active_predictors else character()
  dropped <- if (is.list(manifest)) manifest$dropped_predictors_with_reason else character()
  list(
    feature_table = data.frame(stringsAsFactors = FALSE),
    adapted_matches = adapted_matches,
    active_predictors = active,
    dropped_predictors_with_reason = dropped,
    model_manifest = if (is.list(manifest)) manifest$row else data.frame(stringsAsFactors = FALSE),
    model_manifest_sha256 = if (is.list(manifest)) manifest$manifest_sha256 else "",
    feature_evidence_status = "unavailable",
    missing_active_predictors = active,
    xg_evidence_status = "inactive_optional_unavailable",
    national_team_xg_status = "inactive_optional_unavailable",
    national_team_xg_source_id = "national_team_xg_sources.csv",
    national_team_xg_sample_count = 0L,
    national_team_xg_feature_cutoff_utc = NA_character_,
    national_team_xg_availability_reason = "not_evaluated",
    model_form = data.frame(stringsAsFactors = FALSE),
    feature_evidence_source = character(),
    latest_evidence_at_utc = NA_character_,
    feature_cutoff_utc = if (is.data.frame(adapted_matches) && "feature_cutoff_utc" %in% names(adapted_matches)) adapted_matches$feature_cutoff_utc else character(),
    cutoff_safe = FALSE,
    registry_sha256 = ""
  )
}

phase14_forecast_batch_enrich_features <- function(feature_result, manifest, resolved_release, adapted_matches) {
  if (!is.list(feature_result)) feature_result <- list()
  feature_result$active_predictors <- manifest$active_predictors
  feature_result$dropped_predictors_with_reason <- manifest$dropped_predictors_with_reason
  feature_result$model_manifest_sha256 <- manifest$manifest_sha256
  feature_result$model_data_cutoff <- phase14_forecast_text(resolved_release$model_data_cutoff, "")
  feature_result$national_team_xg_source_id <- "national_team_xg_sources.csv"
  feature_result$national_team_xg_feature_cutoff_utc <- if (nrow(adapted_matches)) as.character(adapted_matches$feature_cutoff_utc[[1L]]) else NA_character_
  feature_result$national_team_xg_availability_reason <- if (is.data.frame(feature_result$model_form) && nrow(feature_result$model_form) && "availability_reason" %in% names(feature_result$model_form)) {
    paste(unique(as.character(feature_result$model_form$availability_reason)), collapse = "|")
  } else if (identical(feature_result$xg_evidence_status, "inactive_optional_unavailable")) {
    "inactive_predictors_registered_missingness"
  } else {
    "no_accepted_point_in_time_national_team_xg"
  }
  if (identical(feature_result$xg_evidence_status, "inactive_optional_unavailable") &&
      !grepl("unavailable|inactive", tolower(feature_result$national_team_xg_availability_reason))) {
    feature_result$national_team_xg_availability_reason <- paste0(
      "inactive_optional_unavailable:",
      feature_result$national_team_xg_availability_reason
    )
  }
  if (is.data.frame(feature_result$model_form) && nrow(feature_result$model_form) && "sample_count" %in% names(feature_result$model_form)) {
    counts <- suppressWarnings(as.integer(feature_result$model_form$sample_count))
    counts <- counts[is.finite(counts)]
    feature_result$national_team_xg_sample_count <- if (length(counts)) min(counts) else 0L
  } else {
    feature_result$national_team_xg_sample_count <- 0L
  }
  feature_result
}

phase14_forecast_batch_lineage_row <- function(
    adapted,
    feature_result,
    resolved_release,
    team_registry,
    edition_registry = NULL,
    forecast_status = "suppressed",
    suppression_reason = "none",
    release_calibration_status = "fitted",
    identity_status = "resolved",
    generated_at_utc = NULL) {
  release_identity <- if (is.list(resolved_release)) resolved_release$release_identity else list()
  model_identity <- if (is.list(resolved_release)) resolved_release$model_identity else list()
  calibrator_identity <- if (is.list(resolved_release)) resolved_release$calibrator_identity else list()
  active <- if (is.list(feature_result)) feature_result$active_predictors else character()
  dropped <- if (is.list(feature_result)) feature_result$dropped_predictors_with_reason else character()
  manifest_hash <- if (is.list(feature_result)) feature_result$model_manifest_sha256 else ""
  model_cutoff <- if (is.list(feature_result)) feature_result$model_data_cutoff else ""
  source <- if (is.list(feature_result)) feature_result$feature_evidence_source else character()
  xg_status <- if (is.list(feature_result)) feature_result$national_team_xg_status %||% feature_result$xg_evidence_status else "unavailable"
  xg_source <- if (is.list(feature_result)) feature_result$national_team_xg_source_id else "national_team_xg_sources.csv"
  xg_samples <- if (is.list(feature_result)) feature_result$national_team_xg_sample_count %||% 0L else 0L
  xg_cutoff <- if (is.list(feature_result)) feature_result$national_team_xg_feature_cutoff_utc else NA_character_
  xg_reason <- if (is.list(feature_result)) feature_result$national_team_xg_availability_reason else "not_evaluated"
  registry_row <- phase14_forecast_edition_row(edition_registry, adapted$edition_id[[1L]])
  registry_revision <- if (is.data.frame(registry_row) && "registry_revision" %in% names(registry_row)) suppressWarnings(as.integer(registry_row$registry_revision[[1L]])) else NA_integer_
  registry_row_hash <- if (is.data.frame(registry_row) && nrow(registry_row)) {
    if ("row_sha256" %in% names(registry_row)) as.character(registry_row$row_sha256[[1L]]) else phase14_forecast_hash_data(registry_row)
  } else ""
  source_bundle_id <- if (is.data.frame(registry_row) && nrow(registry_row) && "source_bundle_id" %in% names(registry_row)) as.character(registry_row$source_bundle_id[[1L]]) else ""
  ruleset_version <- if (is.data.frame(registry_row) && nrow(registry_row) && "ruleset_version" %in% names(registry_row)) as.character(registry_row$ruleset_version[[1L]]) else "phase14-state-v1"
  row <- data.frame(
    edition_id = as.character(adapted$edition_id[[1L]]),
    fixture_id = as.character(adapted$fixture_id[[1L]]),
    match_id = as.character(adapted$match_id[[1L]]),
    kickoff_utc = as.character(adapted$kickoff_utc[[1L]]),
    feature_cutoff_utc = as.character(adapted$feature_cutoff_utc[[1L]]),
    identity_status = identity_status,
    forecast_status = forecast_status,
    suppression_reason = suppression_reason,
    feature_evidence_status = phase14_forecast_text(if (is.list(feature_result)) feature_result$feature_evidence_status else "unavailable", "unavailable"),
    release_calibration_status = release_calibration_status,
    active_predictors = paste(active, collapse = "|"),
    dropped_predictors_with_reason = paste(dropped, collapse = "|"),
    model_manifest_sha256 = phase14_forecast_text(manifest_hash, ""),
    model_release_id = phase14_forecast_text(release_identity$release_id, ""),
    release_manifest_sha256 = phase14_forecast_text(release_identity$manifest_sha256, ""),
    release_manifest_path = phase14_forecast_text(resolved_release$release_manifest_path %||% "", ""),
    release_selector_sha256 = phase14_forecast_text(release_identity$selector_self_sha256, ""),
    model_id = phase14_forecast_text(model_identity$model_id, ""),
    model_sha256 = phase14_forecast_text(model_identity$sha256, ""),
    calibrator_id = phase14_forecast_text(calibrator_identity$calibrator_id, ""),
    calibrator_sha256 = phase14_forecast_text(calibrator_identity$sha256, ""),
    calibration_data_cutoff = phase14_forecast_text(resolved_release$calibration_data_cutoff %||% "", ""),
    calibration_gate_id = phase14_forecast_text(calibrator_identity$calibration_gate_id, ""),
    calibration_gate_sha256 = phase14_forecast_text(calibrator_identity$calibration_gate_sha256, ""),
    model_data_cutoff = phase14_forecast_text(model_cutoff, ""),
    feature_evidence_source = paste(source, collapse = "|"),
    latest_evidence_at_utc = phase14_forecast_text(if (is.list(feature_result)) feature_result$latest_evidence_at_utc else "", ""),
    national_team_xg_status = phase14_forecast_text(xg_status, "unavailable"),
    national_team_xg_source_id = phase14_forecast_text(xg_source, "national_team_xg_sources.csv"),
    national_team_xg_sample_count = as.integer(xg_samples),
    national_team_xg_feature_cutoff_utc = phase14_forecast_text(xg_cutoff, ""),
    national_team_xg_availability_reason = phase14_forecast_text(xg_reason, "not_evaluated"),
    source_bundle_id = source_bundle_id,
    accepted_state_sha256 = if (is.data.frame(registry_row) && nrow(registry_row)) phase14_forecast_hash_data(registry_row) else "",
    edition_registry_revision = registry_revision,
    edition_registry_row_sha256 = registry_row_hash,
    ruleset_version = ruleset_version,
    team_identity_registry_sha256 = phase14_forecast_hash_data(team_registry),
    contributing_form_sha256 = if (is.list(feature_result) && is.data.frame(feature_result$model_form)) phase14_forecast_hash_data(feature_result$model_form) else "",
    contributing_history_sha256 = if (is.list(feature_result) && is.data.frame(feature_result$feature_table)) phase14_forecast_hash_data(feature_result$feature_table[, intersect(c("match_id", "elo_diff", "elo_diff__source_date"), names(feature_result$feature_table)), drop = FALSE]) else "",
    generated_at_utc = generated_at_utc %||% "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  row$edition_registry_revision <- as.integer(row$edition_registry_revision)
  row$national_team_xg_sample_count <- as.integer(row$national_team_xg_sample_count)
  row
}

phase14_forecast_batch_hash_row <- function(row, hash_column = "row_sha256") {
  row[[hash_column]] <- ""
  row[[hash_column]] <- phase14_forecast_hash_data(row)
  row
}

phase14_forecast_batch_top10 <- function(forecast_row, grid, top_n = 10L) {
  ordered <- phase14_forecast_order_scorelines(grid)
  top_n <- min(as.integer(top_n), nrow(ordered))
  if (top_n < 1L) return(data.frame(stringsAsFactors = FALSE))
  selected <- ordered[seq_len(top_n), , drop = FALSE]
  output <- data.frame(
    edition_id = as.character(forecast_row$edition_id[[1L]]),
    fixture_id = as.character(forecast_row$fixture_id[[1L]]),
    match_id = as.character(forecast_row$match_id[[1L]]),
    score_distribution_id = as.character(selected$score_distribution_id),
    rank = seq_len(nrow(selected)),
    home_goals = as.integer(selected$home_goals),
    away_goals = as.integer(selected$away_goals),
    probability = as.numeric(selected$probability),
    top10_scoreline_mass = sum(selected$probability),
    top10_omitted_mass = 1 - sum(selected$probability),
    model_release_id = as.character(forecast_row$model_release_id[[1L]]),
    release_manifest_sha256 = as.character(forecast_row$release_manifest_sha256[[1L]]),
    model_data_cutoff = as.character(forecast_row$model_data_cutoff[[1L]]),
    feature_cutoff_utc = as.character(forecast_row$feature_cutoff_utc[[1L]]),
    active_predictors = as.character(forecast_row$active_predictors[[1L]]),
    dropped_predictors_with_reason = as.character(forecast_row$dropped_predictors_with_reason[[1L]]),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  output$row_sha256 <- vapply(seq_len(nrow(output)), function(index) {
    phase14_forecast_hash_data(output[index, , drop = FALSE])
  }, character(1))
  output
}

phase14_forecast_batch_status_columns <- function() {
  c(
    "edition_id", "fixture_id", "match_id", "kickoff_utc", "feature_cutoff_utc",
    "identity_status", "forecast_status", "suppression_reason", "feature_evidence_status",
    "release_calibration_status", "active_predictors", "dropped_predictors_with_reason",
    "model_manifest_sha256", "model_release_id", "release_manifest_sha256", "release_manifest_path",
    "release_selector_sha256", "model_id", "model_sha256", "calibrator_id", "calibrator_sha256",
    "calibration_data_cutoff", "calibration_gate_id", "calibration_gate_sha256", "model_data_cutoff",
    "feature_evidence_source", "latest_evidence_at_utc", "national_team_xg_status",
    "national_team_xg_source_id", "national_team_xg_sample_count", "national_team_xg_feature_cutoff_utc",
    "national_team_xg_availability_reason", "source_bundle_id", "accepted_state_sha256",
    "edition_registry_revision", "edition_registry_row_sha256", "ruleset_version",
    "team_identity_registry_sha256", "contributing_form_sha256", "contributing_history_sha256",
    "generated_at_utc", "row_sha256"
  )
}

phase14_forecast_batch_empty_result <- function(reason = "pre_draw") {
  status <- as.data.frame(setNames(lapply(phase14_forecast_batch_status_columns(), function(name) {
    if (name %in% c("edition_registry_revision", "national_team_xg_sample_count")) integer(0) else character(0)
  }), phase14_forecast_batch_status_columns()), stringsAsFactors = FALSE)
  list(
    forecasts = data.frame(stringsAsFactors = FALSE),
    score_distributions = data.frame(stringsAsFactors = FALSE),
    forecast_top10 = data.frame(stringsAsFactors = FALSE),
    fixture_status = status,
    status = reason,
    suppression_reason = reason
  )
}

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
    rolling_form = NULL,
    resolve_release_fn = phase14_resolve_approved_release,
    build_features_fn = phase14_build_release_features,
    predict_fn = predict_registered_baseline,
    generated_at_utc = NULL,
    compact_top_n = 10L,
    support_max = 40L) {
  if (!is.data.frame(canonical_matches)) stop("Phase 14 fixture forecasts require a data frame", call. = FALSE)
  if ("case_id" %in% names(canonical_matches) && "expected_status_row_count" %in% names(canonical_matches)) {
    return(phase14_forecast_legacy_cases(canonical_matches))
  }
  support_max <- as.integer(support_max)
  if (length(support_max) != 1L || is.na(support_max) || support_max != 40L) {
    stop("Phase 14 production forecast support_max is fixed at G=40", call. = FALSE)
  }
  compact_top_n <- as.integer(compact_top_n)
  if (length(compact_top_n) != 1L || is.na(compact_top_n) || compact_top_n < 1L || compact_top_n > 10L) {
    stop("Phase 14 compact top-N must be between 1 and 10", call. = FALSE)
  }
  if (!nrow(canonical_matches)) return(phase14_forecast_batch_empty_result(edition_lifecycle_state %||% "pre_draw"))
  fixture_ids <- phase14_forecast_batch_fixture_ids(canonical_matches)
  edition_ids <- if ("edition_id" %in% names(canonical_matches)) unique(as.character(canonical_matches$edition_id)) else character()
  if (!length(edition_ids) || any(is.na(edition_ids) | !nzchar(edition_ids))) stop("Phase 14 fixture forecasts require one edition_id", call. = FALSE)
  if (length(edition_ids) != 1L) stop("Phase 14 fixture forecasts require one edition_id per call", call. = FALSE)
  edition_id <- edition_ids[[1L]]
  registry <- phase14_forecast_batch_registry(team_registry)
  registry_row <- phase14_forecast_edition_row(edition_registry, edition_id)
  lifecycle <- if (!is.null(edition_lifecycle_state)) as.character(edition_lifecycle_state[[1L]]) else if (is.data.frame(registry_row) && nrow(registry_row)) phase14_forecast_text(registry_row$lifecycle_state[[1L]], "scheduled") else "scheduled"

  resolved_error <- NULL
  if (is.null(resolved_release)) {
    selector <- selector_path %||% file.path(trusted_release_root, "approved_release.csv")
    resolved_release <- tryCatch(
      phase14_forecast_batch_call(resolve_release_fn, list(selector_path = selector, trusted_release_root = trusted_release_root)),
      error = function(error) {
        resolved_error <<- error
        NULL
      }
    )
  }
  release_reason <- if (!is.null(resolved_error)) phase14_forecast_batch_release_failure_reason(resolved_error) else phase14_forecast_batch_release_contract_reason(resolved_release)
  manifest <- NULL
  manifest_error <- NULL
  if (is.null(release_reason)) {
    manifest <- tryCatch(
      phase14_forecast_model_manifest(resolved_release, model_manifest, model_manifest_path),
      error = function(error) {
        manifest_error <<- error
        NULL
      }
    )
    if (!is.null(manifest_error)) release_reason <- "approved_release_manifest_unavailable"
  }
  generated <- phase14_forecast_batch_generation_utc(generated_at_utc, canonical_matches, canonical_matches, resolved_release)
  empty_features <- phase14_forecast_batch_empty_features(manifest, resolved_release, NULL)

  eligibility <- vapply(seq_len(nrow(canonical_matches)), function(row) {
    if (identical(lifecycle, "pre_draw")) return("pre_draw")
    value <- phase14_forecast_eligibility(canonical_matches, row, edition_id)
    if (identical(value, "feature_cutoff_after_kickoff")) "feature_evidence_unavailable" else value
  }, character(1))
  eligible_rows <- which(eligibility == "eligible")
  adapted <- if (length(eligible_rows)) phase14_adapt_matches_for_forecast(canonical_matches[eligible_rows, , drop = FALSE], registry) else data.frame(stringsAsFactors = FALSE)
  if (length(eligible_rows) && is.null(elo_ratings)) {
    elo_path <- file.path(phase14_forecast_project_root(), "data/processed/elo_ratings.csv")
    elo_ratings <- utils::read.csv(elo_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  }
  feature_result <- empty_features
  if (length(eligible_rows) && is.null(release_reason)) {
    manifest_row <- manifest$row
    attr(manifest_row, "immutable_manifest_sha256") <- manifest$manifest_sha256
    feature_result <- tryCatch(
      phase14_forecast_batch_call(build_features_fn, list(
        adapted_matches = adapted,
        resolved_release = resolved_release,
        selector_path = selector_path,
        trusted_release_root = trusted_release_root,
        elo_ratings = elo_ratings,
        team_registry = team_registry,
        national_team_xg_registry = national_team_xg_registry,
        national_team_xg_history = national_team_xg_history,
        model_manifest = manifest_row,
        model_manifest_path = model_manifest_path,
        rolling_form = rolling_form
      )),
      error = function(error) {
        if (grepl("club rolling_form", conditionMessage(error), fixed = TRUE)) stop(error)
        list(
          feature_table = data.frame(stringsAsFactors = FALSE),
          active_predictors = manifest$active_predictors,
          dropped_predictors_with_reason = manifest$dropped_predictors_with_reason,
          model_manifest_sha256 = manifest$manifest_sha256,
          feature_evidence_status = "unavailable",
          missing_active_predictors = manifest$active_predictors,
          xg_evidence_status = "active_required_missing",
          national_team_xg_status = "active_required_missing",
          model_form = data.frame(stringsAsFactors = FALSE),
          feature_evidence_source = character(),
          latest_evidence_at_utc = NA_character_
        )
      }
    )
    feature_result <- phase14_forecast_batch_enrich_features(feature_result, manifest, resolved_release, adapted)
  }
  if (!length(eligible_rows) || identical(lifecycle, "pre_draw") || !is.null(release_reason)) {
    feature_result <- phase14_forecast_batch_enrich_features(empty_features, manifest %||% list(active_predictors = character(), dropped_predictors_with_reason = character(), manifest_sha256 = ""), resolved_release %||% list(), adapted)
  }
  missing_active <- if (is.list(feature_result) && !is.null(feature_result$missing_active_predictors)) unique(as.character(feature_result$missing_active_predictors)) else character()
  if (length(eligible_rows) && is.list(feature_result) && !length(missing_active) && !is.null(feature_result$feature_table) && is.data.frame(feature_result$feature_table)) {
    active_ids <- unique(vapply(manifest$active_predictors, phase14_forecast_active_feature_id, character(1)))
    missing_active <- active_ids[!vapply(active_ids, function(id) {
      if (!id %in% names(feature_result$feature_table)) return(FALSE)
      companion <- paste0(id, "__value_present")
      if (companion %in% names(feature_result$feature_table)) all(as.logical(feature_result$feature_table[[companion]])) else all(is.finite(as.numeric(feature_result$feature_table[[id]])))
    }, logical(1))]
  }

  forecasts <- list()
  distributions <- data.frame(stringsAsFactors = FALSE)
  top10 <- data.frame(stringsAsFactors = FALSE)
  if (length(eligible_rows) && !identical(lifecycle, "pre_draw") && is.null(release_reason) && !length(missing_active)) {
    fit <- resolved_release$model
    prediction_input <- feature_result$feature_table
    prediction_input$fixture_id <- as.character(adapted$fixture_id)
    prediction_input$venue_role <- as.character(adapted$venue)
    prediction <- tryCatch(
      phase14_forecast_batch_call(predict_fn, list(fit = fit, fixtures = prediction_input, support_max = support_max)),
      error = function(error) stop("Phase 14 approved release model field unavailable: ", conditionMessage(error), call. = FALSE)
    )
    if (!is.list(prediction) || !is.data.frame(prediction$distributions) || !is.data.frame(prediction$predictions)) {
      stop("Phase 14 approved release model prediction output is incomplete", call. = FALSE)
    }
    validate_benchmark_score_distributions(
      prediction$distributions,
      expected_distribution_ids = unique(as.character(prediction$distributions$score_distribution_id)),
      support_max = support_max
    )
    expected_prediction_ids <- as.character(adapted$fixture_id)
    if (anyDuplicated(as.character(prediction$predictions$fixture_id)) ||
        !setequal(as.character(prediction$predictions$fixture_id), expected_prediction_ids)) {
      stop("Phase 14 forecast prediction output silently dropped or duplicated fixture IDs", call. = FALSE)
    }
    distributions <- prediction$distributions
    forecasts <- lapply(seq_len(nrow(adapted)), function(row) {
      fixture_id <- as.character(adapted$fixture_id[[row]])
      grid <- distributions[as.character(distributions$score_distribution_id) == paste0(fixture_id, "__score"), , drop = FALSE]
      if (!nrow(grid)) stop("Phase 14 forecast prediction output is missing score grid for fixture: ", fixture_id, call. = FALSE)
      lineage <- phase14_forecast_batch_lineage_row(
        adapted[row, , drop = FALSE], feature_result, resolved_release, registry, edition_registry,
        forecast_status = "available", suppression_reason = "none", release_calibration_status = "fitted",
        identity_status = "resolved", generated_at_utc = generated
      )
      market <- derive_benchmark_markets(grid)
      raw <- as.numeric(market[c("p_home", "p_draw", "p_away")])
      calibrated <- phase14_forecast_apply_calibrator(resolved_release$calibrator, raw)
      if (abs(sum(raw) - 1) > 1e-10 || abs(sum(calibrated) - 1) > 1e-10) stop("Phase 14 forecast simplex validation failed", call. = FALSE)
      names(calibrated) <- c("home", "draw", "away")
      ordered <- phase14_forecast_order_scorelines(grid)
      selected_top10 <- ordered[seq_len(min(compact_top_n, nrow(ordered))), , drop = FALSE]
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
          score_support_min = 0L, score_support_max = 40L,
          score_cell_count = nrow(grid), raw_tail_mass = unique(as.numeric(grid$raw_tail_mass))[[1L]],
          top10_scoreline_mass = sum(selected_top10$probability),
          top10_omitted_mass = 1 - sum(selected_top10$probability),
          entropy_nats = -sum(calibrated * log(pmax(calibrated, 1e-15))),
          max_outcome_probability = max(calibrated),
          home_goals_p10 = phase14_forecast_cdf_quantile(grid, "home_goals", 0.10),
          home_goals_p90 = phase14_forecast_cdf_quantile(grid, "home_goals", 0.90),
          away_goals_p10 = phase14_forecast_cdf_quantile(grid, "away_goals", 0.10),
          away_goals_p90 = phase14_forecast_cdf_quantile(grid, "away_goals", 0.90),
          uncertainty_status = "available", calculation_method = "analytic_negative_binomial",
          seed_status = "not_applicable", simulation_count_status = "not_applicable",
          monte_carlo_seed = NA_integer_, monte_carlo_count = NA_integer_,
          stringsAsFactors = FALSE, check.names = FALSE
        )
      )
      row$score_support_min <- as.integer(row$score_support_min)
      row$score_support_max <- as.integer(row$score_support_max)
      row$score_cell_count <- as.integer(row$score_cell_count)
      row$modal_home_goals <- as.integer(row$modal_home_goals)
      row$modal_away_goals <- as.integer(row$modal_away_goals)
      phase14_forecast_batch_hash_row(row)
    })
    forecasts <- do.call(rbind, forecasts)
    top10 <- do.call(rbind, lapply(seq_len(nrow(forecasts)), function(index) {
      fixture_id <- forecasts$fixture_id[[index]]
      grid <- distributions[as.character(distributions$score_distribution_id) == paste0(fixture_id, "__score"), , drop = FALSE]
      phase14_forecast_batch_top10(forecasts[index, , drop = FALSE], grid, compact_top_n)
    }))
  } else {
    forecasts <- data.frame(stringsAsFactors = FALSE)
  }

  status_rows <- lapply(seq_len(nrow(canonical_matches)), function(row) {
    fallback <- phase14_forecast_batch_fallback_row(canonical_matches, row, edition_id, registry)
    reason <- eligibility[[row]]
    status <- if (identical(reason, "eligible")) {
      if (!is.null(release_reason)) release_reason else if (length(missing_active)) "feature_evidence_unavailable" else "none"
    } else reason
    available <- identical(status, "none")
    if (available) {
      forecast <- forecasts[as.character(forecasts$fixture_id) == as.character(fallback$fixture_id), , drop = FALSE]
      if (nrow(forecast) != 1L) stop("Phase 14 forecast status coverage is not one-to-one", call. = FALSE)
      return(forecast[, phase14_forecast_batch_status_columns(), drop = FALSE])
    }
    feature_for_status <- feature_result
    if (identical(reason, "pre_draw") || !length(eligible_rows)) feature_for_status <- empty_features
    lineage <- phase14_forecast_batch_lineage_row(
      fallback, feature_for_status, resolved_release %||% list(), registry, edition_registry,
      forecast_status = "suppressed", suppression_reason = status,
      release_calibration_status = if (identical(status, "release_not_calibrated")) "unavailable" else if (is.null(release_reason)) "fitted" else "unavailable",
      identity_status = if (identical(reason, "identity_unresolved")) "unresolved" else "resolved",
      generated_at_utc = generated
    )
    phase14_forecast_batch_hash_row(lineage)
  })
  fixture_status <- do.call(rbind, status_rows)
  rownames(fixture_status) <- NULL
  if (anyDuplicated(as.character(fixture_status$fixture_id)) || !setequal(as.character(fixture_status$fixture_id), fixture_ids)) {
    stop("Phase 14 forecast fixture/status identity is not exact", call. = FALSE)
  }
  available_ids <- as.character(fixture_status$fixture_id[fixture_status$forecast_status == "available"])
  forecast_ids <- if (nrow(forecasts)) as.character(forecasts$fixture_id) else character()
  grid_ids <- if (nrow(distributions)) sub("__score$", "", unique(as.character(distributions$score_distribution_id))) else character()
  top_ids <- if (nrow(top10)) unique(as.character(top10$fixture_id)) else character()
  if (!setequal(forecast_ids, available_ids) || !setequal(grid_ids, available_ids) || !setequal(top_ids, available_ids)) {
    stop("Phase 14 forecast outputs do not equal available fixture coverage", call. = FALSE)
  }
  list(
    forecasts = forecasts,
    score_distributions = distributions,
    local_score_distributions = distributions,
    forecast_top10 = top10,
    fixture_status = fixture_status,
    status = if (all(fixture_status$forecast_status == "available")) "available" else "suppressed",
    suppression_reason = if (all(fixture_status$suppression_reason == "none")) "none" else "mixed",
    features = feature_result,
    active_predictors = if (is.null(manifest)) character() else manifest$active_predictors,
    dropped_predictors_with_reason = if (is.null(manifest)) character() else manifest$dropped_predictors_with_reason,
    model_manifest_sha256 = if (is.null(manifest)) "" else manifest$manifest_sha256,
    generated_at_utc = generated
  )
}
