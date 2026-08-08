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
