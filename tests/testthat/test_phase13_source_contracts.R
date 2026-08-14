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

phase13_source_test_derived_fixture <- function() {
  fixture <- phase13_source_test_fixture()
  fixture$source_urls$status <- NULL
  for (artifact_type in c("fixtures", "results")) {
    fixture$resources[[artifact_type]][[1L]]$source_edition_id <- fixture$source_edition_id
    fixture$resources[[artifact_type]][[1L]]$competition_status <- "scheduled"
  }
  fixture
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

test_that("committed source registries validate after the ignored raw store exists", {
  phase13_source_test_load_apis()
  phase13_source_test_require_api(c("phase13_validate_source_bundle"))
  bundle_path <- file.path(phase13_source_test_project_root, "data/competition/registries/source_bundles.csv")
  artifact_path <- file.path(phase13_source_test_project_root, "data/competition/registries/source_artifacts.csv")
  if (file.exists(bundle_path) && file.exists(artifact_path)) {
    bundles <- read.csv(bundle_path, stringsAsFactors = FALSE, check.names = FALSE)
    artifacts <- read.csv(artifact_path, stringsAsFactors = FALSE, check.names = FALSE)
    for (bundle_id in unique(bundles$bundle_id)) {
      expect_silent(
        phase13_validate_source_bundle(
          bundles[bundles$bundle_id == bundle_id, , drop = FALSE],
          artifacts[artifacts$bundle_id == bundle_id, , drop = FALSE]
        )
      )
    }
  }
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

phase13_source_test_run_acquire <- function(args) {
  script <- file.path(phase13_source_test_project_root, "scripts/acquire_uefa_snapshot.R")
  output <- system2(
    "Rscript",
    c("--vanilla", script, args),
    stdout = TRUE,
    stderr = TRUE
  )
  list(
    output = output,
    status = if (is.null(attr(output, "status"))) 0L else as.integer(attr(output, "status"))
  )
}

phase13_source_test_load_acquire <- function() {
  environment <- new.env(parent = globalenv())
  previous_directory <- getwd()
  setwd(phase13_source_test_project_root)
  on.exit(setwd(previous_directory), add = TRUE)
  sys.source(
    file.path(phase13_source_test_project_root, "scripts/acquire_uefa_snapshot.R"),
    envir = environment
  )
  environment
}

test_that("bounded live fetch retries transient responses through injectable httr2 callbacks", {
  acquire <- phase13_source_test_load_acquire()
  fixture <- phase13_source_test_fixture()
  requests <- list()
  performed <- 0L
  sleeps <- numeric()
  responses <- list(
    httr2::response_json(status_code = 503, body = list(error = "temporary")),
    httr2::response_json(body = fixture$resources$fixtures)
  )

  perform <- function(request) {
    performed <<- performed + 1L
    requests[[performed]] <<- request
    responses[[performed]]
  }

  fetched <- acquire$phase13_acquire_fetch_structured_url(
    url = "https://example.test/fixtures",
    artifact_type = "fixtures",
    request_fn = function(url) httr2::request(url),
    perform_fn = perform,
    clock_fn = function() 100,
    sleep_fn = function(seconds) sleeps <<- c(sleeps, seconds)
  )

  expect_equal(performed, 2L)
  expect_equal(fetched$source_url, "https://example.test/fixtures")
  expect_equal(fetched$payload[[1L]]$source_fixture_id, "nl-2026-0001")
  expect_identical(as.character(requests[[1L]]$headers$Accept), "application/json")
  expect_true(any(sleeps >= 1))
  expect_true(all(sleeps <= 8))
})

test_that("bounded live fetch caps transient retries and rejects non-JSON bodies", {
  acquire <- phase13_source_test_load_acquire()
  attempts <- 0L
  sleeps <- numeric()
  expect_error(
    acquire$phase13_acquire_fetch_structured_url(
      url = "https://example.test/fixtures",
      artifact_type = "fixtures",
      perform_fn = function(request) {
        attempts <<- attempts + 1L
        httr2::response_json(status_code = c(500L, 502L, 504L)[[attempts]], body = list(error = "temporary"))
      },
      clock_fn = function() 100,
      sleep_fn = function(seconds) sleeps <<- c(sleeps, seconds)
    ),
    "fixtures|status|attempt"
  )
  expect_equal(attempts, 3L)
  expect_true(length(sleeps) >= 2L)
  expect_true(all(sleeps <= 8))

  expect_error(
    acquire$phase13_acquire_fetch_structured_url(
      url = "https://example.test/fixtures",
      artifact_type = "fixtures",
      perform_fn = function(request) httr2::response(
        headers = list(`Content-Type` = "text/html"),
        body = charToRaw("<!doctype html><html></html>")
      ),
      sleep_fn = function(seconds) NULL
    ),
    "JSON|HTML|structured"
  )
})

test_that("live input derives status from validated mandatory resources without a status URL", {
  acquire <- phase13_source_test_load_acquire()
  fixture <- phase13_source_test_fixture()
  resources <- fixture$resources[c("fixtures", "groups", "standings", "results")]
  resources$fixtures[[1L]]$source_edition_id <- fixture$source_edition_id
  resources$fixtures[[1L]]$competition_status <- "scheduled"
  resources$results[[1L]]$source_edition_id <- fixture$source_edition_id
  resources$results[[1L]]$competition_status <- "scheduled"
  options <- setNames(
    as.list(c(
      "https://example.test/fixtures",
      "https://example.test/groups",
      "https://example.test/standings",
      "https://example.test/results"
    )),
    paste0(c("fixtures", "groups", "standings", "results"), "-url")
  )
  fetch <- function(url, artifact_type, ...) {
    payload <- resources[[artifact_type]]
    list(
      payload = payload,
      raw_bytes = jsonlite::toJSON(payload, auto_unbox = TRUE, pretty = FALSE, null = "null", digits = 17),
      source_url = url
    )
  }

  input <- acquire$phase13_acquire_live_input(
    options,
    fixture$edition_id,
    fetch_fn = fetch,
    sleep_fn = function(seconds) NULL
  )

  expect_setequal(names(input$resources), c("fixtures", "groups", "standings", "results", "status"))
  expect_identical(input$status_provenance, "derived")
  expect_identical(input$resources$status[[1L]]$competition_status, "scheduled")
  expect_identical(input$resources$status[[1L]]$source_edition_id, fixture$source_edition_id)
  expect_true(grepl("example.test/fixtures", input$source_urls[["status"]], fixed = TRUE))
  expect_true(grepl("example.test/results", input$source_urls[["status"]], fixed = TRUE))
})

test_that("live input reports missing optional status evidence instead of guessing", {
  acquire <- phase13_source_test_load_acquire()
  fixture <- phase13_source_test_fixture()
  resources <- fixture$resources[c("fixtures", "groups", "standings", "results")]
  options <- setNames(
    as.list(c(
      "https://example.test/fixtures",
      "https://example.test/groups",
      "https://example.test/standings",
      "https://example.test/results"
    )),
    paste0(c("fixtures", "groups", "standings", "results"), "-url")
  )
  expect_error(
    acquire$phase13_acquire_live_input(
      options,
      fixture$edition_id,
      fetch_fn = function(url, artifact_type, ...) list(
        payload = resources[[artifact_type]],
        raw_bytes = jsonlite::toJSON(resources[[artifact_type]], auto_unbox = TRUE),
        source_url = url
      ),
      sleep_fn = function(seconds) NULL
    ),
    "status|bearing|optional"
  )
})

test_that("bounded acquisition replays compact structured fixtures into an accepted edition", {
  fixture_dir <- file.path(phase13_source_test_project_root, "tests/fixtures/phase13")
  output_root <- tempfile("phase13-accepted-")
  registry_root <- tempfile("phase13-registries-")
  raw_root <- tempfile("phase13-raw-")
  result <- phase13_source_test_run_acquire(c(
    "--fixture-dir", fixture_dir,
    "--edition-id", "uefa_nations_league_2026_27",
    "--output-root", output_root,
    "--registry-root", registry_root,
    "--raw-root", raw_root,
    "--publish-accepted"
  ))
  expect_equal(result$status, 0L, info = paste(result$output, collapse = "\n"))
  accepted_root <- file.path(output_root, "uefa_nations_league_2026_27")
  expect_true(file.exists(file.path(accepted_root, "source_bundle_manifest.csv")))
  expect_true(all(file.exists(file.path(accepted_root, paste0(c("fixtures", "groups", "standings", "results", "status"), ".csv")))))
  expect_true(file.exists(file.path(registry_root, "source_bundles.csv")))
  expect_true(file.exists(file.path(registry_root, "source_artifacts.csv")))
  expect_true(file.exists(file.path(raw_root, "uefa_nations_league_2026_27")))
})

test_that("official capture rejects rendered HTML and PDF resource bodies", {
  phase13_source_test_load_apis()
  phase13_source_test_require_api(c("phase13_source_validate_structured_bytes"))
  expect_error(phase13_source_validate_structured_bytes("<!doctype html><html></html>", "fixtures"), "HTML|structured")
  expect_error(phase13_source_validate_structured_bytes("%PDF-1.7", "standings"), "PDF|structured")
})

test_that("reviewed fallback acceptance is complete and never mixes provenance", {
  fixture_dir <- file.path(phase13_source_test_project_root, "tests/fixtures/phase13")
  output_root <- tempfile("phase13-fallback-accepted-")
  registry_root <- tempfile("phase13-fallback-registries-")
  raw_root <- tempfile("phase13-fallback-raw-")
  result <- phase13_source_test_run_acquire(c(
    "--fixture-dir", fixture_dir,
    "--fallback-file", file.path(fixture_dir, "reviewed_fallback_bundle.json"),
    "--edition-id", "uefa_nations_league_2026_27",
    "--output-root", output_root,
    "--registry-root", registry_root,
    "--raw-root", raw_root
  ))
  expect_equal(result$status, 0L, info = paste(result$output, collapse = "\n"))
  bundle <- read.csv(file.path(registry_root, "source_bundles.csv"), stringsAsFactors = FALSE, check.names = FALSE)
  artifacts <- read.csv(file.path(registry_root, "source_artifacts.csv"), stringsAsFactors = FALSE, check.names = FALSE)
  expect_identical(bundle$fallback_status, "reviewed_fallback")
  expect_identical(bundle$acceptance_state, "reviewed")
  expect_true(all(artifacts$fallback_status == "reviewed_fallback"))
  expect_true(all(artifacts$review_state == "approved"))
  expect_true(nzchar(bundle$fallback_source))
  expect_match(bundle$fallback_checksum, "^[0-9a-f]{64}$")
  expect_true(all(grepl("^[0-9a-f]{64}$", artifacts$canonical_content_sha256)))
})

test_that("blocked candidate writes failure metadata and retains the prior accepted bundle", {
  fixture_dir <- file.path(phase13_source_test_project_root, "tests/fixtures/phase13")
  output_root <- tempfile("phase13-blocked-accepted-")
  registry_root <- tempfile("phase13-blocked-registries-")
  raw_root <- tempfile("phase13-blocked-raw-")
  accepted <- phase13_source_test_run_acquire(c(
    "--fixture-dir", fixture_dir,
    "--edition-id", "uefa_nations_league_2026_27",
    "--output-root", output_root,
    "--registry-root", registry_root,
    "--raw-root", raw_root,
    "--publish-accepted"
  ))
  expect_equal(accepted$status, 0L, info = paste(accepted$output, collapse = "\n"))
  accepted_manifest <- file.path(output_root, "uefa_nations_league_2026_27", "source_bundle_manifest.csv")
  before <- readLines(accepted_manifest, warn = FALSE)

  invalid_fixture_dir <- tempfile("phase13-invalid-fixture-")
  dir.create(invalid_fixture_dir, recursive = TRUE)
  invalid_fixture <- jsonlite::fromJSON(
    file.path(fixture_dir, "uefa_nations_league_sample.json"),
    simplifyVector = FALSE
  )
  invalid_fixture$resources$standings[[1L]]$points <- NULL
  jsonlite::write_json(
    invalid_fixture,
    file.path(invalid_fixture_dir, "uefa_nations_league_sample.json"),
    auto_unbox = TRUE,
    pretty = TRUE
  )
  blocked <- suppressWarnings(phase13_source_test_run_acquire(c(
    "--fixture-dir", invalid_fixture_dir,
    "--edition-id", "uefa_nations_league_2026_27",
    "--output-root", output_root,
    "--registry-root", registry_root,
    "--raw-root", raw_root,
    "--bundle-id", "nl-2026-27-invalid-refresh-v1"
  )))
  expect_false(identical(blocked$status, 0L))
  expect_identical(readLines(accepted_manifest, warn = FALSE), before)
  blocked_path <- file.path(output_root, "uefa_nations_league_2026_27", "blocked_refresh.json")
  expect_true(file.exists(blocked_path))
  blocked_metadata <- jsonlite::fromJSON(blocked_path)
  expect_identical(blocked_metadata$last_accepted_bundle_id, "nl-2026-27-official-sample-v1")
  expect_identical(blocked_metadata$output_bundle_target, "uefa_nations_league_2026_27")
  expect_identical(blocked_metadata$status, "blocked")
})

test_that("capture-only registries retain exact raw bytes and canonical source hashes", {
  phase13_source_test_load_apis()
  acquire <- phase13_source_test_load_acquire()
  fixture <- phase13_source_test_derived_fixture()
  fixture_file <- tempfile("phase13-derived-fixture-", fileext = ".json")
  jsonlite::write_json(fixture, fixture_file, auto_unbox = TRUE, pretty = FALSE)
  edition_id <- fixture$edition_id
  fixture_options <- list(
    `fixture-dir` = dirname(fixture_file),
    `fixture-file` = fixture_file,
    `fallback-file` = NULL,
    `bundle-id` = NULL
  )
  candidate <- acquire$phase13_acquire_candidate(
    fixture_options,
    edition_id,
    project_root = phase13_source_test_project_root
  )
  registry_root <- tempfile("phase13-capture-registries-")
  raw_root <- tempfile("phase13-capture-raw-")
  output_root <- tempfile("phase13-capture-only-")
  result <- phase13_source_test_run_acquire(c(
    "--fixture-dir", dirname(fixture_file),
    "--fixture-file", fixture_file,
    "--edition-id", edition_id,
    "--output-root", output_root,
    "--registry-root", registry_root,
    "--raw-root", raw_root
  ))
  expect_equal(result$status, 0L, info = paste(result$output, collapse = "\n"))
  expect_false(dir.exists(file.path(output_root, edition_id)))

  bundles <- utils::read.csv(
    file.path(registry_root, "source_bundles.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  artifacts <- utils::read.csv(
    file.path(registry_root, "source_artifacts.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  expect_equal(nrow(bundles), 1L)
  expect_equal(nrow(artifacts), 5L)
  expect_true(all(c("canonical_content_sha256", "row_sha256") %in% names(bundles)))
  expect_true(all(c(
    "source_artifact_id", "source_url_lineage", "status_provenance",
    "canonical_content_sha256", "raw_sha256", "row_sha256"
  ) %in% names(artifacts)))
  expect_match(bundles$canonical_content_sha256, "^[0-9a-f]{64}$")
  expect_true(all(grepl("^[0-9a-f]{64}$", artifacts$canonical_content_sha256)))

  status <- artifacts[artifacts$artifact_type == "status", , drop = FALSE]
  expect_equal(nrow(status), 1L)
  expect_identical(status$status_provenance, "derived")
  expect_true(grepl(paste0(candidate$bundle$bundle_id[[1L]], "-fixtures"), status$source_artifact_id, fixed = TRUE))
  expect_true(grepl(paste0(candidate$bundle$bundle_id[[1L]], "-results"), status$source_artifact_id, fixed = TRUE))
  expect_true(grepl("example", status$source_url_lineage, fixed = TRUE) || grepl("uefa.com", status$source_url_lineage, fixed = TRUE))

  raw_dir <- file.path(raw_root, edition_id, candidate$bundle$bundle_id[[1L]])
  for (artifact_type in phase13_source_required_resource_types()) {
    artifact <- artifacts[artifacts$artifact_type == artifact_type, , drop = FALSE]
    raw_path <- file.path(raw_dir, paste0(artifact_type, ".json"))
    expect_true(file.exists(raw_path))
    raw_bytes <- readBin(raw_path, what = "raw", n = file.info(raw_path)$size)
    expect_identical(as.integer(length(raw_bytes)), as.integer(artifact$bytes[[1L]]))
    expect_identical(
      digest::digest(raw_bytes, algo = "sha256", serialize = FALSE),
      as.character(artifact$raw_sha256[[1L]])
    )

    table <- phase13_source_resource_table(
      candidate$resources[[artifact_type]],
      artifact_type,
      edition_id,
      artifact$artifact_id[[1L]]
    )
    table <- cbind(
      schema_version = rep(paste0("phase13-", artifact_type, "-v1"), nrow(table)),
      table
    )
    table$row_sha256 <- phase13_row_sha256(table)
    canonical_path <- tempfile("phase13-canonical-", fileext = ".csv")
    utils::write.csv(table, canonical_path, row.names = FALSE, na = "", quote = TRUE)
    canonical_bytes <- readBin(canonical_path, what = "raw", n = file.info(canonical_path)$size)
    expect_identical(
      digest::digest(canonical_bytes, algo = "sha256", serialize = FALSE),
      as.character(artifact$canonical_content_sha256[[1L]])
    )
  }
})

test_that("source registry replacement is pairwise atomic and failed candidates leave no raw bundle", {
  acquire <- phase13_source_test_load_acquire()
  fixture_dir <- file.path(phase13_source_test_project_root, "tests/fixtures/phase13")
  edition_id <- "uefa_nations_league_2026_27"
  registry_root <- tempfile("phase13-atomic-registries-")
  raw_root <- tempfile("phase13-atomic-raw-")
  base_candidate <- acquire$phase13_acquire_candidate(
    list(
      `fixture-dir` = fixture_dir,
      `fixture-file` = NULL,
      `fallback-file` = NULL,
      `bundle-id` = "nl-2026-27-atomic-base-v1"
    ),
    edition_id,
    project_root = phase13_source_test_project_root
  )
  acquire$phase13_acquire_update_registries(base_candidate, registry_root)
  bundle_path <- file.path(registry_root, "source_bundles.csv")
  artifact_path <- file.path(registry_root, "source_artifacts.csv")
  before_bundle <- readBin(bundle_path, what = "raw", n = file.info(bundle_path)$size)
  before_artifact <- readBin(artifact_path, what = "raw", n = file.info(artifact_path)$size)

  replacement <- acquire$phase13_acquire_candidate(
    list(
      `fixture-dir` = fixture_dir,
      `fixture-file` = NULL,
      `fallback-file` = NULL,
      `bundle-id` = "nl-2026-27-atomic-replacement-v1"
    ),
    edition_id,
    project_root = phase13_source_test_project_root
  )
  original_writer <- acquire$phase13_source_write_csv
  writer_state <- new.env(parent = emptyenv())
  writer_state$writes <- 0L
  mock_writer <- (function(state) {
    function(data, path) {
      state$writes <- state$writes + 1L
      if (state$writes == 2L) stop("forced second registry write failure", call. = FALSE)
      utils::write.csv(data, path, row.names = FALSE, na = "", quote = TRUE)
    }
  })(writer_state)
  assign("phase13_source_write_csv", mock_writer, envir = acquire)
  on.exit(assign("phase13_source_write_csv", original_writer, envir = acquire), add = TRUE)
  expect_error(
    acquire$phase13_acquire_update_registries(replacement, registry_root),
    "forced second registry write failure"
  )
  expect_identical(readBin(bundle_path, what = "raw", n = file.info(bundle_path)$size), before_bundle)
  expect_identical(readBin(artifact_path, what = "raw", n = file.info(artifact_path)$size), before_artifact)

  invalid_fixture_dir <- tempfile("phase13-atomic-invalid-")
  dir.create(invalid_fixture_dir, recursive = TRUE)
  invalid_fixture <- jsonlite::fromJSON(
    file.path(fixture_dir, "uefa_nations_league_sample.json"),
    simplifyVector = FALSE
  )
  invalid_fixture$resources$standings[[1L]]$points <- NULL
  jsonlite::write_json(
    invalid_fixture,
    file.path(invalid_fixture_dir, "uefa_nations_league_sample.json"),
    auto_unbox = TRUE,
    pretty = FALSE
  )
  blocked <- suppressWarnings(phase13_source_test_run_acquire(c(
    "--fixture-dir", invalid_fixture_dir,
    "--edition-id", edition_id,
    "--output-root", tempfile("phase13-atomic-blocked-output-"),
    "--registry-root", registry_root,
    "--raw-root", raw_root,
    "--bundle-id", "nl-2026-27-atomic-invalid-v1"
  )))
  expect_false(identical(blocked$status, 0L))
  expect_identical(readBin(bundle_path, what = "raw", n = file.info(bundle_path)$size), before_bundle)
  expect_identical(readBin(artifact_path, what = "raw", n = file.info(artifact_path)$size), before_artifact)
  expect_false(dir.exists(file.path(raw_root, edition_id, "nl-2026-27-atomic-invalid-v1")))
})
