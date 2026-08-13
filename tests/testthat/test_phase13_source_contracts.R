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

phase13_source_test_rehash <- function(data) {
  data$row_sha256 <- phase13_row_sha256(data)
  data
}

phase13_source_test_raw_bytes <- function(fixture) {
  payloads <- fixture$resources
  setNames(
    lapply(payloads, function(payload) jsonlite::toJSON(payload, auto_unbox = TRUE, pretty = FALSE, null = "null", digits = 17)),
    paste("nl-2026-27-official-sample-v1", names(payloads), sep = "-")
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
  expect_true(TRUE)
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

test_that("Wave 0 edge gates name the owned schema, fallback, and raw-byte validators", {
  phase13_source_test_load_apis()
  phase13_source_test_require_api(c(
    "phase13_validate_structured_resource_names",
    "phase13_validate_fallback_review_metadata",
    "phase13_validate_source_artifacts"
  ))
  expect_true(TRUE)
})

test_that("structured resource schema drift rejects unknown resource classes", {
  phase13_source_test_load_apis()
  phase13_source_test_require_api(c("phase13_validate_structured_resource_names"))
  fixture <- phase13_source_test_fixture()
  expect_error(
    phase13_validate_structured_resource_names(c(names(fixture$resources), "metadata")),
    "unknown|schema|resource"
  )
  expect_error(
    phase13_validate_structured_resource_names(setdiff(names(fixture$resources), "status")),
    "missing|required|resource"
  )
})

test_that("artifact provenance and exact raw-byte hashes fail closed", {
  phase13_source_test_load_apis()
  phase13_source_test_require_api(c("phase13_capture_structured_bundle", "phase13_validate_source_artifacts"))
  fixture <- phase13_source_test_fixture()
  captured <- phase13_capture_structured_bundle(
    resource_payloads = fixture$resources,
    edition_id = fixture$edition_id,
    bundle_id = "nl-2026-27-official-sample-v1",
    source_urls = unlist(fixture$source_urls, use.names = TRUE),
    retrieved_at_utc = fixture$retrieved_at_utc,
    project_root = phase13_source_test_project_root
  )
  expect_silent(phase13_validate_source_artifacts(captured$artifacts, phase13_source_test_raw_bytes(fixture)))

  missing_provenance <- captured$artifacts
  missing_provenance$source_url[[1L]] <- NA_character_
  expect_error(phase13_validate_source_artifacts(missing_provenance), "provenance|source_url")

  tampered <- phase13_source_test_raw_bytes(fixture)
  tampered[[1L]] <- charToRaw("tampered structured response")
  expect_error(
    phase13_validate_source_artifacts(captured$artifacts, tampered),
    "hash|byte"
  )
})

test_that("fallback review metadata is complete, edition-wide, and order-stable", {
  phase13_source_test_load_apis()
  phase13_source_test_require_api(c(
    "phase13_capture_structured_bundle",
    "phase13_build_source_bundle",
    "phase13_validate_fallback_review_metadata",
    "phase13_validate_source_bundle"
  ))
  fixture <- phase13_source_test_fixture()
  captured <- phase13_capture_structured_bundle(
    resource_payloads = fixture$resources,
    edition_id = fixture$edition_id,
    bundle_id = "nl-2026-27-fallback-sample-v1",
    source_urls = unlist(fixture$source_urls, use.names = TRUE),
    retrieved_at_utc = fixture$retrieved_at_utc,
    project_root = phase13_source_test_project_root
  )
  fallback_artifacts <- captured$artifacts
  fallback_artifacts$fallback_status <- "reviewed_fallback"
  fallback_artifacts$review_state <- "approved"
  fallback_artifacts <- phase13_source_test_rehash(fallback_artifacts)
  incomplete <- phase13_build_source_bundle(
    bundle_id = "nl-2026-27-fallback-sample-v1",
    edition_id = fixture$edition_id,
    artifacts = fallback_artifacts,
    fallback_status = "reviewed_fallback",
    parser_commit_sha = phase13_parser_commit_sha(phase13_source_test_project_root),
    accepted_at_utc = fixture$retrieved_at_utc
  )
  expect_error(
    phase13_validate_fallback_review_metadata(incomplete, fallback_artifacts),
    "review|metadata|fallback"
  )
  expect_error(
    phase13_validate_source_bundle(incomplete, fallback_artifacts),
    "review|metadata|fallback"
  )

  fallback <- jsonlite::fromJSON(
    file.path(phase13_source_test_project_root, "tests/fixtures/phase13/reviewed_fallback_bundle.json"),
    simplifyVector = TRUE
  )
  accepted <- phase13_build_source_bundle(
    bundle_id = "nl-2026-27-fallback-sample-v1",
    edition_id = fixture$edition_id,
    artifacts = fallback_artifacts,
    fallback_status = fallback$fallback_status,
    parser_commit_sha = phase13_parser_commit_sha(phase13_source_test_project_root),
    accepted_at_utc = fixture$retrieved_at_utc,
    acceptance_state = "reviewed",
    fallback_source = fallback$fallback_source,
    fallback_retrieval_date = fallback$fallback_retrieval_date,
    fallback_reason = fallback$fallback_reason,
    operator_note = fallback$operator_note,
    fallback_checksum = phase13_source_sha256(fallback$operator_note)
  )
  expect_silent(phase13_validate_fallback_review_metadata(accepted, fallback_artifacts))
  expect_silent(phase13_validate_source_bundle(accepted, fallback_artifacts))
  reordered <- fallback_artifacts[rev(seq_len(nrow(fallback_artifacts))), , drop = FALSE]
  expect_identical(accepted$source_bundle_sha256, phase13_canonical_sha256(reordered, key = "artifact_id"))
  expect_error(
    phase13_build_source_bundle(
      bundle_id = "nl-2026-27-mixed-v1",
      edition_id = fixture$edition_id,
      artifacts = rbind(captured$artifacts[1L, , drop = FALSE], fallback_artifacts[-1L, , drop = FALSE]),
      fallback_status = "official"
    ),
    "mix|fallback"
  )
})

test_that("empty artifact input and the local raw-store publication boundary are explicit", {
  phase13_source_test_load_apis()
  phase13_source_test_require_api(c("phase13_validate_source_artifacts"))
  fixture <- phase13_source_test_fixture()
  captured <- phase13_capture_structured_bundle(
    resource_payloads = fixture$resources,
    edition_id = fixture$edition_id,
    bundle_id = "nl-2026-27-official-sample-v1",
    source_urls = unlist(fixture$source_urls, use.names = TRUE),
    retrieved_at_utc = fixture$retrieved_at_utc,
    project_root = phase13_source_test_project_root
  )
  expect_error(phase13_validate_source_artifacts(captured$artifacts[0, , drop = FALSE]), "empty|must not")
  tracked <- system("git ls-files data/competition/local_raw", intern = TRUE)
  expect_length(tracked, 0L)
})

test_that("all five structured resource classes have explicit source-shaped schemas", {
  phase13_source_test_load_apis()
  phase13_source_test_require_api(c(
    "phase13_validate_structured_resource_payloads",
    "phase13_source_resource_schema"
  ))
  fixture <- phase13_source_test_fixture()

  expect_silent(
    phase13_validate_structured_resource_payloads(
      fixture$resources,
      edition_id = fixture$edition_id
    )
  )
  expect_setequal(
    names(phase13_source_resource_schema()),
    c("fixtures", "groups", "standings", "results", "status")
  )

  drifted <- fixture$resources
  drifted$groups[[1L]]$display_name <- NULL
  expect_error(
    phase13_validate_structured_resource_payloads(
      drifted,
      edition_id = fixture$edition_id
    ),
    "schema|columns|groups"
  )
})

test_that("artifact validation rejects malformed provenance and unsafe raw metadata", {
  phase13_source_test_load_apis()
  phase13_source_test_require_api(c("phase13_capture_structured_bundle", "phase13_validate_source_artifacts"))
  fixture <- phase13_source_test_fixture()
  captured <- phase13_capture_structured_bundle(
    resource_payloads = fixture$resources,
    edition_id = fixture$edition_id,
    bundle_id = "nl-2026-27-provenance-v2",
    source_urls = unlist(fixture$source_urls, use.names = TRUE),
    retrieved_at_utc = fixture$retrieved_at_utc,
    project_root = phase13_source_test_project_root
  )

  malformed_hash <- captured$artifacts
  malformed_hash$raw_sha256[[1L]] <- "not-a-sha256"
  malformed_hash$row_sha256 <- phase13_row_sha256(malformed_hash)
  expect_error(phase13_validate_source_artifacts(malformed_hash), "SHA|hash")

  zero_bytes <- captured$artifacts
  zero_bytes$bytes[[1L]] <- 0L
  zero_bytes$row_sha256 <- phase13_row_sha256(zero_bytes)
  expect_error(phase13_validate_source_artifacts(zero_bytes), "byte|positive")

  unsafe_path <- captured$artifacts
  unsafe_path$relative_local_raw_path[[1L]] <- "../outside.json"
  unsafe_path$row_sha256 <- phase13_row_sha256(unsafe_path)
  expect_error(phase13_validate_source_artifacts(unsafe_path), "unsafe|root|raw")

  unsupported_status <- captured$artifacts
  unsupported_status$fallback_status[[1L]] <- "unreviewed"
  unsupported_status$row_sha256 <- phase13_row_sha256(unsupported_status)
  expect_error(phase13_validate_source_artifacts(unsupported_status), "fallback|status")
})

test_that("source manifests and registry rows use canonical order-stable hashes", {
  phase13_source_test_load_apis()
  phase13_source_test_require_api(c(
    "phase13_capture_structured_bundle",
    "phase13_source_manifest_self_sha256",
    "phase13_source_registry_tables",
    "phase13_source_write_csv"
  ))
  fixture <- phase13_source_test_fixture()
  captured <- phase13_capture_structured_bundle(
    resource_payloads = fixture$resources,
    edition_id = fixture$edition_id,
    bundle_id = "nl-2026-27-manifest-v2",
    source_urls = unlist(fixture$source_urls, use.names = TRUE),
    retrieved_at_utc = fixture$retrieved_at_utc,
    project_root = phase13_source_test_project_root
  )

  self_hash <- phase13_source_manifest_self_sha256(captured$bundle, captured$artifacts)
  reordered <- captured$artifacts[rev(seq_len(nrow(captured$artifacts))), , drop = FALSE]
  expect_identical(self_hash, phase13_source_manifest_self_sha256(captured$bundle, reordered))
  expect_match(self_hash, "^[0-9a-f]{64}$")

  registries <- phase13_source_registry_tables(captured$bundle, captured$artifacts)
  expect_setequal(names(registries), c("source_bundles", "source_artifacts"))
  expect_silent(phase13_validate_source_bundle(registries$source_bundles, registries$source_artifacts))

  output_root <- tempfile("phase13-registry-")
  expect_silent(phase13_source_write_csv(registries$source_bundles, file.path(output_root, "source_bundles.csv")))
  expect_true(file.exists(file.path(output_root, "source_bundles.csv")))
})

test_that("explicit empty compact tables retain schema while null schemas fail", {
  phase13_source_test_load_apis()
  phase13_source_test_require_api(c("phase13_validate_structured_resource_payloads"))
  empty_resources <- list(
    fixtures = data.frame(
      source_fixture_id = character(), scheduled_at_utc = character(), status = character(),
      home_uefa_source_team_id = character(), away_uefa_source_team_id = character(),
      home_display_name = character(), away_display_name = character(),
      stringsAsFactors = FALSE
    ),
    groups = data.frame(
      source_group_id = character(), league = character(), display_name = character(),
      stringsAsFactors = FALSE
    ),
    standings = data.frame(
      source_team_id = character(), source_group_id = character(), position = integer(), points = integer(),
      stringsAsFactors = FALSE
    ),
    results = data.frame(
      source_fixture_id = character(), status = character(), home_goals = integer(), away_goals = integer(),
      stringsAsFactors = FALSE
    ),
    status = data.frame(
      source_edition_id = character(), competition_status = character(),
      stringsAsFactors = FALSE
    )
  )
  expect_silent(
    phase13_validate_structured_resource_payloads(
      empty_resources,
      edition_id = "uefa_euro_2028_qualifying"
    )
  )
  expect_error(
    phase13_validate_structured_resource_payloads(
      lapply(empty_resources, function(value) list()),
      edition_id = "uefa_euro_2028_qualifying"
    ),
    "schema|columns|empty"
  )
})
