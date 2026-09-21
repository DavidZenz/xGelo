library(testthat)

if (!exists("phase20_fixture_graph_36x144", envir = .GlobalEnv, mode = "function")) {
  project_root <- normalizePath(
    file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
    winslash = "/", mustWork = TRUE
  )
  source(file.path(project_root, "tests/testthat/helper_uefa_champions_league.R"), local = .GlobalEnv)
}
if (!exists("ucl_validate_schedule", envir = .GlobalEnv, mode = "function")) {
  project_root <- normalizePath(
    file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
    winslash = "/", mustWork = TRUE
  )
  source(file.path(project_root, "R/competition/uefa_champions_league_rules.R"), local = .GlobalEnv)
  source(file.path(project_root, "R/competition/uefa_champions_league_state.R"), local = .GlobalEnv)
}

test_that("completed prior rows require complete identity, lineage, and row integrity", {
  graph <- phase20_test_completed_fixture_graph()
  state <- ucl_build_state(graph, state_cutoff_utc = "2026-09-21T00:00:00Z")
  release <- phase20_approved_release_fixture(graph)

  tampered <- release$forecast_rows
  tampered$prob_home[[1L]] <- 0.99
  rebuilt <- ucl_build_forecast_ledger(
    state, release = release, prior_ledger = tampered,
    state_cutoff_utc = "2026-09-21T00:00:00Z"
  )
  expect_identical(rebuilt$ledger$suppression_reason[[1L]], "prior_row_hash_mismatch")
  expect_identical(rebuilt$ledger$forecast_status[[1L]], "suppressed")

  schema_tampered <- release$forecast_rows
  schema_tampered$row_sha256 <- NULL
  rebuilt_schema <- ucl_build_forecast_ledger(
    state, release = release, prior_ledger = schema_tampered,
    state_cutoff_utc = "2026-09-21T00:00:00Z"
  )
  expect_identical(rebuilt_schema$ledger$suppression_reason[[1L]], "prior_schema_invalid")
})

test_that("ledger cutoff is explicit and a Phase 19 release without rows blocks", {
  graph <- phase20_fixture_graph_36x144()
  expect_identical(
    ucl_build_state(graph)$reason_code,
    "state_cutoff_required"
  )
  expect_identical(
    ucl_build_state(graph, state_cutoff_utc = "2099-12-31T23:59:59Z")$reason_code,
    "state_cutoff_sentinel_forbidden"
  )

  state <- ucl_build_state(graph, state_cutoff_utc = "2026-09-21T00:00:00Z")
  production_without_rows <- function() list(
    authority_mode = "production", fixture_authority = FALSE,
    production_eligible = TRUE, selector = list(authorized = TRUE),
    release_id = "phase19-production-release-v1",
    model_sha256 = paste(rep("a", 64L), collapse = ""),
    calibrator_sha256 = paste(rep("b", 64L), collapse = "")
  )
  blocked <- ucl_build_forecast_ledger(
    state, state_cutoff_utc = "2026-09-21T00:00:00Z",
    production_resolver = production_without_rows
  )
  expect_s3_class(blocked, "ucl_blocked_state")
  expect_identical(blocked$status, "production_blocked")
  expect_identical(blocked$reason_code, "phase19_forecast_rows_missing")
  expect_null(blocked$ledger)
  expect_null(blocked$forecast_rows)
})

test_that("mixed release lineage and forged production callers cannot be promoted", {
  graph <- phase20_fixture_graph_36x144()
  state <- ucl_build_state(graph, state_cutoff_utc = "2026-09-21T00:00:00Z")
  release <- phase20_approved_release_fixture(graph)
  mixed <- release
  mixed$forecast_rows$model_sha256[[2L]] <- phase20_test_hash("different-model")
  mixed_result <- ucl_build_forecast_ledger(
    state, release = mixed, state_cutoff_utc = "2026-09-21T00:00:00Z"
  )
  expect_identical(mixed_result$status, "production_blocked")
  expect_identical(mixed_result$reason_code, "release_lineage_mixed")

  forged <- release
  forged$authority_mode <- "production"
  forged$fixture_authority <- FALSE
  forged$production_eligible <- TRUE
  forged$selector_authorized <- TRUE
  forged_result <- ucl_build_forecast_ledger(
    state, release = forged,
    state_cutoff_utc = "2026-09-21T00:00:00Z",
    production_resolver = function() stop("selector unavailable", call. = FALSE)
  )
  expect_identical(forged_result$status, "production_blocked")
  expect_identical(forged_result$reason_code, "phase19_release_not_authorized")
})

