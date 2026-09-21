library(testthat)

if (!exists("phase20_fixture_graph_36x144", envir = .GlobalEnv, mode = "function")) {
  source(file.path(
    normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
                 winslash = "/", mustWork = TRUE),
    "tests/testthat/helper_uefa_champions_league.R"
  ), local = .GlobalEnv)
}

phase20_test_source_ucl <- function(relative) {
  source(file.path(phase20_test_project_root, relative), local = .GlobalEnv)
}

phase20_test_source_ucl("R/competition/uefa_champions_league_rules.R")
phase20_test_source_ucl("R/competition/uefa_champions_league_state.R")
phase20_test_source_ucl("R/competition/uefa_champions_league_simulation.R")
phase20_test_source_ucl("R/competition/uefa_champions_league_outcomes.R")

phase20_test_rules_evidence_path <- file.path(
  phase20_test_project_root,
  "data/competition/rules/ucl_2026_27_rules_and_draw_evidence.json"
)

phase20_test_read_rules_evidence <- function() {
  expect_true(file.exists(phase20_test_rules_evidence_path))
  jsonlite::fromJSON(phase20_test_rules_evidence_path, simplifyDataFrame = TRUE)
}

test_that("Wave 0 declares the complete 36-club / 144-fixture graph", {
  graph <- phase20_fixture_graph_36x144()

  expect_identical(nrow(graph$clubs), 36L)
  expect_identical(length(unique(graph$clubs$club_id)), 36L)
  expect_identical(nrow(graph$fixtures), 144L)
  expect_identical(length(unique(graph$fixtures$fixture_id)), 144L)
  expect_identical(graph$authority_mode, "fixture")
  expect_true(isTRUE(graph$fixture_authority))
  expect_false(isTRUE(graph$production_eligible))
  expect_true(is.null(graph$selector_path))
  expect_true(is.null(graph$production_root))
  expect_true(all(graph$fixtures$matchday %in% 1:8))
  expect_true(all(graph$fixtures$kickoff_confirmed))
  expect_true(all(nzchar(graph$fixtures$venue_id)))
  expect_true(all(nzchar(graph$fixtures$source_lineage_id)))
  degree <- table(c(graph$fixtures$home_club_id, graph$fixtures$away_club_id))
  expect_identical(as.integer(degree[graph$clubs$club_id]), rep(8L, 36L))
  expect_identical(as.integer(table(graph$fixtures$home_club_id)[graph$clubs$club_id]), rep(4L, 36L))
  expect_identical(as.integer(table(graph$fixtures$away_club_id)[graph$clubs$club_id]), rep(4L, 36L))
  expect_true(all(graph$fixtures$home_club_id != graph$fixtures$away_club_id))
  expect_true(all(grepl("^[0-9a-f]{64}$", graph$fixtures$source_row_sha256)))
})

test_that("Wave 0 keeps the approved-shape release fixture non-promotable", {
  release <- phase20_approved_release_fixture()
  expect_identical(release$authority_mode, "fixture")
  expect_true(isTRUE(release$fixture_authority))
  expect_false(isTRUE(release$production_eligible))
  expect_false(isTRUE(release$selector_authorized))
  expect_true(is.null(release$selector_path))
  expect_true(is.null(release$trusted_release_root))
  expect_identical(release$root_scope, "process_temporary")
  expect_identical(nrow(release$forecast_rows), 144L)
  expect_true(all(abs(release$forecast_rows$prob_home +
                     release$forecast_rows$prob_draw +
                     release$forecast_rows$prob_away - 1) < 1e-12))
  expect_true(all(release$forecast_rows$feature_cutoff_utc <
                  release$forecast_rows$kickoff_utc))
})

