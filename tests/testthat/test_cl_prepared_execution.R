library(testthat)
source("helper_uefa_champions_league.R", local = TRUE)
for (name in c("rules", "state", "simulation")) source(paste0("../../R/competition/uefa_champions_league_", name, ".R"), local = TRUE)

test_that("prepared CL seeds preserve the framed seed family and RNG state", {
  fast <- .ucl_sim_prepare_seed_encoder()
  probes <- expand.grid(seed = c(-100L, 0L, 7L, 2147483646L),
    label = c("fixture", "iteration"), value = c("1", "CL-144", "é", "x\x1fy", NA_character_), stringsAsFactors = FALSE)
  set.seed(918L); saved <- .Random.seed
  for (i in seq_len(nrow(probes))) {
    row <- probes[i, ]
    expect_identical(fast(row$seed, row$label, row$value), .ucl_sim_seed_for(row$seed, row$label, row$value))
  }
  expect_identical(fast(7L, "different-arity"), .ucl_sim_seed_for(7L, "different-arity"))
  expect_identical(saved, .Random.seed)
})

test_that("prepared CL trace encoding preserves types, missingness and layout changes", {
  rules <- .ucl_rule_contract()
  trace <- .ucl_rule_trace_row(rules, "tie-é\x1f", 1L, "goal_difference", c("A", "B"),
    c("B", "A"), "available", c("fixture\n1", "fixture|2"), TRUE, 1L, 2L)
  trace <- trace[rep(1L, 4L), , drop = FALSE]
  trace$criterion_order <- c(1L, NA_integer_, 1L, 2L)
  trace$decisive <- c(TRUE, FALSE, NA, TRUE)
  trace$rank_interval_min <- c(0, -0, NA_real_, NaN)
  fast <- .ucl_rule_prepare_trace_hasher()
  for (rows in list(trace, trace[4:1, ], trace[, rev(names(trace))], trace[0, ])) {
    expect_identical(fast(rows), .ucl_rule_hash_rows(rows))
  }
  trace$criterion_order <- factor(c("x", "é", NA, "x"))
  expect_identical(fast(trace), .ucl_rule_hash_rows(trace))
  expect_identical(fast(trace[1L, ]), .ucl_rule_hash_rows(trace[1L, ]))
})
