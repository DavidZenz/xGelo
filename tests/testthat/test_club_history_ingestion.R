library(testthat)
history_ingestion_root <- normalizePath(file.path(getwd(),
  if (basename(getwd()) == "testthat") "../.." else "."), winslash = "/")
for (dependency in c("R/common/phase18_canonical_hash.R", "R/club/identity.R",
                     "R/club/history_contract.R", "R/club/openfootball_parser.R",
                     "R/club/history_ingestion.R")) source(file.path(history_ingestion_root, dependency))

test_that("native review scope excludes ambiguous knockout, scheduled and awarded evidence", {
  text <- c("# Matches 4", "▪ League", "Tue Sep 17 2024", "A (ENG) v B (ITA) 2-0 (1-0)",
    "A (ENG) v C (FRA)", "▪ Semifinals", "Tue May 6 2025", "B (ITA) v C (FRA) 4-3 (2-0)",
    "▪ League", "Wed Sep 18 2024", "B (ITA) v A (ENG) 3-0 [awarded]")
  path <- tempfile(fileext = ".txt"); writeLines(text, path)
  on.exit(unlink(path))
  parent <- data.frame(source_id = "ucl-2024", raw_sha256 = digest::digest(file = path, algo = "sha256"),
    competition_id = "uefa-champions-league", season_id = "2024-25")
  rows <- phase18_read_openfootball_source(path, parent)
  scopes <- phase18_history_source_scope(rows, parent)
  result <- phase18_ingest_pinned_club_source(path, parent, scopes)
  expect_equal(nrow(result$rows), 1L)
  expect_identical(result$rows$score_text, "2-0")
  expect_equal(nrow(result$exclusions), 3L)
  expect_setequal(result$exclusions$selection_exclusion,
    c("source_status_scheduled", "stage_outside_reviewed_training_scope", "source_status_awarded"))
  expect_equal(nrow(result$diagnostics), 4L)
  expect_error(phase18_ingest_pinned_club_source(path, parent), class = "history_scope_not_reviewed")
  altered <- scopes; altered$selected_rows <- "2"
  expect_error(phase18_ingest_pinned_club_source(path, parent, altered), class = "history_scope_mismatch")
  altered <- scopes; altered$raw_sha256 <- strrep("a", 64)
  altered$row_sha256 <- phase18_history_row_sha256(altered)
  expect_error(phase18_ingest_pinned_club_source(path, parent, altered), class = "history_scope_mismatch")
})

test_that("first-observation scope retains disjoint reviewed lines from a pinned snapshot", {
  rows <- phase18_parse_openfootball_text(c("# Matches 2", "▪ Matchday 1", "Fri Aug 13 2021",
    "A 1-0 B", "C 2-0 D"), "2021-22", "england")
  parent <- data.frame(source_id = "england-pinned-slice", raw_sha256 = strrep("a", 64), competition_id = "england")
  scope <- phase18_history_source_scope(rows, parent, rows$source_match_id[[2L]])
  selected <- phase18_select_openfootball_history(rows, "england", scope$selected_source_match_ids)
  expect_equal(nrow(selected$rows), 1L)
  expect_identical(selected$rows$home_name, "C")
  expect_identical(selected$excluded$selection_exclusion, "regulation_fixture_retained_at_another_pinned_snapshot")
  expect_match(scope$selection_policy, "first_observed$")
  expect_error(phase18_history_source_scope(rows, parent, "line_999999"), class = "history_scope_membership_invalid")
  parent$commit_utc <- "2021-08-12T00:00:00Z"
  expect_error(phase18_history_source_scope(rows, parent, rows$source_match_id[[2L]]), class = "history_result_predates_event")
})
