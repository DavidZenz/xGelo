#' Unit Tests for xG Feature Calculations
#'
#' Tests for calculate_distance() and calculate_angle() functions.

library(testthat)

# Source the features for testing
source("../../R/xg/features.R")

describe("calculate_distance", {
  it("returns correct distance for penalty spot", {
    # Penalty spot is at x=108, y=40 in StatsBomb coordinates
    # Goal center is at x=120, y=40
    # Distance should be 12 yards
    expect_equal(calculate_distance(108, 40), 12, tolerance = 0.01)
  })

  it("returns correct distance for center spot", {
    # Center spot is at x=60, y=40
    # Distance to goal center (120, 40) should be 60 yards
    expect_equal(calculate_distance(60, 40), 60, tolerance = 0.01)
  })

  it("returns correct distance for goal center", {
    # At goal center, distance should be 0
    expect_equal(calculate_distance(120, 40), 0, tolerance = 0.001)
  })

  it("returns vector of same length as input", {
    x <- c(108, 60, 120, 90)
    y <- c(40, 40, 40, 40)
    result <- calculate_distance(x, y)
    expect_length(result, 4)
  })

  it("handles single values", {
    expect_length(calculate_distance(108, 40), 1)
    expect_length(calculate_angle(108, 40), 1)
  })

  it("distance is always non-negative", {
    # Test various points on and off the pitch
    x_vals <- c(0, 60, 108, 120, 130)
    y_vals <- c(0, 20, 40, 60, 80)
    distances <- calculate_distance(x_vals, y_vals)
    expect_true(all(distances >= 0))
  })

  it("max distance on pitch is ~130 yards", {
    # Corner of pitch: x=0, y=0
    dist <- calculate_distance(0, 0)
    expect_lte(dist, 130)
    # Or x=0, y=80
    dist2 <- calculate_distance(0, 80)
    expect_lte(dist2, 130)
  })
})

describe("calculate_angle", {
  it("returns correct angle for center spot", {
    # At center (60, 40), 60 yards from goal
    # The angle is narrow because the goal is far away
    # Expected: acos((a^2 + b^2 - c^2) / (2ab)) where a≈b≈60.11, c=7.32
    # = acos((3613.2 + 3613.2 - 53.6) / (2*60.11*60.11))
    # = acos(7172.8 / 7236.4) ≈ acos(0.9912) ≈ 0.1218 radians
    angle <- calculate_angle(60, 40)
    expect_equal(angle, 0.1218, tolerance = 0.001)
  })

  it("returns angle in range [0, π]", {
    # Test various points
    x_vals <- c(60, 108, 120, 90, 30)
    y_vals <- c(40, 40, 40, 20, 60)
    angles <- calculate_angle(x_vals, y_vals)
    expect_true(all(angles >= 0 & angles <= pi))
  })

  it("returns small angle for penalty spot", {
    # At penalty spot (108, 40), the angle should be small
    angle <- calculate_angle(108, 40)
    expect_lt(angle, pi/4)  # Less than 45 degrees
  })

  it("returns large angle for points behind goal center", {
    # At (119, 40), directly behind goal center but very close
    # The angle to the two posts is very wide (> 90 degrees)
    # a = b ≈ 3.79 yards (distance to each post)
    # c = 7.32 yards (goal width)
    # cos(theta) = (3.79^2 + 3.79^2 - 7.32^2) / (2 * 3.79 * 3.79)
    #           = (14.36 + 14.36 - 53.6) / 28.72
    #           = -24.88 / 28.72 ≈ -0.866
    # theta = acos(-0.866) ≈ 2.6 radians (149 degrees)
    angle <- calculate_angle(119, 40)
    expect_equal(angle, 2.608, tolerance = 0.001)
  })

  it("handles points behind the goal", {
    # Points with x > 120 should still return valid angles
    angle <- calculate_angle(130, 40)
    expect_true(!is.na(angle))
    expect_true(angle >= 0 && angle <= pi)
  })

  it("returns vector of same length as input", {
    x <- c(60, 108, 120, 90)
    y <- c(40, 40, 40, 20)
    result <- calculate_angle(x, y)
    expect_length(result, 4)
  })
})

describe("feature ranges", {
  it("distance values are in valid range", {
    # Test a grid of points across the pitch
    x_grid <- seq(0, 120, by = 20)
    y_grid <- seq(0, 80, by = 20)
    
    distances <- outer(x_grid, y_grid, Vectorize(function(x, y) calculate_distance(x, y)))
    
    expect_true(all(distances >= 0))
    expect_true(all(distances <= 130))
  })

  it("angle values are in valid range", {
    x_grid <- seq(0, 120, by = 20)
    y_grid <- seq(0, 80, by = 20)
    
    angles <- outer(x_grid, y_grid, Vectorize(function(x, y) calculate_angle(x, y)))
    
    expect_true(all(angles >= 0))
    expect_true(all(angles <= pi))
  })
})

