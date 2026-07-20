#' Reconstruct and validate historical World Cup forecast snapshots

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

normalize_worldcup_team_key <- function(x) {
  key <- iconv(tolower(trimws(as.character(x))), to = "ASCII//TRANSLIT")
  key <- gsub("&", " and ", key, fixed = TRUE)
  key <- gsub("[^a-z0-9]+", " ", key)
  key <- trimws(gsub("[[:space:]]+", " ", key))
  aliases <- c(
    "south korea" = "korea republic",
    "korea rep" = "korea republic",
    "czechia" = "czech republic",
    "usa" = "united states",
    "u s a" = "united states",
    "united states of america" = "united states",
    "ivory coast" = "cote d ivoire",
    "cote d ivoire" = "cote d ivoire",
    "cape verde islands" = "cape verde",
    "bosnia herzegovina" = "bosnia and herzegovina",
    "turkiye" = "turkey",
    "t urkiye" = "turkey",
    "congo dr" = "dr congo",
    "iran" = "iran",
    "china pr" = "china"
  )
  replace <- key %in% names(aliases)
  key[replace] <- unname(aliases[key[replace]])
  key
}

parse_utc_time <- function(x) {
  values <- vapply(as.character(x), function(value) {
    if (is.na(value) || !nzchar(value)) return(NA_real_)
    normalized <- sub("Z$", "+0000", value)
    normalized <- sub("([+-][0-9]{2}):([0-9]{2})$", "\\1\\2", normalized)
    parsed <- tryCatch(
      as.POSIXct(
        normalized,
        tz = "UTC",
        tryFormats = c("%Y-%m-%dT%H:%M:%OS%z", "%Y-%m-%dT%H:%M%z", "%Y-%m-%d %H:%M:%OS")
      ),
      error = function(e) as.POSIXct(NA)
    )
    as.numeric(parsed)
  }, numeric(1))
  as.POSIXct(values, origin = "1970-01-01", tz = "UTC")
}

parse_local_generated_time <- function(x, tz = "Europe/Vienna") {
  parsed <- as.POSIXct(
    x,
    tz = tz,
    tryFormats = c("%Y-%m-%d %H:%M:%OS", "%Y-%m-%dT%H:%M:%OS", "%Y-%m-%dT%H:%M:%OS%z")
  )
  parsed
}

format_utc_time <- function(x) {
  out <- rep(NA_character_, length(x))
  valid <- !is.na(x)
  out[valid] <- format(x[valid], "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC", usetz = FALSE)
  out
}

extract_espn_competitor <- function(competitors, side) {
  idx <- which(vapply(competitors, function(x) identical(x$homeAway, side), logical(1)))
  if (length(idx) != 1) return(NULL)
  competitors[[idx]]
}

#' Load cached ESPN World Cup result events
#'
#' @param scoreboard_dir Directory containing cached scoreboard JSON files.
#' @return One row per final event.
#' @export
load_worldcup_2026_result_events <- function(scoreboard_dir = "data/raw/espn") {
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required")
  files <- sort(list.files(scoreboard_dir, pattern = "^scoreboard_[0-9]{8}\\.json$", full.names = TRUE))
  if (!length(files)) stop("No cached ESPN scoreboard files found in ", scoreboard_dir)

  rows <- list()
  n <- 0L
  for (path in files) {
    payload <- jsonlite::fromJSON(path, simplifyVector = FALSE)
    for (event in payload$events %||% list()) {
      competition <- (event$competitions %||% list())[[1]]
      if (is.null(competition)) next
      competitors <- competition$competitors %||% list()
      home <- extract_espn_competitor(competitors, "home")
      away <- extract_espn_competitor(competitors, "away")
      if (is.null(home) || is.null(away)) next
      status <- event$status$type$name %||% competition$status$type$name %||% NA_character_
      completed <- event$status$type$completed %||% competition$status$type$completed %||% FALSE
      if (!isTRUE(completed)) next

      n <- n + 1L
      rows[[n]] <- data.frame(
        event_id = as.character(event$id %||% NA_character_),
        kickoff_utc = as.character(event$date %||% competition$date %||% NA_character_),
        event_date = as.Date(substr(as.character(event$date %||% competition$date), 1, 10)),
        home_team = as.character(home$team$displayName %||% home$team$name %||% NA_character_),
        away_team = as.character(away$team$displayName %||% away$team$name %||% NA_character_),
        home_goals = suppressWarnings(as.integer(home$score %||% NA_character_)),
        away_goals = suppressWarnings(as.integer(away$score %||% NA_character_)),
        home_shootout = suppressWarnings(as.integer(home$shootoutScore %||% NA_integer_)),
        away_shootout = suppressWarnings(as.integer(away$shootoutScore %||% NA_integer_)),
        winner_team = if (isTRUE(home$winner)) {
          as.character(home$team$displayName %||% home$team$name)
        } else if (isTRUE(away$winner)) {
          as.character(away$team$displayName %||% away$team$name)
        } else {
          NA_character_
        },
        status = status,
        source_path = path,
        stringsAsFactors = FALSE
      )
    }
  }
  if (!length(rows)) stop("No final ESPN events found")
  events <- do.call(rbind, rows)
  events <- events[!duplicated(events$event_id, fromLast = TRUE), , drop = FALSE]
  events$home_key <- normalize_worldcup_team_key(events$home_team)
  events$away_key <- normalize_worldcup_team_key(events$away_team)
  events$winner_key <- normalize_worldcup_team_key(events$winner_team)
  events
}

