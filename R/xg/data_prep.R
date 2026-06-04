#' xGelo: xG Training Data Preparation
#'
#' Script for loading StatsBomb events, extracting shots, applying feature contract,
#' and creating model-ready dataset.

#' Prepare xG Training Data from Multiple Event Files
#'
#' @description Loads StatsBomb events, extracts shot features, and prepares training data.
#'
#' @param events_dir Character string path to directory containing StatsBomb events JSON files
#' @param competitions_file Character string path to competitions.json file
#' @param domestic_only Logical whether to filter to domestic leagues only (default: TRUE)
#' @param competition_name Character string name to use for all events (for sample data without metadata)
#' @return A data frame with columns: distance, angle, header, open_play, competition, goal
#' @export
prepare_training_data <- function(events_dir, competitions_file, domestic_only = TRUE, competition_name = "Sample League") {
  library(jsonlite)
  library(dplyr)
  
  # Load competition metadata (for filtering validation)
  if (file.exists(competitions_file)) {
    comps <- fromJSON(competitions_file)
    
    # Filter to domestic leagues if requested
    if (domestic_only) {
      exclude_keywords <- c("World Cup", "UEFA European", "Confederations Cup", 
                           "Qualifiers", "Nations League", "Euro", "CONMEBOL", 
                           "AFC", "CAF", "CONCACAF", "Champions League", 
                           "Europa League", "Europa Conference", "FIFA Club")
      
      is_domestic <- !comps$competition_international & 
        !sapply(comps$competition_name, function(name) {
          any(sapply(exclude_keywords, function(kw) grepl(kw, name, ignore.case = TRUE)))
        })
      
      if (sum(is_domestic) == 0) {
        warning("No domestic competitions found in competitions.json")
      }
    }
  }
  
  # Get list of event files
  event_files <- list.files(events_dir, pattern = "\\.json$", full.names = TRUE)
  cat(sprintf("Found %d event files in %s\n", length(event_files), events_dir))
  
  if (length(event_files) == 0) {
    stop("No event files found in ", events_dir)
  }
  
  # Process each file
  all_features <- list()
  
  for (file in event_files) {
    cat("Processing ", basename(file), "...\n")
    
    tryCatch({
      events <- fromJSON(file)
      
      # Extract features using the provided competition name
      features <- extract_features_from_events(events, competition_name)
      
      if (nrow(features) > 0) {
        # Add file identifier for tracking
        features$file <- basename(file)
        all_features[[length(all_features) + 1]] <- features
      }
    }, error = function(e) {
      warning(sprintf("Error processing %s: %s", basename(file), e$message))
    })
  }
  
  # Combine all features
  if (length(all_features) == 0) {
    stop("No features extracted from any file")
  }
  
  training_data <- bind_rows(all_features)
  
  cat(sprintf("Total shots extracted: %d\n", nrow(training_data)))
  
  # Data quality validation
  na_dist <- sum(is.na(training_data$distance))
  na_angle <- sum(is.na(training_data$angle))
  if (na_dist > 0 || na_angle > 0) {
    warning(sprintf("Found %d shots with NA distance and %d with NA angle", na_dist, na_angle))
  }
  
  # Check bounds
  out_of_bounds_x <- training_data$distance < 0 | training_data$distance > 130
  out_of_bounds_angle <- training_data$angle < 0 | training_data$angle > pi
  
  if (any(out_of_bounds_x)) {
    warning(sprintf("Found %d shots with distance out of bounds [0, 130]", sum(out_of_bounds_x)))
  }
  if (any(out_of_bounds_angle)) {
    warning(sprintf("Found %d shots with angle out of bounds [0, π]", sum(out_of_bounds_angle)))
  }
  
  # Remove the file column before returning (it's just for tracking)
  training_data$file <- NULL
  
  return(training_data)
}

#' Split Training Data into Train and Test Sets
#'
#' @description Splits training data into train and test sets.
#' Since our sample data doesn't have season information, we use a simple random split
#' or can split by file (each file represents a match).
#'
#' @param training_data Data frame with training data
#' @param split_method Character: "random" (default) or "by_file"
#' @param test_proportion Numeric: proportion of data to use for testing (default: 0.2)
#' @param random_seed Integer: random seed for reproducibility (default: 42)
#' @return A list with elements: train_data, test_data
#' @export
split_training_data <- function(training_data, split_method = "random", test_proportion = 0.2, random_seed = 42) {
  if (nrow(training_data) == 0) {
    stop("training_data must have at least one row")
  }
  
  if (split_method == "random") {
    set.seed(random_seed)
    n_test <- floor(nrow(training_data) * test_proportion)
    test_idx <- sample(seq_len(nrow(training_data)), n_test)
    
    train_data <- training_data[-test_idx, ]
    test_data <- training_data[test_idx, ]
  } else if (split_method == "by_file") {
    if (!"file" %in% names(training_data)) {
      stop("split_method='by_file' requires 'file' column in training_data")
    }
    
    # Split by file: use first 80% of files for training, last 20% for testing
    files <- unique(training_data$file)
    n_files <- length(files)
    n_train_files <- floor(n_files * (1 - test_proportion))
    
    train_files <- head(sort(files), n_train_files)
    test_files <- tail(sort(files), n_files - n_train_files)
    
    train_data <- training_data %>% filter(file %in% train_files)
    test_data <- training_data %>% filter(file %in% test_files)
  } else {
    stop("split_method must be 'random' or 'by_file'")
  }
  
  # Verify no overlap in shots (each shot should be in only one set)
  if ("id" %in% names(training_data)) {
    train_ids <- unique(train_data$id)
    test_ids <- unique(test_data$id)
    overlap <- intersect(train_ids, test_ids)
    if (length(overlap) > 0) {
      warning(sprintf("Found %d shots in both train and test sets", length(overlap)))
    }
  }
  
  list(train_data = train_data, test_data = test_data)
}

#' Prepare and Split Training Data (Convenience Function)
#'
#' @description Convenience function that loads events and creates train/test split.
#'
#' @param events_dir Character string path to directory containing StatsBomb events JSON files
#' @param competitions_file Character string path to competitions.json file
#' @param output_dir Character string directory to save processed data (default: "data/processed")
#' @param domestic_only Logical whether to filter to domestic leagues only (default: TRUE)
#' @param competition_name Character string name to use for all events
#' @return A list with elements: train_data, test_data, training_data
#' @export
prepare_and_split_data <- function(events_dir, competitions_file, output_dir = "data/processed", 
                                   domestic_only = TRUE, competition_name = "Sample League") {
  # Prepare training data
  training_data <- prepare_training_data(events_dir, competitions_file, domestic_only, competition_name)
  
  # Split into train/test
  split <- split_training_data(training_data, split_method = "random", test_proportion = 0.2, random_seed = 42)
  
  # Save processed data
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  saveRDS(training_data, file.path(output_dir, "xg_training_data.rds"))
  saveRDS(split$train_data, file.path(output_dir, "xg_train_data.rds"))
  saveRDS(split$test_data, file.path(output_dir, "xg_test_data.rds"))
  
  cat(sprintf("Saved training data to %s\n", file.path(output_dir, "xg_training_data.rds")))
  cat(sprintf("Training set: %d shots\n", nrow(split$train_data)))
  cat(sprintf("Test set: %d shots\n", nrow(split$test_data)))
  
  return(list(
    training_data = training_data,
    train_data = split$train_data,
    test_data = split$test_data
  ))
}
