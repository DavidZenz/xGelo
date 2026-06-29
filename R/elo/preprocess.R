#' Elo Data Preprocessing for xGelo
#'
#' This script preprocesses martj42 results data for Elo rating computation.
#' It loads the raw results, maps team names to canonical names, adds result
#' columns, and prepares the data for the Elo computation function.
#'
#' @author xGelo project
#' @date 2026-06-03

xgelo_eloratings_team_overrides <- function() {
  c(
    CH = "Switzerland",
    SQ = "Scotland",
    KO = "Korea Republic",
    KR = "Korea Republic",
    CI = "Ivory Coast",
    TR = "Turkey",
    QA = "Qatar"
  )
}

xgelo_score_fallback_aliases <- function(team_map_path = "data/raw/team_name_map.csv") {
  normalize <- function(x) {
    x <- trimws(as.character(x))
    x <- iconv(x, from = "", to = "ASCII//TRANSLIT", sub = "")
    tolower(x)
  }

  aliases <- character(0)
  if (file.exists(team_map_path)) {
    team_map <- read.csv(team_map_path, stringsAsFactors = FALSE)
    for (i in seq_len(nrow(team_map))) {
      canonical <- team_map$canonical_name[[i]]
      names_i <- c(team_map$source_name[[i]], canonical)
      if ("alt_names" %in% names(team_map) && !is.na(team_map$alt_names[[i]]) && nzchar(team_map$alt_names[[i]])) {
        names_i <- c(names_i, strsplit(team_map$alt_names[[i]], "\\|")[[1]])
      }
      keys <- normalize(names_i[nzchar(names_i)])
      aliases[keys] <- canonical
    }
  }
  aliases
}

xgelo_canonicalize_fallback_team <- function(team, aliases = character(0)) {
  normalize <- function(x) {
    x <- trimws(as.character(x))
    x <- iconv(x, from = "", to = "ASCII//TRANSLIT", sub = "")
    tolower(x)
  }

  key <- normalize(team)
  matched <- aliases[key]
  out <- ifelse(!is.na(matched), unname(matched), as.character(team))
  out[is.na(team)] <- NA_character_
  out
}

apply_score_fallback <- function(
    results,
    fallback_results,
    fallback_source,
    tournaments = c("FIFA World Cup"),
    date_tolerance_days = 0L,
    team_map_path = "data/raw/team_name_map.csv") {
  if (!nrow(results) || is.null(fallback_results) || !nrow(fallback_results)) {
    results$score_source <- if ("score_source" %in% names(results)) results$score_source else "martj42"
    results$score_source[is.na(results$home_score) | is.na(results$away_score)] <- NA_character_
    return(results)
  }

  required <- c("date", "home_team", "away_team", "home_score", "away_score")
  missing_cols <- setdiff(required, names(fallback_results))
  if (length(missing_cols) > 0) {
    stop(
      paste("Fallback results missing required columns:", paste(missing_cols, collapse = ", ")),
      call. = FALSE
    )
  }

  results$date <- as.Date(results$date)
  fallback_results$date <- as.Date(fallback_results$date)

  if (!"score_source" %in% names(results)) {
    results$score_source <- ifelse(
      is.na(results$home_score) | is.na(results$away_score),
      NA_character_,
      "martj42"
    )
  }

  aliases <- xgelo_score_fallback_aliases(team_map_path)
  results$.fallback_home_team <- xgelo_canonicalize_fallback_team(results$home_team, aliases)
  results$.fallback_away_team <- xgelo_canonicalize_fallback_team(results$away_team, aliases)
  fallback_results$.fallback_home_team <- xgelo_canonicalize_fallback_team(fallback_results$home_team, aliases)
  fallback_results$.fallback_away_team <- xgelo_canonicalize_fallback_team(fallback_results$away_team, aliases)

  fallback_results$.fallback_key <- paste(
    fallback_results$date,
    fallback_results$.fallback_home_team,
    fallback_results$.fallback_away_team,
    sep = "\r"
  )
  fallback_results$.fallback_reverse_key <- paste(
    fallback_results$date,
    fallback_results$.fallback_away_team,
    fallback_results$.fallback_home_team,
    sep = "\r"
  )

  offsets <- unique(c(0L, as.integer(seq(-date_tolerance_days, date_tolerance_days))))
  for (offset in offsets) {
    result_key <- paste(
      results$date + offset,
      results$.fallback_home_team,
      results$.fallback_away_team,
      sep = "\r"
    )
    fallback_idx <- match(result_key, fallback_results$.fallback_key)
    needs_score <- is.na(results$home_score) | is.na(results$away_score)
    eligible <- needs_score &
      results$tournament %in% tournaments &
      !is.na(fallback_idx)

    if (any(eligible)) {
      matched <- fallback_idx[eligible]
      results$home_score[eligible] <- fallback_results$home_score[matched]
      results$away_score[eligible] <- fallback_results$away_score[matched]
      results$score_source[eligible] <- fallback_source
    }

    reverse_idx <- match(result_key, fallback_results$.fallback_reverse_key)
    needs_score <- is.na(results$home_score) | is.na(results$away_score)
    reverse_eligible <- needs_score &
      results$tournament %in% tournaments &
      !is.na(reverse_idx)

    if (any(reverse_eligible)) {
      matched <- reverse_idx[reverse_eligible]
      results$home_score[reverse_eligible] <- fallback_results$away_score[matched]
      results$away_score[reverse_eligible] <- fallback_results$home_score[matched]
      results$score_source[reverse_eligible] <- fallback_source
    }
  }

  results$.fallback_home_team <- NULL
  results$.fallback_away_team <- NULL
  results
}

