library(testthat)

phase18_refresh_test_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."), winslash = "/")

phase18_refresh_test_load <- function() {
  source(file.path(phase18_refresh_test_root, "R/common/phase18_canonical_hash.R"), local = .GlobalEnv)
  for (relative in c("R/competition/ucl_source_acceptance.R", "R/competition/source_contracts.R", "R/competition/edition_registry.R",
    "R/competition/football_data_org_adapter.R", "R/competition/ucl_source_bundle.R",
    "R/competition/ucl_source_refresh.R")) source(file.path(phase18_refresh_test_root, relative), local = .GlobalEnv)
}

phase18_refresh_test_evidence <- function() {
  review <- utils::read.csv(file.path(phase18_refresh_test_root, "tests/fixtures/phase18/provider_terms_review.csv"),
    stringsAsFactors = FALSE, check.names = FALSE)
  review <- review[review$review_set == "approved", setdiff(names(review), "review_set"), drop = FALSE]
  review$reviewer <- "refresh-owner-reviewer"
  review <- phase18_hash_terms_review(review)
  expectations <- phase18_hash_edition_expectations(data.frame(
    schema_version = "phase18-edition-expectation-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
    edition_id = "ucl_2026_27", lifecycle = "league_phase", expected_club_count = 36L,
    expected_league_phase_match_count = 144L,
    allowed_stages = "LEAGUE_STAGE|PLAYOFFS|LAST_16|QUARTER_FINALS|SEMI_FINALS|FINAL",
    standings_required = TRUE, expected_standings_rows = 36L, review_state = "approved",
    reviewer = "refresh-owner-reviewer", reviewed_at_utc = "2026-09-19T12:00:00Z",
    stringsAsFactors = FALSE, check.names = FALSE))
  list(owner_review = review, edition_expectations = expectations)
}

phase18_refresh_test_fetched <- function(suffix = "candidate") {
  resources <- phase18_ucl_required_resources(); urls <- setNames(phase18_fd_request_plan()$url, phase18_fd_request_plan()$resource)
  setNames(lapply(resources, function(resource) {
    body <- charToRaw(jsonlite::toJSON(list(resource = resource, version = suffix), auto_unbox = TRUE))
    list(resource = resource, final_url = urls[[resource]], retrieved_at_utc = "2026-09-19T12:00:00Z",
      body = body, raw_sha256 = phase18_ucl_hash(body), parsed = list(resource = resource))
  }), resources)
}

phase18_refresh_test_projected <- function(evidence) {
  ids <- sprintf("club_%03d", seq_len(36L))
  clubs <- data.frame(schema_version = "phase18-fd-club-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
    edition_id = "ucl_2026_27", provider_id = "football_data_org_v4", provider_club_id = as.character(1000L + seq_len(36L)),
    club_id = ids, display_name = sprintf("Fixture Club %02d", seq_len(36L)), canonical_name = sprintf("Fixture Club %02d", seq_len(36L)),
    last_updated_utc = "2026-09-19T11:00:00Z", row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE)
  clubs$row_sha256 <- phase18_ucl_projected_row_hash(clubs)
  matches <- data.frame(schema_version = "phase18-fd-match-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
    edition_id = "ucl_2026_27", provider_match_id = as.character(2000L + seq_len(144L)), kickoff_utc = "2026-09-20T18:00:00Z",
    status = "SCHEDULED", stage = "LEAGUE_STAGE", home_club_id = ids[((seq_len(144L) - 1L) %% 36L) + 1L],
    away_club_id = ids[((seq_len(144L) + 10L) %% 36L) + 1L], last_updated_utc = "2026-09-19T11:30:00Z",
    row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE)
  matches$row_sha256 <- phase18_ucl_projected_row_hash(matches)
  standings <- data.frame(schema_version = "phase18-fd-standing-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
    edition_id = "ucl_2026_27", stage = "LEAGUE_STAGE", position = seq_len(36L), club_id = ids, played = 0L, points = 0L,
    row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE)
  standings$row_sha256 <- phase18_ucl_projected_row_hash(standings)
  competition <- data.frame(schema_version = "phase18-fd-competition-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
    edition_id = "ucl_2026_27", provider_id = "football_data_org_v4", provider_competition_id = "2001", provider_season_id = "2026",
    code = "CL", name = "UEFA Champions League", last_updated_utc = "2026-09-19T11:45:00Z", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE)
  competition$row_sha256 <- phase18_ucl_projected_row_hash(competition)
  lifecycle <- data.frame(schema_version = "phase18-fd-lifecycle-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
    edition_id = "ucl_2026_27", lifecycle = "league_phase", observed_club_count = 36L, observed_match_count = 144L,
    observed_standings_rows = 36L, observed_stages = "LEAGUE_STAGE", expectation_sha256 = evidence$edition_expectations$expectation_sha256[[1L]],
    source_as_of_utc = "2026-09-19T11:45:00Z", retrieved_at_utc = "2026-09-19T12:00:00Z", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE)
  lifecycle$row_sha256 <- phase18_ucl_projected_row_hash(lifecycle)
  fingerprint <- evidence$schema_fingerprint %||% phase18_hash_schema_fingerprint(data.frame(
    resource = phase18_ucl_required_resources(), endpoint = unname(phase18_probe_endpoints()), observed = TRUE,
    observed_at_utc = "2026-09-19T12:00:00Z",
    fingerprint_sha256 = vapply(phase18_ucl_required_resources(), function(x) phase18_hash_scalar_v2(x, "resource", "character"), character(1)),
    stringsAsFactors = FALSE, check.names = FALSE))
  list(competition = competition, clubs = clubs, matches = matches, standings = standings,
    lifecycle = lifecycle, schema_fingerprint = fingerprint)
}