make_fixture_pair_key <- function(home, away) {
  vapply(seq_along(home), function(i) {
    paste(sort(c(normalize_worldcup_team_key(home[i]), normalize_worldcup_team_key(away[i]))), collapse = "|")
  }, character(1))
}

#' Validate the canonical World Cup fixture registry
#'
#' @param fixtures Registry data frame.
#' @param expected_matches Expected official fixture count.
#' @return The registry, invisibly.
#' @export
validate_fixture_registry <- function(fixtures, expected_matches = 104L) {
  required <- c(
    "match_id", "stage", "home_team", "away_team", "kickoff_utc",
    "actual_home_goals", "actual_away_goals", "actual_winner_team",
    "result_event_id", "result_source_path"
  )
  missing <- setdiff(required, names(fixtures))
  if (length(missing)) stop("Fixture registry missing columns: ", paste(missing, collapse = ", "))
  if (nrow(fixtures) != expected_matches) {
    stop("Fixture registry must contain exactly ", expected_matches, " matches; found ", nrow(fixtures))
  }
  if (anyDuplicated(fixtures$match_id)) stop("Fixture registry match_id values must be unique")
  invalid_kickoff <- is.na(parse_utc_time(fixtures$kickoff_utc))
  if (any(invalid_kickoff)) {
    stop(
      "Fixture registry contains invalid kickoff_utc values: ",
      paste(paste0(fixtures$match_id[invalid_kickoff], "=", fixtures$kickoff_utc[invalid_kickoff]), collapse = ", ")
    )
  }
  if (any(is.na(fixtures$actual_home_goals) | is.na(fixtures$actual_away_goals))) {
    stop("Fixture registry contains missing regulation scores")
  }
  if (any(is.na(fixtures$result_event_id) | !nzchar(fixtures$result_event_id))) {
    stop("Fixture registry contains unmatched result events")
  }
  invisible(fixtures)
}

