library(testthat)

# The aggregate verifier parses these records and joins them to the exact
# [FLAGGED-UNVERIFIED] rows in Plans 19-01..19-10. Keep one record per
# prohibition; the executable tests below mark the corresponding probe id.
# PHASE19_PROBE|19-01-01|P01|[FLAGGED-UNVERIFIED] A production training or current-club coverage call never accepts arbitrary rows/paths, audit-only history, no-incumbent/tombstone current state, fixture evidence, or caller-supplied acceptance flags.|authority|blocked
# PHASE19_PROBE|19-01-02|P02|[FLAGGED-UNVERIFIED] An unavailable enrichment is never zero-filled, omitted, activated, or included in a formula without separately accepted source authority.|feature|rejected
# PHASE19_PROBE|19-01-03|P03|[FLAGGED-UNVERIFIED] Fixture or national-team evidence never becomes club production authority through relabeling or a caller-controlled mode field, and historical acceptance alone never substitutes for current-UCL/identity acceptance.|authority|non_promotable
# PHASE19_PROBE|19-02-01|P04|[FLAGGED-UNVERIFIED] Rating state never keys on display names, FIFA/national IDs, or national-team registries.|rating|rejected
# PHASE19_PROBE|19-02-02|P05|[FLAGGED-UNVERIFIED] A result from one fixture never changes another forecast in the same exact-kickoff or conservative date batch.|temporal|invariant
# PHASE19_PROBE|19-02-03|P06|[FLAGGED-UNVERIFIED] Rating inactivity never decays the absolute rating toward zero; only the difference from the frozen base rating is regressed.|rating|invariant
# PHASE19_PROBE|19-03-01|P07|[FLAGGED-UNVERIFIED] Observed Phase 19 scores never create, tune, rewrite, review, or approve a gate threshold, seed, candidate setting, or baseline identity.|policy|rejected
# PHASE19_PROBE|19-03-02|P08|[FLAGGED-UNVERIFIED] National constants such as open_core, World Cup/Euro panels, frozen/updating tournament tracks, FIFA codes, or national selectors never enter club protocol authority.|policy|rejected
# PHASE19_PROBE|19-03-03|P09|[FLAGGED-UNVERIFIED] A registry edit, row reorder, delimiter collision, duplicate key, missing row, extra file, or hash drift never validates under the same protocol identity.|policy|rejected
# PHASE19_PROBE|19-04-01|P10|[FLAGGED-UNVERIFIED] Held-out league labels never enter parameter selection, rating tuning, model fit, or calibration evidence.|fold|rejected
# PHASE19_PROBE|19-04-02|P11|[FLAGGED-UNVERIFIED] Equal-kickoff, equal-date, exact-cutoff, or later evidence never becomes eligible inside the same assessment boundary.|temporal|rejected
# PHASE19_PROBE|19-04-03|P12|[FLAGGED-UNVERIFIED] Empty blocked or unreviewed candidate production folds never masquerade as a ready protocol, while fixture folds/reviews never overwrite or satisfy production protocol state.|fold|blocked
# PHASE19_PROBE|19-05-01|P13|[FLAGGED-UNVERIFIED] A failed, non-converged, invalid-theta, or incomplete negative-binomial fit never falls back to Poisson, another family, or a control.|model|rejected
# PHASE19_PROBE|19-05-02|P14|[FLAGGED-UNVERIFIED] Non-finite, missing, unavailable, or unregistered predictors are never replaced with zero or silently dropped from the frozen candidate formula.|model|rejected
# PHASE19_PROBE|19-05-03|P15|[FLAGGED-UNVERIFIED] Training rows at or after the exclusive boundary, including same-batch outcomes, never enter a fit.|temporal|rejected
# PHASE19_PROBE|19-06-01|P16|[FLAGGED-UNVERIFIED] Outer assessment or held-out-league labels never fit, choose, or validate a calibrator used on that fold.|calibration|rejected
# PHASE19_PROBE|19-06-02|P17|[FLAGGED-UNVERIFIED] Calibration never rewrites score-grid cells, expected goals, likely scores, or source distribution identity.|calibration|preserved
# PHASE19_PROBE|19-06-03|P18|[FLAGGED-UNVERIFIED] A raw fallback, optimizer failure, insufficient support, or worse proper score never becomes approved calibrated authority.|calibration|failed
# PHASE19_PROBE|19-07-01|P19|[FLAGGED-UNVERIFIED] Candidate and incumbent scores are never compared on different fixture sets, denominators, score supports, or probability views.|evaluation|rejected
# PHASE19_PROBE|19-07-02|P20|[FLAGGED-UNVERIFIED] Missing, duplicate, failed, cold-start, or disconnected predictions never disappear before coverage and gate evaluation.|evaluation|rejected
# PHASE19_PROBE|19-07-03|P21|[FLAGGED-UNVERIFIED] A fixture diagnostic gate pass, blocked/unreviewed production run, or history-only authority never produces promotion_status=promoted.|promotion|ineligible
# PHASE19_PROBE|19-08-01|P22|[FLAGGED-UNVERIFIED] Metadata preflight never reads model/calibrator RDS bytes before trusted-root, exact inventory, parent authority, and file-hash validation succeeds.|release|preflight
# PHASE19_PROBE|19-08-02|P23|[FLAGGED-UNVERIFIED] A compatible R object, copied file, selector swap, relabeled contract, fixture bundle, or alternate root never bypasses explicit forecast-domain authority.|domain|rejected
# PHASE19_PROBE|19-08-03|P24|[FLAGGED-UNVERIFIED] Failed/interrupted/concurrent install or selector replacement never corrupts or replaces the prior approved club authority.|transaction|rollback
# PHASE19_PROBE|19-09-01|P25|[FLAGGED-UNVERIFIED] Club orchestration never depends on phase12_approved_release, national selectors/models/calibrators, national feature/form tables, FIFA identity, or World Cup/Euro benchmark states.|orchestration|isolated
# PHASE19_PROBE|19-09-02|P26|[FLAGGED-UNVERIFIED] A history/current-UCL/review-blocked production run never fits, evaluates as production, creates a release generation, advances a selector, or mutates prior production descriptors.|orchestration|blocked
# PHASE19_PROBE|19-09-03|P27|[FLAGGED-UNVERIFIED] Fixture mode never accepts a production output root or loses fixture authority in any artifact/target result.|orchestration|rejected
# PHASE19_PROBE|19-10-01|P28|[FLAGGED-UNVERIFIED] Nominal happy-path tests never substitute for exact adversarial probes at authority, temporal, domain, filesystem, and transaction boundaries.|inventory|exact
# PHASE19_PROBE|19-10-02|P29|[FLAGGED-UNVERIFIED] Missing, renamed, filtered, skipped, warning-producing, or newly added unmapped Phase 19 tests/prohibitions never count as a passing gate.|inventory|exact
# PHASE19_PROBE|19-10-03|P30|[FLAGGED-UNVERIFIED] Verification never manufactures accepted Phase 18 history/current-UCL evidence, owner policy/fold review, a production club release, or a selector.|verification|human_needed

