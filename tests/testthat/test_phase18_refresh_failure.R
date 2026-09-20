library(testthat)

phase18_refresh_test_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase18_refresh_test_load <- function() {
  files <- c(
    "R/competition/ucl_source_acceptance.R",
    "R/competition/source_contracts.R",
    "R/competition/edition_registry.R",
    "R/competition/football_data_org_adapter.R",
    "R/competition/ucl_source_bundle.R",
    "R/competition/ucl_source_refresh.R"
  )
  for (relative in files) {
    path <- file.path(phase18_refresh_test_root, relative)
    if (file.exists(path)) source(path, local = .GlobalEnv)
  }
  invisible(TRUE)
}

phase18_refresh_test_evidence <- function() {
  review <- utils::read.csv(
    file.path(phase18_refresh_test_root, "tests/fixtures/phase18/provider_terms_review.csv"),
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
  list(owner_review = review, edition_expectations = expectations)
}

phase18_refresh_test_projected <- function(evidence) {
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
  fingerprint <- data.frame(
    resource = phase18_ucl_required_resources(),
    fingerprint_sha256 = vapply(phase18_ucl_required_resources(), phase18_ucl_hash, character(1)),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  list(
    competition = competition, clubs = clubs, matches = matches,
    standings = standings, lifecycle = lifecycle, schema_fingerprint = fingerprint
  )
}

phase18_refresh_test_fetched <- function(suffix = "candidate") {
  resources <- phase18_ucl_required_resources()
  urls <- c(
    competition_metadata = "https://api.football-data.org/v4/competitions/CL",
    teams = "https://api.football-data.org/v4/competitions/CL/teams?season=2026",
    matches = "https://api.football-data.org/v4/competitions/CL/matches?season=2026",
    standings = "https://api.football-data.org/v4/competitions/CL/standings?season=2026"
  )
  setNames(lapply(resources, function(resource) {
    body <- charToRaw(jsonlite::toJSON(list(resource = resource, version = suffix), auto_unbox = TRUE))
    list(
      resource = resource, final_url = urls[[resource]],
      retrieved_at_utc = "2026-09-19T12:00:00Z", body = body,
      raw_sha256 = phase18_ucl_hash(body), parsed = list(resource = resource)
    )
  }), resources)
}

phase18_refresh_test_manual_review <- function(id, raw_hash) {
  review <- data.frame(
    schema_version = "phase18-ucl-manual-source-review-v1",
    manual_review_id = id, edition_id = "ucl_2026_27", decision = "accepted",
    source_url = "https://manual.example/ucl-2026-27.json", license_id = "fixture-test-only",
    reviewer = "fixture-reviewer", reviewed_at_utc = "2026-09-19T12:00:00Z",
    aggregate_raw_sha256 = raw_hash, manual_review_sha256 = "", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  review$manual_review_sha256 <- phase18_ucl_manual_review_hash(review)
  review$row_sha256 <- phase18_row_sha256(review)
  review
}

phase18_refresh_test_candidate <- function(id, suffix = id) {
  evidence <- phase18_refresh_test_evidence()
  fetched <- phase18_refresh_test_fetched(suffix)
  aggregate <- phase18_ucl_hash(paste(vapply(fetched, `[[`, character(1), "raw_sha256"), collapse = "|"))
  phase18_build_ucl_source_bundle(
    phase18_refresh_test_projected(evidence), fetched,
    list(
      authority_type = "manual_source_review",
      manual_source_review = phase18_refresh_test_manual_review(paste0("manual-", id), aggregate)
    ),
    evidence$edition_expectations, id
  )
}

phase18_refresh_test_sandbox <- function(with_incumbent = TRUE) {
  root <- tempfile("phase18-refresh-")
  accepted_root <- file.path(root, "accepted")
  registry_root <- file.path(root, "registries")
  candidate_root <- file.path(root, "candidates", "candidate-v2")
  acceptance_root <- file.path(root, "provider_acceptance")
  dir.create(accepted_root, recursive = TRUE)
  dir.create(registry_root, recursive = TRUE)
  dir.create(acceptance_root, recursive = TRUE)
  if (with_incumbent) {
    phase18_write_ucl_candidate(
      file.path(accepted_root, "ucl_2026_27"),
      phase18_refresh_test_candidate("ucl-refresh-incumbent-v1", "incumbent")
    )
  }
  phase18_write_ucl_candidate(
    candidate_root,
    phase18_refresh_test_candidate("ucl-refresh-candidate-v2", "candidate")
  )
  list(
    root = root, accepted_root = accepted_root, registry_root = registry_root,
    candidate_root = candidate_root, acceptance_root = acceptance_root
  )
}

phase18_refresh_test_snapshot <- function(root) {
  if (!dir.exists(root)) return(setNames(list(), character()))
  files <- list.files(root, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE)
  files <- files[!file.info(files)$isdir]
  relative <- substring(files, nchar(normalizePath(root, winslash = "/", mustWork = TRUE)) + 2L)
  setNames(lapply(files, function(path) readBin(path, "raw", n = file.info(path)$size)), relative)
}

test_that("locked refresh promotes only a complete manual-authorized candidate", {
  phase18_refresh_test_load()
  required <- c(
    "phase18_ucl_refresh_reason_codes", "phase18_classify_ucl_refresh_failure",
    "phase18_refresh_ucl_source", "phase18_validate_ucl_refresh_state"
  )
  expect_true(all(vapply(required, exists, logical(1), mode = "function")))
  sandbox <- phase18_refresh_test_sandbox()
  on.exit(unlink(sandbox$root, recursive = TRUE, force = TRUE), add = TRUE)

  result <- phase18_refresh_ucl_source(
    sandbox$candidate_root, sandbox$accepted_root, sandbox$registry_root,
    sandbox$acceptance_root, now_utc = "2026-09-20T10:00:00Z"
  )
  expect_identical(result$status, "accepted")
  installed <- phase18_read_ucl_candidate(file.path(sandbox$accepted_root, "ucl_2026_27"))
  expect_identical(installed$bundle$bundle_id[[1L]], "ucl-refresh-candidate-v2")
  expect_silent(phase18_validate_ucl_source_bundle(installed))
  expect_false(any(grepl("[.]phase18-ucl-refresh-(stage|backup|lock)", list.files(sandbox$root, all.files = TRUE))))
  history <- utils::read.csv(
    file.path(sandbox$registry_root, "ucl_source_refreshes.csv"),
    stringsAsFactors = FALSE, check.names = FALSE, na.strings = NULL
  )
  expect_silent(phase18_validate_ucl_refresh_state(history, NULL, sandbox$accepted_root))
})

test_that("every ordered promotion failure restores the incumbent byte for byte", {
  phase18_refresh_test_load()
  probe <- phase18_refresh_test_sandbox()
  inventory <- sort(list.files(probe$candidate_root, recursive = TRUE, full.names = FALSE))
  unlink(probe$root, recursive = TRUE, force = TRUE)

  for (failure_index in seq_along(inventory)) {
    sandbox <- phase18_refresh_test_sandbox()
    before <- phase18_refresh_test_snapshot(file.path(sandbox$accepted_root, "ucl_2026_27"))
    result <- phase18_refresh_ucl_source(
      sandbox$candidate_root, sandbox$accepted_root, sandbox$registry_root,
      sandbox$acceptance_root,
      writer_hooks = list(after_promotion = function(index, path, ...) {
        if (identical(index, failure_index)) stop("injected ordered promotion failure", call. = FALSE)
      }),
      now_utc = sprintf("2026-09-20T10:%02d:00Z", failure_index)
    )
    expect_identical(result$status, "blocked", info = paste("promotion index", failure_index))
    expect_identical(result$reason_code, "promotion_failure")
    expect_identical(
      phase18_refresh_test_snapshot(file.path(sandbox$accepted_root, "ucl_2026_27")),
      before,
      info = paste("promotion index", failure_index)
    )
    expect_false(any(grepl("[.]phase18-ucl-refresh-(stage|backup|lock)", list.files(sandbox$root, all.files = TRUE))))
    unlink(sandbox$root, recursive = TRUE, force = TRUE)
  }
})

test_that("read-back, interruption, and concurrent failures preserve incumbent bytes", {
  phase18_refresh_test_load()
  cases <- list(
    readback = list(hook = "before_readback", reason = "read_back_failure"),
    interrupted = list(hook = "interrupt", reason = "interrupted")
  )
  for (case in cases) {
    sandbox <- phase18_refresh_test_sandbox()
    before <- phase18_refresh_test_snapshot(file.path(sandbox$accepted_root, "ucl_2026_27"))
    hooks <- setNames(list(function(...) stop("injected failure", call. = FALSE)), case$hook)
    result <- phase18_refresh_ucl_source(
      sandbox$candidate_root, sandbox$accepted_root, sandbox$registry_root,
      sandbox$acceptance_root, writer_hooks = hooks, now_utc = "2026-09-20T11:00:00Z"
    )
    expect_identical(result$reason_code, case$reason)
    expect_identical(phase18_refresh_test_snapshot(file.path(sandbox$accepted_root, "ucl_2026_27")), before)
    unlink(sandbox$root, recursive = TRUE, force = TRUE)
  }

  sandbox <- phase18_refresh_test_sandbox()
  before <- phase18_refresh_test_snapshot(file.path(sandbox$accepted_root, "ucl_2026_27"))
  dir.create(file.path(sandbox$root, ".phase18-ucl-refresh.lock"))
  result <- phase18_refresh_ucl_source(
    sandbox$candidate_root, sandbox$accepted_root, sandbox$registry_root,
    sandbox$acceptance_root, now_utc = "2026-09-20T11:01:00Z"
  )
  expect_identical(result$reason_code, "concurrent_refresh")
  expect_identical(phase18_refresh_test_snapshot(file.path(sandbox$accepted_root, "ucl_2026_27")), before)
  unlink(sandbox$root, recursive = TRUE, force = TRUE)
})

test_that("failed first refresh preserves no incumbent and invalid authority never promotes", {
  phase18_refresh_test_load()
  sandbox <- phase18_refresh_test_sandbox(with_incumbent = FALSE)
  unlink(sandbox$candidate_root, recursive = TRUE, force = TRUE)
  result <- phase18_refresh_ucl_source(
    sandbox$candidate_root, sandbox$accepted_root, sandbox$registry_root,
    sandbox$acceptance_root, now_utc = "2026-09-20T12:00:00Z"
  )
  expect_identical(result$status, "blocked")
  expect_identical(result$incumbent_status, "no_incumbent")
  expect_false(dir.exists(file.path(sandbox$accepted_root, "ucl_2026_27")))

  fixture <- phase18_refresh_test_candidate("ucl-refresh-fixture-v1")
  contract <- data.frame(
    schema_version = "phase18-ucl-fixture-contract-v1", fixture_id = "fixture-refresh-001",
    edition_id = "ucl_2026_27", fixture_purpose = "tests", fixture_sha256 = "",
    row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  contract$fixture_sha256 <- phase18_ucl_fixture_hash(contract)
  contract$row_sha256 <- phase18_row_sha256(contract)
  evidence <- phase18_refresh_test_evidence()
  fixture <- phase18_build_ucl_source_bundle(
    phase18_refresh_test_projected(evidence), phase18_refresh_test_fetched("fixture"),
    list(authority_type = "fixture_contract", fixture_contract = contract),
    evidence$edition_expectations, "ucl-refresh-fixture-v1"
  )
  fixture_root <- file.path(sandbox$root, "candidates", "fixture")
  phase18_write_ucl_candidate(fixture_root, fixture)
  result <- phase18_refresh_ucl_source(
    fixture_root, sandbox$accepted_root, sandbox$registry_root,
    sandbox$acceptance_root, now_utc = "2026-09-20T12:01:00Z"
  )
  expect_identical(result$reason_code, "fixture_non_promotable")
  expect_false(dir.exists(file.path(sandbox$accepted_root, "ucl_2026_27")))
  unlink(sandbox$root, recursive = TRUE, force = TRUE)
})

