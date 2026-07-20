benchmark_test_editions <- function() {
  data.frame(
    edition_id = c(
      paste0("wc", c(2002, 2006, 2010, 2014, 2018, 2022)),
      paste0("euro", c(2004, 2008, 2012, 2016, 2020, 2024))
    ),
    competition_id = rep(c("world_cup", "euro"), each = 6),
    edition_year = c(2002, 2006, 2010, 2014, 2018, 2022, 2004, 2008, 2012, 2016, 2020, 2024),
    played_year = c(2002, 2006, 2010, 2014, 2018, 2022, 2004, 2008, 2012, 2016, 2021, 2024),
    expected_fixture_count = c(rep(64L, 6), rep(31L, 3), rep(51L, 3)),
    format_id = c(rep("wc32_r16", 6), rep("euro16_qf", 3), rep("euro24_r16_best4third", 3)),
    stringsAsFactors = FALSE
  )
}

synthetic_benchmark_registries <- function() {
  tournaments <- benchmark_test_editions()
  tournaments$schema_version <- "1.0"
  tournaments$opener_date <- as.Date(paste0(tournaments$played_year, "-06-01"))
  tournaments$final_date <- tournaments$opener_date + 30
  tournaments$headline_weight <- 1 / 12
  tournaments$source_id <- "synthetic"
  tournaments$source_sha256 <- strrep("a", 64)

  teams <- data.frame(
    schema_version = "1.0",
    team_id = sprintf("team_%03d", 1:32),
    fifa_code = sprintf("%03d", 1:32),
    canonical_name = paste("Team", 1:32),
    aliases = "",
    historical_entity_id = NA_character_,
    stringsAsFactors = FALSE
  )

  fixtures <- do.call(rbind, lapply(seq_len(nrow(tournaments)), function(i) {
    tournament <- tournaments[i, ]
    n <- tournament$expected_fixture_count
    n_dates <- if (tournament$edition_id == "wc2022") 23L else if (
      tournament$edition_id %in% c("euro2020", "euro2024")
    ) 22L else if (tournament$competition_id == "world_cup") 25L else 19L
    completion_dates <- tournament$opener_date + rep(seq_len(n_dates) - 1L, length.out = n)
    home_index <- ((seq_len(n) - 1L) %% 32L) + 1L
    away_index <- (home_index %% 32L) + 1L
    data.frame(
      schema_version = "1.0",
      edition_id = tournament$edition_id,
      fixture_id = sprintf("%s_%03d", tournament$edition_id, seq_len(n)),
      source_match_id = sprintf("synthetic_%s_%03d", tournament$edition_id, seq_len(n)),
      stage_id = ifelse(seq_len(n) <= n - 15L, "group", "knockout"),
      group_id = ifelse(seq_len(n) <= n - 15L, "A", NA_character_),
      round_id = ifelse(seq_len(n) <= n - 15L, "group", "knockout"),
      home_team_id = teams$team_id[home_index],
      away_team_id = teams$team_id[away_index],
      scheduled_date = completion_dates,
      actual_completion_date = completion_dates,
      time_precision = "date",
      boundary_id = paste(tournament$edition_id, completion_dates, sep = "__"),
      venue_country = "ZZ",
      neutral = TRUE,
      venue_role = "neutral",
      home_is_host = FALSE,
      away_is_host = FALSE,
      regulation_home_goals = 1L,
      regulation_away_goals = 0L,
      final_home_goals = 1L,
      final_away_goals = 0L,
      went_extra_time = FALSE,
      went_penalties = FALSE,
      winner_team_id = teams$team_id[home_index],
      status = "completed",
      fit_eligible = TRUE,
      score_eligible = TRUE,
      exclusion_reason = "",
      result_source = "synthetic",
      result_source_date = completion_dates,
      source_license = "test-only",
      row_sha256 = strrep("b", 64),
      stringsAsFactors = FALSE
    )
  }))
  rownames(fixtures) <- NULL
  extra_time_row <- which(fixtures$stage_id == "knockout")[1]
  fixtures$final_home_goals[extra_time_row] <- 2L
  fixtures$went_extra_time[extra_time_row] <- TRUE

  formats <- data.frame(
    schema_version = "1.0",
    format_id = c("wc32_r16", "euro16_qf", "euro24_r16_best4third"),
    team_count = c(32L, 16L, 24L),
    group_count = c(8L, 4L, 6L),
    group_advancers = c(2L, 2L, 2L),
    best_third_advancers = c(0L, 0L, 4L),
    first_knockout_stage = c("round_of_16", "quarterfinal", "round_of_16"),
    stringsAsFactors = FALSE
  )
  route_rules <- data.frame(
    schema_version = "1.0",
    format_id = formats$format_id,
    rule_id = paste0(formats$format_id, "__default"),
    source_stage = "group",
    destination_stage = formats$first_knockout_stage,
    route_key = c("top2", "top2", "top2_plus_best4third"),
    stringsAsFactors = FALSE
  )

  updating <- do.call(rbind, lapply(split(fixtures, fixtures$edition_id), function(rows) {
    dates <- sort(unique(as.Date(rows$actual_completion_date)))
    data.frame(
      schema_version = "1.0",
      boundary_id = paste(rows$edition_id[1], dates, sep = "__"),
      edition_id = rows$edition_id[1],
      sequence = seq_along(dates),
      track = "updating",
      assessment_date = dates,
      evidence_cutoff_exclusive = dates,
      prior_boundary_id = c(NA_character_, paste(rows$edition_id[1], head(dates, -1L), sep = "__")),
      fixture_count = vapply(dates, function(d) sum(as.Date(rows$actual_completion_date) == d), integer(1)),
      completed_input_count = vapply(dates, function(d) sum(as.Date(rows$actual_completion_date) < d), integer(1)),
      status = "frozen",
      boundary_sha256 = strrep("c", 64),
      stringsAsFactors = FALSE
    )
  }))
  frozen <- data.frame(
    schema_version = "1.0",
    boundary_id = paste0(tournaments$edition_id, "__frozen"),
    edition_id = tournaments$edition_id,
    sequence = 0L,
    track = "frozen",
    assessment_date = tournaments$opener_date,
    evidence_cutoff_exclusive = tournaments$opener_date,
    prior_boundary_id = NA_character_,
    fixture_count = tournaments$expected_fixture_count,
    completed_input_count = 0L,
    status = "frozen",
    boundary_sha256 = strrep("d", 64),
    stringsAsFactors = FALSE
  )

  corrections <- data.frame(
    schema_version = "1.0",
    correction_id = "synthetic_extra_time",
    fixture_id = fixtures$fixture_id[extra_time_row],
    field = "regulation_home_goals",
    original_value = "2",
    corrected_value = "1",
    source_title = "Synthetic official match report",
    source_url = "https://example.invalid/official-report",
    access_date = as.Date("2026-07-20"),
    license = "test-only",
    rationale = "Separate regulation and extra-time goals",
    reviewer = "test-suite",
    verification_status = "verified",
    source_artifact_sha256 = strrep("e", 64),
    row_sha256 = strrep("f", 64),
    stringsAsFactors = FALSE
  )

  list(
    tournaments = tournaments,
    fixtures = fixtures,
    teams = teams,
    formats = formats,
    route_rules = route_rules,
    corrections = corrections,
    boundaries = rbind(frozen, updating)
  )
}