phase19_adversarial_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/", mustWork = TRUE
)

phase19_adversarial_probe_inventory <- function(path = file.path(
    phase19_adversarial_root, "tests/testthat/test_phase19_adversarial_regression.R")) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  lines <- lines[startsWith(lines, "# PHASE19_PROBE|")]
  fields <- lapply(lines, function(line) {
    value <- strsplit(sub("^# PHASE19_PROBE\\|", "", line), "|", fixed = TRUE)[[1L]]
    if (length(value) != 5L) stop("Malformed Phase 19 probe inventory row", call. = FALSE)
    value
  })
  if (!length(fields)) return(data.frame())
  result <- as.data.frame(do.call(rbind, fields), stringsAsFactors = FALSE)
  names(result) <- c("plan_task", "probe_id", "description", "boundary", "outcome")
  result$identity <- result$plan_task
  result[, c("identity", "plan_task", "probe_id", "description", "boundary", "outcome"), drop = FALSE]
}

.phase19_adversarial_hits <- character()
phase19_adversarial_hit <- function(probe_id) {
  inventory <- phase19_adversarial_probe_inventory()
  if (!identical(length(probe_id), 1L) || !probe_id %in% inventory$probe_id) {
    stop("Unknown Phase 19 probe id: ", probe_id, call. = FALSE)
  }
  .phase19_adversarial_hits <<- unique(c(.phase19_adversarial_hits, probe_id))
  invisible(probe_id)
}

phase19_adversarial_load <- local({
  loaded <- FALSE
  function() {
    if (isTRUE(loaded)) return(invisible(TRUE))
    source(file.path(phase19_adversarial_root, "tests/testthat/helper_phase19_club_fixture.R"), local = .GlobalEnv)
    phase19_test_load()
    source(file.path(phase19_adversarial_root, "R/evaluation/proper_scores.R"), local = .GlobalEnv)
    source(file.path(phase19_adversarial_root, "R/evaluation/benchmark_scores.R"), local = .GlobalEnv)
    source(file.path(phase19_adversarial_root, "R/release/domain_contract.R"), local = .GlobalEnv)
    source(file.path(phase19_adversarial_root, "R/club/evaluation_protocol.R"), local = .GlobalEnv)
    source(file.path(phase19_adversarial_root, "R/club/rating.R"), local = .GlobalEnv)
    source(file.path(phase19_adversarial_root, "R/club/goal_model.R"), local = .GlobalEnv)
    source(file.path(phase19_adversarial_root, "R/club/calibration.R"), local = .GlobalEnv)
    source(file.path(phase19_adversarial_root, "R/club/evaluation.R"), local = .GlobalEnv)
    source(file.path(phase19_adversarial_root, "R/release/release_bundle.R"), local = .GlobalEnv)
    source(file.path(phase19_adversarial_root, "R/release/release_install.R"), local = .GlobalEnv)
    source(file.path(phase19_adversarial_root, "R/release/release_contract.R"), local = .GlobalEnv)
    source(file.path(phase19_adversarial_root, "R/competition/forecast_layer.R"), local = .GlobalEnv)
    source(file.path(phase19_adversarial_root, "R/club/release.R"), local = .GlobalEnv)
    loaded <<- TRUE
    invisible(TRUE)
  }
})