phase18_refresh_test_provider_evidence <- function(evidence_root = NULL) {
  base <- phase18_refresh_test_evidence()
  transport <- function(endpoint, attempt, cache = FALSE) list(
    count = unname(c(competition_metadata = 1L, teams = 36L, matches = 144L, standings = 36L)[[endpoint]]),
    stages = if (endpoint == "matches") "LEAGUE_STAGE" else "", freshness_passed = TRUE,
    identity_passed = TRUE, pagination_complete = TRUE, secret_scan_passed = TRUE,
    fingerprint_sha256 = phase18_hash_scalar_v2(paste0("schema-", endpoint), "fingerprint", "character"),
    capability_evidence = if (endpoint == "competition_metadata") list(
      filters = "fixed filters observed", pagination = "pagination observed",
      authenticated_headers = "process-local auth observed", rate_limits = "rate handling observed",
      null_empty_semantics = "null semantics observed", attribution = "attribution observed",
      provider_exit = "provider exit observed") else NULL, retryable = FALSE)
  evidence <- phase18_build_live_probe_evidence(transport, base$owner_review, base$edition_expectations,
    "live-refresh-fixture-001", "2026-09-19T12:30:00Z")
  if (!isTRUE(evidence$valid)) stop(evidence$message, call. = FALSE)
  manifest <- phase18_build_acceptance_manifest(evidence$machine_checks, base$owner_review,
    base$edition_expectations, evidence$schema_fingerprint, "live-refresh-fixture-001",
    "2026-09-19T12:30:00Z", parser_commit_sha = "0123456789abcdef0123456789abcdef01234567")
  if (is.null(evidence_root)) evidence_root <- tempfile("phase18-refresh-acceptance-")
  published <- phase18_publish_acceptance_generation(evidence_root, base$owner_review,
    base$edition_expectations, evidence$machine_checks, evidence$schema_fingerprint, manifest,
    "# Synthetic refresh provider authority\n")
  published[c("manifest", "machine_checks", "owner_review", "edition_expectations",
    "schema_fingerprint", "pointer", "current_generation", "generation_root")]
}

