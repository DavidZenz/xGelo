phase19_test_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/", mustWork = TRUE
)

phase19_test_load <- function() {
  paths <- c(
    "R/common/phase18_canonical_hash.R",
    "R/competition/source_contracts.R",
    "R/competition/ucl_source_acceptance.R",
    "R/competition/edition_registry.R",
    "R/club/identity.R",
    "R/club/identity_bootstrap.R",
    "R/club/history_contract.R",
    "R/competition/football_data_org_adapter.R",
    "R/competition/ucl_source_bundle.R",
    "R/competition/ucl_source_refresh.R",
    "R/club/model_contract.R"
  )
  for (path in file.path(phase19_test_root, paths)) {
    if (!file.exists(path)) stop("RED: missing Phase 19 dependency: ", path, call. = FALSE)
    source(path, local = .GlobalEnv)
  }
  invisible(TRUE)
}

phase19_test_require <- function(names) {
  missing <- names[!vapply(names, exists, logical(1), mode = "function")]
  if (length(missing)) stop("RED: missing Phase 19 API: ", paste(missing, collapse = ", "), call. = FALSE)
}

phase19_test_history_registries <- function() {
  club_ids <- c("club_alpha", "club_beta", "club_gamma", "club_delta")
  names <- c("Alpha FC", "Beta FC", "Gamma FC", "Delta FC")
  clubs <- data.frame(
    schema_version = phase18_club_identity_schema_version(),
    hash_encoding_version = phase18_canonical_encoding_v2(),
    club_id = club_ids, entity_kind = "club", canonical_name = names,
    association_code = c("AAA", "AAA", "BBB", "BBB"),
    valid_from_utc = "2020-01-01T00:00:00Z", valid_to_utc = "",
    club_status = "active", row_sha256 = "", stringsAsFactors = FALSE,
    check.names = FALSE
  )
  source_ids <- data.frame(
    schema_version = phase18_club_identity_schema_version(),
    hash_encoding_version = phase18_canonical_encoding_v2(),
    club_id = club_ids, source_system = "openfootball",
    source_club_id = paste0("name:", gsub(" ", "_", phase18_normalize_club_name(names), fixed = TRUE)),
    valid_from_utc = "2020-01-01T00:00:00Z", valid_to_utc = "",
    review_state = "approved", source_bundle_id = "phase19-fixture-history",
    row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  aliases <- data.frame(
    schema_version = phase18_club_identity_schema_version(),
    hash_encoding_version = phase18_canonical_encoding_v2(),
    club_id = club_ids, source_system = "openfootball", alias = names,
    normalized_alias = phase18_normalize_club_name(names),
    valid_from_utc = "2020-01-01T00:00:00Z", valid_to_utc = "",
    review_state = "approved", reviewed_by = "phase19-fixture-owner",
    reviewed_at_utc = "2026-01-01T00:00:00Z", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  phase18_hash_club_registry_rows(list(clubs = clubs, source_ids = source_ids, aliases = aliases))
}

phase19_test_history_source <- function(source_id, competition_id, season_id, expected) {
  source <- data.frame(
    schema_version = "phase18-club-history-source-v2",
    hash_encoding_version = phase18_canonical_encoding_v2(), source_id = source_id,
    repository_url = paste0("https://github.com/openfootball/", competition_id),
    commit_sha = paste(rep(substr(source_id, 1L, 1L), 40L), collapse = ""),
    commit_utc = "2025-01-01T00:00:00Z",
    relative_path = paste0(season_id, "/", competition_id, ".txt"),
    competition_id = competition_id, season_id = season_id,
    license_id = "cc0-1.0",
    license_url = "https://creativecommons.org/publicdomain/zero/1.0/",
    license_sha256 = paste(rep("b", 64L), collapse = ""),
    license_review_state = "approved", license_reviewed_by = "phase19-fixture-owner",
    license_reviewed_at_utc = "2026-01-01T00:00:00Z",
    retrieval_utc = "2026-01-02T00:00:00Z", bytes = "123",
    raw_sha256 = paste(rep("c", 64L), collapse = ""),
    expected_completed_matches = as.character(expected),
    coverage_reviewed_by = "phase19-fixture-owner",
    coverage_reviewed_at_utc = "2026-01-02T00:00:00Z",
    source_status = "active", blocked_reason = "", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  source$row_sha256 <- phase18_history_row_sha256(source)
  source
}

phase19_test_history_rows <- function(source_id, home, away, date, ordinal) {
  data.frame(
    source_match_id = paste0(source_id, "-", ordinal), event_date = date,
    kickoff_utc = paste0(date, "T18:00:00Z"), stage = "REGULAR_SEASON",
    status = "completed", home_name = home, away_name = away,
    score_text = if (ordinal %% 2L) "2-1" else "1-1", score_semantics = "regulation",
    evidence_updated_at_utc = paste0(date, "T20:00:00Z"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase19_test_history_audit <- function() {
  registries <- phase19_test_history_registries()
  definitions <- list(
    list("a-league", "league-a", "2024-25", c("Alpha FC", "Beta FC"), c("Beta FC", "Alpha FC")),
    list("b-league", "league-b", "2024-25", c("Gamma FC", "Delta FC"), c("Delta FC", "Gamma FC")),
    list("europe-bridge", "champions-league", "2024-25", c("Alpha FC", "Gamma FC"), c("Delta FC", "Beta FC"))
  )
  sources <- list()
  matches <- list()
  for (index in seq_along(definitions)) {
    item <- definitions[[index]]
    sources[[index]] <- phase19_test_history_source(item[[1L]], item[[2L]], item[[3L]], 2L)
    raw <- rbind(
      phase19_test_history_rows(item[[1L]], item[[4L]][[1L]], item[[4L]][[2L]],
                                sprintf("2025-0%d-01", index + 1L), 1L),
      phase19_test_history_rows(item[[1L]], item[[5L]][[1L]], item[[5L]][[2L]],
                                sprintf("2025-0%d-08", index + 1L), 2L)
    )
    matches[[index]] <- phase18_normalize_club_history(
      raw, sources[[index]], registries, "2025-12-01T00:00:00Z"
    )
  }
  phase18_audit_club_history(
    do.call(rbind, matches), do.call(rbind, sources), registries,
    "2025-12-01T00:00:00Z", corpus_id = "phase19-multi-league-fixture",
    created_at_utc = "2025-12-01T00:00:00Z",
    parser_commit = paste(rep("d", 40L), collapse = ""),
    identity_review = phase18_empty_table(phase18_club_review_schema()),
    unresolved_identity = phase18_empty_table(phase18_unresolved_club_token_schema())
  )
}

phase19_test_fixture_root <- function(label = "authority", accepted_history = TRUE,
                                      current_identity_complete = TRUE) {
  root <- tempfile(paste0("phase19-", label, "-"), tmpdir = tempdir())
  dir.create(root, recursive = TRUE)
  phase19_write_fixture_authority_marker(root, paste0("phase19-", label))
  audit <- phase19_test_history_audit()
  if (!accepted_history) {
    audit$corpus_manifest$accepted_for_training <- FALSE
    audit$corpus_manifest$blocked_reasons <- "fixture_forced_block"
    audit$corpus_manifest$manifest_sha256 <- phase18_history_row_sha256(
      audit$corpus_manifest, "manifest_sha256"
    )
  }
  phase18_publish_club_history_generation(
    audit, file.path(root, "history_generations"), file.path(root, "history_current.json")
  )
  phase19_test_write_current_fixture(root, current_identity_complete)
  root
}

phase19_test_provider_evidence <- function() {
  review <- utils::read.csv(
    file.path(phase19_test_root, "tests/fixtures/phase18/provider_terms_review.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  review <- review[review$review_set == "approved", setdiff(names(review), "review_set"), drop = FALSE]
  review$reviewer <- "phase19-fixture-owner"
  review <- phase18_hash_terms_review(review)
  expectations <- phase18_hash_edition_expectations(data.frame(
    schema_version = "phase18-edition-expectation-v2",
    hash_encoding_version = phase18_canonical_encoding_v2(), edition_id = "ucl_2026_27",
    lifecycle = "league_phase", expected_club_count = 36L,
    expected_league_phase_match_count = 144L,
    allowed_stages = "LEAGUE_STAGE|PLAYOFFS|LAST_16|QUARTER_FINALS|SEMI_FINALS|FINAL",
    standings_required = TRUE, expected_standings_rows = 36L,
    review_state = "approved", reviewer = "phase19-fixture-owner",
    reviewed_at_utc = "2026-09-19T12:00:00Z",
    stringsAsFactors = FALSE, check.names = FALSE
  ))
  transport <- function(endpoint, attempt, cache = FALSE) list(
    count = unname(c(competition_metadata = 1L, teams = 36L, matches = 144L, standings = 36L)[[endpoint]]),
    stages = if (endpoint == "matches") "LEAGUE_STAGE" else "",
    freshness_passed = TRUE, identity_passed = TRUE, pagination_complete = TRUE,
    secret_scan_passed = TRUE,
    fingerprint_sha256 = digest::digest(paste0("phase19-schema-", endpoint), algo = "sha256", serialize = FALSE),
    capability_evidence = if (identical(endpoint, "competition_metadata")) list(
      filters = "fixed competition and season filters observed",
      pagination = "pagination completion observed",
      authenticated_headers = "process-local authentication observed",
      rate_limits = "bounded rate limit handling observed",
      null_empty_semantics = "null and empty semantics observed",
      attribution = "reviewed attribution observed",
      provider_exit = "reviewed provider exit observed"
    ) else NULL, retryable = FALSE
  )
  evidence <- phase18_build_live_probe_evidence(
    transport, review, expectations, "phase19-live-fixture", "2026-09-19T12:30:00Z"
  )
  list(edition_expectations = expectations, schema_fingerprint = evidence$schema_fingerprint)
}

phase19_test_fetched <- function() {
  urls <- setNames(phase18_fd_request_plan()$url, phase18_fd_request_plan()$resource)
  setNames(lapply(names(urls), function(resource) {
    body <- charToRaw(jsonlite::toJSON(list(resource = resource, fixture = TRUE), auto_unbox = TRUE))
    list(resource = resource, final_url = urls[[resource]],
         retrieved_at_utc = "2026-09-19T12:00:00Z", body = body,
         raw_sha256 = digest::digest(body, algo = "sha256", serialize = FALSE),
         parsed = list(resource = resource, fixture = TRUE))
  }), names(urls))
}

phase19_test_current_tables <- function(evidence) {
  club_ids <- sprintf("club_%03d", seq_len(36L))
  clubs <- data.frame(
    schema_version = "phase18-fd-club-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
    edition_id = "ucl_2026_27", provider_id = "football_data_org_v4",
    provider_club_id = as.character(1000L + seq_len(36L)), club_id = club_ids,
    display_name = sprintf("Fixture Club %02d", seq_len(36L)),
    canonical_name = sprintf("Fixture Club %02d", seq_len(36L)),
    last_updated_utc = "2026-09-19T11:00:00Z", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  clubs$row_sha256 <- phase18_ucl_projected_row_hash(clubs)
  matches <- data.frame(
    schema_version = "phase18-fd-match-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
    edition_id = "ucl_2026_27", provider_match_id = as.character(2000L + seq_len(144L)),
    kickoff_utc = "2026-09-20T18:00:00Z", status = "SCHEDULED", stage = "LEAGUE_STAGE",
    home_club_id = club_ids[((seq_len(144L) - 1L) %% 36L) + 1L],
    away_club_id = club_ids[((seq_len(144L) + 10L) %% 36L) + 1L],
    last_updated_utc = "2026-09-19T11:30:00Z", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  matches$row_sha256 <- phase18_ucl_projected_row_hash(matches)
  standings <- data.frame(
    schema_version = "phase18-fd-standing-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
    edition_id = "ucl_2026_27", stage = "LEAGUE_STAGE", position = seq_len(36L),
    club_id = club_ids, played = 0L, points = 0L, row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  standings$row_sha256 <- phase18_ucl_projected_row_hash(standings)
  competition <- data.frame(
    schema_version = "phase18-fd-competition-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
    edition_id = "ucl_2026_27", provider_id = "football_data_org_v4",
    provider_competition_id = "2001", provider_season_id = "2026", code = "CL",
    name = "UEFA Champions League", last_updated_utc = "2026-09-19T11:45:00Z",
    row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  competition$row_sha256 <- phase18_ucl_projected_row_hash(competition)
  lifecycle <- data.frame(
    schema_version = "phase18-fd-lifecycle-v2", hash_encoding_version = phase18_canonical_encoding_v2(),
    edition_id = "ucl_2026_27", lifecycle = "league_phase", observed_club_count = 36L,
    observed_match_count = 144L, observed_standings_rows = 36L,
    observed_stages = "LEAGUE_STAGE",
    expectation_sha256 = evidence$edition_expectations$expectation_sha256[[1L]],
    source_as_of_utc = "2026-09-19T11:45:00Z", retrieved_at_utc = "2026-09-19T12:00:00Z",
    row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  lifecycle$row_sha256 <- phase18_ucl_projected_row_hash(lifecycle)
  list(competition = competition, clubs = clubs, matches = matches,
       standings = standings, lifecycle = lifecycle,
       schema_fingerprint = evidence$schema_fingerprint)
}

phase19_test_fixture_contract <- function(fetched) {
  contract <- data.frame(
    schema_version = "phase18-ucl-fixture-contract-v2",
    hash_encoding_version = phase18_canonical_encoding_v2(),
    fixture_id = "phase19-current-ucl-fixture", edition_id = "ucl_2026_27",
    fixture_purpose = "Phase 19 offline contract tests only",
    aggregate_raw_sha256 = phase18_ucl_raw_aggregate_sha256(fetched),
    fixture_sha256 = "", row_sha256 = "", stringsAsFactors = FALSE,
    check.names = FALSE
  )
  contract$fixture_sha256 <- phase18_ucl_fixture_hash(contract)
  contract$row_sha256 <- phase18_ucl_row_hash(contract)
  contract
}

phase19_test_current_registries <- function(complete = TRUE) {
  count <- if (complete) 36L else 35L
  club_ids <- sprintf("club_%03d", seq_len(count))
  display <- sprintf("Fixture Club %02d", seq_len(count))
  clubs <- data.frame(
    schema_version = phase18_club_identity_schema_version(),
    hash_encoding_version = phase18_canonical_encoding_v2(), club_id = club_ids,
    entity_kind = "club", canonical_name = display, association_code = "FIX",
    valid_from_utc = "2020-01-01T00:00:00Z", valid_to_utc = "",
    club_status = "active", row_sha256 = "", stringsAsFactors = FALSE,
    check.names = FALSE
  )
  source_ids <- data.frame(
    schema_version = phase18_club_identity_schema_version(),
    hash_encoding_version = phase18_canonical_encoding_v2(), club_id = club_ids,
    source_system = "football_data_org_v4",
    source_club_id = as.character(1000L + seq_len(count)),
    valid_from_utc = "2020-01-01T00:00:00Z", valid_to_utc = "",
    review_state = "approved", source_bundle_id = "phase19-current-fixture",
    row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  aliases <- data.frame(
    schema_version = phase18_club_identity_schema_version(),
    hash_encoding_version = phase18_canonical_encoding_v2(), club_id = club_ids,
    source_system = "football_data_org_v4", alias = display,
    normalized_alias = phase18_normalize_club_name(display),
    valid_from_utc = "2020-01-01T00:00:00Z", valid_to_utc = "",
    review_state = "approved", reviewed_by = "phase19-fixture-owner",
    reviewed_at_utc = "2026-01-01T00:00:00Z", row_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  phase18_hash_club_registry_rows(list(clubs = clubs, source_ids = source_ids, aliases = aliases))
}

phase19_test_write_current_fixture <- function(root, complete = TRUE) {
  evidence <- phase19_test_provider_evidence()
  fetched <- phase19_test_fetched()
  candidate <- phase18_build_ucl_source_bundle(
    phase19_test_current_tables(evidence), fetched,
    list(authority_type = "fixture_contract",
         fixture_contract = phase19_test_fixture_contract(fetched)),
    evidence$edition_expectations, "phase19-current-ucl-fixture-v1"
  )
  phase18_write_ucl_candidate(file.path(root, "ucl_candidate"), candidate)
  registry_root <- file.path(root, "club_registries")
  dir.create(registry_root, recursive = TRUE)
  phase18_write_club_registries_atomic(phase19_test_current_registries(complete), registry_root)
  invisible(root)
}

phase19_test_tamper_history <- function(root) {
  pointer <- phase18_history_read_pointer_file(file.path(root, "history_current.json"))
  path <- file.path(root, "history_generations", pointer$accepted_generation_id,
                    "accepted", "matches.csv")
  rows <- phase18_history_read_csv(path)
  rows$final_home_goals[[1L]] <- "99"
  phase18_history_write_csv(rows, path)
  invisible(root)
}

phase19_test_tamper_current <- function(root) {
  path <- file.path(root, "ucl_candidate", "tables", "clubs.csv")
  rows <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = NULL)
  rows$canonical_name[[1L]] <- "Attacker FC"
  utils::write.csv(rows, path, row.names = FALSE, na = "", quote = TRUE)
  invisible(root)
}