phase19_adversarial_error <- function(expression, reason_code = NULL) {
  result <- tryCatch(force(expression), error = function(error) error)
  expect_true(inherits(result, "error"), info = "Expected a public boundary to reject the attack")
  if (!is.null(reason_code)) expect_identical(as.character(result$reason_code), reason_code)
  result
}

phase19_adversarial_current_matching <- function(current) {
  ids <- c("club_alpha", "club_beta", "club_gamma", "club_delta")
  clubs <- current$clubs[seq_along(ids), , drop = FALSE]
  clubs$provider_club_id <- as.character(9000L + seq_along(ids))
  clubs$club_id <- ids
  clubs$display_name <- paste("Adversarial", ids)
  clubs$canonical_name <- clubs$display_name
  clubs$row_sha256 <- ""
  clubs$row_sha256 <- phase18_ucl_projected_row_hash(clubs)
  clubs <- clubs[order(clubs$club_id, method = "radix"), , drop = FALSE]
  rownames(clubs) <- NULL
  current$clubs <- clubs
  current$club_count <- as.integer(nrow(clubs))
  current$roster_sha256 <- phase18_hash_table_v2(clubs, key = "club_id", schema_tag = "phase19-current-ucl-club-roster-v1")
  current$snapshot_sha256 <- phase19_current_snapshot_sha256(current)
  phase19_validate_current_ucl_club_snapshot(current, "fixture")
  current
}

phase19_adversarial_rating_context <- function() {
  phase19_adversarial_load()
  root <- phase19_test_fixture_root("adversarial-rating")
  training <- phase19_load_fixture_club_training_snapshot(root)
  current <- phase19_adversarial_current_matching(phase19_load_fixture_current_ucl_club_snapshot(root))
  parameters <- phase19_club_rating_parameters(base_rating = 1500, home_advantage = 60, k_factor = 20, inactivity_factor = 0.995)
  state <- phase19_initialize_club_rating_state(training, current, parameters)
  batch <- data.frame(
    fixture_id = c("fixture_b", "fixture_a"), forecast_domain = "club", authority_mode = "fixture",
    boundary_id = "kickoff:2025-05-01T18:00:00Z", kickoff_utc = "2025-05-01T18:00:00Z",
    home_club_id = c("club_gamma", "club_alpha"), away_club_id = c("club_delta", "club_beta"),
    status = "completed", counts_for_model = TRUE, regulation_home_goals = c(0L, 4L),
    regulation_away_goals = c(1L, 0L), extra_time_home_goals = c(3L, NA_integer_),
    extra_time_away_goals = c(2L, NA_integer_), stringsAsFactors = FALSE, check.names = FALSE
  )
  list(root = root, training = training, current = current, parameters = parameters, state = state, batch = batch)
}

phase19_adversarial_fold_context <- function() {
  phase19_adversarial_load()
  root <- phase19_test_fixture_root("adversarial-fold")
  training <- phase19_load_fixture_club_training_snapshot(root)
  protocol <- phase19_load_fixture_club_evaluation_protocol()
  folds <- phase19_build_fixture_club_fold_registry(training, protocol)
  list(root = root, training = training, protocol = protocol, folds = folds)
}