phase18_refresh_test_candidate <- function(id, suffix = id, authority = "manual", provider_evidence = NULL) {
  evidence <- if (identical(authority, "provider")) provider_evidence else phase18_refresh_test_evidence()
  fetched <- phase18_refresh_test_fetched(suffix)
  if (identical(authority, "manual")) {
    review <- data.frame(schema_version = "phase18-ucl-manual-source-review-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
      manual_review_id = paste0("manual-", id), edition_id = "ucl_2026_27", decision = "accepted",
      source_url = "https://manual.example/ucl.json", license_id = "fixture-test-only", reviewer = "fixture-reviewer",
      reviewed_at_utc = "2026-09-19T12:00:00Z", aggregate_raw_sha256 = phase18_ucl_raw_aggregate_sha256(fetched),
      manual_review_sha256 = "", row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE)
    review$manual_review_sha256 <- phase18_ucl_manual_review_hash(review); review$row_sha256 <- phase18_ucl_row_hash(review)
    auth <- list(authority_type = "manual_source_review", manual_source_review = review)
  } else if (identical(authority, "fixture")) {
    contract <- data.frame(schema_version = "phase18-ucl-fixture-contract-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
      fixture_id = paste0("fixture-", id), edition_id = "ucl_2026_27", fixture_purpose = "offline contract test",
      aggregate_raw_sha256 = phase18_ucl_raw_aggregate_sha256(fetched), fixture_sha256 = "", row_sha256 = "",
      stringsAsFactors = FALSE, check.names = FALSE)
    contract$fixture_sha256 <- phase18_ucl_fixture_hash(contract); contract$row_sha256 <- phase18_ucl_row_hash(contract)
    auth <- list(authority_type = "fixture_contract", fixture_contract = contract)
  } else {
    auth <- list(authority_type = "provider_acceptance", provider_acceptance = evidence)
  }
  phase18_build_ucl_source_bundle(phase18_refresh_test_projected(evidence), fetched, auth, evidence$edition_expectations, id)
}

phase18_refresh_test_sandbox <- function() {
  root <- tempfile("phase18-refresh-"); accepted <- file.path(root, "accepted"); registries <- file.path(root, "registries")
  candidate <- file.path(root, "candidates", "candidate"); acceptance <- file.path(root, "provider_acceptance")
  dir.create(accepted, recursive = TRUE); dir.create(registries); dir.create(acceptance)
  phase18_write_ucl_candidate(candidate, phase18_refresh_test_candidate("ucl-refresh-candidate-v2"))
  list(root = root, accepted_root = accepted, registry_root = registries, candidate_root = candidate, acceptance_root = acceptance)
}

phase18_refresh_test_snapshot <- function(root) {
  files <- sort(list.files(root, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE)); files <- files[!file.info(files)$isdir]
  paths <- if (length(files)) substring(files, nchar(normalizePath(root, winslash = "/", mustWork = TRUE)) + 2L) else character()
  setNames(lapply(files, function(path) readBin(path, "raw", n = file.info(path)$size)), paths)
}

test_that("successful refresh commits one immutable accepted/evidence pointer", {
  phase18_refresh_test_load(); x <- phase18_refresh_test_sandbox(); on.exit(unlink(x$root, recursive = TRUE), add = TRUE)
  result <- phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root,
    now_utc = "2026-09-20T18:00:00Z")
  expect_identical(result$status, "accepted")
  current <- phase18_read_ucl_refresh_current(x$accepted_root, x$registry_root)
  expect_identical(current$accepted$bundle$bundle_id[[1L]], "ucl-refresh-candidate-v2")
  expect_silent(phase18_validate_ucl_refresh_current(current)); expect_silent(phase18_validate_ucl_refresh_state(current$history, current$sidecar))
  expect_true(dir.exists(current$accepted_generation_root)); expect_true(dir.exists(current$transaction_generation_root))
  expect_false(dir.exists(file.path(x$accepted_root, "ucl_2026_27")))
})

test_that("every pre-commit interruption leaves the prior pointer authoritative", {
  phase18_refresh_test_load(); x <- phase18_refresh_test_sandbox(); on.exit(unlink(x$root, recursive = TRUE), add = TRUE)
  phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root, now_utc = "2026-09-20T18:01:00Z")
  pointer_before <- readBin(file.path(x$registry_root, "ucl_source_current.json"), "raw", n = 100000L)
  unlink(x$candidate_root, recursive = TRUE)
  phase18_write_ucl_candidate(x$candidate_root, phase18_refresh_test_candidate("ucl-refresh-next-v2", "next"))
  for (hook in c("before_promotion", "interrupt", "before_readback")) {
    result <- phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root,
      writer_hooks = setNames(list(function(...) stop("injected termination")), hook),
      now_utc = paste0("2026-09-20T18:0", match(hook, c("before_promotion", "interrupt", "before_readback")) + 1L, ":00Z"))
    expect_identical(result$status, "blocked")
    expect_identical(readBin(file.path(x$registry_root, "ucl_source_current.json"), "raw", n = 100000L), pointer_before)
    expect_silent(phase18_read_ucl_refresh_current(x$accepted_root, x$registry_root))
  }
})

