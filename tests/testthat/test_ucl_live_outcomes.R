library(testthat)
live_out_root <- normalizePath(if (basename(getwd()) == "testthat") "../.." else ".", mustWork = TRUE)
for (e in parse(file.path(live_out_root, "tests/testthat/test_ucl_live_bridge.R")))
  if (!is.call(e) || !identical(e[[1L]], as.name("test_that"))) eval(e, .GlobalEnv)
live_out_load <- function() {
  for (path in c("R/competition/uefa_champions_league_simulation.R", "R/competition/uefa_champions_league_outcomes.R",
      "R/competition/ucl_joint_score_view.R", "R/competition/ucl_live_outcomes.R")) source(file.path(live_out_root, path), local = .GlobalEnv)
}

test_that("mixed ledger enters strict simulator mechanics without granting fixture authority", {
  current <- ucl_live_test_current(function(x) {
    # Valid independent circulant schedule: four forward offsets give each
    # club four home/four away matches against eight distinct opponents.
    row <- 0:143; clubs <- as.character(x$clubs$club_id)
    x$matches$home_club_id <- clubs[row %% 36L + 1L]
    x$matches$away_club_id <- clubs[(row %% 36L + row %/% 36L + 1L) %% 36L + 1L]
    x$matches$status <- "FINISHED"; x$matches$home_score <- 0L; x$matches$away_score <- 0L
    x$matches$status[143:144] <- "TIMED"; x$matches$home_score[143:144] <- NA_integer_; x$matches$away_score[143:144] <- NA_integer_
    x
  })
  ucl_bridge_load(); live_out_load()
  bridge <- ucl_live_build_bridge(current, now_utc = "2026-09-19T13:00:00Z")
  expect_identical(bridge$graph_validation$status, "ready")
  ids <- as.character(bridge$fixtures$fixture_id[bridge$fixtures$provider_status == "TIMED"])
  index <- match(ids, bridge$ledger$fixture_id)
  bridge$ledger$forecast_status[index] <- "available"
  bridge$ledger$suppression_reason[index] <- NA_character_
  bridge$ledger$feature_cutoff_utc[index] <- bridge$information_cutoff_utc
  bridge$ledger$prob_home[index] <- .55; bridge$ledger$prob_draw[index] <- .25; bridge$ledger$prob_away[index] <- .20
  bridge$ledger$xg_home[index] <- 1.5; bridge$ledger$xg_away[index] <- 1.1; bridge$ledger$likely_score[index] <- "1-0"
  bridge$ledger$model_release_id[index] <- "fixture-only-no-production-release"
  bridge$ledger$model_sha256[index] <- strrep("a", 64L); bridge$ledger$calibrator_sha256[index] <- strrep("b", 64L)
  bridge$model_lineage <- list(model_release_id = "fixture-only-no-production-release", model_sha256 = strrep("a", 64L), calibrator_sha256 = strrep("b", 64L))
  prediction <- data.frame(fixture_id = ids, model_release_id = "fixture-only-no-production-release", probability_view = "calibrated_1x2", score_distribution_sha256 = strrep("c", 64L))
  grids <- lapply(ids, function(id) { g <- expand.grid(home_goals = 0:40, away_goals = 0:40); g$probability <- 1/nrow(g); g$fixture_id <- id; g })
  forecasts <- list(predictions = prediction, score_distributions = do.call(rbind, grids))
  ledger <- .ucl_live_to_simulation_ledger(bridge, forecasts)
  expect_s3_class(ledger, "ucl_forecast_ledger")
  expect_false(ledger$production_eligible)
  expect_true(ledger$fixture_authority)
  expect_false(.ucl_live_verify_simulation_ledger(ledger, bridge$graph))
  expect_true(.ucl_sim_validate_ledger(ledger, bridge$graph, bridge$information_cutoff_utc)$valid)
  expect_equal(sum(ledger$ledger$forecast_status == "available"), 2L)
  expect_equal(sum(is.na(ledger$ledger$prob_home)), 142L)
  expect_equal(nrow(ledger$joint_score_views), 2L)
  expect_lte(max(ledger$joint_score_views$max_1x2_error), 1e-12)
  # A source-backed-looking fixture is still rejected by the fixed production reader.
  blocked <- ucl_live_build_simulation_ledger(current, forecasts, bridge$information_cutoff_utc)
  expect_identical(blocked$reason_code, "source_parent_changed")
  expect_false(blocked$production_eligible)
})