read_eloratings_team_dictionary <- function(path = "data/raw/eloratings/en.teams.tsv") {
  if (!file.exists(path)) {
    stop(paste("EloRatings team dictionary not found:", path), call. = FALSE)
  }

  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  parsed <- strsplit(lines[nzchar(lines)], "\t", fixed = TRUE)
  rows <- lapply(parsed, function(fields) {
    if (length(fields) < 2 || grepl("_loc$", fields[[1]])) {
      return(NULL)
    }
    data.frame(
      eloratings_code = fields[[1]],
      eloratings_name = fields[[2]],
      stringsAsFactors = FALSE
    )
  })
  dict <- do.call(rbind, rows[!vapply(rows, is.null, logical(1))])
  overrides <- xgelo_eloratings_team_overrides()
  override_idx <- match(names(overrides), dict$eloratings_code)
  dict$team_name <- dict$eloratings_name
  dict$team_name[override_idx[!is.na(override_idx)]] <- unname(overrides[!is.na(override_idx)])
  dict
}

read_eloratings_latest_results <- function(
    latest_path = "data/raw/eloratings/latest.tsv",
    teams_path = "data/raw/eloratings/en.teams.tsv",
    tournaments = c("WC")) {
  if (!file.exists(latest_path)) {
    stop(paste("EloRatings latest results not found:", latest_path), call. = FALSE)
  }

  team_dict <- read_eloratings_team_dictionary(teams_path)
  lines <- readLines(latest_path, warn = FALSE, encoding = "UTF-8")
  lines <- lines[nzchar(lines)]
  if (!length(lines)) {
    return(data.frame())
  }

  fields <- strsplit(lines, "\t", fixed = TRUE)
  rows <- lapply(fields, function(x) {
    if (length(x) < 8) {
      return(NULL)
    }
    data.frame(
      date = as.Date(sprintf("%s-%s-%s", x[[1]], x[[2]], x[[3]])),
      home_code = x[[4]],
      away_code = x[[5]],
      home_score = suppressWarnings(as.integer(x[[6]])),
      away_score = suppressWarnings(as.integer(x[[7]])),
      eloratings_tournament = x[[8]],
      stringsAsFactors = FALSE
    )
  })
  results <- do.call(rbind, rows[!vapply(rows, is.null, logical(1))])
  if (!nrow(results)) {
    return(results)
  }

  results <- results[
    results$eloratings_tournament %in% tournaments &
      !is.na(results$home_score) &
      !is.na(results$away_score),
    ,
    drop = FALSE
  ]

  results$home_team <- team_dict$team_name[match(results$home_code, team_dict$eloratings_code)]
  results$away_team <- team_dict$team_name[match(results$away_code, team_dict$eloratings_code)]
  results <- results[!is.na(results$home_team) & !is.na(results$away_team), , drop = FALSE]
  results
}

