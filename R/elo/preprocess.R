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
  if (!nrow(results) || is.null(eloratings_results) || !nrow(eloratings_results)) {
    results$score_source <- if ("score_source" %in% names(results)) results$score_source else "martj42"
    results$score_source[is.na(results$home_score) | is.na(results$away_score)] <- NA_character_
    return(results)
  }

  results$date <- as.Date(results$date)
  eloratings_results$date <- as.Date(eloratings_results$date)

  if (!"score_source" %in% names(results)) {
    results$score_source <- ifelse(
      is.na(results$home_score) | is.na(results$away_score),
      NA_character_,
      "martj42"
    )
  }

  results$key <- paste(results$date, results$home_team, results$away_team, sep = "\r")
  eloratings_results$key <- paste(
    eloratings_results$date,
    eloratings_results$home_team,
    eloratings_results$away_team,
    sep = "\r"
  )
  eloratings_results$reverse_key <- paste(
    eloratings_results$date,
    eloratings_results$away_team,
    eloratings_results$home_team,
    sep = "\r"
  )
  fallback_idx <- match(results$key, eloratings_results$key)
  needs_score <- is.na(results$home_score) | is.na(results$away_score)
  eligible <- needs_score &
    results$tournament %in% tournaments &
    !is.na(fallback_idx)

  if (any(eligible)) {
    matched <- fallback_idx[eligible]
    results$home_score[eligible] <- eloratings_results$home_score[matched]
    results$away_score[eligible] <- eloratings_results$away_score[matched]
    results$score_source[eligible] <- "eloratings_fallback"
  }

  reverse_idx <- match(results$key, eloratings_results$reverse_key)
  needs_score <- is.na(results$home_score) | is.na(results$away_score)
  reverse_eligible <- needs_score &
    results$tournament %in% tournaments &
    !is.na(reverse_idx)

  if (any(reverse_eligible)) {
    matched <- reverse_idx[reverse_eligible]
    results$home_score[reverse_eligible] <- eloratings_results$away_score[matched]
    results$away_score[reverse_eligible] <- eloratings_results$home_score[matched]
    results$score_source[reverse_eligible] <- "eloratings_fallback"
  }

  results$key <- NULL
  results
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
                            score_fallback_audit_path = "data/processed/eloratings_score_fallback_audit.csv") {
  
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
      str_split(row$alt_names, "\\|")[1]
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
