library(testthat)

nl_runtime_hash_root <- normalizePath(if (basename(getwd()) == "testthat") "../.." else ".", mustWork = TRUE)
while (!file.exists(file.path(nl_runtime_hash_root, "R/competition/source_contracts.R"))) {
  parent <- dirname(nl_runtime_hash_root)
  if (identical(parent, nl_runtime_hash_root)) stop("NL runtime hash test cannot locate project sources")
  nl_runtime_hash_root <- parent
}

nl_runtime_hash_api <- function() {
  withr::local_dir(nl_runtime_hash_root)
  api <- new.env(parent = globalenv())
  directory <- Sys.getenv("XGELO_NL_RUNTIME_TEST_DIRECTORY", file.path(nl_runtime_hash_root, "R/competition"))
  sys.source(file.path(nl_runtime_hash_root, "R/competition/source_contracts.R"), api)
  sys.source(file.path(directory, "uefa_nations_league_rules.R"), api)
  sys.source(file.path(nl_runtime_hash_root, "R/competition/standings.R"), api)
  sys.source(file.path(nl_runtime_hash_root, "R/competition/uefa_euro_priority.R"), api)
  sys.source(file.path(directory, "uefa_nations_league_simulation.R"), api)
  api
}

nl_runtime_hash_matches <- function() {
  pairs <- expand.grid(home_team_id = paste0("team_", letters[1:4]),
    away_team_id = paste0("team_", letters[1:4]), stringsAsFactors = FALSE)
  pairs <- pairs[pairs$home_team_id != pairs$away_team_id, , drop = FALSE]
  pairs$match_id <- paste(pairs$home_team_id, pairs$away_team_id, sep = "__")
  pairs$edition_id <- "uefa_nations_league_2026_27"
  pairs$group_id <- "A1"
  pairs$source_bundle_id <- "independent-runtime-hash-fixture"
  pairs$state_cutoff_utc <- "2026-11-05T12:00:00Z"
  pairs$evidence_completed_at_utc <- "2026-11-05T10:00:00Z"
  pairs$match_status <- "completed"
  pairs$counts_for_standings <- TRUE
  pairs$final_home_goals <- 0L
  pairs$final_away_goals <- 0L
  pairs
}

test_that("adapted standings hash batching preserves every independent numeric cell and hash", {
  api <- nl_runtime_hash_api()
  set.seed(20261105)
  for (iteration in 1:100) {
    matches <- nl_runtime_hash_matches()
    matches$counts_for_standings <- sample(c(TRUE, FALSE), nrow(matches), replace = TRUE)
    matches$final_home_goals <- sample.int(9L, nrow(matches), replace = TRUE) - 1L
    matches$final_away_goals <- sample.int(9L, nrow(matches), replace = TRUE) - 1L
    data <- api$phase14_compute_standings(matches, matches$edition_id[[1L]], "A1",
      matches$state_cutoff_utc[[1L]], matches$source_bundle_id[[1L]])
    data$computed_rank <- sample(seq_len(nrow(data)))
    data$ordering_status <- "ruleset_adapter"
    data$ruleset_adapter_id <- "uefa_nl_article15_v2"
    data <- data[sample(seq_len(nrow(data))), , drop = FALSE]
    expect_identical(api$uefa_nl_sim_universal_hashes(data), api$phase14_standings_apply_hashes(data))
  }
})

test_that("the optional hash seam retains the entire authoritative group state", {
  api <- nl_runtime_hash_api()
  rows <- nl_runtime_hash_matches()
  rows$final_home_goals <- rep(c(0L, 1L, 2L), length.out = nrow(rows))
  rows$final_away_goals <- rep(c(1L, 2L, 0L), length.out = nrow(rows))
  teams <- sort(unique(rows$home_team_id))
  args <- list(match_rows = rows, discipline_points = data.frame(team_id = teams, discipline_points = 0L),
    access_list = data.frame(team_id = teams, access_list_position = seq_along(teams)),
    group_id = "A1", rules = api$uefa_nl_2026_27_rules(), edition_id = rows$edition_id[[1L]],
    state_cutoff_utc = rows$state_cutoff_utc[[1L]], source_bundle_id = rows$source_bundle_id[[1L]], team_ids = teams)
  reference <- do.call(api$uefa_nl_build_group_standings_state, args)
  calls <- 0L
  args$.standings_hashes <- function(data) { calls <<- calls + 1L; api$uefa_nl_sim_universal_hashes(data) }
  candidate <- do.call(api$uefa_nl_build_group_standings_state, args)
  expect_identical(calls, 1L)
  expect_identical(candidate, reference)
})