describe("extract_features_from_events", {
  it("returns empty data frame when no shots", {
    # Create a minimal valid events data frame with no shots
    events <- data.frame(
      type = I(data.frame(id = 1:5, name = rep('Pass', 5))),
      location = I(vector('list', 5)),
      shot = I(data.frame(
        body_part = I(data.frame(name = rep(NA_character_, 5))),
        type = I(data.frame(name = rep(NA_character_, 5))),
        outcome = I(data.frame(name = rep(NA_character_, 5)))
      )),
      play_pattern = I(data.frame(id = 1:5, name = rep('Regular Play', 5))),
      stringsAsFactors = FALSE
    )
    
    features <- extract_features_from_events(events, 'Test League')
    
    expect_equal(nrow(features), 0)
    expect_equal(ncol(features), 6)
  })

  it("extracts features from mock shot data", {
    # Create mock events with shot data
    events <- data.frame(
      type = I(data.frame(id = 1:3, name = c('Pass', 'Shot', 'Shot'))),
      location = I(list(NULL, c(80, 40), c(100, 40))),
      shot = I(data.frame(
        body_part = I(data.frame(name = c(NA, 'Right Foot', 'Head'))),
        type = I(data.frame(name = c(NA, 'Open Play', 'Open Play'))),
        outcome = I(data.frame(name = c(NA, 'Goal', 'Saved')))
      )),
      play_pattern = I(data.frame(id = 1:3, name = c('Regular Play', 'Regular Play', 'From Corner'))),
      stringsAsFactors = FALSE
    )
    
    features <- extract_features_from_events(events, 'Test League')
    
    # Should return a data frame with 2 shots
    expect_is(features, 'data.frame')
    expect_equal(nrow(features), 2)
    expect_named(features, c('distance', 'angle', 'header', 'open_play', 'competition', 'goal'))
    
    # First shot: (80, 40) -> distance ~40, not a header, regular play, goal
    # Second shot: (100, 40) -> header, from corner, saved
    # Note: open_play is based on play_pattern == "Regular Play", not shot type
    expect_equal(features$header, c(FALSE, TRUE))
    expect_equal(features$open_play, c(TRUE, FALSE))  # Regular Play vs From Corner
    expect_equal(features$goal, c(TRUE, FALSE))
  })

  it("excludes penalty shots", {
    # Create mock events with a penalty
    events <- data.frame(
      type = I(data.frame(id = 1:2, name = c('Shot', 'Shot'))),
      location = I(list(c(80, 40), c(108, 40))),
      shot = I(data.frame(
        body_part = I(data.frame(name = c('Right Foot', 'Right Foot'))),
        type = I(data.frame(name = c('Open Play', 'Penalty'))),
        outcome = I(data.frame(name = c('Goal', 'Goal')))
      )),
      play_pattern = I(data.frame(id = 1:2, name = c('Regular Play', 'Regular Play'))),
      stringsAsFactors = FALSE
    )
    
    features <- extract_features_from_events(events, 'Test League')
    
    # Should exclude the penalty, so only 1 shot
    expect_equal(nrow(features), 1)
    # The penalty was at (108, 40) which has distance 12, so the remaining shot is at (80, 40)
    expect_equal(features$distance, 40, tolerance = 0.01)
  })

  it("handles missing location data", {
    # Create mock events with missing location
    events <- data.frame(
      type = I(data.frame(id = 1:2, name = c('Shot', 'Shot'))),
      location = I(list(NULL, c(80, 40))),
      shot = I(data.frame(
        body_part = I(data.frame(name = c('Right Foot', 'Right Foot'))),
        type = I(data.frame(name = c('Open Play', 'Open Play'))),
        outcome = I(data.frame(name = c('Goal', 'Goal')))
      )),
      play_pattern = I(data.frame(id = 1:2, name = c('Regular Play', 'Regular Play'))),
      stringsAsFactors = FALSE
    )
    
    features <- extract_features_from_events(events, 'Test League')
    
    # Should have 2 shots, but first will have NA for distance/angle
    expect_equal(nrow(features), 2)
    expect_true(is.na(features$distance[1]))
    expect_true(is.na(features$angle[1]))
    expect_equal(features$distance[2], 40, tolerance = 0.01)
  })
})