test_that("post-pointer notification failure cannot contradict a committed refresh", {
  phase18_refresh_test_load(); x <- phase18_refresh_test_sandbox(); on.exit(unlink(x$root, recursive = TRUE), add = TRUE)
  result <- phase18_refresh_ucl_source(
    x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root,
    writer_hooks = list(after_pointer_commit = function(...) stop("notification unavailable")),
    now_utc = "2026-09-20T18:05:30Z"
  )
  expect_identical(result$status, "accepted")
  expect_true(result$recorded)
  expect_identical(result$notification_warning, "after_pointer_commit_failed")
  current <- phase18_read_ucl_refresh_current(x$accepted_root, x$registry_root)
  expect_identical(current$accepted$bundle$bundle_id[[1L]], "ucl-refresh-candidate-v2")
})

test_that("concurrent readers observe only complete old or new generations", {
  skip_on_os("windows")
  phase18_refresh_test_load(); x <- phase18_refresh_test_sandbox(); on.exit(unlink(x$root, recursive = TRUE), add = TRUE)
  phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root,
    now_utc = "2026-09-20T18:06:00Z")
  unlink(x$candidate_root, recursive = TRUE)
  phase18_write_ucl_candidate(x$candidate_root, phase18_refresh_test_candidate("ucl-refresh-next-v2", "next"))
  reader <- parallel::mcparallel({
    ids <- character()
    for (i in seq_len(40L)) {
      value <- phase18_read_ucl_refresh_current(x$accepted_root, x$registry_root)
      ids <- c(ids, value$accepted$bundle$bundle_id[[1L]])
      Sys.sleep(0.005)
    }
    ids
  }, silent = TRUE)
  phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root,
    now_utc = "2026-09-20T18:07:00Z")
  observed <- parallel::mccollect(reader)[[1L]]
  expect_true(all(observed %in% c("ucl-refresh-candidate-v2", "ucl-refresh-next-v2")))
  expect_identical(phase18_read_ucl_refresh_current(x$accepted_root, x$registry_root)$accepted$bundle$bundle_id[[1L]],
    "ucl-refresh-next-v2")
})

test_that("failed transaction evidence writers preserve the current pointer", {
  phase18_refresh_test_load(); x <- phase18_refresh_test_sandbox(); on.exit(unlink(x$root, recursive = TRUE), add = TRUE)
  phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root,
    now_utc = "2026-09-20T18:08:00Z")
  pointer <- readBin(file.path(x$registry_root, "ucl_source_current.json"), "raw", n = 100000L)
  unlink(x$candidate_root, recursive = TRUE)
  result <- phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root,
    writer_hooks = list(history_writer = function(...) stop("injected history writer failure")),
    now_utc = "2026-09-20T18:09:00Z")
  expect_identical(result$status, "blocked"); expect_false(result$recorded)
  expect_identical(readBin(file.path(x$registry_root, "ucl_source_current.json"), "raw", n = 100000L), pointer)
  expect_silent(phase18_read_ucl_refresh_current(x$accepted_root, x$registry_root))
})

test_that("lock loser performs no shared mutation", {
  phase18_refresh_test_load(); x <- phase18_refresh_test_sandbox(); on.exit(unlink(x$root, recursive = TRUE), add = TRUE)
  phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root, now_utc = "2026-09-20T18:10:00Z")
  dir.create(file.path(x$root, ".phase18-ucl-refresh.lock")); before <- phase18_refresh_test_snapshot(x$root)
  result <- phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root)
  expect_identical(result$reason_code, "concurrent_refresh"); expect_false(result$recorded)
  expect_identical(phase18_refresh_test_snapshot(x$root), before)
})

test_that("tampered pointer and prior ledger block before candidate publication", {
  phase18_refresh_test_load(); x <- phase18_refresh_test_sandbox(); on.exit(unlink(x$root, recursive = TRUE), add = TRUE)
  phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root, now_utc = "2026-09-20T18:11:00Z")
  pointer_path <- file.path(x$registry_root, "ucl_source_current.json"); pointer <- jsonlite::fromJSON(pointer_path)
  pointer$transaction_generation_sha256 <- paste(rep("0", 64L), collapse = ""); jsonlite::write_json(pointer, pointer_path, auto_unbox = TRUE)
  before <- phase18_refresh_test_snapshot(x$root)
  result <- phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root)
  expect_identical(result$reason_code, "schema_invalid"); expect_false(result$recorded)
  expect_identical(phase18_refresh_test_snapshot(x$root), before)
})

