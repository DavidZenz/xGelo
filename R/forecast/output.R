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
#' @return Path to saved forecast CSV
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
  
  # Create fixture ID
  if (!is.null(date)) {
    fixture_id <- paste(home_team, "vs", away_team, as.character(date), sep = "_")
    date_str <- as.character(date)
  } else {
    fixture_id <- paste(home_team, "vs", away_team, sep = "_")
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
    model_version = "1.0",
    timestamp = as.character(Sys.time()),
    stringsAsFactors = FALSE
  )
  
  # Ensure output directory exists
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  # Save to CSV
  output_path <- file.path(output_dir, paste0(fixture_id, ".csv"))
  write.csv(forecast, output_path, row.names = FALSE)
  
  message(paste("Forecast saved to", output_path))
  
  return(list(forecast = forecast, path = output_path))
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
  }
  
  return(results)
}
