library(testthat)

ucl_live_root <- normalizePath(if (basename(getwd()) == "testthat") "../.." else ".", mustWork = TRUE)
# Reuse source-contract fixture constructors without executing their tests.
for (expr in parse(file.path(ucl_live_root, "tests/testthat/test_phase18_source_bundle.R"))) {
  if (!is.call(expr) || !identical(expr[[1L]], as.name("test_that"))) eval(expr, envir = .GlobalEnv)
}

ucl_live_test_current <- function() {
  phase18_bundle_test_load()
  for (path in c("R/competition/ucl_source_refresh.R", "R/dashboard/edition_registry_v2.R",
    "R/dashboard/payload_contract_v2.R", "R/dashboard/payload_ucl.R", "R/dashboard/renderer_v2.R")) {
    source(file.path(ucl_live_root, path), local = .GlobalEnv)
  }
  evidence <- phase18_bundle_test_provider_evidence("approved_no_durable_raw_cache")
  projected <- phase18_bundle_test_projected(evidence)
  for (field in c("won", "drawn", "lost", "goals_for", "goals_against", "goal_difference")) projected$standings[[field]] <- 0L
  projected$standings$row_sha256 <- phase18_ucl_projected_row_hash(projected$standings)
  projected$matches$matchday <- rep(1:8, length.out = 144L)
  projected$matches$home_score <- rep(NA_integer_, 144L)
  projected$matches$away_score <- rep(NA_integer_, 144L)
  projected$matches$status[[1L]] <- "FINISHED"
  projected$matches$home_score[[1L]] <- 2L
  projected$matches$away_score[[1L]] <- 1L
  projected$matches$row_sha256 <- phase18_ucl_projected_row_hash(projected$matches)
  candidate <- phase18_build_ucl_source_bundle(projected, phase18_bundle_test_fetched(),
    list(authority_type = "provider_acceptance", provider_acceptance = evidence),
    evidence$edition_expectations, "live-dashboard-fixture")
  ref <- list(accepted_status = "accepted", accepted_generation_id = "fixture-generation",
    accepted_generation_sha256 = strrep("a", 64L))
  list(pointer = ref, state = ref, history = data.frame(), accepted = candidate, sidecar = NULL)
}

test_that("accepted live facts remain available without any forecast authority", {
  current <- ucl_live_test_current()
  payload <- phase21_payload_ucl_live_source(current, now_utc = "2026-09-19T13:00:00Z")
  expect_identical(payload$metadata$source_status, "accepted")
  expect_identical(payload$metadata$forecast_status, "unavailable")
  expect_false(payload$metadata$production_eligible)
  expect_true(is.na(payload$metadata$model_release_id))
  expect_length(payload$sections$standings$rows, 36L)
  expect_length(payload$sections$fixtures$rows, 143L)
  expect_length(payload$sections$results$rows, 1L)
  expect_true(is.na(payload$sections$fixtures$rows[[1L]]$Score))
  expect_identical(payload$sections$results$rows[[1L]]$Score, "2–1")
  expect_identical(payload$sections$match_forecasts$status, "unavailable")
  expect_length(payload$sections$match_forecasts$rows, 0L)
  expect_match(payload$credits$attribution, "Football-Data.org API", fixed = TRUE)
  html <- phase21_render_dashboard(payload)
  expect_match(html, "<details", fixed = TRUE)
  expect_false(grepl("Phase 20", html, fixed = TRUE))
  stale <- phase21_payload_ucl_live_source(current, now_utc = "2026-09-22T13:00:00Z")
  expect_identical(stale$sections$standings$status, "stale")
  expect_true(stale$metadata$showing_last_accepted_snapshot)
})

test_that("unaccepted or tampered live facts cannot produce an accepted dashboard", {
  current <- ucl_live_test_current()
  invalid <- current
  invalid$pointer$accepted_status <- "no_incumbent"
  expect_error(phase21_payload_ucl_live_source(invalid), "accepted UCL")
  invalid <- current
  invalid$accepted$tables$standings$points[[1L]] <- 999L
  expect_error(phase21_payload_ucl_live_source(invalid), class = "phase18_ucl_bundle_error")
})

test_that("the isolated production runtime can read receipt-backed current-source candidates", {
  current <- ucl_live_test_current()
  root <- tempfile("ucl-isolated-receipt-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  phase18_write_ucl_candidate(root, current$accepted)
  importer <- new.env(parent = globalenv())
  withr::local_dir(ucl_live_root)
  sys.source(file.path(ucl_live_root, "scripts/build_uefa_champions_league_outcomes.R"), envir = importer)
  runtime <- importer$phase20_ucl_runtime
  expect_identical(parent.env(runtime), baseenv())
  candidate <- runtime$phase18_read_ucl_candidate(root)
  expect_silent(runtime$phase18_validate_ucl_source_bundle(candidate))
  expect_length(candidate$raw_bytes, 0L)
})
