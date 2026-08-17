library(testthat)

phase14_nl_production_test_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase14_nl_production_test_load_apis <- function() {
  paths <- file.path(
    phase14_nl_production_test_root,
    c(
      "R/elo/preprocess.R",
      "R/release/release_contract.R",
      "R/competition/source_contracts.R",
      "R/competition/team_identity.R",
      "R/competition/edition_registry.R",
      "R/competition/match_state.R",
      "R/competition/uefa_nations_league_adapter.R"
    )
  )
  for (path in paths) if (file.exists(path)) source(path, local = .GlobalEnv)
  invisible(TRUE)
}

phase14_nl_production_test_read <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = "")
}

phase14_nl_production_test_sha256 <- function(path) {
  bytes <- readBin(path, what = "raw", n = file.info(path)$size)
  digest::digest(bytes, algo = "sha256", serialize = FALSE)
}

test_that("production Nations League snapshot is the complete official UEFA schedule", {
  phase14_nl_production_test_load_apis()
  registries <- load_competition_edition_registries(
    registry_dir = file.path(phase14_nl_production_test_root, "data/competition/registries"),
    project_root = phase14_nl_production_test_root,
    accepted_root = file.path(phase14_nl_production_test_root, "data/competition/accepted"),
    raw_root = file.path(phase14_nl_production_test_root, "data/competition/local_raw")
  )
  snapshots <- registries$accepted_snapshots
  nations <- snapshots[["uefa_nations_league_2026_27"]]
  fixtures <- nations$fixtures
  groups <- nations$groups
  standings <- nations$standings
  results <- nations$results
  identity <- attr(registries, "team_identity")
  bundles <- attr(registries, "source_bundles")
  artifacts <- attr(registries, "source_artifacts")
  bundle_id <- "nl-2026-27-official-uefa-v2"

  expect_identical(as.character(nations$status$competition_status), "scheduled")
  expect_equal(nrow(fixtures), 156L)
  expect_equal(nrow(groups), 14L)
  expect_equal(nrow(standings), 0L)
  expect_equal(nrow(results), 156L)
  expect_equal(length(unique(as.character(fixtures$uefa_source_fixture_id))), 156L)
  expect_equal(length(unique(as.character(groups$source_group_id))), 14L)
  expect_true(all(toupper(as.character(fixtures$source_status)) == "UPCOMING"))
  expect_true(all(as.logical(fixtures$kickoff_confirmed)))
  expect_true(all(nzchar(as.character(fixtures$confirmed_kickoff_at_utc))))
  expect_false(any(
    (as.character(fixtures$home_team_id) == "team_aut" & as.character(fixtures$away_team_id) == "team_deu") |
      (as.character(fixtures$home_team_id) == "team_deu" & as.character(fixtures$away_team_id) == "team_aut")
  ))

  expect_identical(
    as.character(results$uefa_source_fixture_id),
    as.character(fixtures$uefa_source_fixture_id)
  )
  expect_true(all(as.character(results$match_status) == "scheduled"))
  expect_true(all(is.na(results$home_goals) & is.na(results$away_goals)))
  expect_true(all(!as.logical(results$counts_for_standings) & !as.logical(results$counts_for_form)))

  expect_equal(nrow(identity), 54L)
  expect_setequal(
    unique(c(as.character(fixtures$home_team_id), as.character(fixtures$away_team_id))),
    as.character(identity$team_id)
  )
  expect_true(all(as.character(identity$mapping_method) == "source_id"))
  expect_true(all(as.character(identity$mapping_warning) == "none"))
  expect_true(all(nzchar(as.character(identity$canonical_name))))
  expect_true(all(nzchar(as.character(identity$aliases))))
  expect_true(all(nzchar(as.character(identity$uefa_team_code))))
  expect_true(all(!duplicated(as.character(identity$uefa_source_team_id))))

  nl_bundle <- bundles[as.character(bundles$bundle_id) == bundle_id, , drop = FALSE]
  nl_artifacts <- artifacts[as.character(artifacts$bundle_id) == bundle_id, , drop = FALSE]
  expect_equal(nrow(nl_bundle), 1L)
  expect_equal(nrow(nl_artifacts), 5L)
  expect_identical(as.character(nl_bundle$bundle_status), "accepted")
  expect_identical(as.character(nl_bundle$acceptance_state), "accepted")
  expect_identical(as.character(nl_bundle$fallback_status), "official")
  expect_match(as.character(nl_bundle$parser_commit_sha), "^d322121")
  expect_false(any(grepl("sample", c(nl_bundle$bundle_id, nl_artifacts$artifact_id), fixed = TRUE)))
  expect_true(all(as.character(nl_artifacts$source_url) == phase14_uefa_nl_matches_url()))
  expect_true(all(as.character(nl_artifacts$source_url_lineage) == phase14_uefa_nl_matches_url()))
  expect_true(all(as.character(nl_artifacts$raw_sha256) == "a8b9a1d9c4329a33ffa15a447cb84f2cf92c01caac9668f46d3f0f0abeaed4cd"))
  expect_equal(length(unique(as.character(nl_artifacts$retrieved_at_utc))), 1L)

  for (index in seq_len(nrow(nl_artifacts))) {
    raw_path <- file.path(phase14_nl_production_test_root, nl_artifacts$relative_local_raw_path[[index]])
    expect_true(file.exists(raw_path), info = raw_path)
    expect_identical(
      phase14_nl_production_test_sha256(raw_path),
      as.character(nl_artifacts$raw_sha256[[index]])
    )
  }
})

