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
  rankings <- phase20_fixture_resolved_rankings()
  draw <- phase20_fixture_accepted_draw(source_bundle_id = fixture$state$source_bundle_id)
  accepted <- ucl_validate_draw_artifact(draw, source_bundle_id = fixture$state$source_bundle_id)
  expect_identical(accepted$status, "accepted")
  paths <- ucl_enumerate_legal_knockout_paths(rankings, draw_artifact = draw, source_bundle_id = fixture$state$source_bundle_id)
  expect_identical(nrow(paths), nrow(draw$pairings))
  expect_true(all(paths$path_status == "accepted_draw"))
  expect_identical(as.character(paths$draw_artifact_id), rep(draw$draw_artifact_id, nrow(draw$pairings)))
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
  expect_true(all(grepl("^ucl-outcomes-", manifest$manifest_id)))
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

# -------------------------------------------------------------------------
# Plan 20-03 RED contracts.  These cases intentionally name the simulator
# seams before they are implemented; the first fresh-process run must fail.
# -------------------------------------------------------------------------

test_that("UCLOUT-02 fixes every settled lifecycle and samples only eligible open rows", {
  required <- c(".ucl_prepare_iteration_matches", ".ucl_sample_open_fixtures")
  missing <- required[!vapply(required, exists, logical(1), mode = "function", inherits = TRUE)]
  if (length(missing)) stop(phase20_test_missing_entrypoint_condition(missing, "20-03 conditional sampling"))
  graph <- phase20_fixture_settled_lifecycle_graph()
  ledger <- phase20_fixture_conditional_ledger(graph, score_grid_ids = graph$fixtures$fixture_id[6:144], suppressed_ids = graph$fixtures$fixture_id[7L])
  prepared <- .ucl_prepare_iteration_matches(graph$fixtures, cutoff_utc = phase20_test_information_cutoff_utc)
  expect_setequal(prepared$fixed_fixture_ids, graph$fixtures$fixture_id[1:5])
  sampled <- .ucl_sample_open_fixtures(prepared, ledger = ledger, seed = 20260921L, cutoff_utc = phase20_test_information_cutoff_utc)
  expect_true(all(graph$fixtures$fixture_id[1:5] %in% sampled$fixed_fixture_ids))
  expect_false(graph$fixtures$fixture_id[5L] %in% sampled$sampled_fixture_ids)
  expect_true(graph$fixtures$fixture_id[7L] %in% sampled$suppressed_fixture_ids)
  for (fixture_id in graph$fixtures$fixture_id[1:4]) {
    before <- graph$fixtures[graph$fixtures$fixture_id == fixture_id, , drop = FALSE]
    after <- sampled$matches[sampled$matches$fixture_id == fixture_id, , drop = FALSE]
    expect_identical(after$final_home_goals, before$final_home_goals)
    expect_identical(after$final_away_goals, before$final_away_goals)
  }
})

test_that("UCLOUT-02 emits conserved full-rank, band, and cut-line distributions", {
  required <- c("ucl_aggregate_rank_distributions")
  missing <- required[!vapply(required, exists, logical(1), mode = "function", inherits = TRUE)]
  if (length(missing)) stop(phase20_test_missing_entrypoint_condition(missing, "20-03 distribution aggregation"))
  clubs <- phase20_test_fixture_club_ids()
  rows <- do.call(rbind, lapply(seq_len(4L), function(iteration) {
    data.frame(
      run_id = "run-20-03", iteration = iteration, edition_id = phase20_test_edition_id,
      club_id = clubs, rank = seq_along(clubs), rank_interval_min = seq_along(clubs),
      rank_interval_max = seq_along(clubs), rank_status = "resolved",
      qualification_band = c(rep("direct_round_of_16", 8L), rep("knockout_play_off", 16L), rep("eliminated", 12L)),
      stringsAsFactors = FALSE, check.names = FALSE
    )
  }))
  aggregate <- ucl_aggregate_rank_distributions(list(rank_rows = rows, run_id = "run-20-03"))
  expect_identical(aggregate$status, "ready")
  expect_identical(nrow(aggregate$rank_distribution), 36L * 36L)
  rank_sums <- tapply(aggregate$rank_distribution$probability, aggregate$rank_distribution$club_id, sum)
  expect_true(all(abs(as.numeric(rank_sums) - 1) < 1e-12))
  band_sums <- tapply(aggregate$band_probabilities$probability, aggregate$band_probabilities$club_id, sum)
  expect_true(all(abs(as.numeric(band_sums) - 1) < 1e-12))
  expect_true(all(c("rank_8", "rank_24") %in% names(aggregate$cutline_distributions)))
  expect_true(all(vapply(aggregate$cutline_distributions, function(value) abs(sum(value$probability) - 1) < 1e-12, logical(1))))
  unresolved <- ucl_aggregate_rank_distributions(list(rank_rows = rbind(rows[rows$club_id != clubs[[8L]], ], data.frame(
    run_id = "run-20-03", iteration = 1L, edition_id = phase20_test_edition_id, club_id = clubs[[8L]],
    rank = NA_integer_, rank_interval_min = 7L, rank_interval_max = 9L,
    rank_status = "unresolved", qualification_band = "unresolved", stringsAsFactors = FALSE
  ))))
  expect_identical(unresolved$status, "unresolved")
  expect_true(all(is.na(unresolved$band_probabilities$probability[unresolved$band_probabilities$club_id == clubs[[8L]]])))
})

