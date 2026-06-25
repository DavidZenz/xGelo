#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(jsonlite)
})

output_dir <- Sys.getenv("XGELO_OUTPUT_DIR", "outputs/dashboard_100k")
dashboard_path <- file.path(output_dir, "worldcup_dashboard_data.json")
matches_path <- "data/processed/elo_matches.csv"

if (!file.exists(dashboard_path)) {
  stop("Missing dashboard payload: ", dashboard_path, call. = FALSE)
}
if (!file.exists(matches_path)) {
  stop("Missing processed matches: ", matches_path, call. = FALSE)
}

matches <- read.csv(matches_path, stringsAsFactors = FALSE)
matches$date <- as.Date(matches$date)

dashboard <- jsonlite::fromJSON(dashboard_path, simplifyVector = TRUE)
fixtures <- dashboard$fixtures
fixtures$date <- as.Date(fixtures$date)
cutoff <- as.Date(dashboard$metadata$actual_results_cutoff_date)

scored_worldcup <- matches[
  matches$tournament == "FIFA World Cup" &
    matches$date <= cutoff &
    !is.na(matches$home_score) &
    !is.na(matches$away_score),
  ,
  drop = FALSE
]

if (nrow(scored_worldcup) > 0) {
  fixture_key <- paste(fixtures$date, fixtures$home_team, fixtures$away_team)
  fixture_reverse_key <- paste(fixtures$date, fixtures$away_team, fixtures$home_team)
  exact_fixture_index <- setNames(seq_len(nrow(fixtures)), fixture_key)
  reverse_fixture_index <- setNames(seq_len(nrow(fixtures)), fixture_reverse_key)

  stale <- data.frame()
  for (idx in seq_len(nrow(scored_worldcup))) {
    row <- scored_worldcup[idx, , drop = FALSE]
    key <- paste(row$date, row$home_team_canonical, row$away_team_canonical)
    fixture_idx <- unname(exact_fixture_index[key])
    reverse_match <- FALSE
    if (is.na(fixture_idx)) {
      fixture_idx <- unname(reverse_fixture_index[key])
      reverse_match <- !is.na(fixture_idx)
    }
    if (is.na(fixture_idx)) next

    fixture <- fixtures[fixture_idx, , drop = FALSE]
    expected_home <- as.integer(if (reverse_match) row$away_score[1] else row$home_score[1])
    expected_away <- as.integer(if (reverse_match) row$home_score[1] else row$away_score[1])
    fixture_completed <- fixture$is_completed %in% c(TRUE, "TRUE", "true", "1")
    if (
      !fixture_completed ||
        expected_home != fixture$actual_home_goals[1] ||
        expected_away != fixture$actual_away_goals[1]
    ) {
      stale <- rbind(
        stale,
        data.frame(
          date = row$date,
          source_home_team = row$home_team_canonical,
          source_away_team = row$away_team_canonical,
          fixture_home_team = fixture$home_team,
          fixture_away_team = fixture$away_team,
          expected_score = paste(expected_home, expected_away, sep = "-"),
          dashboard_score = fixture$actual_score,
          stringsAsFactors = FALSE
        )
      )
    }
  }

  if (nrow(stale) > 0) {
    print(stale, row.names = FALSE)
    stop("Dashboard payload is stale relative to scored World Cup fixtures.", call. = FALSE)
  }
}

completed_fixture_count <- sum(fixtures$is_completed, na.rm = TRUE)
metadata_completed <- as.integer(dashboard$metadata$completed_group_matches)
if (!identical(metadata_completed, as.integer(completed_fixture_count))) {
  stop(
    sprintf(
      "Dashboard completed_group_matches mismatch: metadata=%s fixtures=%s",
      dashboard$metadata$completed_group_matches,
      completed_fixture_count
    ),
    call. = FALSE
  )
}

message(sprintf(
  "Dashboard result freshness OK: %s completed fixtures through %s",
  completed_fixture_count,
  cutoff
))
