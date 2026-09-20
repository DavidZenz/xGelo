library(testthat)

phase18_refresh_test_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase18_refresh_test_load <- function() {
  files <- c(
    "R/common/phase18_canonical_hash.R",
    "R/competition/ucl_source_acceptance.R",
    "R/competition/source_contracts.R",
    "R/competition/edition_registry.R",
    "R/competition/football_data_org_adapter.R",
    "R/competition/ucl_source_bundle.R",
    "R/competition/ucl_source_refresh.R"
  )
  for (relative in files) {
    path <- file.path(phase18_refresh_test_root, relative)
    source(path, local = .GlobalEnv)
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

phase18_refresh_test_exit_review <- function(
    disposition, retained_paths = character(), retained_hashes = character(),
    retention_permitted = identical(disposition, "retain"),
    display_permitted = identical(disposition, "retain")) {
  review <- data.frame(
    schema_version = "phase18-ucl-provider-exit-review-v1",
    exit_review_id = paste0("exit-review-", disposition, "-001"),
    provider_id = "football_data_org_v4", edition_id = "ucl_2026_27",
    decision = "reviewed", exit_disposition = disposition,
    retention_permitted = retention_permitted, display_permitted = display_permitted,
    terms_sha256 = phase18_ucl_hash("reviewed provider terms"),
    provider_decision_id = "provider-accepted-before-exit",
    provider_decision_sha256 = phase18_ucl_hash("accepted provider decision"),
    reviewer = "fixture-compliance-reviewer", reviewed_at_utc = "2026-09-20T13:00:00Z",
    reason = "provider relationship ended",
    retained_relative_paths = paste(retained_paths, collapse = "|"),
    retained_inventory_sha256s = paste(retained_hashes, collapse = "|"),
    exit_review_sha256 = "", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  phase18_hash_ucl_provider_exit_review(review)
}

phase18_refresh_test_exit_sandbox <- function() {
  root <- tempfile("phase18-provider-exit-")
  accepted_root <- file.path(root, "accepted")
  registry_root <- file.path(root, "registries")
  target <- file.path(accepted_root, "ucl_2026_27")
  dir.create(file.path(target, "manual_open"), recursive = TRUE)
  dir.create(registry_root, recursive = TRUE)
  writeBin(charToRaw("provider-derived-public-bytes"), file.path(target, "provider_public.csv"))
  writeBin(charToRaw("independently-lawful-manual-bytes"), file.path(target, "manual_open", "reviewed.csv"))
  list(root = root, accepted_root = accepted_root, registry_root = registry_root, target = target)
}

test_that("blocked history and sidecar are hash-linked and recovery uses a new batch", {
  phase18_refresh_test_load()
  sandbox <- phase18_refresh_test_sandbox(with_incumbent = TRUE)
  missing <- file.path(sandbox$root, "candidates", "missing")
  blocked <- phase18_refresh_ucl_source(
    missing, sandbox$accepted_root, sandbox$registry_root, sandbox$acceptance_root,
    now_utc = "2026-09-20T13:00:00Z"
  )
  expect_true(blocked$recorded)
  history_path <- file.path(sandbox$registry_root, "ucl_source_refreshes.csv")
  sidecar_path <- file.path(sandbox$registry_root, "ucl_source_blocked_refresh.json")
  history <- phase18_ucl_refresh_read_history(history_path)
  sidecar <- jsonlite::fromJSON(sidecar_path, simplifyVector = TRUE)
  expect_silent(phase18_validate_ucl_refresh_state(history, sidecar, sandbox$accepted_root))
  expect_identical(sidecar$refresh_batch_id, blocked$refresh_batch_id)
  expect_identical(sidecar$history_row_sha256, history$row_sha256[[1L]])
  expect_identical(sidecar$blocked_record_sha256, history$blocked_record_sha256[[1L]])

  recovered <- phase18_refresh_ucl_source(
    sandbox$candidate_root, sandbox$accepted_root, sandbox$registry_root, sandbox$acceptance_root,
    now_utc = "2026-09-20T13:01:00Z"
  )
  history <- phase18_ucl_refresh_read_history(history_path)
  expect_identical(as.character(history$status), c("blocked", "accepted"))
  expect_equal(anyDuplicated(as.character(history$refresh_batch_id)), 0L)
  expect_false(file.exists(sidecar_path))
  expect_silent(phase18_validate_ucl_refresh_state(history, NULL, sandbox$accepted_root))
  expect_false(identical(blocked$refresh_batch_id, recovered$refresh_batch_id))
  unlink(sandbox$root, recursive = TRUE, force = TRUE)
})

test_that("blocked sidecar cannot disagree with its history reason", {
  phase18_refresh_test_load()
  sandbox <- phase18_refresh_test_sandbox()
  phase18_refresh_ucl_source(
    file.path(sandbox$root, "missing"), sandbox$accepted_root, sandbox$registry_root,
    sandbox$acceptance_root, now_utc = "2026-09-20T13:30:00Z"
  )
  history <- phase18_ucl_refresh_read_history(file.path(sandbox$registry_root, "ucl_source_refreshes.csv"))
  sidecar <- jsonlite::fromJSON(
    file.path(sandbox$registry_root, "ucl_source_blocked_refresh.json"), simplifyVector = TRUE
  )
  sidecar$reason_code <- "http_failure"
  sidecar$blocked_record_sha256 <- phase18_ucl_refresh_sidecar_hash(sidecar)
  history$blocked_record_sha256[[nrow(history)]] <- sidecar$blocked_record_sha256
  expect_error(
    phase18_validate_ucl_refresh_state(history, sidecar, sandbox$accepted_root),
    "disagree"
  )
  unlink(sandbox$root, recursive = TRUE, force = TRUE)
})

test_that("required technical reasons are closed and sanitized", {
  phase18_refresh_test_load()
  required <- c(
    "missing_credential", "owner_review_required", "authority_invalid",
    "fixture_non_promotable", "http_failure", "rate_limited", "null_response",
    "empty_response", "stale_response", "incomplete_pagination", "schema_invalid",
    "expectation_mismatch", "coverage_invalid", "identity_invalid",
    "provenance_collision", "secret_exposure", "concurrent_refresh", "interrupted",
    "provider_exit_required", "promotion_failure", "read_back_failure"
  )
  expect_setequal(intersect(required, phase18_ucl_refresh_reason_codes()), required)
  probes <- c(
    "HTTP 503 server error" = "http_failure",
    "HTTP 429 rate limit" = "rate_limited",
    "null response" = "null_response",
    "stale freshness evidence" = "stale_response",
    "incomplete pagination" = "incomplete_pagination",
    "secret exposure detected" = "secret_exposure"
  )
  classified <- vapply(names(probes), function(message) {
    phase18_classify_ucl_refresh_failure(simpleError(message))$reason_code
  }, character(1))
  expect_identical(unname(classified), unname(probes))
})

test_that("history and sidecar writer failures never corrupt accepted state", {
  phase18_refresh_test_load()
  sandbox <- phase18_refresh_test_sandbox()
  accepted_before <- phase18_refresh_test_snapshot(file.path(sandbox$accepted_root, "ucl_2026_27"))
  result <- phase18_refresh_ucl_source(
    sandbox$candidate_root, sandbox$accepted_root, sandbox$registry_root,
    sandbox$acceptance_root,
    writer_hooks = list(history_writer = function(...) stop("injected history writer failure")),
    now_utc = "2026-09-20T14:00:00Z"
  )
  expect_identical(result$reason_code, "history_write_failure")
  expect_identical(phase18_refresh_test_snapshot(file.path(sandbox$accepted_root, "ucl_2026_27")), accepted_before)
  expect_true(result$recorded)
  unlink(sandbox$root, recursive = TRUE, force = TRUE)

  sandbox <- phase18_refresh_test_sandbox()
  accepted_before <- phase18_refresh_test_snapshot(file.path(sandbox$accepted_root, "ucl_2026_27"))
  result <- phase18_refresh_ucl_source(
    file.path(sandbox$root, "missing"), sandbox$accepted_root, sandbox$registry_root,
    sandbox$acceptance_root,
    writer_hooks = list(sidecar_writer = function(...) stop("injected sidecar writer failure")),
    now_utc = "2026-09-20T14:01:00Z"
  )
  expect_identical(phase18_refresh_test_snapshot(file.path(sandbox$accepted_root, "ucl_2026_27")), accepted_before)
  expect_identical(result$reason_code, "sidecar_write_failure")
  expect_true(result$recorded)
  history <- phase18_ucl_refresh_read_history(file.path(sandbox$registry_root, "ucl_source_refreshes.csv"))
  sidecar <- jsonlite::fromJSON(file.path(sandbox$registry_root, "ucl_source_blocked_refresh.json"), simplifyVector = TRUE)
  expect_silent(phase18_validate_ucl_refresh_state(history, sidecar, sandbox$accepted_root))
  unlink(sandbox$root, recursive = TRUE, force = TRUE)
})

test_that("reviewed retain preserves every byte and disables automation", {
  phase18_refresh_test_load()
  sandbox <- phase18_refresh_test_exit_sandbox()
  before <- phase18_refresh_test_snapshot(sandbox$target)
  review <- phase18_refresh_test_exit_review("retain")
  result <- phase18_apply_provider_exit(
    review, sandbox$accepted_root, sandbox$registry_root,
    now_utc = "2026-09-20T15:00:00Z"
  )
  expect_identical(result$status, "retained_last_known_good")
  expect_false(result$automation_enabled)
  expect_identical(phase18_refresh_test_snapshot(sandbox$target), before)
  history <- phase18_ucl_refresh_read_history(file.path(sandbox$registry_root, "ucl_source_refreshes.csv"))
  expect_identical(history$status[[1L]], "retained_last_known_good")
  expect_identical(history$disposition[[1L]], "retain")
  expect_false(phase18_ucl_refresh_bool(history$automation_enabled[[1L]], "automation_enabled"))
  unlink(sandbox$root, recursive = TRUE, force = TRUE)
})

test_that("reviewed withdraw removes provider bytes, preserves lawful bytes, and writes a tombstone", {
  phase18_refresh_test_load()
  sandbox <- phase18_refresh_test_exit_sandbox()
  retained_path <- file.path("manual_open", "reviewed.csv")
  retained_bytes <- readBin(file.path(sandbox$target, retained_path), "raw", n = file.info(file.path(sandbox$target, retained_path))$size)
  retained_hash <- phase18_ucl_hash(retained_bytes)
  review <- phase18_refresh_test_exit_review("withdraw", retained_path, retained_hash)
  result <- phase18_apply_provider_exit(
    review, sandbox$accepted_root, sandbox$registry_root,
    now_utc = "2026-09-20T16:00:00Z"
  )
  expect_identical(result$status, "source_unavailable")
  expect_false(result$automation_enabled)
  expect_false(file.exists(file.path(sandbox$target, "provider_public.csv")))
  expect_identical(
    readBin(file.path(sandbox$target, retained_path), "raw", n = file.info(file.path(sandbox$target, retained_path))$size),
    retained_bytes
  )
  expect_silent(phase18_validate_ucl_unavailable_tombstone(result$tombstone_path))
  expect_setequal(
    list.files(sandbox$target, recursive = TRUE),
    c(retained_path, "source_unavailable.json")
  )
  unlink(sandbox$root, recursive = TRUE, force = TRUE)
})

test_that("failed provider withdrawal restores the complete pre-exit tree", {
  phase18_refresh_test_load()
  sandbox <- phase18_refresh_test_exit_sandbox()
  before <- phase18_refresh_test_snapshot(sandbox$target)
  retained_path <- file.path("manual_open", "reviewed.csv")
  retained_hash <- phase18_ucl_hash(readBin(
    file.path(sandbox$target, retained_path), "raw", n = file.info(file.path(sandbox$target, retained_path))$size
  ))
  review <- phase18_refresh_test_exit_review("withdraw", retained_path, retained_hash)
  expect_error(
    phase18_apply_provider_exit(
      review, sandbox$accepted_root, sandbox$registry_root,
      writer_hooks = list(after_provider_exit_swap = function(...) stop("injected withdrawal failure")),
      now_utc = "2026-09-20T17:00:00Z"
    ),
    "after_provider_exit_swap|promotion"
  )
  expect_identical(phase18_refresh_test_snapshot(sandbox$target), before)
  expect_false(any(grepl("[.]phase18-ucl-exit-(stage|backup)", list.files(sandbox$root, all.files = TRUE))))
  unlink(sandbox$root, recursive = TRUE, force = TRUE)
})

test_that("provider exit cannot retain without explicit reviewed permission", {
  phase18_refresh_test_load()
  sandbox <- phase18_refresh_test_exit_sandbox()
  before <- phase18_refresh_test_snapshot(sandbox$target)
  review <- phase18_refresh_test_exit_review(
    "retain", retention_permitted = FALSE, display_permitted = FALSE
  )
  expect_error(
    phase18_apply_provider_exit(review, sandbox$accepted_root, sandbox$registry_root),
    class = "phase18_refresh_provider_exit_required"
  )
  expect_identical(phase18_refresh_test_snapshot(sandbox$target), before)
  unlink(sandbox$root, recursive = TRUE, force = TRUE)
})