test_that("UCLOUT-03 enumerates only Article 19/Annex B legal paths", {
  rankings <- phase20_fixture_resolved_rankings()
  paths <- ucl_enumerate_legal_knockout_paths(rankings, source_bundle_id = phase20_test_source_bundle_id)
  expect_true(nrow(paths) >= 24L)
  expect_true(all(paths$path_status == "pre_draw_legal"))
  expect_true(all(paths$unresolved_reason == "missing_edition_draw_procedure"))
  expect_true(all(paths$leg_order == "seeded_return_leg"))
  playoff <- paths[paths$stage_id == "knockout_play_off", , drop = FALSE]
  expect_true(all(paste(playoff$seed_rank, playoff$opponent_rank, sep = "-") %in% c(
    "9-23", "9-24", "10-23", "10-24", "11-21", "11-22", "12-21", "12-22",
    "13-19", "13-20", "14-19", "14-20", "15-17", "15-18", "16-17", "16-18"
  )))
  expect_true(all(!is.na(playoff$bracket_position)))
  expect_true(all(vapply(seq_len(nrow(paths)), function(index) isTRUE(.ucl_validate_legal_path(paths[index, , drop = FALSE])), logical(1))))
})

test_that("UCLOUT-03 suppresses rank-boundary paths and conditions exactly on accepted draw lineage", {
  boundary <- ucl_enumerate_legal_knockout_paths(phase20_fixture_unresolved_rankings(8L), source_bundle_id = phase20_test_source_bundle_id)
  expect_true(all(boundary$path_status == "unresolved"))
  expect_true(all(boundary$unresolved_reason %in% c("unresolved_rank_interval", "unresolved_rank_boundary")))
  draw <- phase20_fixture_accepted_draw()
  accepted <- ucl_validate_draw_artifact(draw, source_bundle_id = phase20_test_source_bundle_id)
  expect_identical(accepted$status, "accepted")
  paths <- ucl_enumerate_legal_knockout_paths(phase20_fixture_resolved_rankings(), draw_artifact = draw, source_bundle_id = phase20_test_source_bundle_id)
  expect_identical(nrow(paths), nrow(draw$pairings))
  expect_true(all(paths$path_status == "accepted_draw"))
  expect_identical(as.character(paths$draw_artifact_id), rep(draw$draw_artifact_id, nrow(draw$pairings)))
  expect_identical(as.character(paths$participant_a), as.character(draw$pairings$participant_a))
  for (kind in c("stale", "partial", "foreign", "contradictory")) {
    invalid <- ucl_validate_draw_artifact(phase20_fixture_draw_variant(kind), source_bundle_id = phase20_test_source_bundle_id)
    expect_identical(invalid$status, "unresolved")
    expect_true(nzchar(invalid$reason))
  }
  suppressed <- ucl_enumerate_legal_knockout_paths(phase20_fixture_resolved_rankings(), draw_artifact = NULL, source_bundle_id = phase20_test_source_bundle_id)
  expect_true(all(suppressed$path_status == "pre_draw_legal"))
  expect_true(all(suppressed$draw_artifact_id %in% NA_character_))
})