#' Build the canonical 2026 World Cup fixture and result registry
#'
#' @param group_results_path Current dashboard match export.
#' @param bracket_results_path Current dashboard bracket export.
#' @param scoreboard_dir Cached ESPN scoreboard directory.
#' @return A validated 104-row data frame.
#' @export
build_worldcup_2026_fixture_registry <- function(
    group_results_path = "outputs/dashboard/worldcup_match_forecasts.csv",
    bracket_results_path = "outputs/dashboard/worldcup_bracket_paths.csv",
    scoreboard_dir = "data/raw/espn"
) {
  group <- read.csv(group_results_path, stringsAsFactors = FALSE, check.names = FALSE)
  group <- group[group$stage == "group", , drop = FALSE]
  bracket <- read.csv(bracket_results_path, stringsAsFactors = FALSE, check.names = FALSE)
  bracket <- bracket[grepl("^M[0-9]+$", bracket$match_id), , drop = FALSE]

  group_rows <- data.frame(
    match_id = group$match_id,
    stage = "group",
    round = paste("Group", group$group),
    fixture_date = as.Date(group$date),
    home_team = group$home_team,
    away_team = group$away_team,
    actual_home_goals = as.integer(group$actual_home_goals),
    actual_away_goals = as.integer(group$actual_away_goals),
    actual_winner_team = ifelse(
      group$actual_home_goals > group$actual_away_goals,
      group$home_team,
      ifelse(group$actual_home_goals < group$actual_away_goals, group$away_team, NA_character_)
    ),
    stringsAsFactors = FALSE
  )
  knockout_rows <- data.frame(
    match_id = bracket$match_id,
    stage = "knockout",
    round = bracket$round,
    fixture_date = as.Date(bracket$actual_match_date),
    home_team = bracket$slot1_team,
    away_team = bracket$slot2_team,
    actual_home_goals = as.integer(bracket$actual_slot1_goals),
    actual_away_goals = as.integer(bracket$actual_slot2_goals),
    actual_winner_team = bracket$actual_winner_team,
    stringsAsFactors = FALSE
  )
  fixtures <- rbind(group_rows, knockout_rows)
  fixtures$pair_key <- make_fixture_pair_key(fixtures$home_team, fixtures$away_team)

  events <- load_worldcup_2026_result_events(scoreboard_dir)
  events$pair_key <- make_fixture_pair_key(events$home_team, events$away_team)
  event_index <- integer(nrow(fixtures))
  for (i in seq_len(nrow(fixtures))) {
    candidates <- which(events$pair_key == fixtures$pair_key[i])
    if (length(candidates) > 1L) {
      date_distance <- abs(as.integer(events$event_date[candidates] - fixtures$fixture_date[i]))
      candidates <- candidates[date_distance == min(date_distance, na.rm = TRUE)]
    }
    if (length(candidates) != 1L) {
      stop(
        "Expected exactly one result event for ", fixtures$match_id[i], " (",
        fixtures$home_team[i], " vs ", fixtures$away_team[i], "); found ", length(candidates)
      )
    }
    event_index[i] <- candidates
  }
  if (anyDuplicated(event_index)) stop("A result event was mapped to more than one fixture")
  matched <- events[event_index, , drop = FALSE]

  fixtures$kickoff_utc <- matched$kickoff_utc
  fixtures$result_event_id <- matched$event_id
  fixtures$result_source_path <- matched$source_path
  fixtures$result_status <- matched$status
  fixtures$actual_winner_team <- ifelse(
    is.na(fixtures$actual_winner_team) | !nzchar(fixtures$actual_winner_team),
    matched$winner_team,
    fixtures$actual_winner_team
  )
  fixtures$home_key <- normalize_worldcup_team_key(fixtures$home_team)
  fixtures$away_key <- normalize_worldcup_team_key(fixtures$away_team)
  fixtures$winner_key <- normalize_worldcup_team_key(fixtures$actual_winner_team)
  fixtures <- fixtures[order(parse_utc_time(fixtures$kickoff_utc), fixtures$match_id), , drop = FALSE]
  rownames(fixtures) <- NULL
  validate_fixture_registry(fixtures)
  fixtures
}

run_git_read <- function(args, repo = ".", required = TRUE) {
  output <- suppressWarnings(system2("git", c("-C", repo, args), stdout = TRUE, stderr = TRUE))
  status <- attr(output, "status") %||% 0L
  if (status != 0L) {
    if (required) stop("Git command failed: git ", paste(args, collapse = " "), "\n", paste(output, collapse = "\n"))
    return(character())
  }
  output
}

git_blob_id <- function(commit, path, repo = ".") {
  value <- run_git_read(c("rev-parse", paste0(commit, ":", path)), repo = repo, required = FALSE)
  if (!length(value)) NA_character_ else trimws(value[1])
}

read_git_blob_text <- function(commit, path, repo = ".", required = TRUE) {
  run_git_read(c("show", paste0(commit, ":", path)), repo = repo, required = required)
}

#' List commits containing historical prematch archive versions
#'
#' @param source_ref Git ref reachable history should be read from.
#' @param archive_paths Forecast archive paths.
#' @param repo Repository root.
#' @return Commit metadata in chronological order.
#' @export
list_forecast_archive_commits <- function(
    source_ref = "HEAD",
    archive_paths = c(
      "outputs/dashboard/worldcup_prematch_forecasts.csv",
      "outputs/dashboard/worldcup_bracket_prematch_forecasts.csv"
    ),
    repo = "."
) {
  lines <- run_git_read(
    c("log", "--reverse", "--format=%H%x09%aI%x09%cI%x09%P", source_ref, "--", archive_paths),
    repo = repo
  )
  if (!length(lines)) return(data.frame())
  fields <- strsplit(lines, "\t", fixed = TRUE)
  out <- data.frame(
    commit_sha = vapply(fields, `[`, character(1), 1),
    author_at = vapply(fields, `[`, character(1), 2),
    committed_at = vapply(fields, `[`, character(1), 3),
    parent_shas = vapply(fields, function(x) if (length(x) >= 4) x[4] else "", character(1)),
    stringsAsFactors = FALSE
  )
  out[!duplicated(out$commit_sha), , drop = FALSE]
}