test_that("tampered ledger sidecar and incumbent bytes are never extended", {
  phase18_refresh_test_load()
  tamper_case <- function(kind) {
    x <- phase18_refresh_test_sandbox()
    phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root,
      now_utc = "2026-09-20T18:11:30Z")
    current <- phase18_read_ucl_refresh_current(x$accepted_root, x$registry_root)
    if (identical(kind, "ledger")) {
      ledger <- file.path(current$transaction_generation_root, "ucl_source_refreshes.csv")
      value <- phase18_ucl_refresh_read_history(ledger); value$reason_code[[1L]] <- "schema_invalid"
      utils::write.csv(value, ledger, row.names = FALSE, na = "", quote = TRUE)
    } else if (identical(kind, "incumbent")) {
      writeBin(charToRaw("tampered"), file.path(current$accepted_generation_root, "bundle.csv"))
    } else {
      unlink(x$candidate_root, recursive = TRUE)
      phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root,
        now_utc = "2026-09-20T18:11:31Z")
      current <- phase18_read_ucl_refresh_current(x$accepted_root, x$registry_root)
      sidecar <- file.path(current$transaction_generation_root, "ucl_source_blocked_refresh.json")
      value <- jsonlite::fromJSON(sidecar); value$reason_code <- "http_failure"
      jsonlite::write_json(value, sidecar, auto_unbox = TRUE)
    }
    before <- phase18_refresh_test_snapshot(x$root)
    result <- phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root)
    expect_identical(result$status, "blocked", info = kind); expect_false(result$recorded, info = kind)
    expect_identical(phase18_refresh_test_snapshot(x$root), before, info = kind)
    unlink(x$root, recursive = TRUE)
  }
  for (kind in c("ledger", "sidecar", "incumbent")) tamper_case(kind)
})

test_that("technical first-refresh failure records explicit no-incumbent without accepted bytes", {
  phase18_refresh_test_load(); x <- phase18_refresh_test_sandbox(); on.exit(unlink(x$root, recursive = TRUE), add = TRUE)
  unlink(x$candidate_root, recursive = TRUE)
  result <- phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root,
    now_utc = "2026-09-20T18:12:00Z")
  expect_identical(result$status, "blocked"); expect_true(result$recorded)
  current <- phase18_read_ucl_refresh_current(x$accepted_root, x$registry_root)
  expect_identical(current$pointer$accepted_status, "no_incumbent"); expect_null(current$accepted)
  expect_identical(current$history$status[[1L]], "blocked")
})

test_that("fixture authority never becomes current", {
  phase18_refresh_test_load(); x <- phase18_refresh_test_sandbox(); on.exit(unlink(x$root, recursive = TRUE), add = TRUE)
  unlink(x$candidate_root, recursive = TRUE)
  phase18_write_ucl_candidate(x$candidate_root, phase18_refresh_test_candidate("ucl-fixture-v2", authority = "fixture"))
  result <- phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root,
    now_utc = "2026-09-20T18:13:00Z")
  expect_identical(result$reason_code, "fixture_non_promotable")
  expect_identical(phase18_read_ucl_refresh_current(x$accepted_root, x$registry_root)$pointer$accepted_status, "no_incumbent")
})