test_that("UCLOUT-02/03 preserve replay identity and parent authority diagnostics", {
  graph <- phase20_test_completed_fixture_graph()
  state <- ucl_build_state(graph, state_cutoff_utc = phase20_test_information_cutoff_utc)
  ledger <- ucl_build_forecast_ledger(state)
  ledger$authority$original_parent_reason <- "no_accepted_club_history"
  before <- if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) get(".Random.seed", envir = .GlobalEnv) else NULL
  first <- ucl_run_simulation(state, ledger = ledger, simulations = 2L, seed = 20260921L)
  after <- if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) get(".Random.seed", envir = .GlobalEnv) else NULL
  second <- ucl_run_simulation(phase20_fixture_reverse_order(graph), ledger = ledger, simulations = 2L, seed = 20260921L)
  expect_identical(before, after)
  expect_identical(first$run_id, second$run_id)
  expect_identical(first$rank_rows, second$rank_rows)
  expect_identical(first$metadata$original_parent_reason, "no_accepted_club_history")
  expect_false(isTRUE(first$metadata$production_eligible))
})

# -------------------------------------------------------------------------
# Plan 20-04 RED contracts.  These tests intentionally exercise the closed
# knockout/outcome contracts before their implementation is expanded.
# -------------------------------------------------------------------------

test_that("20-04 RED: two-leg resolution is editioned, aggregate-only, and stage-event complete", {
  tie <- phase20_fixture_ucl_two_leg(
    regulation = c(1L, 0L), second_regulation = c(1L, 0L),
    extra_time = c(1L, 0L)
  )
  result <- ucl_resolve_two_leg_tie(tie$first, tie$second)
  expect_identical(result$status, "resolved")
  expect_identical(result$participant_a, "ucl-club-09")
  expect_identical(result$participant_b, "ucl-club-24")
  expect_identical(result$aggregate_regulation_home, 1L)
  expect_identical(result$aggregate_regulation_away, 1L)
  expect_identical(result$aggregate_final_home, 2L)
  expect_identical(result$aggregate_final_away, 1L)
  expect_true(isTRUE(result$extra_time_applied))
  expect_false(isTRUE(result$away_goals_used))
  expect_identical(result$leg_order, "seeded_return_leg")
  expect_identical(result$leg_1_venue_id, "venue-ucl-club-24")
  expect_identical(result$leg_2_venue_id, "venue-ucl-club-09")

  invalid <- tie$second
  invalid$home_club_id <- "ucl-club-01"
  invalid$away_club_id <- "ucl-club-02"
  blocked <- ucl_resolve_two_leg_tie(tie$first, invalid)
  expect_identical(blocked$status, "blocked")
  expect_identical(blocked$reason, "invalid_leg_topology")

  event <- .ucl_record_stage_event(
    result, stage_id = "knockout_play_off", stage_event_id = "playoff-01",
    seed_slot_id = "playoff-seed-09", draw_policy_id = tie$first$draw_policy_id,
    draw_artifact_id = NA_character_, draw_artifact_sha256 = NA_character_,
    source_artifact_ids = paste(c(tie$first$source_artifact_ids, tie$second$source_artifact_ids), collapse = ";"),
    source_bundle_id = phase20_test_source_bundle_id, simulation_run_id = "ucl20-run-0001"
  )
  expect_true(is.data.frame(event))
  expect_true(all(c(
    "stage_event_id", "participant_a", "participant_b", "leg_order",
    "leg_1_venue_id", "leg_2_venue_id", "aggregate_regulation_home",
    "aggregate_regulation_away", "aggregate_final_home", "aggregate_final_away",
    "extra_time_applied", "extra_time_home", "extra_time_away",
    "penalty_applied", "penalty_home", "penalty_away", "draw_policy_id",
    "draw_artifact_id", "draw_artifact_sha256", "source_artifact_ids",
    "source_bundle_id", "ruleset_sha256", "simulation_run_id"
  ) %in% names(event)))
})

