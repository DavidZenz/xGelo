library(testthat)

# Publication integration uses tests/fixtures/phase13 as a synthetic contract
# fixture.  It is never production evidence; production coverage lives in
# test_uefa_nations_league_production.R.

phase13_integration_test_project_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase13_integration_test_load_api <- function() {
  environment <- new.env(parent = globalenv())
  previous_directory <- getwd()
  setwd(phase13_integration_test_project_root)
  on.exit(setwd(previous_directory), add = TRUE)
  sys.source(
    file.path(phase13_integration_test_project_root, "scripts/acquire_uefa_snapshot.R"),
    envir = environment
  )
  environment
}

phase13_integration_test_copy_tree <- function(source, target) {
  dir.create(target, recursive = TRUE, showWarnings = FALSE)
  for (path in list.files(source, full.names = TRUE, all.files = FALSE)) {
    destination <- file.path(target, basename(path))
    if (dir.exists(path)) {
      phase13_integration_test_copy_tree(path, destination)
    } else {
      stopifnot(file.copy(path, destination, overwrite = TRUE))
    }
  }
  invisible(target)
}

phase13_integration_test_snapshot <- function(root) {
  if (!dir.exists(root)) return(list())
  files <- list.files(root, recursive = TRUE, full.names = TRUE, all.files = FALSE, no.. = TRUE)
  files <- files[!file.info(files)$isdir]
  if (!length(files)) return(list())
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  setNames(lapply(files, function(path) {
    bytes <- readBin(path, what = "raw", n = file.info(path)$size)
    list(
      bytes = bytes,
      sha256 = digest::digest(bytes, algo = "sha256", serialize = FALSE)
    )
  }), substring(files, nchar(root) + 2L))
}

phase13_integration_test_read_table <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
}

phase13_integration_test_candidate <- function(acquire, bundle_id = "nl-2026-27-official-sample-v1") {
  acquire$phase13_acquire_candidate(
    list(
      `fixture-dir` = file.path(phase13_integration_test_project_root, "tests/fixtures/phase13"),
      `fixture-file` = NULL,
      `fallback-file` = NULL,
      `bundle-id` = bundle_id
    ),
    "uefa_nations_league_2026_27",
    project_root = phase13_integration_test_project_root
  )
}

phase13_integration_test_copy_sandbox <- function() {
  root <- tempfile("phase13-publication-integration-", tmpdir = phase13_integration_test_project_root)
  accepted_root <- file.path(root, "accepted")
  registry_root <- file.path(root, "registries")
  raw_root <- file.path(root, "local_raw")
  phase13_integration_test_copy_tree(
    file.path(phase13_integration_test_project_root, "data/competition/accepted"),
    accepted_root
  )
  phase13_integration_test_copy_tree(
    file.path(phase13_integration_test_project_root, "data/competition/local_raw"),
    raw_root
  )
  dir.create(registry_root, recursive = TRUE, showWarnings = FALSE)
  registry_files <- file.path(
    phase13_integration_test_project_root,
    "data/competition/registries",
    c("competition_editions.csv", "source_artifacts.csv", "source_bundles.csv", "team_identity.csv")
  )
  stopifnot(all(file.copy(registry_files, registry_root, overwrite = TRUE)))
  refresh_marker <- file.path(
    registry_root,
    "refresh_batches",
    "uefa_nations_league_2026_27",
    "refresh-keep",
    "blocked_refresh.json"
  )
  dir.create(dirname(refresh_marker), recursive = TRUE, showWarnings = FALSE)
  writeBin(charToRaw("pre-existing registry-side refresh record"), refresh_marker)
  list(
    root = root,
    accepted_root = accepted_root,
    registry_root = registry_root,
    raw_root = raw_root,
    refresh_marker = refresh_marker
  )
}

