library(testthat)

phase13_registry_test_project_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase13_registry_test_load_apis <- function() {
  source_paths <- file.path(
    phase13_registry_test_project_root,
    c(
      "R/competition/source_contracts.R",
      "R/competition/team_identity.R",
      "R/competition/edition_registry.R"
    )
  )
  for (path in source_paths) if (file.exists(path)) source(path, local = .GlobalEnv)
  invisible(TRUE)
}

phase13_registry_test_require_api <- function(required) {
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop(
      paste0(
        "Wave 0 RED contract awaits Phase 13 registry API: ",
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

phase13_registry_test_fixture <- function() {
  jsonlite::fromJSON(
    file.path(
      phase13_registry_test_project_root,
      "tests/fixtures/phase13/uefa_nations_league_sample.json"
    ),
    simplifyVector = FALSE
  )
}

phase13_registry_test_identity_map <- function(fixture) {
  rows <- lapply(fixture$teams, function(team) {
    data.frame(
      team_id = team$team_id,
      fifa_code = team$fifa_code,
      canonical_name = team$canonical_name,
      aliases = team$aliases,
      uefa_source_team_id = team$uefa_source_team_id,
      uefa_display_name_current = team$uefa_display_name_current,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

phase13_registry_test_predraw_fixture <- function() {
  jsonlite::fromJSON(
    file.path(
      phase13_registry_test_project_root,
      "tests/fixtures/phase13/euro2028_predraw_sample.json"
    ),
    simplifyVector = TRUE
  )
}

phase13_registry_test_copy_normalized_sandbox <- function() {
  root <- tempfile("phase13-registry-copy-", tmpdir = phase13_registry_test_project_root)
  accepted_root <- file.path(root, "accepted")
  registry_root <- file.path(root, "registries")
  source_accepted_root <- file.path(phase13_registry_test_project_root, "data/competition/accepted")
  source_registry_root <- file.path(phase13_registry_test_project_root, "data/competition/registries")
  editions <- c("uefa_nations_league_2026_27", "uefa_euro_2028_qualifying")
  dir.create(accepted_root, recursive = TRUE, showWarnings = FALSE)
  dir.create(registry_root, recursive = TRUE, showWarnings = FALSE)
  for (edition_id in editions) {
    target <- file.path(accepted_root, edition_id)
    dir.create(target, recursive = TRUE, showWarnings = FALSE)
    source_files <- list.files(
      file.path(source_accepted_root, edition_id),
      full.names = TRUE,
      all.files = FALSE
    )
    stopifnot(all(file.copy(source_files, target, overwrite = TRUE)))
  }
  registry_files <- file.path(
    source_registry_root,
    c("competition_editions.csv", "source_artifacts.csv", "source_bundles.csv", "team_identity.csv")
  )
  stopifnot(all(file.copy(registry_files, registry_root, overwrite = TRUE)))
  list(root = root, accepted_root = accepted_root, registry_root = registry_root)
}

phase13_registry_test_load_sandbox <- function(sandbox) {
  load_competition_edition_registries(
    sandbox$registry_root,
    project_root = phase13_registry_test_project_root,
    accepted_root = sandbox$accepted_root
  )
}

phase13_registry_test_write_csv <- function(data, path) {
  utils::write.csv(data, path, row.names = FALSE, na = "", quote = TRUE)
  invisible(path)
}

test_that("direct UEFA source IDs resolve stable xGelo team IDs while preserving display names", {
  phase13_registry_test_load_apis()
  phase13_registry_test_require_api(c(
    "phase13_prepare_team_identity_map",
    "phase13_normalize_fixture_rows"
  ))
  fixture <- phase13_registry_test_fixture()
  identity_map <- phase13_prepare_team_identity_map(phase13_registry_test_identity_map(fixture))
  source_fixture <- fixture$resources$fixtures[[1L]]
  rows <- data.frame(
    source_fixture_id = source_fixture$source_fixture_id,
    home_uefa_source_team_id = source_fixture$home$uefa_source_team_id,
    away_uefa_source_team_id = source_fixture$away$uefa_source_team_id,
    home_display_name = source_fixture$home$display_name,
    away_display_name = source_fixture$away$display_name,
    scheduled_at_utc = source_fixture$scheduled_at_utc,
    status = source_fixture$status,
    stringsAsFactors = FALSE
  )

  normalized <- phase13_normalize_fixture_rows(
    rows,
    identity_map = identity_map,
    edition_id = fixture$edition_id,
    source_artifact_id = "nl-2026-27-official-sample-v1-fixtures"
  )

  expect_identical(normalized$home_team_id, "team_aut")
  expect_identical(normalized$away_team_id, "team_deu")
  expect_identical(normalized$home_display_name, "Austria")
  expect_identical(normalized$away_display_name, "Germany")
  expect_identical(normalized$home_mapping_method, "source_id")
  expect_identical(normalized$away_mapping_method, "source_id")
  expect_true(grepl("^[0-9a-f]{64}$", normalized$row_sha256))
})

test_that("accepted source bundle links to the approved Phase 12 model release in the edition registry", {
  phase13_registry_test_load_apis()
  phase13_registry_test_require_api(c(
    "phase13_build_competition_edition_row",
    "validate_phase13_competition_edition_registries"
  ))
  fixture <- phase13_registry_test_fixture()
  source_bundle <- data.frame(
    bundle_id = "nl-2026-27-official-sample-v1",
    edition_id = fixture$edition_id,
    bundle_status = "accepted",
    stringsAsFactors = FALSE
  )
  registry <- phase13_build_competition_edition_row(
    edition_id = fixture$edition_id,
    competition_id = "uefa_nations_league",
    display_name = "UEFA Nations League 2026/27",
    lifecycle_state = "scheduled",
    ruleset_version = "uefa-nations-league-2026-27-v1",
    source_bundle_id = source_bundle$bundle_id,
    model_release_id = "phase12-wc2026-incumbent-retained-v1",
    output_bundle_target = "outputs/competition/uefa_nations_league_2026_27",
    active_output_bundle_id = "nl-2026-27-official-sample-v1"
  )

  expect_silent(validate_phase13_competition_edition_registries(
    registry,
    source_bundles = source_bundle
  ))
  expect_identical(registry$source_bundle_id, source_bundle$bundle_id)
  expect_identical(registry$model_release_id, "phase12-wc2026-incumbent-retained-v1")
})

test_that("normalized display-name fallback is visible and ambiguity fails closed", {
  phase13_registry_test_load_apis()
  phase13_registry_test_require_api(c("phase13_prepare_team_identity_map", "phase13_resolve_team_identity"))
  identity_map <- data.frame(
    team_id = c("team_civ", "team_dup_a", "team_dup_b"),
    fifa_code = c("CIV", "DPA", "DPB"),
    canonical_name = c("Cote d'Ivoire", "Duplicate A", "Duplicate B"),
    aliases = c("Côte d'Ivoire", "Same Alias", "Same Alias"),
    uefa_source_team_id = c("200", "201", "202"),
    uefa_display_name_current = c("Côte d'Ivoire", "Duplicate A", "Duplicate B"),
    stringsAsFactors = FALSE
  )
  prepared <- phase13_prepare_team_identity_map(identity_map)
  expect_warning(
    fallback <- phase13_resolve_team_identity(prepared, source_team_id = "missing", display_name = "Cote d'Ivoire"),
    "normalized display-name fallback"
  )
  expect_identical(fallback$team_id, "team_civ")
  expect_identical(fallback$mapping_warning, "normalized_display_name_requires_review")
  expect_error(
    phase13_resolve_team_identity(prepared, source_team_id = "missing", display_name = "Same Alias"),
    "ambiguous"
  )
})

test_that("empty normalized tables retain a complete schema and reject null input", {
  phase13_registry_test_load_apis()
  phase13_registry_test_require_api(c(
    "phase13_empty_normalized_fixture_rows", "phase13_normalized_result_schema",
    "phase13_empty_normalized_result_rows", "phase13_normalize_fixture_rows",
    "phase13_normalize_accepted_result_rows"
  ))
  fixture <- phase13_registry_test_fixture()
  identity_map <- phase13_prepare_team_identity_map(phase13_registry_test_identity_map(fixture))
  empty_source <- data.frame(
    source_fixture_id = character(0),
    home_uefa_source_team_id = character(0),
    away_uefa_source_team_id = character(0),
    home_display_name = character(0),
    away_display_name = character(0),
    scheduled_at_utc = character(0),
    status = character(0),
    stringsAsFactors = FALSE
  )
  normalized <- phase13_normalize_fixture_rows(empty_source, identity_map, fixture$edition_id)
  expect_named(normalized, phase13_normalized_fixture_schema())
  expect_equal(nrow(normalized), 0L)
  expect_error(
    phase13_normalize_fixture_rows(data.frame(), identity_map, fixture$edition_id),
    "missing columns"
  )
})

test_that("accepted results inherit exact fixture identity and preserve valid source scores", {
  phase13_registry_test_load_apis()
  phase13_registry_test_require_api(c(
    "phase13_normalize_fixture_rows", "phase13_normalize_accepted_result_rows",
    "phase13_normalized_result_schema"
  ))
  fixture <- phase13_registry_test_fixture()
  identity_map <- phase13_prepare_team_identity_map(phase13_registry_test_identity_map(fixture))
  source_fixture <- fixture$resources$fixtures[[1L]]
  normalized_fixture <- phase13_normalize_fixture_rows(
    data.frame(
      source_fixture_id = source_fixture$source_fixture_id,
      home_uefa_source_team_id = source_fixture$home$uefa_source_team_id,
      away_uefa_source_team_id = source_fixture$away$uefa_source_team_id,
      home_display_name = source_fixture$home$display_name,
      away_display_name = source_fixture$away$display_name,
      scheduled_at_utc = source_fixture$scheduled_at_utc,
      status = source_fixture$status,
      stringsAsFactors = FALSE
    ),
    identity_map,
    fixture$edition_id,
    source_artifact_id = "nl-fixtures-v1"
  )
  source_result <- fixture$resources$results[[1L]]
  results <- data.frame(
    source_fixture_id = source_result$source_fixture_id,
    status = "completed",
    home_goals = 2L,
    away_goals = 1L,
    edition_id = fixture$edition_id,
    source_artifact_id = "nl-results-v1",
    stringsAsFactors = FALSE
  )

  normalized <- phase13_normalize_accepted_result_rows(
    results,
    normalized_fixture,
    edition_id = fixture$edition_id,
    source_artifact_id = "nl-results-v1",
    lifecycle_state = "complete"
  )
  expect_named(normalized, phase13_normalized_result_schema())
  expect_identical(normalized$fixture_id, "uefa_nations_league_2026_27-nl-2026-0001")
  expect_identical(normalized$home_team_id, "team_aut")
  expect_identical(normalized$away_team_id, "team_deu")
  expect_identical(normalized$home_display_name, "Austria")
  expect_identical(normalized$away_display_name, "Germany")
  expect_identical(normalized$status, "completed")
  expect_identical(normalized$home_goals, 2L)
  expect_identical(normalized$away_goals, 1L)
  expect_identical(normalized$source_artifact_id, "nl-results-v1")
  expect_identical(normalized$fixture_source_artifact_id, "nl-fixtures-v1")
  expect_true(grepl("^[0-9a-f]{64}$", normalized$row_sha256))

  score_only <- results
  score_only$home_goals <- 3L
  score_only$away_goals <- 2L
  score_normalized <- phase13_normalize_accepted_result_rows(
    score_only,
    normalized_fixture,
    edition_id = fixture$edition_id,
    source_artifact_id = "nl-results-v1",
    lifecycle_state = "complete"
  )
  identity_fields <- setdiff(phase13_normalized_result_schema(), c("home_goals", "away_goals", "row_sha256"))
  expect_identical(normalized[identity_fields], score_normalized[identity_fields])
  expect_identical(score_normalized$home_goals, 3L)
  expect_identical(score_normalized$away_goals, 2L)
  expect_false(identical(normalized$row_sha256, score_normalized$row_sha256))
})

test_that("accepted result identity is stable under later-row append, reorder, and score changes", {
  phase13_registry_test_load_apis()
  phase13_registry_test_require_api(c("phase13_normalize_fixture_rows", "phase13_normalize_accepted_result_rows"))
  fixture <- phase13_registry_test_fixture()
  identity_map <- phase13_prepare_team_identity_map(phase13_registry_test_identity_map(fixture))
  source_fixture <- fixture$resources$fixtures[[1L]]
  fixture_row <- data.frame(
    source_fixture_id = source_fixture$source_fixture_id,
    home_uefa_source_team_id = source_fixture$home$uefa_source_team_id,
    away_uefa_source_team_id = source_fixture$away$uefa_source_team_id,
    home_display_name = source_fixture$home$display_name,
    away_display_name = source_fixture$away$display_name,
    scheduled_at_utc = source_fixture$scheduled_at_utc,
    status = source_fixture$status,
    stringsAsFactors = FALSE
  )
  later_fixture <- fixture_row
  later_fixture$source_fixture_id <- "nl-2026-0002"
  later_fixture$scheduled_at_utc <- "2026-10-05T18:45:00Z"
  normalized_fixtures <- phase13_normalize_fixture_rows(
    rbind(fixture_row, later_fixture),
    identity_map,
    fixture$edition_id,
    source_artifact_id = "nl-fixtures-v1"
  )
  results <- data.frame(
    source_fixture_id = c("nl-2026-0001", "nl-2026-0002"),
    status = c("completed", "completed"),
    home_goals = c(1L, 2L),
    away_goals = c(0L, 1L),
    stringsAsFactors = FALSE
  )
  baseline <- phase13_normalize_accepted_result_rows(
    results[1L, , drop = FALSE], normalized_fixtures,
    edition_id = fixture$edition_id,
    source_artifact_id = "nl-results-v1",
    lifecycle_state = "complete"
  )
  appended <- phase13_normalize_accepted_result_rows(
    results, normalized_fixtures,
    edition_id = fixture$edition_id,
    source_artifact_id = "nl-results-v1",
    lifecycle_state = "complete"
  )
  stable_fields <- setdiff(phase13_normalized_result_schema(), c("home_goals", "away_goals", "row_sha256"))
  expect_identical(
    baseline[stable_fields],
    appended[appended$uefa_source_fixture_id == "nl-2026-0001", stable_fields, drop = FALSE]
  )

  perturbed <- results
  perturbed$home_goals[[2L]] <- 5L
  perturbed$away_goals[[2L]] <- 4L
  reordered <- perturbed[c(2L, 1L), , drop = FALSE]
  reordered_normalized <- phase13_normalize_accepted_result_rows(
    reordered, normalized_fixtures,
    edition_id = fixture$edition_id,
    source_artifact_id = "nl-results-v1",
    lifecycle_state = "complete"
  )
  baseline_reordered <- reordered_normalized[reordered_normalized$uefa_source_fixture_id == "nl-2026-0001", , drop = FALSE]
  baseline_identity <- baseline[stable_fields]
  reordered_identity <- baseline_reordered[stable_fields]
  row.names(baseline_identity) <- NULL
  row.names(reordered_identity) <- NULL
  expect_identical(baseline_identity, reordered_identity)
  expect_identical(
    reordered_normalized[reordered_normalized$uefa_source_fixture_id == "nl-2026-0002", c("home_goals", "away_goals")],
    data.frame(home_goals = 5L, away_goals = 4L, stringsAsFactors = FALSE)
  )
})

test_that("accepted result joins reject duplicate, unknown, invalid, and mismatched identity inputs", {
  phase13_registry_test_load_apis()
  phase13_registry_test_require_api(c("phase13_normalize_fixture_rows", "phase13_normalize_accepted_result_rows"))
  fixture <- phase13_registry_test_fixture()
  identity_map <- phase13_prepare_team_identity_map(phase13_registry_test_identity_map(fixture))
  source_fixture <- fixture$resources$fixtures[[1L]]
  normalized_fixture <- phase13_normalize_fixture_rows(
    data.frame(
      source_fixture_id = source_fixture$source_fixture_id,
      home_uefa_source_team_id = source_fixture$home$uefa_source_team_id,
      away_uefa_source_team_id = source_fixture$away$uefa_source_team_id,
      home_display_name = source_fixture$home$display_name,
      away_display_name = source_fixture$away$display_name,
      scheduled_at_utc = source_fixture$scheduled_at_utc,
      status = source_fixture$status,
      stringsAsFactors = FALSE
    ),
    identity_map,
    fixture$edition_id,
    source_artifact_id = "nl-fixtures-v1"
  )
  results <- data.frame(
    source_fixture_id = source_fixture$source_fixture_id,
    status = "completed",
    home_goals = 1L,
    away_goals = 0L,
    stringsAsFactors = FALSE
  )
  expect_error(
    phase13_normalize_accepted_result_rows(rbind(results, results), normalized_fixture),
    "duplicate"
  )
  unknown <- results
  unknown$source_fixture_id <- "missing-fixture"
  expect_error(
    phase13_normalize_accepted_result_rows(unknown, normalized_fixture),
    "unknown"
  )
  invalid_score <- results
  invalid_score$home_goals <- 1.5
  expect_error(
    phase13_normalize_accepted_result_rows(invalid_score, normalized_fixture),
    "invalid.*home_goals"
  )
  incomplete_score <- results
  incomplete_score$away_goals <- NA_integer_
  expect_error(
    phase13_normalize_accepted_result_rows(incomplete_score, normalized_fixture),
    "both.*home_goals.*away_goals|both.*away_goals.*home_goals"
  )
  mismatched_identity <- results
  mismatched_identity$home_team_id <- "team_forged"
  expect_error(
    phase13_normalize_accepted_result_rows(mismatched_identity, normalized_fixture),
    "identity|edition"
  )
  mismatched_edition <- results
  mismatched_edition$edition_id <- "uefa_euro_2028_qualifying"
  expect_error(
    phase13_normalize_accepted_result_rows(mismatched_edition, normalized_fixture),
    "identity|edition"
  )
})

test_that("empty EURO pre-draw results retain the exact normalized result schema", {
  phase13_registry_test_load_apis()
  phase13_registry_test_require_api(c(
    "phase13_empty_normalized_result_rows", "phase13_normalized_result_schema",
    "phase13_normalize_fixture_rows", "phase13_normalize_accepted_result_rows"
  ))
  empty_fixture <- data.frame(
    source_fixture_id = character(0),
    home_uefa_source_team_id = character(0),
    away_uefa_source_team_id = character(0),
    home_display_name = character(0),
    away_display_name = character(0),
    scheduled_at_utc = character(0),
    status = character(0),
    stringsAsFactors = FALSE
  )
  normalized_fixture <- phase13_normalize_fixture_rows(
    empty_fixture,
    data.frame(
      team_id = character(0), fifa_code = character(0), canonical_name = character(0),
      aliases = character(0), uefa_source_team_id = character(0),
      uefa_display_name_current = character(0), stringsAsFactors = FALSE
    ),
    "uefa_euro_2028_qualifying",
    lifecycle_state = "pre_draw"
  )
  empty_results <- data.frame(
    source_fixture_id = character(0), status = character(0),
    home_goals = integer(0), away_goals = integer(0),
    stringsAsFactors = FALSE
  )
  normalized <- phase13_normalize_accepted_result_rows(
    empty_results,
    normalized_fixture,
    edition_id = "uefa_euro_2028_qualifying",
    lifecycle_state = "pre_draw"
  )
  expect_named(normalized, phase13_normalized_result_schema())
  expect_equal(nrow(normalized), 0L)
})

test_that("EURO qualifying remains an explicit pre-draw row without fabricated structures", {
  phase13_registry_test_load_apis()
  phase13_registry_test_require_api(c(
    "phase13_build_competition_edition_row",
    "validate_phase13_competition_edition_registries"
  ))
  fixture <- phase13_registry_test_predraw_fixture()
  source_bundle <- data.frame(
    bundle_id = "euro-2028-pre-draw-v1",
    edition_id = fixture$edition_id,
    bundle_status = "accepted",
    stringsAsFactors = FALSE
  )
  registry <- phase13_build_competition_edition_row(
    edition_id = fixture$edition_id,
    competition_id = "uefa_euro_2028_qualifying",
    display_name = "UEFA EURO 2028 qualifying",
    lifecycle_state = fixture$lifecycle_state,
    ruleset_version = "uefa-euro-2028-qualifying-v1",
    source_bundle_id = source_bundle$bundle_id,
    model_release_id = "phase12-wc2026-incumbent-retained-v1",
    output_bundle_target = fixture$output_bundle_target,
    active_output_bundle_id = "euro-2028-pre-draw-v1"
  )
  expect_silent(validate_phase13_competition_edition_registries(registry, source_bundle))
  expect_identical(registry$lifecycle_state, "pre_draw")
  expect_false(any(c("group_count", "fixture_count", "standings_hash") %in% names(registry)))
  fabricated <- registry
  fabricated$fixture_count <- 1L
  expect_error(validate_phase13_competition_edition_registries(fabricated, source_bundle), "fabricate|pre-draw")
  expect_identical(fixture$published_resource_classes, list())
})

test_that("lifecycle transitions are adjacent and blocked rows retain the last accepted output", {
  phase13_registry_test_load_apis()
  phase13_registry_test_require_api(c(
    "phase13_validate_lifecycle_transition",
    "phase13_block_competition_edition",
    "phase13_transition_competition_edition",
    "phase13_competition_registry_hash"
  ))
  row <- phase13_build_competition_edition_row(
    edition_id = "uefa_nations_league_2026_27",
    competition_id = "uefa_nations_league",
    display_name = "UEFA Nations League 2026/27",
    lifecycle_state = "pre_draw",
    ruleset_version = "uefa-nations-league-2026-27-v1",
    source_bundle_id = "nl-2026-27-official-sample-v1",
    model_release_id = "phase12-wc2026-incumbent-retained-v1",
    output_bundle_target = "outputs/competition/uefa_nations_league_2026_27",
    active_output_bundle_id = "nl-output-v1"
  )
  expect_silent(phase13_validate_lifecycle_transition("pre_draw", "scheduled"))
  expect_error(phase13_validate_lifecycle_transition("pre_draw", "in_progress"), "forward|one state")
  blocked <- phase13_block_competition_edition(row, "missing standings resource", "2026-08-13T18:00:00Z", "operator")
  expect_true(blocked$blocked)
  expect_identical(blocked$active_output_bundle_id, "nl-output-v1")
  expect_identical(blocked$last_accepted_output_bundle_id, "nl-output-v1")
  expect_error(
    phase13_transition_competition_edition(blocked, "scheduled"),
    "operator action|validation"
  )
  recovered <- phase13_transition_competition_edition(
    blocked, "scheduled", operator_action = "verified replacement bundle", validation_passed = TRUE
  )
  expect_false(recovered$blocked)
  expect_identical(recovered$active_output_bundle_id, "nl-output-v1")
  other <- row
  other$edition_id <- "uefa_euro_2028_qualifying"
  other$competition_id <- "uefa_euro_2028_qualifying"
  other$display_name <- "UEFA EURO 2028 qualifying"
  other$row_sha256 <- phase13_registry_row_hash(other)
  expect_identical(
    phase13_competition_registry_hash(rbind(row, other)),
    phase13_competition_registry_hash(rbind(other, row))
  )
})

test_that("team identity registry carries provenance and order-stable row hashes", {
  phase13_registry_test_load_apis()
  phase13_registry_test_require_api(c(
    "phase13_team_identity_registry_required_columns",
    "load_phase13_team_identity_registry",
    "validate_phase13_team_identity_registry",
    "phase13_team_identity_registry_hash"
  ))

  registry <- load_phase13_team_identity_registry(
    file.path(phase13_registry_test_project_root, "data/competition/registries/team_identity.csv")
  )
  expect_true(all(phase13_team_identity_registry_required_columns() %in% names(registry)))
  expect_silent(validate_phase13_team_identity_registry(registry))
  expect_identical(
    phase13_team_identity_registry_hash(registry),
    phase13_team_identity_registry_hash(registry[rev(seq_len(nrow(registry))), , drop = FALSE])
  )

  fixture <- phase13_registry_test_fixture()
  identity_map <- phase13_prepare_team_identity_map(phase13_registry_test_identity_map(fixture))
  resolved <- phase13_resolve_team_identity(identity_map, "101", "Germany")
  expect_true(all(c("aliases", "source_bundle_id", "row_sha256") %in% names(resolved)))
  expect_identical(resolved$mapping_method, "source_id")
  expect_true(grepl("^[0-9a-f]{64}$", resolved$row_sha256))
})

test_that("default identity loading requires adjacent accepted source-bundle provenance", {
  phase13_registry_test_load_apis()
  phase13_registry_test_require_api(c("load_phase13_team_identity_registry", "phase13_row_sha256"))
  sandbox <- phase13_registry_test_copy_normalized_sandbox()
  on.exit(unlink(sandbox$root, recursive = TRUE, force = TRUE), add = TRUE)
  identity_path <- file.path(sandbox$registry_root, "team_identity.csv")
  expect_silent(load_phase13_team_identity_registry(identity_path))

  identity <- utils::read.csv(identity_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  identity$source_bundle_id[[1L]] <- "forged-source-bundle"
  identity$row_sha256 <- phase13_row_sha256(identity)
  phase13_registry_test_write_csv(identity, identity_path)
  expect_error(
    load_phase13_team_identity_registry(identity_path),
    "non-accepted source bundle"
  )
})

test_that("default identity loading rejects missing or non-accepted adjacent source bundles", {
  phase13_registry_test_load_apis()
  phase13_registry_test_require_api(c("load_phase13_team_identity_registry", "phase13_row_sha256"))
  missing_sandbox <- phase13_registry_test_copy_normalized_sandbox()
  on.exit(unlink(missing_sandbox$root, recursive = TRUE, force = TRUE), add = TRUE)
  identity_path <- file.path(missing_sandbox$registry_root, "team_identity.csv")
  file.remove(file.path(missing_sandbox$registry_root, "source_bundles.csv"))
  expect_error(
    load_phase13_team_identity_registry(identity_path),
    "adjacent source bundle registry file is missing"
  )

  rejected_sandbox <- phase13_registry_test_copy_normalized_sandbox()
  on.exit(unlink(rejected_sandbox$root, recursive = TRUE, force = TRUE), add = TRUE)
  rejected_path <- file.path(rejected_sandbox$registry_root, "source_bundles.csv")
  bundles <- utils::read.csv(rejected_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  identity <- utils::read.csv(
    file.path(rejected_sandbox$registry_root, "team_identity.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
  bundle_id <- as.character(identity$source_bundle_id[[1L]])
  bundles$bundle_status[as.character(bundles$bundle_id) == bundle_id] <- "candidate"
  bundles$row_sha256 <- phase13_row_sha256(bundles)
  phase13_registry_test_write_csv(bundles, rejected_path)
  expect_error(
    load_phase13_team_identity_registry(
      file.path(rejected_sandbox$registry_root, "team_identity.csv")
    ),
    "non-accepted source bundle"
  )
})

test_that("identity validation rejects duplicate FIFA codes and strict non-pre-draw empties", {
  phase13_registry_test_load_apis()
  phase13_registry_test_require_api(c(
    "phase13_prepare_team_identity_map",
    "phase13_normalize_fixture_rows",
    "validate_phase13_team_identity_registry"
  ))
  fixture <- phase13_registry_test_fixture()
  identity_map <- phase13_registry_test_identity_map(fixture)
  duplicate_fifa <- identity_map
  duplicate_fifa$fifa_code[[2L]] <- duplicate_fifa$fifa_code[[1L]]
  expect_error(phase13_prepare_team_identity_map(duplicate_fifa), "FIFA")

  empty_identity_map <- identity_map[0, , drop = FALSE]
  source_fixture <- fixture$resources$fixtures[[1L]]
  source_rows <- data.frame(
    source_fixture_id = source_fixture$source_fixture_id,
    home_uefa_source_team_id = source_fixture$home$uefa_source_team_id,
    away_uefa_source_team_id = source_fixture$away$uefa_source_team_id,
    home_display_name = source_fixture$home$display_name,
    away_display_name = source_fixture$away$display_name,
    scheduled_at_utc = source_fixture$scheduled_at_utc,
    status = source_fixture$status,
    stringsAsFactors = FALSE
  )
  expect_error(
    phase13_normalize_fixture_rows(
      data.frame(source_rows[0, , drop = FALSE]), empty_identity_map,
      fixture$edition_id, lifecycle_state = "scheduled"
    ),
    "pre_draw|empty|identity"
  )
  expect_silent(
    phase13_normalize_fixture_rows(
      source_rows[0, , drop = FALSE], empty_identity_map,
      "uefa_euro_2028_qualifying", lifecycle_state = "pre_draw"
    )
  )
})

test_that("competition edition CSV is a checked two-edition release registry", {
  phase13_registry_test_load_apis()
  phase13_registry_test_require_api(c(
    "load_competition_edition_registries",
    "validate_competition_edition_registries",
    "phase13_competition_edition_required_columns"
  ))
  registries <- load_competition_edition_registries(
    file.path(phase13_registry_test_project_root, "data/competition/registries")
  )
  expect_identical(
    sort(as.character(registries$edition_id)),
    sort(c("uefa_nations_league_2026_27", "uefa_euro_2028_qualifying"))
  )
  expect_true(all(c("audit_at_utc", "source_edition_id", "official_draw_date") %in% names(registries)))
  expect_silent(validate_competition_edition_registries(registries))
  euro <- registries[registries$edition_id == "uefa_euro_2028_qualifying", , drop = FALSE]
  expect_identical(euro$lifecycle_state, "pre_draw")
  expect_identical(euro$official_draw_date, "2026-12-06")
  expect_identical(euro$active_output_bundle_id, "uefa_euro_2028_qualifying-official-v1")
  expect_true(!any(c("group_count", "fixture_count", "standings_hash", "probability_hash") %in% names(euro)))
})

test_that("production loading returns normalized accepted snapshots and truthful EURO pre-draw state", {
  phase13_registry_test_load_apis()
  phase13_registry_test_require_api(c("load_competition_edition_registries", "phase13_normalized_fixture_schema", "phase13_normalized_result_schema"))
  registries <- load_competition_edition_registries(
    file.path(phase13_registry_test_project_root, "data/competition/registries")
  )
  snapshots <- registries$accepted_snapshots
  expect_true(setequal(names(snapshots), c("uefa_nations_league_2026_27", "uefa_euro_2028_qualifying")))

  nations <- snapshots[["uefa_nations_league_2026_27"]]
  expect_named(nations$fixtures, phase13_normalized_fixture_schema())
  expect_named(nations$results, phase13_normalized_result_schema())
  expect_true(all(c("home_team_id", "away_team_id", "edition_id", "source_artifact_id") %in% names(nations$fixtures)))
  expect_true(all(c("home_team_id", "away_team_id", "edition_id", "fixture_source_artifact_id") %in% names(nations$results)))
  expect_true(all(nzchar(as.character(nations$fixtures$home_display_name))))
  expect_true(all(nzchar(as.character(nations$fixtures$away_display_name))))
  expect_identical(
    as.character(nations$results$fixture_source_artifact_id),
    as.character(nations$fixtures$source_artifact_id)
  )
  expect_identical(as.character(nations$status$competition_status), "scheduled")

  euro <- snapshots[["uefa_euro_2028_qualifying"]]
  expect_named(euro$fixtures, phase13_normalized_fixture_schema())
  expect_named(euro$results, phase13_normalized_result_schema())
  expect_equal(nrow(euro$fixtures), 0L)
  expect_equal(nrow(euro$groups), 0L)
  expect_equal(nrow(euro$standings), 0L)
  expect_equal(nrow(euro$results), 0L)
  expect_identical(as.character(euro$status$competition_status), "pre_draw")
})

test_that("bundle canonical content hashes include the derived artifact hash fields", {
  phase13_registry_test_load_apis()
  source(file.path(phase13_registry_test_project_root, "R/competition/publication_hashes.R"), local = .GlobalEnv)
  source(file.path(phase13_registry_test_project_root, "R/competition/publication_manifests.R"), local = .GlobalEnv)
  artifacts <- utils::read.csv(
    file.path(phase13_registry_test_project_root, "data/competition/registries/source_artifacts.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
  bundle <- utils::read.csv(
    file.path(phase13_registry_test_project_root, "data/competition/registries/source_bundles.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
  rebuilt <- phase13_publication_manifest_build_bundle(
    bundle[bundle$edition_id == "uefa_nations_league_2026_27", , drop = FALSE],
    artifacts[artifacts$edition_id == "uefa_nations_league_2026_27", , drop = FALSE]
  )
  expect_identical(
    as.character(rebuilt$canonical_content_sha256[[1L]]),
    as.character(phase13_publication_manifest_content_hash(
      rebuilt,
      artifacts[artifacts$edition_id == "uefa_nations_league_2026_27", , drop = FALSE]
    ))
  )
})

test_that("temporary accepted snapshot copies fail closed on a missing edition directory", {
  phase13_registry_test_load_apis()
  phase13_registry_test_require_api("load_competition_edition_registries")
  sandbox <- phase13_registry_test_copy_normalized_sandbox()
  on.exit(unlink(sandbox$root, recursive = TRUE, force = TRUE), add = TRUE)
  unlink(file.path(sandbox$accepted_root, "uefa_euro_2028_qualifying"), recursive = TRUE, force = TRUE)
  expect_error(
    phase13_registry_test_load_sandbox(sandbox),
    "accepted snapshot directory is missing"
  )
})

test_that("temporary accepted table tampering fails before downstream loading", {
  phase13_registry_test_load_apis()
  phase13_registry_test_require_api(c("load_competition_edition_registries", "phase13_row_sha256"))
  sandbox <- phase13_registry_test_copy_normalized_sandbox()
  on.exit(unlink(sandbox$root, recursive = TRUE, force = TRUE), add = TRUE)
  fixture_path <- file.path(sandbox$accepted_root, "uefa_nations_league_2026_27", "fixtures.csv")
  fixtures <- utils::read.csv(fixture_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  fixtures$scheduled_at_utc[[1L]] <- "2026-09-05T19:00:00Z"
  phase13_registry_test_write_csv(fixtures, fixture_path)
  expect_error(
    phase13_registry_test_load_sandbox(sandbox),
    "row SHA-256 mismatch"
  )
})

test_that("recomputed row hashes cannot conceal stale accepted canonical content", {
  phase13_registry_test_load_apis()
  phase13_registry_test_require_api(c("load_competition_edition_registries", "phase13_row_sha256"))
  sandbox <- phase13_registry_test_copy_normalized_sandbox()
  on.exit(unlink(sandbox$root, recursive = TRUE, force = TRUE), add = TRUE)
  fixture_path <- file.path(sandbox$accepted_root, "uefa_nations_league_2026_27", "fixtures.csv")
  fixtures <- utils::read.csv(fixture_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  fixtures$scheduled_at_utc[[1L]] <- "2026-09-05T19:00:00Z"
  fixtures$row_sha256 <- phase13_row_sha256(fixtures)
  phase13_registry_test_write_csv(fixtures, fixture_path)
  expect_error(
    phase13_registry_test_load_sandbox(sandbox),
    "canonical content hash mismatch"
  )
})

test_that("recomputed manifest row hashes cannot forge accepted artifact links", {
  phase13_registry_test_load_apis()
  phase13_registry_test_require_api(c("load_competition_edition_registries", "phase13_row_sha256"))
  sandbox <- phase13_registry_test_copy_normalized_sandbox()
  on.exit(unlink(sandbox$root, recursive = TRUE, force = TRUE), add = TRUE)
  manifest_path <- file.path(
    sandbox$accepted_root,
    "uefa_nations_league_2026_27",
    "source_bundle_manifest.csv"
  )
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
  manifest$artifact_id[[1L]] <- "forged-artifact"
  manifest$row_sha256 <- phase13_row_sha256(manifest)
  phase13_registry_test_write_csv(manifest, manifest_path)
  expect_error(
    phase13_registry_test_load_sandbox(sandbox),
    "unknown artifact|artifact link"
  )
})

test_that("edition validation preflights the approved release and handles serialized blocked overlays", {
  phase13_registry_test_load_apis()
  phase13_registry_test_require_api(c(
    "phase13_preflight_approved_model_release",
    "phase13_build_competition_edition_row",
    "phase13_transition_competition_edition"
  ))
  preflight <- phase13_preflight_approved_model_release(
    file.path(phase13_registry_test_project_root, "outputs/releases")
  )
  expect_identical(preflight$metadata$release_id, "phase12-wc2026-incumbent-retained-v1")

  row <- phase13_build_competition_edition_row(
    edition_id = "uefa_nations_league_2026_27",
    competition_id = "uefa_nations_league",
    display_name = "UEFA Nations League 2026/27",
    lifecycle_state = "pre_draw",
    ruleset_version = "uefa-nations-league-2026-27-v1",
    source_bundle_id = "nl-2026-27-official-sample-v1",
    model_release_id = "phase12-wc2026-incumbent-retained-v1",
    output_bundle_target = "outputs/competition/uefa_nations_league_2026_27"
  )
  blocked <- phase13_block_competition_edition(row, "refresh failed", "2026-08-13T18:00:00Z", "operator")
  serialized <- blocked
  serialized$blocked <- "TRUE"
  expect_error(
    phase13_transition_competition_edition(serialized, "scheduled"),
    "operator action|validation"
  )
})

test_that("edition validation rejects forged release pins and null release slots", {
  phase13_registry_test_load_apis()
  phase13_registry_test_require_api(c(
    "load_competition_edition_registries",
    "validate_competition_edition_registries",
    "phase13_registry_row_hash"
  ))
  registries <- load_competition_edition_registries(
    file.path(phase13_registry_test_project_root, "data/competition/registries")
  )
  source_bundles <- attr(registries, "source_bundles")

  forged <- registries
  forged$model_release_id[[1L]] <- "forged-release"
  forged$row_sha256 <- phase13_registry_row_hash(forged)
  expect_error(
    validate_competition_edition_registries(forged, source_bundles = source_bundles),
    "model release|approved|Phase 12"
  )

  missing_output <- registries
  missing_output$output_bundle_target[[1L]] <- ""
  missing_output$row_sha256 <- phase13_registry_row_hash(missing_output)
  expect_error(
    validate_competition_edition_registries(missing_output, source_bundles = source_bundles),
    "empty required field|output"
  )
})

test_that("martj42 history identity and edition contracts survive append, reorder, and score-only changes", {
  phase13_registry_test_load_apis()
  phase13_registry_test_require_api(c(
    "phase13_generate_martj42_identity_map",
    "phase13_normalize_historical_result_rows",
    "phase13_martj42_edition_lookup_hash",
    "phase13_identity_row_hash"
  ))
  history <- utils::read.csv(
    file.path(phase13_registry_test_project_root, "tests/fixtures/phase13/martj42_history_sample.csv"),
    stringsAsFactors = FALSE, check.names = FALSE, na.strings = ""
  )
  registry <- utils::read.csv(
    file.path(phase13_registry_test_project_root, "data/competition/registries/team_identity.csv"),
    stringsAsFactors = FALSE, check.names = FALSE, na.strings = ""
  )
  edition_lookup <- utils::read.csv(
    file.path(phase13_registry_test_project_root, "tests/fixtures/phase13/martj42_history_edition_map.csv"),
    stringsAsFactors = FALSE, check.names = FALSE, na.strings = ""
  )
  identity_map <- phase13_generate_martj42_identity_map(
    history, registry, "martj42", "martj42-fixture-v1", strrep("a", 64),
    "martj42-results-fixture-v1"
  )
  baseline <- phase13_normalize_historical_result_rows(history, identity_map, edition_lookup)

  rehash_lookup <- function(lookup) {
    lookup$edition_lookup_sha256 <- ""
    lookup$row_sha256 <- ""
    lookup$edition_lookup_sha256 <- phase13_martj42_edition_lookup_hash(lookup)
    lookup$row_sha256 <- phase13_identity_row_hash(lookup)
    lookup
  }
  future_history <- history[3L, , drop = FALSE]
  future_history$match_id <- "martj42-0004"
  future_history$date <- "2027-05-10"
  future_history$home_score <- 3
  future_history$away_score <- 2
  future_history$tournament <- "Friendly"
  future_lookup <- edition_lookup[3L, , drop = FALSE]
  future_lookup$match_id <- future_history$match_id
  expanded_history <- rbind(history, future_history)
  expanded_lookup <- rehash_lookup(rbind(edition_lookup, future_lookup))
  expanded <- phase13_normalize_historical_result_rows(expanded_history, identity_map, expanded_lookup)
  reordered <- phase13_normalize_historical_result_rows(
    expanded_history[c(4L, 2L, 1L, 3L), , drop = FALSE],
    identity_map,
    expanded_lookup[c(4L, 2L, 1L, 3L), , drop = FALSE]
  )
  perturbed_history <- expanded_history
  perturbed_history$home_score[4L] <- 7
  perturbed_history$away_score[4L] <- 6
  perturbed <- phase13_normalize_historical_result_rows(perturbed_history, identity_map, expanded_lookup)

  stable_fields <- setdiff(
    phase13_normalized_historical_result_schema(),
    c("home_score", "away_score", "edition_lookup_sha256", "edition_lookup_row_sha256", "row_sha256")
  )
  baseline_stable <- baseline[order(baseline$source_result_id), stable_fields, drop = FALSE]
  expanded_stable <- expanded[expanded$source_result_id %in% baseline$source_result_id, stable_fields, drop = FALSE]
  reordered_stable <- reordered[reordered$source_result_id %in% baseline$source_result_id, stable_fields, drop = FALSE]
  perturbed_stable <- perturbed[perturbed$source_result_id %in% baseline$source_result_id, stable_fields, drop = FALSE]
  expanded_stable <- expanded_stable[order(expanded_stable$source_result_id), , drop = FALSE]
  reordered_stable <- reordered_stable[order(reordered_stable$source_result_id), , drop = FALSE]
  perturbed_stable <- perturbed_stable[order(perturbed_stable$source_result_id), , drop = FALSE]
  rownames(baseline_stable) <- NULL
  rownames(expanded_stable) <- NULL
  rownames(reordered_stable) <- NULL
  rownames(perturbed_stable) <- NULL
  expect_identical(baseline_stable, expanded_stable)
  expect_identical(baseline_stable, reordered_stable)
  expect_identical(baseline_stable, perturbed_stable)
  perturbed_future_scores <- perturbed[perturbed$source_result_id == "martj42-0004", c("home_score", "away_score"), drop = FALSE]
  rownames(perturbed_future_scores) <- NULL
  expect_identical(perturbed_future_scores, data.frame(home_score = 7, away_score = 6))

  score_only_history <- history
  score_only_history$home_score[1L] <- 4
  score_only_history$away_score[1L] <- 3
  score_only <- phase13_normalize_historical_result_rows(score_only_history, identity_map, edition_lookup)
  score_fields <- setdiff(phase13_normalized_historical_result_schema(), c("home_score", "away_score", "row_sha256"))
  score_identity <- score_only[1L, score_fields, drop = FALSE]
  baseline_identity <- baseline[1L, score_fields, drop = FALSE]
  rownames(score_identity) <- NULL
  rownames(baseline_identity) <- NULL
  expect_identical(score_identity, baseline_identity)
  expect_identical(score_only[1L, c("home_score", "away_score")], data.frame(home_score = 4, away_score = 3))
  expect_false(identical(score_only$row_sha256[[1L]], baseline$row_sha256[[1L]]))

  identity_changed <- history
  identity_changed$home_team[1L] <- "Germany"
  expect_error(
    phase13_normalize_historical_result_rows(identity_changed, identity_map, edition_lookup),
    "identity map|unresolved|coverage"
  )
  edition_changed <- edition_lookup
  edition_changed$edition_id[1L] <- "martj42_historical_v2"
  expect_error(
    phase13_normalize_historical_result_rows(history, identity_map, edition_changed),
    "canonical hash mismatch|row SHA-256 mismatch"
  )
})

test_that("martj42 identity-map malformed, unresolved, duplicate, conflicting, and ambiguous cases fail closed", {
  phase13_registry_test_load_apis()
  phase13_registry_test_require_api(c(
    "phase13_generate_martj42_identity_map",
    "phase13_validate_martj42_identity_map",
    "phase13_validate_martj42_identity_coverage"
  ))
  history <- utils::read.csv(
    file.path(phase13_registry_test_project_root, "tests/fixtures/phase13/martj42_history_sample.csv"),
    stringsAsFactors = FALSE, check.names = FALSE, na.strings = ""
  )
  registry <- utils::read.csv(
    file.path(phase13_registry_test_project_root, "data/competition/registries/team_identity.csv"),
    stringsAsFactors = FALSE, check.names = FALSE, na.strings = ""
  )
  cases <- utils::read.csv(
    file.path(phase13_registry_test_project_root, "tests/fixtures/phase13/martj42_identity_map_cases.csv"),
    stringsAsFactors = FALSE, check.names = FALSE, na.strings = ""
  )
  identity_map <- phase13_generate_martj42_identity_map(
    history, registry, "martj42", "martj42-fixture-v1", strrep("a", 64),
    "martj42-results-fixture-v1"
  )
  expect_equal(
    sort(unique(cases$case_type)),
    sort(c("missing_provenance", "duplicate_source_identity", "conflicting_mapping", "unresolved_identity", "ambiguous_alias"))
  )

  provenance_cases <- cases[cases$case_type == "missing_provenance", , drop = FALSE]
  for (index in seq_len(nrow(provenance_cases))) {
    broken <- identity_map
    field <- switch(
      provenance_cases$case_id[[index]],
      "missing-source-version" = "source_version",
      "missing-source-input-hash" = "source_input_sha256",
      "missing-source-artifact" = "source_artifact_id"
    )
    broken[[field]][1L] <- NA_character_
    expect_error(phase13_validate_martj42_identity_map(broken), "metadata|provenance|SHA-256")
  }

  duplicate <- rbind(identity_map, identity_map[1L, , drop = FALSE])
  expect_error(phase13_validate_martj42_identity_map(duplicate), "duplicate source identity")
  conflicting <- identity_map
  conflicting$team_id[1L] <- "team_forged"
  conflicting <- rbind(identity_map, conflicting[1L, , drop = FALSE])
  expect_error(phase13_validate_martj42_identity_map(conflicting), "conflicting mapping")

  unresolved_history <- history
  unresolved_history$home_team[1L] <- "Unknownland"
  unresolved_history$home_source_team_id[1L] <- NA_character_
  expect_error(
    phase13_validate_martj42_identity_coverage(unresolved_history, identity_map),
    "unresolved|unexpected source identities"
  )

  ambiguous_registry <- rbind(registry[1L, , drop = FALSE], registry[1L, , drop = FALSE])
  ambiguous_registry$team_id <- c("team_civ_a", "team_civ_b")
  ambiguous_registry$fifa_code <- c("CVA", "CVB")
  ambiguous_registry$canonical_name <- c("Cote d Ivoire", "Cote d Ivoire")
  ambiguous_registry$aliases <- c("Cote d Ivoire", "Cote d Ivoire")
  ambiguous_registry$uefa_source_team_id <- c("102", "103")
  ambiguous_registry$uefa_display_name_current <- c("Cote d Ivoire", "Cote d Ivoire")
  expect_error(
    phase13_generate_martj42_identity_map(
      history, ambiguous_registry, "martj42", "martj42-fixture-v1", strrep("a", 64),
      "martj42-results-fixture-v1"
    ),
    "ambiguous normalized aliases"
  )
})