test_that("20-04 RED: neutral final resolves regulation, extra time, and penalties without home advantage", {
  final <- phase20_fixture_ucl_final(regulation = c(1L, 1L), extra_time = c(1L, 0L))
  resolved <- ucl_resolve_final(final)
  expect_identical(resolved$status, "resolved")
  expect_identical(resolved$winner, "ucl-club-01")
  expect_true(isTRUE(resolved$neutral))
  expect_true(isTRUE(resolved$extra_time_applied))
  expect_false(isTRUE(resolved$home_advantage))
  expect_identical(resolved$final_home_goals, 2L)
  expect_identical(resolved$final_away_goals, 1L)
  expect_identical(resolved$venue_id, "neutral-final-venue")

  penalties <- phase20_fixture_ucl_final(
    regulation = c(0L, 0L), extra_time = c(0L, 0L),
    penalties = c(5L, 4L)
  )
  penalty_result <- ucl_resolve_final(penalties)
  expect_identical(penalty_result$winner, "ucl-club-01")
  expect_true(isTRUE(penalty_result$penalty_applied))
  expect_identical(penalty_result$penalty_home, 5L)
  expect_identical(penalty_result$penalty_away, 4L)
})

test_that("20-04 RED: stage input/output conservation and progression are exact and monotone", {
  events <- phase20_fixture_stage_events()
  counts <- ucl_aggregate_stage_events(
    events,
    stage_inputs = c(knockout_play_off = 2L, round_of_16 = 1L,
                     quarter_final = 1L, semi_final = 1L, final = 1L),
    league_bands = c(direct_round_of_16 = 8L, knockout_play_off = 16L, eliminated = 12L)
  )
  expect_true(isTRUE(attr(counts, "valid")))
  expect_true(all(counts$input_count == counts$resolved_count +
                  counts$unresolved_count + counts$suppressed_count))
  expect_identical(counts$output_count[counts$stage_id == "knockout_play_off"], 1L)

  progression <- phase20_fixture_progression_stages()
  checked <- ucl_validate_progression_reconciliation(
    progression,
    stage_inputs = c(knockout_play_off = 16L, round_of_16 = 16L,
                     quarter_final = 8L, semi_final = 4L, final = 2L, champion = 1L),
    league_bands = c(direct_round_of_16 = 8L, knockout_play_off = 16L, eliminated = 12L)
  )
  expect_true(isTRUE(checked$valid))
  non_monotone <- progression
  non_monotone$probability[[3L]] <- 0.95
  expect_false(isTRUE(ucl_validate_progression_reconciliation(non_monotone)$valid))
  broken_sum <- progression
  broken_sum$probability[[6L]] <- 1.2
  expect_false(isTRUE(ucl_validate_progression_reconciliation(broken_sum)$valid))
})

test_that("20-04 RED: knockout paths and outcome inventory persist complete lineage", {
  fixture <- phase20_test_fixture_candidate()
  manifest <- fixture$candidate$artifacts$outcomes_manifest
  expected_paths <- paste0(names(phase20_expected_output_schemas), ".csv")
  expect_identical(nrow(manifest), 10L)
  expect_setequal(as.character(manifest$artifact_path), expected_paths)
  expect_true(all(grepl("^[0-9a-f]{64}$", as.character(manifest$artifact_sha256))))
  expect_true(all(grepl("^[0-9a-f]{64}$", as.character(manifest$parent_sha256))))
  expect_true(all(grepl("^[0-9a-f]{64}$", as.character(manifest$manifest_sha256))))

  paths <- fixture$candidate$artifacts$knockout_paths
  expect_true(nrow(paths) > 0L)
  expect_true(all(c(
    "stage_event_id", "participant_a", "participant_b", "leg_order",
    "leg_1_venue_id", "leg_2_venue_id", "aggregate_regulation_home",
    "aggregate_regulation_away", "aggregate_final_home", "aggregate_final_away",
    "extra_time_applied", "extra_time_home", "extra_time_away",
    "penalty_applied", "penalty_home", "penalty_away", "draw_policy_id",
    "draw_artifact_id", "draw_artifact_sha256", "source_artifact_ids",
    "source_bundle_id", "ruleset_sha256", "simulation_run_id"
  ) %in% names(paths)))
  expect_true(all(nzchar(as.character(paths$stage_event_id))))

  tampered <- fixture$candidate
  tampered$artifacts$knockout_paths$row_sha256[[1L]] <- "tampered"
  expect_false(isTRUE(ucl_validate_outcome_candidate(tampered)$valid))

  repeated <- phase20_test_fixture_candidate()
  reversed <- phase20_test_fixture_candidate(reverse = TRUE)
  expect_identical(fixture$candidate$artifact_hashes, repeated$candidate$artifact_hashes)
  expect_identical(fixture$candidate$artifact_hashes, reversed$candidate$artifact_hashes)
  expect_identical(fixture$candidate$artifacts$outcomes_manifest,
                   repeated$candidate$artifacts$outcomes_manifest)
  expect_identical(fixture$candidate$artifacts$outcomes_manifest,
                   reversed$candidate$artifacts$outcomes_manifest)
})

