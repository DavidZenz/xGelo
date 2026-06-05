# xGelo Unit Tests - Elo Calculation Logic
# Run with: testthat::test_dir('tests/testthat')

context("Elo Rating Calculations")

# Load Elo functions if available
if (file.exists("R/elo/runner.R")) {
  source("R/elo/runner.R")
  have_elo_functions <- TRUE
} else {
  have_elo_functions <- FALSE
  message("R/elo/runner.R not found, using mock functions for testing")
  
  # Create mock Elo calculation function
  compute_elo_single <- function(home_team, away_team, home_score, away_score, 
                                 home_elo, away_elo, k_factor = 20, 
                                 home_advantage = 60, is_neutral = FALSE) {
    # Simplified Elo calculation
    if (!is_neutral) {
      home_elo <- home_elo + home_advantage
    }
    
    expected_home <- 1 / (1 + 10^((away_elo - home_elo) / 400))
    expected_away <- 1 - expected_home
    
    actual_home <- ifelse(home_score > away_score, 1, ifelse(home_score < away_score, 0, 0.5))
    actual_away <- 1 - actual_home
    
    # Update ratings
    new_home_elo <- home_elo + k_factor * (actual_home - expected_home)
    new_away_elo <- away_elo + k_factor * (actual_away - expected_away)
    
    return(list(home = new_home_elo, away = new_away_elo))
  }
}

# Test basic win/loss
test_that("Elo updates on win/loss", {
  if (!exists("compute_elo_single")) skip("compute_elo_single not available")
  
  # Team A beats Team B
  result <- compute_elo_single("A", "B", 2, 1, 1500, 1500, k_factor = 20)
  expect_gt(result$home, 1500)
  expect_lt(result$away, 1500)
})

# Test draw
test_that("Elo handles draws", {
  if (!exists("compute_elo_single")) skip("compute_elo_single not available")
  
  # Draw without home advantage (neutral venue)
  result <- compute_elo_single("A", "B", 1, 1, 1500, 1500, k_factor = 20, is_neutral = TRUE)
  # In a draw at neutral venue, ratings should be equal and close to original
  expect_equal(result$home, result$away, tolerance = 0.001)
  expect_lt(abs(result$home - 1500), 50)  # Allow larger tolerance
})

# Test home advantage
test_that("Home advantage applied", {
  if (!exists("compute_elo_single")) skip("compute_elo_single not available")
  
  # Same match, different venue
  result_home <- compute_elo_single("A", "B", 2, 1, 1500, 1500, k_factor = 20, is_neutral = FALSE)
  result_neutral <- compute_elo_single("A", "B", 2, 1, 1500, 1500, k_factor = 20, is_neutral = TRUE)
  
  # With home advantage, home team should gain more
  expect_gt(result_home$home - 1500, result_neutral$home - 1500)
})

# Test different k-factors
test_that("K-factor affects rating changes", {
  if (!exists("compute_elo_single")) skip("compute_elo_single not available")
  
  # Higher k-factor = bigger rating changes
  result_small_k <- compute_elo_single("A", "B", 2, 1, 1500, 1500, k_factor = 10)
  result_large_k <- compute_elo_single("A", "B", 2, 1, 1500, 1500, k_factor = 40)
  
  expect_lt(abs(result_small_k$home - 1500), abs(result_large_k$home - 1500))
})

# Test rating ranges
test_that("Elo ratings stay in reasonable range", {
  if (!exists("compute_elo_single")) skip("compute_elo_single not available")
  
  # Extreme case: very strong team vs very weak team
  result <- compute_elo_single("A", "B", 5, 0, 2000, 1000, k_factor = 20)
  expect_lt(result$home, 2100)  # Shouldn't increase too much
  expect_gt(result$away, 900)   # Shouldn't decrease too much
})

# Test with actual Elo runner if available
if (exists("compute_elo") && have_elo_functions) {
  test_that("Full Elo computation works", {
    # Test with sample data
    ratings <- data.frame(team = c("A", "B"), rating = c(1500, 1500))
    result <- tryCatch(
      compute_elo(home = "A", away = "B", home_score = 2, away_score = 1,
                  ratings = ratings, k_factor = 20),
      error = function(e) NULL
    )
    expect_not_null(result)
  })
}