test_that("Wave 0 pins the exact seven regulation records and unresolved draw row", {
  evidence <- phase20_test_read_rules_evidence()
  expected_ids <- c("article_17", "article_18", "article_19", "article_20",
                    "article_21", "article_22", "annex_b",
                    "draw_procedure_2026_27")
  expected_urls <- c(
    article_17 = "https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-17-Match-system-league-phase-Online",
    article_18 = "https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-18-Equality-of-points-league-phase-Online",
    article_19 = "https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-19-Draw-system-knockout-phase-Online",
    article_20 = "https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-20-Match-system-knockout-phase-Online",
    article_21 = "https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-21-Knockout-system-extra-time-and-penalty-shoot-outs-Online",
    article_22 = "https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Article-22-Match-system-final-Online",
    annex_b = "https://documents.uefa.com/r/Regulations-of-the-UEFA-Champions-League-2026/27/Annex-B-UEFA-Champions-League-Competition-System-Online"
  )
  expect_identical(nrow(evidence), 8L)
  expect_setequal(evidence$document_id, expected_ids)
  expect_identical(names(evidence), c(
    "document_id", "article_or_annex", "edition_id", "canonical_domain",
    "canonical_article", "source_url", "artifact_url", "source_url_role",
    "reviewer", "reviewed_at_utc", "raw_sha256", "canonical_sha256",
    "accepted", "complete", "unresolved_reason"
  ))
  regulations <- evidence$document_id != "draw_procedure_2026_27"
  expect_true(all(evidence$edition_id == phase20_test_edition_id))
  expect_true(all(evidence$canonical_domain == "documents.uefa.com"))
  expect_identical(unname(evidence$source_url[regulations]), unname(expected_urls[evidence$document_id[regulations]]))
  expect_identical(unname(evidence$artifact_url[regulations]), unname(expected_urls[evidence$document_id[regulations]]))
  expect_true(all(evidence$accepted[regulations]))
  expect_true(all(evidence$complete[regulations]))
  expect_true(all(nzchar(evidence$reviewer[regulations])))
  expect_true(all(grepl("^[0-9a-f]{64}$", evidence$raw_sha256[regulations])))
  expect_true(all(grepl("^[0-9a-f]{64}$", evidence$canonical_sha256[regulations])))
  draw <- evidence[evidence$document_id == "draw_procedure_2026_27", , drop = FALSE]
  expect_identical(draw$article_or_annex, "draw_procedure")
  expect_identical(draw$canonical_article, "Article-19-Draw-system-knockout-phase-Online")
  expect_identical(draw$source_url, expected_urls[["article_19"]])
  expect_true(is.na(draw$artifact_url) || is.null(draw$artifact_url))
  expect_identical(draw$source_url_role, "governing_rule_anchor_for_missing_artifact")
  expect_identical(draw$reviewer, "unreviewed")
  expect_true(is.na(draw$reviewed_at_utc))
  expect_true(is.na(draw$raw_sha256))
  expect_true(is.na(draw$canonical_sha256))
  expect_false(isTRUE(draw$accepted))
  expect_false(isTRUE(draw$complete))
  expect_identical(draw$unresolved_reason, "missing_edition_draw_procedure")
})

test_that("Wave 0 records the closed Phase 19 parent-reason normalization map", {
  cases <- phase20_expected_parent_reason_cases()
  expect_identical(nrow(cases), 13L)
  expect_true(all(cases$normalized_status %in% c(
    "production_human_needed", "production_blocked"
  )))
  expect_setequal(unique(na.omit(cases$human_needed_reason)), c(
    "phase18_authority_missing", "phase19_cr01_cr05_repair_pending",
    "phase19_selector_not_accepted"
  ))
  expect_true(isTRUE(phase20_test_require_ucl_entrypoints("phase20_result_contract", "parent-reason-normalization")))
})

test_that("UCLRULE-01: project-owned league table and qualification bands", {
  expect_true(isTRUE(phase20_test_require_ucl_entrypoints(c("ucl_validate_schedule", "ucl_build_state"), "UCLRULE-01")))
})

test_that("UCLRULE-02: Article 18 ordered trace and unresolved rank interval", {
  expect_true(isTRUE(phase20_test_require_ucl_entrypoints("ucl_apply_article18", "UCLRULE-02")))
})

test_that("UCLRULE-03: accepted eight-opponent schedule contract", {
  expect_true(isTRUE(phase20_test_require_ucl_entrypoints("ucl_validate_schedule", "UCLRULE-03")))
})

test_that("UCLOUT-01: immutable approved pre-kickoff forecast ledger", {
  expect_true(isTRUE(phase20_test_require_ucl_entrypoints("ucl_build_forecast_ledger", "UCLOUT-01")))
})

test_that("UCLOUT-02: fixed-results conditional rank and band probabilities", {
  expect_true(isTRUE(phase20_test_require_ucl_entrypoints(c("ucl_run_simulation", "ucl_aggregate_rank_distributions"), "UCLOUT-02")))
})

