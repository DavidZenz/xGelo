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
  review <- utils::read.csv(
    file.path(phase18_test_root, "tests/fixtures/phase18/provider_terms_review.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  review <- review[review$review_set == review_set, setdiff(names(review), "review_set"), drop = FALSE]
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
    reviewer = "fixture-reviewer",
    reviewed_at_utc = "2026-09-19T12:00:00Z",
    row_sha256 = "",
    expectation_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  phase18_hash_edition_expectations(expectations)
}

phase18_test_machine_checks <- function(execution_mode = "offline_contract_test", passed = TRUE) {
  expectation_sha <- phase18_test_expectations()$expectation_sha256[[1L]]
  checks <- data.frame(
    schema_version = "phase18-machine-check-v1",
    capability = c("competition_metadata", "teams", "matches", "standings"),
    decision = "INTEGRATE",
    execution_mode = execution_mode,
    passed = passed,
    observed_count = c(1L, 36L, 144L, 36L),
    observed_stages = c("", "", "LEAGUE_STAGE", ""),
    expectation_sha256 = expectation_sha,
    live_run_id = if (identical(execution_mode, "live_acceptance_probe")) "live-fixture-001" else "",
    real_key_evidence = identical(execution_mode, "live_acceptance_probe"),
    freshness_passed = passed,
    identity_passed = passed,
    pagination_complete = passed,
    secret_scan_passed = passed,
    checked_at_utc = "2026-09-19T12:30:00Z",
    row_sha256 = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
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
  review_path <- file.path(phase18_test_root, "tests/fixtures/phase18/provider_terms_review.csv")
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
  manifest_path <- file.path(evidence_root, "football_data_org_v4", "ucl_2026_27", "acceptance_manifest.csv")
  expect_true(file.exists(manifest_path))
  persisted <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
  expect_silent(phase18_validate_acceptance_manifest(
    persisted,
    result$machine_checks,
    result$owner_review,
    result$edition_expectations
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
    evidence_hashes = list(schema_fingerprint_sha256 = paste(rep("d", 64L), collapse = "")),
    decision_id = "offline-proof-001",
    now_utc = "2026-09-19T12:30:00Z"
  )
  expect_false(manifest$automation_enabled)
  expect_identical(manifest$decision, "not_run")
  expect_identical(manifest$live_provider_decision, "not_run")
  expect_true(manifest$offline_contract_tests_passed)
  expect_silent(phase18_validate_acceptance_manifest(manifest, machine, review, expectations))
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

test_that("production evidence enumerates every reviewed dimension and coverage capability", {
  phase18_test_load()
  root <- file.path(
    phase18_test_root,
    "data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27"
  )
  paths <- file.path(root, c(
    "provider_terms_review.csv", "edition_expectations.csv", "coverage_matrix.csv",
    "schema_fingerprint.csv", "acceptance_manifest.csv", "ACCEPTANCE.md"
  ))
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
  expectations_path <- file.path(
    phase18_test_root,
    "data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27/edition_expectations.csv"
  )
  expectations <- utils::read.csv(expectations_path, stringsAsFactors = FALSE, check.names = FALSE)
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
  schema_hash <- paste(rep("e", 64L), collapse = "")
  accepted <- phase18_build_acceptance_manifest(
    machine, review, expectations,
    list(schema_fingerprint_sha256 = schema_hash),
    "live-proof-001", "2026-09-19T12:30:00Z"
  )
  expect_true(accepted$automation_enabled)
  expect_identical(accepted$decision, "accepted")
  expect_silent(phase18_validate_acceptance_manifest(accepted, machine, review, expectations))

  stale_review <- review
  stale_review$terms_sha256 <- paste(rep("f", 64L), collapse = "")
  stale_review <- phase18_hash_terms_review(stale_review)
  expect_error(
    phase18_validate_acceptance_manifest(accepted, machine, stale_review, expectations),
    "recomputed evidence|review"
  )
  missing_owner_row <- review[-1L, , drop = FALSE]
  blocked <- phase18_build_acceptance_manifest(
    machine, missing_owner_row, expectations,
    list(schema_fingerprint_sha256 = schema_hash),
    "live-proof-002", "2026-09-19T12:30:00Z"
  )
  expect_false(blocked$automation_enabled)
})

test_that("committed no-key decision validates in a fresh process", {
  root <- file.path(
    phase18_test_root,
    "data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27"
  )
  command <- paste0(
    "setwd('", phase18_test_root, "');source('R/common/phase18_canonical_hash.R');",
    "source('R/competition/ucl_source_acceptance.R');",
    "r<-read.csv('", file.path(root, "provider_terms_review.csv"), "',check.names=FALSE);",
    "e<-read.csv('", file.path(root, "edition_expectations.csv"), "',check.names=FALSE);",
    "m<-read.csv('", file.path(root, "coverage_matrix.csv"), "',check.names=FALSE);",
    "a<-read.csv('", file.path(root, "acceptance_manifest.csv"), "',check.names=FALSE);",
    "phase18_validate_acceptance_manifest(a,m,r,e);",
    "stopifnot(!a$automation_enabled[[1]], a$reason_code[[1]]=='missing_credential')"
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
      fingerprint_sha256 = phase18_sha256_text(paste(fingerprint_seed, endpoint, sep = "|"))
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
      schema_version = phase18_club_identity_schema_version(), club_id = ids,
      entity_kind = "club", canonical_name = display, association_code = "FX",
      valid_from_utc = "2020-01-01T00:00:00Z", valid_to_utc = "",
      club_status = "active", row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
    ),
    source_ids = data.frame(
      schema_version = phase18_club_identity_schema_version(), club_id = ids,
      source_system = "football_data_org_v4", source_club_id = provider_ids,
      valid_from_utc = "2020-01-01T00:00:00Z", valid_to_utc = "",
      review_state = "approved", source_bundle_id = "fixture-review-v1",
      row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
    ),
    aliases = data.frame(
      schema_version = phase18_club_identity_schema_version(), club_id = ids,
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
  before <- phase18_test_tree_sha(root)
  lock <- file.path(root, ".phase18-acceptance.lock")
  dir.create(lock)
  concurrent <- phase18_run_live_acceptance_probe(
    root, phase18_test_review("approved"), phase18_test_expectations(),
    phase18_test_probe_transport(), "live-probe-concurrent", "2026-09-19T13:00:00Z"
  )
  expect_identical(concurrent$reason_code, "blocked_concurrent_acceptance")
  unlink(lock, recursive = TRUE, force = TRUE)
  expect_identical(phase18_test_tree_sha(root), before)

  failed <- phase18_run_live_acceptance_probe(
    root, phase18_test_review("approved"), phase18_test_expectations(),
    phase18_test_probe_transport(), "live-probe-writer-failure", "2026-09-19T13:00:00Z",
    failure_injector = function(stage, ...) {
      if (identical(stage, "after_promote_2")) stop("injected interruption", call. = FALSE)
    }
  )
  expect_identical(failed$reason_code, "interrupted")
  expect_identical(phase18_test_tree_sha(root), before)
  residue <- list.files(dirname(root), pattern = "phase18-acceptance-(stage|backup)", all.files = TRUE)
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
    if (!dir.exists(root)) return(setNames(character(), character()))
    paths <- list.files(root, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE)
    paths <- paths[file.exists(paths) & !dir.exists(paths)]
    relative <- substring(paths, nchar(normalizePath(root, winslash = "/")) + 2L)
    setNames(vapply(paths, function(path) {
      digest::digest(file = path, algo = "sha256", serialize = FALSE)
    }, character(1)), paste(basename(root), relative, sep = "/"))
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
  durable_roots <- file.path(phase18_test_root, c(
    "data/competition/provider_acceptance",
    "data/competition/accepted",
    "data/competition/registries",
    "data/club/registries",
    "data/club/identity_reviews",
    "data/club/history_audits",
    "data/club/accepted"
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

  acceptance <- phase18_loader_run_cli(
    "scripts/accept_ucl_provider.R",
    c(
      "--provider-id", "football_data_org_v4",
      "--edition-id", "ucl_2026_27",
      "--review-path", shQuote(file.path(phase18_test_root, "tests/fixtures/phase18/provider_terms_review.csv")),
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
      paste0("--audit-root=", shQuote(file.path(club_scratch, "audit"))),
      paste0("--accepted-root=", shQuote(file.path(club_scratch, "accepted")))
    )
  )

  expect_equal(acceptance$status, 0L, info = paste(acceptance$output, collapse = "\n"))
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