test_that("graph identity covers settled semantics and rejects forged metadata", {
  graph <- phase20_fixture_graph_36x144()
  base <- ucl_validate_schedule(graph)
  expect_identical(base$status, "ready")

  settled <- phase20_test_completed_fixture_graph(graph, index = 1L, home_goals = 2L, away_goals = 1L)
  settled_changed <- settled
  settled_changed$fixtures$regulation_home_goals[[1L]] <- 3L
  settled_changed$fixtures$final_home_goals[[1L]] <- 3L
  changed <- ucl_validate_schedule(settled_changed)
  expect_identical(changed$status, "ready")
  expect_false(identical(
    ucl_validate_schedule(settled)$graph_sha256,
    changed$graph_sha256
  ))

  delimiter_left <- graph
  delimiter_left$fixtures$source_artifact_id[[1L]] <- "source|artifact"
  delimiter_left$fixtures$source_row_key[[1L]] <- "row"
  delimiter_right <- graph
  delimiter_right$fixtures$source_artifact_id[[1L]] <- "source"
  delimiter_right$fixtures$source_row_key[[1L]] <- "artifact|row"
  left <- ucl_validate_schedule(delimiter_left)
  right <- ucl_validate_schedule(delimiter_right)
  expect_identical(left$status, "ready")
  expect_identical(right$status, "ready")
  expect_false(identical(left$graph_sha256, right$graph_sha256))

  forged_bundle <- graph
  forged_bundle$source_bundle_id <- "caller-forged-bundle"
  expect_identical(
    ucl_validate_schedule(forged_bundle)$reason_code,
    "lineage_bundle_metadata_mismatch"
  )
  forged_lineage <- graph
  forged_lineage$source_lineage_id <- "caller-forged-lineage"
  expect_identical(
    ucl_validate_schedule(forged_lineage)$reason_code,
    "lineage_metadata_mismatch"
  )
  forged_authority <- graph
  forged_authority$production_eligible <- TRUE
  expect_identical(
    ucl_validate_schedule(forged_authority)$reason_code,
    "source_authority_invalid"
  )
  marker_missing <- graph
  marker_missing$fixtures$fixture_authority <- NULL
  expect_identical(
    ucl_validate_schedule(marker_missing)$reason_code,
    "source_authority_invalid"
  )
})

test_that("Phase 14 absence blocks production and fixture fallback is non-promotable", {
  graph <- phase20_fixture_graph_36x144()
  fixture_state <- NULL
  old_source_phase14 <- get(".ucl_state_source_phase14", envir = .GlobalEnv)
  old_bundle_validator_exists <- exists("phase18_validate_ucl_source_bundle", envir = .GlobalEnv, mode = "function")
  old_bundle_validator <- if (old_bundle_validator_exists) get("phase18_validate_ucl_source_bundle", envir = .GlobalEnv) else NULL
  on.exit({
    assign(".ucl_state_source_phase14", old_source_phase14, envir = .GlobalEnv)
    if (old_bundle_validator_exists) {
      assign("phase18_validate_ucl_source_bundle", old_bundle_validator, envir = .GlobalEnv)
    } else if (exists("phase18_validate_ucl_source_bundle", envir = .GlobalEnv, inherits = FALSE)) {
      rm("phase18_validate_ucl_source_bundle", envir = .GlobalEnv)
    }
  }, add = TRUE)

  assign(".ucl_state_source_phase14", function() FALSE, envir = .GlobalEnv)
  fixture_state <- ucl_build_state(graph, state_cutoff_utc = "2026-09-21T00:00:00Z")
  expect_identical(fixture_state$status, "ready")
  expect_identical(fixture_state$standings_authority, "fixture_fallback_non_promotable")
  expect_false(isTRUE(fixture_state$production_eligible))

  production <- graph
  production$fixtures$fixture_authority <- FALSE
  production$fixtures$production_eligible <- TRUE
  production$authority_mode <- "production"
  production$fixture_authority <- FALSE
  production$production_eligible <- TRUE
  bundle <- data.frame(
    bundle_id = graph$source_bundle_id,
    bundle_sha256 = paste(rep("c", 64L), collapse = ""),
    edition_id = graph$edition_id,
    stringsAsFactors = FALSE, check.names = FALSE
  )
  production$source_bundle_evidence <- list(bundle = bundle, tables = list(), authority = list())
  assign("phase18_validate_ucl_source_bundle", function(...) invisible(TRUE), envir = .GlobalEnv)
  production_validation <- ucl_validate_schedule(production)
  expect_identical(production_validation$status, "ready")
  production_state <- ucl_build_state(production, state_cutoff_utc = "2026-09-21T00:00:00Z")
  expect_s3_class(production_state, "ucl_blocked_state")
  expect_identical(production_state$reason_code, "phase14_authority_missing")
})

test_that("rules evidence uses a pinned sidecar and framed value identity", {
  rules <- .ucl_rule_contract()
  expect_identical(
    rules$evidence_sidecar_sha256,
    "5a77b6b5a7c97d35a8afa49d35e120ccba880a833b31b2f022e667a3291ffbf8"
  )
  expect_false(identical(
    .ucl_rule_hash(list(left = "a\u001fb", right = "c")),
    .ucl_rule_hash(list(left = "a", right = "b\u001fc"))
  ))

  source_path <- file.path(
    normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
                  winslash = "/", mustWork = TRUE),
    "data/competition/rules/ucl_2026_27_rules_and_draw_evidence.json"
  )
  tampered_path <- tempfile("ucl-rules-tampered-", fileext = ".json")
  expect_true(file.copy(source_path, tampered_path, overwrite = TRUE))
  on.exit(unlink(tampered_path), add = TRUE)
  writeBin(c(readBin(tampered_path, what = "raw", n = file.info(tampered_path)$size), as.raw(0L)), tampered_path)
  expect_error(.ucl_rule_verify_evidence_sidecar(tampered_path), "pinned reviewed artifact")
})