read_csv_text <- function(lines) {
  if (!length(lines)) return(data.frame())
  read.csv(text = paste(lines, collapse = "\n"), stringsAsFactors = FALSE, check.names = FALSE)
}

column_or_na <- function(data, name, default = NA) {
  if (name %in% names(data)) data[[name]] else rep(default, nrow(data))
}

normalize_archive_rows <- function(data, archive_path) {
  if (!nrow(data)) return(data.frame())
  is_bracket <- grepl("bracket", archive_path, fixed = TRUE)
  if (is_bracket) {
    out <- data.frame(
      match_id = column_or_na(data, "match_id", NA_character_),
      forecast_scope = "knockout",
      home_team = column_or_na(data, "slot1_team", NA_character_),
      away_team = column_or_na(data, "slot2_team", NA_character_),
      expected_home_goals = as.numeric(column_or_na(data, "prematch_slot1_expected_goals")),
      expected_away_goals = as.numeric(column_or_na(data, "prematch_slot2_expected_goals")),
      p_home = as.numeric(column_or_na(data, "prematch_slot1_regulation_win_probability")),
      p_draw = as.numeric(column_or_na(data, "prematch_draw_after_regulation_probability")),
      p_away = as.numeric(column_or_na(data, "prematch_slot2_regulation_win_probability")),
      p_home_advance = as.numeric(column_or_na(data, "prematch_slot1_advancement_probability")),
      p_away_advance = as.numeric(column_or_na(data, "prematch_slot2_advancement_probability")),
      p_over_2_5 = as.numeric(column_or_na(data, "prematch_over_2_5_probability")),
      p_btts = as.numeric(column_or_na(data, "prematch_both_teams_to_score_probability")),
      most_likely_score = column_or_na(data, "prematch_most_likely_score", NA_character_),
      generated_at_raw = column_or_na(data, "prematch_generated_at", NA_character_),
      feature_cutoff_date = column_or_na(data, "prematch_feature_cutoff_date", NA_character_),
      result_cutoff_date = column_or_na(data, "prematch_actual_results_cutoff_date", NA_character_),
      forecast_source = column_or_na(data, "prematch_forecast_source", "dashboard_bracket_archive"),
      stringsAsFactors = FALSE
    )
  } else {
    out <- data.frame(
      match_id = column_or_na(data, "match_id", NA_character_),
      forecast_scope = "group",
      home_team = column_or_na(data, "home_team", NA_character_),
      away_team = column_or_na(data, "away_team", NA_character_),
      expected_home_goals = as.numeric(column_or_na(data, "prematch_home_goals_expected")),
      expected_away_goals = as.numeric(column_or_na(data, "prematch_away_goals_expected")),
      p_home = as.numeric(column_or_na(data, "prematch_win_probability")),
      p_draw = as.numeric(column_or_na(data, "prematch_draw_probability")),
      p_away = as.numeric(column_or_na(data, "prematch_loss_probability")),
      p_home_advance = NA_real_,
      p_away_advance = NA_real_,
      p_over_2_5 = as.numeric(column_or_na(data, "prematch_over_2_5_probability")),
      p_btts = as.numeric(column_or_na(data, "prematch_both_teams_to_score_probability")),
      most_likely_score = column_or_na(data, "prematch_most_likely_score", NA_character_),
      generated_at_raw = column_or_na(data, "prematch_generated_at", NA_character_),
      feature_cutoff_date = column_or_na(data, "prematch_feature_cutoff_date", NA_character_),
      result_cutoff_date = column_or_na(data, "prematch_actual_results_cutoff_date", NA_character_),
      forecast_source = column_or_na(data, "prematch_forecast_source", "dashboard_archive"),
      stringsAsFactors = FALSE
    )
  }
  match_number <- suppressWarnings(as.integer(sub("^M", "", out$match_id)))
  official_id <- grepl("^G[A-L][0-9]{2}$", out$match_id) |
    (grepl("^M[0-9]+$", out$match_id) & match_number >= 73L & match_number <= 104L)
  out[official_id %in% TRUE, , drop = FALSE]
}

