library(testthat)

cold_non_wc_root <- normalizePath(if (basename(getwd())=="testthat") "../.." else ".",mustWork=TRUE)

test_that("standalone non-WC startup loads authorities in a private project without Git metadata", {
  root <- tempfile("non wc cold ");dir.create(root)
  on.exit(unlink(root,recursive=TRUE),add=TRUE)
  project <- file.path(root,"project with spaces");dir.create(project)
  expect_true(file.copy(file.path(cold_non_wc_root,"R"),project,recursive=TRUE))
  expect_true(file.copy(file.path(cold_non_wc_root,"scripts"),project,recursive=TRUE))
  dir.create(file.path(project,".planning"))
  probe <- file.path(project,"scripts/cold_probe.R")
  writeLines(c(
    'file <- gsub("~+~", " ", sub("^--file=", "", commandArgs(FALSE)[startsWith(commandArgs(FALSE),"--file=")]),fixed=TRUE)',
    'root <- dirname(dirname(normalizePath(file,mustWork=TRUE)));setwd(root)',
    'source(file.path(root,"scripts/stage_non_wc_dashboards.R"))',
    'non_wc_runtime$phase17_provider_source_authorities(root)',
    'stopifnot(!file.exists(file.path(root,".git")))',
    'for (name in c("phase14_build_fixture_forecasts","phase14_validate_competition_state_bundle","phase15_nl_compare_replays")) stopifnot(exists(name,envir=non_wc_runtime,inherits=FALSE))',
    'cat("COLD_NON_WC_AUTHORITY_READY=true\\n")'),probe)
  rscript <- file.path(R.home("bin"),"Rscript")
  output <- system2(rscript,c("--vanilla",shQuote(probe)),stdout=TRUE,stderr=TRUE)
  expect_null(attr(output,"status"),info=paste(output,collapse="\n"))
  expect_match(paste(output,collapse="\n"),"COLD_NON_WC_AUTHORITY_READY=true",fixed=TRUE)
  # Exercise the real --file CLI too. With no source/registry fixtures it must
  # reach the actual missing-production-input gate, not a path/bootstrap error.
  stage <- file.path(project,"docs/candidate")
  output <- suppressWarnings(system2(rscript,c("--vanilla",shQuote(file.path(project,"scripts/stage_non_wc_dashboards.R")),
    "--stage-root",shQuote(stage),"--cl-forecasts=disabled"),stdout=TRUE,stderr=TRUE))
  expect_identical(attr(output,"status"),1L)
  expect_match(paste(output,collapse="\n"),"Phase 17 production input is missing",fixed=TRUE)
  expect_false(any(grepl("//R/",output,fixed=TRUE)))
  expect_false(dir.exists(stage))
})
