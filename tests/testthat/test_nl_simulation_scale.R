library(testthat)

nl_scale_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
if (!exists("uefa_nl_run_simulation", mode = "function")) {
  sys.source(file.path(nl_scale_root, "R/competition/uefa_nations_league_rules.R"), envir = .GlobalEnv)
  sys.source(file.path(nl_scale_root, "R/competition/standings.R"), envir = .GlobalEnv)
  sys.source(file.path(nl_scale_root, "R/competition/uefa_euro_priority.R"), envir = .GlobalEnv)
  sys.source(file.path(nl_scale_root, "R/competition/uefa_nations_league_simulation.R"), envir = .GlobalEnv)
}

test_that("large-run iteration seeds preserve replay prefixes and caller RNG", {
  set.seed(448L)
  before <- .Random.seed
  prefix <- vapply(seq_len(20L), function(i) uefa_nl_sim_seed_for(15017L, iteration = i), integer(1))
  # Chunk boundaries and the target simulation count must not enter seeds.
  chunked <- unlist(lapply(split(seq_len(20L), ceiling(seq_len(20L) / 7L)), function(ids) {
    vapply(ids, function(i) uefa_nl_sim_seed_for(15017L, iteration = i), integer(1))
  }), use.names = FALSE)
  expect_identical(prefix, chunked)
  expect_identical(uefa_nl_sim_seed_for(15017L, iteration = 100000L),
                   89898712L)
  expect_identical(.Random.seed, before)
})

test_that("seeded per-iteration sampling is invariant to chunk and worker scheduling", {
  one <- function(i) uefa_nl_sim_with_seed(uefa_nl_sim_seed_for(15017L, iteration = i), function() {
    uefa_nl_sample_calibrated_outcome(c(home = .45, draw = .28, away = .27), n = 8L)
  })
  ids <- seq_len(24L)
  serial <- lapply(ids, one)
  chunked <- unlist(lapply(split(ids, ceiling(ids / 5L)), function(chunk) lapply(chunk, one)), recursive = FALSE)
  expect_identical(serial, unname(chunked))
  if (.Platform$OS.type != "windows") {
    parallel <- parallel::mclapply(ids, one, mc.cores = 4L, mc.set.seed = FALSE)
    expect_identical(serial, parallel)
  }
})

test_that("scale policy retains unresolved probability semantics", {
  expect_true(is.na(uefa_nl_sim_mean_path(c(1, 0, NA_real_))))
  expect_true(is.na(uefa_nl_sim_mean_path(numeric())))
  expect_identical(uefa_nl_sim_mean_path(c(1, 0, 1, 0)), .5)
  expect_identical(uefa_nl_sim_normalize_workers(4L, 1L), 1L)
  expect_identical(uefa_nl_sim_normalize_count(100000L), 100000L)
})