apply_eloratings_score_fallback <- function(
    results,
    eloratings_results,
    tournaments = c("FIFA World Cup")) {
  apply_score_fallback(
    results = results,
    fallback_results = eloratings_results,
    fallback_source = "eloratings_fallback",
    tournaments = tournaments,
    date_tolerance_days = 0L
  )
}

download_eloratings_fallback_files <- function(
    output_dir = "data/raw/eloratings",
    latest_url = "https://www.eloratings.net/latest.tsv",
    teams_url = "https://www.eloratings.net/en.teams.tsv") {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  latest_path <- file.path(output_dir, "latest.tsv")
  teams_path <- file.path(output_dir, "en.teams.tsv")
  download.file(latest_url, latest_path, mode = "wb", quiet = TRUE)
  download.file(teams_url, teams_path, mode = "wb", quiet = TRUE)

  data.frame(
    file = c(latest_path, teams_path),
    downloaded_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    stringsAsFactors = FALSE
  )
}

read_espn_scoreboard_results <- function(
    scoreboard_dir = "data/raw/espn",
    scoreboard_files = NULL) {
  if (is.null(scoreboard_files)) {
    if (!dir.exists(scoreboard_dir)) {
      return(data.frame())
    }
    scoreboard_files <- list.files(scoreboard_dir, pattern = "\\.json$", full.names = TRUE)
  }
  scoreboard_files <- scoreboard_files[file.exists(scoreboard_files)]
  if (!length(scoreboard_files)) {
    return(data.frame())
  }

  rows <- list()
  for (path in scoreboard_files) {
    payload <- jsonlite::fromJSON(path, simplifyVector = FALSE)
    events <- payload$events
    if (is.null(events) || !length(events)) {
      next
    }
    for (event in events) {
      competition <- event$competitions[[1]]
      completed <- isTRUE(competition$status$type$completed)
      if (!completed) {
        next
      }
      competitors <- competition$competitors
      if (is.null(competitors) || length(competitors) < 2) {
        next
      }
      home <- NULL
      away <- NULL
      for (competitor in competitors) {
        if (identical(competitor$homeAway, "home")) home <- competitor
        if (identical(competitor$homeAway, "away")) away <- competitor
      }
      if (is.null(home) || is.null(away)) {
        next
      }
      home_score <- suppressWarnings(as.integer(home$score))
      away_score <- suppressWarnings(as.integer(away$score))
      if (is.na(home_score) || is.na(away_score)) {
        next
      }

      event_date <- competition$date
      if (is.null(event_date) || !nzchar(event_date)) {
        event_date <- event$date
      }
      event_links <- event$links
      source_url <- NA_character_
      if (!is.null(event_links) && length(event_links) > 0 && !is.null(event_links[[1]]$href)) {
        source_url <- event_links[[1]]$href
      }

      rows[[length(rows) + 1L]] <- data.frame(
        date = as.Date(substr(event_date, 1L, 10L)),
        home_team = home$team$displayName,
        away_team = away$team$displayName,
        home_score = home_score,
        away_score = away_score,
        espn_event_id = event$id,
        espn_event_date = event_date,
        espn_status = competition$status$type$description,
        source_url = source_url,
        stringsAsFactors = FALSE
      )
    }
  }

  if (!length(rows)) {
    return(data.frame())
  }
  unique(do.call(rbind, rows))
}

apply_espn_score_fallback <- function(
    results,
    espn_results,
    tournaments = c("FIFA World Cup"),
    date_tolerance_days = 1L,
    team_map_path = "data/raw/team_name_map.csv") {
  apply_score_fallback(
    results = results,
    fallback_results = espn_results,
    fallback_source = "espn_scoreboard_fallback",
    tournaments = tournaments,
    date_tolerance_days = date_tolerance_days,
    team_map_path = team_map_path
  )
}

