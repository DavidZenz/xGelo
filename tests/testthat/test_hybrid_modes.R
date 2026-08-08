library(testthat)

source(file.path(
  normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else ".")),
  "tests/testthat/helper_hybrid_phase11.R"
))
hybrid_source_if_present("R/benchmark/hybrid_adapters.R")
hybrid_require_modes_api()

test_that("HYBRID-05 / D-13 through D-16 keep open, enriched, and external modes separate", {
  registry <- canonical_phase11_mode_registry()
  expect_silent(validate_hybrid_mode_registry(registry))

  expect_true(is.data.frame(registry))
  expect_setequal(
    as.character(registry$mode_id),
    c("open_default", "enriched_squad", "external_market")
  )
  expect_true(all(c(
    "mode_id", "panel_id", "vintage_id", "source_artifact_sha256",
    "derived_only_publication", "license_class", "active_status",
    "promotion_boundary", "research_only"
  ) %in% names(registry)))
  expect_identical(
    registry$panel_id[match("open_default", registry$mode_id)],
    "open_core"
  )
  expect_identical(
    registry$panel_id[match("enriched_squad", registry$mode_id)],
    "feature_rich"
  )
  expect_false(anyDuplicated(paste(registry$mode_id, registry$panel_id)))
  expect_true(all(grepl("^[0-9a-f]{64}$", registry$source_artifact_sha256)))
  expect_true(all(nzchar(registry$vintage_id)))
  expect_true(all(nzchar(registry$license_class)))
  expect_true(all(registry$derived_only_publication))
  expect_true(all(registry$research_only))

  open <- registry[registry$mode_id == "open_default", , drop = FALSE]
  optional <- registry[registry$mode_id != "open_default", , drop = FALSE]
  expect_true(any(open$promotion_boundary %in% c("open_default", "open_default_candidate")))
  expect_false(any(grepl("open_default|promotion", optional$promotion_boundary, ignore.case = TRUE)))
  expect_true(all(optional$active_status %in% c("active", "inactive")))
})

test_that("HYBRID-05 / D-13 rejects pooled or raw restricted mode declarations", {
  registry <- canonical_phase11_mode_registry()

  pooled <- registry
  pooled$panel_id[pooled$mode_id == "enriched_squad"] <- "open_core"
  expect_error(validate_hybrid_mode_registry(pooled), "panel|separate|feature_rich")

  raw <- registry
  raw$derived_only_publication[raw$mode_id == "enriched_squad"] <- FALSE
  expect_error(validate_hybrid_mode_registry(raw), "derived|raw|restricted")
})

test_that("HYBRID-05 / D-14 validates manually frozen external probabilities only", {
  snapshot <- hybrid_manual_market_snapshot()
  cutoffs <- hybrid_manual_market_cutoffs()

  expect_silent(validate_manual_market_snapshot(
    snapshot,
    fixture_cutoffs = cutoffs
  ))
  converted <- market_probabilities_to_benchmark_predictions(
    snapshot = snapshot,
    fixture_cutoffs = cutoffs
  )
  expect_true(is.data.frame(converted))
  expect_true(all(c(
    "fixture_id", "p_home", "p_draw", "p_away", "mode_id", "active_status"
  ) %in% names(converted)))
  expect_true(all(converted$mode_id == "external_market"))
  expect_true(all(converted$active_status == "active"))

  bad_probability <- snapshot
  bad_probability$p_home[1] <- 0.90
  expect_error(
    validate_manual_market_snapshot(bad_probability, fixture_cutoffs = cutoffs),
    "probabil|sum|normal",
    ignore.case = TRUE
  )

  bad_timestamp <- snapshot
  bad_timestamp$captured_at_utc[1] <- NA_character_
  expect_error(
    validate_manual_market_snapshot(bad_timestamp, fixture_cutoffs = cutoffs),
    "timestamp|captured|date",
    ignore.case = TRUE
  )

  bad_live_path <- snapshot
  bad_live_path$source_url_or_label[1] <- "curl bookmaker live scrape"
  expect_error(
    validate_manual_market_snapshot(bad_live_path, fixture_cutoffs = cutoffs),
    "live|collect|scrap|network",
    ignore.case = TRUE
  )

  bad_raw <- snapshot
  bad_raw$raw_bookmaker_row <- "restricted raw source"
  expect_error(
    validate_manual_market_snapshot(bad_raw, fixture_cutoffs = cutoffs),
    "raw|restricted|derived",
    ignore.case = TRUE
  )
})

test_that("HYBRID-05 / enriched adapter is derived-only and feature-rich", {
  metadata <- hybrid_enriched_squad_adapter_metadata()

  expect_true(is.data.frame(metadata))
  expect_equal(metadata$mode_id, "enriched_squad")
  expect_equal(metadata$panel_id, "feature_rich")
  expect_equal(metadata$source_id, "transfermarkt_squad_snapshot_local")
  expect_true(isTRUE(metadata$derived_only_publication))
  expect_false(isTRUE(metadata$open_mode_compatible))
  expect_true(grepl("transfermarkt_squad_strength", metadata$source_artifact_path, fixed = TRUE))
  expect_true(nzchar(metadata$inactive_reason) || identical(metadata$active_status, "active"))
  expect_false(any(c("player_id", "market_value_in_eur") %in% names(metadata)))

  aggregates <- read_hybrid_enriched_squad_aggregates()
  expect_true(is.data.frame(aggregates))
  expect_true(all(c("team", "as_of_date", "feature_source_date", "log_squad_value") %in% names(aggregates)))
  expect_false(any(grepl("player_id|market_value|current_club", names(aggregates), ignore.case = TRUE)))
})

test_that("HYBRID-05 / missing manual market input is explicit and non-blocking", {
  absent_path <- tempfile("phase11-market-absent-", fileext = ".csv")
  snapshot <- read_manual_market_snapshot(absent_path)

  expect_true(is.data.frame(snapshot))
  expect_equal(nrow(snapshot), 0L)
  expect_equal(attr(snapshot, "active_status"), "inactive")
  expect_match(attr(snapshot, "inactive_reason"), "absent|unavailable|missing", ignore.case = TRUE)
  expect_silent(validate_manual_market_snapshot(snapshot))

  manifest_path <- file.path(hybrid_project_root, "data/benchmark/phase11/manual_market_manifest.csv")
  expect_true(file.exists(manifest_path))
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
  expect_true(all(c(
    "snapshot_id", "fixture_id", "home_team_id", "away_team_id", "market_date",
    "captured_at_utc", "source_name", "source_url_or_label", "license_class",
    "redistribution_allowed", "manual_freeze_operator", "p_home", "p_draw", "p_away",
    "source_sha256", "row_sha256", "active_status"
  ) %in% names(manifest)))
  expect_silent(validate_manual_market_manifest(manifest))
})

test_that("HYBRID-05 / external probabilities remain a reference panel", {
  snapshot <- hybrid_manual_market_snapshot()
  predictions <- market_probabilities_to_benchmark_predictions(snapshot)

  expect_equal(predictions$panel_id, rep("external_reference", nrow(predictions)))
  expect_false(any(predictions$open_mode_compatible))
  expect_true(all(predictions$research_only))
  expect_true(all(predictions$wc2026_sealed))
  expect_true(all(predictions$promotion_boundary == "external_reference_only"))
  expect_false(any(predictions$mode_id == "open_default"))
})
