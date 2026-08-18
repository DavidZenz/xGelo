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

phase14_state_tracer_root <- phase14_state_test_project_root

phase14_state_tracer_inputs <- function() {
  list(
    editions = utils::read.csv(
      file.path(phase14_state_tracer_root, "data/competition/registries/competition_editions.csv"),
      stringsAsFactors = FALSE,
      check.names = FALSE,
      na.strings = ""
    ),
    teams = utils::read.csv(
      file.path(phase14_state_tracer_root, "data/competition/registries/team_identity.csv"),
      stringsAsFactors = FALSE,
      check.names = FALSE,
      na.strings = ""
    ),
    elo = utils::read.csv(
      file.path(phase14_state_tracer_root, "data/processed/elo_ratings.csv"),
      stringsAsFactors = FALSE,
      check.names = FALSE,
      na.strings = ""
    ),
    selector_path = file.path(phase14_state_tracer_root, "outputs/releases/approved_release.csv"),
    release_root = file.path(phase14_state_tracer_root, "outputs/releases"),
    model_manifest_path = file.path(
      phase14_state_tracer_root,
      "outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/manifests/model_manifests.csv"
    ),
    xg_registry = file.path(
      phase14_state_tracer_root,
      "data/competition/registries/national_team_xg_sources.csv"
    )
  )
}

