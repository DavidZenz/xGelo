#' Forecast Feature Tables
#'
#' Builds match-grain feature tables for goal-model training and holdout
#' evaluation. All lookups are strictly pre-match or pre-cutoff.

#' Canonicalize external country/team names used by feature sources
#'
#' @param team Team names
#' @return Canonical xGelo team names
#' @export
canonicalise_feature_team_name <- function(team) {
  aliases <- c(
    "Korea, South" = "Korea Republic",
    "South Korea" = "Korea Republic",
    "Bosnia-Herzegovina" = "Bosnia and Herzegovina",
    "Bosnia Herzegovina" = "Bosnia and Herzegovina",
    "Curacao" = "Cura\u00e7ao",
    "Cura\u00e7ao" = "Cura\u00e7ao",
    "Cote d'Ivoire" = "Ivory Coast",
    "C\u00f4te d'Ivoire" = "Ivory Coast",
    "Cote d Ivoire" = "Ivory Coast",
    "Ivory Coast" = "Ivory Coast",
    "Türkiye" = "Turkey",
    "Turkiye" = "Turkey",
    "Czechia" = "Czech Republic",
    "Cape Verde Islands" = "Cape Verde",
    "Cabo Verde" = "Cape Verde",
    "Democratic Republic of the Congo" = "DR Congo",
    "Congo DR" = "DR Congo",
    "Congo, DR" = "DR Congo",
    "DR Congo" = "DR Congo"
  )
  out <- as.character(team)
  matched <- out %in% names(aliases)
  out[matched] <- unname(aliases[out[matched]])
  out
}

#' Audit team coverage across local forecast sources
#'
#' @param teams Canonical teams that must be covered
#' @param sources Named list of team-name vectors, one per source
#' @return Data frame with one row per team and one logical column per source
#' @export
audit_team_source_coverage <- function(teams, sources) {
  if (is.null(names(sources)) || any(names(sources) == "")) {
    stop("sources must be a named list")
  }
  out <- data.frame(team = as.character(teams), stringsAsFactors = FALSE)
  required <- canonicalise_feature_team_name(teams)
  for (source_name in names(sources)) {
    source_teams <- unique(canonicalise_feature_team_name(sources[[source_name]]))
    out[[source_name]] <- required %in% source_teams
  }
  out
}

#' Assert complete team coverage for selected sources
#'
#' @param coverage Coverage data frame from audit_team_source_coverage()
#' @param sources Source columns that must be complete
#' @return Invisibly returns coverage when all required sources are complete
#' @export
assert_team_source_coverage <- function(coverage, sources = setdiff(names(coverage), "team")) {
  missing_sources <- setdiff(sources, names(coverage))
  if (length(missing_sources) > 0) {
    stop(paste("Coverage missing source columns:", paste(missing_sources, collapse = ", ")))
  }
  gaps <- lapply(sources, function(source_name) coverage$team[!coverage[[source_name]]])
  names(gaps) <- sources
  gaps <- gaps[lengths(gaps) > 0]
  if (length(gaps) > 0) {
    details <- vapply(
      names(gaps),
      function(source_name) paste0(source_name, ": ", paste(gaps[[source_name]], collapse = ", ")),
      character(1)
    )
    stop(paste("Team coverage gaps detected:", paste(details, collapse = " | ")))
  }
  invisible(coverage)
}

#' Build a tolerant team key for cross-source feature joins
#'
#' @param team Team names
#' @return Lowercase ASCII-ish comparison keys
#' @export
feature_team_match_key <- function(team) {
  out <- canonicalise_feature_team_name(team)
  out <- iconv(out, from = "", to = "ASCII//TRANSLIT", sub = "")
  out <- tolower(out)
  gsub("[^a-z0-9]+", "", out)
}

