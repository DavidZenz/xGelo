library(testthat)

phase18_bundle_test_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase18_bundle_test_load <- function() {
  source(file.path(phase18_bundle_test_root, "R/common/phase18_canonical_hash.R"), local = .GlobalEnv)
  source(file.path(phase18_bundle_test_root, "R/competition/ucl_source_acceptance.R"), local = .GlobalEnv)
  source(file.path(phase18_bundle_test_root, "R/competition/source_contracts.R"), local = .GlobalEnv)
  source(file.path(phase18_bundle_test_root, "R/competition/edition_registry.R"), local = .GlobalEnv)
  source(file.path(phase18_bundle_test_root, "R/competition/football_data_org_adapter.R"), local = .GlobalEnv)
  bundle_path <- file.path(phase18_bundle_test_root, "R/competition/ucl_source_bundle.R")
  if (file.exists(bundle_path)) source(bundle_path, local = .GlobalEnv)
  sys.source(file.path(phase18_bundle_test_root, "scripts/accept_ucl_provider.R"), envir = .GlobalEnv)
  invisible(TRUE)
}

phase18_bundle_test_provider_evidence <- function() {
  review <- utils::read.csv(
    file.path(phase18_bundle_test_root, "tests/fixtures/phase18/provider_terms_review.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  review <- review[review$review_set == "approved", setdiff(names(review), "review_set"), drop = FALSE]
  review$reviewer <- "bundle-owner-reviewer"
  review <- phase18_hash_terms_review(review)
  expectations <- phase18_hash_edition_expectations(data.frame(
    schema_version = "phase18-edition-expectation-v2",
    hash_encoding_version = phase18_canonical_encoding_v2(), edition_id = "ucl_2026_27",
    lifecycle = "league_phase", expected_club_count = 36L,
    expected_league_phase_match_count = 144L,
    allowed_stages = "LEAGUE_STAGE|PLAYOFFS|LAST_16|QUARTER_FINALS|SEMI_FINALS|FINAL",
    standings_required = TRUE, expected_standings_rows = 36L,
    review_state = "approved", reviewer = "fixture-owner",
    reviewed_at_utc = "2026-09-19T12:00:00Z",
    stringsAsFactors = FALSE,
    check.names = FALSE
  ))
  transport <- function(endpoint, attempt, cache = FALSE) list(
    count = unname(c(competition_metadata = 1L, teams = 36L, matches = 144L, standings = 36L)[[endpoint]]),
    stages = if (endpoint == "matches") "LEAGUE_STAGE" else "",
    freshness_passed = TRUE, identity_passed = TRUE, pagination_complete = TRUE,
    secret_scan_passed = TRUE,
    fingerprint_sha256 = digest::digest(paste0("fixture-schema-", endpoint), algo = "sha256", serialize = FALSE),
    capability_evidence = if (identical(endpoint, "competition_metadata")) list(
      filters = "fixed competition and season filters observed",
      pagination = "pagination completion observed",
      authenticated_headers = "process-local authentication observed",
      rate_limits = "bounded rate limit handling observed",
      null_empty_semantics = "null and empty semantics observed",
      attribution = "reviewed attribution observed",
      provider_exit = "reviewed provider exit observed"
    ) else NULL,
    retryable = FALSE
  )
  evidence <- phase18_build_live_probe_evidence(
    transport, review, expectations, "live-bundle-fixture-001", "2026-09-19T12:30:00Z"
  )
  manifest <- phase18_build_acceptance_manifest(
    evidence$machine_checks, review, expectations,
    evidence$schema_fingerprint,
    "live-bundle-fixture-001", "2026-09-19T12:30:00Z",
    parser_commit_sha = "0123456789abcdef0123456789abcdef01234567"
  )
  root <- tempfile("phase18-bundle-acceptance-")
  published <- phase18_publish_acceptance_generation(
    root, review, expectations, evidence$machine_checks,
    evidence$schema_fingerprint, manifest, "# Synthetic bundle authority\n"
  )
  published[c(
    "manifest", "machine_checks", "owner_review", "edition_expectations",
    "schema_fingerprint", "pointer", "current_generation", "generation_root"
  )]
}

phase18_bundle_test_projected <- function(evidence) {
  club_ids <- sprintf("club_%03d", seq_len(36L))
  clubs <- data.frame(
    schema_version = "phase18-fd-club-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
    edition_id = "ucl_2026_27",
    provider_id = "football_data_org_v4", provider_club_id = as.character(1000L + seq_len(36L)),
    club_id = club_ids, display_name = sprintf("Fixture Club %02d", seq_len(36L)),
    canonical_name = sprintf("Fixture Club %02d", seq_len(36L)),
    last_updated_utc = "2026-09-19T11:00:00Z", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  clubs$row_sha256 <- phase18_ucl_projected_row_hash(clubs)
  matches <- data.frame(
    schema_version = "phase18-fd-match-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
    edition_id = "ucl_2026_27",
    provider_match_id = as.character(2000L + seq_len(144L)),
    kickoff_utc = "2026-09-20T18:00:00Z", status = "SCHEDULED", stage = "LEAGUE_STAGE",
    home_club_id = club_ids[((seq_len(144L) - 1L) %% 36L) + 1L],
    away_club_id = club_ids[((seq_len(144L) + 10L) %% 36L) + 1L],
    last_updated_utc = "2026-09-19T11:30:00Z", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  matches$row_sha256 <- phase18_ucl_projected_row_hash(matches)
  standings <- data.frame(
    schema_version = "phase18-fd-standing-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
    edition_id = "ucl_2026_27",
    stage = "LEAGUE_STAGE", position = seq_len(36L), club_id = club_ids,
    played = 0L, points = 0L, row_sha256 = "", stringsAsFactors = FALSE,
    check.names = FALSE
  )
  standings$row_sha256 <- phase18_ucl_projected_row_hash(standings)
  competition <- data.frame(
    schema_version = "phase18-fd-competition-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
    edition_id = "ucl_2026_27",
    provider_id = "football_data_org_v4", provider_competition_id = "2001",
    provider_season_id = "2026", code = "CL", name = "UEFA Champions League",
    last_updated_utc = "2026-09-19T11:45:00Z", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  competition$row_sha256 <- phase18_ucl_projected_row_hash(competition)
  lifecycle <- data.frame(
    schema_version = "phase18-fd-lifecycle-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
    edition_id = "ucl_2026_27",
    lifecycle = "league_phase", observed_club_count = 36L,
    observed_match_count = 144L, observed_standings_rows = 36L,
    observed_stages = "LEAGUE_STAGE",
    expectation_sha256 = evidence$edition_expectations$expectation_sha256[[1L]],
    source_as_of_utc = "2026-09-19T11:45:00Z",
    retrieved_at_utc = "2026-09-19T12:00:00Z", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  lifecycle$row_sha256 <- phase18_ucl_projected_row_hash(lifecycle)
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

phase18_bundle_test_manual_review <- function(fetched = phase18_bundle_test_fetched(), decision = "accepted") {
  review <- data.frame(
    schema_version = "phase18-ucl-manual-source-review-v2",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    manual_review_id = "manual-ucl-fixture-001", edition_id = "ucl_2026_27",
    decision = decision, source_url = "https://manual.example/ucl-2026-27.json",
    license_id = "fixture-test-only", reviewer = "manual-owner",
    reviewed_at_utc = "2026-09-19T12:00:00Z",
    aggregate_raw_sha256 = phase18_ucl_raw_aggregate_sha256(fetched),
    manual_review_sha256 = "", row_sha256 = "", stringsAsFactors = FALSE,
    check.names = FALSE
  )
  review$manual_review_sha256 <- phase18_ucl_manual_review_hash(review)
  review$row_sha256 <- phase18_ucl_row_hash(review)
  review
}

test_that("manual authority rejects placeholder reviewers and invalid or future review times", {
  phase18_bundle_test_load()
  evidence <- phase18_bundle_test_provider_evidence()
  projected <- phase18_bundle_test_projected(evidence)
  fetched <- phase18_bundle_test_fetched()
  baseline <- phase18_bundle_test_manual_review(fetched)
  variants <- list(
    placeholder = function(x) { x$reviewer <- "fixture-reviewer"; x },
    invalid_time = function(x) { x$reviewed_at_utc <- "not-a-time"; x },
    future_time = function(x) { x$reviewed_at_utc <- "2999-01-01T00:00:00Z"; x }
  )
  for (mutate in variants) {
    review <- mutate(baseline)
    review$manual_review_sha256 <- phase18_ucl_manual_review_hash(review)
    review$row_sha256 <- phase18_ucl_row_hash(review)
    expect_error(
      phase18_build_ucl_source_bundle(
        projected, fetched,
        list(authority_type = "manual_source_review", manual_source_review = review),
        evidence$edition_expectations, "manual-authority-rejected"
      ),
      class = "blocked_authority"
    )
  }
})

phase18_bundle_test_fixture_contract <- function(fetched = phase18_bundle_test_fetched()) {
  contract <- data.frame(
    schema_version = "phase18-ucl-fixture-contract-v2",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    fixture_id = "ucl-contract-fixture-001", edition_id = "ucl_2026_27",
    fixture_purpose = "offline contract tests only",
    aggregate_raw_sha256 = phase18_ucl_raw_aggregate_sha256(fetched),
    fixture_sha256 = "", row_sha256 = "", stringsAsFactors = FALSE,
    check.names = FALSE
  )
  contract$fixture_sha256 <- phase18_ucl_fixture_hash(contract)
  contract$row_sha256 <- phase18_ucl_row_hash(contract)
  contract
}

phase18_bundle_test_candidate <- function(bundle_id = "ucl-2026-27-filesystem-fixture-v1") {
  evidence <- phase18_bundle_test_provider_evidence()
  fetched <- phase18_bundle_test_fetched()
  phase18_build_ucl_source_bundle(
    phase18_bundle_test_projected(evidence), fetched,
    list(
      authority_type = "fixture_contract",
      fixture_contract = phase18_bundle_test_fixture_contract(fetched)
    ),
    evidence$edition_expectations, bundle_id
  )
}

phase18_bundle_test_candidate_tree <- function(label) {
  root <- tempfile(paste0("phase18-ucl-", label, "-"))
  phase18_write_ucl_candidate(
    root,
    phase18_bundle_test_candidate(paste0("ucl-2026-27-", label, "-v1"))
  )
  root
}

test_that("authority is inseparable from exact candidate edition raw bytes and fingerprints", {
  phase18_bundle_test_load()
  evidence <- phase18_bundle_test_provider_evidence()
  projected <- phase18_bundle_test_projected(evidence)
  fetched <- phase18_bundle_test_fetched()
  aggregate <- phase18_ucl_raw_aggregate_sha256(fetched)

  manual <- phase18_bundle_test_manual_review(fetched)
  expect_silent(phase18_validate_source_authority(
    "manual_reviewed",
    list(authority_type = "manual_source_review", manual_source_review = manual),
    candidate_edition_id = "ucl_2026_27", aggregate_raw_sha256 = aggregate
  ))
  wrong_edition <- manual
  wrong_edition$edition_id <- "ucl_2025_26"
  wrong_edition$manual_review_sha256 <- phase18_ucl_manual_review_hash(wrong_edition)
  wrong_edition$row_sha256 <- phase18_ucl_row_hash(wrong_edition)
  expect_error(
    phase18_validate_source_authority(
      "manual_reviewed",
      list(authority_type = "manual_source_review", manual_source_review = wrong_edition),
      candidate_edition_id = "ucl_2026_27", aggregate_raw_sha256 = aggregate
    ),
    class = "blocked_authority"
  )
  wrong_raw <- manual
  wrong_raw$aggregate_raw_sha256 <- phase18_hash_sequence_v2(
    list("competition_metadata", paste(rep("0", 64L), collapse = "")),
    "phase18-test-wrong-raw-v2", c("resource", "raw_sha256"),
    c("character", "character")
  )
  wrong_raw$manual_review_sha256 <- phase18_ucl_manual_review_hash(wrong_raw)
  wrong_raw$row_sha256 <- phase18_ucl_row_hash(wrong_raw)
  expect_error(
    phase18_validate_source_authority(
      "manual_reviewed",
      list(authority_type = "manual_source_review", manual_source_review = wrong_raw),
      candidate_edition_id = "ucl_2026_27", aggregate_raw_sha256 = aggregate
    ),
    class = "blocked_authority"
  )

  fingerprint_tamper <- evidence
  fingerprint_tamper$schema_fingerprint$fingerprint_sha256[[1L]] <- paste(rep("a", 64L), collapse = "")
  fingerprint_tamper$schema_fingerprint$row_sha256 <- phase18_acceptance_hash_rows(
    fingerprint_tamper$schema_fingerprint, "phase18-schema-fingerprint-row-v2"
  )
  expect_error(
    phase18_validate_source_authority(
      "provider_live",
      list(authority_type = "provider_acceptance", provider_acceptance = fingerprint_tamper),
      candidate_edition_id = "ucl_2026_27", aggregate_raw_sha256 = aggregate
    ),
    class = "blocked_authority"
  )
})

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
    "source(%s); source(%s); source(%s); x <- phase18_read_ucl_candidate(%s); phase18_validate_ucl_source_bundle(x)",
    shQuote(file.path(phase18_bundle_test_root, "R/common/phase18_canonical_hash.R")),
    shQuote(file.path(phase18_bundle_test_root, "R/competition/ucl_source_acceptance.R")),
    shQuote(file.path(phase18_bundle_test_root, "R/competition/ucl_source_bundle.R")), shQuote(root)
  )
  output <- system2("Rscript", c("--vanilla", "-e", shQuote(expression)), stdout = TRUE, stderr = TRUE)
  expect_equal(attr(output, "status") %||% 0L, 0L, info = paste(output, collapse = "\n"))

  evidence_parent <- tempfile("phase18-provider-authority-")
  evidence_root <- file.path(evidence_parent, "football_data_org_v4", "ucl_2026_27")
  dir.create(evidence_root, recursive = TRUE)
  phase18_publish_acceptance_generation(
    evidence_root, evidence$owner_review, evidence$edition_expectations,
    evidence$machine_checks, evidence$schema_fingerprint, evidence$manifest,
    "# Fixture accepted provider authority\n"
  )
  cli_root <- tempfile("phase18-provider-live-cli-")
  registry_root <- tempfile("phase18-club-registry-")
  dir.create(registry_root)
  review_path <- tempfile("phase18-provider-review-", fileext = ".csv")
  utils::write.csv(evidence$owner_review, review_path, row.names = FALSE, na = "", quote = TRUE)
  cli <- phase18_accept_ucl_provider_main(
    args = c(
      "--provider-id", "football_data_org_v4", "--edition-id", "ucl_2026_27",
      "--review-path", review_path,
      "--evidence-root", evidence_parent, "--mode", "provider_live",
      "--club-registry-root", registry_root, "--candidate-root", cli_root,
      "--bundle-id", "ucl-2026-27-provider-cli-v1"
    ),
    token_present = TRUE, now_utc = "2026-09-19T12:30:00Z",
    candidate_input_fn = function(options, accepted) list(
      projected = phase18_bundle_test_projected(accepted),
      fetched = phase18_bundle_test_fetched()
    )
  )
  expect_identical(cli$reason_code, "candidate_validated")
  expect_true(cli$promotion_eligible)
  expect_true(dir.exists(cli$candidate_root))
})

test_that("manual and fixture authorities are closed, recomputed, and source-mode specific", {
  phase18_bundle_test_load()
  evidence <- phase18_bundle_test_provider_evidence()
  projected <- phase18_bundle_test_projected(evidence)
  fetched <- phase18_bundle_test_fetched()

  manual <- phase18_bundle_test_manual_review()
  manual_candidate <- phase18_build_ucl_source_bundle(
    projected, fetched,
    list(authority_type = "manual_source_review", manual_source_review = manual),
    evidence$edition_expectations, "ucl-2026-27-manual-fixture-v1"
  )
  expect_silent(phase18_validate_ucl_source_bundle(manual_candidate))
  expect_true(manual_candidate$bundle$promotion_eligible[[1L]])
  expect_false(manual_candidate$bundle$provider_automation_enabled[[1L]])

  fixture <- phase18_bundle_test_fixture_contract()
  fixture_candidate <- phase18_build_ucl_source_bundle(
    projected, fetched,
    list(authority_type = "fixture_contract", fixture_contract = fixture),
    evidence$edition_expectations, "ucl-2026-27-contract-fixture-v1"
  )
  expect_silent(phase18_validate_ucl_source_bundle(fixture_candidate))
  expect_false(fixture_candidate$bundle$promotion_eligible[[1L]])
  expect_false(fixture_candidate$bundle$provider_automation_enabled[[1L]])
  expect_identical(fixture_candidate$authority$reason_code[[1L]], "fixture_permanently_non_promotable")

  expect_error(
    phase18_validate_source_authority("fixture_contract", list(
      authority_type = "fixture_contract", fixture_contract = fixture,
      manual_source_review = manual
    ), candidate_edition_id = "ucl_2026_27",
    aggregate_raw_sha256 = phase18_ucl_raw_aggregate_sha256(fetched)),
    "exactly one|authority"
  )
  forged <- fixture_candidate
  forged$authority$promotion_eligible <- TRUE
  forged$authority$row_sha256 <- phase18_ucl_row_hash(forged$authority)
  forged$bundle$promotion_eligible <- TRUE
  forged$bundle$row_sha256 <- phase18_ucl_row_hash(forged$bundle)
  expect_error(phase18_validate_ucl_source_bundle(forged), "authority|non-promotable")
})

test_that("complete bundle hashes are order-stable and every tamper surface fails closed", {
  phase18_bundle_test_load()
  evidence <- phase18_bundle_test_provider_evidence()
  authority <- list(authority_type = "fixture_contract", fixture_contract = phase18_bundle_test_fixture_contract())
  projected <- phase18_bundle_test_projected(evidence)
  fetched <- phase18_bundle_test_fetched()
  base <- phase18_build_ucl_source_bundle(
    projected, fetched, authority, evidence$edition_expectations, "ucl-2026-27-tamper-fixture-v1"
  )
  reordered <- projected
  for (name in c("clubs", "matches", "standings")) {
    reordered[[name]] <- reordered[[name]][rev(seq_len(nrow(reordered[[name]]))), , drop = FALSE]
  }
  replay <- phase18_build_ucl_source_bundle(
    reordered, fetched, authority, evidence$edition_expectations, "ucl-2026-27-tamper-fixture-v1"
  )
  expect_identical(base$bundle$bundle_sha256, replay$bundle$bundle_sha256)
  expect_identical(base$bundle$manifest_self_sha256, replay$bundle$manifest_self_sha256)

  raw_tamper <- base
  raw_tamper$raw_bytes$teams[[1L]] <- as.raw(bitwXor(as.integer(raw_tamper$raw_bytes$teams[[1L]]), 1L))
  expect_error(phase18_validate_ucl_source_bundle(raw_tamper), "[Rr]aw|hash")
  canonical_tamper <- base
  canonical_tamper$tables$clubs$display_name[[1L]] <- "Tampered Club"
  expect_error(phase18_validate_ucl_source_bundle(canonical_tamper), "row hash|[Cc]anonical")
  schema_tamper <- base
  schema_tamper$artifacts$schema_fingerprint_sha256[[1L]] <- phase18_ucl_hash(charToRaw("drift"))
  expect_error(phase18_validate_ucl_source_bundle(schema_tamper), "Artifact hash|schema")
  path_tamper <- base
  path_tamper$artifacts$relative_raw_path[[1L]] <- "../outside.json"
  path_tamper$artifacts$row_sha256 <- phase18_ucl_row_hash(path_tamper$artifacts)
  expect_error(phase18_validate_ucl_source_bundle(path_tamper), "Unsafe|path")
  manifest_tamper <- base
  manifest_tamper$bundle$manifest_self_sha256 <- phase18_ucl_hash(charToRaw("forged manifest"))
  manifest_tamper$bundle$row_sha256 <- phase18_ucl_row_hash(manifest_tamper$bundle)
  expect_error(phase18_validate_ucl_source_bundle(manifest_tamper), "manifest|hash")

  root <- tempfile("phase18-collision-")
  expect_silent(phase18_write_ucl_candidate(root, base))
  expect_silent(phase18_write_ucl_candidate(root, replay))
  changed <- fetched
  changed$teams$body <- c(changed$teams$body, charToRaw(" "))
  changed$teams$raw_sha256 <- phase18_ucl_hash(changed$teams$body)
  collision_authority <- list(
    authority_type = "fixture_contract",
    fixture_contract = phase18_bundle_test_fixture_contract(changed)
  )
  collision <- phase18_build_ucl_source_bundle(
    projected, changed, collision_authority, evidence$edition_expectations,
    "ucl-2026-27-tamper-fixture-v1"
  )
  expect_error(phase18_write_ucl_candidate(root, collision), class = "blocked_provenance_collision")
})

test_that("manual and fixture CLI modes share validation and never enable provider automation", {
  phase18_bundle_test_load()
  evidence <- phase18_bundle_test_provider_evidence()
  projected <- phase18_bundle_test_projected(evidence)
  fetched <- phase18_bundle_test_fetched()
  common <- c(
    "--provider-id", "football_data_org_v4", "--edition-id", "ucl_2026_27",
    "--review-path", file.path(phase18_bundle_test_root, "tests/fixtures/phase18/provider_terms_review.csv"),
    "--evidence-root", tempfile("phase18-nonprovider-evidence-")
  )
  manual_path <- tempfile("phase18-manual-review-", fileext = ".csv")
  utils::write.csv(phase18_bundle_test_manual_review(), manual_path, row.names = FALSE, na = "", quote = TRUE)
  manual_root <- tempfile("phase18-manual-cli-")
  manual <- phase18_accept_ucl_provider_main(
    args = c(common, "--mode", "manual_reviewed", "--manual-review-path", manual_path,
      "--candidate-root", manual_root, "--bundle-id", "ucl-2026-27-manual-cli-v1"),
    token_present = FALSE,
    candidate_input_fn = function(options, authority) list(
      projected = projected, fetched = fetched, edition_expectations = evidence$edition_expectations
    )
  )
  expect_true(manual$promotion_eligible)
  expect_false(manual$provider_automation_enabled)

  fixture_path <- tempfile("phase18-fixture-contract-", fileext = ".csv")
  utils::write.csv(phase18_bundle_test_fixture_contract(), fixture_path, row.names = FALSE, na = "", quote = TRUE)
  fixture_root <- tempfile("phase18-fixture-cli-")
  fixture <- phase18_accept_ucl_provider_main(
    args = c(common, "--mode", "fixture_contract", "--fixture-contract-path", fixture_path,
      "--candidate-root", fixture_root, "--bundle-id", "ucl-2026-27-fixture-cli-v1"),
    token_present = FALSE,
    candidate_input_fn = function(options, authority) list(
      projected = projected, fetched = fetched, edition_expectations = evidence$edition_expectations
    )
  )
  expect_false(fixture$promotion_eligible)
  expect_false(fixture$provider_automation_enabled)
  expect_identical(fixture$reason_code, "candidate_validated_non_promotable")
})

test_that("committed manual source review is explicit and cannot fabricate approval", {
  phase18_bundle_test_load()
  path <- file.path(
    phase18_bundle_test_root, "data/competition/manual_source_reviews/ucl_2026_27.csv"
  )
  expect_true(file.exists(path))
  review <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = NULL)
  expect_identical(review$decision[[1L]], "not_reviewed")
  expect_match(review$manual_review_sha256[[1L]], "^[0-9a-f]{64}$")
  expect_match(review$row_sha256[[1L]], "^[0-9a-f]{64}$")
  expect_error(
    phase18_validate_source_authority("manual_reviewed", list(
      authority_type = "manual_source_review", manual_source_review = review
    ), candidate_edition_id = "ucl_2026_27",
    aggregate_raw_sha256 = as.character(review$aggregate_raw_sha256[[1L]])),
    "not accepted"
  )
})

test_that("bundle schemas expose the complete provenance graph and reject incomplete inventory", {
  phase18_bundle_test_load()
  evidence <- phase18_bundle_test_provider_evidence()
  projected <- phase18_bundle_test_projected(evidence)
  fetched <- phase18_bundle_test_fetched()
  candidate <- phase18_build_ucl_source_bundle(
    projected, fetched,
    list(authority_type = "provider_acceptance", provider_acceptance = evidence),
    evidence$edition_expectations, "ucl-2026-27-schema-fixture-v1"
  )
  expect_true(all(c(
    "provider_id", "source_url", "retrieved_at_utc", "source_as_of_utc",
    "edition_id", "expectation_sha256", "schema_fingerprint_sha256", "bytes",
    "raw_sha256", "canonical_content_sha256", "parser_commit_sha", "row_count",
    "authority_type", "authority_id", "authority_sha256", "row_sha256"
  ) %in% names(candidate$artifacts)))
  expect_true(all(c(
    "artifact_manifest_sha256", "table_manifest_sha256", "bundle_sha256",
    "manifest_self_sha256", "promotion_eligible"
  ) %in% names(candidate$bundle)))
  expect_true(all(candidate$authority[c(
    "manual_review_id", "manual_review_sha256", "fixture_id", "fixture_sha256"
  )] == ""))

  incomplete <- projected
  incomplete$standings <- NULL
  expect_error(
    phase18_build_ucl_source_bundle(
      incomplete, fetched,
      list(authority_type = "provider_acceptance", provider_acceptance = evidence),
      evidence$edition_expectations, "ucl-2026-27-incomplete-fixture-v1"
    ),
    "five canonical|incomplete"
  )
  empty <- projected
  empty$clubs <- empty$clubs[0, , drop = FALSE]
  expect_error(
    phase18_build_ucl_source_bundle(
      empty, fetched,
      list(authority_type = "provider_acceptance", provider_acceptance = evidence),
      evidence$edition_expectations, "ucl-2026-27-empty-fixture-v1"
    ),
    "empty"
  )
  duplicate <- projected
  duplicate$clubs$club_id[[2L]] <- duplicate$clubs$club_id[[1L]]
  duplicate$clubs$row_sha256 <- phase18_ucl_projected_row_hash(duplicate$clubs)
  expect_error(
    phase18_build_ucl_source_bundle(
      duplicate, fetched,
      list(authority_type = "provider_acceptance", provider_acceptance = evidence),
      evidence$edition_expectations, "ucl-2026-27-duplicate-fixture-v1"
    ),
    "duplicate"
  )

  root <- tempfile("phase18-inventory-fixture-")
  phase18_write_ucl_candidate(root, candidate)
  writeLines("surplus", file.path(root, "surplus.txt"))
  expect_error(phase18_read_ucl_candidate(root), "inventory")
})

test_that("candidate reader rejects every lexical symlink shape before resolution", {
  phase18_bundle_test_load()

  file_root <- phase18_bundle_test_candidate_tree("file-symlink")
  file_path <- file.path(file_root, "raw", "teams.json")
  unlink(file_path)
  expect_true(file.symlink(file.path(file_root, "raw", "competition_metadata.json"), file_path))
  expect_error(phase18_read_ucl_candidate(file_root), class = "blocked_symlink")

  directory_root <- phase18_bundle_test_candidate_tree("directory-symlink")
  raw_target <- tempfile("phase18-ucl-raw-target-")
  expect_true(file.rename(file.path(directory_root, "raw"), raw_target))
  expect_true(file.symlink(raw_target, file.path(directory_root, "raw")))
  expect_error(phase18_read_ucl_candidate(directory_root), class = "blocked_symlink")

  broken_root <- phase18_bundle_test_candidate_tree("broken-symlink")
  expect_true(file.symlink(file.path(broken_root, "missing-target"), file.path(broken_root, ".broken")))
  expect_error(phase18_read_ucl_candidate(broken_root), class = "blocked_symlink")

  trusted_root <- phase18_bundle_test_candidate_tree("trusted-root-symlink")
  trusted_alias <- tempfile("phase18-ucl-trusted-alias-")
  expect_true(file.symlink(trusted_root, trusted_alias))
  expect_error(phase18_read_ucl_candidate(trusted_alias), class = "blocked_symlink")
})

test_that("authority inventories include hidden entries and are exact recursively", {
  phase18_bundle_test_load()

  hidden_root <- phase18_bundle_test_candidate_tree("hidden-inventory")
  writeLines("hidden", file.path(hidden_root, ".secret"))
  expect_error(phase18_read_ucl_candidate(hidden_root), class = "blocked_inventory")

  surplus_root <- phase18_bundle_test_candidate_tree("surplus-evidence")
  writeLines("surplus", file.path(surplus_root, "authority_evidence", "surplus.csv"))
  expect_error(phase18_read_ucl_candidate(surplus_root), class = "blocked_inventory")

  nested_root <- phase18_bundle_test_candidate_tree("nested-evidence")
  dir.create(file.path(nested_root, "authority_evidence", "nested"))
  expect_error(phase18_read_ucl_candidate(nested_root), class = "blocked_inventory")
})

test_that("candidate snapshots abort when a validated path drifts after its one read", {
  phase18_bundle_test_load()
  root <- phase18_bundle_test_candidate_tree("snapshot-drift")
  mutated <- FALSE
  previous <- options(phase18.ucl.snapshot_hook = function(path, bytes) {
    if (!mutated && identical(basename(path), "authority.csv")) {
      mutated <<- TRUE
      writeBin(c(bytes, charToRaw("\n")), path)
    }
  })
  on.exit(options(previous), add = TRUE)

  expect_error(phase18_read_ucl_candidate(root), class = "blocked_path_drift")
  expect_true(mutated)
})

test_that("empty null adjacent and equal-key resource outcomes are explicit", {
  phase18_bundle_test_load()
  evidence <- phase18_bundle_test_provider_evidence()
  projected <- phase18_bundle_test_projected(evidence)
  fetched <- phase18_bundle_test_fetched()

  empty <- fetched
  empty$teams$body <- raw()
  empty$teams$raw_sha256 <- phase18_ucl_hash(empty$teams$body)
  expect_error(
    phase18_build_ucl_source_bundle(
      projected, empty,
      list(authority_type = "fixture_contract", fixture_contract = phase18_bundle_test_fixture_contract(empty)),
      evidence$edition_expectations, "ucl-2026-27-empty-raw-v1"
    ),
    class = "blocked_empty_resource"
  )

  null <- fetched
  null$matches$body <- NULL
  expect_error(
    phase18_build_ucl_source_bundle(
      projected, null,
      list(authority_type = "fixture_contract", fixture_contract = phase18_bundle_test_fixture_contract(null)),
      evidence$edition_expectations, "ucl-2026-27-null-raw-v1"
    ),
    class = "blocked_empty_resource"
  )

  adjacent <- projected
  old_ids <- adjacent$clubs$club_id[1:2]
  new_ids <- c("edge_01", "edge_010")
  adjacent$clubs$club_id[1:2] <- new_ids
  adjacent$standings$club_id[match(old_ids, adjacent$standings$club_id)] <- new_ids
  for (index in seq_along(old_ids)) {
    adjacent$matches$home_club_id[adjacent$matches$home_club_id == old_ids[[index]]] <- new_ids[[index]]
    adjacent$matches$away_club_id[adjacent$matches$away_club_id == old_ids[[index]]] <- new_ids[[index]]
  }
  for (name in c("clubs", "matches", "standings")) {
    adjacent[[name]]$row_sha256 <- phase18_ucl_projected_row_hash(adjacent[[name]])
  }
  adjacent_candidate <- phase18_build_ucl_source_bundle(
    adjacent, fetched,
    list(authority_type = "fixture_contract", fixture_contract = phase18_bundle_test_fixture_contract(fetched)),
    evidence$edition_expectations, "ucl-2026-27-adjacent-ids-v1"
  )
  expect_silent(phase18_validate_ucl_source_bundle(adjacent_candidate))
  expect_true(all(new_ids %in% adjacent_candidate$tables$clubs$club_id))

  equal <- adjacent
  equal$clubs$club_id[[2L]] <- equal$clubs$club_id[[1L]]
  equal$clubs$row_sha256 <- phase18_ucl_projected_row_hash(equal$clubs)
  expect_error(
    phase18_build_ucl_source_bundle(
      equal, fetched,
      list(authority_type = "fixture_contract", fixture_contract = phase18_bundle_test_fixture_contract(fetched)),
      evidence$edition_expectations, "ucl-2026-27-equal-ids-v1"
    ),
    "duplicate"
  )
})