forecast_revision_hash <- function(data) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("digest is required for revision hashing")
  fields <- c(
    "match_id", "home_team", "away_team", "expected_home_goals", "expected_away_goals",
    "p_home", "p_draw", "p_away", "p_home_advance", "p_away_advance",
    "p_over_2_5", "p_btts", "most_likely_score", "generated_at_raw",
    "feature_cutoff_date", "result_cutoff_date"
  )
  vapply(seq_len(nrow(data)), function(i) {
    digest::digest(paste(vapply(fields, function(x) as.character(data[[x]][i]), character(1)), collapse = "|"),
      algo = "sha256", serialize = FALSE
    )
  }, character(1))
}

#' Extract every committed prematch archive occurrence
#'
#' @param commits Commit inventory from `list_forecast_archive_commits()`.
#' @param archive_paths Archive paths.
#' @param repo Repository root.
#' @param generated_tz Timezone used by legacy naive generation timestamps.
#' @return One row per match occurrence per commit.
#' @export
extract_forecast_occurrences <- function(
    commits,
    archive_paths = c(
      "outputs/dashboard/worldcup_prematch_forecasts.csv",
      "outputs/dashboard/worldcup_bracket_prematch_forecasts.csv"
    ),
    repo = ".",
    generated_tz = "Europe/Vienna"
) {
  if (!nrow(commits)) return(data.frame())
  dashboard_path <- "outputs/dashboard/worldcup_dashboard_data.json"
  feature_path <- "data/processed/worldcup_2026_forecast_features_hybrid.csv"
  model_paths <- c(
    "models/home_goal_model_hybrid.rds", "models/away_goal_model_hybrid.rds",
    "models/home_goal_model.rds", "models/away_goal_model.rds"
  )
  rows <- list()
  n <- 0L
  for (i in seq_len(nrow(commits))) {
    commit <- commits$commit_sha[i]
    dashboard_blob <- git_blob_id(commit, dashboard_path, repo)
    feature_blob <- git_blob_id(commit, feature_path, repo)
    model_blobs <- setNames(vapply(model_paths, git_blob_id, character(1), commit = commit, repo = repo), model_paths)
    for (archive_path in archive_paths) {
      lines <- read_git_blob_text(commit, archive_path, repo = repo, required = FALSE)
      if (!length(lines)) next
      archive <- tryCatch(read_csv_text(lines), error = function(e) data.frame())
      normalized <- normalize_archive_rows(archive, archive_path)
      if (!nrow(normalized)) next
      normalized$commit_sha <- commit
      normalized$author_at <- commits$author_at[i]
      normalized$committed_at <- commits$committed_at[i]
      normalized$parent_shas <- commits$parent_shas[i]
      normalized$archive_path <- archive_path
      normalized$archive_blob <- git_blob_id(commit, archive_path, repo)
      normalized$dashboard_blob <- dashboard_blob
      normalized$feature_blob <- feature_blob
      normalized$home_model_blob <- if (!is.na(model_blobs[1])) model_blobs[1] else model_blobs[3]
      normalized$away_model_blob <- if (!is.na(model_blobs[2])) model_blobs[2] else model_blobs[4]
      generated <- parse_local_generated_time(normalized$generated_at_raw, tz = generated_tz)
      normalized$generated_at_utc <- format_utc_time(generated)
      normalized$forecast_revision_id <- forecast_revision_hash(normalized)
      n <- n + 1L
      rows[[n]] <- normalized
    }
  }
  if (!length(rows)) return(data.frame())
  ledger <- do.call(rbind, rows)
  rownames(ledger) <- NULL
  ledger
}

probabilities_valid <- function(home, draw, away, tolerance = 1e-6) {
  values <- c(home, draw, away)
  all(is.finite(values)) && all(values >= 0 & values <= 1) && abs(sum(values) - 1) <= tolerance
}

evidence_flags_for_row <- function(row) {
  flags <- character()
  generated <- parse_utc_time(row$generated_at_utc)
  committed <- parse_utc_time(row$committed_at)
  kickoff <- parse_utc_time(row$kickoff_utc)
  if (is.na(generated)) flags <- c(flags, "generation_time_invalid")
  if (!is.na(generated) && !is.na(kickoff) && generated >= kickoff) flags <- c(flags, "post_kickoff_generation")
  if (is.na(committed)) flags <- c(flags, "commit_time_invalid")
  if (!is.na(committed) && !is.na(kickoff) && committed >= kickoff) flags <- c(flags, "post_kickoff_commit")
  if (!probabilities_valid(row$p_home, row$p_draw, row$p_away)) flags <- c(flags, "probability_invalid")
  if (!isTRUE(row$fixture_identity_match)) flags <- c(flags, "fixture_identity_mismatch")
  if (!isTRUE(row$source_cutoff_proven)) flags <- c(flags, "source_cutoff_not_proven")
  if (!isTRUE(row$artifact_complete)) flags <- c(flags, "artifact_missing")
  unique(flags)
}