#' Get latest team value before a lookup date
#' @keywords internal
latest_team_value_before <- function(data, team, lookup_date, value_col, team_col = "team", date_col = "date", default = NA_real_) {
  if (is.null(data) || nrow(data) == 0 || !all(c(team_col, date_col, value_col) %in% names(data))) return(default)
  data[[date_col]] <- as.Date(data[[date_col]])
  rows <- data[
    data[[team_col]] == team &
      !is.na(data[[date_col]]) &
      data[[date_col]] < as.Date(lookup_date) &
      !is.na(data[[value_col]]),
    ,
    drop = FALSE
  ]
  if (nrow(rows) == 0) return(default)
  rows <- rows[order(rows[[date_col]]), , drop = FALSE]
  value <- tail(rows[[value_col]], 1)
  ifelse(is.finite(value), value, default)
}

#' Create a fast evidence-returning latest-before lookup function
#'
#' The selected source row is retained even when its value is missing. This is
#' essential for distinguishing a missing value in a real source row from a
#' team with no prior source row at all.
#'
#' @param data Source data frame
#' @param value_col Numeric value column
#' @param team_col Team identifier column
#' @param date_col Source date column
#' @param default Registered fallback written when no finite value is available
#' @return Function of team and lookup date returning value and evidence fields
#' @export
make_latest_team_evidence_lookup <- function(
    data,
    value_col,
    team_col = "team",
    date_col = "date",
    default = NA_real_
) {
  missing_evidence <- function(reason, source_present = FALSE, source_date = as.Date(NA)) {
    list(
      value = as.numeric(default),
      source_present = isTRUE(source_present),
      source_date = as.Date(source_date),
      value_present = FALSE,
      imputed = TRUE,
      imputation_reason = reason
    )
  }

  if (is.null(data) || nrow(data) == 0 || !all(c(team_col, date_col, value_col) %in% names(data))) {
    return(function(team, lookup_date) missing_evidence("missing_source_row"))
  }
  data[[date_col]] <- as.Date(data[[date_col]])
  data[[value_col]] <- suppressWarnings(as.numeric(data[[value_col]]))
  data <- data[!is.na(data[[team_col]]) & !is.na(data[[date_col]]), , drop = FALSE]
  split_data <- split(data[order(data[[date_col]]), , drop = FALSE], data[[team_col]])

  function(team, lookup_date) {
    team_rows <- split_data[[team]]
    if (is.null(team_rows) || nrow(team_rows) == 0) {
      return(missing_evidence("missing_source_row"))
    }
    idx <- findInterval(as.Date(lookup_date) - 1, team_rows[[date_col]])
    if (idx <= 0) return(missing_evidence("missing_source_row"))

    source_date <- team_rows[[date_col]][idx]
    value <- team_rows[[value_col]][idx]
    if (!is.finite(value)) {
      return(missing_evidence("missing_source_value", TRUE, source_date))
    }
    list(
      value = as.numeric(value),
      source_present = TRUE,
      source_date = as.Date(source_date),
      value_present = TRUE,
      imputed = FALSE,
      imputation_reason = ""
    )
  }
}

#' Create a value-only latest-before lookup function
#' @keywords internal
make_latest_team_lookup <- function(data, value_col, team_col = "team", date_col = "date", default = NA_real_) {
  evidence_lookup <- make_latest_team_evidence_lookup(
    data = data,
    value_col = value_col,
    team_col = team_col,
    date_col = date_col,
    default = default
  )
  function(team, lookup_date) evidence_lookup(team, lookup_date)$value
}

#' Combine two team lookups into home-minus-away evidence
#' @keywords internal
forecast_difference_evidence <- function(home, away) {
  source_present <- isTRUE(home$source_present) && isTRUE(away$source_present)
  value_present <- isTRUE(home$value_present) && isTRUE(away$value_present)
  source_date <- if (source_present) {
    max(as.Date(c(home$source_date, away$source_date)), na.rm = TRUE)
  } else {
    as.Date(NA)
  }
  reason <- if (!source_present) {
    "missing_source_row"
  } else if (!value_present) {
    "missing_source_value"
  } else {
    ""
  }
  list(
    value = as.numeric(home$value) - as.numeric(away$value),
    source_present = source_present,
    source_date = as.Date(source_date),
    value_present = value_present,
    imputed = !value_present,
    imputation_reason = reason
  )
}

