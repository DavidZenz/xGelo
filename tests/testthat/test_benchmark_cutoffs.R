library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "tests/testthat/helper_benchmark.R"))
source(file.path(project_root, "R/benchmark/registry.R"))
source(file.path(project_root, "R/benchmark/cutoffs.R"))

test_that("canonical boundaries contain frozen and date-complete updating tracks", {
  registries <- load_benchmark_registries(file.path(project_root, "data/benchmark/phase09"))
  boundaries <- make_benchmark_boundaries(registries$tournaments, registries$fixtures)

  expect_equal(sum(boundaries$track == "frozen"), 12L)
  expect_equal(sum(boundaries$track == "updating"), 272L)
  frozen <- boundaries[boundaries$track == "frozen", ]
  expect_equal(
    frozen$evidence_cutoff_exclusive,
    registries$tournaments$opener_date[match(frozen$edition_id, registries$tournaments$edition_id)]
  )
  expect_silent(assert_benchmark_cutoffs(registries$fixtures, boundaries))
  stored <- registries$boundaries[order(registries$boundaries$boundary_id), ]
  generated <- boundaries[order(boundaries$boundary_id), ]
  expect_identical(generated$boundary_sha256, stored$boundary_sha256)
})

test_that("same-date fixtures share one strictly prior evidence state", {
  registries <- synthetic_benchmark_registries()
  history <- synthetic_benchmark_history()
  edition <- registries$tournaments[registries$tournaments$edition_id == "wc2002", ]
  fixtures <- registries$fixtures[registries$fixtures$edition_id == "wc2002", ]
  boundaries <- make_benchmark_boundaries(edition, fixtures)
  states <- build_benchmark_track_states(history, fixtures, boundaries)

  updating <- states[states$track == "updating", ]
  same_date <- split(updating, updating$assessment_date)
  expect_true(all(vapply(same_date, function(x) length(unique(x$state_sha256)) == 1L, logical(1))))
  expect_true(all(as.Date(updating$max_evidence_date) < as.Date(updating$evidence_cutoff_exclusive) |
    is.na(updating$max_evidence_date)))
})

test_that("date ordering cannot alter boundary state hashes", {
  registries <- synthetic_benchmark_registries()
  history <- synthetic_benchmark_history()
  fixtures <- registries$fixtures[registries$fixtures$edition_id == "wc2002", ]
  tournament <- registries$tournaments[registries$tournaments$edition_id == "wc2002", ]
  boundaries <- make_benchmark_boundaries(tournament, fixtures)

  first <- build_benchmark_track_states(history, fixtures, boundaries)
  second <- build_benchmark_track_states(
    history[rev(seq_len(nrow(history))), ],
    fixtures[rev(seq_len(nrow(fixtures))), ],
    boundaries[rev(seq_len(nrow(boundaries))), ]
  )
  first <- first[order(first$fixture_id, first$track), c("fixture_id", "track", "state_sha256")]
  second <- second[order(second$fixture_id, second$track), c("fixture_id", "track", "state_sha256")]
  rownames(first) <- rownames(second) <- NULL
  expect_identical(first, second)
})

test_that("updating boundaries form a complete prior-boundary chain", {
  registries <- synthetic_benchmark_registries()
  fixtures <- registries$fixtures[registries$fixtures$edition_id == "wc2002", ]
  tournament <- registries$tournaments[registries$tournaments$edition_id == "wc2002", ]
  boundaries <- make_benchmark_boundaries(tournament, fixtures)
  updating <- boundaries[boundaries$track == "updating", ]
  updating <- updating[order(updating$sequence), ]

  expect_true(is.na(updating$prior_boundary_id[1]) || !nzchar(updating$prior_boundary_id[1]))
  expect_identical(updating$prior_boundary_id[-1], updating$boundary_id[-nrow(updating)])
  boundary <- updating[2, ]
  eligible <- eligible_benchmark_history(synthetic_benchmark_history(), boundary)
  expect_true(all(as.Date(eligible$actual_completion_date) < as.Date(boundary$evidence_cutoff_exclusive)))
})
