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
  scored_worldcup$key <- paste(
    scored_worldcup$date,
    scored_worldcup$home_team_canonical,
    scored_worldcup$away_team_canonical
  )
  fixtures$key <- paste(fixtures$date, fixtures$home_team, fixtures$away_team)
  scored_worldcup <- scored_worldcup[scored_worldcup$key %in% fixtures$key, , drop = FALSE]
}

if (nrow(scored_worldcup) > 0) {
  matched <- merge(
    scored_worldcup[, c("key", "date", "home_team_canonical", "away_team_canonical", "home_score", "away_score")],
    fixtures[, c("key", "is_completed", "actual_home_goals", "actual_away_goals")],
    by = "key",
    all.x = TRUE
  )

  stale <- matched[
    is.na(matched$is_completed) |
      !matched$is_completed |
      matched$home_score != matched$actual_home_goals |
      matched$away_score != matched$actual_away_goals,
    ,
    drop = FALSE
  ]

  if (nrow(stale) > 0) {
    print(stale)
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