primary_reason_from_flags <- function(flags) {
  precedence <- c(
    "fixture_identity_mismatch", "probability_invalid", "generation_time_invalid",
    "post_kickoff_generation", "commit_time_invalid", "post_kickoff_commit",
    "source_cutoff_not_proven", "artifact_missing"
  )
  hit <- precedence[precedence %in% flags]
  if (length(hit)) hit[1] else NA_character_
}

#' Classify forecast occurrence evidence
#'
#' @param occurrences Raw occurrence ledger.
#' @param fixtures Canonical fixture registry.
#' @return Occurrences with evidence flags and eligibility.
#' @export
classify_forecast_evidence <- function(occurrences, fixtures) {
  if (!nrow(occurrences)) return(occurrences)
  idx <- match(occurrences$match_id, fixtures$match_id)
  occurrences$kickoff_utc <- fixtures$kickoff_utc[idx]
  occurrences$canonical_home_team <- fixtures$home_team[idx]
  occurrences$canonical_away_team <- fixtures$away_team[idx]
  occurrences$stage <- fixtures$stage[idx]
  occurrences$round <- fixtures$round[idx]
  occurrences$actual_home_goals <- fixtures$actual_home_goals[idx]
  occurrences$actual_away_goals <- fixtures$actual_away_goals[idx]
  occurrences$actual_winner_team <- fixtures$actual_winner_team[idx]
  occurrences$fixture_identity_match <- !is.na(idx) &
    normalize_worldcup_team_key(occurrences$home_team) == normalize_worldcup_team_key(occurrences$canonical_home_team) &
    normalize_worldcup_team_key(occurrences$away_team) == normalize_worldcup_team_key(occurrences$canonical_away_team)

  generated <- parse_utc_time(occurrences$generated_at_utc)
  generated_date <- as.Date(generated, tz = "UTC")
  feature_date <- suppressWarnings(as.Date(occurrences$feature_cutoff_date))
  result_date <- suppressWarnings(as.Date(occurrences$result_cutoff_date))
  feature_ok <- !is.na(feature_date) & !is.na(generated_date) & feature_date <= generated_date
  result_ok <- is.na(result_date) | (!is.na(generated_date) & result_date <= generated_date)
  occurrences$source_cutoff_proven <- feature_ok & result_ok
  occurrences$artifact_complete <- !is.na(occurrences$archive_blob) &
    !is.na(occurrences$dashboard_blob) & !is.na(occurrences$feature_blob) &
    !is.na(occurrences$home_model_blob) & !is.na(occurrences$away_model_blob)

  all_flags <- lapply(seq_len(nrow(occurrences)), function(i) evidence_flags_for_row(occurrences[i, , drop = FALSE]))
  occurrences$validation_flags <- vapply(all_flags, function(x) paste(x, collapse = ";"), character(1))
  occurrences$primary_reason <- vapply(all_flags, primary_reason_from_flags, character(1))
  hard_flags <- c(
    "fixture_identity_mismatch", "probability_invalid", "generation_time_invalid",
    "post_kickoff_generation", "commit_time_invalid", "post_kickoff_commit"
  )
  has_hard_failure <- vapply(all_flags, function(x) any(x %in% hard_flags), logical(1))
  occurrences$evidence_tier <- ifelse(
    has_hard_failure,
    "rejected",
    ifelse(occurrences$source_cutoff_proven & occurrences$artifact_complete, "verified", "documented")
  )
  occurrences$strict_eligible <- occurrences$evidence_tier == "verified"
  occurrences$exploratory_eligible <- occurrences$evidence_tier == "documented"
  occurrences
}

select_view_rows <- function(data, direction = c("first", "latest")) {
  direction <- match.arg(direction)
  if (!nrow(data)) return(data)
  commit_time <- parse_utc_time(data$committed_at)
  generated_time <- parse_utc_time(data$generated_at_utc)
  order_index <- order(data$match_id, commit_time, generated_time, data$commit_sha, na.last = TRUE)
  if (direction == "latest") order_index <- rev(order_index)
  ordered <- data[order_index, , drop = FALSE]
  selected <- ordered[!duplicated(ordered$match_id), , drop = FALSE]
  selected[order(selected$match_id), , drop = FALSE]
}