read_verified_score_fallback_results <- function(
    path = "data/raw/verified_score_fallbacks.csv") {
  if (!file.exists(path)) {
    return(data.frame())
  }

  results <- read.csv(path, stringsAsFactors = FALSE)
  required <- c("date", "home_team", "away_team", "home_score", "away_score")
  missing_cols <- setdiff(required, names(results))
  if (length(missing_cols) > 0) {
    stop(
      paste("Verified score fallback file missing required columns:", paste(missing_cols, collapse = ", ")),
      call. = FALSE
    )
  }

  results$date <- as.Date(results$date)
  results$home_score <- suppressWarnings(as.integer(results$home_score))
  results$away_score <- suppressWarnings(as.integer(results$away_score))
  results[!is.na(results$date) & !is.na(results$home_score) & !is.na(results$away_score), , drop = FALSE]
}

apply_verified_score_fallback <- function(
    results,
    verified_results,
    tournaments = c("FIFA World Cup"),
    team_map_path = "data/raw/team_name_map.csv") {
  apply_score_fallback(
    results = results,
    fallback_results = verified_results,
    fallback_source = "verified_score_fallback",
    tournaments = tournaments,
    date_tolerance_days = 0L,
    team_map_path = team_map_path
  )
}

worldcup_2026_scoreboard_dates <- function(
    today = Sys.Date(),
    tournament_start = Sys.getenv("XGELO_TOURNAMENT_START_DATE", "2026-06-11"),
    tournament_final = Sys.getenv("XGELO_TOURNAMENT_FINAL_DATE", "2026-07-19")) {
  today <- as.Date(today)
  tournament_start <- as.Date(tournament_start)
  tournament_final <- as.Date(tournament_final)
  if (is.na(today) || is.na(tournament_start) || is.na(tournament_final)) {
    stop("World Cup scoreboard dates must parse as ISO dates", call. = FALSE)
  }

  start_date <- if (today <= tournament_final) tournament_start else max(tournament_start, today - 2L)
  end_date <- if (today <= tournament_final) tournament_final else today + 1L
  seq.Date(start_date, end_date, by = "day")
}

download_espn_scoreboard_files <- function(
    output_dir = "data/raw/espn",
    dates = worldcup_2026_scoreboard_dates(),
    base_url = "https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/scoreboard") {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  dates <- as.Date(dates)
  out <- data.frame(
    file = character(0),
    date = character(0),
    downloaded_at = character(0),
    stringsAsFactors = FALSE
  )
  for (date in dates) {
    date <- as.Date(date, origin = "1970-01-01")
    date_string <- format(date, "%Y%m%d")
    path <- file.path(output_dir, paste0("scoreboard_", date_string, ".json"))
    url <- paste0(base_url, "?dates=", date_string)
    download.file(url, path, mode = "wb", quiet = TRUE)
    out <- rbind(
      out,
      data.frame(
        file = path,
        date = date_string,
        downloaded_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
        stringsAsFactors = FALSE
      )
    )
  }
  out
}