#' Add canonical evidence companions for one feature
#' @keywords internal
add_forecast_feature_evidence <- function(row, feature_id, evidence) {
  row[[feature_id]] <- as.numeric(evidence$value)
  row[[paste0(feature_id, "__value_present")]] <- isTRUE(evidence$value_present)
  row[[paste0(feature_id, "__source_present")]] <- isTRUE(evidence$source_present)
  row[[paste0(feature_id, "__source_date")]] <- as.Date(evidence$source_date)
  row[[paste0(feature_id, "__imputed")]] <- isTRUE(evidence$imputed)
  row[[paste0(feature_id, "__imputation_reason")]] <- as.character(evidence$imputation_reason)
  row
}

#' Build a feature table for match forecasting
#'
#' @param matches Match data
#' @param elo_ratings Elo history data frame
#' @param rolling_form Optional rolling-form data frame
#' @param squad_strength Optional Transfermarkt squad-strength data frame
#' @param goal_ability Optional goal-ability feature data frame already keyed to matches
#' @param cutoff_date Optional fixed cutoff used for all lookups
#' @param home_advantage Elo home advantage
#' @return Data frame at one row per match
#' @export
build_forecast_feature_table <- function(
    matches,
    elo_ratings,
    rolling_form = NULL,
    squad_strength = NULL,
    goal_ability = NULL,
    cutoff_date = NULL,
    home_advantage = 60
) {
  required_cols <- c("date", "home_team_canonical", "away_team_canonical", "home_score", "away_score")
  missing_cols <- setdiff(required_cols, names(matches))
  if (length(missing_cols) > 0) {
    stop(paste("Matches missing required columns:", paste(missing_cols, collapse = ", ")))
  }
  if (missing(elo_ratings) || is.null(elo_ratings)) stop("elo_ratings is required")

  matches$date <- as.Date(matches$date)
  elo_ratings$date <- as.Date(elo_ratings$date)
  if (!is.null(rolling_form) && "match_date" %in% names(rolling_form)) rolling_form$match_date <- as.Date(rolling_form$match_date)
  if (!is.null(squad_strength) && "as_of_date" %in% names(squad_strength)) squad_strength$as_of_date <- as.Date(squad_strength$as_of_date)
  if (!is.null(squad_strength) && "team" %in% names(squad_strength)) {
    squad_strength$team <- canonicalise_feature_team_name(squad_strength$team)
  }
  match_ids <- if ("match_id" %in% names(matches)) {
    make.unique(as.character(matches$match_id), sep = "__")
  } else {
    make.unique(
      paste(matches$home_team_canonical, matches$away_team_canonical, matches$date, sep = "_"),
      sep = "__"
    )
  }

  lookup_dates <- if (is.null(cutoff_date)) matches$date else rep(as.Date(cutoff_date), nrow(matches))
  venue <- if ("neutral" %in% names(matches)) ifelse(as.logical(matches$neutral), "neutral", "home") else "home"
  if ("venue" %in% names(matches)) venue <- matches$venue

  get_elo <- make_latest_team_evidence_lookup(elo_ratings, "rating", default = 1500)
  form_lookups <- list()
  get_form <- function(team, date_value, col) {
    if (is.null(form_lookups[[col]])) {
      form_lookups[[col]] <<- make_latest_team_evidence_lookup(rolling_form, col, date_col = "match_date", default = 0)
    }
    form_lookups[[col]](team, date_value)
  }
  squad_date_col <- if (!is.null(squad_strength) && "feature_source_date" %in% names(squad_strength)) "feature_source_date" else "as_of_date"
  squad_lookups <- list()
  get_squad <- function(team, date_value, col) {
    if (is.null(squad_lookups[[col]])) {
      squad_lookups[[col]] <<- make_latest_team_evidence_lookup(squad_strength, col, date_col = squad_date_col, default = 0)
    }
    squad_lookups[[col]](team, date_value)
  }

  rows <- vector("list", nrow(matches))
  for (i in seq_len(nrow(matches))) {
    lookup_date <- lookup_dates[i]
    home_team <- matches$home_team_canonical[i]
    away_team <- matches$away_team_canonical[i]
    home_elo <- get_elo(home_team, lookup_date)
    away_elo <- get_elo(away_team, lookup_date)
    elo_evidence <- forecast_difference_evidence(home_elo, away_elo)

    if (venue[i] == "home") elo_evidence$value <- elo_evidence$value + home_advantage
    if (venue[i] == "away") elo_evidence$value <- elo_evidence$value - home_advantage

    row <- data.frame(
      match_id = match_ids[i],
      date = matches$date[i],
      home_team = home_team,
      away_team = away_team,
      home_goals = matches$home_score[i],
      away_goals = matches$away_score[i],
      venue = venue[i],
      feature_source_date = as.Date(NA),
      stringsAsFactors = FALSE
    )
    row <- add_forecast_feature_evidence(row, "elo_diff", elo_evidence)
    row$actual_outcome <- if (is.na(row$home_goals) || is.na(row$away_goals)) {
      NA_character_
    } else if (row$home_goals > row$away_goals) {
      "home_win"
    } else if (row$home_goals == row$away_goals) {
      "draw"
    } else {
      "away_win"
    }

    form_cols <- c("xgf_ewma", "xga_ewma", "xgd_ewma", "shots_ewma", "form_index")
    for (col in form_cols) {
      evidence <- forecast_difference_evidence(
        get_form(home_team, lookup_date, col),
        get_form(away_team, lookup_date, col)
      )
      row <- add_forecast_feature_evidence(row, paste0(col, "_diff"), evidence)
    }

    squad_cols <- c(
      "log_squad_value", "log_top11_value", "log_top15_value", "median_player_value",
      "squad_value_concentration", "avg_age", "total_caps", "total_goals",
      "num_players_with_value", "missing_value_share",
      "log_top23_value", "top5_value_share", "top11_to_top23_ratio", "value_drop_11_to_23",
      "value_weighted_avg_age", "top11_avg_age", "top11_u24_value_share", "top11_over30_value_share",
      "log_goalkeeper_value", "log_defense_value", "log_midfield_value", "log_attack_value",
      "log_top1_goalkeeper_value", "log_top4_defense_value", "log_top4_midfield_value", "log_top3_attack_value",
      "defense_value_share", "midfield_value_share", "attack_value_share",
      "squad_value_momentum_6m", "squad_value_momentum_12m",
      "top11_value_momentum_6m", "top11_value_momentum_12m"
    )
    for (col in squad_cols) {
      if (!is.null(squad_strength) && col %in% names(squad_strength)) {
        evidence <- forecast_difference_evidence(
          get_squad(home_team, lookup_date, col),
          get_squad(away_team, lookup_date, col)
        )
        row <- add_forecast_feature_evidence(row, paste0(col, "_diff"), evidence)
      }
    }

    rows[[i]] <- row
  }

  result <- do.call(rbind, rows)
  if (!is.null(goal_ability) && nrow(goal_ability) == nrow(result)) {
    result <- cbind(result, goal_ability)
  }
  source_date_cols <- grep("__source_date$", names(result), value = TRUE)
  if (length(source_date_cols) > 0) {
    source_dates <- do.call(cbind, lapply(result[source_date_cols], function(x) as.numeric(as.Date(x))))
    latest <- apply(source_dates, 1, function(x) if (all(is.na(x))) NA_real_ else max(x, na.rm = TRUE))
    result$feature_source_date <- as.Date(latest, origin = "1970-01-01")
  }
  result
}