phase13_integration_test_assert_source_handoff <- function(acquire, handoff_set) {
  expected_types <- phase13_source_required_resource_types()
  compact <- phase13_source_compact_resource_schema()
  expect_setequal(names(handoff_set$handoffs), phase13_publication_editions())
  for (edition_id in phase13_publication_editions()) {
    handoff <- handoff_set$handoffs[[edition_id]]
    for (artifact_type in expected_types) {
      table <- handoff$tables[[artifact_type]]
      expected <- c(
        "schema_version", compact[[artifact_type]],
        "edition_id", "source_artifact_id", "row_sha256"
      )
      expect_identical(names(table), expected)
      expect_false(any(c("team_id", "home_team_id", "away_team_id") %in% names(table)))
    }
  }
  invisible(TRUE)
}

test_that("synthetic fixture refresh rehydrates raw source handoffs and atomically publishes both editions", {
  acquire <- phase13_integration_test_load_api()
  sandbox <- phase13_integration_test_copy_sandbox()
  on.exit(unlink(sandbox$root, recursive = TRUE, force = TRUE), add = TRUE)
  candidate <- phase13_integration_test_candidate(acquire)

  handoff_set <- acquire$phase13_acquire_build_source_handoff_set(
    candidate = candidate,
    edition_id = "uefa_nations_league_2026_27",
    raw_root = sandbox$raw_root,
    registry_root = sandbox$registry_root,
    project_root = phase13_integration_test_project_root
  )
  on.exit(unlink(handoff_set$handoff_root, recursive = TRUE, force = TRUE), add = TRUE)
  phase13_integration_test_assert_source_handoff(acquire, handoff_set)
  expect_error(
    acquire$phase13_acquire_publication_validate_handoffs(
      sandbox$accepted_root,
      sandbox$registry_root
    ),
    "schema mismatch|source handoff"
  )

  calls <- 0L
  publish_fn <- function(...) {
    calls <<- calls + 1L
    published <- acquire$phase13_publish_normalized_editions(...)
    # The generic publication seam owns source/accepted artifacts; this
    # synthetic test wrapper also mirrors the production correction runner's
    # candidate identity-registry rebind before refresh validation.
    identity_path <- file.path(sandbox$registry_root, "team_identity.csv")
    identity <- phase13_integration_test_read_table(identity_path)
    identity$source_bundle_id <- as.character(candidate$bundle$bundle_id[[1L]])
    identity$row_sha256 <- get("phase13_identity_row_hash", envir = acquire, inherits = TRUE)(identity)
    get("phase13_source_write_csv", envir = acquire, inherits = TRUE)(identity, identity_path)
    edition_path <- file.path(sandbox$registry_root, "competition_editions.csv")
    editions <- phase13_integration_test_read_table(edition_path)
    edition_index <- match("uefa_nations_league_2026_27", as.character(editions$edition_id))
    editions$source_bundle_id[[edition_index]] <- as.character(candidate$bundle$bundle_id[[1L]])
    editions$active_output_bundle_id[[edition_index]] <- as.character(candidate$bundle$bundle_id[[1L]])
    editions$last_accepted_output_bundle_id[[edition_index]] <- as.character(candidate$bundle$bundle_id[[1L]])
    editions$row_sha256[[edition_index]] <- get("phase13_registry_row_hash", envir = acquire, inherits = TRUE)(editions[edition_index, , drop = FALSE])
    editions$row_sha256 <- get("phase13_row_sha256", envir = acquire, inherits = TRUE)(editions)
    get("phase13_source_write_csv", envir = acquire, inherits = TRUE)(editions, edition_path)
    published
  }
  marker_before <- phase13_integration_test_snapshot(sandbox$refresh_marker)
  published <- acquire$phase13_acquire_publish_refresh(
    candidate = candidate,
    output_root = sandbox$accepted_root,
    edition_id = "uefa_nations_league_2026_27",
    raw_root = sandbox$raw_root,
    registry_root = sandbox$registry_root,
    project_root = phase13_integration_test_project_root,
    registry_context_root = sandbox$registry_root,
    refresh_batch_id = "refresh-2026-08-16-public-success-v1",
    publish_normalized_fn = publish_fn
  )

  expect_identical(calls, 1L)
  expect_length(published$publication$targets, 14L)
  targets <- acquire$phase13_normalized_publication_targets(
    sandbox$accepted_root,
    sandbox$registry_root
  )
  expect_true(all(file.exists(unname(targets))))
  for (edition_id in phase13_publication_editions()) {
    fixtures <- phase13_integration_test_read_table(file.path(sandbox$accepted_root, edition_id, "fixtures.csv"))
    results <- phase13_integration_test_read_table(file.path(sandbox$accepted_root, edition_id, "results.csv"))
    expect_true(all(c("home_team_id", "away_team_id", "edition_id") %in% names(fixtures)))
    expect_true(all(c("home_team_id", "away_team_id", "edition_id") %in% names(results)))
    if (nrow(fixtures)) expect_true(all(as.character(fixtures$edition_id) == edition_id))
    if (nrow(results)) expect_true(all(as.character(results$edition_id) == edition_id))
    manifest <- phase13_integration_test_read_table(file.path(sandbox$accepted_root, edition_id, "source_bundle_manifest.csv"))
    expect_equal(nrow(manifest), 5L)
    expect_true(all(grepl("^[0-9a-f]{64}$", manifest$manifest_self_sha256)))
    expect_true(all(grepl("^[0-9a-f]{64}$", manifest$canonical_content_sha256)))
  }
  euro_status <- phase13_integration_test_read_table(file.path(
    sandbox$accepted_root, "uefa_euro_2028_qualifying", "status.csv"
  ))
  expect_equal(euro_status$competition_status, "pre_draw")
  for (artifact_type in c("fixtures", "groups", "standings", "results")) {
    expect_equal(nrow(phase13_integration_test_read_table(file.path(
      sandbox$accepted_root, "uefa_euro_2028_qualifying", paste0(artifact_type, ".csv")
    ))), 0L)
  }
  nl_fixtures <- phase13_integration_test_read_table(file.path(
    sandbox$accepted_root, "uefa_nations_league_2026_27", "fixtures.csv"
  ))
  expect_equal(nrow(nl_fixtures), 1L)
  expect_identical(
    as.character(nl_fixtures$source_artifact_id[[1L]]),
    "nl-2026-27-official-sample-v1-fixtures"
  )

  artifacts <- phase13_integration_test_read_table(file.path(sandbox$registry_root, "source_artifacts.csv"))
  expect_equal(nrow(artifacts), 10L)
  for (index in seq_len(nrow(artifacts))) {
    table_path <- file.path(
      sandbox$accepted_root,
      artifacts$edition_id[[index]],
      paste0(artifacts$artifact_type[[index]], ".csv")
    )
    expect_identical(
      tolower(as.character(artifacts$canonical_content_sha256[[index]])),
      tolower(acquire$phase13_acquire_file_sha256(table_path))
    )
  }
  loaded <- load_competition_edition_registries(
    registry_dir = sandbox$registry_root,
    project_root = phase13_integration_test_project_root,
    accepted_root = sandbox$accepted_root,
    raw_root = sandbox$raw_root
  )
  expect_equal(nrow(loaded), 2L)
  expect_setequal(as.character(loaded$edition_id), phase13_publication_editions())
  expect_identical(
    phase13_integration_test_snapshot(sandbox$refresh_marker),
    marker_before
  )
})