# -------------------------------------------------------------------------
# Plan 20-05 RED contracts.  These tests intentionally exercise the fixed
# orchestration and aggregate verification boundaries before their production
# entrypoints are added.  The public-boundary assertions below must fail with
# red_missing_ucl_entrypoints until Task 2 implements the CLI, targets, and
# aggregate gate.
# -------------------------------------------------------------------------

test_that("20-05 RED: fixed CLI modes and production result are public contracts", {
  phase20_test_require_ucl_entrypoints(
    c("ucl20_parse_args", "ucl20_build_outcomes", "phase20_result_contract"),
    "20-05 fixed-cli-production-boundary"
  )

  parsed <- ucl20_parse_args(c(
    "--edition-id=ucl_2026_27", "--simulations=2", "--seed=20260921",
    "--dry-run"
  ))
  expect_identical(parsed$edition_id, "ucl_2026_27")
  expect_identical(parsed$simulations, 2L)
  expect_identical(parsed$seed, 20260921L)
  expect_true(isTRUE(parsed$dry_run))
  expect_error(ucl20_parse_args("--edition-id=uefa_nations_league_2026_27"), "not supported|Unsupported")
  expect_error(ucl20_parse_args("--unknown-option=value"), "Unknown|Unsupported")
  for (argument in c(
    "--fixture-root=/tmp/fixture", "--output-root=/tmp/output",
    "--selector-path=/tmp/selector", "--trusted-release-root=/tmp/release",
    "--national-root=/tmp/national", "--source-root=/tmp/source"
  )) {
    expect_error(ucl20_parse_args(argument), "does not accept|Unsupported|authority")
  }

  protected_before <- phase20_test_protected_root_snapshot()
  result <- ucl20_build_outcomes(simulations = 1L, seed = 20260921L)
  expect_true(is.list(result))
  expect_true(result$status %in% c(
    "production_human_needed", "production_blocked", "unresolved_draw_procedure"
  ))
  expect_false(isTRUE(result$production_eligible))
  expect_false(isTRUE(result$selector_changed))
  expect_false(isTRUE(result$incumbent_changed))
  expect_identical(phase20_test_protected_root_snapshot(), protected_before)
})

test_that("20-05 RED: fixture mechanics remain non-promotable at the public boundary", {
  phase20_test_require_ucl_entrypoints(
    c("ucl20_build_outcomes", "phase20_result_contract"),
    "20-05 fixture-authority-boundary"
  )
  graph <- phase20_fixture_graph_36x144()
  release <- phase20_approved_release_fixture(graph)
  protected_before <- phase20_test_protected_root_snapshot()
  result <- ucl20_build_outcomes(
    graph = graph, release = release, simulations = 1L,
    seed = 20260921L, write = FALSE
  )
  expect_true(result$status %in% c("mechanics_complete", "unresolved_draw_procedure"))
  expect_false(isTRUE(result$production_eligible))
  expect_identical(phase20_test_protected_root_snapshot(), protected_before)
})

test_that("20-05 RED: aggregate verifier entrypoint and exact target graph are explicit", {
  verifier <- file.path(phase20_test_project_root, "scripts", "verify_phase20_contracts.R")
  if (!file.exists(verifier)) {
    stop(phase20_test_missing_entrypoint_condition(
      "scripts/verify_phase20_contracts.R", "20-05 aggregate verifier"
    ))
  }
  phase20_test_require_ucl_entrypoints("phase20_verify_contracts", "20-05 aggregate result contract")

  target_source <- paste(readLines(file.path(phase20_test_project_root, "_targets.R"), warn = FALSE), collapse = "\n")
  expect_true(all(vapply(
    phase20_expected_target_names,
    function(name) grepl(paste0("tar_target\\s*\\(\\s*", name, "\\b"), target_source),
    logical(1)
  )))
  expect_false(grepl("phase14_resolve_approved_release|resolve_phase12_approved_release", target_source))
})
