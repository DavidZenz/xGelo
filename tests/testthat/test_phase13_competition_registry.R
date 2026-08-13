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
