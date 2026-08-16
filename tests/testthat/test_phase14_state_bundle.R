library(testthat)

phase14_state_test_project_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase14_state_test_fixture_path <- file.path(
  phase14_state_test_project_root,
  "tests/fixtures/phase14/edition_isolation_cases.csv"
)

phase14_state_test_edition_ids <- function() {
  c("uefa_euro_2028_qualifying", "uefa_nations_league_2026_27")
}

phase14_state_test_shared_allowlist <- function() {
  c(
    "canonical_team_identity",
    "approved_model_calibrator_release",
    "elo_xg_strength_inputs",
    "historical_senior_international_matches"
  )
}

phase14_state_test_prohibited_shared_classes <- function() {
  c(
    "fixtures", "results", "status", "groups", "standings",
    "competition_form", "forecasts", "cutoffs", "source_bundles",
    "warnings", "output_paths", "derived_competition_state"
  )
}

phase14_state_test_cases <- function() {
  utils::read.csv(
    phase14_state_test_fixture_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = character()
  )
}

phase14_state_test_split_set <- function(value) {
  value <- as.character(value)
  if (length(value) != 1L || !nzchar(value) || identical(value, "none")) {
    return(character())
  }
  sort(unique(strsplit(value, "|", fixed = TRUE)[[1L]]), method = "radix")
}

phase14_state_test_boolean <- function(value) {
  value <- tolower(as.character(value))
  if (length(value) != 1L || !value %in% c("true", "false")) {
    stop("Phase 14 isolation boolean must be true or false", call. = FALSE)
  }
  identical(value, "true")
}

phase14_state_test_canonical_replay <- function(input_sequence) {
  tokens <- strsplit(as.character(input_sequence), ";", fixed = TRUE)[[1L]]
  paste(sort(tokens, method = "radix"), collapse = "\n")
}

phase14_state_test_load_api <- function() {
  path <- file.path(
    phase14_state_test_project_root,
    "R/competition/state_bundle.R"
  )
  if (file.exists(path)) source(path, local = .GlobalEnv)
  invisible(TRUE)
}

test_that("edition isolation fixture freezes the complete D-18/D-21 case matrix", {
  cases <- phase14_state_test_cases()
  expected_columns <- c(
    "case_id", "failure_scope", "shared_input_class",
    "shared_input_disposition", "source_edition_id", "affected_editions",
    "expected_invalid_editions", "expected_nl_status", "expected_euro_status",
    "foreign_join_status", "history_scope", "release_active_predictors",
    "xg_evidence_status", "derived_row_scope", "derived_state_copy_allowed",
    "expected_fan_out", "audit_status", "input_order", "input_sequence",
    "deterministic_replay_identity", "expected_canonical_bytes",
    "expected_state_sha256", "expected_reason"
  )
  expected_case_ids <- c(
    "nl_local_fixture_failure",
    "euro_local_status_failure",
    "shared_identity_failure",
    "shared_release_failure",
    "shared_history_failure",
    "active_required_evidence_failure",
    "inactive_optional_xg_unavailable",
    "synthetic_xg_active_failure",
    "undeclared_cross_edition_join",
    "declared_all_senior_history_join",
    "deterministic_replay_normal",
    "deterministic_replay_reversed"
  )

  expect_identical(names(cases), expected_columns)
  expect_identical(as.character(cases$case_id), expected_case_ids)
  expect_identical(anyDuplicated(cases$case_id), 0L)
  expect_true(all(nzchar(cases$expected_reason)))
  expect_setequal(unique(cases$expected_nl_status), c("valid", "invalid"))
  expect_setequal(unique(cases$expected_euro_status), c("valid", "invalid"))
  expect_true(all(cases$derived_row_scope == "edition_scoped"))
})

test_that("only identity, release, strengths, and declared senior history are shared", {
  cases <- phase14_state_test_cases()
  allowed <- unique(cases$shared_input_class[cases$shared_input_disposition == "allowed"])
  rejected <- unique(cases$shared_input_class[cases$shared_input_disposition == "rejected"])

  expect_setequal(allowed, phase14_state_test_shared_allowlist())
  expect_identical(rejected, "derived_competition_state")
  expect_false(any(phase14_state_test_prohibited_shared_classes() %in% allowed))
  expect_true(all(
    cases$shared_input_disposition[cases$shared_input_class == "none"] == "not_applicable"
  ))
  expect_true(all(!vapply(
    cases$derived_state_copy_allowed,
    phase14_state_test_boolean,
    logical(1)
  )))
})

test_that("edition-local failures invalidate only their diagnostic candidate", {
  cases <- phase14_state_test_cases()
  local <- cases[cases$failure_scope == "edition_local_failure", , drop = FALSE]

  expect_identical(as.character(local$case_id), c(
    "nl_local_fixture_failure",
    "euro_local_status_failure"
  ))
  expect_identical(as.integer(local$expected_fan_out), c(1L, 1L))
  for (index in seq_len(nrow(local))) {
    invalid <- phase14_state_test_split_set(local$expected_invalid_editions[[index]])
    affected <- phase14_state_test_split_set(local$affected_editions[[index]])
    expect_identical(invalid, affected, info = local$case_id[[index]])
    expect_identical(invalid, local$source_edition_id[[index]], info = local$case_id[[index]])
  }

  nl <- local[local$source_edition_id == "uefa_nations_league_2026_27", , drop = FALSE]
  euro <- local[local$source_edition_id == "uefa_euro_2028_qualifying", , drop = FALSE]
  expect_identical(c(nl$expected_nl_status, nl$expected_euro_status), c("invalid", "valid"))
  expect_identical(c(euro$expected_nl_status, euro$expected_euro_status), c("valid", "invalid"))
})

