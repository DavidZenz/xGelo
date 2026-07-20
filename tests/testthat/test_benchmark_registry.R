library(testthat)

project_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
source(file.path(project_root, "tests/testthat/helper_benchmark.R"))
source(file.path(project_root, "R/benchmark/registry.R"))

test_that("canonical registry has the locked 12-edition and 630-fixture denominator", {
  registries <- load_benchmark_registries(file.path(project_root, "data/benchmark/phase09"))
  expected <- benchmark_test_editions()

  expect_silent(validate_benchmark_registries(registries))
  expect_equal(nrow(registries$tournaments), 12L)
  expect_equal(nrow(registries$fixtures), 630L)
  expect_equal(anyDuplicated(registries$fixtures$fixture_id), 0L)
  counts <- table(registries$fixtures$edition_id)
  expect_equal(unname(counts[expected$edition_id]), expected$expected_fixture_count)
})

test_that("edition, format, identity, and regulation contracts are explicit", {
  registries <- load_benchmark_registries(file.path(project_root, "data/benchmark/phase09"))
  euro2020 <- registries$tournaments[registries$tournaments$edition_id == "euro2020", ]

  expect_equal(euro2020$edition_year, 2020L)
  expect_equal(euro2020$played_year, 2021L)
  expect_setequal(
    registries$formats$format_id,
    c("wc32_r16", "euro16_qf", "euro24_r16_best4third")
  )
  expect_true(all(registries$fixtures$home_team_id %in% registries$teams$team_id))
  expect_true(all(registries$fixtures$away_team_id %in% registries$teams$team_id))
  expect_true(all(nzchar(registries$teams$fifa_code)))
  expect_equal(anyDuplicated(registries$teams$fifa_code), 0L)
  extra_time <- registries$fixtures$went_extra_time
  expect_true(any(extra_time))
  expect_true(any(
    registries$fixtures$regulation_home_goals[extra_time] != registries$fixtures$final_home_goals[extra_time] |
      registries$fixtures$regulation_away_goals[extra_time] != registries$fixtures$final_away_goals[extra_time]
  ))
})

test_that("canonical registry hashes ignore harmless row order", {
  registries <- synthetic_benchmark_registries()
  original <- canonical_benchmark_sha256(registries$fixtures, key = "fixture_id")
  reordered <- canonical_benchmark_sha256(
    registries$fixtures[rev(seq_len(nrow(registries$fixtures))), ],
    key = "fixture_id"
  )
  expect_identical(original, reordered)
  expect_match(original, "^[0-9a-f]{64}$")
})

test_that("registry validation fails on denominator, identity, and provenance drift", {
  registries <- synthetic_benchmark_registries()
  short <- registries
  short$fixtures <- short$fixtures[-1, ]
  expect_error(validate_benchmark_registries(short), "630")

  unknown <- registries
  unknown$fixtures$home_team_id[1] <- "spoofed-team"
  expect_error(validate_benchmark_registries(unknown), "team")

  unverified <- registries
  unverified$corrections$verification_status <- "awaiting_human_approval"
  expect_error(benchmark_registry_manifest(unverified), "verified|approval")
})

test_that("registry path validation rejects traversal and external absolute roots", {
  expect_error(validate_benchmark_registry_paths("../phase09"), "path|root|relative")
  expect_error(validate_benchmark_registry_paths(tempdir()), "path|root|relative")
  expect_silent(validate_benchmark_registry_paths("data/benchmark/phase09", project_root))
})