test_that("provider exit rejects manual and no-incumbent states without pointer mutation", {
  phase18_refresh_test_load(); x <- phase18_refresh_test_sandbox(); on.exit(unlink(x$root, recursive = TRUE), add = TRUE)
  phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root, now_utc = "2026-09-20T18:14:00Z")
  current <- phase18_read_ucl_refresh_current(x$accepted_root, x$registry_root); inventory <- phase18_ucl_refresh_inventory(current$accepted_generation_root)
  review <- data.frame(schema_version = "phase18-ucl-provider-exit-review-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
    exit_review_id = "exit-review-001", provider_id = "football_data_org_v4", edition_id = "ucl_2026_27",
    decision = "reviewed", exit_disposition = "retain", retention_permitted = TRUE, display_permitted = TRUE,
    terms_sha256 = phase18_hash_scalar_v2("terms", "terms", "character"), provider_decision_id = "unrelated",
    provider_decision_sha256 = phase18_hash_scalar_v2("decision", "decision", "character"),
    incumbent_bundle_id = current$accepted$bundle$bundle_id[[1L]], incumbent_bundle_sha256 = current$accepted$bundle$bundle_sha256[[1L]],
    reviewed_inventory_paths = paste(inventory$paths, collapse = "|"), reviewed_inventory_sha256s = paste(inventory$hashes, collapse = "|"),
    reviewer = "compliance", reviewed_at_utc = "2026-09-20T18:15:00Z", reason = "exit", retained_relative_paths = "",
    retained_inventory_sha256s = "", exit_review_sha256 = "", row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE)
  review <- phase18_hash_ucl_provider_exit_review(review); before <- readBin(file.path(x$registry_root, "ucl_source_current.json"), "raw", n = 100000L)
  expect_error(phase18_apply_provider_exit(review, x$accepted_root, x$registry_root), class = "phase18_refresh_provider_exit_required")
  expect_identical(readBin(file.path(x$registry_root, "ucl_source_current.json"), "raw", n = 100000L), before)
})

phase18_refresh_test_exit_review <- function(current, disposition, retained = setNames(character(), character())) {
  inventory <- phase18_ucl_refresh_inventory(current$accepted_generation_root)
  authority <- current$accepted$authority; bundle <- current$accepted$bundle
  row <- data.frame(schema_version = "phase18-ucl-provider-exit-review-v2",
    hash_encoding_version = phase18_canonical_encoding_v2(), exit_review_id = paste0("exit-review-", disposition, "-001"),
    provider_id = "football_data_org_v4", edition_id = bundle$edition_id[[1L]], decision = "reviewed",
    exit_disposition = disposition, retention_permitted = identical(disposition, "retain"),
    display_permitted = identical(disposition, "retain"), terms_sha256 = phase18_hash_scalar_v2("terms", "terms", "character"),
    provider_decision_id = authority$provider_decision_id[[1L]], provider_decision_sha256 = authority$provider_decision_sha256[[1L]],
    incumbent_bundle_id = bundle$bundle_id[[1L]], incumbent_bundle_sha256 = bundle$bundle_sha256[[1L]],
    reviewed_inventory_paths = paste(inventory$paths, collapse = "|"), reviewed_inventory_sha256s = paste(inventory$hashes, collapse = "|"),
    reviewer = "fixture-compliance", reviewed_at_utc = "2026-09-20T18:20:00Z", reason = "provider relationship ended",
    retained_relative_paths = paste(names(retained), collapse = "|"), retained_inventory_sha256s = paste(unname(retained), collapse = "|"),
    exit_review_sha256 = "", row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE)
  phase18_hash_ucl_provider_exit_review(row)
}

test_that("provider exit is bound to exact provider incumbent and inventory", {
  phase18_refresh_test_load(); x <- phase18_refresh_test_sandbox(); on.exit(unlink(x$root, recursive = TRUE), add = TRUE)
  evidence_root <- file.path(x$acceptance_root, "football_data_org_v4", "ucl_2026_27")
  evidence <- phase18_refresh_test_provider_evidence(evidence_root)
  unlink(x$candidate_root, recursive = TRUE)
  phase18_write_ucl_candidate(x$candidate_root, phase18_refresh_test_candidate("ucl-provider-v2", authority = "provider", provider_evidence = evidence))
  expect_identical(phase18_refresh_ucl_source(x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root,
    now_utc = "2026-09-20T18:21:00Z")$status, "accepted")
  current <- phase18_read_ucl_refresh_current(x$accepted_root, x$registry_root)
  review <- phase18_refresh_test_exit_review(current, "retain")
  stale <- review; stale$incumbent_bundle_sha256 <- paste(rep("0", 64L), collapse = "")
  stale <- phase18_hash_ucl_provider_exit_review(stale)
  pointer_before <- readBin(file.path(x$registry_root, "ucl_source_current.json"), "raw", n = 100000L)
  expect_error(phase18_apply_provider_exit(stale, x$accepted_root, x$registry_root), class = "phase18_refresh_provider_exit_required")
  expect_identical(readBin(file.path(x$registry_root, "ucl_source_current.json"), "raw", n = 100000L), pointer_before)
  retained <- phase18_apply_provider_exit(review, x$accepted_root, x$registry_root, now_utc = "2026-09-20T18:22:00Z")
  expect_identical(retained$status, "retained_last_known_good")
  after_retain <- phase18_read_ucl_refresh_current(x$accepted_root, x$registry_root)
  expect_identical(after_retain$pointer$accepted_generation_id, current$pointer$accepted_generation_id)
  withdraw <- phase18_refresh_test_exit_review(after_retain, "withdraw")
  result <- phase18_apply_provider_exit(withdraw, x$accepted_root, x$registry_root, now_utc = "2026-09-20T18:23:00Z")
  expect_identical(result$status, "source_unavailable")
  final <- phase18_read_ucl_refresh_current(x$accepted_root, x$registry_root)
  expect_identical(final$pointer$accepted_status, "unavailable_tombstone")
  expect_silent(phase18_validate_ucl_unavailable_tombstone(result$tombstone_path))
})