#' Derive deterministic strict/exploratory first and latest views
#'
#' @param ledger Classified occurrence ledger.
#' @return Selected forecast rows.
#' @export
derive_forecast_views <- function(ledger) {
  specs <- list(
    strict = ledger[ledger$strict_eligible %in% TRUE, , drop = FALSE],
    exploratory = ledger[ledger$exploratory_eligible %in% TRUE, , drop = FALSE]
  )
  views <- list()
  n <- 0L
  for (sample_name in names(specs)) {
    for (direction in c("first", "latest")) {
      selected <- select_view_rows(specs[[sample_name]], direction)
      if (!nrow(selected)) next
      selected$sample <- sample_name
      selected$view <- paste0(direction, "_valid")
      n <- n + 1L
      views[[n]] <- selected
    }
  }
  if (!length(views)) return(data.frame())
  out <- do.call(rbind, views)
  rownames(out) <- NULL
  out
}

#' Validate classified ledger invariants
#'
#' @param ledger Classified occurrence ledger.
#' @param fixtures Canonical fixture registry.
#' @return TRUE invisibly.
#' @export
validate_forecast_ledger <- function(ledger, fixtures) {
  if (any(ledger$strict_eligible & ledger$exploratory_eligible, na.rm = TRUE)) {
    stop("Strict and exploratory eligibility must be mutually exclusive")
  }
  kickoff <- parse_utc_time(ledger$kickoff_utc)
  generated <- parse_utc_time(ledger$generated_at_utc)
  committed <- parse_utc_time(ledger$committed_at)
  scored <- ledger$strict_eligible | ledger$exploratory_eligible
  if (any(scored & (is.na(generated) | is.na(committed) | generated >= kickoff | committed >= kickoff), na.rm = TRUE)) {
    stop("A scored ledger row is not strictly pre-kickoff")
  }
  rejected <- ledger$evidence_tier == "rejected"
  if (any(rejected & (is.na(ledger$primary_reason) | !nzchar(ledger$primary_reason)))) {
    stop("Rejected rows must have a primary_reason")
  }
  if (length(setdiff(unique(ledger$match_id), fixtures$match_id))) stop("Ledger contains unknown match IDs")
  invisible(TRUE)
}

extract_json_snapshot <- function(commit, repo = ".") {
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required")
  lines <- read_git_blob_text(commit, "outputs/dashboard/worldcup_dashboard_data.json", repo, required = FALSE)
  if (!length(lines)) return(NULL)
  jsonlite::fromJSON(paste(lines, collapse = "\n"), simplifyDataFrame = TRUE)
}

#' Extract full distributions for selected forecast views
#'
#' @param selected Selected forecast view rows.
#' @param repo Repository root.
#' @return List with scoreline, stage, bracket, and metadata snapshots.
#' @export
extract_selected_distributions <- function(selected, repo = ".") {
  if (!nrow(selected)) return(list(scorelines = data.frame(), stage = data.frame(), bracket = data.frame(), metadata = data.frame()))
  commits <- unique(selected$commit_sha)
  scorelines <- stage <- bracket <- metadata <- list()
  for (commit in commits) {
    snapshot <- extract_json_snapshot(commit, repo)
    if (is.null(snapshot)) next
    match_ids <- selected$match_id[selected$commit_sha == commit]
    if (is.data.frame(snapshot$scoreline_distributions)) {
      rows <- snapshot$scoreline_distributions[snapshot$scoreline_distributions$match_id %in% match_ids, , drop = FALSE]
      if (nrow(rows)) {
        rows$commit_sha <- commit
        scorelines[[length(scorelines) + 1L]] <- rows
      }
    }
    if (is.data.frame(snapshot$stage_probabilities)) {
      rows <- snapshot$stage_probabilities
      rows$commit_sha <- commit
      stage[[length(stage) + 1L]] <- rows
    }
    if (is.data.frame(snapshot$bracket_paths)) {
      rows <- snapshot$bracket_paths[snapshot$bracket_paths$match_id %in% match_ids, , drop = FALSE]
      if (nrow(rows)) {
        rows$commit_sha <- commit
        bracket[[length(bracket) + 1L]] <- rows
      }
    }
    meta <- snapshot$metadata %||% list()
    metadata[[length(metadata) + 1L]] <- data.frame(
      commit_sha = commit,
      generated_at = as.character(meta$generated_at %||% NA_character_),
      model_version = as.character(meta$model_version %||% NA_character_),
      feature_cutoff_date = as.character(meta$feature_cutoff_date %||% NA_character_),
      stringsAsFactors = FALSE
    )
  }
  bind <- function(x) {
    if (!length(x)) return(data.frame())
    all_names <- unique(unlist(lapply(x, names), use.names = FALSE))
    normalized <- lapply(x, function(data) {
      missing <- setdiff(all_names, names(data))
      for (name in missing) data[[name]] <- NA
      data[, all_names, drop = FALSE]
    })
    do.call(rbind, normalized)
  }
  list(scorelines = bind(scorelines), stage = bind(stage), bracket = bind(bracket), metadata = bind(metadata))
}

