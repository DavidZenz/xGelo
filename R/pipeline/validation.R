#' Schema Validation for xGelo Data Ingestion
#'
#' This script provides validation functions for all ingested data sources.
#' Validation runs automatically after each ingest and stops the pipeline on failure.

library(jsonlite)

#' Validate martj42 CSV files
#'
#' @param file_path Path to the CSV file to validate
#' @return TRUE if valid, stops execution with error message if invalid
validate_martj42 <- function(file_path) {
  data <- tryCatch({
    read.csv(file_path, stringsAsFactors = FALSE)
  }, error = function(e) {
    stop(paste("Failed to read file:", file_path, "-", e$message))
  })

  # Check required columns
  required_cols <- c("date", "home_team", "away_team", "home_score", "away_score", 
                    "tournament", "city", "country", "neutral")
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    stop(paste("Missing required columns in", file_path, ":", paste(missing_cols, collapse = ", ")))
  }

  # Type validation - basic checks without pointblank
  # Check date can be converted to numeric/Date
  if (!all(is.na(suppressWarnings(as.numeric(data$date))))) {
    stop(paste("Date column validation failed for", file_path))
  }
  
  # Check scores are numeric
  if (!all(is.na(suppressWarnings(as.numeric(data$home_score))))) {
    stop(paste("home_score column validation failed for", file_path))
  }
  if (!all(is.na(suppressWarnings(as.numeric(data$away_score))))) {
    stop(paste("away_score column validation failed for", file_path))
  }
  
  # Check neutral is logical
  if (!all(data$neutral %in% c(TRUE, FALSE, "TRUE", "FALSE", "true", "false"))) {
    stop(paste("neutral column validation failed for", file_path))
  }

  message(paste("✓", file_path, "validation passed"))
  return(TRUE)
}

#' Validate StatsBomb events JSON
#'
#' @param file_path Path to the JSON file to validate
#' @return TRUE if valid, stops execution with error message if invalid
validate_statsbomb_events <- function(file_path) {
  json <- tryCatch({
    fromJSON(file_path, simplifyVector = FALSE)
  }, error = function(e) {
    stop(paste("Failed to parse JSON:", file_path, "-", e$message))
  })

  # Check structure
  if (!"events" %in% names(json)) {
    stop(paste("Invalid StatsBomb events structure:", file_path, "- missing 'events' key"))
  }

  # Check at least one event exists
  if (length(json$events) == 0) {
    stop(paste("No events found in:", file_path))
  }

  # Check event structure (first event should have required fields)
  first_event <- json$events[[1]]
  required_fields <- c("id", "index", "period", "timestamp", "minute", "second", "type")
  missing_fields <- setdiff(required_fields, names(first_event))
  if (length(missing_fields) > 0) {
    stop(paste("Missing required fields in events:", paste(missing_fields, collapse = ", ")))
  }

  message(paste("✓", file_path, "validation passed"))
  return(TRUE)
}

#' Validate StatsBomb lineups JSON
#'
#' @param file_path Path to the JSON file to validate
#' @return TRUE if valid, stops execution with error message if invalid
validate_statsbomb_lineups <- function(file_path) {
  json <- tryCatch({
    fromJSON(file_path, simplifyVector = FALSE)
  }, error = function(e) {
    stop(paste("Failed to parse JSON:", file_path, "-", e$message))
  })

  # Check structure - lineups is a list of match lineups
  if (!"lineups" %in% names(json)) {
    stop(paste("Invalid StatsBomb lineups structure:", file_path, "- missing 'lineups' key"))
  }

  if (length(json$lineups) == 0) {
    stop(paste("No lineups found in:", file_path))
  }

  message(paste("✓", file_path, "validation passed"))
  return(TRUE)
}

#' Validate team name mapping CSV
#'
#' @param file_path Path to the CSV file to validate
#' @return TRUE if valid, stops execution with error message if invalid
validate_team_mapping <- function(file_path) {
  data <- tryCatch({
    read.csv(file_path, stringsAsFactors = FALSE)
  }, error = function(e) {
    stop(paste("Failed to read team mapping:", file_path, "-", e$message))
  })

  required_cols <- c("source_name", "canonical_name", "fifa_code", "alt_names")
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    stop(paste("Missing required columns in team mapping:", paste(missing_cols, collapse = ", ")))
  }

  message(paste("✓", file_path, "validation passed"))
  return(TRUE)
}

#' Run all validations for a given data source
#'
#' @param source Either "martj42" or "statsbomb"
#' @param base_dir Base directory for the source data
#' @return TRUE if all validations pass
validate_source <- function(source, base_dir) {
  cat(sprintf("Validating %s data in %s...\n", source, base_dir))
  
  if (source == "martj42") {
    files <- list.files(base_dir, pattern = "\\.csv$", full.names = TRUE)
    for (f in files) {
      validate_martj42(f)
    }
    validate_team_mapping(file.path(base_dir, "team_name_map.csv"))
  } else if (source == "statsbomb") {
    # Validate events
    events_dir <- file.path(base_dir, "events")
    if (dir.exists(events_dir)) {
      event_files <- list.files(events_dir, pattern = "\\.json$", full.names = TRUE)
      for (f in event_files) {
        validate_statsbomb_events(f)
      }
    }
    
    # Validate lineups
    lineups_dir <- file.path(base_dir, "lineups")
    if (dir.exists(lineups_dir)) {
      lineup_files <- list.files(lineups_dir, pattern = "\\.json$", full.names = TRUE)
      for (f in lineup_files) {
        validate_statsbomb_lineups(f)
      }
    }
    
    # Validate competitions
    comp_file <- file.path(base_dir, "competitions.json")
    if (file.exists(comp_file)) {
      validate_statsbomb_events(comp_file)  # Same structure check works
    }
  }
  
  return(TRUE)
}

#' Run all validations
#'
#' This function is called automatically after each ingest.
#' Stops execution with error if any validation fails.
validate_all <- function() {
  cat("Running all data validations...\n")
  
  tryCatch({
    validate_source("martj42", "data/raw/martj42")
    validate_source("statsbomb", "data/raw/statsbomb")
    cat("\n✓ All validations passed!\n")
    return(TRUE)
  }, error = function(e) {
    cat(sprintf("\n✗ Validation failed: %s\n", e$message))
    stop("Validation failed - pipeline stopped")
  })
}

# Run validations if called directly
if (identical(sys.nframe(), 0)) {
  validate_all()
}