synthetic_benchmark_history <- function(include_wc2026 = FALSE) {
  history <- data.frame(
    fixture_id = paste0("history_", 1:6),
    edition_id = rep("history", 6),
    actual_completion_date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-02", "2024-06-03", "2024-06-04", "2024-06-05")),
    home_team_id = rep(c("team_001", "team_002"), 3),
    away_team_id = rep(c("team_002", "team_001"), 3),
    regulation_home_goals = c(1L, 0L, 2L, 1L, 0L, 3L),
    regulation_away_goals = c(0L, 0L, 1L, 1L, 2L, 0L),
    stringsAsFactors = FALSE
  )
  if (include_wc2026) {
    history <- rbind(history, data.frame(
      fixture_id = "wc2026_001", edition_id = "wc2026",
      actual_completion_date = as.Date("2026-06-11"),
      home_team_id = "team_001", away_team_id = "team_002",
      regulation_home_goals = 4L, regulation_away_goals = 0L,
      stringsAsFactors = FALSE
    ))
  }
  history
}

synthetic_format_fixtures <- function() {
  data.frame(
    format_id = c("wc32_r16", "euro16_qf", "euro24_r16_best4third"),
    fixture_id = c("wc2002_001", "euro2004_001", "euro2016_001"),
    stage_id = c("round_of_16", "quarterfinal", "round_of_16"),
    route_key = c("top2", "top2", "top2_plus_best4third"),
    stringsAsFactors = FALSE
  )
}

fixed_benchmark_score_grid <- function() {
  grid <- expand.grid(home_goals = 0:2, away_goals = 0:2)
  grid$probability <- c(0.18, 0.15, 0.07, 0.17, 0.16, 0.08, 0.08, 0.07, 0.04)
  grid
}

recording_benchmark_adapter <- function(recorder = new.env(parent = emptyenv())) {
  recorder$calls <- 0L
  adapter <- function(data) {
    recorder$calls <- recorder$calls + 1L
    recorder$last_data <- data
    data
  }
  attr(adapter, "recorder") <- recorder
  adapter
}