#' Preprocess martj42 results for Elo computation
#'
#' @param results_path Path to the martj42 results.csv file
#' @param team_map_path Path to the team name mapping CSV file
#' @param output_path Path to save the preprocessed data (default: "data/processed/elo_matches.csv")
#' @return Data frame with preprocessed matches
#' @export
preprocess_martj42 <- function(results_path = "data/raw/martj42/results.csv",
                            team_map_path = "data/raw/team_name_map.csv",
                            output_path = "data/processed/elo_matches.csv",
                            eloratings_latest_path = "data/raw/eloratings/latest.tsv",
                            eloratings_teams_path = "data/raw/eloratings/en.teams.tsv",
                            use_eloratings_fallback = file.exists(eloratings_latest_path) && file.exists(eloratings_teams_path),
                            score_fallback_audit_path = "data/processed/eloratings_score_fallback_audit.csv",
                            espn_scoreboard_dir = "data/raw/espn",
                            use_espn_fallback = dir.exists(espn_scoreboard_dir) && length(list.files(espn_scoreboard_dir, pattern = "\\.json$")) > 0,
                            espn_score_fallback_audit_path = "data/processed/espn_score_fallback_audit.csv",
                            verified_score_fallback_path = "data/raw/verified_score_fallbacks.csv",
                            use_verified_score_fallback = file.exists(verified_score_fallback_path),
                            verified_score_fallback_audit_path = "data/processed/verified_score_fallback_audit.csv") {
  
  # Load libraries
  suppressPackageStartupMessages({
    library(dplyr)
    library(lubridate)
    library(stringr)
  })
  
  # Load results
  if (!file.exists(results_path)) {
    stop(paste("Results file not found:", results_path))
  }
  
  results <- read.csv(results_path, stringsAsFactors = FALSE)
  
  message(paste("Loaded", nrow(results), "matches from", results_path))

  if (use_eloratings_fallback) {
    eloratings_results <- read_eloratings_latest_results(
      latest_path = eloratings_latest_path,
      teams_path = eloratings_teams_path,
      tournaments = c("WC")
    )
    results <- apply_eloratings_score_fallback(
      results = results,
      eloratings_results = eloratings_results,
      tournaments = c("FIFA World Cup")
    )
    fallback_rows <- results[!is.na(results$score_source) & results$score_source == "eloratings_fallback", , drop = FALSE]
    if (!dir.exists(dirname(score_fallback_audit_path))) {
      dir.create(dirname(score_fallback_audit_path), recursive = TRUE)
    }
    write.csv(fallback_rows, score_fallback_audit_path, row.names = FALSE)
    message(paste("Applied", nrow(fallback_rows), "EloRatings fallback scores."))
  } else {
    results$score_source <- ifelse(
      is.na(results$home_score) | is.na(results$away_score),
      NA_character_,
      "martj42"
    )
  }

  if (use_espn_fallback) {
    espn_results <- read_espn_scoreboard_results(scoreboard_dir = espn_scoreboard_dir)
    results <- apply_espn_score_fallback(
      results = results,
      espn_results = espn_results,
      tournaments = c("FIFA World Cup"),
      date_tolerance_days = 1L,
      team_map_path = team_map_path
    )
    fallback_rows <- results[!is.na(results$score_source) & results$score_source == "espn_scoreboard_fallback", , drop = FALSE]
    if (!dir.exists(dirname(espn_score_fallback_audit_path))) {
      dir.create(dirname(espn_score_fallback_audit_path), recursive = TRUE)
    }
    write.csv(fallback_rows, espn_score_fallback_audit_path, row.names = FALSE)
    message(paste("Applied", nrow(fallback_rows), "ESPN scoreboard fallback scores."))
  }

  if (use_verified_score_fallback) {
    verified_results <- read_verified_score_fallback_results(verified_score_fallback_path)
    results <- apply_verified_score_fallback(
      results = results,
      verified_results = verified_results,
      tournaments = c("FIFA World Cup"),
      team_map_path = team_map_path
    )
    fallback_rows <- results[!is.na(results$score_source) & results$score_source == "verified_score_fallback", , drop = FALSE]
    if (!dir.exists(dirname(verified_score_fallback_audit_path))) {
      dir.create(dirname(verified_score_fallback_audit_path), recursive = TRUE)
    }
    write.csv(fallback_rows, verified_score_fallback_audit_path, row.names = FALSE)
    message(paste("Applied", nrow(fallback_rows), "verified fallback scores."))
  }
  
  # Load team name mapping
  if (!file.exists(team_map_path)) {
    stop(paste("Team map file not found:", team_map_path))
  }
  
  team_map <- read.csv(team_map_path, stringsAsFactors = FALSE)
  
  message(paste("Loaded", nrow(team_map), "team mappings from", team_map_path))
  
  # Validate that team_map has required columns
  required_map_cols <- c("source_name", "canonical_name", "fifa_code")
  missing_map_cols <- setdiff(required_map_cols, names(team_map))
  if (length(missing_map_cols) > 0) {
    stop(paste("Team map missing required columns:", paste(missing_map_cols, collapse = ", ")))
  }
  
  # Validate results has required columns
  required_cols <- c("date", "home_team", "away_team", "home_score", "away_score", "neutral")
  missing_cols <- setdiff(required_cols, names(results))
  if (length(missing_cols) > 0) {
    stop(paste("Results missing required columns:", paste(missing_cols, collapse = ", ")))
  }
  
  # Create mapping from source_name to canonical_name
  # Handle pipe-delimited alt_names
  team_mapping <- list()
  for (i in 1:nrow(team_map)) {
    row <- team_map[i, ]
    source_name <- row$source_name
    canonical_name <- row$canonical_name
    fifa_code <- row$fifa_code
    
    # Split alt_names if present
    alt_names <- if (!is.na(row$alt_names) && nchar(row$alt_names) > 0) {
      str_split(row$alt_names, "\\|")[[1]]
    } else {
      character(0)
    }
    
    # Map all variations to canonical name
    all_names <- c(source_name, alt_names)
    for (name in all_names) {
      if (!is.na(name) && nchar(name) > 0) {
        team_mapping[[tolower(name)]] <- list(
          canonical_name = canonical_name,
          fifa_code = fifa_code,
          source_name = source_name
        )
      }
    }
  }
  
  # Function to map team name to canonical name
  map_team_name <- function(team_name) {
    if (is.na(team_name)) {
      return(NA_character_)
    }
    
    lower_name <- tolower(team_name)
    
    if (lower_name %in% names(team_mapping)) {
      return(team_mapping[[lower_name]]$canonical_name)
    } else {
      # Try fuzzy matching or return original
      return(team_name)
    }
  }
  
  # Function to map team name to FIFA code
  map_team_fifa <- function(team_name) {
    if (is.na(team_name)) {
      return(NA_character_)
    }
    
    lower_name <- tolower(team_name)
    
    if (lower_name %in% names(team_mapping)) {
      return(team_mapping[[lower_name]]$fifa_code)
    } else {
      return(NA_character_)
    }
  }
  
  # Preprocess results
  elo_matches <- results |>
    # Convert date to Date object
    mutate(date = as.Date(date)) |>
    
    # Map team names to canonical names
    mutate(
      home_team_canonical = sapply(home_team, map_team_name),
      away_team_canonical = sapply(away_team, map_team_name),
      home_team_fifa = sapply(home_team, map_team_fifa),
      away_team_fifa = sapply(away_team, map_team_fifa)
    ) |>
    
    # Determine result from scores
    mutate(
      result = case_when(
        home_score > away_score ~ 1.0,
        home_score == away_score ~ 0.5,
        home_score < away_score ~ 0.0
      )
    ) |>
    
    # Create match identifier
    mutate(
      match_id = paste(home_team_canonical, away_team_canonical, date, sep = "_")
    ) |>
    
    # Mark home/away
    mutate(
      is_home = !neutral
    ) |>
    
    # Sort chronologically (oldest first)
    arrange(date)
  
  # Check for unmapped teams
  unmapped_home <- which(is.na(elo_matches$home_team_fifa))
  unmapped_away <- which(is.na(elo_matches$away_team_fifa))
  
  if (length(unmapped_home) > 0) {
    warning(paste("Unmapped home teams:", 
                  paste(unique(elo_matches$home_team[unmapped_home]), collapse = ", ")))
  }
  if (length(unmapped_away) > 0) {
    warning(paste("Unmapped away teams:",
                  paste(unique(elo_matches$away_team[unmapped_away]), collapse = ", ")))
  }
  
  # Save preprocessed data
  if (!dir.exists(dirname(output_path))) {
    dir.create(dirname(output_path), recursive = TRUE)
  }
  
  write.csv(elo_matches, output_path, row.names = FALSE)
  
  message(paste("Preprocessed data saved to", output_path))
  message(paste("Total matches:", nrow(elo_matches)))
  message(paste("Date range:", min(elo_matches$date), "to", max(elo_matches$date)))
  message(paste("Unique teams:", length(unique(c(elo_matches$home_team_canonical, elo_matches$away_team_canonical)))))
  
  # Return the preprocessed data
  elo_matches
}

#' Preprocess and save Elo matches (wrapper for use in pipeline)
#'
#' @param results_path Path to results.csv
#' @param team_map_path Path to team_name_map.csv
#' @param output_path Path to save output
#' @return Path to saved file
#' @export
preprocess_and_save_elo_matches <- function(results_path = "data/raw/martj42/results.csv",
                                           team_map_path = "data/raw/team_name_map.csv",
                                           output_path = "data/processed/elo_matches.csv") {
  result <- preprocess_martj42(results_path, team_map_path, output_path)
  invisible(output_path)
}
