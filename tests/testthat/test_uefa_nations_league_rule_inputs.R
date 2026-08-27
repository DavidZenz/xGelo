library(testthat)

rule_input_test_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/",
  mustWork = TRUE
)
sys.source(file.path(rule_input_test_root, "R/competition/uefa_nations_league_rules.R"), envir = .GlobalEnv)
sys.source(file.path(rule_input_test_root, "R/competition/uefa_nations_league_rule_inputs.R"), envir = .GlobalEnv)

test_that("captured Article 15 inputs are complete, hashed, and initialized", {
  base <- uefa_nl_build_topology(project_root = rule_input_test_root)
  inputs <- phase15_nl_read_rule_inputs(
    project_root = rule_input_test_root,
    teams = base$teams
  )

  expect_identical(inputs$rule_input_id, "nl-2026-27-article15-rule-inputs-v1")
  expect_equal(nrow(inputs$access_list), 54L)
  expect_equal(sort(inputs$access_list$access_list_position), seq_len(54L))
  expect_setequal(inputs$access_list$team_id, base$teams$team_id)
  expect_true(all(inputs$access_list$status == "admitted"))
  expect_true(all(inputs$access_list$group_formation_status == "validated"))
  expect_equal(nrow(inputs$discipline_points), 54L)
  expect_setequal(inputs$discipline_points$team_id, base$teams$team_id)
  expect_true(all(inputs$discipline_points$discipline_points == 0L))
  expect_true(all(inputs$discipline_points$initialization_status == "initialized_pre_match"))
  expect_identical(inputs$manifest$capture_status[[1L]], "accepted")
  expect_identical(inputs$manifest$discipline_initialization_policy[[1L]], "zero_before_first_league_phase_match")

  topology <- uefa_nl_build_topology(
    groups = read.csv(file.path(rule_input_test_root, "data/competition/accepted/uefa_nations_league_2026_27/groups.csv"), stringsAsFactors = FALSE, check.names = FALSE),
    fixtures = read.csv(file.path(rule_input_test_root, "data/competition/accepted/uefa_nations_league_2026_27/fixtures.csv"), stringsAsFactors = FALSE, check.names = FALSE),
    access_list = inputs$access_list,
    discipline_points = inputs$discipline_points,
    project_root = rule_input_test_root
  )
  expect_identical(topology$access_list_status, "validated")
  expect_identical(topology$discipline_points_status, "initialized_pre_match")
  expect_identical(topology$group_formation_status, "validated")
  expect_true(all(!is.na(topology$teams$access_list_position)))
  expect_true(all(topology$teams$discipline_points == 0L))
})

test_that("Article 15 input validators fail closed on tampering", {
  inputs <- phase15_nl_read_rule_inputs(project_root = rule_input_test_root)

  tampered_discipline <- inputs$discipline_points
  tampered_discipline$discipline_points[[1L]] <- 1L
  expect_error(
    phase15_nl_rule_input_validate_discipline_points(tampered_discipline),
    "initialize every team to zero"
  )

  tampered_access <- inputs$access_list
  tampered_access$access_list_position[[1L]] <- 2L
  expect_error(
    phase15_nl_rule_input_validate_access_list(tampered_access),
    "complete 1:54 universe"
  )
})
