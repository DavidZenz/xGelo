#' xGelo Forecasting Layer - Output Generation
#'
#' Formats and saves forecast outputs
#'
#' @author xGelo project
#' @date 2026-06-03

#' Generate forecast for a fixture
#'
#' @param home_team Home team canonical name
#' @param away_team Away team canonical name
#' @param date Match date (optional)
#' @param venue Match venue
#' @param output_dir Output directory for forecast files
#' @param ... Additional arguments to pass to simulate_fixture
#' @return List with forecast data, scoreline distribution, and output paths
#' @export
generate_forecast <- function(
    home_team,
    away_team,
    date = NULL,
    venue = "home",
    output_dir = "outputs/forecasts",
    ...
) {

  suppressPackageStartupMessages({
    library(dplyr)
  })

  # Run simulation
  result <- do.call(simulate_fixture, list(
    home_team = home_team,
    away_team = away_team,
    date = date,
    venue = venue,
    ...
  ))

  sanitize_fixture_part <- function(value) {
    cleaned <- gsub("[^A-Za-z0-9_-]+", "_", value)
    cleaned <- gsub("_+", "_", cleaned)
    gsub("^_|_$", "", cleaned)
  }

  # Create fixture ID
  if (!is.null(date)) {
    fixture_id <- paste(home_team, "vs", away_team, as.character(date), sep = "_")
    file_fixture_id <- paste(
      sanitize_fixture_part(home_team),
      "vs",
      sanitize_fixture_part(away_team),
      sanitize_fixture_part(as.character(date)),
      sep = "_"
    )
    date_str <- as.character(date)
  } else {
    fixture_id <- paste(home_team, "vs", away_team, sep = "_")
    file_fixture_id <- paste(
      sanitize_fixture_part(home_team),
      "vs",
      sanitize_fixture_part(away_team),
      sep = "_"
    )
    date_str <- "unknown"
  }

  # Format output
  forecast <- data.frame(
    fixture_id = fixture_id,
    home_team = home_team,
    away_team = away_team,
    date = date_str,
    venue = venue,
    home_goals_expected = result$expected_home,
    away_goals_expected = result$expected_away,
    win_probability = result$win_prob,
    draw_probability = result$draw_prob,
    loss_probability = result$loss_prob,
    predicted_outcome = result$predicted_outcome,
    most_likely_score = result$most_likely_score,
    most_likely_home_goals = result$most_likely_home_goals,
    most_likely_away_goals = result$most_likely_away_goals,
    most_likely_score_probability = result$most_likely_score_probability,
    rounded_expected_score = result$rounded_expected_score,
    rounded_expected_home_goals = result$rounded_expected_home_goals,
    rounded_expected_away_goals = result$rounded_expected_away_goals,
    over_2_5_probability = result$over_2_5_probability,
    under_2_5_probability = result$under_2_5_probability,
    both_teams_to_score_probability = result$both_teams_to_score_probability,
    n_sim = result$n_sim,
    model_version = "1.1",
    timestamp = as.character(Sys.time()),
    stringsAsFactors = FALSE
  )

  # Ensure output directory exists
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  scorelines_dir <- file.path(output_dir, "scorelines")
  if (!dir.exists(scorelines_dir)) {
    dir.create(scorelines_dir, recursive = TRUE)
  }

  # Save to CSV
  output_path <- file.path(output_dir, paste0(file_fixture_id, ".csv"))
  scorelines_path <- file.path(scorelines_dir, paste0(file_fixture_id, "_scorelines.csv"))
  scorelines <- if (!is.null(result$scoreline_distribution)) {
    result$scoreline_distribution
  } else {
    result$top_scorelines
  }

  write.csv(forecast, output_path, row.names = FALSE)
  write.csv(scorelines, scorelines_path, row.names = FALSE)

  message(paste("Forecast saved to", output_path))
  message(paste("Scoreline distribution saved to", scorelines_path))

  return(list(
    forecast = forecast,
    scorelines = scorelines,
    path = output_path,
    forecast_path = output_path,
    scorelines_path = scorelines_path
  ))
}

#' Generate forecasts for multiple fixtures
#'
#' @param fixtures Data frame with home_team, away_team, date, venue columns
#' @param output_dir Output directory
#' @param ... Additional arguments to pass to generate_forecast
#' @return List of forecast results
#' @export
generate_batch_forecasts <- function(
    fixtures,
    output_dir = "outputs/forecasts",
    ...
) {

  results <- list()

  for (i in 1:nrow(fixtures)) {
    fixt <- fixtures[i, ]
    result <- generate_forecast(
      home_team = fixt$home_team,
      away_team = fixt$away_team,
      date = if (!is.na(fixt$date)) as.Date(fixt$date) else NULL,
      venue = ifelse(is.na(fixt$venue), "home", fixt$venue),
      output_dir = output_dir,
      ...
    )
    results[[length(results) + 1]] <- result
    message(paste("Generated forecast", i, "of", nrow(fixtures)))
  }

  return(results)
}

#' Wrapper to run test forecasts
#' @export
run_output_generation <- function() {
  # Test with some example fixtures
  test_fixtures <- data.frame(
    home_team = c("Spain", "Germany", "France"),
    away_team = c("Italy", "Netherlands", "England"),
    date = as.Date(c("2026-06-10", "2026-06-11", "2026-06-12")),
    venue = c("home", "home", "neutral"),
    stringsAsFactors = FALSE
  )

  message("Generating test forecasts...")
  results <- generate_batch_forecasts(test_fixtures)

  message(paste("Generated", length(results), "forecasts"))

  # Print summary
  for (r in results) {
    cat("\nFixture:", r$forecast$fixture_id, "\n")
    cat("  Win:", round(r$forecast$win_probability, 3),
        "Draw:", round(r$forecast$draw_probability, 3),
        "Loss:", round(r$forecast$loss_probability, 3), "\n")
    cat("  Expected goals:", round(r$forecast$home_goals_expected, 2), "-",
        round(r$forecast$away_goals_expected, 2), "\n")
    cat("  Predicted outcome:", r$forecast$predicted_outcome,
        "Modal score:", r$forecast$most_likely_score, "\n")
  }

  return(results)
}
