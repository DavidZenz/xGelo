library(testthat)

phase18_history_test_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase18_history_test_load <- function() {
  for (path in file.path(phase18_history_test_root, c(
    "R/competition/source_contracts.R",
    "R/club/identity.R",
    "R/club/identity_bootstrap.R",
    "R/club/history_contract.R"
  ))) if (file.exists(path)) source(path, local = .GlobalEnv)
}

phase18_history_test_require <- function(names) {
  missing <- names[!vapply(names, exists, logical(1), mode = "function")]
  if (length(missing)) stop("RED: missing Phase 18 history API: ", paste(missing, collapse = ", "), call. = FALSE)
}

phase18_history_test_registries <- function() {
  schemas <- phase18_club_registry_schemas()
  clubs <- data.frame(
    schema_version = "phase18-club-identity-1",
    club_id = c("club_alpha", "club_beta"), entity_kind = "club",
    canonical_name = c("Alpha FC", "Beta FC"), association_code = c("AAA", "BBB"),
    valid_from_utc = c("2020-01-01T00:00:00Z", "2020-01-01T00:00:00Z"), valid_to_utc = c("", ""),
    club_status = "active", row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  source_ids <- data.frame(
    schema_version = "phase18-club-identity-1", club_id = c("club_alpha", "club_beta"),
    source_system = "openfootball", source_club_id = c("name:alpha_fc", "name:beta_fc"),
    valid_from_utc = c("2020-01-01T00:00:00Z", "2020-01-01T00:00:00Z"), valid_to_utc = c("", ""),
    review_state = "approved", source_bundle_id = "fixture-review", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  aliases <- data.frame(
    schema_version = "phase18-club-identity-1", club_id = c("club_alpha", "club_beta"),
    source_system = "openfootball", alias = c("Alpha FC", "Beta FC"), normalized_alias = c("alpha fc", "beta fc"),
    valid_from_utc = c("2020-01-01T00:00:00Z", "2020-01-01T00:00:00Z"), valid_to_utc = c("", ""),
    review_state = "approved", reviewed_by = "fixture-owner", reviewed_at_utc = "2026-01-01T00:00:00Z",
    row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  registries <- list(clubs = clubs, source_ids = source_ids, aliases = aliases)
  phase18_hash_club_registry_rows(registries)
}

phase18_history_test_source <- function(expected = 5L, status = "active") {
  row <- data.frame(
    schema_version = "phase18-club-history-source-1", source_id = "england-2025-fixture",
    repository_url = "https://github.com/openfootball/england", commit_sha = paste(rep("a", 40), collapse = ""),
    commit_utc = "2026-01-01T00:00:00Z", relative_path = "2025-26/1-premierleague.txt",
    competition_id = "england-premier-league", season_id = "2025-26", license_id = "cc0-1.0",
    license_url = "https://creativecommons.org/publicdomain/zero/1.0/", license_sha256 = paste(rep("b", 64), collapse = ""),
    license_review_state = "approved", license_reviewed_by = "fixture-owner", license_reviewed_at_utc = "2026-01-01T00:00:00Z",
    retrieval_utc = "2026-01-02T00:00:00Z", bytes = "123", raw_sha256 = paste(rep("c", 64), collapse = ""),
    expected_completed_matches = as.character(expected), coverage_reviewed_by = "fixture-owner",
    coverage_reviewed_at_utc = "2026-01-02T00:00:00Z", source_status = status, blocked_reason = "", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  row$row_sha256 <- phase18_club_row_sha256(row)
  row
}

test_that("history schemas and pins are exact and fail closed", {
  phase18_history_test_load()
  phase18_history_test_require(c("phase18_history_source_schema", "phase18_normalized_club_match_schema", "phase18_validate_history_sources"))
  source <- phase18_history_test_source()
  expect_silent(phase18_validate_history_sources(source))
  expect_true(all(c("repository_url", "commit_sha", "raw_sha256", "expected_completed_matches") %in% phase18_history_source_schema()))
  expect_true(all(c("regulation_home_goals", "shootout_home_goals", "evidence_available_at_utc", "counts_for_model") %in% phase18_normalized_club_match_schema()))
  bad <- source; bad$commit_sha <- "main"; bad$row_sha256 <- phase18_club_row_sha256(bad)
  expect_error(phase18_validate_history_sources(bad), class = "invalid_history_source_pin")
  unsafe <- source; unsafe$relative_path <- "../secret"; unsafe$row_sha256 <- phase18_club_row_sha256(unsafe)
  expect_error(phase18_validate_history_sources(unsafe), class = "unsafe_history_source_path")
})

test_that("date-only evidence uses next-day UTC and strict prior-information cutoff", {
  phase18_history_test_load()
  phase18_history_test_require("phase18_normalize_club_history")
  rows <- utils::read.csv(file.path(phase18_history_test_root, "tests/fixtures/phase18/openfootball/score_cases.csv"), stringsAsFactors = FALSE, check.names = FALSE, na.strings = NULL)
  date_only <- rows[rows$source_match_id == "date-only", , drop = FALSE]
  at_cutoff <- phase18_normalize_club_history(date_only, phase18_history_test_source(1L), phase18_history_test_registries(), "2025-05-03T00:00:00Z")
  expect_identical(at_cutoff$kickoff_precision, "date")
  expect_identical(at_cutoff$kickoff_utc, "")
  expect_identical(at_cutoff$evidence_available_at_utc, "2025-05-03T00:00:00Z")
  expect_false(at_cutoff$counts_for_model)
  one_second_later <- phase18_normalize_club_history(date_only, phase18_history_test_source(1L), phase18_history_test_registries(), "2025-05-03T00:00:01Z")
  expect_true(one_second_later$counts_for_model)
  one_second_before <- phase18_normalize_club_history(date_only, phase18_history_test_source(1L), phase18_history_test_registries(), "2025-05-02T23:59:59Z")
  expect_false(one_second_before$counts_for_model)
})

test_that("score meanings remain split and unknown semantics stay auditable", {
  phase18_history_test_load()
  phase18_history_test_require("phase18_normalize_club_history")
  rows <- utils::read.csv(file.path(phase18_history_test_root, "tests/fixtures/phase18/openfootball/score_cases.csv"), stringsAsFactors = FALSE, check.names = FALSE, na.strings = NULL)
  normalized <- phase18_normalize_club_history(rows, phase18_history_test_source(nrow(rows)), phase18_history_test_registries(), "2025-06-01T00:00:00Z")
  extra <- normalized[normalized$source_match_id == "extra-time", , drop = FALSE]
  shootout <- normalized[normalized$source_match_id == "shootout", , drop = FALSE]
  unknown <- normalized[normalized$source_match_id == "unknown-score", , drop = FALSE]
  expect_identical(extra$regulation_home_goals, "1")
  expect_identical(extra$final_home_goals, "2")
  expect_identical(extra$completion_method, "extra_time")
  expect_identical(shootout$shootout_home_goals, "4")
  expect_identical(shootout$final_home_goals, "1")
  expect_true(shootout$counts_for_model)
  expect_false(unknown$counts_for_model)
  expect_identical(unknown$exclusion_reason, "unresolved_score_semantics")
  expect_true(all(grepl("^[0-9a-f]{64}$", normalized$row_sha256)))
})
