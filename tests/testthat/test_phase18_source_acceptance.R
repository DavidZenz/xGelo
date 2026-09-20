library(testthat)

phase18_test_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase18_test_load <- function() {
  common_path <- file.path(phase18_test_root, "R/common/phase18_canonical_hash.R")
  source_path <- file.path(phase18_test_root, "R/competition/ucl_source_acceptance.R")
  script_path <- file.path(phase18_test_root, "scripts/accept_ucl_provider.R")
  source(common_path, local = .GlobalEnv)
  if (file.exists(source_path)) source(source_path, local = .GlobalEnv)
  if (file.exists(script_path)) sys.source(script_path, envir = .GlobalEnv)
  invisible(TRUE)
}

phase18_test_require <- function(functions) {
  missing <- functions[!vapply(functions, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop("Missing Phase 18 API: ", paste(missing, collapse = ", "), call. = FALSE)
  }
}

phase18_test_review <- function(review_set = "approved") {
  review <- phase18_read_terms_review_fixture(
    file.path(phase18_test_root, "tests/fixtures/phase18/provider_terms_review.csv"),
    review_set
  )
  review$reviewer <- "fixture-owner"
  phase18_hash_terms_review(review)
}

phase18_test_expectations <- function() {
  expectations <- data.frame(
    schema_version = "phase18-edition-expectation-v1",
    edition_id = "ucl_2026_27",
    lifecycle = "league_phase",
    expected_club_count = 36L,
    expected_league_phase_match_count = 144L,
    allowed_stages = "LEAGUE_STAGE|PLAYOFFS|LAST_16|QUARTER_FINALS|SEMI_FINALS|FINAL",
    standings_required = TRUE,
    expected_standings_rows = 36L,
    review_state = "approved",
    reviewer = "fixture-owner",
    reviewed_at_utc = "2026-09-19T12:00:00Z",
    row_sha256 = "",
    expectation_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  phase18_hash_edition_expectations(expectations)
}

phase18_test_fingerprint <- function(observed = TRUE, now_utc = "2026-09-19T12:30:00Z") {
  fingerprint <- phase18_default_schema_fingerprint(now_utc)
  if (isTRUE(observed)) {
    fingerprint$observed <- TRUE
    fingerprint$fingerprint_sha256 <- vapply(
      fingerprint$resource,
      function(resource) phase18_sha256_text(paste0("fixture-schema|", resource)),
      character(1)
    )
    fingerprint <- phase18_hash_schema_fingerprint(fingerprint)
  }
  fingerprint
}

phase18_test_machine_checks <- function(execution_mode = "offline_contract_test", passed = TRUE) {
  checks <- phase18_default_machine_checks(phase18_test_expectations(), "2026-09-19T12:30:00Z", "offline_only")
  decisions <- phase18_capability_decisions()
  kinds <- phase18_capability_evidence_kinds()
  integrate <- checks$decision == "INTEGRATE"
  resources <- checks$capability %in% names(phase18_probe_endpoints())
  checks$execution_mode <- execution_mode
  checks$executed[integrate] <- TRUE
  checks$passed <- passed
  checks$evidence_kind <- unname(kinds[checks$capability])
  checks$evidence_observation[integrate] <- paste0("observed:", checks$capability[integrate])
  checks$evidence_observation[!integrate] <- "not_executed_not_applicable"
  checks$applicable_check_count[integrate] <- 1L
  checks$live_run_id <- if (identical(execution_mode, "live_acceptance_probe")) "live-fixture-001" else "offline-fixture-001"
  checks$real_key_evidence[integrate] <- identical(execution_mode, "live_acceptance_probe")
  checks$freshness_passed[resources] <- passed
  checks$identity_passed[resources] <- passed
  checks$pagination_complete[resources] <- passed
  checks$secret_scan_passed[resources] <- passed
  checks$observed_count[match(names(phase18_probe_endpoints()), checks$capability)] <- c(1L, 36L, 144L, 36L)
  checks$observed_stages[checks$capability == "matches"] <- "LEAGUE_STAGE"
  checks$evidence_sha256[integrate] <- mapply(
    phase18_machine_evidence_hash,
    checks$capability[integrate], checks$evidence_kind[integrate],
    checks$evidence_observation[integrate], checks$applicable_check_count[integrate],
    checks$live_run_id[integrate], USE.NAMES = FALSE
  )
  phase18_hash_machine_checks(checks)
}

test_that("Phase 18 source-acceptance API seam exists", {
  phase18_test_load()
  phase18_test_require(c(
    "phase18_provider_preflight",
    "phase18_validate_terms_review",
    "phase18_validate_edition_expectations",
    "phase18_build_acceptance_manifest",
    "phase18_validate_acceptance_manifest",
    "phase18_accept_ucl_provider_main"
  ))
  expect_true(TRUE)
})

test_that("missing credential preflight is a durable fail-closed decision", {
  phase18_test_load()
  preflight <- phase18_provider_preflight(FALSE, "2026-09-19T12:00:00Z")
  expect_identical(preflight$decision, "not_run")
  expect_identical(preflight$reason_code, "missing_credential")
  expect_identical(preflight$credential_status, "absent")
  expect_false(preflight$automation_enabled)
  expect_match(preflight$row_sha256, "^[0-9a-f]{64}$")
})

test_that("no-key operator path never calls transport and emits a validating manifest", {
  phase18_test_load()
  evidence_root <- tempfile("phase18-no-key-")
  review_path <- tempfile("phase18-no-key-review-", fileext = ".csv")
  utils::write.csv(phase18_test_review("pending"), review_path, row.names = FALSE, na = "", quote = TRUE)
  transport_calls <- 0L
  result <- phase18_accept_ucl_provider_main(
    args = c(
      "--provider-id", "football_data_org_v4",
      "--edition-id", "ucl_2026_27",
      "--review-path", review_path,
      "--evidence-root", evidence_root
    ),
    token_present = FALSE,
    transport_fn = function(...) {
      transport_calls <<- transport_calls + 1L
      stop("transport must not be called")
    },
    now_utc = "2026-09-19T12:30:00Z"
  )
  expect_identical(transport_calls, 0L)
  expect_identical(result$manifest$decision, "not_run")
  expect_identical(result$manifest$reason_code, "missing_credential")
  expect_false(result$manifest$automation_enabled)
  manifest_path <- result$paths[["acceptance_manifest.csv"]]
  expect_true(file.exists(manifest_path))
  persisted <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
  expect_silent(phase18_validate_acceptance_manifest(
    persisted,
    result$machine_checks,
    result$owner_review,
    result$edition_expectations,
    result$schema_fingerprint
  ))
  expect_false(any(grepl("token|authorization|header|request", names(persisted), ignore.case = TRUE)))
})

test_that("offline evidence cannot bootstrap automation", {
  phase18_test_load()
  review <- phase18_test_review("approved")
  expectations <- phase18_test_expectations()
  machine <- phase18_test_machine_checks("offline_contract_test", TRUE)
  manifest <- phase18_build_acceptance_manifest(
    machine_checks = machine,
    owner_review = review,
    edition_expectations = expectations,
    schema_fingerprint = phase18_test_fingerprint(FALSE),
    decision_id = "offline-proof-001",
    now_utc = "2026-09-19T12:30:00Z"
  )
  expect_false(manifest$automation_enabled)
  expect_identical(manifest$decision, "not_run")
  expect_identical(manifest$live_provider_decision, "not_run")
  expect_true(manifest$offline_contract_tests_passed)
  expect_silent(phase18_validate_acceptance_manifest(manifest, machine, review, expectations, phase18_test_fingerprint(FALSE)))
})

test_that("owner review validation is typed for approved pending rejected and malformed input", {
  phase18_test_load()
  approved <- phase18_validate_terms_review(phase18_test_review("approved"))
  pending <- phase18_validate_terms_review(phase18_test_review("pending"))
  rejected <- phase18_validate_terms_review(phase18_test_review("rejected"))
  malformed <- phase18_validate_terms_review(NULL)
  expect_true(approved$valid)
  expect_identical(approved$decision, "accepted")
  expect_false(pending$valid)
  expect_identical(pending$decision, "manual_only")
  expect_false(rejected$valid)
  expect_identical(rejected$decision, "rejected")
  expect_false(malformed$valid)
  expect_true(malformed$decision %in% c("manual_only", "rejected"))
})

test_that("owner terms authority rejects blank reviewers and foreign application scope", {
  phase18_test_load()
  blank <- phase18_test_review("approved")
  blank$reviewer <- "   "
  blank <- phase18_hash_terms_review(blank)
  expect_false(phase18_validate_terms_review(blank)$valid)

  foreign_provider <- phase18_test_review("approved")
  foreign_provider$provider_id <- "other_provider"
  foreign_provider <- phase18_hash_terms_review(foreign_provider)
  expect_false(phase18_validate_terms_review(foreign_provider)$valid)

  foreign_app <- phase18_test_review("approved")
  foreign_app$application_id <- "other_app"
  foreign_app <- phase18_hash_terms_review(foreign_app)
  expect_false(phase18_validate_terms_review(foreign_app)$valid)
})

test_that("production evidence enumerates every reviewed dimension and coverage capability", {
  phase18_test_load()
  root <- file.path(
    phase18_test_root,
    "data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27"
  )
  accepted <- phase18_read_acceptance_set(root)
  paths <- accepted$paths
  expect_true(all(file.exists(paths)))
  review <- utils::read.csv(paths[[1L]], stringsAsFactors = FALSE, check.names = FALSE)
  coverage <- utils::read.csv(paths[[3L]], stringsAsFactors = FALSE, check.names = FALSE)
  expected_capabilities <- c(
    "competition_metadata", "teams", "matches", "standings", "scorers",
    "head_to_head", "match_detail", "team_detail", "person_detail", "filters",
    "pagination", "authenticated_headers", "rate_limits", "null_empty_semantics",
    "attribution", "provider_exit"
  )
  expect_setequal(review$dimension, phase18_owner_review_dimensions())
  expect_equal(nrow(review), length(phase18_owner_review_dimensions()))
  expect_true(all(review$status == "pending"))
  expect_setequal(coverage$capability, expected_capabilities)
  expect_equal(nrow(coverage), length(expected_capabilities))
  expect_true(all(coverage$execution_mode == "not_run"))
})

test_that("reviewed league-phase expectations reject every shortfall excess and unknown stage", {
  phase18_test_load()
  expectations <- phase18_test_expectations()
  baseline <- list(
    club_count = 36L,
    league_phase_match_count = 144L,
    stages = "LEAGUE_STAGE",
    standings_rows = 36L
  )
  expect_true(phase18_validate_edition_expectations(expectations, baseline, "league_phase")$valid)
  for (clubs in c(35L, 37L)) {
    observed <- baseline
    observed$club_count <- clubs
    expect_identical(phase18_validate_edition_expectations(expectations, observed, "league_phase")$reason_code, "cardinality")
  }
  for (matches in c(143L, 145L)) {
    observed <- baseline
    observed$league_phase_match_count <- matches
    expect_identical(phase18_validate_edition_expectations(expectations, observed, "league_phase")$reason_code, "cardinality")
  }
  bad_stage <- baseline
  bad_stage$stages <- "INVENTED_STAGE"
  expect_identical(phase18_validate_edition_expectations(expectations, bad_stage, "league_phase")$reason_code, "stage")
  bad_standings <- baseline
  bad_standings$standings_rows <- 35L
  expect_identical(phase18_validate_edition_expectations(expectations, bad_standings, "league_phase")$reason_code, "standings")
})

test_that("only exact live owner and machine conjunction can enable automation", {
  phase18_test_load()
  review <- phase18_test_review("approved")
  expectations <- phase18_test_expectations()
  machine <- phase18_test_machine_checks("live_acceptance_probe", TRUE)
  fingerprint <- phase18_test_fingerprint(TRUE)
  accepted <- phase18_build_acceptance_manifest(
    machine, review, expectations,
    fingerprint,
    "live-proof-001", "2026-09-19T12:30:00Z"
  )
  expect_true(accepted$automation_enabled)
  expect_identical(accepted$decision, "accepted")
  expect_silent(phase18_validate_acceptance_manifest(accepted, machine, review, expectations, fingerprint))

  stale_review <- review
  stale_review$terms_sha256 <- paste(rep("f", 64L), collapse = "")
  stale_review <- phase18_hash_terms_review(stale_review)
  expect_error(
    phase18_validate_acceptance_manifest(accepted, machine, stale_review, expectations, fingerprint),
    "recomputed evidence|review"
  )
  missing_owner_row <- review[-1L, , drop = FALSE]
  expect_error(
    phase18_build_acceptance_manifest(
      machine, missing_owner_row, expectations, fingerprint,
      "live-proof-002", "2026-09-19T12:30:00Z"
    ),
    "dimensions are not exact"
  )
})

test_that("committed no-key decision validates in a fresh process", {
  root <- file.path(
    phase18_test_root,
    "data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27"
  )
  command <- paste0(
    "setwd('", phase18_test_root, "');source('R/common/phase18_canonical_hash.R');",
    "source('R/competition/ucl_source_acceptance.R');",
    "x<-phase18_read_acceptance_set('", root, "');",
    "stopifnot(!x$manifest$automation_enabled[[1]], x$manifest$reason_code[[1]]=='missing_credential')"
  )
  output <- system2("Rscript", c("--vanilla", "-e", shQuote(command)), stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  expect_equal(status, 0L, info = paste(output, collapse = "\n"))
})

phase18_test_seed_probe_root <- function() {
  evidence_root <- tempfile("phase18-probe-root-")
  review_path <- tempfile("phase18-approved-review-", fileext = ".csv")
  utils::write.csv(phase18_test_review("approved"), review_path, row.names = FALSE, na = "", quote = TRUE)
  phase18_accept_ucl_provider_main(
    args = c(
      "--provider-id", "football_data_org_v4",
      "--edition-id", "ucl_2026_27",
      "--review-path", review_path,
      "--evidence-root", evidence_root
    ),
    token_present = FALSE,
    transport_fn = function(...) stop("no-key seed must not call transport"),
    now_utc = "2026-09-19T12:30:00Z"
  )
  file.path(evidence_root, "football_data_org_v4", "ucl_2026_27")
}

phase18_test_tree_sha <- function(root) {
  paths <- list.files(root, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE)
  paths <- paths[file.exists(paths) & !dir.exists(paths)]
  relative <- substring(paths, nchar(normalizePath(root, winslash = "/")) + 2L)
  values <- vapply(paths, function(path) {
    digest::digest(readBin(path, what = "raw", n = file.info(path)$size), algo = "sha256", serialize = FALSE)
  }, character(1))
  setNames(values, relative)
}

phase18_test_write_subprocess <- function(lines, prefix) {
  path <- tempfile(prefix, fileext = ".R")
  writeLines(lines, path, useBytes = TRUE)
  path
}

phase18_test_wait_for_path <- function(path, process = NULL, timeout = 10) {
  deadline <- Sys.time() + timeout
  while (!file.exists(path) && Sys.time() < deadline) {
    if (!is.null(process) && !process$is_alive()) break
    Sys.sleep(0.02)
  }
  if (!file.exists(path)) {
    details <- if (is.null(process)) "" else paste(process$read_all_error(), collapse = "\n")
    stop("Timed out waiting for subprocess marker: ", path, "\n", details, call. = FALSE)
  }
  invisible(path)
}

phase18_test_probe_transport <- function(overrides = list(), fingerprint_seed = "fixture-v1") {
  counts <- c(competition_metadata = 1L, teams = 36L, matches = 144L, standings = 36L)
  for (name in names(overrides)) counts[[name]] <- overrides[[name]]
  calls <- character()
  transport <- function(endpoint, attempt, cache = FALSE) {
    calls <<- c(calls, endpoint)
    list(
      count = unname(counts[[endpoint]]),
      stages = if (identical(endpoint, "matches")) (overrides$stages %||% "LEAGUE_STAGE") else "",
      freshness_passed = TRUE,
      identity_passed = TRUE,
      pagination_complete = TRUE,
      secret_scan_passed = TRUE,
      fingerprint_sha256 = phase18_sha256_text(paste(fingerprint_seed, endpoint, sep = "|")),
      capability_evidence = if (identical(endpoint, "competition_metadata")) list(
        filters = "season=2026 and competition=CL request plan observed",
        pagination = "all four resource pagination windows completed",
        authenticated_headers = "process-local authentication header was applied",
        rate_limits = "provider rate-limit metadata and bounded retry path observed",
        null_empty_semantics = "null and empty resource semantics checked",
        attribution = "reviewed attribution contract bound to response",
        provider_exit = "reviewed provider-exit contract bound to response"
      ) else NULL
    )
  }
  attr(transport, "calls") <- function() calls
  transport
}

phase18_test_adapter_registries <- function() {
  ids <- sprintf("club_%03d", seq_len(36L))
  provider_ids <- as.character(1000L + seq_len(36L))
  display <- sprintf("Fixture Club %02d", seq_len(36L))
  phase18_hash_club_registry_rows(list(
    clubs = data.frame(
      schema_version = phase18_club_identity_schema_version(),
      hash_encoding_version = phase18_canonical_encoding_v2(), club_id = ids,
      entity_kind = "club", canonical_name = display, association_code = "FX",
      valid_from_utc = "2020-01-01T00:00:00Z", valid_to_utc = "",
      club_status = "active", row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
    ),
    source_ids = data.frame(
      schema_version = phase18_club_identity_schema_version(),
      hash_encoding_version = phase18_canonical_encoding_v2(), club_id = ids,
      source_system = "football_data_org_v4", source_club_id = provider_ids,
      valid_from_utc = "2020-01-01T00:00:00Z", valid_to_utc = "",
      review_state = "approved", source_bundle_id = "fixture-review-v1",
      row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
    ),
    aliases = data.frame(
      schema_version = phase18_club_identity_schema_version(),
      hash_encoding_version = phase18_canonical_encoding_v2(), club_id = ids,
      source_system = "football_data_org_v4", alias = display,
      normalized_alias = phase18_normalize_club_name(display),
      valid_from_utc = "2020-01-01T00:00:00Z", valid_to_utc = "",
      review_state = "approved", reviewed_by = "fixture-reviewer",
      reviewed_at_utc = "2026-09-19T10:00:00Z", row_sha256 = "",
      stringsAsFactors = FALSE, check.names = FALSE
    )
  ))
}

phase18_test_projected_adapter <- function() {
  ids <- sprintf("club_%03d", seq_len(36L))
  provider_ids <- as.character(1000L + seq_len(36L))
  display <- sprintf("Fixture Club %02d", seq_len(36L))
  list(
    competition = data.frame(edition_id = "ucl_2026_27"),
    clubs = data.frame(
      provider_club_id = provider_ids, club_id = ids, display_name = display,
      last_updated_utc = "2026-09-19T11:00:00Z", stringsAsFactors = FALSE
    ),
    matches = data.frame(stage = rep("LEAGUE_STAGE", 144L)),
    standings = data.frame(club_id = ids),
    coverage = list(
      stages = "LEAGUE_STAGE", freshness_passed = TRUE,
      identity_passed = TRUE, pagination_complete = TRUE
    ),
    schema_fingerprint = data.frame(
      resource = c("competition_metadata", "teams", "matches", "standings"),
      fingerprint_sha256 = vapply(
        c("competition_metadata", "teams", "matches", "standings"),
        function(value) phase18_sha256_text(paste0("fixture|", value)), character(1)
      ),
      raw_sha256 = vapply(
        c("competition_metadata", "teams", "matches", "standings"),
        function(value) phase18_sha256_text(paste0("raw|", value)), character(1)
      ), stringsAsFactors = FALSE, check.names = FALSE
    )
  )
}

test_that("operator CLI routes offline and live modes only through the fixed adapter seams", {
  phase18_test_load()
  registry_root <- tempfile("phase18-cli-club-registry-")
  phase18_write_club_registries_atomic(phase18_test_adapter_registries(), registry_root)
  review_path <- tempfile("phase18-cli-review-", fileext = ".csv")
  utils::write.csv(phase18_test_review("approved"), review_path, row.names = FALSE, na = "", quote = TRUE)
  evidence_root <- tempfile("phase18-cli-evidence-")
  target_root <- file.path(evidence_root, "football_data_org_v4", "ucl_2026_27")
  dir.create(target_root, recursive = TRUE)
  utils::write.csv(
    phase18_test_expectations(), file.path(target_root, "edition_expectations.csv"),
    row.names = FALSE, na = "", quote = TRUE
  )
  observed_plan <- NULL
  fetch_stub <- function(request_plan, perform_request, clock_fn, sleep_fn) {
    observed_plan <<- request_plan
    setNames(lapply(request_plan$resource, function(resource) list(resource = resource)), request_plan$resource)
  }
  project_stub <- function(fetched, edition_id, club_registries, edition_expectations, now_utc) {
    phase18_test_projected_adapter()
  }
  args <- c(
    "--provider-id", "football_data_org_v4", "--edition-id", "ucl_2026_27",
    "--review-path", review_path, "--evidence-root", evidence_root,
    "--club-registry-root", registry_root
  )
  offline <- phase18_accept_ucl_provider_main(
    c(args, "--mode", "offline_contract_test"), token_present = FALSE,
    perform_request = function(...) stop("fetch stub owns the offline seam"),
    fetch_window_fn = fetch_stub, project_resources_fn = project_stub,
    now_utc = "2026-09-19T12:30:00Z"
  )
  expect_identical(observed_plan, phase18_fd_request_plan())
  expect_identical(offline$manifest$execution_mode, "offline_contract_test")
  expect_false(offline$manifest$automation_enabled)
  expect_identical(offline$manifest$reason_code, "offline_only")

  phase18_accept_ucl_provider_main(
    args, token_present = FALSE, now_utc = "2026-09-19T12:30:00Z"
  )
  old <- Sys.getenv("FOOTBALL_DATA_API_TOKEN", unset = NA_character_)
  on.exit(if (is.na(old)) Sys.unsetenv("FOOTBALL_DATA_API_TOKEN") else Sys.setenv(FOOTBALL_DATA_API_TOKEN = old), add = TRUE)
  Sys.setenv(FOOTBALL_DATA_API_TOKEN = "phase18-cli-sentinel-secret")
  live <- phase18_accept_ucl_provider_main(
    c(args, "--mode", "live_acceptance_probe"), token_present = TRUE,
    perform_request = function(...) stop("fetch stub owns the live seam"),
    fetch_window_fn = fetch_stub, project_resources_fn = project_stub,
    now_utc = "2026-09-19T13:00:00Z"
  )
  expect_identical(live$reason_code, "accepted")
  expect_true(live$manifest$automation_enabled)
  expect_true(phase18_validate_provider_live_authority(file.path(evidence_root, "football_data_org_v4", "ucl_2026_27"))$authorized)
  expect_error(phase18_accept_parse_args(c(args, "--token", "forbidden")), "Unsupported")
  expect_error(phase18_accept_parse_args(c(args, "--host", "https://evil.example")), "Unsupported")
})

test_that("missing-key pending-review and non-live decisions preserve incumbent bytes", {
  phase18_test_load()
  evidence_root <- tempfile("phase18-cli-preserve-")
  approved_path <- tempfile("phase18-approved-review-", fileext = ".csv")
  pending_path <- tempfile("phase18-pending-review-", fileext = ".csv")
  utils::write.csv(phase18_test_review("approved"), approved_path, row.names = FALSE, na = "", quote = TRUE)
  utils::write.csv(phase18_test_review("pending"), pending_path, row.names = FALSE, na = "", quote = TRUE)
  args <- c(
    "--provider-id", "football_data_org_v4", "--edition-id", "ucl_2026_27",
    "--review-path", approved_path, "--evidence-root", evidence_root
  )
  seeded <- phase18_accept_ucl_provider_main(args, token_present = FALSE, now_utc = "2026-09-19T12:00:00Z")
  root <- seeded$evidence_root
  before <- phase18_test_tree_sha(root)

  phase18_accept_ucl_provider_main(args, token_present = FALSE, now_utc = "2026-09-19T12:05:00Z")
  expect_identical(phase18_test_tree_sha(root), before)
  phase18_accept_ucl_provider_main(
    replace(args, match(approved_path, args), pending_path),
    token_present = TRUE, now_utc = "2026-09-19T12:10:00Z"
  )
  expect_identical(phase18_test_tree_sha(root), before)

  registry_root <- tempfile("phase18-unused-registry-")
  live_args <- c(args, "--mode", "live_acceptance_probe", "--club-registry-root", registry_root)
  expect_error(
    phase18_accept_ucl_provider_main(live_args, token_present = FALSE, now_utc = "2026-09-19T12:15:00Z"),
    "requires FOOTBALL_DATA_API_TOKEN"
  )
  expect_identical(phase18_test_tree_sha(root), before)
})

`%||%` <- function(value, fallback) if (is.null(value)) fallback else value

test_that("live acceptance probe is the only first-acceptance path and uses four fixed calls", {
  phase18_test_load()
  root <- phase18_test_seed_probe_root()
  expect_false(phase18_validate_provider_live_authority(root)$authorized)
  transport <- phase18_test_probe_transport()
  result <- phase18_run_live_acceptance_probe(
    evidence_root = root,
    owner_review = phase18_test_review("approved"),
    edition_expectations = phase18_test_expectations(),
    transport_fn = transport,
    decision_id = "live-probe-001",
    now_utc = "2026-09-19T13:00:00Z"
  )
  expect_identical(result$reason_code, "accepted")
  expect_true(result$manifest$automation_enabled)
  expect_setequal(attr(transport, "calls")(), c("competition_metadata", "teams", "matches", "standings"))
  expect_equal(length(attr(transport, "calls")()), 4L)
  expect_true(phase18_validate_provider_live_authority(root)$authorized)
})

test_that("concurrency and writer interruption preserve incumbent bytes", {
  phase18_test_load()
  root <- phase18_test_seed_probe_root()
  before <- phase18_read_acceptance_set(root)
  pointer_before <- readBin(file.path(root, "current.json"), "raw", file.info(file.path(root, "current.json"))$size)
  lock <- file.path(root, ".phase18-acceptance.lock")
  dir.create(lock)
  concurrent <- phase18_run_live_acceptance_probe(
    root, phase18_test_review("approved"), phase18_test_expectations(),
    phase18_test_probe_transport(), "live-probe-concurrent", "2026-09-19T13:00:00Z"
  )
  expect_identical(concurrent$reason_code, "blocked_concurrent_acceptance")
  unlink(lock, recursive = TRUE, force = TRUE)
  expect_identical(phase18_read_acceptance_set(root)$current_generation, before$current_generation)

  failed <- phase18_run_live_acceptance_probe(
    root, phase18_test_review("approved"), phase18_test_expectations(),
    phase18_test_probe_transport(), "live-probe-writer-failure", "2026-09-19T13:00:00Z",
    failure_injector = function(stage, ...) {
      if (identical(stage, "before_pointer_swap")) stop("injected interruption", call. = FALSE)
    }
  )
  expect_identical(failed$reason_code, "interrupted")
  expect_identical(readBin(file.path(root, "current.json"), "raw", file.info(file.path(root, "current.json"))$size), pointer_before)
  residue <- list.files(root, pattern = "phase18-acceptance-stage", all.files = TRUE)
  expect_length(residue, 0L)
  expect_false(dir.exists(lock))
})

test_that("live probe rejects cardinality stage and standings drift without mutation", {
  phase18_test_load()
  cases <- list(
    list(overrides = list(teams = 35L), reason = "cardinality"),
    list(overrides = list(teams = 37L), reason = "cardinality"),
    list(overrides = list(matches = 143L), reason = "cardinality"),
    list(overrides = list(matches = 145L), reason = "cardinality"),
    list(overrides = list(stages = "INVENTED_STAGE"), reason = "stage"),
    list(overrides = list(standings = 35L), reason = "standings")
  )
  for (index in seq_along(cases)) {
    root <- phase18_test_seed_probe_root()
    before <- phase18_test_tree_sha(root)
    result <- phase18_run_live_acceptance_probe(
      root, phase18_test_review("approved"), phase18_test_expectations(),
      phase18_test_probe_transport(cases[[index]]$overrides),
      paste0("live-probe-invalid-", index), "2026-09-19T13:00:00Z"
    )
    expect_identical(result$reason_code, cases[[index]]$reason)
    expect_identical(phase18_test_tree_sha(root), before)
  }
})

test_that("exact replay is idempotent while decision collisions are blocked", {
  phase18_test_load()
  root <- phase18_test_seed_probe_root()
  first <- phase18_run_live_acceptance_probe(
    root, phase18_test_review("approved"), phase18_test_expectations(),
    phase18_test_probe_transport(), "live-probe-replay", "2026-09-19T13:00:00Z"
  )
  expect_identical(first$reason_code, "accepted")
  accepted_bytes <- phase18_test_tree_sha(root)
  replay <- phase18_run_live_acceptance_probe(
    root, phase18_test_review("approved"), phase18_test_expectations(),
    phase18_test_probe_transport(), "live-probe-replay", "2026-09-19T13:00:00Z"
  )
  expect_true(replay$idempotent)
  expect_identical(phase18_test_tree_sha(root), accepted_bytes)
  collision <- phase18_run_live_acceptance_probe(
    root, phase18_test_review("approved"), phase18_test_expectations(),
    phase18_test_probe_transport(fingerprint_seed = "fixture-v2"),
    "live-probe-replay", "2026-09-19T13:00:00Z"
  )
  expect_identical(collision$reason_code, "blocked_decision_collision")
  expect_identical(phase18_test_tree_sha(root), accepted_bytes)
  expect_false(any(grepl("phase18-acceptance-(stage|backup|lock)", list.files(dirname(root), all.files = TRUE))))
})

phase18_loader_script_consumers <- c(
  "R/competition/ucl_source_acceptance.R",
  "R/competition/source_contracts.R",
  "R/competition/edition_registry.R",
  "R/club/identity.R",
  "R/club/identity_bootstrap.R",
  "R/competition/football_data_org_adapter.R",
  "R/competition/ucl_source_bundle.R",
  "R/competition/ucl_source_refresh.R",
  "R/club/history_contract.R"
)

phase18_expect_canonical_first_script <- function(relative_path) {
  lines <- readLines(file.path(phase18_test_root, relative_path), warn = FALSE)
  common <- grep("R/common/phase18_canonical_hash[.]R", lines)
  consumers <- which(vapply(lines, function(line) {
    any(vapply(phase18_loader_script_consumers, grepl, logical(1), x = line, fixed = TRUE))
  }, logical(1)))
  expect_equal(length(common), 1L, info = relative_path)
  expect_true(length(consumers) > 0L, info = relative_path)
  if (length(common) == 1L && length(consumers)) {
    expect_true(common[[1L]] < min(consumers), info = relative_path)
    expect_match(lines[[common[[1L]]]], "^source\\(", info = relative_path)
  }
}

phase18_loader_snapshot <- function(roots) {
  records <- unlist(lapply(roots, function(root) {
    normalized_root <- gsub("\\\\", "/", as.character(root))
    normalized_project <- paste0(gsub("\\\\", "/", phase18_test_root), "/")
    label <- if (startsWith(normalized_root, normalized_project)) {
      substring(normalized_root, nchar(normalized_project) + 1L)
    } else {
      normalized_root
    }
    if (file.exists(root) && !dir.exists(root)) {
      return(setNames(
        digest::digest(file = root, algo = "sha256", serialize = FALSE),
        paste0(label, ":file")
      ))
    }
    if (!dir.exists(root)) return(setNames("absent", paste0(label, ":absent")))
    paths <- list.files(root, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE)
    paths <- paths[file.exists(paths) & !dir.exists(paths)]
    relative <- substring(paths, nchar(normalizePath(root, winslash = "/")) + 2L)
    hashes <- setNames(vapply(paths, function(path) {
      digest::digest(file = path, algo = "sha256", serialize = FALSE)
    }, character(1)), paste(label, relative, sep = "/"))
    c(setNames("directory", paste0(label, ":directory")), hashes)
  }), recursive = FALSE)
  unlist(records, use.names = TRUE)
}

phase18_loader_run_cli <- function(script, args = character(), env = character()) {
  output <- suppressWarnings(system2(
    "Rscript", c("--vanilla", shQuote(file.path(phase18_test_root, script)), args),
    stdout = TRUE, stderr = TRUE, env = env
  ))
  list(output = output, status = attr(output, "status") %||% 0L)
}

test_that("all Phase 18 production CLIs bootstrap the canonical hash module first", {
  scripts <- c(
    "scripts/accept_ucl_provider.R",
    "scripts/bootstrap_club_identity.R",
    "scripts/refresh_ucl_source.R",
    "scripts/build_club_history_corpus.R"
  )
  invisible(lapply(scripts, phase18_expect_canonical_first_script))
})

test_that("credential-free CLI smoke paths preserve durable Phase 18 evidence", {
  phase18_test_load()
  durable_roots <- file.path(phase18_test_root, c(
    "data/competition/provider_acceptance",
    "data/competition/accepted",
    "data/competition/registries",
    "data/club/registries",
    "data/club/identity_reviews",
    "data/club/history_audits",
    "data/club/accepted",
    "data/club/history_current.json",
    "data/club/history_generations"
  ))
  before <- phase18_loader_snapshot(durable_roots)
  scratch <- tempfile("phase18-loader-smoke-")
  dir.create(scratch, recursive = TRUE)
  on.exit(unlink(scratch, recursive = TRUE, force = TRUE), add = TRUE)
  club_scratch <- file.path(
    phase18_test_root, "data/club",
    paste0(".phase18-loader-smoke-", Sys.getpid(), "-", as.integer(Sys.time()))
  )
  dir.create(club_scratch, recursive = TRUE)
  on.exit(unlink(club_scratch, recursive = TRUE, force = TRUE), add = TRUE)
  production_acceptance <- phase18_read_acceptance_set(file.path(
    phase18_test_root,
    "data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27"
  ))

  acceptance <- phase18_loader_run_cli(
    "scripts/accept_ucl_provider.R",
    c(
      "--provider-id", "football_data_org_v4",
      "--edition-id", "ucl_2026_27",
      "--review-path", shQuote(file.path(
        production_acceptance$generation_root,
        "provider_terms_review.csv"
      )),
      "--evidence-root", shQuote(file.path(scratch, "provider_acceptance"))
    ),
    env = "FOOTBALL_DATA_API_TOKEN="
  )
  identity <- phase18_loader_run_cli(
    "scripts/bootstrap_club_identity.R",
    c("--mode=verify", paste0("--project-root=", shQuote(phase18_test_root)))
  )
  refresh <- phase18_loader_run_cli("scripts/refresh_ucl_source.R")
  history <- phase18_loader_run_cli(
    "scripts/build_club_history_corpus.R",
    c(
      paste0("--project-root=", shQuote(phase18_test_root)),
      paste0("--generations-root=", shQuote(file.path(club_scratch, "generations"))),
      paste0("--current-path=", shQuote(file.path(club_scratch, "current.json")))
    )
  )

  expect_equal(acceptance$status, 2L, info = paste(acceptance$output, collapse = "\n"))
  expect_true(identity$status %in% c(0L, 2L), info = paste(identity$output, collapse = "\n"))
  expect_equal(refresh$status, 1L, info = paste(refresh$output, collapse = "\n"))
  expect_true(history$status %in% c(0L, 2L), info = paste(history$output, collapse = "\n"))
  combined <- paste(c(acceptance$output, identity$output, refresh$output, history$output), collapse = "\n")
  expect_false(grepl("could not find function.*phase18_|object.*phase18_.*not found", combined, ignore.case = TRUE))
  expect_identical(phase18_loader_snapshot(durable_roots), before)
})

phase18_loader_extract_block <- function(relative_path, start_pattern) {
  lines <- readLines(file.path(phase18_test_root, relative_path), warn = FALSE)
  start <- which(startsWith(trimws(lines), start_pattern))
  expect_equal(length(start), 1L, info = paste(relative_path, start_pattern))
  if (length(start) != 1L) return(character())
  balance <- 0L
  opened <- FALSE
  for (index in seq.int(start[[1L]], length(lines))) {
    opens <- lengths(regmatches(lines[[index]], gregexpr("{", lines[[index]], fixed = TRUE)))
    closes <- lengths(regmatches(lines[[index]], gregexpr("}", lines[[index]], fixed = TRUE)))
    if (opens > 0L) opened <- TRUE
    balance <- balance + opens - closes
    if (opened && balance == 0L) return(lines[start[[1L]]:index])
  }
  fail(paste("Unclosed loader inventory block:", relative_path, start_pattern))
  character()
}

phase18_expect_canonical_first_block <- function(lines, label, dynamic = FALSE) {
  common <- grep("R/common/phase18_canonical_hash[.]R", lines)
  consumers <- which(vapply(lines, function(line) {
    any(vapply(phase18_loader_script_consumers, grepl, logical(1), x = line, fixed = TRUE))
  }, logical(1)))
  expect_equal(length(common), 1L, info = label)
  expect_true(length(consumers) > 0L, info = label)
  if (length(common) == 1L && length(consumers)) {
    expect_true(common[[1L]] < min(consumers), info = label)
    expect_false(grepl("^[[:space:]]*if", lines[[common[[1L]]]]), info = label)
  }
  if (isTRUE(dynamic)) {
    expect_false(any(grepl("if[[:space:]]*\\(file[.]exists.*source", lines)), info = label)
  }
}

test_that("Phase 18 loader inventory is canonical-first in every parent and child process", {
  scripts <- c(
    "scripts/accept_ucl_provider.R",
    "scripts/bootstrap_club_identity.R",
    "scripts/refresh_ucl_source.R",
    "scripts/build_club_history_corpus.R"
  )
  invisible(lapply(scripts, phase18_expect_canonical_first_script))

  direct_loaders <- list(
    list("tests/testthat/test_phase18_source_acceptance.R", "phase18_test_load <- function", FALSE),
    list("tests/testthat/test_phase18_football_data_adapter.R", "phase18_fd_test_load <- function", FALSE),
    list("tests/testthat/test_phase18_source_bundle.R", "phase18_bundle_test_load <- function", FALSE),
    list("tests/testthat/test_phase18_refresh_failure.R", "phase18_refresh_test_load <- function", TRUE),
    list("tests/testthat/test_phase18_club_identity.R", "phase18_identity_test_load <- function", FALSE),
    list("tests/testthat/test_phase18_club_history_contract.R", "phase18_history_test_load <- function", TRUE)
  )
  for (entry in direct_loaders) {
    block <- phase18_loader_extract_block(entry[[1L]], entry[[2L]])
    phase18_expect_canonical_first_block(block, paste(entry[[1L]], entry[[2L]]), entry[[3L]])
  }

  child_processes <- list(
    list(
      "tests/testthat/test_phase18_source_acceptance.R",
      "test_that(\"committed no-key decision validates in a fresh process\""
    ),
    list(
      "tests/testthat/test_phase18_source_bundle.R",
      "test_that(\"provider-live projected resources write and fresh-process validate a candidate bundle\""
    )
  )
  for (entry in child_processes) {
    block <- phase18_loader_extract_block(entry[[1L]], entry[[2L]])
    phase18_expect_canonical_first_block(block, paste(entry[[1L]], "fresh process"))
  }
})

phase18_gap08_approved_expectations <- function() {
  phase18_hash_edition_expectations(data.frame(
    schema_version = "phase18-edition-expectation-v2",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    edition_id = "ucl_2026_27",
    lifecycle = "league_phase",
    expected_club_count = 36L,
    expected_league_phase_match_count = 144L,
    allowed_stages = "LEAGUE_STAGE|PLAYOFFS|LAST_16|QUARTER_FINALS|SEMI_FINALS|FINAL",
    standings_required = TRUE,
    expected_standings_rows = 36L,
    review_state = "approved",
    reviewer = "fixture-owner",
    reviewed_at_utc = "2026-09-19T12:00:00Z",
    row_sha256 = "",
    expectation_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  ))
}

test_that("durable review loading never rehashes tampering or multiplexes review sets", {
  phase18_test_load()
  path <- tempfile("phase18-gap08-review-", fileext = ".csv")
  approved <- phase18_test_review("approved")
  utils::write.csv(approved, path, row.names = FALSE, na = "", quote = TRUE)
  loaded <- phase18_read_terms_review(path)
  expect_identical(loaded$row_sha256, approved$row_sha256)

  tampered <- approved
  tampered$reviewer[[1L]] <- "attacker"
  utils::write.csv(tampered, path, row.names = FALSE, na = "", quote = TRUE)
  expect_error(phase18_read_terms_review(path), "integrity")

  multiplexed <- rbind(
    transform(approved, review_set = "approved"),
    transform(approved, review_set = "second")
  )
  utils::write.csv(multiplexed, path, row.names = FALSE, na = "", quote = TRUE)
  expect_error(phase18_read_terms_review(path), "review sets|schema")
})

test_that("edition authority is exact reviewed v2 evidence", {
  phase18_test_load()
  approved <- phase18_gap08_approved_expectations()
  expect_true(phase18_validate_edition_expectations(approved)$valid)

  pending <- phase18_default_edition_expectations("ucl_2026_27", "2026-09-19T12:00:00Z")
  expect_false(phase18_validate_edition_expectations(pending)$valid)
  expect_identical(phase18_validate_edition_expectations(pending)$reason_code, "terms")

  bad_reviewer <- approved
  bad_reviewer$reviewer <- "pending_owner_review"
  bad_reviewer <- phase18_hash_edition_expectations(bad_reviewer)
  expect_false(phase18_validate_edition_expectations(bad_reviewer)$valid)

  wrong_edition <- approved
  wrong_edition$edition_id <- "ucl_2025_26"
  wrong_edition <- phase18_hash_edition_expectations(wrong_edition)
  expect_false(phase18_validate_edition_expectations(wrong_edition)$valid)
})

test_that("machine authority requires the exact sixteen capability evidence contracts", {
  phase18_test_load()
  expectations <- phase18_gap08_approved_expectations()
  checks <- phase18_default_machine_checks(expectations, "2026-09-19T12:00:00Z", "missing_credential")
  expect_equal(nrow(checks), 16L)
  expect_setequal(checks$capability, names(phase18_capability_decisions()))
  expect_true(phase18_validate_machine_checks(checks)$valid)

  expect_false(phase18_validate_machine_checks(checks[-1L, , drop = FALSE])$valid)
  invented <- checks
  opted_out <- invented$decision == "OPT-OUT"
  invented$executed[opted_out] <- TRUE
  invented$freshness_passed[opted_out] <- TRUE
  invented <- phase18_hash_machine_checks(invented)
  expect_false(phase18_validate_machine_checks(invented)$valid)

  zero_observations <- phase18_test_machine_checks("live_acceptance_probe", TRUE)
  resources <- zero_observations$capability %in% names(phase18_probe_endpoints())
  zero_observations$observed_count[resources] <- 0L
  zero_observations <- phase18_hash_machine_checks(zero_observations)
  validation <- phase18_validate_machine_checks(zero_observations)
  expect_false(validation$valid)
  expect_identical(validation$reason_code, "coverage")
  manifest <- phase18_build_acceptance_manifest(
    zero_observations, phase18_test_review("approved"), expectations,
    phase18_test_fingerprint(TRUE), "zero-observation-proof", "2026-09-19T12:30:00Z",
    parser_commit_sha = "0123456789abcdef0123456789abcdef01234567"
  )
  expect_false(manifest$automation_enabled)
  expect_identical(manifest$reason_code, "coverage")
})

test_that("schema fingerprint rows and aggregate are independently recomputed", {
  phase18_test_load()
  fingerprint <- phase18_default_schema_fingerprint("2026-09-19T12:00:00Z")
  validated <- phase18_validate_schema_fingerprint(fingerprint)
  expect_true(validated$valid)
  expect_match(validated$schema_fingerprint_sha256, "^[0-9a-f]{64}$")

  tampered <- fingerprint
  tampered$endpoint[[1L]] <- "/competitions/evil"
  expect_error(phase18_validate_schema_fingerprint(tampered), "integrity")
})

test_that("manifest authority receives and binds the actual fingerprint table", {
  phase18_test_load()
  review <- phase18_test_review("approved")
  expectations <- phase18_gap08_approved_expectations()
  fingerprint <- phase18_default_schema_fingerprint("2026-09-19T12:00:00Z")
  machine <- phase18_default_machine_checks(expectations, "2026-09-19T12:00:00Z", "missing_credential")
  manifest <- phase18_build_acceptance_manifest(
    machine, review, expectations, fingerprint,
    "gap08-fingerprint-proof", "2026-09-19T12:00:00Z",
    parser_commit_sha = "0123456789abcdef0123456789abcdef01234567"
  )
  expect_silent(phase18_validate_acceptance_manifest(
    manifest, machine, review, expectations, fingerprint
  ))
  tampered <- fingerprint
  tampered$fingerprint_sha256[[1L]] <- paste(rep("f", 64L), collapse = "")
  expect_error(
    phase18_validate_acceptance_manifest(manifest, machine, review, expectations, tampered),
    "integrity|fingerprint"
  )
})

test_that("acceptance publication selects one immutable generation with a hash-bound pointer", {
  phase18_test_load()
  root <- phase18_test_seed_probe_root()
  pointer_path <- file.path(root, "current.json")
  expect_true(file.exists(pointer_path))
  before <- phase18_read_acceptance_set(root)
  expect_match(before$current_generation, "^generations/[a-z0-9-]+$")
  expect_identical(
    sort(list.files(file.path(root, before$current_generation), all.files = TRUE, no.. = TRUE)),
    sort(phase18_acceptance_file_names())
  )

  result <- phase18_run_live_acceptance_probe(
    root, phase18_test_review("approved"), phase18_test_expectations(),
    phase18_test_probe_transport(), "generation-proof-001", "2026-09-19T13:00:00Z"
  )
  expect_identical(result$reason_code, "accepted")
  after <- phase18_read_acceptance_set(root)
  expect_false(identical(before$current_generation, after$current_generation))
  expect_identical(after$pointer$decision_id[[1L]], after$manifest$decision_id[[1L]])
  expect_identical(after$pointer$manifest_sha256[[1L]], after$manifest$row_sha256[[1L]])
})

test_that("pointer-swap interruption exposes only the old or complete new generation", {
  phase18_test_load()
  root <- phase18_test_seed_probe_root()
  old <- phase18_read_acceptance_set(root)
  old_pointer <- readBin(file.path(root, "current.json"), "raw", file.info(file.path(root, "current.json"))$size)
  interrupted <- phase18_run_live_acceptance_probe(
    root, phase18_test_review("approved"), phase18_test_expectations(),
    phase18_test_probe_transport(), "generation-before-swap", "2026-09-19T13:00:00Z",
    failure_injector = function(stage, ...) {
      if (identical(stage, "before_pointer_swap")) stop("injected interruption", call. = FALSE)
    }
  )
  expect_identical(interrupted$reason_code, "interrupted")
  expect_identical(
    readBin(file.path(root, "current.json"), "raw", file.info(file.path(root, "current.json"))$size),
    old_pointer
  )
  expect_identical(phase18_read_acceptance_set(root)$current_generation, old$current_generation)

  committed <- phase18_run_live_acceptance_probe(
    root, phase18_test_review("approved"), phase18_test_expectations(),
    phase18_test_probe_transport(fingerprint_seed = "after-swap"),
    "generation-after-swap", "2026-09-19T13:05:00Z",
    failure_injector = function(stage, ...) {
      if (identical(stage, "after_pointer_swap")) stop("post-commit interruption", call. = FALSE)
    }
  )
  expect_identical(committed$reason_code, "accepted")
  expect_silent(phase18_read_acceptance_set(root))
  expect_identical(
    phase18_read_acceptance_set(root)$manifest$decision_id[[1L]],
    "generation-after-swap"
  )
})

test_that("terminating a writer on either side of the pointer swap preserves a complete generation", {
  skip_if_not_installed("processx")
  phase18_test_load()
  writer_script <- phase18_test_write_subprocess(c(
    "args <- commandArgs(trailingOnly = TRUE)",
    "project <- args[[1L]]; root <- args[[2L]]; payload_path <- args[[3L]]",
    "marker <- args[[4L]]; pause_at <- args[[5L]]",
    "source(file.path(project, 'R/common/phase18_canonical_hash.R'))",
    "source(file.path(project, 'R/competition/ucl_source_acceptance.R'))",
    "payload <- readRDS(payload_path)",
    "phase18_run_live_acceptance_probe(root, payload$review, payload$expectations, payload$transport,",
    "  payload$decision_id, payload$now_utc, failure_injector = function(stage, ...) {",
    "    if (identical(stage, pause_at)) { writeLines(stage, marker); Sys.sleep(60) }",
    "  })"
  ), "phase18-kill-writer-")
  on.exit(unlink(writer_script, force = TRUE), add = TRUE)

  run_kill_case <- function(pause_at, decision_id) {
    root <- phase18_test_seed_probe_root()
    old <- phase18_read_acceptance_set(root)
    payload_path <- tempfile("phase18-kill-payload-", fileext = ".rds")
    marker <- tempfile("phase18-kill-marker-")
    saveRDS(list(
      review = phase18_test_review("approved"),
      expectations = phase18_test_expectations(),
      transport = phase18_test_probe_transport(fingerprint_seed = decision_id),
      decision_id = decision_id,
      now_utc = "2026-09-19T14:00:00Z"
    ), payload_path)
    on.exit(unlink(c(payload_path, marker), force = TRUE), add = TRUE)
    process <- processx::process$new(
      "Rscript", c("--vanilla", writer_script, phase18_test_root, root, payload_path, marker, pause_at),
      stdout = "|", stderr = "|"
    )
    phase18_test_wait_for_path(marker, process)
    process$kill()
    process$wait(timeout = 5000)
    selected <- phase18_read_acceptance_set(root)
    expect_silent(phase18_validate_acceptance_manifest(
      selected$manifest, selected$machine_checks, selected$owner_review,
      selected$edition_expectations, selected$schema_fingerprint
    ))
    if (identical(pause_at, "before_pointer_swap")) {
      expect_identical(selected$current_generation, old$current_generation)
    } else {
      expect_identical(selected$manifest$decision_id[[1L]], decision_id)
    }
  }

  run_kill_case("before_pointer_swap", "killed-before-pointer")
  run_kill_case("after_pointer_swap", "killed-after-pointer")
})

test_that("a concurrent subprocess reader observes only complete old or new decision tuples", {
  skip_if_not_installed("processx")
  phase18_test_load()
  root <- phase18_test_seed_probe_root()
  old <- phase18_read_acceptance_set(root)
  payload_path <- tempfile("phase18-concurrent-payload-", fileext = ".rds")
  writer_marker <- tempfile("phase18-concurrent-writer-")
  reader_marker <- tempfile("phase18-concurrent-reader-")
  release <- tempfile("phase18-concurrent-release-")
  observations <- tempfile("phase18-concurrent-observations-", fileext = ".csv")
  saveRDS(list(
    review = phase18_test_review("approved"), expectations = phase18_test_expectations(),
    transport = phase18_test_probe_transport(fingerprint_seed = "concurrent-new"),
    decision_id = "concurrent-new", now_utc = "2026-09-19T14:05:00Z"
  ), payload_path)
  writer_script <- phase18_test_write_subprocess(c(
    "args <- commandArgs(trailingOnly = TRUE)",
    "project <- args[[1L]]; root <- args[[2L]]; payload <- readRDS(args[[3L]])",
    "marker <- args[[4L]]; release <- args[[5L]]",
    "source(file.path(project, 'R/common/phase18_canonical_hash.R'))",
    "source(file.path(project, 'R/competition/ucl_source_acceptance.R'))",
    "phase18_run_live_acceptance_probe(root, payload$review, payload$expectations, payload$transport,",
    "  payload$decision_id, payload$now_utc, failure_injector = function(stage, ...) {",
    "    if (identical(stage, 'before_pointer_swap')) {",
    "      writeLines(stage, marker); while (!file.exists(release)) Sys.sleep(0.01)",
    "    }",
    "  })"
  ), "phase18-concurrent-writer-")
  reader_script <- phase18_test_write_subprocess(c(
    "args <- commandArgs(trailingOnly = TRUE)",
    "project <- args[[1L]]; root <- args[[2L]]; output <- args[[3L]]; ready <- args[[4L]]",
    "source(file.path(project, 'R/common/phase18_canonical_hash.R'))",
    "source(file.path(project, 'R/competition/ucl_source_acceptance.R'))",
    "rows <- vector('list', 120L)",
    "for (index in seq_len(120L)) {",
    "  rows[[index]] <- tryCatch({ x <- phase18_read_acceptance_set(root); data.frame(",
    "    decision_id = x$manifest$decision_id[[1L]], manifest_sha256 = x$manifest$row_sha256[[1L]],",
    "    error = '', stringsAsFactors = FALSE) }, error = function(error) data.frame(",
    "    decision_id = '', manifest_sha256 = '', error = conditionMessage(error), stringsAsFactors = FALSE))",
    "  if (index == 1L) writeLines('ready', ready)",
    "  Sys.sleep(0.002)",
    "}",
    "utils::write.csv(do.call(rbind, rows), output, row.names = FALSE, quote = TRUE)"
  ), "phase18-concurrent-reader-")
  on.exit(unlink(c(
    payload_path, writer_marker, reader_marker, release, observations,
    writer_script, reader_script
  ), recursive = TRUE, force = TRUE), add = TRUE)

  writer <- processx::process$new(
    "Rscript", c("--vanilla", writer_script, phase18_test_root, root, payload_path, writer_marker, release),
    stdout = "|", stderr = "|"
  )
  phase18_test_wait_for_path(writer_marker, writer)
  reader <- processx::process$new(
    "Rscript", c("--vanilla", reader_script, phase18_test_root, root, observations, reader_marker),
    stdout = "|", stderr = "|"
  )
  phase18_test_wait_for_path(reader_marker, reader)
  writeLines("release", release)
  writer$wait(timeout = 10000)
  reader$wait(timeout = 30000)
  expect_equal(writer$get_exit_status(), 0L, info = paste(writer$read_all_error(), collapse = "\n"))
  expect_equal(reader$get_exit_status(), 0L, info = paste(reader$read_all_error(), collapse = "\n"))

  observed <- utils::read.csv(
    observations, stringsAsFactors = FALSE, check.names = FALSE,
    na.strings = character(), colClasses = "character"
  )
  new <- phase18_read_acceptance_set(root)
  allowed <- c(
    paste(old$manifest$decision_id[[1L]], old$manifest$row_sha256[[1L]], sep = "|"),
    paste(new$manifest$decision_id[[1L]], new$manifest$row_sha256[[1L]], sep = "|")
  )
  tuples <- paste(observed$decision_id, observed$manifest_sha256, sep = "|")
  expect_true(
    all(!nzchar(observed$error)),
    info = paste(unique(observed$error[nzchar(observed$error)]), collapse = "\n")
  )
  expect_true(all(tuples %in% allowed))
  expect_setequal(unique(tuples), allowed)
})

phase18_gap08_cli_args <- function(evidence_root, review_path, edition_id = "ucl_2026_27", mode = "preflight") {
  c(
    "--provider-id", "football_data_org_v4",
    "--edition-id", edition_id,
    "--review-path", review_path,
    "--evidence-root", evidence_root,
    "--mode", mode
  )
}

phase18_gap08_load_bundle_fixture_helpers <- function() {
  expressions <- parse(file.path(phase18_test_root, "tests/testthat/test_phase18_source_bundle.R"))
  wanted <- c(
    "phase18_bundle_test_projected", "phase18_bundle_test_fetched",
    "phase18_bundle_test_manual_review", "phase18_bundle_test_fixture_contract"
  )
  for (expression in expressions) {
    if (is.call(expression) && identical(expression[[1L]], as.name("<-")) &&
        is.symbol(expression[[2L]]) && as.character(expression[[2L]]) %in% wanted) {
      eval(expression, envir = .GlobalEnv)
    }
  }
  phase18_test_require(wanted)
  invisible(TRUE)
}

phase18_gap08_run_cli_harness <- function(harness, payload) {
  payload_path <- tempfile("phase18-cli-mode-payload-", fileext = ".rds")
  saveRDS(payload, payload_path)
  on.exit(unlink(payload_path, force = TRUE), add = TRUE)
  output <- suppressWarnings(system2(
    "Rscript", c("--vanilla", harness, phase18_test_root, payload_path),
    stdout = TRUE, stderr = TRUE
  ))
  list(status = attr(output, "status") %||% 0L, output = output)
}

test_that("unsafe and unknown edition IDs fail before any filesystem mutation", {
  phase18_test_load()
  sandbox <- tempfile("phase18-edition-sandbox-")
  dir.create(sandbox, recursive = TRUE)
  review_path <- tempfile("phase18-edition-review-", fileext = ".csv")
  utils::write.csv(phase18_test_review("pending"), review_path, row.names = FALSE, na = "", quote = TRUE)
  before <- phase18_test_tree_sha(sandbox)
  unsafe <- c(
    "../ucl_2026_27", "ucl_2026_27/escape", "ucl_2026_27\\escape",
    ".", "..", "%2e%2e%2fucl_2026_27", normalizePath(tempdir(), winslash = "/"),
    "ucl_2025_26"
  )
  for (edition_id in unsafe) {
    expect_error(
      phase18_accept_parse_args(phase18_gap08_cli_args(sandbox, review_path, edition_id)),
      "edition|supported|unsafe"
    )
    expect_identical(phase18_test_tree_sha(sandbox), before)
  }

  outside <- tempfile("phase18-edition-outside-")
  dir.create(outside)
  link <- file.path(sandbox, "football_data_org_v4")
  if (isTRUE(file.symlink(outside, link))) {
    outside_before <- phase18_test_tree_sha(outside)
    expect_error(
      phase18_accept_ucl_provider_main(
        phase18_gap08_cli_args(sandbox, review_path),
        token_present = FALSE,
        now_utc = "2026-09-19T15:00:00Z"
      ),
      "unsafe|trusted provider root"
    )
    expect_identical(phase18_test_tree_sha(outside), outside_before)
  }
})

test_that("every CLI main result uses the tagged decision or bundle union", {
  phase18_test_load()
  evidence_root <- tempfile("phase18-result-union-")
  review_path <- tempfile("phase18-result-review-", fileext = ".csv")
  utils::write.csv(phase18_test_review("pending"), review_path, row.names = FALSE, na = "", quote = TRUE)
  result <- phase18_accept_ucl_provider_main(
    phase18_gap08_cli_args(evidence_root, review_path),
    token_present = FALSE,
    now_utc = "2026-09-19T15:00:00Z"
  )
  expect_identical(result$result_type, "decision")
  expect_identical(result$mode, "preflight")
  expect_identical(result$status, "blocked")
  expect_identical(result$reason_code, "missing_credential")
  expect_true(isTRUE(result$durable_mutation))
  expect_named(result$decision, c("decision_id", "decision", "automation_enabled"))
  expect_null(result$bundle)
})

test_that("CLI render and exit contracts distinguish success blocked rejected and errors", {
  phase18_test_load()
  phase18_test_require(c("phase18_accept_cli_exit_code", "phase18_accept_render_result"))
  decision <- list(
    result_type = "decision", mode = "preflight", status = "blocked",
    reason_code = "missing_credential", durable_mutation = TRUE,
    decision = list(decision_id = "missing-key", decision = "not_run", automation_enabled = FALSE),
    bundle = NULL
  )
  rendered <- phase18_accept_render_result(decision)
  expect_match(rendered, "type=decision")
  expect_match(rendered, "status=blocked")
  expect_false(grepl("bundle_sha256", rendered, fixed = TRUE))
  expect_equal(phase18_accept_cli_exit_code(decision), 2L)
  rejected <- decision
  rejected$status <- "rejected"
  success <- decision
  success$status <- "success"
  expect_equal(phase18_accept_cli_exit_code(rejected), 3L)
  expect_equal(phase18_accept_cli_exit_code(success), 0L)
})

test_that("executable CLI rejects traversal without creating paths", {
  phase18_test_load()
  sandbox <- tempfile("phase18-cli-traversal-")
  dir.create(sandbox, recursive = TRUE)
  review_path <- tempfile("phase18-cli-traversal-review-", fileext = ".csv")
  utils::write.csv(phase18_test_review("pending"), review_path, row.names = FALSE, na = "", quote = TRUE)
  before <- phase18_test_tree_sha(sandbox)
  args <- c(
    file.path(phase18_test_root, "scripts/accept_ucl_provider.R"),
    phase18_gap08_cli_args(sandbox, review_path, "../escape")
  )
  output <- suppressWarnings(system2(
    "Rscript", c("--vanilla", shQuote(args)), stdout = TRUE, stderr = TRUE
  ))
  status <- attr(output, "status") %||% 0L
  expect_equal(status, 64L, info = paste(output, collapse = "\n"))
  expect_match(paste(output, collapse = "\n"), "edition|supported|unsafe")
  expect_identical(phase18_test_tree_sha(sandbox), before)
})

test_that("Rscript subprocesses expose mode-correct decision and bundle exits", {
  phase18_test_load()
  phase18_gap08_load_bundle_fixture_helpers()
  registry_root <- tempfile("phase18-mode-registry-")
  phase18_write_club_registries_atomic(phase18_test_adapter_registries(), registry_root)
  review_path <- tempfile("phase18-mode-review-", fileext = ".csv")
  review <- phase18_test_review("approved")
  utils::write.csv(review, review_path, row.names = FALSE, na = "", quote = TRUE)
  expectations <- phase18_gap08_approved_expectations()
  fingerprint <- phase18_test_fingerprint(TRUE)
  fixture_evidence <- list(
    edition_expectations = expectations,
    schema_fingerprint = fingerprint
  )
  projected <- phase18_bundle_test_projected(fixture_evidence)
  projected$coverage <- list(
    stages = "LEAGUE_STAGE", freshness_passed = TRUE,
    identity_passed = TRUE, pagination_complete = TRUE
  )
  fetched <- phase18_bundle_test_fetched()
  inputs <- list(
    projected = projected, fetched = fetched,
    edition_expectations = expectations
  )
  evidence_root <- tempfile("phase18-mode-evidence-")
  target_root <- file.path(evidence_root, "football_data_org_v4", "ucl_2026_27")
  dir.create(target_root, recursive = TRUE)
  machine <- phase18_default_machine_checks(expectations, "2026-09-19T15:00:00Z", "missing_credential")
  disabled_fingerprint <- phase18_default_schema_fingerprint("2026-09-19T15:00:00Z")
  disabled <- phase18_build_acceptance_manifest(
    machine, review, expectations, disabled_fingerprint,
    "mode-matrix-disabled", "2026-09-19T15:00:00Z",
    parser_commit_sha = "0123456789abcdef0123456789abcdef01234567"
  )
  phase18_publish_acceptance_generation(
    target_root, review, expectations, machine, disabled_fingerprint,
    disabled, phase18_acceptance_markdown(disabled)
  )

  manual_path <- tempfile("phase18-mode-manual-", fileext = ".csv")
  fixture_path <- tempfile("phase18-mode-fixture-", fileext = ".csv")
  utils::write.csv(phase18_bundle_test_manual_review(), manual_path, row.names = FALSE, na = "", quote = TRUE)
  utils::write.csv(phase18_bundle_test_fixture_contract(), fixture_path, row.names = FALSE, na = "", quote = TRUE)
  harness <- phase18_test_write_subprocess(c(
    "args <- commandArgs(trailingOnly = TRUE)",
    "project <- args[[1L]]; payload <- readRDS(args[[2L]])",
    "sys.source(file.path(project, 'scripts/accept_ucl_provider.R'), envir = .GlobalEnv)",
    "call <- list(args = payload$args, token_present = payload$token_present, now_utc = payload$now_utc)",
    "if (payload$kind == 'adapter') {",
    "  call$perform_request <- function(...) stop('fetch stub owns transport')",
    "  call$fetch_window_fn <- function(...) payload$inputs$fetched",
    "  call$project_resources_fn <- function(...) payload$inputs$projected",
    "} else if (payload$kind == 'candidate') {",
    "  call$candidate_input_fn <- function(...) payload$inputs",
    "}",
    "result <- tryCatch(do.call(phase18_accept_ucl_provider_main, call),",
    "  error = function(error) phase18_accept_error_result(error, payload$args))",
    "cat(phase18_accept_render_result(result),",
    "  if (identical(result$result_type, 'error')) paste0(' message=', result$message) else '', '\\n')",
    "quit(save = 'no', status = phase18_accept_cli_exit_code(result), runLast = FALSE)"
  ), "phase18-mode-harness-")
  on.exit(unlink(c(harness, manual_path, fixture_path), force = TRUE), add = TRUE)
  common <- phase18_gap08_cli_args(evidence_root, review_path)

  cases <- list(
    offline_contract_test = list(
      kind = "adapter", args = c(common, "--club-registry-root", registry_root),
      token_present = FALSE, now_utc = "2026-09-19T15:05:00Z", inputs = inputs,
      status = 2L, type = "decision", reason = "offline_only"
    ),
    live_acceptance_probe = list(
      kind = "adapter", args = c(
        phase18_gap08_cli_args(evidence_root, review_path, mode = "live_acceptance_probe"),
        "--club-registry-root", registry_root
      ),
      token_present = TRUE, now_utc = "2026-09-19T15:10:00Z", inputs = inputs,
      status = 0L, type = "decision", reason = "accepted"
    )
  )
  cases$offline_contract_test$args[match("preflight", cases$offline_contract_test$args)] <- "offline_contract_test"
  for (name in names(cases)) {
    result <- phase18_gap08_run_cli_harness(harness, cases[[name]])
    expect_equal(result$status, cases[[name]]$status, info = paste(result$output, collapse = "\n"))
    text <- paste(result$output, collapse = "\n")
    expect_match(text, paste0("type=", cases[[name]]$type))
    expect_match(text, paste0("mode=", name))
    expect_match(text, paste0("reason=", cases[[name]]$reason))
  }

  production_parent <- file.path(phase18_test_root, "data/competition/provider_acceptance")
  production_selected <- phase18_read_acceptance_set(file.path(
    production_parent, "football_data_org_v4", "ucl_2026_27"
  ))
  provider_case <- list(
    kind = "candidate",
    args = c(
      phase18_gap08_cli_args(
        production_parent, production_selected$paths[["provider_terms_review.csv"]],
        mode = "provider_live"
      ),
      "--club-registry-root", registry_root,
      "--candidate-root", tempfile("phase18-provider-candidate-"),
      "--bundle-id", "ucl-2026-27-provider-mode-v1"
    ),
    token_present = TRUE, now_utc = "2026-09-19T15:15:00Z", inputs = inputs
  )
  manual_case <- list(
    kind = "candidate",
    args = c(
      phase18_gap08_cli_args(tempfile("phase18-manual-evidence-"), review_path, mode = "manual_reviewed"),
      "--candidate-root", tempfile("phase18-manual-candidate-"),
      "--bundle-id", "ucl-2026-27-manual-mode-v1", "--manual-review-path", manual_path
    ),
    token_present = FALSE, now_utc = "2026-09-19T15:20:00Z", inputs = inputs
  )
  fixture_case <- list(
    kind = "candidate",
    args = c(
      phase18_gap08_cli_args(tempfile("phase18-fixture-evidence-"), review_path, mode = "fixture_contract"),
      "--candidate-root", tempfile("phase18-fixture-candidate-"),
      "--bundle-id", "ucl-2026-27-fixture-mode-v1", "--fixture-contract-path", fixture_path
    ),
    token_present = FALSE, now_utc = "2026-09-19T15:25:00Z", inputs = inputs
  )
  blocked_provider <- phase18_gap08_run_cli_harness(harness, provider_case)
  expect_equal(
    blocked_provider$status, 2L,
    info = paste(blocked_provider$output, collapse = "\n")
  )
  expect_match(paste(blocked_provider$output, collapse = "\n"), "type=decision")
  expect_match(paste(blocked_provider$output, collapse = "\n"), "mode=provider_live")

  for (entry in list(manual_reviewed = manual_case, fixture_contract = fixture_case)) {
    result <- phase18_gap08_run_cli_harness(harness, entry)
    expect_equal(result$status, 0L, info = paste(result$output, collapse = "\n"))
    text <- paste(result$output, collapse = "\n")
    expect_match(text, "type=bundle")
    expect_match(text, "status=success")
    expect_match(text, "bundle_sha256=[0-9a-f]{64}")
  }
})