phase14_state_tracer_fixture <- function() {
  data.frame(
    edition_id = "uefa_nations_league_2026_27",
    match_id = "uefa_nations_league_2026_27-nl-2026-0001",
    fixture_id = "uefa_nations_league_2026_27-nl-2026-0001",
    home_team_id = "team_aut",
    away_team_id = "team_deu",
    scheduled_at_utc = "2026-09-05T18:45:00Z",
    kickoff_utc = "2026-09-05T18:45:00Z",
    kickoff_confirmed = TRUE,
    confirmed_kickoff_at_utc = "2026-09-05T18:45:00Z",
    feature_cutoff_utc = "2026-09-05T18:44:59Z",
    source_status = "scheduled",
    match_status = "scheduled",
    venue = "home",
    home_score = NA_real_,
    away_score = NA_real_,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

test_that("state candidate keeps NL forecastable and EURO pre_draw structurally empty", {
  inputs <- phase14_state_tracer_inputs()
  fixture <- phase14_state_tracer_fixture()
  resolved <- phase14_resolve_approved_release(
    selector_path = inputs$selector_path,
    trusted_release_root = inputs$release_root
  )

  nl <- phase14_build_competition_state_candidate(
    edition_id = "uefa_nations_league_2026_27",
    edition_registry = inputs$editions,
    canonical_matches = fixture,
    team_registry = inputs$teams,
    resolved_release = resolved,
    elo_ratings = inputs$elo,
    national_team_xg_registry = inputs$xg_registry,
    model_manifest_path = inputs$model_manifest_path
  )
  expect_identical(nl$candidate_status, "valid")
  expect_identical(nl$lifecycle_state, "scheduled")
  expect_identical(nl$forecast_status$forecast_status, "available")
  expect_identical(nl$forecast_status$suppression_reason, "none")
  expect_identical(nl$forecast$forecasts$primary_probability_view, "calibrated_1x2")

  euro <- phase14_build_competition_state_candidate(
    edition_id = "uefa_euro_2028_qualifying",
    edition_registry = inputs$editions,
    canonical_matches = fixture[FALSE, , drop = FALSE],
    team_registry = inputs$teams,
    resolved_release = resolved,
    elo_ratings = inputs$elo,
    national_team_xg_registry = inputs$xg_registry,
    model_manifest_path = inputs$model_manifest_path
  )
  expect_identical(euro$candidate_status, "valid")
  expect_identical(euro$lifecycle_state, "pre_draw")
  expect_identical(euro$forecast_status, "pre_draw")
  expect_equal(nrow(euro$fixtures), 0L)
  expect_equal(nrow(euro$results), 0L)
  expect_equal(nrow(euro$groups), 0L)
  expect_equal(nrow(euro$standings), 0L)
  expect_equal(nrow(euro$competition_form), 0L)
  expect_equal(nrow(euro$all_senior_form), 0L)
  expect_equal(nrow(euro$forecast$forecasts), 0L)
  expect_equal(nrow(euro$forecast$score_distributions), 0L)
})

test_that("active required shared input failure fans out while inactive xG remains audited", {
  inputs <- phase14_state_tracer_inputs()
  fixture <- phase14_state_tracer_fixture()
  manifest <- utils::read.csv(
    inputs$model_manifest_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = ""
  )
  manifest <- manifest[manifest$model_id == "open_nb_incumbent", , drop = FALSE][1L, , drop = FALSE]
  manifest$active_predictors <- "elo_diff|xgf_ewma_diff|xga_ewma_diff|xgd_ewma_diff"
  manifest$dropped_predictors_with_reason <- "form_index_diff|inactive_optional"

  candidates <- phase14_build_competition_state_candidate(
    edition_id = c("uefa_nations_league_2026_27", "uefa_euro_2028_qualifying"),
    edition_registry = inputs$editions,
    canonical_matches = fixture,
    team_registry = inputs$teams,
    selector_path = inputs$selector_path,
    trusted_release_root = inputs$release_root,
    elo_ratings = inputs$elo,
    national_team_xg_registry = inputs$xg_registry,
    model_manifest = manifest
  )
  expect_true(is.list(candidates$candidates))
  expect_equal(length(candidates$candidates), 2L)
  expect_true(all(vapply(candidates$candidates, function(candidate) {
    identical(candidate$candidate_status, "invalid") &&
      identical(candidate$failure_reason, "active_national_team_xg_unavailable")
  }, logical(1))))
  expect_identical(candidates$shared_input_audit$fan_out, 2L)

  inactive <- phase14_build_competition_state_candidate(
    edition_id = c("uefa_nations_league_2026_27", "uefa_euro_2028_qualifying"),
    edition_registry = inputs$editions,
    canonical_matches = fixture,
    team_registry = inputs$teams,
    selector_path = inputs$selector_path,
    trusted_release_root = inputs$release_root,
    elo_ratings = inputs$elo,
    national_team_xg_registry = inputs$xg_registry,
    model_manifest_path = inputs$model_manifest_path
  )
  expect_true(all(vapply(inactive$candidates, function(candidate) {
    identical(candidate$shared_input_audit$xg_evidence_status, "inactive_optional_unavailable")
  }, logical(1))))

  foreign <- fixture
  foreign$edition_id <- "uefa_euro_2028_qualifying"
  expect_error(
    phase14_build_competition_state_candidate(
      edition_id = "uefa_nations_league_2026_27",
      edition_registry = inputs$editions,
      canonical_matches = foreign,
      team_registry = inputs$teams,
      selector_path = inputs$selector_path,
      trusted_release_root = inputs$release_root,
      elo_ratings = inputs$elo,
      national_team_xg_registry = inputs$xg_registry,
      model_manifest_path = inputs$model_manifest_path
    ),
    "cross-edition|edition_id"
  )
})

phase14_state_test_expected_inventory <- function() {
  c(
    "state/canonical_matches.csv",
    "state/standings.csv",
    "state/competition_form.csv",
    "state/all_international_form.csv",
    "state/model_form.csv",
    "state/forecast_status.csv",
    "state/forecasts.csv",
    "state/forecast_top10.csv",
    "audit/standings_reconciliation.csv",
    "audit/state_manifest.csv",
    "local/score_distributions.rds"
  )
}

phase14_state_test_batch <- function(canonical_matches = phase14_state_tracer_fixture(), ...) {
  inputs <- phase14_state_tracer_inputs()
  arguments <- list(
    edition_id = phase14_state_test_edition_ids(),
    edition_registry = inputs$editions,
    canonical_matches = canonical_matches,
    team_registry = inputs$teams,
    selector_path = inputs$selector_path,
    trusted_release_root = inputs$release_root,
    resolved_release = phase14_resolve_approved_release(
      selector_path = inputs$selector_path,
      trusted_release_root = inputs$release_root
    ),
    elo_ratings = inputs$elo,
    national_team_xg_registry = inputs$xg_registry,
    model_manifest_path = inputs$model_manifest_path,
    generated_at_utc = "2026-08-17T00:00:00Z"
  )
  overrides <- list(...)
  arguments[names(overrides)] <- overrides
  do.call(phase14_build_competition_state_batch, arguments)
}

test_that("production state batch exposes exact isolated inventory and validates candidates", {
  batch <- phase14_state_test_batch()

  expect_true(is.list(batch))
  expect_identical(batch$edition_ids, phase14_state_test_edition_ids())
  expect_identical(names(batch$candidates), phase14_state_test_edition_ids())
  expect_true(is.data.frame(batch$batch_manifest))
  expect_setequal(batch$batch_manifest$edition_id, phase14_state_test_edition_ids())

  for (candidate in batch$candidates) {
    expect_true(is.data.frame(candidate$state_manifest))
    expect_setequal(candidate$state_manifest$artifact_path, phase14_state_test_expected_inventory())
    expect_true(isTRUE(phase14_validate_competition_state_bundle(candidate)))
    expect_true(all(candidate$state_manifest$model_data_cutoff == "2026-06-10"))
    expect_true(all(candidate$state_manifest$active_predictors == "elo_diff"))
  }

  nl <- batch$candidates[["uefa_nations_league_2026_27"]]
  euro <- batch$candidates[["uefa_euro_2028_qualifying"]]
  expect_equal(nrow(nl$forecast$score_distributions), 41L * 41L)
  expect_equal(nrow(nl$forecast$forecast_top10), 10L)
  expect_identical(nl$forecast_status$forecast_status, "available")
  expect_identical(euro$lifecycle_state, "pre_draw")
  expect_identical(euro$forecast_status, "pre_draw")
  expect_equal(nrow(euro$forecast$score_distributions), 0L)
  expect_equal(nrow(euro$forecast$forecast_top10), 0L)
})

test_that("state batch replay is byte/hash deterministic and preserves edition-local rows", {
  first <- phase14_state_test_batch()
  second <- phase14_state_test_batch()

  expect_identical(first$batch_sha256, second$batch_sha256)
  expect_identical(first$batch_manifest, second$batch_manifest)
  for (edition_id in first$edition_ids) {
    expect_identical(
      first$candidates[[edition_id]]$state_manifest,
      second$candidates[[edition_id]]$state_manifest
    )
    expect_identical(
      first$candidates[[edition_id]]$forecast$forecasts,
      second$candidates[[edition_id]]$forecast$forecasts
    )
  }
})

test_that("shared identity failure fans out before edition work while local failure stays local", {
  inputs <- phase14_state_tracer_inputs()
  bad_identity <- inputs$teams
  bad_identity$canonical_name[[1L]] <- bad_identity$canonical_name[[2L]]
  shared <- phase14_state_test_batch(team_registry = bad_identity)

  expect_true(all(vapply(shared$candidates, function(candidate) {
    identical(candidate$candidate_status, "invalid") &&
      identical(candidate$failure_scope, "shared")
  }, logical(1))))
  expect_identical(shared$shared_input_audit$failure_reason, "shared_identity_validation_failed")
  expect_identical(shared$shared_input_audit$fan_out, 2L)

  local_fixture <- phase14_state_tracer_fixture()
  local_fixture$match_status <- "postponed"
  local_fixture$source_status <- "postponed"
  local <- phase14_state_test_batch(canonical_matches = local_fixture)
  expect_identical(local$candidates[["uefa_nations_league_2026_27"]]$candidate_status, "invalid")
  expect_identical(local$candidates[["uefa_nations_league_2026_27"]]$failure_scope, "edition_local")
  expect_identical(local$candidates[["uefa_euro_2028_qualifying"]]$candidate_status, "valid")
  expect_identical(local$shared_input_audit$fan_out, 0L)
})

test_that("edition-local resources are partitioned before candidate construction", {
  inputs <- phase14_state_tracer_inputs()
  nl_fixture <- phase14_state_tracer_fixture()
  nl_fixture$match_status <- "postponed"
  nl_fixture$source_status <- "postponed"
  euro_resource <- nl_fixture
  euro_resource$edition_id <- "uefa_euro_2028_qualifying"
  euro_resource$match_id <- "uefa_euro_2028_qualifying-local-resource"
  euro_resource$fixture_id <- euro_resource$match_id

  batch <- phase14_state_test_batch(
    canonical_matches = nl_fixture,
    results = rbind(nl_fixture, euro_resource)
  )
  nl <- batch$candidates[["uefa_nations_league_2026_27"]]
  euro <- batch$candidates[["uefa_euro_2028_qualifying"]]

  expect_identical(nl$candidate_status, "invalid")
  expect_identical(nl$failure_scope, "edition_local")
  expect_identical(euro$candidate_status, "valid")
  expect_identical(euro$lifecycle_state, "pre_draw")
  expect_false(any(grepl("uefa_nations_league_2026_27", names(euro$state_artifacts))))
  expect_equal(nrow(euro$state_artifacts[["state/canonical_matches.csv"]]), 0L)
})

test_that("shared failure fan-out preserves every source fixture as suppressed status", {
  inputs <- phase14_state_tracer_inputs()
  bad_identity <- inputs$teams
  bad_identity$canonical_name[[1L]] <- bad_identity$canonical_name[[2L]]
  batch <- phase14_state_test_batch(team_registry = bad_identity)
  nl <- batch$candidates[["uefa_nations_league_2026_27"]]
  source_ids <- as.character(phase14_state_tracer_fixture()$fixture_id)
  status <- nl$state_artifacts[["state/forecast_status.csv"]]

  expect_identical(nl$candidate_status, "invalid")
  expect_identical(nl$failure_scope, "shared")
  expect_identical(as.character(nl$state_artifacts[["state/canonical_matches.csv"]]$fixture_id), source_ids)
  expect_identical(as.character(status$fixture_id), source_ids)
  expect_true(all(as.character(status$forecast_status) == "suppressed"))
  expect_true(all(as.character(status$suppression_reason) == "shared_identity_validation_failed"))
  expect_identical(
    as.integer(nl$state_manifest$`row_count`[nl$state_manifest$artifact_path == "state/forecast_status.csv"]),
    1L
  )
})

test_that("resolver model cutoff reaches every status, forecast, and manifest row", {
  batch <- phase14_state_test_batch()
  cutoff <- as.character(batch$resolved_release$model_data_cutoff)
  for (candidate in batch$candidates) {
    manifest <- candidate$state_manifest
    status <- candidate$state_artifacts[["state/forecast_status.csv"]]
    expect_true("model_data_cutoff" %in% names(status))
    expect_true(all(as.character(manifest$model_data_cutoff) == cutoff))
    expect_true(all(as.character(status$model_data_cutoff) == cutoff))
    if (nrow(candidate$state_artifacts[["state/forecasts.csv"]])) {
      expect_true("model_data_cutoff" %in% names(candidate$state_artifacts[["state/forecasts.csv"]]))
      expect_true(all(as.character(candidate$state_artifacts[["state/forecasts.csv"]]$model_data_cutoff) == cutoff))
    }
  }
})

test_that("build script uses fixed startup seed and dry-run replay without durable mutation", {
  script_path <- file.path(phase14_state_test_project_root, "scripts/build_competition_state.R")
  expect_true(file.exists(script_path))
  script_lines <- readLines(script_path, warn = FALSE)
  expect_true(any(grepl("set.seed\\(14017L\\)", script_lines, fixed = FALSE)))

  script_env <- new.env(parent = globalenv())
  sys.source(script_path, envir = script_env)
  expect_true(exists("phase14_build_competition_state_main", envir = script_env, inherits = FALSE))

  inputs <- phase14_state_tracer_inputs()
  loader <- function(edition_ids, project_root) {
    list(
      edition_registry = inputs$editions,
      canonical_matches = phase14_state_tracer_fixture(),
      team_registry = inputs$teams,
      resolved_release = phase14_resolve_approved_release(inputs$selector_path, inputs$release_root),
      elo_ratings = inputs$elo,
      national_team_xg_registry = inputs$xg_registry,
      model_manifest_path = inputs$model_manifest_path
    )
  }
  run_once <- function() {
    script_env$phase14_build_competition_state_main(
      args = c("--edition-id", "both", "--dry-run"),
      project_root = phase14_state_test_project_root,
      input_loader_fn = loader,
      build_batch_fn = phase14_build_competition_state_batch,
      validate_fn = phase14_validate_competition_state_bundle
    )
  }
  before <- digest::digest(file = inputs$selector_path, algo = "sha256")
  first <- run_once()
  second <- run_once()
  after <- digest::digest(file = inputs$selector_path, algo = "sha256")

  expect_true(isTRUE(first$dry_run))
  expect_identical(first$seed, 14017L)
  expect_identical(first$batch$batch_sha256, second$batch$batch_sha256)
  expect_identical(first$batch$batch_manifest, second$batch$batch_manifest)
  expect_identical(before, after)
})

phase14_state_test_two_fixtures <- function() {
  first <- phase14_state_tracer_fixture()
  second <- first
  second$match_id <- "uefa_nations_league_2026_27-nl-2026-0002"
  second$fixture_id <- second$match_id
  second$scheduled_at_utc <- "2026-09-06T18:45:00Z"
  second$kickoff_utc <- second$scheduled_at_utc
  second$confirmed_kickoff_at_utc <- second$scheduled_at_utc
  second$feature_cutoff_utc <- "2026-09-06T18:44:59Z"
  rbind(first, second)
}

phase14_state_test_tree_snapshot <- function(root) {
  files <- list.files(root, recursive = TRUE, full.names = TRUE, all.files = FALSE, no.. = TRUE)
  files <- files[!file.info(files)$isdir]
  if (!length(files)) return(setNames(character(), character()))
  relative <- substring(files, nchar(normalizePath(root, winslash = "/", mustWork = TRUE)) + 2L)
  hashes <- vapply(files, function(path) {
    digest::digest(readBin(path, what = "raw", n = file.info(path)$size), algo = "sha256", serialize = FALSE)
  }, character(1))
  setNames(hashes, relative)
}

test_that("reversed input order has identical canonical hashes and replay-check never promotes", {
  normal <- phase14_state_test_batch(canonical_matches = phase14_state_test_two_fixtures())
  reversed_input <- phase14_state_test_two_fixtures()[2:1, , drop = FALSE]
  reversed <- phase14_state_test_batch(canonical_matches = reversed_input)
  expect_identical(normal$batch_sha256, reversed$batch_sha256)
  expect_identical(normal$batch_manifest, reversed$batch_manifest)
  for (edition_id in normal$edition_ids) {
    expect_identical(
      normal$candidates[[edition_id]]$state_manifest,
      reversed$candidates[[edition_id]]$state_manifest
    )
    expect_identical(
      normal$candidates[[edition_id]]$state_artifacts[["state/forecast_status.csv"]],
      reversed$candidates[[edition_id]]$state_artifacts[["state/forecast_status.csv"]]
    )
  }

  script_path <- file.path(phase14_state_test_project_root, "scripts/build_competition_state.R")
  script_env <- new.env(parent = globalenv())
  sys.source(script_path, envir = script_env)
  inputs <- phase14_state_tracer_inputs()
  loader <- function(edition_ids, project_root) {
    list(
      edition_registry = inputs$editions,
      canonical_matches = phase14_state_test_two_fixtures(),
      team_registry = inputs$teams,
      resolved_release = phase14_resolve_approved_release(inputs$selector_path, inputs$release_root),
      elo_ratings = inputs$elo,
      national_team_xg_registry = inputs$xg_registry,
      model_manifest_path = inputs$model_manifest_path
    )
  }
  before <- phase14_state_test_tree_snapshot(file.path(phase14_state_test_project_root, "outputs/competition"))
  result <- script_env$phase14_build_competition_state_main(
    args = c("--edition-id", "both", "--replay-check"),
    project_root = phase14_state_test_project_root,
    input_loader_fn = loader,
    build_batch_fn = phase14_build_competition_state_batch,
    validate_fn = phase14_validate_competition_state_bundle
  )
  after <- phase14_state_test_tree_snapshot(file.path(phase14_state_test_project_root, "outputs/competition"))

  expect_true(isTRUE(result$replay_check))
  expect_true(isTRUE(result$replay$verified))
  expect_identical(result$replay$normal$batch_sha256, result$replay$reversed$batch_sha256)
  expect_identical(result$replay$normal$batch_sha256, result$replay$repeated$batch_sha256)
  expect_identical(before, after)
  expect_false(isTRUE(result$durable_mutation))
})