#' Validate producer-captured forecast feature evidence
#'
#' @param features Canonical wide feature table
#' @param feature_contract Registered feature contract data frame
#' @param derived_mappings Named mapping from adapter-derived IDs to producer IDs
#' @return TRUE invisibly
#' @export
validate_forecast_feature_evidence <- function(
    features,
    feature_contract = read.csv("data/benchmark/phase09/feature_contract.csv", stringsAsFactors = FALSE),
    derived_mappings = c(
      elo_difference_for_team = "elo_diff",
      venue_advantage_for_team = "elo_diff"
    )
) {
  if (!all(c("match_id", "date") %in% names(features))) {
    stop("Forecast features must contain match_id and date")
  }
  if (any(is.na(features$match_id) | !nzchar(as.character(features$match_id))) || anyDuplicated(features$match_id)) {
    stop("Forecast feature match_id values must be non-empty and unique")
  }
  if (!all(c("feature_id", "source_id") %in% names(feature_contract))) {
    stop("Feature contract must contain feature_id and source_id")
  }

  feature_ids <- unique(as.character(feature_contract$feature_id))
  producer_ids <- vapply(feature_ids, function(feature_id) {
    if (feature_id %in% names(derived_mappings)) unname(derived_mappings[[feature_id]]) else feature_id
  }, character(1))
  missing_features <- setdiff(unique(producer_ids), names(features))
  if (length(missing_features) > 0) {
    stop(paste("Forecast features missing registered values:", paste(missing_features, collapse = ", ")))
  }

  fixture_dates <- as.Date(features$date)
  for (producer_id in unique(producer_ids)) {
    companion_names <- paste0(
      producer_id,
      c("__value_present", "__source_present", "__source_date", "__imputed", "__imputation_reason")
    )
    missing_companions <- setdiff(companion_names, names(features))
    if (length(missing_companions) > 0) {
      stop(paste("Forecast evidence missing companions for", producer_id, ":", paste(missing_companions, collapse = ", ")))
    }

    value_present <- as.logical(features[[paste0(producer_id, "__value_present")]])
    source_present <- as.logical(features[[paste0(producer_id, "__source_present")]])
    source_date <- as.Date(features[[paste0(producer_id, "__source_date")]])
    imputed <- as.logical(features[[paste0(producer_id, "__imputed")]])
    reason <- as.character(features[[paste0(producer_id, "__imputation_reason")]])
    reason[is.na(reason)] <- ""

    if (anyNA(value_present) || anyNA(source_present) || anyNA(imputed)) {
      stop(paste("Forecast evidence flags may not be missing for", producer_id))
    }
    if (any(value_present & !source_present)) {
      stop(paste("Forecast value cannot be present without a source for", producer_id))
    }
    if (any(source_present & is.na(source_date))) {
      stop(paste("Source-present forecast evidence requires a source date for", producer_id))
    }
    if (any(!source_present & !is.na(source_date))) {
      stop(paste("Source-absent forecast evidence cannot fabricate a source date for", producer_id))
    }
    if (any(!is.na(source_date) & source_date >= fixture_dates)) {
      stop(paste("Forecast evidence source dates must be strictly before fixture dates for", producer_id))
    }
    if (any(imputed != !value_present)) {
      stop(paste("Forecast evidence imputed flag disagrees with value presence for", producer_id))
    }
    if (any(imputed & !nzchar(reason))) {
      stop(paste("Forecast imputation reason is required for", producer_id))
    }
    if (any(!imputed & nzchar(reason))) {
      stop(paste("Non-imputed forecast evidence cannot carry an imputation reason for", producer_id))
    }
    values <- suppressWarnings(as.numeric(features[[producer_id]]))
    if (any(values == 0 & !source_present & !imputed, na.rm = TRUE)) {
      stop(paste("Missing-source zero must remain explicitly imputed for", producer_id))
    }
  }
  invisible(TRUE)
}

