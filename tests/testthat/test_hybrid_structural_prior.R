library(testthat)

source(file.path(
  normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else ".")),
  "tests/testthat/helper_hybrid_phase11.R"
))
hybrid_require_structural_api()

test_that("HYBRID-04 / D-09 requires vintage, source-date, license, and checksum parents", {
  files <- hybrid_structural_snapshot_fixture()
  cutoff <- as.Date("2010-06-11")
  loaded <- load_structural_prior_snapshots(
    snapshot_path = files$snapshot_path,
    metadata_path = files$metadata_path,
    checksums_path = files$checksums_path,
    evidence_cutoff_exclusive = cutoff
  )

  expect_true(is.data.frame(loaded))
  expect_true(all(c(
    "snapshot_year", "source_date", "vintage_id", "license_class",
    "parent_source_sha256", "row_sha256"
  ) %in% names(loaded)))
  expect_true(all(as.integer(loaded$snapshot_year) < as.integer(format(cutoff, "%Y"))))
  expect_true(all(as.Date(loaded$source_date) < cutoff))
  expect_true(all(nzchar(loaded$vintage_id)))
  expect_true(all(loaded$license_class == "open-or-derived-open"))
  expect_true(all(grepl("^[0-9a-f]{64}$", loaded$parent_source_sha256)))
  expect_true(all(grepl("^[0-9a-f]{64}$", loaded$row_sha256)))

  missing_checksum <- files$checksums
  missing_checksum <- missing_checksum[-nrow(missing_checksum), , drop = FALSE]
  missing_checksum_path <- file.path(files$directory, "missing_checksums.csv")
  utils::write.csv(missing_checksum, missing_checksum_path, row.names = FALSE)
  expect_error(
    load_structural_prior_snapshots(
      snapshot_path = files$snapshot_path,
      metadata_path = files$metadata_path,
      checksums_path = missing_checksum_path,
      evidence_cutoff_exclusive = cutoff
    ),
    "checksum|parent|canonical|registered",
    ignore.case = TRUE
  )
})

test_that("HYBRID-04 / D-10 and D-11 shrink continuously toward a registered structural prior", {
  files <- hybrid_structural_snapshot_fixture()
  cutoff <- as.Date("2010-06-11")
  snapshots <- load_structural_prior_snapshots(
    snapshot_path = files$snapshot_path,
    metadata_path = files$metadata_path,
    checksums_path = files$checksums_path,
    evidence_cutoff_exclusive = cutoff
  )
  signal <- compute_structural_prior_signal(
    snapshots = snapshots,
    team_ids = c("DEU", "FRA", "ITA"),
    evidence_cutoff_exclusive = cutoff
  )

  expect_true(is.data.frame(signal))
  expect_true(all(c(
    "team_id", "structural_prior", "source_date", "vintage_id"
  ) %in% names(signal)))
  expect_true(all(as.Date(signal$source_date) < cutoff))
  expect_true(all(signal$vintage_id == "synthetic_2009_v1"))

  means <- data.frame(
    team_id = c("DEU", "FRA", "ITA"),
    baseline_mean = c(1.80, 1.35, 0.90),
    structural_prior = signal$structural_prior[match(c("DEU", "FRA", "ITA"), signal$team_id)],
    effective_match_count = c(0, 1, 10),
    stringsAsFactors = FALSE
  )
  shrunk <- apply_structural_sparse_shrinkage(
    means = means,
    prior_strength = 4,
    evidence_half_life_days = 730,
    registered_vintage_id = "synthetic_2009_v1"
  )

  expect_true(is.data.frame(shrunk))
  expect_true(all(c(
    "team_id", "prior_weight", "pre_shrinkage_mean",
    "post_shrinkage_mean", "effective_match_count", "prior_strength"
  ) %in% names(shrunk)))
  expect_true(all(shrunk$prior_weight >= 0 & shrunk$prior_weight <= 1))
  expect_true(all(diff(shrunk$prior_weight) < 0))
  expect_true(all(shrunk$post_shrinkage_mean >= pmin(
    shrunk$pre_shrinkage_mean, shrunk$structural_prior
  )))
  expect_true(all(shrunk$post_shrinkage_mean <= pmax(
    shrunk$pre_shrinkage_mean, shrunk$structural_prior
  )))
  expect_equal(unique(shrunk$prior_strength), 4)
  expect_true(any(shrunk$prior_weight > 0 & shrunk$prior_weight < 1))
  expect_false(any(grepl("gdp|population", names(shrunk), ignore.case = TRUE)))
})