test_that("public refresh restores every target and registry-side file after each promotion failure", {
  acquire <- phase13_integration_test_load_api()
  for (failure_index in seq_len(14L)) {
    sandbox <- phase13_integration_test_copy_sandbox()
    candidate <- phase13_integration_test_candidate(acquire)
    on.exit(unlink(sandbox$root, recursive = TRUE, force = TRUE), add = TRUE)
    targets <- acquire$phase13_normalized_publication_targets(
      sandbox$accepted_root,
      sandbox$registry_root
    )
    targets_before <- phase13_integration_test_snapshot(sandbox$accepted_root)
    registry_targets_before <- phase13_integration_test_snapshot(sandbox$registry_root)
    editions_path <- file.path(sandbox$registry_root, "competition_editions.csv")
    editions_before <- phase13_integration_test_snapshot(editions_path)
    refresh_before <- phase13_integration_test_snapshot(file.path(sandbox$registry_root, "refresh_batches"))
    expect_error(
      acquire$phase13_acquire_publish_refresh(
        candidate = candidate,
        output_root = sandbox$accepted_root,
        edition_id = "uefa_nations_league_2026_27",
        raw_root = sandbox$raw_root,
        registry_root = sandbox$registry_root,
        project_root = phase13_integration_test_project_root,
        registry_context_root = sandbox$registry_root,
        refresh_batch_id = paste0("refresh-2026-08-16-public-failure-", failure_index),
        failure_injector = function(index, target, transaction) index == failure_index
      ),
      "Injected|promotion|failure"
    )
    expect_length(targets, 14L)
    expect_identical(phase13_integration_test_snapshot(sandbox$accepted_root), targets_before)
    expect_identical(phase13_integration_test_snapshot(sandbox$registry_root), registry_targets_before)
    expect_identical(phase13_integration_test_snapshot(editions_path), editions_before)
    expect_identical(phase13_integration_test_snapshot(file.path(sandbox$registry_root, "refresh_batches")), refresh_before)
    expect_false(any(grepl("^\\.phase13-publication-(stage|backup)-", list.files(sandbox$root))))
  }
})

