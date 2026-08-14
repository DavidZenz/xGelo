library(testthat)

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

phase13_integration_test_require_api <- function(environment, required) {
  missing <- required[!vapply(required, function(name) exists(name, envir = environment, mode = "function"), logical(1))]
  if (length(missing)) {
    stop(
      paste0(
        "Wave 9 RED contract awaits normalized publication API: ",
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

phase13_integration_test_source_handoff_table <- function(normalized, artifact_type, edition_id, source_artifact_id) {
  normalized <- as.data.frame(normalized, stringsAsFactors = FALSE, check.names = FALSE)
  if (identical(artifact_type, "fixtures")) {
    compact <- data.frame(
      source_fixture_id = as.character(normalized$uefa_source_fixture_id),
      scheduled_at_utc = as.character(normalized$scheduled_at_utc),
      status = as.character(normalized$status),
      home_uefa_source_team_id = as.character(normalized$home_uefa_source_team_id),
      away_uefa_source_team_id = as.character(normalized$away_uefa_source_team_id),
      home_display_name = as.character(normalized$home_display_name),
      away_display_name = as.character(normalized$away_display_name),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  } else if (identical(artifact_type, "results")) {
    compact <- data.frame(
      source_fixture_id = as.character(normalized$uefa_source_fixture_id),
      status = as.character(normalized$status),
      home_goals = normalized$home_goals,
      away_goals = normalized$away_goals,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  } else {
    compact_fields <- phase13_source_compact_resource_schema()[[artifact_type]]
    compact <- normalized[, compact_fields, drop = FALSE]
  }
  output <- cbind(
    schema_version = rep(paste0("phase13-", artifact_type, "-v1"), nrow(compact)),
    compact,
    edition_id = rep(edition_id, nrow(compact)),
    source_artifact_id = rep(source_artifact_id, nrow(compact))
  )
  output$row_sha256 <- phase13_row_sha256(output)
  output
}

phase13_integration_test_prepare_source_handoff <- function(sandbox, acquire, editions) {
  artifacts_path <- file.path(sandbox$registry_root, "source_artifacts.csv")
  bundles_path <- file.path(sandbox$registry_root, "source_bundles.csv")
  artifacts <- phase13_integration_test_read_table(artifacts_path)
  bundles <- phase13_integration_test_read_table(bundles_path)
  write_csv <- get("phase13_publication_write_csv", envir = acquire, inherits = TRUE)
  file_sha256 <- get("phase13_acquire_file_sha256", envir = acquire, inherits = TRUE)
  row_sha256 <- get("phase13_row_sha256", envir = acquire, inherits = TRUE)
  rebuild_bundle <- get("phase13_acquire_rebuild_bundle_row", envir = acquire, inherits = TRUE)
  bundle_content_table <- get("phase13_acquire_bundle_content_table", envir = acquire, inherits = TRUE)
  canonical_content_sha256 <- get("phase13_acquire_canonical_content_sha256", envir = acquire, inherits = TRUE)
  validate_bundle <- get("phase13_validate_source_bundle", envir = acquire, inherits = TRUE)
  source_manifest_table <- get("phase13_acquire_source_manifest_table", envir = acquire, inherits = TRUE)

  for (edition_id in editions) {
    for (artifact_type in phase13_source_required_resource_types()) {
      artifact_index <- which(
        as.character(artifacts$edition_id) == edition_id &
          as.character(artifacts$artifact_type) == artifact_type
      )
      if (length(artifact_index) != 1L) {
        stop("Phase 13 integration fixture source-artifact link is incomplete", call. = FALSE)
      }
      path <- file.path(sandbox$accepted_root, edition_id, paste0(artifact_type, ".csv"))
      normalized <- phase13_integration_test_read_table(path)
      source_table <- phase13_integration_test_source_handoff_table(
        normalized,
        artifact_type,
        edition_id,
        as.character(artifacts$source_artifact_id[[artifact_index]])
      )
      write_csv(source_table, path)
      artifacts$canonical_content_sha256[[artifact_index]] <- file_sha256(path)
    }
  }
  artifacts$row_sha256 <- row_sha256(artifacts)

  rebuilt_bundles <- lapply(editions, function(edition_id) {
    bundle_index <- which(as.character(bundles$edition_id) == edition_id)
    edition_artifacts <- artifacts[as.character(artifacts$edition_id) == edition_id, , drop = FALSE]
    if (length(bundle_index) != 1L || nrow(edition_artifacts) != 5L) {
      stop("Phase 13 integration fixture source bundle link is incomplete", call. = FALSE)
    }
    bundle <- rebuild_bundle(bundles[bundle_index, , drop = FALSE], edition_artifacts)
    bundle$canonical_content_sha256 <- canonical_content_sha256(
      bundle_content_table(bundle, edition_artifacts)
    )
    bundle <- rebuild_bundle(bundle, edition_artifacts)
    validate_bundle(bundle, edition_artifacts)
    manifest <- source_manifest_table(bundle, edition_artifacts)
    write_csv(
      manifest,
      file.path(sandbox$accepted_root, edition_id, "source_bundle_manifest.csv")
    )
    bundle
  })
  bundles <- do.call(rbind, rebuilt_bundles)
  row.names(bundles) <- NULL
  write_csv(artifacts, artifacts_path)
  write_csv(bundles, bundles_path)
  invisible(sandbox)
}

phase13_integration_test_copy_sandbox <- function(acquire) {
  root <- tempfile("phase13-publication-integration-")
  accepted_root <- file.path(root, "accepted")
  registry_root <- file.path(root, "registries")
  source_accepted <- file.path(phase13_integration_test_project_root, "data/competition/accepted")
  source_registry <- file.path(phase13_integration_test_project_root, "data/competition/registries")
  editions <- c("uefa_nations_league_2026_27", "uefa_euro_2028_qualifying")
  dir.create(accepted_root, recursive = TRUE, showWarnings = FALSE)
  dir.create(registry_root, recursive = TRUE, showWarnings = FALSE)
  for (edition_id in editions) {
    target <- file.path(accepted_root, edition_id)
    dir.create(target, recursive = TRUE, showWarnings = FALSE)
    file.copy(
      list.files(file.path(source_accepted, edition_id), full.names = TRUE),
      target,
      overwrite = TRUE
    )
  }
  file.copy(
    file.path(source_registry, c("source_artifacts.csv", "source_bundles.csv", "team_identity.csv", "competition_editions.csv")),
    registry_root,
    overwrite = TRUE
  )
  phase13_integration_test_prepare_source_handoff(
    list(root = root, accepted_root = accepted_root, registry_root = registry_root),
    acquire,
    editions
  )
  refresh_marker <- file.path(
    registry_root, "refresh_batches", "uefa_nations_league_2026_27", "refresh-keep", "blocked_refresh.json"
  )
  dir.create(dirname(refresh_marker), recursive = TRUE, showWarnings = FALSE)
  writeBin(charToRaw("registry-side refresh record"), refresh_marker)
  list(
    root = root,
    accepted_root = accepted_root,
    registry_root = registry_root,
    refresh_marker = refresh_marker
  )
}

phase13_integration_test_target_bytes <- function(targets) {
  lapply(unname(targets), function(path) {
    if (!file.exists(path)) return(NULL)
    readBin(path, what = "raw", n = file.info(path)$size)
  })
}

phase13_integration_test_read_table <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
}

test_that("normalized publication atomically promotes both editions and the complete hash graph", {
  acquire <- phase13_integration_test_load_api()
  phase13_integration_test_require_api(acquire, c(
    "phase13_publish_normalized_editions",
    "phase13_normalized_publication_targets"
  ))
  sandbox <- phase13_integration_test_copy_sandbox(acquire)
  targets <- acquire$phase13_normalized_publication_targets(sandbox$accepted_root, sandbox$registry_root)
  groups_before <- phase13_integration_test_read_table(file.path(
    sandbox$accepted_root, "uefa_nations_league_2026_27", "groups.csv"
  ))
  standings_before <- phase13_integration_test_read_table(file.path(
    sandbox$accepted_root, "uefa_nations_league_2026_27", "standings.csv"
  ))
  status_before <- phase13_integration_test_read_table(file.path(
    sandbox$accepted_root, "uefa_nations_league_2026_27", "status.csv"
  ))

  published <- acquire$phase13_publish_normalized_editions(
    output_root = sandbox$accepted_root,
    registry_root = sandbox$registry_root,
    registry_context_root = sandbox$registry_root
  )

  expect_length(published$targets, 14L)
  expect_true(all(file.exists(unname(targets))))
  for (edition_id in c("uefa_nations_league_2026_27", "uefa_euro_2028_qualifying")) {
    fixtures <- phase13_integration_test_read_table(file.path(sandbox$accepted_root, edition_id, "fixtures.csv"))
    results <- phase13_integration_test_read_table(file.path(sandbox$accepted_root, edition_id, "results.csv"))
    expect_true(all(c("home_team_id", "away_team_id", "edition_id") %in% names(fixtures)))
    expect_true(all(c("home_team_id", "away_team_id", "edition_id") %in% names(results)))
    expect_true(all(as.character(fixtures$edition_id) == edition_id))
    expect_true(all(as.character(results$edition_id) == edition_id))
    expect_true(all(c("source_artifact_id", "row_sha256") %in% names(fixtures)))
    expect_true(all(c("source_artifact_id", "fixture_source_artifact_id", "row_sha256") %in% names(results)))
    manifest <- phase13_integration_test_read_table(file.path(sandbox$accepted_root, edition_id, "source_bundle_manifest.csv"))
    expect_equal(nrow(manifest), 5L)
    expect_true(all(grepl("^[0-9a-f]{64}$", manifest$manifest_self_sha256)))
    expect_true(all(grepl("^[0-9a-f]{64}$", manifest$canonical_content_sha256)))
  }
  expect_identical(
    phase13_integration_test_read_table(file.path(sandbox$accepted_root, "uefa_nations_league_2026_27", "groups.csv")),
    groups_before
  )
  expect_identical(
    phase13_integration_test_read_table(file.path(sandbox$accepted_root, "uefa_nations_league_2026_27", "standings.csv")),
    standings_before
  )
  expect_identical(
    phase13_integration_test_read_table(file.path(sandbox$accepted_root, "uefa_nations_league_2026_27", "status.csv")),
    status_before
  )
  expect_identical(readBin(sandbox$refresh_marker, what = "raw", n = file.info(sandbox$refresh_marker)$size), charToRaw("registry-side refresh record"))
  expect_false(any(grepl("refresh_batches", published$targets, fixed = TRUE)))
  expect_true(isTRUE(published$loader_ready))
})

test_that("every injected post-promotion failure restores all normalized publication targets", {
  acquire <- phase13_integration_test_load_api()
  phase13_integration_test_require_api(acquire, c(
    "phase13_publish_normalized_editions",
    "phase13_normalized_publication_targets"
  ))
  sandbox <- phase13_integration_test_copy_sandbox(acquire)
  targets <- acquire$phase13_normalized_publication_targets(sandbox$accepted_root, sandbox$registry_root)
  before <- phase13_integration_test_target_bytes(targets)

  for (failure_index in seq_along(targets)) {
    expect_error(
      acquire$phase13_publish_normalized_editions(
        output_root = sandbox$accepted_root,
        registry_root = sandbox$registry_root,
        registry_context_root = sandbox$registry_root,
        failure_injector = function(index, target, transaction) index == failure_index
      ),
      "Injected|failure|promotion"
    )
    expect_identical(phase13_integration_test_target_bytes(targets), before)
    expect_identical(readBin(sandbox$refresh_marker, what = "raw", n = file.info(sandbox$refresh_marker)$size), charToRaw("registry-side refresh record"))
    expect_false(any(grepl("^\\.phase13-publication-(stage|backup)-", list.files(sandbox$root))))
  }
})

test_that("stale and forged source links fail before any normalized target is promoted", {
  acquire <- phase13_integration_test_load_api()
  phase13_integration_test_require_api(acquire, c(
    "phase13_publish_normalized_editions",
    "phase13_normalized_publication_targets"
  ))
  sandbox <- phase13_integration_test_copy_sandbox(acquire)
  targets <- acquire$phase13_normalized_publication_targets(sandbox$accepted_root, sandbox$registry_root)
  before <- phase13_integration_test_target_bytes(targets)
  artifacts_path <- file.path(sandbox$registry_root, "source_artifacts.csv")
  artifacts <- phase13_integration_test_read_table(artifacts_path)
  artifacts$canonical_content_sha256[[1L]] <- paste(rep("0", 64L), collapse = "")
  utils::write.csv(artifacts, artifacts_path, row.names = FALSE, na = "", quote = TRUE)
  before_forged <- phase13_integration_test_target_bytes(targets)
  expect_error(
    acquire$phase13_publish_normalized_editions(
      output_root = sandbox$accepted_root,
      registry_root = sandbox$registry_root,
      registry_context_root = sandbox$registry_root
    ),
    "stale|hash|row|manifest|source"
  )
  expect_identical(phase13_integration_test_target_bytes(targets), before_forged)
})

test_that("normalized identity and edition assignments remain stable under source row changes", {
  acquire <- phase13_integration_test_load_api()
  phase13_integration_test_require_api(acquire, c(
    "phase13_normalize_fixture_rows",
    "phase13_normalize_accepted_result_rows"
  ))
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
  normalize_fixtures <- get("phase13_normalize_fixture_rows", envir = acquire, inherits = TRUE)
  normalize_results <- get("phase13_normalize_accepted_result_rows", envir = acquire, inherits = TRUE)
  source_fixture <- fixture$resources$fixtures[[1L]]
  rows <- data.frame(
    source_fixture_id = c(source_fixture$source_fixture_id, "nl-2026-0002"),
    home_uefa_source_team_id = c(source_fixture$home$uefa_source_team_id, source_fixture$home$uefa_source_team_id),
    away_uefa_source_team_id = c(source_fixture$away$uefa_source_team_id, source_fixture$away$uefa_source_team_id),
    home_display_name = c(source_fixture$home$display_name, source_fixture$home$display_name),
    away_display_name = c(source_fixture$away$display_name, source_fixture$away$display_name),
    scheduled_at_utc = c(source_fixture$scheduled_at_utc, "2026-09-06T18:45:00Z"),
    status = c(source_fixture$status, source_fixture$status),
    stringsAsFactors = FALSE
  )
  baseline <- normalize_fixtures(
    rows,
    identity_map,
    fixture$edition_id,
    source_artifact_id = "fixtures-artifact",
    lifecycle_state = "scheduled"
  )
  reordered <- normalize_fixtures(
    rows[2:1, , drop = FALSE],
    identity_map,
    fixture$edition_id,
    source_artifact_id = "fixtures-artifact",
    lifecycle_state = "scheduled"
  )
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
  result_before <- normalize_results(
    results, baseline, edition_id = fixture$edition_id,
    source_artifact_id = "results-artifact", lifecycle_state = "scheduled"
  )
  result_after <- normalize_results(
    changed_scores, baseline, edition_id = fixture$edition_id,
    source_artifact_id = "results-artifact", lifecycle_state = "scheduled"
  )
  expect_identical(result_before$home_team_id, result_after$home_team_id)
  expect_identical(result_before$away_team_id, result_after$away_team_id)
  expect_identical(result_before$edition_id, result_after$edition_id)
  expect_false(identical(result_before$row_sha256, result_after$row_sha256))
})
