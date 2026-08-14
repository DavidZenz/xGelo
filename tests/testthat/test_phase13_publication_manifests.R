library(testthat)

phase13_manifest_test_project_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase13_manifest_test_load_apis <- function() {
  source(file.path(phase13_manifest_test_project_root, "R/competition/source_contracts.R"), local = .GlobalEnv)
  source(file.path(phase13_manifest_test_project_root, "R/competition/team_identity.R"), local = .GlobalEnv)
  source(file.path(phase13_manifest_test_project_root, "R/competition/publication_hashes.R"), local = .GlobalEnv)
  manifest_path <- file.path(phase13_manifest_test_project_root, "R/competition/publication_manifests.R")
  if (file.exists(manifest_path)) source(manifest_path, local = .GlobalEnv)
  invisible(TRUE)
}

phase13_manifest_test_require_api <- function(required) {
  missing <- required[!vapply(required, exists, logical(1), mode = "function")]
  if (length(missing)) {
    stop(
      paste0(
        "Wave 8 RED contract awaits Phase 13 publication API: ",
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

phase13_manifest_test_read_csv <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
}

phase13_manifest_test_write_csv <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(data, path, row.names = FALSE, na = "", quote = TRUE)
  invisible(path)
}

phase13_manifest_test_bytes <- function(path) {
  if (!file.exists(path)) return(raw(0))
  readBin(path, what = "raw", n = file.info(path)$size)
}

phase13_manifest_test_seed <- function() {
  phase13_manifest_test_load_apis()
  phase13_manifest_test_require_api(c(
    "phase13_normalized_resource_targets",
    "phase13_refresh_canonical_table_hashes",
    "phase13_refresh_accepted_manifest_hashes"
  ))

  root <- tempfile("phase13-publication-manifests-")
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  accepted_root <- file.path(root, "data/competition/accepted")
  registry_root <- file.path(root, "data/competition/registries")
  dir.create(accepted_root, recursive = TRUE, showWarnings = FALSE)
  dir.create(registry_root, recursive = TRUE, showWarnings = FALSE)

  source_accepted_root <- file.path(phase13_manifest_test_project_root, "data/competition/accepted")
  editions <- c("uefa_nations_league_2026_27", "uefa_euro_2028_qualifying")
  for (edition_id in editions) {
    file.copy(
      file.path(source_accepted_root, edition_id),
      accepted_root,
      recursive = TRUE,
      copy.date = TRUE
    )
  }
  for (name in c("source_artifacts.csv", "source_bundles.csv")) {
    file.copy(file.path(phase13_manifest_test_project_root, "data/competition/registries", name), registry_root)
  }

  artifacts <- phase13_manifest_test_read_csv(file.path(registry_root, "source_artifacts.csv"))
  identity_map <- phase13_manifest_test_read_csv(
    file.path(phase13_manifest_test_project_root, "data/competition/registries/team_identity.csv")
  )
  identity_map <- identity_map[, phase13_team_identity_required_columns(), drop = FALSE]

  nl <- "uefa_nations_league_2026_27"
  nl_fixture_artifact <- artifacts$source_artifact_id[
    artifacts$edition_id == nl & artifacts$artifact_type == "fixtures"
  ][[1L]]
  nl_result_artifact <- artifacts$source_artifact_id[
    artifacts$edition_id == nl & artifacts$artifact_type == "results"
  ][[1L]]
  normalized_fixtures <- phase13_normalize_fixture_rows(
    phase13_manifest_test_read_csv(file.path(accepted_root, nl, "fixtures.csv")),
    identity_map = identity_map,
    edition_id = nl,
    source_artifact_id = nl_fixture_artifact,
    lifecycle_state = "scheduled"
  )
  normalized_results <- phase13_normalize_accepted_result_rows(
    phase13_manifest_test_read_csv(file.path(accepted_root, nl, "results.csv")),
    normalized_fixtures = normalized_fixtures,
    edition_id = nl,
    source_artifact_id = nl_result_artifact,
    lifecycle_state = "scheduled"
  )
  phase13_manifest_test_write_csv(normalized_fixtures, file.path(accepted_root, nl, "fixtures.csv"))
  phase13_manifest_test_write_csv(normalized_results, file.path(accepted_root, nl, "results.csv"))

  euro <- "uefa_euro_2028_qualifying"
  phase13_manifest_test_write_csv(
    phase13_empty_normalized_fixture_rows(),
    file.path(accepted_root, euro, "fixtures.csv")
  )
  phase13_manifest_test_write_csv(
    phase13_empty_normalized_result_rows(),
    file.path(accepted_root, euro, "results.csv")
  )

  targets <- phase13_normalized_resource_targets(root)
  canonical <- phase13_refresh_canonical_table_hashes(
    staged_root = root,
    table_targets = targets,
    source_artifacts = artifacts
  )
  bundles <- phase13_manifest_test_read_csv(file.path(registry_root, "source_bundles.csv"))
  list(
    root = root,
    accepted_root = accepted_root,
    registry_root = registry_root,
    actual_root = phase13_manifest_test_project_root,
    targets = targets,
    canonical = canonical,
    source_artifacts = canonical$source_artifacts,
    source_bundles = bundles,
    editions = editions,
    resource_types = phase13_source_required_resource_types()
  )
}

phase13_manifest_test_refresh <- function(fixture, ...) {
  phase13_refresh_accepted_manifest_hashes(
    staged_root = fixture$root,
    canonical_refresh = fixture$canonical,
    ...
  )
}

test_that("Wave 8 exposes the accepted-manifest hash API", {
  phase13_manifest_test_load_apis()
  phase13_manifest_test_require_api(c("phase13_refresh_accepted_manifest_hashes"))
  expect_true(is.function(phase13_refresh_accepted_manifest_hashes))
})

test_that("accepted manifests and source bundles regenerate as one complete five-artifact graph", {
  fixture <- phase13_manifest_test_seed()
  durable_manifest_bytes <- lapply(
    fixture$editions,
    function(edition_id) phase13_manifest_test_bytes(
      file.path(fixture$actual_root, "data/competition/accepted", edition_id, "source_bundle_manifest.csv")
    )
  )
  durable_bundle_bytes <- phase13_manifest_test_bytes(
    file.path(fixture$actual_root, "data/competition/registries/source_bundles.csv")
  )

  refreshed <- phase13_manifest_test_refresh(fixture)
  expect_true(is.list(refreshed))
  expect_true(all(c(
    "manifests", "source_bundles", "source_artifacts", "bundle_hashes",
    "artifact_manifest_hashes", "manifest_self_hashes"
  ) %in% names(refreshed)))
  expect_length(refreshed$manifests, 2L)
  expect_equal(nrow(refreshed$source_bundles), 2L)
  expect_equal(nrow(refreshed$source_artifacts), 10L)
  expect_true(all(grepl("^[0-9a-f]{64}$", refreshed$bundle_hashes)))
  expect_true(all(grepl("^[0-9a-f]{64}$", refreshed$artifact_manifest_hashes)))
  expect_true(all(grepl("^[0-9a-f]{64}$", refreshed$manifest_self_hashes)))

  for (edition_id in fixture$editions) {
    manifest <- refreshed$manifests[[edition_id]]
    manifest_on_disk <- phase13_manifest_test_read_csv(refreshed$manifest_paths[[edition_id]])
    expect_identical(names(manifest_on_disk), phase13_publication_manifest_schema())
    expect_equal(nrow(manifest_on_disk), 5L)
    row.names(manifest_on_disk) <- NULL
    row.names(manifest) <- NULL
    expect_equal(manifest_on_disk, manifest)
    artifact_rows <- refreshed$source_artifacts[
      refreshed$source_artifacts$edition_id == edition_id,
      ,
      drop = FALSE
    ]
    bundle <- refreshed$source_bundles[
      refreshed$source_bundles$edition_id == edition_id,
      ,
      drop = FALSE
    ]
    expect_equal(nrow(manifest), 5L)
    expect_setequal(manifest$artifact_type, fixture$resource_types)
    expect_true(all(as.character(manifest$edition_id) == edition_id))
    expect_true(all(as.character(manifest$bundle_id) == as.character(bundle$bundle_id[[1L]])))
    expect_true(all(as.character(manifest$source_artifact_id) %in% artifact_rows$source_artifact_id))
    expect_true(all(as.character(manifest$raw_sha256) %in% artifact_rows$raw_sha256))
    canonical_columns <- which(names(manifest) == "canonical_content_sha256")
    expect_length(canonical_columns, 2L)
    expect_true(all(as.character(manifest[[canonical_columns[[2L]]]]) %in% artifact_rows$canonical_content_sha256))
    expect_length(unique(as.character(manifest$source_bundle_sha256)), 1L)
    expect_length(unique(as.character(manifest$artifact_manifest_sha256)), 1L)
    expect_length(unique(as.character(manifest$manifest_self_sha256)), 1L)
    expect_identical(
      as.character(bundle$source_bundle_sha256[[1L]]),
      as.character(bundle$artifact_manifest_sha256[[1L]])
    )
    expect_identical(
      as.character(bundle$source_bundle_sha256[[1L]]),
      as.character(refreshed$bundle_hashes[[edition_id]])
    )
    expect_identical(
      as.character(bundle$artifact_manifest_sha256[[1L]]),
      as.character(refreshed$artifact_manifest_hashes[[edition_id]])
    )
    expect_identical(
      as.character(bundle$manifest_self_sha256[[1L]]),
      as.character(refreshed$manifest_self_hashes[[edition_id]])
    )
    expect_silent(phase13_validate_source_bundle(bundle, artifact_rows))
  }

  bundles_on_disk <- phase13_manifest_test_read_csv(refreshed$source_bundles_path)
  expect_identical(names(bundles_on_disk), names(refreshed$source_bundles))
  row.names(bundles_on_disk) <- NULL
  row.names(refreshed$source_bundles) <- NULL
  expect_equal(bundles_on_disk, refreshed$source_bundles)

  for (index in seq_along(fixture$editions)) {
    manifest_path <- file.path(
      fixture$actual_root,
      "data/competition/accepted",
      fixture$editions[[index]],
      "source_bundle_manifest.csv"
    )
    expect_identical(phase13_manifest_test_bytes(manifest_path), durable_manifest_bytes[[index]])
  }
  expect_identical(
    phase13_manifest_test_bytes(file.path(fixture$actual_root, "data/competition/registries/source_bundles.csv")),
    durable_bundle_bytes
  )
})

test_that("EURO pre_draw status lineage and empty structures remain truthful", {
  fixture <- phase13_manifest_test_seed()
  refreshed <- phase13_manifest_test_refresh(fixture)
  euro_manifest <- refreshed$manifests[["uefa_euro_2028_qualifying"]]
  euro_status <- euro_manifest[euro_manifest$artifact_type == "status", , drop = FALSE]
  expect_equal(nrow(euro_manifest[euro_manifest$artifact_type != "status", , drop = FALSE]), 4L)
  expect_identical(as.character(euro_status$status_provenance), "explicit")
  expect_identical(as.character(euro_status$fallback_status), "official")
  for (artifact_type in setdiff(fixture$resource_types, "status")) {
    expect_equal(
      nrow(refreshed$canonical$tables[[phase13_publication_key("uefa_euro_2028_qualifying", artifact_type)]]),
      0L
    )
  }
})

test_that("derived hashes are stable under harmless registry ordering", {
  baseline_fixture <- phase13_manifest_test_seed()
  baseline <- phase13_manifest_test_refresh(baseline_fixture)
  reordered_fixture <- phase13_manifest_test_seed()
  reordered_artifacts <- reordered_fixture$canonical$source_artifacts[
    rev(seq_len(nrow(reordered_fixture$canonical$source_artifacts))),
    ,
    drop = FALSE
  ]
  reordered_bundles <- reordered_fixture$source_bundles[
    rev(seq_len(nrow(reordered_fixture$source_bundles))),
    ,
    drop = FALSE
  ]
  reordered <- phase13_manifest_test_refresh(
    reordered_fixture,
    source_artifacts = reordered_artifacts,
    source_bundles = reordered_bundles
  )
  expect_identical(baseline$bundle_hashes, reordered$bundle_hashes)
  expect_identical(baseline$artifact_manifest_hashes, reordered$artifact_manifest_hashes)
  expect_identical(baseline$manifest_self_hashes, reordered$manifest_self_hashes)
  for (edition_id in baseline_fixture$editions) {
    expect_identical(
      baseline$manifests[[edition_id]],
      reordered$manifests[[edition_id]]
    )
  }
})

test_that("stale canonical values and forged manifest links fail closed", {
  fixture <- phase13_manifest_test_seed()
  stale <- fixture$canonical
  stale$table_hashes[["uefa_nations_league_2026_27::fixtures"]] <- strrep("0", 64)
  expect_error(
    phase13_manifest_test_refresh(fixture, canonical_refresh = stale),
    "stale|canonical|mismatch"
  )

  forged <- fixture$canonical$source_artifacts
  forged$source_artifact_id[[1L]] <- "forged-source-artifact"
  forged$row_sha256 <- phase13_row_sha256(forged)
  expect_error(
    phase13_manifest_test_refresh(fixture, source_artifacts = forged),
    "forged|source|lineage|link|mismatch"
  )
})

test_that("duplicate artifacts and mixed fallback provenance fail closed", {
  fixture <- phase13_manifest_test_seed()
  duplicate <- rbind(
    fixture$canonical$source_artifacts,
    fixture$canonical$source_artifacts[1L, , drop = FALSE]
  )
  expect_error(
    phase13_manifest_test_refresh(fixture, source_artifacts = duplicate),
    "duplicate|artifact|complete|ten"
  )

  mixed <- fixture$canonical$source_artifacts
  mixed$fallback_status[[1L]] <- "reviewed_fallback"
  mixed$review_state[[1L]] <- "approved"
  mixed$row_sha256 <- phase13_row_sha256(mixed)
  expect_error(
    phase13_manifest_test_refresh(fixture, source_artifacts = mixed),
    "mix|fallback|status|edition"
  )
})
