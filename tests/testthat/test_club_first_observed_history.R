library(testthat)
first_observed_test_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
old_directory <- getwd(); setwd(first_observed_test_root)
source("scripts/select_first_observed_club_history.R")
setwd(old_directory)

test_that("final results retain their first actual matching pinned observation", {
  root <- tempfile("first-observed-"); dir.create(root)
  on.exit(unlink(root, recursive = TRUE))
  parents <- data.frame(source_path = "england/2024-25/league.txt", raw_sha256 = c("old", "final"),
    competition_id = "england", season_id = "2024-25", commit_sha = c("commit-old", "commit-final"),
    commit_utc = c("2024-10-01T00:00:00Z", "2025-06-01T00:00:00Z"), is_latest_file_bytes = c("false", "true"))
  rows <- data.frame(source_path = parents$source_path[c(1, 1, 2, 2)], raw_sha256 = c("old", "old", "final", "final"),
    source_match_id = c("line_1", "line_2", "line_10", "line_20"),
    event_date = rep(c("2024-09-01", "2024-09-02"), 2), stage = "REGULAR_SEASON", status = "completed",
    home_name = c("A", "B", "Alpha FC", "Beta FC"), away_name = c("B", "A", "Beta FC", "Alpha FC"),
    score_text = c("1-0", "2-0", "1-0", "2-1"), score_semantics = "regulation")
  proposals <- data.frame(source_name = c("A", "Alpha FC", "B", "Beta FC"), normalized_name = c("a", "alpha fc", "b", "beta fc"),
    source_club_id = c("name:a", "name:alpha_fc", "name:b", "name:beta_fc"),
    proposed_club_id = c("club_alpha", "club_alpha", "club_beta", "club_beta"), ambiguity = "")
  write.csv(parents, file.path(root, "candidates.csv"), row.names = FALSE)
  write.csv(rows, file.path(root, "candidate_rows.csv"), row.names = FALSE)
  write.csv(proposals, file.path(root, "all_candidate_identity_proposals.csv"), row.names = FALSE)
  result <- select_first_observed_club_history(root)
  expect_equal(nrow(result$ledger), 2L)
  expect_identical(result$ledger$raw_sha256[match("1-0", result$ledger$score_text)], "old")
  expect_identical(result$ledger$raw_sha256[match("2-1", result$ledger$score_text)], "final")
  expect_false("2-0" %in% result$ledger$score_text)
  expect_equal(sum(as.integer(result$selections$selected_regulation_results)), 2L)
  parents$commit_utc[[1L]] <- "2024-08-01T00:00:00Z"
  write.csv(parents, file.path(root, "candidates.csv"), row.names = FALSE)
  future_seed <- select_first_observed_club_history(root)
  expect_true(all(future_seed$ledger$commit_utc >= paste0(future_seed$ledger$event_date, "T00:00:00Z")))
  expect_identical(future_seed$ledger$raw_sha256[match("1-0", future_seed$ledger$score_text)], "final")
})