test_that("offline main routes transaction failure to the durable blocked-refresh boundary", {
  acquire <- phase13_integration_test_load_api()
  sandbox <- phase13_integration_test_copy_sandbox()
  on.exit(unlink(sandbox$root, recursive = TRUE, force = TRUE), add = TRUE)
  accepted_before <- phase13_integration_test_snapshot(sandbox$accepted_root)
  source_before <- phase13_integration_test_snapshot(sandbox$registry_root)
  refresh_before <- phase13_integration_test_snapshot(file.path(sandbox$registry_root, "refresh_batches"))
  batch_id <- "refresh-2026-08-16-main-blocked-v1"
  wrapper <- function(...) {
    acquire$phase13_acquire_publish_refresh(
      ...,
      failure_injector = function(index, target, transaction) index == 1L
    )
  }
  expect_error(
    acquire$phase13_acquire_main(
      args = c(
        "--fixture-dir", file.path(phase13_integration_test_project_root, "tests/fixtures/phase13"),
        "--edition-id", "uefa_nations_league_2026_27",
        "--bundle-id", "nl-2026-27-official-sample-v1",
        "--publish-accepted",
        "--output-root", sandbox$accepted_root,
        "--registry-root", sandbox$registry_root,
        "--raw-root", sandbox$raw_root,
        "--refresh-batch-id", batch_id
      ),
      publish_refresh_fn = wrapper
    ),
    "source capture blocked|Injected|promotion"
  )
  expect_identical(phase13_integration_test_snapshot(sandbox$accepted_root), accepted_before)
  expect_identical(
    phase13_integration_test_snapshot(sandbox$registry_root)[
      names(source_before)[names(source_before) %in% c(
        "source_artifacts.csv", "source_bundles.csv", "team_identity.csv"
      )]
    ],
    source_before[names(source_before)[names(source_before) %in% c(
      "source_artifacts.csv", "source_bundles.csv", "team_identity.csv"
    )]]
  )
  expect_identical(phase13_integration_test_snapshot(file.path(sandbox$registry_root, "refresh_batches"))[
    names(refresh_before)
  ], refresh_before)
  editions <- phase13_integration_test_read_table(file.path(sandbox$registry_root, "competition_editions.csv"))
  edition <- editions[editions$edition_id == "uefa_nations_league_2026_27", , drop = FALSE]
  expect_true(phase13_registry_logical(edition$blocked[[1L]], "blocked"))
  expect_identical(as.character(edition$blocked_refresh_batch_id[[1L]]), batch_id)
  blocked_path <- file.path(
    sandbox$registry_root, "refresh_batches", "uefa_nations_league_2026_27", batch_id, "blocked_refresh.json"
  )
  history_path <- file.path(
    sandbox$registry_root, "refresh_batches", "uefa_nations_league_2026_27", "status_history.csv"
  )
  blocked <- jsonlite::fromJSON(blocked_path, simplifyVector = TRUE)
  history <- phase13_integration_test_read_table(history_path)
  expect_identical(as.character(blocked$status), "blocked")
  expect_identical(as.character(blocked$refresh_batch_id), batch_id)
  expect_identical(as.character(blocked$candidate_bundle_id), "nl-2026-27-official-sample-v1")
  expect_true(isTRUE(blocked$edition_blocked))
  expect_equal(nrow(history), 1L)
  expect_identical(as.character(history$status[[1L]]), "blocked")
  expect_identical(as.character(history$refresh_batch_id[[1L]]), batch_id)
  expect_silent(load_competition_edition_registries(
    registry_dir = sandbox$registry_root,
    project_root = phase13_integration_test_project_root,
    accepted_root = sandbox$accepted_root,
    raw_root = sandbox$raw_root
  ))
})

