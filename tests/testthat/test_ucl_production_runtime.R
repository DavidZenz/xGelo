# Standard repository tests use code-only temporary roots, never live parents.
cl_sparse_origin <- Sys.getenv("XGELO_CL_RUNTIME_TEST_PROJECT", unset = "")
if (!nzchar(cl_sparse_origin)) {
  cl_sparse_origin <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  while (!file.exists(file.path(cl_sparse_origin, "R/competition/ucl_production_runtime.R"))) {
    next_root <- dirname(cl_sparse_origin)
    if (identical(next_root, cl_sparse_origin)) stop("CL test code origin missing")
    cl_sparse_origin <- next_root
  }
}
sys.source(file.path(cl_sparse_origin, "tests/testthat/ucl_sparse_runtime_test_helper.R"), envir = environment())
runtime_test_root <- ucl_sparse_code_test_project(ucl_sparse_test_code_origin("XGELO_CL_RUNTIME_TEST_PROJECT"))

test_that("CL production facade cold-loads from its module rather than caller cwd", {
  env <- new.env(parent = baseenv())
  before <- getwd()
  foreign <- tempfile("ucl-foreign-cwd-"); dir.create(foreign)
  foreign <- normalizePath(foreign, mustWork = TRUE)
  on.exit(setwd(before), add = TRUE)
  setwd(foreign)
  sys.source(file.path(runtime_test_root, "R/competition/ucl_production_runtime.R"), env)
  expect_identical(env$.ucl_runtime_bound_root, runtime_test_root)
  namespace <- env$.ucl_runtime_load()
  expect_identical(getwd(), foreign)
  expect_identical(parent.env(namespace), baseenv())
  expect_identical(parent.env(namespace$phase20_ucl_runtime), baseenv())
  expect_identical(namespace$phase20_ucl_project_root, runtime_test_root)
  expect_identical(namespace$phase20_ucl_runtime$.phase19_club_project_root, runtime_test_root)
  expect_identical(namespace$phase20_ucl_runtime$tail, utils::tail)
  expect_identical(namespace$phase20_ucl_runtime$capture.output, utils::capture.output)
  for (name in c("ucl20_build_live_outcomes", "ucl_live_validate_result",
      "ucl_future_production_context", "ucl_read_live_outcomes",
      "ucl_validate_live_outcomes_read_result"))
    expect_true(base::exists(name, namespace$phase20_ucl_runtime, inherits = FALSE))
})

test_that("CL namespace does not inherit poisoned national or global helpers", {
  env <- new.env(parent = baseenv())
  sys.source(file.path(runtime_test_root, "R/competition/ucl_production_runtime.R"), env)
  names <- c("phase19_forecast_current_ucl", "ucl20_build_outcomes", "phase14_resolve_approved_release")
  saved <- lapply(names, function(name) if (base::exists(name, .GlobalEnv, inherits = FALSE))
    get(name, .GlobalEnv, inherits = FALSE) else NULL)
  present <- vapply(names, base::exists, logical(1), envir = .GlobalEnv, inherits = FALSE)
  on.exit(for (i in seq_along(names)) {
    if (present[[i]]) assign(names[[i]], saved[[i]], .GlobalEnv)
    else if (base::exists(names[[i]], .GlobalEnv, inherits = FALSE)) rm(list = names[[i]], envir = .GlobalEnv)
  }, add = TRUE)
  poison <- function(...) stop("Global helper was incorrectly inherited")
  for (name in names) assign(name, poison, .GlobalEnv)
  namespace <- env$.ucl_runtime_load()
  expect_false(identical(namespace$phase20_ucl_runtime$phase19_forecast_current_ucl, poison))
  expect_false(identical(namespace$phase20_ucl_runtime$ucl20_build_outcomes, poison))
  expect_false(base::exists("phase14_resolve_approved_release", namespace$phase20_ucl_runtime, inherits = TRUE))
  before <- getwd()
  result <- env$ucl_build_production_outcomes(1L, 1L)
  expect_false(isTRUE(result$production_eligible))
  expect_true(result$status %in% c("production_blocked", "production_human_needed"))
  expect_identical(getwd(), before)
})

test_that("CL facade validates scalar controls and restores cwd after errors", {
  env <- new.env(parent = baseenv())
  sys.source(file.path(runtime_test_root, "R/competition/ucl_production_runtime.R"), env)
  before <- getwd()
  for (arguments in list(list(simulations = c(1L, 2L)), list(simulations = NA_real_),
      list(simulations = 0), list(simulations = 1.5), list(seed = c(1L, 2L)),
      list(seed = -1L), list(write = TRUE, replay_check = TRUE),
      list(information_cutoff_utc = c("2026-11-06T00:00:00Z", "2026-11-07T00:00:00Z"))))
    expect_error(do.call(env$ucl_build_production_outcomes, arguments), "Invalid CL production run controls")
  expect_error(env$ucl_build_production_outcomes(information_cutoff_utc = "bad"), "cutoff")
  expect_error(env$.ucl_runtime_in_project(function() stop("deliberate callback failure")), "deliberate callback failure")
  expect_identical(getwd(), before)
  for (name in c("ucl_build_production_outcomes", "ucl_read_production_outcomes",
      "ucl_validate_production_outcome_read_result"))
    expect_false(any(grepl("root|path|selector|release", names(formals(get(name, env))), ignore.case = TRUE)))
})

test_that("CL cached namespace is discarded when a dependency byte changes", {
  env <- new.env(parent = baseenv())
  sys.source(file.path(runtime_test_root, "R/competition/ucl_production_runtime.R"), env)
  first <- env$.ucl_runtime_load()
  expect_identical(env$.ucl_runtime_load(), first)
  path <- file.path(runtime_test_root, "R/competition/ucl_live_outcome_reader.R")
  original <- readBin(path, "raw", n = file.info(path)$size)
  on.exit(writeBin(original, path), add = TRUE)
  writeBin(c(original, charToRaw("\n# dependency drift probe\n")), path)
  second <- env$.ucl_runtime_load()
  expect_false(identical(first, second))
  expect_identical(second$phase20_ucl_project_root, runtime_test_root)
})

test_that("CL persisted reads remain blocked without accepted production parents", {
  env <- new.env(parent = baseenv())
  sys.source(file.path(runtime_test_root, "R/competition/ucl_production_runtime.R"), env)
  result <- env$ucl_read_production_outcomes()
  expect_identical(result$status, "blocked")
  expect_false(isTRUE(result$production_eligible))
  expect_false(env$ucl_validate_production_outcome_read_result(result))
  expect_false(env$ucl_validate_production_outcome_read_result(list(status = "available", production_eligible = TRUE)))
})

test_that("missing persisted reader cannot reuse a cached CL namespace", {
  env <- new.env(parent = baseenv())
  sys.source(file.path(runtime_test_root, "R/competition/ucl_production_runtime.R"), env)
  env$.ucl_runtime_load()
  path <- file.path(runtime_test_root, "R/competition/ucl_live_outcome_reader.R")
  backup <- paste0(path, ".saved")
  stopifnot(file.rename(path, backup))
  on.exit(file.rename(backup, path), add = TRUE)
  before <- getwd()
  result <- env$ucl_read_production_outcomes()
  expect_identical(result$status, "blocked")
  expect_identical(result$reason_code, "fixed_runtime_unavailable")
  expect_false(isTRUE(result$production_eligible))
  expect_false(env$ucl_validate_production_outcome_read_result(list(status = "available", production_eligible = TRUE)))
  expect_identical(getwd(), before)
})
