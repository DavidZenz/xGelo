library(testthat)
source("../../R/common/simulation_execution.R")
source("../../R/competition/uefa_nations_league_rules.R")
source("../../R/competition/uefa_nations_league_simulation.R")

test_that("vector counters preserve representative rows, frequencies and chunk merging", {
  rows <- data.frame(team = c("é", "B", "é", NA, "B", "C"), rank = c(1L, 2L, 1L, NA, 2L, 3L),
    value = c(1/3, NA, 2/3, NaN, 1/3, -0), label = letters[1:6], stringsAsFactors = FALSE)
  reference <- simulation_bucket_state(c("table", "means"))
  fast <- uefa_nl_stream_counter_state(c("table", "means"))
  for (iteration in 1:3) {
    selected <- if (iteration == 2L) c(6L, 5L, 2L, 1L) else 1:6
    value <- rows[selected, , drop = FALSE]
    simulation_bucket_observe(reference$table, value, c("team", "rank"), "value", iteration)
    simulation_bucket_observe(reference$means, value, "team", "value", iteration, character())
    uefa_nl_stream_observe(fast$table, value, c("team", "rank"), "value", iteration, "value")
    uefa_nl_stream_observe(fast$means, value, "team", "value", iteration, character())
  }
  result <- uefa_nl_stream_finalize_counters(fast)
  for (name in names(result)) {
    expect_identical(simulation_bucket_values(result[[name]]), simulation_bucket_values(reference[[name]]))
    expect_identical(ls(result[[name]], sorted = FALSE), ls(reference[[name]], sorted = FALSE))
  }
  expect_identical(uefa_nl_stream_finalize_counters(result), result)

  earlier <- uefa_nl_stream_counter_state("table")
  later <- uefa_nl_stream_counter_state("table")
  uefa_nl_stream_observe(earlier$table, rows, "team", "value", 1L, "value")
  uefa_nl_stream_observe(later$table, rows[6:1, ], "team", "value", 8L, "value")
  old <- simulation_bucket_state("table")
  simulation_bucket_observe(old$table, rows, "team", "value", 1L)
  simulation_bucket_observe(old$table, rows[6:1, ], "team", "value", 8L)
  merged <- simulation_bucket_merge_state(uefa_nl_stream_finalize_counters(later), uefa_nl_stream_finalize_counters(earlier))
  # Histogram tokens keep merge order; counts, representative rows and ordinals
  # must still match the ordered reduction exactly.
  for (key in ls(old$table)) {
    a <- get(key, old$table); b <- get(key, merged$table)
    expect_identical(b$row, a$row)
    expect_identical(b$ordinal, a$ordinal)
    expect_identical(b$n, a$n)
    expect_identical(b$values$value[sort(names(b$values$value))], a$values$value[sort(names(a$values$value))])
  }
})

test_that("mean sidecar rows preserve legacy metric and observation order exactly", {
  legacy <- function(value) {
    frames <- list()
    append <- function(table, rows, keys, metrics) {
      if (!nrow(rows)) return(invisible(NULL))
      key <- simulation_bucket_keys(rows, keys)
      for (metric in metrics) frames[[length(frames) + 1L]] <<- data.frame(
        key = paste(table, key, metric, sep = "\x1d"), value = as.numeric(rows[[metric]]), stringsAsFactors = FALSE)
    }
    standings <- attr(value, "nl_stream_capture")$standings
    append("standings", standings, c("league", "group_id", "team_id", "rank"), c("points", "goal_difference"))
    append("paths", value$paths, "team_id", uefa_nl_stream_path_fields())
    append("euro", value$euro_priority, "team_id", uefa_euro_priority_metrics())
    transitions <- value$transition_events; transitions$iteration <- NULL
    metrics <- intersect(c("probability", "playoff_eligibility_probability", "playoff_win_probability", "playoff_loss_probability"), names(transitions))
    append("transitions", transitions, setdiff(names(transitions), c(metrics, "row_sha256", "table_sha256")), metrics)
    if (!length(frames)) return(data.frame(key = character(), value = numeric()))
    do.call(rbind, frames)
  }
  paths <- data.frame(team_id = c("A", "é", "C", "D"))
  for (metric in uefa_nl_stream_path_fields()) paths[[metric]] <- c(NA_real_, -0, NaN, 1/3)
  euro <- data.frame(team_id = c("A", "B"))
  for (metric in uefa_euro_priority_metrics()) euro[[metric]] <- c(1/3, NA_real_)
  value <- list(paths = paths, euro_priority = euro, transition_events = data.frame(iteration = 1L,
    team_id = c("A", "B"), probability = c(1/3, NA), row_sha256 = c("a", "b")))
  attr(value, "nl_stream_capture") <- list(standings = data.frame(league = "A", group_id = "1",
    team_id = c("A", "B", "A", "B"), rank = c(1L, 2L, 1L, 2L), points = c(1, 2, 3, 4), goal_difference = c(-0, NA, NaN, 1/3)))
  expect_identical(uefa_nl_stream_mean_records(value), legacy(value))
  value$paths$p_champion <- NULL
  expect_error(uefa_nl_stream_mean_records(value), "Missing streamed mean fields: paths")
})

test_that("prepared metadata preserves schemas, types, hashes and empty frames", {
  metadata <- list(edition_id = "2026-27", projection_run_id = "run", simulation_seed = 7L,
    rules = uefa_nl_2026_27_rules(), source_bundle_id = "source", source_bundle_sha256 = "sha", model_release_id = "model")
  apply <- uefa_nl_stream_prepare_metadata(17L, metadata)
  for (rows in list(data.frame(team = c("A", "B")), data.frame(team = character()), data.frame(team = "A", simulation_count = 2))) {
    expect_identical(apply(rows), uefa_nl_stream_metadata(rows, 17L, metadata))
  }
})