#' Convert dashboard fixtures to forecast feature input rows
#'
#' @param fixtures World Cup fixtures with home_team, away_team, date, and venue
#' @return Match-like data frame accepted by build_forecast_feature_table()
#' @export
worldcup_fixtures_to_feature_matches <- function(fixtures) {
  required_cols <- c("match_id", "date", "home_team", "away_team", "venue")
  missing_cols <- setdiff(required_cols, names(fixtures))
  if (length(missing_cols) > 0) {
    stop(paste("World Cup fixtures missing required columns:", paste(missing_cols, collapse = ", ")))
  }
  n <- nrow(fixtures)
  data.frame(
    match_id = fixtures$match_id,
    date = as.Date(fixtures$date),
    home_team_canonical = fixtures$home_team,
    away_team_canonical = fixtures$away_team,
    home_score = rep(NA_real_, n),
    away_score = rep(NA_real_, n),
    neutral = fixtures$venue == "neutral",
    venue = fixtures$venue,
    stringsAsFactors = FALSE
  )
}

#' Build ordered knockout candidate fixtures for WC2026
#'
#' @param teams Canonical team names
#' @param knockout_date Date used for all knockout route feature rows
#' @return Match-like ordered-pair fixture data frame
#' @export
worldcup_knockout_candidate_feature_matches <- function(teams, knockout_date) {
  teams <- unique(as.character(teams))
  pair_grid <- expand.grid(
    home_team_canonical = teams,
    away_team_canonical = teams,
    stringsAsFactors = FALSE
  )
  pair_grid <- pair_grid[pair_grid$home_team_canonical != pair_grid$away_team_canonical, , drop = FALSE]
  pair_grid$match_id <- paste0(
    "KO_",
    seq_len(nrow(pair_grid))
  )
  pair_grid$date <- as.Date(knockout_date)
  pair_grid$home_score <- NA_real_
  pair_grid$away_score <- NA_real_
  pair_grid$neutral <- TRUE
  pair_grid$venue <- "neutral"
  pair_grid[, c(
    "match_id", "date", "home_team_canonical", "away_team_canonical",
    "home_score", "away_score", "neutral", "venue"
  )]
}

