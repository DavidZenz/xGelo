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

phase18_history_test_good_matches <- function(count = 5L) {
  rows <- utils::read.csv(file.path(phase18_history_test_root, "tests/fixtures/phase18/openfootball/score_cases.csv"), stringsAsFactors = FALSE, check.names = FALSE, na.strings = NULL)
  rows <- rows[rows$source_match_id == "reg-1", , drop = FALSE]
  rows <- rows[rep(1L, count), , drop = FALSE]
  rows$source_match_id <- paste0("good-", seq_len(count))
  rows$event_date <- format(as.Date("2025-05-01") + seq_len(count) - 1L, "%Y-%m-%d")
  rows$kickoff_utc <- paste0(rows$event_date, "T18:00:00Z")
  rows$evidence_updated_at_utc <- paste0(rows$event_date, "T20:00:00Z")
  phase18_normalize_club_history(rows, phase18_history_test_source(count), phase18_history_test_registries(), "2025-06-01T00:00:00Z")
}

test_that("coverage equality and all zero-tolerance gates fail at one step", {
  phase18_history_test_load()
  phase18_history_test_require("phase18_audit_club_history")
  matches <- phase18_history_test_good_matches(5L)
  source <- phase18_history_test_source(5L)
  passed <- phase18_audit_club_history(matches, source, phase18_history_test_registries(), "2025-06-01T00:00:00Z")
  expect_true(passed$corpus_manifest$accepted_for_training)
  expect_true(passed$coverage_audit$gate_passed)

  one_fewer <- phase18_audit_club_history(matches[-1L, , drop = FALSE], source, phase18_history_test_registries(), "2025-06-01T00:00:00Z")
  expect_false(one_fewer$corpus_manifest$accepted_for_training)
  one_extra <- matches[c(seq_len(nrow(matches)), nrow(matches)), , drop = FALSE]
  one_extra$source_match_id[[nrow(one_extra)]] <- "extra-row"
  one_extra$match_id[[nrow(one_extra)]] <- "clubmatch_extra"
  one_extra$event_date[[nrow(one_extra)]] <- "2025-05-20"
  one_extra$row_sha256 <- phase18_club_row_sha256(one_extra)
  extra_audit <- phase18_audit_club_history(one_extra, source, phase18_history_test_registries(), "2025-06-01T00:00:00Z")
  expect_false(extra_audit$coverage_audit$gate_passed)

  identity_bad <- matches
  identity_bad$home_club_id[[1L]] <- ""
  identity_bad$counts_for_model[[1L]] <- FALSE
  identity_bad$exclusion_reason[[1L]] <- "unresolved_club_identity"
  identity_bad$row_sha256 <- phase18_club_row_sha256(identity_bad)
  expect_false(phase18_audit_club_history(identity_bad, source, phase18_history_test_registries(), "2025-06-01T00:00:00Z")$identity_audit$gate_passed)

  score_bad <- matches
  score_bad$score_semantics[[1L]] <- "unknown"
  score_bad$completion_method[[1L]] <- "unresolved"
  score_bad$counts_for_model[[1L]] <- FALSE
  score_bad$exclusion_reason[[1L]] <- "unresolved_score_semantics"
  score_bad$row_sha256 <- phase18_club_row_sha256(score_bad)
  expect_false(phase18_audit_club_history(score_bad, source, phase18_history_test_registries(), "2025-06-01T00:00:00Z")$score_semantics_audit$gate_passed)

  temporal_bad <- matches
  temporal_bad$evidence_available_at_utc[[1L]] <- "2025-06-01T00:00:00Z"
  temporal_bad$counts_for_model[[1L]] <- FALSE
  temporal_bad$exclusion_reason[[1L]] <- "evidence_not_prior_to_cutoff"
  temporal_bad$row_sha256 <- phase18_club_row_sha256(temporal_bad)
  expect_false(phase18_audit_club_history(temporal_bad, source, phase18_history_test_registries(), "2025-06-01T00:00:00Z")$temporal_audit$gate_passed)
})

test_that("semantic duplicates and pending source review are auditable but blocked", {
  phase18_history_test_load()
  phase18_history_test_require("phase18_audit_club_history")
  matches <- phase18_history_test_good_matches(5L)
  duplicate <- matches[c(seq_len(nrow(matches)), 1L), , drop = FALSE]
  duplicate$source_match_id[[nrow(duplicate)]] <- "cross-source-copy"
  duplicate$match_id[[nrow(duplicate)]] <- "clubmatch_cross_source_copy"
  duplicate$row_sha256 <- phase18_club_row_sha256(duplicate)
  source <- phase18_history_test_source(6L)
  audited <- phase18_audit_club_history(duplicate, source, phase18_history_test_registries(), "2025-06-01T00:00:00Z")
  expect_false(audited$duplicate_audit$gate_passed[[1L]])
  expect_false(audited$corpus_manifest$accepted_for_training)

  pending <- phase18_history_test_source(5L, "blocked_pending_review")
  pending$commit_sha <- ""
  pending$license_review_state <- "pending"
  pending$blocked_reason <- "missing_verified_pin_and_owner_license_review"
  pending$row_sha256 <- phase18_club_row_sha256(pending)
  blocked <- phase18_audit_club_history(phase18_history_empty(phase18_normalized_club_match_schema()), pending, phase18_history_test_registries(), "2025-06-01T00:00:00Z")
  expect_false(blocked$corpus_manifest$accepted_for_training)
  expect_match(blocked$corpus_manifest$blocked_reasons, "source_pin_fraction")
  expect_match(blocked$corpus_manifest$blocked_reasons, "license_fraction")
})

test_that("declared production panel is five seasons by six source families and stays blocked", {
  phase18_history_test_load()
  inventory <- phase18_history_read_csv(file.path(phase18_history_test_root, "data/club/history_sources.csv"))
  expect_equal(nrow(inventory), 30L)
  expect_setequal(unique(inventory$season_id), c("2021-22", "2022-23", "2023-24", "2024-25", "2025-26"))
  expect_equal(length(unique(inventory$repository_url)), 6L)
  expect_true(all(inventory$source_status == "blocked_pending_review"))
  expect_true(all(!grepl("(^|/)(main|master|HEAD)($|/)", inventory$commit_sha)))
  expect_silent(phase18_validate_history_sources(inventory))
})