phase19_adversarial_calibration_fold <- function(protocol) {
  ids <- sprintf("cal_%03d", seq_len(60L))
  row <- data.frame(
    schema_version = "phase19-club-fold-v1", hash_encoding_version = phase18_canonical_encoding_v2(),
    forecast_domain = "club", authority_mode = "fixture", fixture_authority = TRUE,
    fold_id = "club__heldout_league_transport__league-z__2025-26", fold_family = "heldout_league_transport",
    assessment_competition_id = "league-z", assessment_season_id = "2025-26",
    assessment_start_utc = "2025-03-01T00:00:00Z", assessment_end_utc = "2025-05-31T00:00:00Z",
    training_cutoff_exclusive = "2025-01-01T00:00:00Z", calibration_cutoff_exclusive = "2025-03-01T00:00:00Z",
    declared_fixture_ids = "assessment_a|assessment_b", declared_fixture_count = 2L,
    declared_fixture_sha256 = phase19_fold_id_sha256(c("assessment_a", "assessment_b"), "declared"),
    training_fixture_ids = "fit_a|fit_b", training_fixture_count = 2L,
    training_fixture_sha256 = phase19_fold_id_sha256(c("fit_a", "fit_b"), "training"),
    calibration_fixture_ids = paste(ids, collapse = "|"), calibration_fixture_count = 60L,
    calibration_fixture_sha256 = phase19_fold_id_sha256(ids, "calibration"), held_out_competition_id = "league-z",
    fit_excluded_competition_id = "league-z", tuning_excluded_competition_id = "league-z",
    calibration_excluded_competition_id = "league-z", eligibility_status = "eligible", support_reason_code = "",
    accepted_generation_id = "phase19-adversarial-calibration", corpus_manifest_sha256 = strrep("a", 64L),
    snapshot_sha256 = strrep("b", 64L), protocol_sha256 = protocol$protocol_sha256,
    policy_review_sha256 = protocol$policy_review$review_sha256, calibration_recipe_sha256 = phase19_expected_calibration_recipe()$recipe_sha256,
    row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  row$row_sha256 <- phase19_fold_row_sha256(row)
  row
}

phase19_adversarial_calibration_rows <- function(fold, candidate_id = "club_elo_nb") {
  fixture_ids <- strsplit(fold$calibration_fixture_ids[[1L]], "|", fixed = TRUE)[[1L]]
  observed <- rep(c("home", "draw", "away"), length.out = length(fixture_ids))
  probability <- rbind(home = c(0.58, 0.24, 0.18), draw = c(0.37, 0.39, 0.24), away = c(0.25, 0.25, 0.50))[observed, , drop = FALSE]
  rows <- data.frame(
    fixture_id = fixture_ids, candidate_id = candidate_id, outer_fold_id = fold$fold_id,
    inner_fold_id = rep(c("inner_01", "inner_02", "inner_03"), length.out = length(fixture_ids)),
    evidence_role = "inner_out_of_fold", competition_id = "league-a", event_date = "2025-02-01",
    kickoff_utc = "2025-02-01T18:00:00Z", kickoff_precision = "instant",
    completion_not_before_utc = "2025-02-01T20:00:00Z", evidence_available_at_utc = "2025-02-01T20:00:00Z",
    counts_for_model = TRUE, p_home_raw = probability[, 1L], p_draw_raw = probability[, 2L], p_away_raw = probability[, 3L],
    observed_class = observed, source_grid_sha256 = vapply(fixture_ids, function(id) digest::digest(paste0("grid-", id), algo = "sha256", serialize = FALSE), character(1)),
    source_prediction_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
  )
  rows$source_prediction_sha256 <- phase19_club_calibration_source_row_sha256(rows)
  rows
}

phase19_adversarial_calibration_predictions <- function() {
  data.frame(
    fixture_id = c("assessment_b", "assessment_a"), candidate_id = "club_elo_nb", evidence_cutoff_exclusive = "2025-03-01T00:00:00Z",
    p_home = c(0.31, 0.62), p_draw = c(0.29, 0.23), p_away = c(0.40, 0.15), p_over_2_5 = c(0.55, 0.63), p_btts = c(0.48, 0.57),
    expected_home_goals = c(1.1, 1.8), expected_away_goals = c(1.4, 0.8), likely_home_goals = c(1L, 2L), likely_away_goals = c(1L, 1L),
    distribution_sha256 = vapply(c("assessment_b", "assessment_a"), function(id) digest::digest(paste0("assessment-grid-", id), algo = "sha256", serialize = FALSE), character(1)),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase19_adversarial_minimal_decision <- function() {
  structure(list(
    schema_version = "phase19-club-promotion-decision-v1", hash_encoding_version = phase18_canonical_encoding_v2(), forecast_domain = "club", authority_mode = "fixture", fixture_authority = TRUE,
    candidate_id = "club_elo_nb", incumbent_id = "club_venue_nb", selected_model_id = "club_elo_nb", diagnostic_gate_outcome = "pass", authority_eligibility = "fixture_ineligible", promotion_status = "ineligible_fixture", decision_sha256 = strrep("5", 64L)
  ), class = c("phase19_club_promotion_decision", "list"))
}

phase19_adversarial_minimal_model <- function() {
  structure(list(
    schema_version = "phase19-club-goal-fit-v1", forecast_domain = "club", authority_mode = "fixture", fixture_authority = TRUE, promotion_eligible = FALSE, model_id = "club_elo_nb", model_family = "negative_binomial", fit_status = "converged", fallback_status = "none", fit_sha256 = strrep("6", 64L), training_snapshot_sha256 = strrep("7", 64L), current_snapshot_sha256 = strrep("8", 64L), protocol_sha256 = strrep("d", 64L), cutoff_utc = "2025-01-01T00:00:00Z", support_max = 40L, active_features = c("elo_difference_for_team", "venue_role")
  ), class = c("phase19_club_goal_fit", "list"))
}

phase19_adversarial_minimal_calibrator <- function() {
  structure(list(
    schema_version = "phase19-club-calibrator-v1", forecast_domain = "club", authority_mode = "fixture", fixture_authority = TRUE, promotion_eligible = FALSE, model_id = "club_elo_nb", candidate_id = "club_elo_nb", calibrator_id = "adversarial-calibrator", fit_status = "fitted", distribution_unchanged = TRUE, calibrator_sha256 = strrep("9", 64L), protocol_sha256 = strrep("d", 64L), calibration_data_cutoff = "2025-01-01T00:00:00Z"
  ), class = c("phase19_club_calibrator", "list"))
}

phase19_adversarial_release_generation <- local({
  cached <- NULL
  function() {
    if (!is.null(cached)) return(cached)
    phase19_adversarial_load()
    old_directory <- getwd()
    setwd(phase19_adversarial_root)
    on.exit(setwd(old_directory), add = TRUE)
    script <- file.path(phase19_adversarial_root, "scripts/run_phase19_club_evaluation.R")
    lines <- readLines(script, warn = FALSE, encoding = "UTF-8")
    main <- which(trimws(lines) == "phase19_cli_main()")
    if (length(main) != 1L) stop("RED: fixture CLI main boundary is not exact", call. = FALSE)
    eval(parse(text = lines[seq_len(main - 1L)]), envir = .GlobalEnv)
    fixture_root <- phase19_test_fixture_root("adversarial-release")
    output_root <- tempfile("phase19-adversarial-release-output-", tmpdir = tempdir())
    release_root <- tempfile("phase19-adversarial-release-authority-", tmpdir = tempdir())
    dir.create(output_root, recursive = TRUE)
    dir.create(release_root, recursive = TRUE)
    record <- phase19_cli_fixture(list(
      fixture_root = fixture_root, output_root = output_root, release_root = release_root
    ))
    generation <- file.path(release_root, as.character(record$release_id))
    if (!dir.exists(generation)) stop("RED: fixture CLI did not publish a typed release", call. = FALSE)
    cached <<- generation
    generation
  }
})

phase19_adversarial_stage_release <- function(label) {
  generation <- phase19_adversarial_release_generation()
  root <- tempfile(paste0("phase19-adversarial-release-", label, "-"), tmpdir = tempdir())
  staged_root <- file.path(root, "staged")
  dir.create(staged_root, recursive = TRUE)
  children <- list.files(generation, all.files = TRUE, no.. = TRUE, full.names = TRUE)
  copied <- vapply(children, function(child) {
    file.copy(child, staged_root, recursive = TRUE, copy.date = TRUE)
  }, logical(1))
  if (any(!copied)) stop("RED: typed fixture release copy failed", call. = FALSE)
  list(root = root, staged = list(release_root = staged_root))
}

phase19_adversarial_cli <- function(arguments = character()) {
  script <- file.path(phase19_adversarial_root, "scripts/run_phase19_club_evaluation.R")
  output <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", shQuote(script), vapply(arguments, shQuote, character(1))), stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  list(status = as.integer(status), text = paste(output, collapse = "\n"))
}

phase19_adversarial_byte_map <- function(paths) {
  result <- list()
  for (path in paths) {
    path <- normalizePath(path, winslash = "/", mustWork = FALSE)
    if (!file.exists(path) && !dir.exists(path)) {
      result[[path]] <- "<absent>"
      next
    }
    entries <- if (dir.exists(path)) list.files(path, recursive = TRUE, all.files = TRUE, full.names = TRUE, include.dirs = FALSE, no.. = TRUE) else path
    if (!length(entries)) {
      result[[path]] <- "<empty>"
      next
    }
    result[[path]] <- vapply(entries, function(entry) {
      rel <- if (identical(entry, path)) basename(entry) else substring(entry, nchar(paste0(path, "/")) + 1L)
      if (nzchar(Sys.readlink(entry))) paste0(rel, "=<symlink>") else paste0(rel, "=", digest::digest(entry, algo = "sha256", file = TRUE))
    }, character(1))
  }
  result
}

test_that("the Phase 19 prohibition inventory is exact and executable", {
  inventory <- phase19_adversarial_probe_inventory()
  expect_identical(nrow(inventory), 30L)
  expect_identical(anyDuplicated(inventory$identity), 0L)
  expect_identical(anyDuplicated(inventory$probe_id), 0L)
  expect_true(all(grepl("^19-(0[1-9]|10)-0[1-3]$", inventory$plan_task)))
  phase19_adversarial_hit("P29")
})

test_that("the aggregate Phase 19 contract verifier is present", {
  expect_true(file.exists(file.path(phase19_adversarial_root, "scripts", "verify_phase19_contracts.R")))
})

test_that("authority, enrichment, and fixture escalation probes use public validators", {
  phase19_adversarial_load()
  phase19_adversarial_error(phase19_load_club_training_snapshot(untrusted_path = "audit.csv"))
  phase19_adversarial_hit("P01")
  protocol <- phase19_load_fixture_club_evaluation_protocol()
  phase19_adversarial_error(phase19_club_goal_reject_unavailable_columns(data.frame(current_xg = 0, stringsAsFactors = FALSE), protocol$feature_contract, "adversarial"))
  phase19_adversarial_hit("P02")
  root <- phase19_test_fixture_root("authority-escalation")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  training <- phase19_load_fixture_club_training_snapshot(root)
  phase19_adversarial_error(phase19_assert_production_club_authority(training), "fixture_authority")
  phase19_adversarial_error(phase19_stage_production_club_release(phase19_adversarial_minimal_decision(), phase19_adversarial_minimal_model(), phase19_adversarial_minimal_calibrator(), output_root = file.path(tempdir(), "phase19-never-production-root")))
  phase19_adversarial_hit("P03")
})

test_that("current authority, identity generations, and policy/fold reviews fail closed", {
  phase19_adversarial_load()
  expect_identical(phase19_current_ucl_acceptance_reason("no_incumbent"), "no_accepted_current_ucl")
  expect_identical(phase19_current_ucl_acceptance_reason("withdrawn"), "no_accepted_current_ucl")
  incomplete_root <- phase19_test_fixture_root("identity-incomplete", current_identity_complete = FALSE)
  on.exit(unlink(incomplete_root, recursive = TRUE, force = TRUE), add = TRUE)
  incomplete <- phase19_load_fixture_current_ucl_club_snapshot(incomplete_root)
  expect_identical(incomplete$status, "blocked")
  expect_identical(incomplete$reason_code, "current_ucl_identity_incomplete")
  identity_root <- phase19_test_fixture_root("identity-drift")
  on.exit(unlink(identity_root, recursive = TRUE, force = TRUE), add = TRUE)
  current <- phase19_load_fixture_current_ucl_club_snapshot(identity_root)
  current$identity_generation <- "forged-generation"
  phase19_adversarial_error(phase19_validate_current_ucl_club_snapshot(current, "fixture"), "invalid_snapshot")
  protocol <- phase19_load_fixture_club_evaluation_protocol()
  pending <- phase19_evaluate_policy_review(protocol, protocol$policy_review, "production")
  expect_identical(pending$status, "blocked")
  expect_identical(pending$reason_code, "protocol_policy_not_approved")
  forged <- protocol$policy_review
  forged$review_sha256 <- strrep("f", 64L)
  expect_identical(phase19_evaluate_policy_review(protocol, forged, "production")$reason_code, "protocol_policy_not_approved")
  fold_root <- phase19_test_fixture_root("review-pending")
  on.exit(unlink(fold_root, recursive = TRUE, force = TRUE), add = TRUE)
  training <- phase19_load_fixture_club_training_snapshot(fold_root)
  phase19_publish_fixture_fold_candidate(fold_root, training, protocol, strrep("a", 40L))
  fold <- phase19_load_fixture_fold_protocol(fold_root)
  expect_identical(fold$status, "blocked")
  expect_identical(fold$reason_code, "fold_inventory_not_approved")
  phase19_adversarial_hit("P12")
})

test_that("rating identity, batch, and inactivity probes preserve frozen semantics", {
  context <- phase19_adversarial_rating_context()
  on.exit(unlink(context$root, recursive = TRUE, force = TRUE), add = TRUE)
  national <- context$batch
  national$home_club_id[[1L]] <- "AUT"
  phase19_adversarial_error(phase19_forecast_club_rating_batch(context$state, national))
  phase19_adversarial_hit("P04")
  first <- phase19_forecast_club_rating_batch(context$state, context$batch)
  second <- phase19_forecast_club_rating_batch(context$state, context$batch[2:1, , drop = FALSE])
  expect_identical(serialize(first$predictions, NULL, version = 3), serialize(second$predictions, NULL, version = 3))
  changed <- context$batch
  changed$regulation_home_goals[changed$fixture_id == "fixture_a"] <- 12L
  changed_result <- phase19_forecast_club_rating_batch(context$state, changed)
  peer <- first$predictions$fixture_id == "fixture_b"
  expect_identical(first$predictions[peer, c("home_pre_match_rating", "away_pre_match_rating", "pre_batch_state_sha256")], changed_result$predictions[changed_result$predictions$fixture_id == "fixture_b", c("home_pre_match_rating", "away_pre_match_rating", "pre_batch_state_sha256")])
  phase19_adversarial_hit("P05")
  completed <- first$state
  postponed <- context$batch
  postponed$status <- "postponed"
  postponed$counts_for_model <- FALSE
  postponed$regulation_home_goals <- NA_integer_
  postponed$regulation_away_goals <- NA_integer_
  postponed$kickoff_utc <- "2027-05-01T18:00:00Z"
  postponed$boundary_id <- "kickoff:2027-05-01T18:00:00Z"
  decayed <- phase19_forecast_club_rating_batch(completed, postponed)$state
  base <- context$parameters$base_rating
  expect_true(all((decayed$clubs$rating - base) * (completed$clubs$rating - base) >= 0))
  expect_identical(decayed$clubs$prior_match_count, completed$clubs$prior_match_count)
  phase19_adversarial_hit("P06")
})

test_that("protocol registry and national-authority attacks are rejected", {
  phase19_adversarial_load()
  protocol <- phase19_load_fixture_club_evaluation_protocol()
  gates <- protocol$gate_registry
  gates$threshold[[1L]] <- gates$threshold[[1L]] + 1
  phase19_adversarial_error(phase19_validate_gate_registry(gates))
  phase19_adversarial_hit("P07")
  phase19_adversarial_error(phase19_protocol_assert_no_national_authority(list(open_core = "world_cup", fifa_code = "AUT"), "attack"), "protocol_domain_mismatch")
  phase19_adversarial_hit("P08")
  candidates <- protocol$candidate_registry
  candidates$release_selectable[[1L]] <- TRUE
  phase19_adversarial_error(phase19_validate_candidate_registry(candidates, protocol$feature_contract))
  phase19_adversarial_hit("P09")
})

test_that("fold temporal and held-out evidence attacks fail at public role validators", {
  context <- phase19_adversarial_fold_context()
  on.exit(unlink(context$root, recursive = TRUE, force = TRUE), add = TRUE)
  fold <- context$folds[1L, , drop = FALSE]
  rows <- phase19_fold_role_evidence(context$training, fold, "fit")
  fold$fit_excluded_competition_id <- as.character(rows$competition_id[[1L]])
  phase19_adversarial_error(phase19_validate_fold_role_evidence(rows, fold, "fit"), "fold_heldout_leakage")
  fold$fit_excluded_competition_id <- as.character(context$folds$fit_excluded_competition_id[[1L]])
  rows$completion_not_before_utc[[1L]] <- fold$training_cutoff_exclusive[[1L]]
  phase19_adversarial_error(phase19_validate_fold_role_evidence(rows, fold, "fit"), "fold_temporal_leakage")
  phase19_adversarial_hit("P10")
  phase19_adversarial_hit("P11")
})

test_that("goal-model fallback, feature, and cutoff attacks fail closed", {
  context <- phase19_adversarial_rating_context()
  on.exit(unlink(context$root, recursive = TRUE, force = TRUE), add = TRUE)
  protocol <- phase19_load_fixture_club_evaluation_protocol()
  registration <- protocol$candidate_registry[protocol$candidate_registry$model_id == "club_elo_nb", , drop = FALSE]
  rating <- phase19_replay_club_ratings(context$training, context$current, context$parameters)
  fit <- phase19_fit_club_goal_model(registration, context$training, rating, protocol, context$training$cutoff_utc)
  forged <- fit
  forged$fallback_status <- "poisson"
  phase19_adversarial_error(phase19_validate_club_goal_fit(forged), "invalid_fit")
  phase19_adversarial_hit("P13")
  phase19_adversarial_error(phase19_club_goal_reject_unavailable_columns(data.frame(injury = 0, stringsAsFactors = FALSE), protocol$feature_contract, "formula"))
  phase19_adversarial_hit("P14")
  phase19_adversarial_error(phase19_club_goal_eligible_history(context$training, "2025-02-01T20:00:00Z"), "insufficient_training_support")
  phase19_adversarial_hit("P15")
})

test_that("nested calibration rejects outer labels, preserves distributions, and never falls back", {
  phase19_adversarial_load()
  protocol <- phase19_load_fixture_club_evaluation_protocol()
  fold <- phase19_adversarial_calibration_fold(protocol)
  candidate <- protocol$candidate_registry[protocol$candidate_registry$model_id == "club_elo_nb", , drop = FALSE]
  rows <- phase19_adversarial_calibration_rows(fold)
  outer <- rows
  outer$fixture_id[[1L]] <- "assessment_a"
  outer$source_prediction_sha256 <- phase19_club_calibration_source_row_sha256(outer)
  rejected <- phase19_fit_club_calibrator(outer, fold, candidate, protocol)
  expect_identical(rejected$fit_status, "failed")
  expect_false(rejected$authoritative)
  phase19_adversarial_hit("P16")
  calibrator <- phase19_fit_club_calibrator(rows, fold, candidate, protocol)
  applied <- phase19_apply_club_calibrator(calibrator, phase19_adversarial_calibration_predictions(), fold)
  expect_identical(applied$predictions$distribution_sha256, applied$predictions$source_distribution_sha256)
  expect_identical(applied$predictions$p_over_2_5, applied$predictions$p_over_2_5_raw)
  expect_identical(applied$predictions$expected_home_goals, applied$predictions$expected_home_goals_raw)
  expect_true(all(applied$predictions$distribution_unchanged))
  phase19_adversarial_hit("P17")
  failed <- phase19_fit_club_calibrator(rows, fold, candidate, protocol, optimizer_fn = function(...) stop("injected optimizer failure"))
  expect_identical(failed$fit_status, "failed")
  expect_identical(failed$failure_reason_code, "optimizer_failed")
  expect_false(failed$authoritative)
  expect_error(phase19_validate_club_calibrator(failed, require_fitted = TRUE), class = "phase19_club_calibration_error")
  phase19_adversarial_hit("P18")
})

test_that("paired evaluation and promotion boundaries reject coverage and authority attacks", {
  context <- phase19_adversarial_fold_context()
  on.exit(unlink(context$root, recursive = TRUE, force = TRUE), add = TRUE)
  fold <- context$folds[1L, , drop = FALSE]
  declared <- phase19_fold_parse_id_text(fold$declared_fixture_ids[[1L]], "declared_fixture_ids")
  phase19_adversarial_error(phase19_validate_fold_prediction_coverage(fold, declared[-1L]), "fold_coverage_invalid")
  phase19_adversarial_hit("P19")
  phase19_adversarial_error(phase19_validate_fold_prediction_coverage(fold, c(declared, declared[[1L]])), "fold_coverage_invalid")
  phase19_adversarial_hit("P20")
  decision <- phase19_adversarial_minimal_decision()
  phase19_adversarial_error(phase19_club_release_decision_check(decision, "production"), "production_authority_invalid")
  expect_identical(decision$promotion_status, "ineligible_fixture")
  phase19_adversarial_hit("P21")
})

test_that("release metadata, domain, selector, lock, and rollback attacks preserve authority", {
  phase19_adversarial_load()
  fixture <- phase19_adversarial_stage_release("preflight")
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  object_path <- file.path(fixture$staged$release_root, "model/approved_model.rds")
  writeBin(charToRaw("not-an-rds"), object_path)
  phase19_adversarial_error(phase19_validate_club_release(fixture$staged$release_root, load_models = FALSE))
  phase19_adversarial_hit("P22")
  expect_error(assert_forecast_domain(list(forecast_domain = "club"), "national_team"), class = "phase19_domain_error")
  expect_error(phase19_validate_club_release(fixture$staged$release_root, load_models = FALSE, expected_domain = "national_team"), class = "phase19_club_release_error")
  phase19_adversarial_hit("P23")
  clean <- phase19_adversarial_stage_release("rollback")
  on.exit(unlink(clean$root, recursive = TRUE, force = TRUE), add = TRUE)
  installed <- phase19_install_club_release(clean$staged$release_root, file.path(clean$root, "approved"))
  selector_before <- readBin(installed$selector_path, "raw", file.info(installed$selector_path)$size)
  second <- phase19_adversarial_stage_release("lock")
  on.exit(unlink(second$root, recursive = TRUE, force = TRUE), add = TRUE)
  lock <- file.path(clean$root, "approved", ".approved_release.lock")
  file.create(lock)
  expect_error(phase19_install_club_release(second$staged$release_root, file.path(clean$root, "approved")), class = "phase19_club_release_error")
  unlink(lock)
  third <- phase19_adversarial_stage_release("interrupt")
  on.exit(unlink(third$root, recursive = TRUE, force = TRUE), add = TRUE)
  failing_validator <- function(root, load_models = TRUE, expected_domain = "club") {
    if (isTRUE(load_models)) stop("injected interrupted readback", call. = FALSE)
    phase19_validate_club_release(root, load_models = load_models, expected_domain = expected_domain)
  }
  expect_error(phase19_install_club_release(third$staged$release_root, file.path(clean$root, "approved"), validator = failing_validator))
  expect_identical(readBin(installed$selector_path, "raw", file.info(installed$selector_path)$size), selector_before)
  phase19_adversarial_hit("P24")
})

test_that("orchestration stays club-only, blocked, explicit, and non-promotable", {
  phase19_adversarial_load()
  withr::local_dir(phase19_adversarial_root)
  manifest <- targets::tar_manifest(fields = c(name, command, format), callr_function = NULL, script = "_targets.R")
  club <- manifest[grepl("^club_", manifest$name), , drop = FALSE]
  expect_false(any(grepl("phase12_approved_release|national|fifa|worldcup|euro|open_core", club$command, ignore.case = TRUE)))
  phase19_adversarial_hit("P25")
  protected <- c(file.path(phase19_adversarial_root, "data/club/history_current.json"), file.path(phase19_adversarial_root, "data/club/history_generations"), file.path(phase19_adversarial_root, "data/club/fold_protocol_runtime"), file.path(phase19_adversarial_root, "outputs/releases/club"), file.path(phase19_adversarial_root, "outputs/releases/approved_release.csv"))
  blocked_path <- file.path(phase19_adversarial_root, "outputs/club_model/blocked/phase19-production-blocked.json")
  existed <- file.exists(blocked_path)
  before <- phase19_adversarial_byte_map(protected)
  result <- phase19_adversarial_cli()
  expect_identical(result$status, 0L)
  expect_match(result$text, "status=human_needed", fixed = TRUE)
  expect_match(result$text, "reason_code=no_accepted_club_history", fixed = TRUE)
  expect_identical(phase19_adversarial_byte_map(protected), before)
  expect_false(file.exists(file.path(phase19_adversarial_root, "outputs/releases/club/approved_release.csv")))
  phase19_adversarial_hit("P26")
  if (!existed && file.exists(blocked_path)) {
    unlink(blocked_path, force = TRUE)
    blocked_dir <- dirname(blocked_path)
    model_dir <- dirname(blocked_dir)
    if (dir.exists(blocked_dir) && !length(list.files(blocked_dir, all.files = TRUE, no.. = TRUE))) unlink(blocked_dir, recursive = FALSE)
    if (dir.exists(model_dir) && !length(list.files(model_dir, all.files = TRUE, no.. = TRUE))) unlink(model_dir, recursive = FALSE)
  }
  fixture <- phase19_test_fixture_root("explicit-root")
  on.exit(unlink(fixture, recursive = TRUE, force = TRUE), add = TRUE)
  production_root <- file.path(phase19_adversarial_root, "outputs/releases/club")
  expect_error(phase19_stage_fixture_club_release(phase19_adversarial_minimal_decision(), phase19_adversarial_minimal_model(), phase19_adversarial_minimal_calibrator(), production_root, release_id = "escalation", history_snapshot = list(snapshot_sha256 = strrep("7", 64L)), current_snapshot = list(snapshot_sha256 = strrep("8", 64L))), class = "phase19_club_release_error")
  phase19_adversarial_hit("P27")
  phase19_adversarial_hit("P30")
})

test_that("every exact adversarial probe is exercised once and no nominal-only shortcut passes", {
  inventory <- phase19_adversarial_probe_inventory()
  expected <- inventory$probe_id
  expect_setequal(.phase19_adversarial_hits, setdiff(expected, "P28"))
  phase19_adversarial_hit("P28")
  expect_setequal(.phase19_adversarial_hits, expected)
})