#' Build WC2026 forecast features for group fixtures and knockout pairings
#'
#' @param groups World Cup group seed data
#' @param fixtures World Cup group fixtures
#' @param history_matches Historical match data
#' @param elo_ratings Elo ratings
#' @param rolling_form Optional rolling-form features
#' @param squad_strength Optional Transfermarkt squad-strength features
#' @param feature_cutoff_date Generated-at cutoff for forecast features
#' @param output_path Optional CSV output path
#' @return WC2026 feature table
#' @export
build_worldcup_forecast_feature_table <- function(
    groups,
    fixtures,
    history_matches,
    elo_ratings,
    rolling_form = NULL,
    squad_strength = NULL,
    feature_cutoff_date = Sys.Date(),
    output_path = NULL
) {
  if (!all(c("team") %in% names(groups))) stop("groups must contain team")
  feature_cutoff_date <- as.Date(feature_cutoff_date)
  fixtures$date <- as.Date(fixtures$date)
  knockout_date <- max(max(fixtures$date, na.rm = TRUE) + 1, feature_cutoff_date + 1, na.rm = TRUE)
  open_fixtures <- fixtures[feature_cutoff_date < fixtures$date, , drop = FALSE]
  group_rows <- worldcup_fixtures_to_feature_matches(open_fixtures)
  knockout_rows <- worldcup_knockout_candidate_feature_matches(groups$team, knockout_date)
  feature_matches <- rbind(group_rows, knockout_rows)
  if (nrow(feature_matches) == 0) {
    stop("No WC2026 forecast feature rows remain after applying the feature cutoff")
  }
  if (any(feature_cutoff_date >= feature_matches$date, na.rm = TRUE)) {
    bad <- feature_matches[feature_cutoff_date >= feature_matches$date, c("match_id", "date"), drop = FALSE]
    stop(paste(
      "WC2026 feature cutoff must be before every forecast match; first offending rows:",
      paste(head(paste(bad$match_id, bad$date, sep = "@"), 5), collapse = ", ")
    ))
  }

  ability <- suppressWarnings(compute_goal_ability_features(
    fixtures = feature_matches,
    history_matches = history_matches,
    cutoff_date = feature_cutoff_date
  ))
  features <- build_forecast_feature_table(
    matches = feature_matches,
    elo_ratings = elo_ratings,
    rolling_form = rolling_form,
    squad_strength = squad_strength,
    goal_ability = ability,
    cutoff_date = feature_cutoff_date
  )
  features$match_id <- feature_matches$match_id
  features$model_version <- "hybrid"
  features$feature_cutoff_date <- feature_cutoff_date
  features <- features[, c(
    "match_id", "model_version", "feature_cutoff_date",
    setdiff(names(features), c("match_id", "model_version", "feature_cutoff_date"))
  )]
  assert_no_feature_leakage(features, cutoff_date = feature_cutoff_date)
  expected_rows <- nrow(open_fixtures) + length(unique(groups$team)) * (length(unique(groups$team)) - 1)
  if (nrow(features) != expected_rows) {
    stop(paste("Expected", expected_rows, "WC2026 feature rows, found", nrow(features)))
  }
  if (!is.null(output_path)) {
    if (!dir.exists(dirname(output_path))) dir.create(dirname(output_path), recursive = TRUE)
    write.csv(features, output_path, row.names = FALSE)
  }
  features
}