test_that("CL uncertainty includes finite Monte Carlo intervals and explicit NA absences", {
  live_out_load()
  rows <- data.frame(club_id = c("a", "b", "c"), stage_id = "champion", probability = c(.5, 0, NA_real_), simulation_count = 1000L)
  out <- ucl_live_monte_carlo_uncertainty(rows)
  expect_equal(out$monte_carlo_se[[1L]], sqrt(.25/1000), tolerance = 1e-14)
  expect_lt(out$mc95_lower[[1L]], .5); expect_gt(out$mc95_upper[[1L]], .5)
  expect_equal(out$mc95_lower[[2L]], 0, tolerance = 1e-14)
  expect_gt(out$mc95_upper[[2L]], 0)
  expect_true(is.na(out$mc95_upper[[3L]]))
  rows$probability[[1L]] <- .50001
  expect_error(ucl_live_monte_carlo_uncertainty(rows), "empirical simulation frequencies")
})

test_that("pending sampler review and caller flags never authorize production writes", {
  live_out_load()
  expect_false(.ucl_live_joint_policy_approved())
  result <- .ucl_live_result("team_strength_model_not_promoted", "2026-11-05T19:00:00Z")
  expect_true(ucl_live_validate_result(result))
  forged <- result; forged$production_eligible <- TRUE; forged$status <- "production_ready"
  expect_false(ucl_live_validate_result(forged))
  rejected <- .ucl_live_publish_result(forged)
  expect_false(rejected$production_eligible)
  expect_identical(rejected$status, "production_blocked")
  expect_true("production_writer_not_authorized" %in% rejected$blocked_reason_codes)
  expect_true(phase20_verify_contracts(result))
})

test_that("publication CSV storage round-trips types and nulls independently", {
  current <- ucl_live_test_current(); ucl_bridge_load(); live_out_load()
  directory <- tempfile("ucl-publish-test-"); dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  tables <- list(example = data.frame(id = c("a", "b"), count = c(1L, NA_integer_), value = c(.4, NA_real_), accepted = c(TRUE, FALSE)))
  files <- .ucl_live_write_tables(tables, directory)
  expect_identical(files$example$sha256, digest::digest(file = file.path(directory, "example.csv"), algo = "sha256"))
  expect_identical(files$example$canonical_sha256, .ucl_out_artifact_hash(tables$example))
  expect_identical(files$example$rows, 2L)
})


test_that("private production CLI lookup preserves lexical dependencies and rejects ambient authority", {
  withr::local_dir(file.path(live_out_root,"tests/testthat"))
  importer <- new.env(parent=globalenv())
  sys.source(file.path(live_out_root,"scripts/build_uefa_champions_league_outcomes.R"),envir=importer)
  runtime<-importer$phase20_ucl_runtime
  expect_identical(importer$phase20_ucl_project_root,live_out_root)
  expect_false(importer$phase20_ucl_is_direct())
  expect_silent(runtime$phase19_require_canonical_v2())
  expect_true(runtime$exists("phase18_hash_row_v2",mode="function"))
  marker<-".ucl_untrusted_ambient_lookup_marker";old<-get0(marker,envir=.GlobalEnv,inherits=FALSE)
  assign(marker,function()"untrusted",envir=.GlobalEnv)
  on.exit(if(is.null(old))rm(list=marker,envir=.GlobalEnv)else assign(marker,old,envir=.GlobalEnv),add=TRUE)
  expect_false(runtime$exists(marker,mode="function"))
  expect_true(runtime$exists(marker,envir=.GlobalEnv,mode="function"))
})


test_that("sourced CLI resolves its own file under chdir and an unrelated Rscript wrapper", {
  withr::local_dir(file.path(live_out_root,"tests/testthat"))
  imported <- new.env(parent=globalenv())
  source("../../scripts/build_uefa_champions_league_outcomes.R",local=imported,chdir=TRUE)
  expect_identical(imported$phase20_ucl_project_root,live_out_root)
  expect_false(imported$phase20_ucl_is_direct())
  wrapper <- tempfile("ucl-wrapper-",fileext=".R")
  on.exit(unlink(wrapper),add=TRUE)
  writeLines(c(sprintf("sys.source(%s,envir<-new.env(parent=globalenv()))",encodeString(file.path(live_out_root,"scripts/build_uefa_champions_league_outcomes.R"),quote='"')),
    sprintf("stopifnot(identical(envir$phase20_ucl_project_root,%s),!envir$phase20_ucl_is_direct())",encodeString(live_out_root,quote='"')),
    'stopifnot(isTRUE(envir$phase20_ucl_runtime$exists("phase18_hash_row_v2",mode="function")))',
    'cat("CL_WRAPPER_IMPORT_OK\\n")'),wrapper)
  result <- system2(file.path(R.home("bin"),"Rscript"),c("--vanilla",shQuote(wrapper)),stdout=TRUE,stderr=TRUE)
  expect_null(attr(result,"status"))
  expect_true(any(grepl("CL_WRAPPER_IMPORT_OK",result,fixed=TRUE)))
})
