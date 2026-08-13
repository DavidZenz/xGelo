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
  phase13_registry_test_require_api(c("phase13_empty_normalized_fixture_rows", "phase13_normalize_fixture_rows"))
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