test_that("official Nations League acceptance retains release authority and rebuilds identity hashes", {
  phase14_nl_production_test_load_apis()
  registry_root <- file.path(phase14_nl_production_test_root, "data/competition/registries")
  editions <- phase14_nl_production_test_read(file.path(registry_root, "competition_editions.csv"))
  crosswalk <- phase14_nl_production_test_read(file.path(registry_root, "match_identity.csv"))
  selector <- phase14_nl_production_test_read(file.path(phase14_nl_production_test_root, "outputs/releases/approved_release.csv"))
  fixtures <- phase14_nl_production_test_read(file.path(
    phase14_nl_production_test_root,
    "data/competition/accepted/uefa_nations_league_2026_27/fixtures.csv"
  ))

  expect_equal(nrow(crosswalk), 49832L)
  expect_equal(table(as.character(crosswalk$source_namespace))[["competition_fixture"]], 156L)
  expect_equal(table(as.character(crosswalk$source_namespace))[["competition_result"]], 156L)
  competition_rows <- crosswalk[as.character(crosswalk$edition_id) == "uefa_nations_league_2026_27", , drop = FALSE]
  expect_equal(length(unique(as.character(competition_rows$match_id))), 156L)
  expect_silent(phase14_validate_match_identity_crosswalk(crosswalk))
  expect_setequal(
    as.character(competition_rows$source_match_id),
    as.character(fixtures$uefa_source_fixture_id)
  )

  nations <- editions[as.character(editions$edition_id) == "uefa_nations_league_2026_27", , drop = FALSE]
  euro <- editions[as.character(editions$edition_id) == "uefa_euro_2028_qualifying", , drop = FALSE]
  expect_identical(as.character(nations$active_output_bundle_id), "nl-2026-27-official-uefa-v2")
  expect_identical(as.character(nations$blocked), "FALSE")
  expect_identical(as.character(euro$lifecycle_state), "pre_draw")
  expect_identical(as.character(euro$official_draw_date), "2026-12-06")
  expect_identical(as.character(euro$active_output_bundle_id), "uefa_euro_2028_qualifying-official-v1")
  expect_identical(as.character(nations$model_release_id), "phase14-open-nb-incumbent-calibrated-v1")
  expect_identical(as.character(euro$model_release_id), "phase14-open-nb-incumbent-calibrated-v1")
  expect_identical(as.character(selector$release_id[[1L]]), "phase14-open-nb-incumbent-calibrated-v1")
})