test_that("UCLOUT-03: legal rank-constrained draw paths", {
  expect_true(isTRUE(phase20_test_require_ucl_entrypoints(c("ucl_enumerate_legal_knockout_paths", "ucl_validate_draw_artifact"), "UCLOUT-03")))
})

test_that("UCLOUT-04: two-leg and neutral-final resolution", {
  expect_true(isTRUE(phase20_test_require_ucl_entrypoints(c("ucl_resolve_two_leg_tie", "ucl_resolve_final"), "UCLOUT-04")))
})

test_that("UCLOUT-05: stage accounting and monotone progression", {
  expect_true(isTRUE(phase20_test_require_ucl_entrypoints(c("ucl_aggregate_stage_events", "ucl_validate_progression_reconciliation"), "UCLOUT-05")))
})

test_that("UCLOUT-06: canonical replay and protected incumbent bytes", {
  expect_true(isTRUE(phase20_test_require_ucl_entrypoints(c(
    "ucl_validate_outcome_candidate", "ucl_write_outcome_candidate",
    "ucl_outcomes_manifest"
  ), "UCLOUT-06")))
})

phase20_edge_inventory <- phase20_expected_edge_probe_inventory()
for (edge_index in seq_len(nrow(phase20_edge_inventory))) {
  edge <- phase20_edge_inventory[edge_index, , drop = FALSE]
  test_that(paste(edge$edge_id, "stable edge contract"), {
    expect_true(isTRUE(phase20_test_require_ucl_entrypoints(
      edge$required_entrypoint,
      scope = edge$edge_id
    )))
  })
}

phase20_test_fixture_candidate <- function(reverse = FALSE, completed = FALSE) {
  graph <- phase20_fixture_graph_36x144()
  if (isTRUE(completed)) graph <- phase20_test_completed_fixture_graph(graph)
  if (isTRUE(reverse)) graph <- phase20_fixture_reverse_order(graph)
  state <- ucl_build_state(graph, state_cutoff_utc = "2026-09-21T00:00:00Z")
  release <- phase20_approved_release_fixture(graph)
  ledger <- ucl_build_forecast_ledger(state, release = release, state_cutoff_utc = "2026-09-21T00:00:00Z")
  simulation <- ucl_run_simulation(state, ledger = ledger, simulations = 1L, seed = 20260921L)
  candidate <- ucl_validate_outcome_candidate(list(state = state, ledger = ledger, simulation = simulation))
  list(graph = graph, state = state, release = release, ledger = ledger, simulation = simulation, candidate = candidate)
}

test_that("UCLRULE-01/UCLRULE-03 validate the complete accepted schedule", {
  graph <- phase20_fixture_graph_36x144()
  validation <- ucl_validate_schedule(graph)
  expect_identical(validation$status, "ready")
  expect_identical(nrow(validation$clubs), 36L)
  expect_identical(nrow(validation$fixtures), 144L)
  expect_identical(validation$graph$graph_sha256, ucl_validate_schedule(phase20_fixture_reverse_order(graph))$graph_sha256)
  expect_true(all(validation$fixtures$matchday %in% 1:8))
  expect_true(all(table(c(validation$fixtures$home_club_id, validation$fixtures$away_club_id)) == 8L))
})

test_that("Schedule mutations are typed blocked states and never repaired", {
  mutations <- phase20_fixture_mutation_catalog()
  results <- lapply(mutations, ucl_validate_schedule)
  expect_true(all(vapply(results, function(value) inherits(value, "ucl_blocked_state"), logical(1))))
  expect_true(all(vapply(results, function(value) identical(value$status, "blocked"), logical(1))))
  expect_identical(nrow(mutations$missing_fixture$fixtures), 143L)
})