#' Validate a forecast feature table has required model rows and columns
#'
#' @param features Forecast feature table
#' @param fixtures World Cup group fixtures
#' @param teams World Cup teams
#' @param predictors Required predictor columns
#' @param knockout_date Knockout candidate feature date
#' @param cutoff_date Optional forecast feature cutoff. Group fixtures on or before
#' the cutoff are completed or same-day unavailable and need not have feature rows.
#' @return TRUE invisibly
#' @export
assert_worldcup_forecast_features <- function(features, fixtures, teams, predictors, knockout_date = NULL, cutoff_date = NULL) {
  required_cols <- c("date", "home_team", "away_team", "feature_source_date", predictors)
  missing_cols <- setdiff(required_cols, names(features))
  if (length(missing_cols) > 0) {
    stop(paste("WC2026 feature table missing required columns:", paste(missing_cols, collapse = ", ")))
  }
  features$date <- as.Date(features$date)
  fixtures$date <- as.Date(fixtures$date)
  if (is.null(knockout_date)) knockout_date <- max(fixtures$date, na.rm = TRUE) + 1
  if (!is.null(cutoff_date)) {
    knockout_date <- max(as.Date(knockout_date), as.Date(cutoff_date) + 1, na.rm = TRUE)
    fixtures <- fixtures[as.Date(cutoff_date) < fixtures$date, , drop = FALSE]
  }
  group_keys <- paste(fixtures$date, fixtures$home_team, fixtures$away_team, sep = "\r")
  feature_keys <- paste(features$date, features$home_team, features$away_team, sep = "\r")
  missing_group <- setdiff(group_keys, feature_keys)
  if (length(missing_group) > 0) {
    stop(paste("WC2026 feature table missing group fixture rows:", paste(head(missing_group, 5), collapse = " | ")))
  }
  pair_grid <- expand.grid(home_team = unique(teams), away_team = unique(teams), stringsAsFactors = FALSE)
  pair_grid <- pair_grid[pair_grid$home_team != pair_grid$away_team, , drop = FALSE]
  pair_keys <- paste(as.Date(knockout_date), pair_grid$home_team, pair_grid$away_team, sep = "\r")
  missing_pairs <- setdiff(pair_keys, feature_keys)
  if (length(missing_pairs) > 0) {
    stop(paste("WC2026 feature table missing knockout candidate rows:", paste(head(missing_pairs, 5), collapse = " | ")))
  }
  assert_no_feature_leakage(features)
  invisible(TRUE)
}

#' Assert no feature row uses same-day or future information
#'
#' @param feature_table Feature table with date and feature_source_date
#' @param cutoff_date Optional expected maximum source cutoff
#' @return TRUE invisibly when valid
#' @export
assert_no_feature_leakage <- function(feature_table, cutoff_date = NULL) {
  if (!all(c("date", "feature_source_date") %in% names(feature_table))) {
    stop("Feature table must contain date and feature_source_date")
  }
  feature_table$date <- as.Date(feature_table$date)
  feature_table$feature_source_date <- as.Date(feature_table$feature_source_date)
  bad_rows <- which(feature_table$feature_source_date >= feature_table$date)
  if (length(bad_rows) > 0) {
    stop(paste("Feature leakage detected in rows:", paste(head(bad_rows, 10), collapse = ", ")))
  }
  if (!is.null(cutoff_date) && any(feature_table$feature_source_date >= as.Date(cutoff_date), na.rm = TRUE)) {
    stop(paste("Feature source dates must be before cutoff:", cutoff_date))
  }
  invisible(TRUE)
}