test_that("normalized identity and edition assignments remain stable under source row changes", {
  acquire <- phase13_integration_test_load_api()
  fixture <- jsonlite::fromJSON(
    file.path(phase13_integration_test_project_root, "tests/fixtures/phase13/uefa_nations_league_sample.json"),
    simplifyVector = FALSE
  )
  identity_map <- get("phase13_prepare_team_identity_map", envir = acquire, inherits = TRUE)(do.call(rbind, lapply(fixture$teams, function(team) data.frame(
    team_id = team$team_id,
    fifa_code = team$fifa_code,
    canonical_name = team$canonical_name,
    aliases = team$aliases,
    uefa_source_team_id = team$uefa_source_team_id,
    uefa_display_name_current = team$uefa_display_name_current,
    stringsAsFactors = FALSE
  ))))
  rows <- data.frame(
    source_fixture_id = c("nl-2026-0001", "nl-2026-0002"),
    home_uefa_source_team_id = c("8", "8"),
    away_uefa_source_team_id = c("47", "47"),
    home_display_name = c("Austria", "Austria"),
    away_display_name = c("Germany", "Germany"),
    scheduled_at_utc = c("2026-09-05T18:45:00Z", "2026-09-06T18:45:00Z"),
    status = c("scheduled", "scheduled"),
    stringsAsFactors = FALSE
  )
  normalize_fixtures <- get("phase13_normalize_fixture_rows", envir = acquire, inherits = TRUE)
  normalize_results <- get("phase13_normalize_accepted_result_rows", envir = acquire, inherits = TRUE)
  baseline <- normalize_fixtures(rows, identity_map, fixture$edition_id, "fixtures-artifact", "scheduled")
  reordered <- normalize_fixtures(rows[2:1, , drop = FALSE], identity_map, fixture$edition_id, "fixtures-artifact", "scheduled")
  baseline_identity <- baseline[order(baseline$uefa_source_fixture_id), c("uefa_source_fixture_id", "home_team_id", "away_team_id", "edition_id")]
  reordered_identity <- reordered[order(reordered$uefa_source_fixture_id), c("uefa_source_fixture_id", "home_team_id", "away_team_id", "edition_id")]
  row.names(baseline_identity) <- NULL
  row.names(reordered_identity) <- NULL
  expect_identical(baseline_identity, reordered_identity)
  results <- data.frame(
    source_fixture_id = rows$source_fixture_id,
    status = "complete",
    home_goals = c(1L, 2L),
    away_goals = c(0L, 1L),
    stringsAsFactors = FALSE
  )
  changed_scores <- results
  changed_scores$home_goals[[1L]] <- 3L
  result_before <- normalize_results(results, baseline, fixture$edition_id, "results-artifact", "scheduled")
  result_after <- normalize_results(changed_scores, baseline, fixture$edition_id, "results-artifact", "scheduled")
  expect_identical(result_before$home_team_id, result_after$home_team_id)
  expect_identical(result_before$away_team_id, result_after$away_team_id)
  expect_identical(result_before$edition_id, result_after$edition_id)
  expect_false(identical(result_before$row_sha256, result_after$row_sha256))
})
