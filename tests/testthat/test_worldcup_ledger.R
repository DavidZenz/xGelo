library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "R/evaluation/worldcup_ledger.R"))

test_that("fixture registry reconciles all 104 official matches", {
  fixtures <- build_worldcup_2026_fixture_registry(
    group_results_path = file.path(project_root, "outputs/dashboard/worldcup_match_forecasts.csv"),
    bracket_results_path = file.path(project_root, "outputs/dashboard/worldcup_bracket_paths.csv"),
    scoreboard_dir = file.path(project_root, "data/raw/espn")
  )
  expect_equal(nrow(fixtures), 104)
  expect_equal(length(unique(fixtures$match_id)), 104)
  expect_true(all(!is.na(parse_utc_time(fixtures$kickoff_utc))))
  expect_true(all(c("M103", "M104") %in% fixtures$match_id))
  expect_true(all(!is.na(fixtures$result_event_id)))
})

test_that("team normalization handles current source aliases", {
  expect_equal(normalize_worldcup_team_key("South Korea"), "korea republic")
  expect_equal(normalize_worldcup_team_key("Czechia"), "czech republic")
  expect_equal(normalize_worldcup_team_key("Ivory Coast"), "cote d ivoire")
  expect_equal(normalize_worldcup_team_key("U.S.A."), "united states")
})

test_that("forecast evidence enforces pre-kickoff timing and tiers", {
  fixtures <- data.frame(
    match_id = "GA01", stage = "group", round = "Group A",
    kickoff_utc = "2026-06-11T19:00:00Z", home_team = "Mexico",
    away_team = "South Africa", actual_home_goals = 2L,
    actual_away_goals = 0L, actual_winner_team = "Mexico",
    stringsAsFactors = FALSE
  )
  row <- data.frame(
    match_id = "GA01", home_team = "Mexico", away_team = "South Africa",
    p_home = 0.5, p_draw = 0.25, p_away = 0.25,
    generated_at_utc = "2026-06-11T10:00:00Z",
    committed_at = "2026-06-11T10:05:00Z",
    feature_cutoff_date = "2026-06-10", result_cutoff_date = NA_character_,
    archive_blob = "a", dashboard_blob = "b", feature_blob = "f",
    home_model_blob = "c", away_model_blob = "d",
    commit_sha = "1", forecast_revision_id = "r1", stringsAsFactors = FALSE
  )
  verified <- classify_forecast_evidence(row, fixtures)
  expect_equal(verified$evidence_tier, "verified")
  expect_true(verified$strict_eligible)

  row$dashboard_blob <- NA_character_
  documented <- classify_forecast_evidence(row, fixtures)
  expect_equal(documented$evidence_tier, "documented")
  expect_true(documented$exploratory_eligible)

  row$committed_at <- "2026-06-11T19:00:00Z"
  rejected <- classify_forecast_evidence(row, fixtures)
  expect_equal(rejected$evidence_tier, "rejected")
  expect_equal(rejected$primary_reason, "post_kickoff_commit")
})

test_that("first and latest views are deterministic and never blended", {
  ledger <- data.frame(
    match_id = rep(c("GA01", "GA02"), each = 2),
    strict_eligible = c(TRUE, TRUE, FALSE, FALSE),
    exploratory_eligible = c(FALSE, FALSE, TRUE, TRUE),
    committed_at = c(
      "2026-06-10T08:00:00Z", "2026-06-11T08:00:00Z",
      "2026-06-11T09:00:00Z", "2026-06-12T09:00:00Z"
    ),
    generated_at_utc = c(
      "2026-06-10T07:00:00Z", "2026-06-11T07:00:00Z",
      "2026-06-11T08:00:00Z", "2026-06-12T08:00:00Z"
    ),
    commit_sha = c("a", "b", "c", "d"),
    stringsAsFactors = FALSE
  )
  views <- derive_forecast_views(ledger)
  expect_equal(nrow(views), 4)
  expect_equal(views$commit_sha[views$sample == "strict" & views$view == "first_valid"], "a")
  expect_equal(views$commit_sha[views$sample == "strict" & views$view == "latest_valid"], "b")
  expect_false(any(views$sample == "strict" & views$commit_sha %in% c("c", "d")))
})

test_that("Git commit inventory is chronological and read-only", {
  commits <- list_forecast_archive_commits(repo = project_root)
  expect_gt(nrow(commits), 0)
  expect_true(all(nchar(commits$commit_sha) == 40))
  expect_true(all(diff(as.numeric(parse_utc_time(commits$committed_at))) >= 0))
  expect_equal(
    run_git_read(c("status", "--porcelain"), repo = project_root),
    system2("git", c("-C", project_root, "status", "--porcelain"), stdout = TRUE)
  )
})