test_that("post-swap notification failure cannot contradict committed provider exit", {
  phase18_refresh_test_load(); x <- phase18_refresh_test_sandbox(); on.exit(unlink(x$root, recursive = TRUE), add = TRUE)
  evidence_root <- file.path(x$acceptance_root, "football_data_org_v4", "ucl_2026_27")
  evidence <- phase18_refresh_test_provider_evidence(evidence_root)
  unlink(x$candidate_root, recursive = TRUE)
  phase18_write_ucl_candidate(
    x$candidate_root,
    phase18_refresh_test_candidate("ucl-provider-post-swap-v2", authority = "provider", provider_evidence = evidence)
  )
  phase18_refresh_ucl_source(
    x$candidate_root, x$accepted_root, x$registry_root, x$acceptance_root,
    now_utc = "2026-09-20T18:24:00Z"
  )
  current <- phase18_read_ucl_refresh_current(x$accepted_root, x$registry_root)
  review <- phase18_refresh_test_exit_review(current, "withdraw")
  result <- phase18_apply_provider_exit(
    review, x$accepted_root, x$registry_root,
    writer_hooks = list(after_provider_exit_swap = function(...) stop("notification unavailable")),
    now_utc = "2026-09-20T18:25:00Z"
  )
  expect_identical(result$status, "source_unavailable")
  expect_true(result$recorded)
  expect_identical(result$notification_warning, "after_provider_exit_swap_failed")
  expect_identical(
    phase18_read_ucl_refresh_current(x$accepted_root, x$registry_root)$pointer$accepted_status,
    "unavailable_tombstone"
  )
})

test_that("technical reason vocabulary is closed and sanitized", {
  phase18_refresh_test_load()
  expect_true(all(c("concurrent_refresh", "interrupted", "promotion_failure", "read_back_failure",
    "history_write_failure", "sidecar_write_failure") %in% phase18_ucl_refresh_reason_codes()))
  expect_identical(phase18_classify_ucl_refresh_failure(simpleError("HTTP 429 rate limit"))$reason_code, "rate_limited")
})

test_that("refresh CLI modes use tagged stable exits without durable mutation", {
  phase18_refresh_test_load()
  old_wd <- setwd(phase18_refresh_test_root); on.exit(setwd(old_wd), add = TRUE)
  source(file.path(phase18_refresh_test_root, "scripts/refresh_ucl_source.R"), local = .GlobalEnv, chdir = TRUE)
  expect_identical(phase18_refresh_cli_exit_code(list(status = "accepted")), 0L)
  expect_identical(phase18_refresh_cli_exit_code(list(status = "blocked")), 2L)
  expect_identical(phase18_refresh_cli_exit_code(error = simpleError("--edition must be ucl_2026_27")), 64L)
  before <- phase18_refresh_test_snapshot(file.path(phase18_refresh_test_root, "data/competition"))
  output <- suppressWarnings(system2("Rscript", c("--vanilla", file.path(phase18_refresh_test_root, "scripts/refresh_ucl_source.R"),
    "--edition", "../escape"), stdout = TRUE, stderr = TRUE))
  expect_identical(attr(output, "status"), 64L)
  expect_false(any(grepl("token|credential=|x-auth", output, ignore.case = TRUE)))
  expect_identical(phase18_refresh_test_snapshot(file.path(phase18_refresh_test_root, "data/competition")), before)
})
