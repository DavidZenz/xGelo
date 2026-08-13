library(testthat)

phase13_source_test_project_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase13_source_test_load_apis <- function() {
  source_path <- file.path(phase13_source_test_project_root, "R/competition/source_contracts.R")
  if (file.exists(source_path)) source(source_path, local = .GlobalEnv)
  invisible(TRUE)
}

phase13_source_test_require_api <- function(required) {
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop(
      paste0(
        "Wave 0 RED contract awaits Phase 13 source API: ",
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

phase13_source_test_fixture <- function() {
  jsonlite::fromJSON(
    file.path(
      phase13_source_test_project_root,
      "tests/fixtures/phase13/uefa_nations_league_sample.json"
    ),
    simplifyVector = FALSE
  )
}

phase13_source_test_identity_map <- function(fixture) {
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

phase13_source_test_fixture_rows <- function(fixture) {
  row <- fixture$resources$fixtures[[1L]]
  data.frame(
    source_fixture_id = row$source_fixture_id,
    home_uefa_source_team_id = row$home$uefa_source_team_id,
    away_uefa_source_team_id = row$away$uefa_source_team_id,
    home_display_name = row$home$display_name,
    away_display_name = row$away$display_name,
    scheduled_at_utc = row$scheduled_at_utc,
    status = row$status,
    stringsAsFactors = FALSE
  )
}

test_that("Wave 0 exposes the source-contract API seam", {
  phase13_source_test_load_apis()
  phase13_source_test_require_api(c(
    "phase13_capture_structured_bundle",
    "phase13_build_source_artifact",
    "phase13_validate_source_bundle",
    "phase13_parser_commit_sha",
    "phase13_canonical_sha256"
  ))
})

test_that("compact structured fixture produces complete artifact provenance and an accepted bundle", {
  phase13_source_test_load_apis()
  phase13_source_test_require_api(c("phase13_capture_structured_bundle"))
  fixture <- phase13_source_test_fixture()

  captured <- phase13_capture_structured_bundle(
    resource_payloads = fixture$resources,
    edition_id = fixture$edition_id,
    bundle_id = "nl-2026-27-official-sample-v1",
    source_urls = unlist(fixture$source_urls, use.names = TRUE),
    retrieved_at_utc = fixture$retrieved_at_utc,
    fallback_status = "official",
    project_root = phase13_source_test_project_root
  )

  expect_silent(phase13_validate_source_bundle(captured$bundle, captured$artifacts))
  expect_identical(captured$bundle$bundle_status, "accepted")
  expect_setequal(captured$artifacts$artifact_type, names(fixture$resources))
  expect_true(all(c("source_url", "retrieved_at_utc", "bytes", "raw_sha256", "parser_commit_sha", "fallback_status") %in% names(captured$artifacts)))
  expect_true(all(captured$artifacts$bytes > 0L))
  expect_true(all(grepl("^[0-9a-f]{64}$", captured$artifacts$raw_sha256)))
  expect_true(all(captured$artifacts$parser_commit_sha == phase13_parser_commit_sha(phase13_source_test_project_root)))
  expect_true(grepl("^[0-9a-f]{64}$", captured$bundle$source_bundle_sha256))
})

test_that("accepted bundle rejects a missing required structured resource class", {
  phase13_source_test_load_apis()
  phase13_source_test_require_api(c("phase13_capture_structured_bundle"))
  fixture <- phase13_source_test_fixture()
  incomplete <- fixture$resources
  incomplete$groups <- NULL

  expect_error(
    phase13_capture_structured_bundle(
      resource_payloads = incomplete,
      edition_id = fixture$edition_id,
      bundle_id = "nl-2026-27-incomplete-v1",
      source_urls = unlist(fixture$source_urls, use.names = TRUE),
      retrieved_at_utc = fixture$retrieved_at_utc,
      fallback_status = "official",
      project_root = phase13_source_test_project_root
    ),
    "required resource|incomplete"
  )
})