test_that("required shared failures fan out to both editions", {
  cases <- phase14_state_test_cases()
  shared <- cases[cases$failure_scope == "shared_required_failure", , drop = FALSE]
  expected_cases <- c(
    "shared_identity_failure",
    "shared_release_failure",
    "shared_history_failure",
    "active_required_evidence_failure",
    "synthetic_xg_active_failure"
  )

  expect_setequal(shared$case_id, expected_cases)
  expect_true(all(shared$source_edition_id == "shared"))
  expect_true(all(shared$expected_fan_out == 2L))
  expect_true(all(shared$expected_nl_status == "invalid"))
  expect_true(all(shared$expected_euro_status == "invalid"))
  for (index in seq_len(nrow(shared))) {
    expect_identical(
      phase14_state_test_split_set(shared$expected_invalid_editions[[index]]),
      phase14_state_test_edition_ids(),
      info = shared$case_id[[index]]
    )
  }
})

test_that("immutable active predictors control xG failure fan-out", {
  cases <- phase14_state_test_cases()
  inactive <- cases[cases$case_id == "inactive_optional_xg_unavailable", , drop = FALSE]
  active <- cases[cases$case_id == "synthetic_xg_active_failure", , drop = FALSE]
  required <- cases[cases$case_id == "active_required_evidence_failure", , drop = FALSE]

  expect_false("national_team_xg" %in% phase14_state_test_split_set(inactive$release_active_predictors))
  expect_identical(inactive$xg_evidence_status, "inactive_optional_unavailable")
  expect_identical(inactive$audit_status, "unavailable_audited")
  expect_identical(phase14_state_test_split_set(inactive$expected_invalid_editions), character())
  expect_identical(as.integer(inactive$expected_fan_out), 0L)
  expect_identical(c(inactive$expected_nl_status, inactive$expected_euro_status), c("valid", "valid"))

  expect_true("national_team_xg" %in% phase14_state_test_split_set(active$release_active_predictors))
  expect_identical(active$xg_evidence_status, "active_required_missing")
  expect_identical(as.integer(active$expected_fan_out), 2L)
  expect_identical(
    phase14_state_test_split_set(active$expected_invalid_editions),
    phase14_state_test_edition_ids()
  )

  expect_identical(required$release_active_predictors, "elo_rating")
  expect_identical(required$expected_reason, "active_predictor_evidence_unavailable")
  expect_identical(as.integer(required$expected_fan_out), 2L)
})

test_that("cross-edition joins require the declared all-senior history scope", {
  cases <- phase14_state_test_cases()
  rejected <- cases[cases$case_id == "undeclared_cross_edition_join", , drop = FALSE]
  declared <- cases[cases$case_id == "declared_all_senior_history_join", , drop = FALSE]

  expect_identical(rejected$shared_input_disposition, "rejected")
  expect_identical(rejected$foreign_join_status, "rejected_undeclared")
  expect_identical(rejected$history_scope, "competition_edition")
  expect_identical(rejected$expected_invalid_editions, "uefa_nations_league_2026_27")
  expect_identical(as.integer(rejected$expected_fan_out), 1L)

  expect_identical(declared$shared_input_class, "historical_senior_international_matches")
  expect_identical(declared$shared_input_disposition, "allowed")
  expect_identical(declared$foreign_join_status, "allowed_declared")
  expect_identical(declared$history_scope, "all_senior_international")
  expect_identical(phase14_state_test_split_set(declared$expected_invalid_editions), character())
  expect_identical(as.integer(declared$expected_fan_out), 0L)
})

test_that("normal and reversed inputs replay to explicit identical bytes and SHA-256", {
  cases <- phase14_state_test_cases()
  replay <- cases[cases$failure_scope == "deterministic_replay", , drop = FALSE]
  expect_identical(as.character(replay$input_order), c("normal", "reversed"))
  expect_identical(unique(replay$deterministic_replay_identity), "nl-replay-v1")
  expect_identical(rev(strsplit(replay$input_sequence[[1L]], ";", fixed = TRUE)[[1L]]),
                   strsplit(replay$input_sequence[[2L]], ";", fixed = TRUE)[[1L]])

  canonical <- vapply(
    replay$input_sequence,
    phase14_state_test_canonical_replay,
    character(1)
  )
  bytes <- unname(nchar(canonical, type = "bytes"))
  hashes <- unname(vapply(canonical, function(value) {
    digest::digest(value, algo = "sha256", serialize = FALSE)
  }, character(1)))

  expect_identical(bytes, as.integer(replay$expected_canonical_bytes))
  expect_true(all(bytes == 393L))
  expect_identical(hashes, as.character(replay$expected_state_sha256))
  expect_true(all(grepl("^[0-9a-f]{64}$", hashes)))
  expect_identical(length(unique(canonical)), 1L)
  expect_identical(length(unique(hashes)), 1L)
})

test_that("production state candidate builder retains the edition-scoped entry point", {
  phase14_state_test_load_api()
  skip_if_not(exists("phase14_build_competition_state_candidate", mode = "function"))

  builder <- get("phase14_build_competition_state_candidate", mode = "function")
  expect_true("edition_id" %in% names(formals(builder)))
})