test_that("Article 18 retains an unresolved interval and ignores provider display order", {
  standings <- data.frame(
    team_id = c("a", "b", "c"), points = c(7L, 7L, 7L), provider_rank = c(1L, 2L, 3L),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  ranking <- ucl_apply_article18(standings, phase = "final")
  expect_true(all(is.na(ranking$rank)))
  expect_true(all(ranking$rank_interval_min == 1L))
  expect_true(all(ranking$rank_interval_max == 3L))
  expect_true(any(attr(ranking, "trace")$evidence_status == "missing"))
  expect_true(all(is.na(ranking$decisive_trace_id)))
})

test_that("Fixture authority supplies mechanics but production remains fail-closed", {
  protected_before <- phase20_test_protected_root_snapshot()
  fixture <- phase20_test_fixture_candidate()
  expect_identical(fixture$candidate$status, "unresolved_draw_procedure")
  expect_true(isTRUE(fixture$candidate$valid))
  expect_false(isTRUE(fixture$candidate$production_eligible))
  expect_true(isTRUE(fixture$candidate$fixture_authority))
  expect_identical(nrow(fixture$ledger$ledger), 144L)
  production <- ucl_build_forecast_ledger(fixture$state)
  expect_identical(production$authority$original_parent_reason, "no_accepted_club_history")
  expect_identical(production$authority$status, "production_human_needed")
  expect_false(isTRUE(production$production_eligible))
  expect_false(isTRUE(production$selector_authorized))
  expect_identical(phase20_test_protected_root_snapshot(), protected_before)
})

test_that("Completed forecast rows remain byte-identical when state is rebuilt", {
  graph <- phase20_test_completed_fixture_graph()
  state <- ucl_build_state(graph, state_cutoff_utc = "2026-09-21T00:00:00Z")
  release <- phase20_approved_release_fixture(graph)
  rebuilt <- ucl_build_forecast_ledger(state, release = release, prior_ledger = release$forecast_rows, state_cutoff_utc = "2026-09-21T00:00:00Z")
  expect_identical(rebuilt$ledger[1L, ], release$forecast_rows[1L, ])
})

test_that("Conditional simulation fixes settled rows, samples eligible opens, and is reproducible", {
  fixture <- phase20_test_fixture_candidate(completed = TRUE)
  repeat_run <- ucl_run_simulation(fixture$state, fixture$ledger, simulations = 1L, seed = 20260921L)
  expect_identical(fixture$simulation$run_id, repeat_run$run_id)
  expect_identical(fixture$simulation$rank_rows, repeat_run$rank_rows)
  expect_identical(nrow(fixture$simulation$rank_rows), 36L)
  aggregate <- ucl_aggregate_rank_distributions(fixture$simulation)
  expect_identical(aggregate$simulation_count, 1L)
  expect_true(nrow(aggregate$rank_distribution) > 0L)
  expect_true(all(aggregate$band_probabilities$probability >= 0 | is.na(aggregate$band_probabilities$probability)))
  expect_identical(fixture$simulation$status, "unresolved_draw_procedure")
})

test_that("Draw evidence gates legal paths and accepted same-edition conditioning", {
  fixture <- phase20_test_fixture_candidate()
  unresolved <- ucl_validate_draw_artifact()
  expect_identical(unresolved$status, "unresolved")
  expect_identical(unresolved$reason, "missing_edition_draw_procedure")
  rankings <- data.frame(club_id = sprintf("club-%02d", 1:36), rank = 1:36,
                         rank_interval_min = 1:36, rank_interval_max = 1:36,
                         rank_status = "resolved", stringsAsFactors = FALSE)
  pairings <- data.frame(participant_a = "club-09", participant_b = "club-24", stringsAsFactors = FALSE)
  draw <- list(edition_id = phase20_test_edition_id, source_bundle_id = fixture$state$source_bundle_id,
               accepted = TRUE, complete = TRUE, draw_artifact_id = "draw-2026-27",
               draw_artifact_sha256 = strrep("a", 64L), pairings = pairings)
  accepted <- ucl_validate_draw_artifact(draw, source_bundle_id = fixture$state$source_bundle_id)
  expect_identical(accepted$status, "accepted")
  paths <- ucl_enumerate_legal_knockout_paths(rankings, draw_artifact = draw, source_bundle_id = fixture$state$source_bundle_id)
  expect_identical(nrow(paths), 1L)
  expect_identical(paths$path_status, "accepted_draw")
  expect_identical(paths$draw_artifact_id, "draw-2026-27")
})

test_that("Two-leg and final resolvers apply no-away-goals and neutral-final rules", {
  first <- data.frame(home_club_id = "a", away_club_id = "b", final_home_goals = 1L, final_away_goals = 0L, stringsAsFactors = FALSE)
  second <- data.frame(home_club_id = "b", away_club_id = "a", final_home_goals = 0L, final_away_goals = 0L, venue_id = "b-home", stringsAsFactors = FALSE)
  aggregate <- ucl_resolve_two_leg_tie(first, second)
  expect_identical(aggregate$status, "resolved")
  expect_identical(aggregate$winner, "a")
  expect_false(isTRUE(aggregate$away_goals_used))
  et_second <- second
  et_second$final_home_goals <- 1L
  et_second$extra_time_home_goals <- 1L
  et_second$extra_time_away_goals <- 0L
  extra_time <- ucl_resolve_two_leg_tie(first, et_second)
  expect_identical(extra_time$winner, "b")
  penalties <- second
  penalties$penalty_home <- 4L
  penalties$penalty_away <- 3L
  penalty <- ucl_resolve_two_leg_tie(first, penalties)
  expect_identical(penalty$status, "resolved")
  final <- data.frame(home_club_id = "a", away_club_id = "b", neutral = TRUE,
                      final_home_goals = 1L, final_away_goals = 1L,
                      penalty_home = 5L, penalty_away = 4L, stringsAsFactors = FALSE)
  final_result <- ucl_resolve_final(final)
  expect_identical(final_result$winner, "a")
  expect_true(isTRUE(final_result$neutral))
})

test_that("Stage reconciliation accepts conserved resolved probabilities and flags bad bounds", {
  progression <- data.frame(
    club_id = rep("a", 3L), stage_id = c("league", "playoff", "final"), stage_order = 1:3,
    qualification_band = c("direct_round_of_16", "knockout_play_off", "eliminated"),
    probability = c(0.9, 0.1, 0), status = "resolved", stringsAsFactors = FALSE
  )
  expect_true(isTRUE(ucl_validate_progression_reconciliation(progression)$valid))
  bad <- progression
  bad$probability[1L] <- Inf
  expect_false(isTRUE(ucl_validate_progression_reconciliation(bad)$valid))
  events <- data.frame(stage_id = c("playoff", "playoff", "final"), status = c("resolved", "unresolved", "resolved"), stringsAsFactors = FALSE)
  counts <- ucl_aggregate_stage_events(events)
  expect_identical(counts$input_count, c(1L, 2L))
  expect_identical(counts$unresolved_count, c(0L, 1L))
})

test_that("Outcome candidates have exact artifact schemas and canonical reverse replay", {
  normal <- phase20_test_fixture_candidate()
  reverse <- phase20_test_fixture_candidate(reverse = TRUE)
  expect_true(isTRUE(normal$candidate$valid))
  expect_true(isTRUE(reverse$candidate$valid))
  expect_identical(normal$candidate$artifact_hashes, reverse$candidate$artifact_hashes)
  expected <- phase20_expected_output_schemas
  for (artifact in names(expected)) {
    if (identical(artifact, "outcomes_manifest")) next
    expect_identical(names(normal$candidate$artifacts[[artifact]]), expected[[artifact]])
  }
  manifest <- ucl_outcomes_manifest(normal$candidate)
  expect_identical(names(manifest), expected$outcomes_manifest)
  expect_true(grepl("^ucl-outcomes-", manifest$manifest_id))
})

test_that("Outcome writes are confined to a temporary sibling root", {
  fixture <- phase20_test_fixture_candidate()
  root <- tempfile("ucl20-outcome-")
  written <- ucl_write_outcome_candidate(fixture$candidate, output_root = root)
  expect_identical(written$status, "written")
  expect_identical(length(list.files(root, pattern = "\\.csv$")), 10L)
  expect_error(ucl_write_outcome_candidate(fixture$candidate, output_root = phase20_test_fixed_root), "process-temporary")
})

test_that("Parent reasons and typed result contracts remain closed", {
  cases <- phase20_expected_parent_reason_cases()
  for (index in seq_len(nrow(cases))) {
    normalized <- .ucl_state_normalize_parent_reason(cases$original_parent_reason[index])
    expect_identical(normalized$status, cases$normalized_status[index])
    expect_identical(normalized$human_needed_reason, cases$human_needed_reason[index])
    expect_identical(normalized$production_blocked_reason, cases$production_blocked_reason[index])
    expect_identical(normalized$normalization_error, cases$normalization_error[index])
  }
  contract <- phase20_result_contract(status = "production_human_needed", human_needed_reason = "phase19_cr01_cr05_repair_pending", original_parent_reason = "no_accepted_club_history")
  expect_true(isTRUE(phase20_verify_contracts(contract)))
  expect_identical(ucl20_parse_args(c("--edition-id=ucl_2026_27", "--simulations=2", "--seed=7", "--replay-check"))$simulations, 2L)
  expect_error(ucl20_parse_args("--fixture-root=/tmp/forbidden"), "does not accept")
})

test_that("The module registry contains exactly the 19 declared public seams", {
  module_env <- new.env(parent = .GlobalEnv)
  for (relative in c("R/competition/uefa_champions_league_rules.R", "R/competition/uefa_champions_league_state.R", "R/competition/uefa_champions_league_simulation.R", "R/competition/uefa_champions_league_outcomes.R")) {
    sys.source(file.path(phase20_test_project_root, relative), envir = module_env)
  }
  exported <- sort(ls(module_env, pattern = "^(ucl|ucl20|phase20)_"), method = "radix")
  expect_setequal(exported, sort(phase20_expected_public_symbols, method = "radix"))
})

test_that("UCLRULE-02 exposes the complete Article 18 trace and separate presentation order", {
  standings <- data.frame(
    club_id = c("club-b", "club-a", "club-c"),
    points = c(7L, 7L, 7L),
    goal_difference = c(0L, 0L, 0L),
    goals_for = c(0L, 0L, 0L),
    away_goals_scored = c(0L, 0L, 0L),
    wins = c(0L, 0L, 0L),
    away_wins = c(0L, 0L, 0L),
    opponent_points = c(0L, 0L, 0L),
    opponent_goal_difference = c(0L, 0L, 0L),
    opponent_goals_scored = c(0L, 0L, 0L),
    disciplinary_points = c(0L, 0L, 0L),
    club_coefficient = c(2, 1, 3),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  ranking <- ucl_apply_article18(standings, phase = "final")
  trace <- attr(ranking, "trace")
  expect_true(all(c(
    "edition_id", "tie_group_id", "criterion_order", "criterion_id",
    "subset_before", "subset_after", "evidence_status", "source_artifact_ids",
    "decisive", "rank_interval_min", "rank_interval_max", "ruleset_version",
    "ruleset_sha256", "row_sha256"
  ) %in% names(trace)))
  expect_identical(sort(unique(trace$criterion_order)), 1:10)
  expect_identical(as.character(trace$criterion_id[trace$criterion_order == 10L]), "club_coefficient")
  expect_true(any(trace$decisive))
  expect_true(all(ranking$rank_status == "resolved"))
  expect_true(all(!is.na(ranking$decisive_trace_id)))
  expect_true(all(c("presentation_rank", "presentation_order") %in% names(ranking)))
  expect_false(identical(ranking$rank, ranking$presentation_rank))
})

test_that("Interim Article 18 stops after criterion five without closing qualification rank", {
  standings <- data.frame(
    club_id = c("club-b", "club-a", "club-c"),
    points = c(7L, 7L, 7L),
    goal_difference = c(0L, 0L, 0L),
    goals_for = c(0L, 0L, 0L),
    away_goals_scored = c(0L, 0L, 0L),
    wins = c(0L, 0L, 0L),
    away_wins = c(0L, 0L, 0L),
    opponent_points = c(0L, 0L, 0L),
    opponent_goal_difference = c(0L, 0L, 0L),
    opponent_goals_scored = c(0L, 0L, 0L),
    disciplinary_points = c(0L, 0L, 0L),
    club_coefficient = c(2, 1, 3),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  ranking <- ucl_apply_article18(standings, phase = "interim")
  trace <- attr(ranking, "trace")
  expect_true(all(ranking$ranking_phase == "interim"))
  expect_true(all(is.na(ranking$rank)))
  expect_true(all(ranking$rank_status == "unresolved"))
  expect_true(all(trace$criterion_order <= 5L))
  expect_true(all(ranking$presentation_order %in% seq_len(nrow(ranking))))
  expect_true(all(ranking$presentation_rank == rank(ranking$presentation_order, ties.method = "first")))
})

test_that("Rank intervals touching 8 or 24 suppress the affected qualification band", {
  make_tie <- function(boundary, tie_size = 2L) {
    ids <- sprintf("club-%02d", seq_len(36L))
    start <- if (boundary == 8L) 7L else 24L
    points <- if (boundary == 8L) {
      c(seq(100L, 95L), rep(90L, tie_size), seq(89L, 62L))
    } else {
      c(seq(100L, 78L), rep(70L, tie_size), seq(69L, 59L))
    }
    points <- points[seq_len(36L)]
    data.frame(club_id = ids, points = points, stringsAsFactors = FALSE)
  }
  rank8 <- ucl_apply_article18(make_tie(8L), phase = "final")
  rank24 <- ucl_apply_article18(make_tie(24L), phase = "final")
  expect_true(all(rank8$qualification_band[rank8$club_id %in% c("club-07", "club-08")] == "unresolved"))
  expect_true(all(rank24$qualification_band[rank24$club_id %in% c("club-24", "club-25")] == "unresolved"))
  expect_true(all(is.na(rank8$rank[rank8$club_id %in% c("club-07", "club-08")])) )
  expect_true(all(is.na(rank24$rank[rank24$club_id %in% c("club-24", "club-25")])) )
})

test_that("Schedule validation rejects missing lineage hashes, mixed bundles, and score contradictions", {
  graph <- phase20_fixture_graph_36x144()
  no_hash <- graph
  no_hash$fixtures$source_row_sha256 <- NULL
  mixed_bundle <- graph
  mixed_bundle$fixtures$source_bundle_id[1L] <- "foreign-source-bundle"
  contradictory <- phase20_test_completed_fixture_graph(graph)
  contradictory$fixtures$final_home_goals[1L] <- contradictory$fixtures$regulation_home_goals[1L] + 1L
  for (candidate in list(no_hash, mixed_bundle, contradictory)) {
    result <- ucl_validate_schedule(candidate)
    expect_s3_class(result, "ucl_blocked_state")
    expect_identical(result$status, "blocked")
  }
})

test_that("Forecast ledger enforces strict cutoff equality and release lineage", {
  graph <- phase20_fixture_graph_36x144()
  state <- ucl_build_state(graph, state_cutoff_utc = "2026-09-01T00:00:00Z")
  release <- phase20_approved_release_fixture(graph)
  at_kickoff <- release
  at_kickoff$forecast_rows$feature_cutoff_utc[1L] <- graph$fixtures$kickoff_utc[1L]
  at_kickoff$forecast_rows$xg_home[2L] <- Inf
  at_kickoff$forecast_rows$source_bundle_id[3L] <- "foreign-source-bundle"
  ledger <- ucl_build_forecast_ledger(state, release = at_kickoff, state_cutoff_utc = "2026-09-01T00:00:00Z")
  expect_identical(nrow(ledger$ledger), 144L)
  expect_identical(ledger$ledger$suppression_reason[1L], "cutoff_violation")
  expect_identical(ledger$ledger$suppression_reason[2L], "insufficient_model_evidence")
  expect_identical(ledger$ledger$suppression_reason[3L], "lineage_mismatch")
  expect_true(all(c("prob_home", "prob_draw", "prob_away", "xg_home", "xg_away", "likely_score") %in% names(ledger$ledger)))
  repeat_ledger <- ucl_build_forecast_ledger(state, release = at_kickoff, prior_ledger = ledger$ledger, state_cutoff_utc = "2026-09-01T00:00:00Z")
  expect_identical(ledger$ledger, repeat_ledger$ledger)
})

test_that("CR-01 through CR-05 probes reject forged or unbacked parent evidence", {
  probes <- list(
    phase20_probe_cr01_forged_roster_rejected,
    phase20_probe_cr02_rating_replay_tamper_rejected,
    phase20_probe_cr03_forged_fold_rejected,
    phase20_probe_cr04_forged_probability_calibrator_rejected,
    phase20_probe_cr05_unbacked_installer_rejected
  )
  results <- lapply(probes, function(probe) probe())
  expect_true(all(vapply(results, is.list, logical(1))))
  expect_true(all(vapply(results, function(result) identical(result$status, "rejected"), logical(1))))
  expect_true(all(vapply(results, function(result) nzchar(result$original_parent_reason), logical(1))))
})
