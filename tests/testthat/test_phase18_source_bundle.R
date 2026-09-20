library(testthat)

phase18_bundle_test_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase18_bundle_test_load <- function() {
  source(file.path(phase18_bundle_test_root, "R/competition/ucl_source_acceptance.R"), local = .GlobalEnv)
  source(file.path(phase18_bundle_test_root, "R/competition/source_contracts.R"), local = .GlobalEnv)
  source(file.path(phase18_bundle_test_root, "R/competition/edition_registry.R"), local = .GlobalEnv)
  bundle_path <- file.path(phase18_bundle_test_root, "R/competition/ucl_source_bundle.R")
  if (file.exists(bundle_path)) source(bundle_path, local = .GlobalEnv)
  invisible(TRUE)
}

phase18_bundle_test_provider_evidence <- function() {
  review <- utils::read.csv(
    file.path(phase18_bundle_test_root, "tests/fixtures/phase18/provider_terms_review.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  review <- review[review$review_set == "approved", setdiff(names(review), "review_set"), drop = FALSE]
  review <- phase18_hash_terms_review(review)
  expectations <- phase18_hash_edition_expectations(data.frame(
    schema_version = "phase18-edition-expectation-v1", edition_id = "ucl_2026_27",
    lifecycle = "league_phase", expected_club_count = 36L,
    expected_league_phase_match_count = 144L,
    allowed_stages = "LEAGUE_STAGE|PLAYOFFS|LAST_16|QUARTER_FINALS|SEMI_FINALS|FINAL",
    standings_required = TRUE, expected_standings_rows = 36L,
    reviewer = "fixture-reviewer", reviewed_at_utc = "2026-09-19T12:00:00Z",
    row_sha256 = "", expectation_sha256 = "", stringsAsFactors = FALSE,
    check.names = FALSE
  ))
  transport <- function(endpoint, attempt, cache = FALSE) list(
    count = unname(c(competition_metadata = 1L, teams = 36L, matches = 144L, standings = 36L)[[endpoint]]),
    stages = if (endpoint == "matches") "LEAGUE_STAGE" else "",
    freshness_passed = TRUE, identity_passed = TRUE, pagination_complete = TRUE,
    secret_scan_passed = TRUE,
    fingerprint_sha256 = digest::digest(paste0("fixture-schema-", endpoint), algo = "sha256", serialize = FALSE),
    retryable = FALSE
  )
  evidence <- phase18_build_live_probe_evidence(
    transport, review, expectations, "live-bundle-fixture-001", "2026-09-19T12:30:00Z"
  )
  manifest <- phase18_build_acceptance_manifest(
    evidence$machine_checks, review, expectations,
    list(schema_fingerprint_sha256 = evidence$schema_fingerprint_sha256),
    "live-bundle-fixture-001", "2026-09-19T12:30:00Z",
    parser_commit_sha = "0123456789abcdef0123456789abcdef01234567"
  )
  list(
    manifest = manifest, machine_checks = evidence$machine_checks,
    owner_review = review, edition_expectations = expectations,
    schema_fingerprint = evidence$schema_fingerprint
  )
}

phase18_bundle_test_projected <- function(evidence) {
  club_ids <- sprintf("club_%03d", seq_len(36L))
  clubs <- data.frame(
    schema_version = "phase18-fd-club-v1", edition_id = "ucl_2026_27",
    provider_id = "football_data_org_v4", provider_club_id = as.character(1000L + seq_len(36L)),
    club_id = club_ids, display_name = sprintf("Fixture Club %02d", seq_len(36L)),
    canonical_name = sprintf("Fixture Club %02d", seq_len(36L)),
    last_updated_utc = "2026-09-19T11:00:00Z", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  clubs$row_sha256 <- phase18_row_sha256(clubs)
  matches <- data.frame(
    schema_version = "phase18-fd-match-v1", edition_id = "ucl_2026_27",
    provider_match_id = as.character(2000L + seq_len(144L)),
    kickoff_utc = "2026-09-20T18:00:00Z", status = "SCHEDULED", stage = "LEAGUE_STAGE",
    home_club_id = club_ids[((seq_len(144L) - 1L) %% 36L) + 1L],
    away_club_id = club_ids[((seq_len(144L) + 10L) %% 36L) + 1L],
    last_updated_utc = "2026-09-19T11:30:00Z", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  matches$row_sha256 <- phase18_row_sha256(matches)
  standings <- data.frame(
    schema_version = "phase18-fd-standing-v1", edition_id = "ucl_2026_27",
    stage = "LEAGUE_STAGE", position = seq_len(36L), club_id = club_ids,
    played = 0L, points = 0L, row_sha256 = "", stringsAsFactors = FALSE,
    check.names = FALSE
  )
  standings$row_sha256 <- phase18_row_sha256(standings)
  competition <- data.frame(
    schema_version = "phase18-fd-competition-v1", edition_id = "ucl_2026_27",
    provider_id = "football_data_org_v4", provider_competition_id = "2001",
    provider_season_id = "2026", code = "CL", name = "UEFA Champions League",
    last_updated_utc = "2026-09-19T11:45:00Z", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  competition$row_sha256 <- phase18_row_sha256(competition)
  lifecycle <- data.frame(
    schema_version = "phase18-fd-lifecycle-v1", edition_id = "ucl_2026_27",
    lifecycle = "league_phase", observed_club_count = 36L,
    observed_match_count = 144L, observed_standings_rows = 36L,
    observed_stages = "LEAGUE_STAGE",
    expectation_sha256 = evidence$edition_expectations$expectation_sha256[[1L]],
    source_as_of_utc = "2026-09-19T11:45:00Z",
    retrieved_at_utc = "2026-09-19T12:00:00Z", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  lifecycle$row_sha256 <- phase18_row_sha256(lifecycle)
  list(
    competition = competition, clubs = clubs, matches = matches,
    standings = standings, lifecycle = lifecycle,
    schema_fingerprint = evidence$schema_fingerprint
  )
}

phase18_bundle_test_fetched <- function() {
  urls <- setNames(phase18_fd_request_plan()$url, phase18_fd_request_plan()$resource)
  setNames(lapply(names(urls), function(resource) {
    body <- charToRaw(jsonlite::toJSON(list(resource = resource, fixture = TRUE), auto_unbox = TRUE))
    list(
      resource = resource, final_url = urls[[resource]],
      retrieved_at_utc = "2026-09-19T12:00:00Z", body = body,
      raw_sha256 = digest::digest(body, algo = "sha256", serialize = FALSE),
      parsed = list(resource = resource, fixture = TRUE)
    )
  }), names(urls))
}

test_that("provider-live projected resources write and fresh-process validate a candidate bundle", {
  phase18_bundle_test_load()
  required <- c(
    "phase18_validate_source_authority", "phase18_build_ucl_source_bundle",
    "phase18_validate_ucl_source_bundle", "phase18_write_ucl_candidate",
    "phase18_read_ucl_candidate"
  )
  expect_true(all(vapply(required, exists, logical(1), mode = "function")))

  evidence <- phase18_bundle_test_provider_evidence()
  authority <- list(
    authority_type = "provider_acceptance",
    provider_acceptance = evidence
  )
  candidate <- phase18_build_ucl_source_bundle(
    phase18_bundle_test_projected(evidence), phase18_bundle_test_fetched(), authority,
    evidence$edition_expectations, "ucl-2026-27-provider-fixture-v1"
  )
  expect_silent(phase18_validate_ucl_source_bundle(candidate))
  expect_true(candidate$bundle$promotion_eligible[[1L]])
  expect_identical(candidate$bundle$authority_type[[1L]], "provider_acceptance")

  root <- tempfile("phase18-ucl-candidate-")
  expect_silent(phase18_write_ucl_candidate(root, candidate))
  expect_setequal(
    list.files(root),
    c("artifacts.csv", "authority.csv", "bundle.csv", "raw", "table_manifest.csv", "tables", "authority_evidence")
  )
  expression <- sprintf(
    "source(%s); source(%s); x <- phase18_read_ucl_candidate(%s); phase18_validate_ucl_source_bundle(x)",
    dQuote(file.path(phase18_bundle_test_root, "R/competition/ucl_source_acceptance.R")),
    dQuote(file.path(phase18_bundle_test_root, "R/competition/ucl_source_bundle.R")), dQuote(root)
  )
  output <- system2("Rscript", c("--vanilla", "-e", shQuote(expression)), stdout = TRUE, stderr = TRUE)
  expect_equal(attr(output, "status") %||% 0L, 0L, info = paste(output, collapse = "\n"))
})