test_that("HYBRID-04 / D-09 rejects post-cutoff, current, and ad hoc snapshots", {
  files <- hybrid_structural_snapshot_fixture()
  cutoff <- as.Date("2010-06-11")
  post_cutoff <- files$snapshots
  post_cutoff$source_date[[1L]] <- cutoff
  post_cutoff$row_sha256 <- benchmark_contract_row_hash(post_cutoff, "row_sha256")
  post_directory <- tempfile("hybrid-structural-post-")
  dir.create(post_directory, recursive = TRUE)
  post_path <- file.path(post_directory, "structural_sources.csv")
  post_metadata_path <- file.path(post_directory, "structural_sources_metadata.csv")
  post_checksums_path <- file.path(post_directory, "structural_sources_checksums.csv")
  utils::write.csv(post_cutoff, post_path, row.names = FALSE)
  file.copy(files$metadata_path, post_metadata_path)
  file.copy(files$checksums_path, post_checksums_path)
  expect_error(
    load_structural_prior_snapshots(
      snapshot_path = post_path,
      metadata_path = post_metadata_path,
      checksums_path = post_checksums_path,
      evidence_cutoff_exclusive = cutoff
    ),
    "cutoff|source date|source year",
    ignore.case = TRUE
  )

  current_snapshot <- files$snapshots
  current_snapshot$vintage_id <- "current"
  current_snapshot$row_sha256 <- benchmark_contract_row_hash(current_snapshot, "row_sha256")
  current_directory <- tempfile("hybrid-structural-current-")
  dir.create(current_directory, recursive = TRUE)
  current_path <- file.path(current_directory, "structural_sources.csv")
  current_metadata_path <- file.path(current_directory, "structural_sources_metadata.csv")
  current_checksums_path <- file.path(current_directory, "structural_sources_checksums.csv")
  utils::write.csv(current_snapshot, current_path, row.names = FALSE)
  file.copy(files$metadata_path, current_metadata_path)
  file.copy(files$checksums_path, current_checksums_path)
  expect_error(
    load_structural_prior_snapshots(
      snapshot_path = current_path,
      metadata_path = current_metadata_path,
      checksums_path = current_checksums_path,
      evidence_cutoff_exclusive = cutoff
    ),
    "current|latest|checksum|registered",
    ignore.case = TRUE
  )

  ad_hoc_path <- file.path(files$directory, "ad_hoc_structural.csv")
  file.copy(files$snapshot_path, ad_hoc_path, overwrite = TRUE)
  expect_error(
    load_structural_prior_snapshots(
      snapshot_path = ad_hoc_path,
      metadata_path = files$metadata_path,
      checksums_path = files$checksums_path,
      evidence_cutoff_exclusive = cutoff
    ),
    "checksum|registered|parent",
    ignore.case = TRUE
  )
})

test_that("HYBRID-04 dispatches the registered prior and fails closed when a team snapshot is unavailable", {
  protocol <- load_and_validate_hybrid_protocol()
  registration <- protocol$model_registry[
    protocol$model_registry$candidate_id == "phase11_structural_sparse_prior_open",
    , drop = FALSE
  ]
  expect_equal(nrow(registration), 1L)
  expect_identical(as.character(registration$panel_rule), "open_core")
  expect_identical(as.character(registration$feature_rule), "structural_prior_only_no_raw_fields")
  expect_identical(as.character(registration$structural_snapshot_vintage_id), "worldbank_wdi_2000_v1")
  expect_equal(as.numeric(registration$prior_strength), 4)
  expect_true(grepl("effective_match_count", as.character(registration$effective_count_formula), fixed = TRUE))
  expect_identical(
    as.character(registration$structural_prior_manifest_sha256),
    digest::digest(
      file.path(hybrid_project_root, "data/benchmark/phase11/structural_prior_manifest.csv"),
      algo = "sha256", file = TRUE
    )
  )

  fixtures <- hybrid_rf_fixtures()
  fixtures$track_id <- "frozen"
  fixtures$forecast_sequence <- seq_len(nrow(fixtures))
  fixtures$result_cutoff_exclusive <- fixtures$evidence_cutoff_exclusive
  fixtures$regulation_home_goals <- c(1L, 0L)
  fixtures$regulation_away_goals <- c(0L, 1L)
  fixtures$score_eligible <- TRUE
  result <- run_hybrid_challenger_benchmark(
    history = hybrid_rf_history(),
    fixtures = fixtures,
    candidate_order = "phase11_structural_sparse_prior_open",
    run_id = "phase11_structural_runner_test"
  )
  expect_equal(nrow(result$predictions), 0L)
  expect_equal(nrow(result$distributions), 0L)
  expect_equal(nrow(result$scores), 0L)
  expect_identical(as.character(result$candidate_evidence$active_status), "inactive")
  expect_identical(
    as.character(result$candidate_evidence$score_status),
    "no_score_structural_validation_failed"
  )
  expect_equal(as.integer(result$candidate_evidence$score_row_count), 0L)
  expect_true(grepl("ISO3|snapshot|structural", result$candidate_evidence$inactive_reason, ignore.case = TRUE))
})
