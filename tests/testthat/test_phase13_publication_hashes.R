library(testthat)

phase13_publication_test_project_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase13_publication_test_load_apis <- function() {
  source(file.path(phase13_publication_test_project_root, "R/competition/source_contracts.R"), local = .GlobalEnv)
  source(file.path(phase13_publication_test_project_root, "R/competition/team_identity.R"), local = .GlobalEnv)
  hash_path <- file.path(phase13_publication_test_project_root, "R/competition/publication_hashes.R")
  if (file.exists(hash_path)) source(hash_path, local = .GlobalEnv)
  invisible(TRUE)
}

phase13_publication_test_require_api <- function(required) {
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

phase13_publication_test_read_csv <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
}

phase13_publication_test_write_csv <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(data, path, row.names = FALSE, na = "", quote = TRUE)
  invisible(path)
}

phase13_publication_test_bytes <- function(path) {
  if (!file.exists(path)) return(raw(0))
  readBin(path, what = "raw", n = file.info(path)$size)
}

phase13_publication_test_source_fixture_rows <- function(normalized) {
  normalized <- as.data.frame(normalized, stringsAsFactors = FALSE, check.names = FALSE)
  if (!nrow(normalized)) {
    return(data.frame(
      source_fixture_id = character(0),
      home_uefa_source_team_id = character(0),
      away_uefa_source_team_id = character(0),
      home_display_name = character(0),
      away_display_name = character(0),
      scheduled_at_utc = character(0),
      status = character(0),
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    source_fixture_id = as.character(normalized$uefa_source_fixture_id),
    home_uefa_source_team_id = as.character(normalized$home_uefa_source_team_id),
    away_uefa_source_team_id = as.character(normalized$away_uefa_source_team_id),
    home_display_name = as.character(normalized$home_display_name),
    away_display_name = as.character(normalized$away_display_name),
    scheduled_at_utc = as.character(normalized$scheduled_at_utc),
    status = as.character(normalized$status),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase13_publication_test_source_result_rows <- function(normalized) {
  normalized <- as.data.frame(normalized, stringsAsFactors = FALSE, check.names = FALSE)
  if (!nrow(normalized)) {
    return(data.frame(
      source_fixture_id = character(0),
      status = character(0),
      home_goals = integer(0),
      away_goals = integer(0),
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    source_fixture_id = as.character(normalized$uefa_source_fixture_id),
    status = as.character(normalized$status),
    home_goals = normalized$home_goals,
    away_goals = normalized$away_goals,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase13_publication_test_seed <- function() {
  phase13_publication_test_load_apis()
  phase13_publication_test_require_api(c(
    "phase13_normalized_resource_targets",
    "phase13_refresh_canonical_table_hashes"
  ))

  root <- tempfile("phase13-publication-hashes-")
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  accepted_root <- file.path(root, "data/competition/accepted")
  registry_root <- file.path(root, "data/competition/registries")
  dir.create(accepted_root, recursive = TRUE, showWarnings = FALSE)
  dir.create(registry_root, recursive = TRUE, showWarnings = FALSE)

  source_accepted_root <- file.path(phase13_publication_test_project_root, "data/competition/accepted")
  for (edition_id in c("uefa_nations_league_2026_27", "uefa_euro_2028_qualifying")) {
    file.copy(
      file.path(source_accepted_root, edition_id),
      accepted_root,
      recursive = TRUE,
      copy.date = TRUE
    )
  }
  for (name in c("source_artifacts.csv", "source_bundles.csv")) {
    file.copy(file.path(phase13_publication_test_project_root, "data/competition/registries", name), registry_root)
  }

  artifacts <- phase13_publication_test_read_csv(file.path(registry_root, "source_artifacts.csv"))
  identity_map <- phase13_publication_test_read_csv(
    file.path(phase13_publication_test_project_root, "data/competition/registries/team_identity.csv")
  )
  identity_map <- identity_map[, phase13_team_identity_required_columns(), drop = FALSE]

  nl <- "uefa_nations_league_2026_27"
  nl_fixture_artifact <- artifacts$source_artifact_id[artifacts$edition_id == nl & artifacts$artifact_type == "fixtures"][[1L]]
  nl_result_artifact <- artifacts$source_artifact_id[artifacts$edition_id == nl & artifacts$artifact_type == "results"][[1L]]
  normalized_fixture_seed <- phase13_publication_test_read_csv(file.path(accepted_root, nl, "fixtures.csv"))
  source_fixtures <- phase13_publication_test_source_fixture_rows(normalized_fixture_seed)
  normalized_fixtures <- phase13_normalize_fixture_rows(
    source_fixtures,
    identity_map = identity_map,
    edition_id = nl,
    source_artifact_id = nl_fixture_artifact,
    lifecycle_state = "scheduled"
  )
  normalized_result_seed <- phase13_publication_test_read_csv(file.path(accepted_root, nl, "results.csv"))
  source_results <- phase13_publication_test_source_result_rows(normalized_result_seed)
  normalized_results <- phase13_normalize_accepted_result_rows(
    source_results,
    normalized_fixtures = normalized_fixtures,
    edition_id = nl,
    source_artifact_id = nl_result_artifact,
    lifecycle_state = "scheduled"
  )
  phase13_publication_test_write_csv(normalized_fixtures, file.path(accepted_root, nl, "fixtures.csv"))
  phase13_publication_test_write_csv(normalized_results, file.path(accepted_root, nl, "results.csv"))

  euro <- "uefa_euro_2028_qualifying"
  phase13_publication_test_write_csv(
    phase13_empty_normalized_fixture_rows(),
    file.path(accepted_root, euro, "fixtures.csv")
  )
  phase13_publication_test_write_csv(
    phase13_empty_normalized_result_rows(),
    file.path(accepted_root, euro, "results.csv")
  )

  targets <- phase13_normalized_resource_targets(root)
  list(
    root = root,
    accepted_root = accepted_root,
    registry_root = registry_root,
    artifacts = artifacts,
    targets = targets,
    actual_targets = phase13_normalized_resource_targets(phase13_publication_test_project_root),
    editions = c(nl, euro),
    resource_types = phase13_source_required_resource_types()
  )
}

test_that("Wave 8 exposes the canonical table/hash API and complete resource target vector", {
  phase13_publication_test_load_apis()
  phase13_publication_test_require_api(c(
    "phase13_normalized_resource_targets",
    "phase13_refresh_canonical_table_hashes"
  ))
  targets <- phase13_normalized_resource_targets(phase13_publication_test_project_root)
  expect_length(targets, 10L)
  expect_named(targets)
  expect_setequal(
    basename(targets),
    paste0(rep(phase13_source_required_resource_types(), 2L), ".csv")
  )
  expect_error(
    phase13_normalized_resource_targets(
      phase13_publication_test_project_root,
      editions = c("uefa_nations_league_2026_27", "uefa_nations_league_2026_27")
    ),
    "duplicate|edition|target"
  )
})

test_that("canonical refresh rewrites all ten staged tables and preserves raw provenance", {
  fixture <- phase13_publication_test_seed()
  before_durable <- lapply(fixture$actual_targets, phase13_publication_test_bytes)
  refreshed <- phase13_refresh_canonical_table_hashes(
    staged_root = fixture$root,
    table_targets = fixture$targets,
    source_artifacts = fixture$artifacts
  )

  expect_true(is.list(refreshed))
  expect_true(all(c("tables", "source_artifacts", "table_hashes") %in% names(refreshed)))
  expect_length(refreshed$tables, 10L)
  expect_length(refreshed$table_hashes, 10L)
  expect_equal(nrow(refreshed$source_artifacts), nrow(fixture$artifacts))
  expect_true(all(grepl("^[0-9a-f]{64}$", refreshed$table_hashes)))

  for (key in names(fixture$targets)) {
    path <- fixture$targets[[key]]
    table <- phase13_publication_test_read_csv(path)
    expect_identical(names(table), names(refreshed$tables[[key]]))
    if (nrow(table)) expect_equal(table, refreshed$tables[[key]])
    if (!nrow(table)) expect_equal(nrow(refreshed$tables[[key]]), 0L)
    expect_identical(
      digest::digest(phase13_publication_test_bytes(path), algo = "sha256", serialize = FALSE),
      refreshed$table_hashes[[key]]
    )
    expect_equal(as.character(table$row_sha256), phase13_row_sha256(table))
  }

  for (edition_id in fixture$editions) {
    for (artifact_type in fixture$resource_types) {
      table <- refreshed$tables[[paste(edition_id, artifact_type, sep = "::")]]
      links <- refreshed$source_artifacts[
        refreshed$source_artifacts$edition_id == edition_id &
          refreshed$source_artifacts$artifact_type == artifact_type,
        , drop = FALSE
      ]
      expect_equal(nrow(links), 1L)
      expect_identical(links$canonical_content_sha256[[1L]], refreshed$table_hashes[[paste(edition_id, artifact_type, sep = "::")]])
      expect_identical(as.character(table$edition_id), rep(edition_id, nrow(table)))
      if (nrow(table)) expect_true(all(nzchar(as.character(table$source_artifact_id))))
    }
  }

  provenance <- c(
    "raw_sha256", "source_url", "retrieved_at_utc", "parser_commit_sha",
    "fallback_status", "review_state", "artifact_id", "source_artifact_id",
    "bundle_id", "edition_id", "artifact_type"
  )
  expect_identical(refreshed$source_artifacts[provenance], fixture$artifacts[provenance])
  expect_false(any(vapply(seq_along(fixture$actual_targets), function(index) {
    !identical(phase13_publication_test_bytes(fixture$actual_targets[[index]]), before_durable[[index]])
  }, logical(1))))
})

test_that("canonical content is order-stable while row identity changes only with content", {
  fixture <- phase13_publication_test_seed()
  baseline <- phase13_refresh_canonical_table_hashes(
    fixture$root, fixture$targets, fixture$artifacts
  )
  fixture_path <- fixture$targets[["uefa_nations_league_2026_27::fixtures"]]
  reordered <- phase13_publication_test_read_csv(fixture_path)
  reordered <- reordered[rev(seq_len(nrow(reordered))), , drop = FALSE]
  phase13_publication_test_write_csv(reordered, fixture_path)
  reordered_result <- phase13_refresh_canonical_table_hashes(
    fixture$root, fixture$targets, fixture$artifacts
  )
  expect_identical(
    baseline$tables[["uefa_nations_league_2026_27::fixtures"]]$row_sha256,
    reordered_result$tables[["uefa_nations_league_2026_27::fixtures"]]$row_sha256
  )
  expect_identical(
    baseline$table_hashes[["uefa_nations_league_2026_27::fixtures"]],
    reordered_result$table_hashes[["uefa_nations_league_2026_27::fixtures"]]
  )

  changed <- reordered_result$tables[["uefa_nations_league_2026_27::fixtures"]]
  changed$status[[1L]] <- "in_progress"
  phase13_publication_test_write_csv(changed, fixture_path)
  changed_result <- phase13_refresh_canonical_table_hashes(
    fixture$root, fixture$targets, fixture$artifacts
  )
  expect_false(identical(
    baseline$table_hashes[["uefa_nations_league_2026_27::fixtures"]],
    changed_result$table_hashes[["uefa_nations_league_2026_27::fixtures"]]
  ))
  expect_false(identical(
    baseline$tables[["uefa_nations_league_2026_27::fixtures"]]$row_sha256,
    changed_result$tables[["uefa_nations_league_2026_27::fixtures"]]$row_sha256
  ))
})

test_that("EURO pre_draw normalized empty tables receive complete schemas and hashes", {
  fixture <- phase13_publication_test_seed()
  refreshed <- phase13_refresh_canonical_table_hashes(fixture$root, fixture$targets, fixture$artifacts)
  expect_identical(
    names(refreshed$tables[["uefa_euro_2028_qualifying::fixtures"]]),
    phase13_normalized_fixture_schema()
  )
  expect_identical(
    names(refreshed$tables[["uefa_euro_2028_qualifying::results"]]),
    phase13_normalized_result_schema()
  )
  expect_equal(nrow(refreshed$tables[["uefa_euro_2028_qualifying::fixtures"]]), 0L)
  expect_equal(nrow(refreshed$tables[["uefa_euro_2028_qualifying::groups"]]), 0L)
  expect_equal(nrow(refreshed$tables[["uefa_euro_2028_qualifying::standings"]]), 0L)
  expect_equal(nrow(refreshed$tables[["uefa_euro_2028_qualifying::results"]]), 0L)
  expect_match(refreshed$table_hashes[["uefa_euro_2028_qualifying::fixtures"]], "^[0-9a-f]{64}$")
  expect_match(refreshed$table_hashes[["uefa_euro_2028_qualifying::groups"]], "^[0-9a-f]{64}$")
})

test_that("resource target validation rejects unsafe, duplicate, incomplete, and cross-edition links", {
  fixture <- phase13_publication_test_seed()
  expect_error(
    phase13_refresh_canonical_table_hashes(
      fixture$root,
      c(fixture$targets[[1L]], file.path(fixture$root, "../outside.csv")),
      fixture$artifacts
    ),
    "unsafe|trusted|target"
  )
  expect_error(
    phase13_refresh_canonical_table_hashes(
      fixture$root,
      fixture$targets[-1L],
      fixture$artifacts
    ),
    "ten|complete|required|target"
  )
  duplicated <- fixture$targets
  duplicated[[length(duplicated) + 1L]] <- duplicated[[1L]]
  names(duplicated)[[length(duplicated)]] <- "duplicate::fixtures"
  expect_error(
    phase13_refresh_canonical_table_hashes(fixture$root, duplicated, fixture$artifacts),
    "duplicate|target"
  )
  cross_edition <- fixture$targets
  cross_edition[["uefa_nations_league_2026_27::fixtures"]] <-
    cross_edition[["uefa_euro_2028_qualifying::fixtures"]]
  expect_error(
    phase13_refresh_canonical_table_hashes(fixture$root, cross_edition, fixture$artifacts),
    "edition|cross|target"
  )
})

test_that("malformed source-artifact links fail closed before staged output is returned", {
  fixture <- phase13_publication_test_seed()
  missing_artifact <- fixture$artifacts[-1L, , drop = FALSE]
  expect_error(
    phase13_refresh_canonical_table_hashes(fixture$root, fixture$targets, missing_artifact),
    "artifact|link|complete|required"
  )

  forged <- fixture$artifacts
  forged$source_artifact_id[[1L]] <- "forged-source-artifact"
  expect_error(
    phase13_refresh_canonical_table_hashes(fixture$root, fixture$targets, forged),
    "artifact|link|source|hash"
  )

  cross_edition <- fixture$artifacts
  nl_fixture_index <- which(
    cross_edition$edition_id == "uefa_nations_league_2026_27" &
      cross_edition$artifact_type == "fixtures"
  )[[1L]]
  cross_edition$edition_id[[nl_fixture_index]] <- "uefa_euro_2028_qualifying"
  expect_error(
    phase13_refresh_canonical_table_hashes(fixture$root, fixture$targets, cross_edition),
    "edition|cross|artifact"
  )
})