write_checksum_manifest <- function(paths, source_ref, source_sha, output_path) {
  existing <- paths[file.exists(paths)]
  manifest <- data.frame(
    path = existing,
    bytes = as.numeric(file.info(existing)$size),
    md5 = unname(tools::md5sum(existing)),
    source_ref = source_ref,
    source_sha = source_sha,
    stringsAsFactors = FALSE
  )
  write.csv(manifest, output_path, row.names = FALSE)
  manifest
}

#' Write the complete World Cup forecast ledger bundle
#'
#' @param source_ref Git source ref.
#' @param output_dir Output directory.
#' @param repo Repository root.
#' @param max_commits Optional bounded number of most recent commits for tests.
#' @return Named output paths and in-memory summaries.
#' @export
write_forecast_ledger_bundle <- function(
    source_ref = "HEAD",
    output_dir = "outputs/evaluation/wc2026",
    repo = ".",
    max_commits = Inf
) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  fixtures <- build_worldcup_2026_fixture_registry()
  commits <- list_forecast_archive_commits(source_ref = source_ref, repo = repo)
  if (is.finite(max_commits) && nrow(commits) > max_commits) {
    commits <- tail(commits, as.integer(max_commits))
  }
  occurrences <- extract_forecast_occurrences(commits, repo = repo)
  ledger <- classify_forecast_evidence(occurrences, fixtures)
  validate_forecast_ledger(ledger, fixtures)
  selected <- derive_forecast_views(ledger)
  distributions <- extract_selected_distributions(selected, repo = repo)

  coverage <- merge(
    fixtures[, c("match_id", "stage", "round", "kickoff_utc", "home_team", "away_team")],
    aggregate(
      cbind(strict = ledger$strict_eligible, exploratory = ledger$exploratory_eligible) ~ match_id,
      data = ledger,
      FUN = function(x) any(x %in% TRUE)
    ),
    by = "match_id",
    all.x = TRUE
  )
  coverage$strict[is.na(coverage$strict)] <- FALSE
  coverage$exploratory[is.na(coverage$exploratory)] <- FALSE
  coverage$status <- ifelse(coverage$strict, "verified", ifelse(coverage$exploratory, "documented", "missing_or_rejected"))

  paths <- c(
    fixtures = file.path(output_dir, "fixture_results.csv"),
    ledger_csv = file.path(output_dir, "forecast_ledger.csv"),
    ledger_rds = file.path(output_dir, "forecast_ledger.rds"),
    selected = file.path(output_dir, "selected_forecasts.csv"),
    distributions = file.path(output_dir, "selected_distributions.rds"),
    coverage = file.path(output_dir, "forecast_coverage.csv"),
    rejections = file.path(output_dir, "rejection_summary.csv")
  )
  write.csv(fixtures, paths["fixtures"], row.names = FALSE)
  write.csv(ledger, paths["ledger_csv"], row.names = FALSE)
  saveRDS(ledger, paths["ledger_rds"])
  write.csv(selected, paths["selected"], row.names = FALSE)
  saveRDS(distributions, paths["distributions"])
  write.csv(coverage, paths["coverage"], row.names = FALSE)
  rejection_summary <- as.data.frame(table(
    evidence_tier = ledger$evidence_tier,
    primary_reason = ifelse(is.na(ledger$primary_reason), "none", ledger$primary_reason)
  ), stringsAsFactors = FALSE)
  rejection_summary <- rejection_summary[rejection_summary$Freq > 0, , drop = FALSE]
  write.csv(rejection_summary, paths["rejections"], row.names = FALSE)

  source_sha <- run_git_read(c("rev-parse", source_ref), repo = repo)[1]
  manifest_path <- file.path(output_dir, "bundle_manifest.csv")
  write_checksum_manifest(unname(paths), source_ref, source_sha, manifest_path)
  list(paths = c(paths, manifest = manifest_path), fixtures = fixtures, ledger = ledger, selected = selected, coverage = coverage)
}
