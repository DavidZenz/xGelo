library(testthat)
root <- normalizePath(Sys.getenv("XGELO_PROJECT_ROOT",if(basename(getwd())=="testthat")"../.." else "."),mustWork=TRUE)
private <- Sys.getenv("XGELO_CL9_MODULE_ROOT",file.path(root,"R/competition"))
review_root <- Sys.getenv("XGELO_CL9_REVIEW_ROOT",file.path(root,"data/competition/rules/reviews/ucl-forecast-policy-v1"))
withr::local_dir(root)
for (path in c("R/common/phase18_canonical_hash.R", "R/competition/source_contracts.R",
    "R/competition/uefa_champions_league_rules.R", "R/competition/uefa_champions_league_state.R",
    "R/competition/uefa_champions_league_simulation.R", "R/competition/ucl_joint_score_view.R",
    "R/competition/uefa_champions_league_outcomes.R", "R/competition/ucl_live_outcomes.R")) source(file.path(root, path))
source(file.path(private, "ucl_future_matchups.R"))
source(file.path(private, "uefa_champions_league_simulation.R"))
source(file.path(private, "ucl_joint_score_view.R"))
source(file.path(private,"uefa_champions_league_outcomes.R"))
source(file.path(private,"ucl_live_outcomes.R"))
fixture_context <- function(ratings = c(a = 1600, b = 1450), temperature = 1.2) ucl_future_fixture_context(
  c("(Intercept)" = log(1.1), elo_difference_for_team = .0015, venue_rolehome = log(1.25)), 3, ratings,
  home_advantage = 60, temperature = temperature, primary_probability_view = "calibrated_1x2")
fixture_slot <- function(stage = "final", leg = 1L, date = "2027-06-05T00:00:00Z") ucl_future_fixture_slot(
  paste(stage, leg, sep = "-"), stage, leg, date, neutral = stage == "final")
fixture_slots <- function() list(fixture_slot("round_of_16", 1L, "2027-03-09T00:00:00Z"), fixture_slot("round_of_16", 2L, "2027-03-16T00:00:00Z"))

test_that("neutral counterfactual swaps clubs exactly and removes both home interventions", {
  context <- fixture_context()
  slot <- fixture_slot()
  ab <- ucl_future_forecast_matchup(context, "a", "b", slot)
  ba <- ucl_future_forecast_matchup(context, "b", "a", slot)
  expect_equal(unname(ab$primary_1x2), unname(rev(ba$primary_1x2)), tolerance = 1e-12)
  expect_equal(unname(ab$theoretical_raw_means), unname(rev(ba$theoretical_raw_means)), tolerance = 1e-12)
  transpose <- ba$raw_grid[order(ba$raw_grid$away_goals, ba$raw_grid$home_goals), ]
  ab_order <- ab$raw_grid[order(ab$raw_grid$home_goals, ab$raw_grid$away_goals), ]
  expect_equal(ab_order$probability, transpose$probability, tolerance = 1e-12)
  equal <- fixture_context(c(a = 1500, b = 1500))
  neutral <- ucl_future_forecast_matchup(equal, "a", "b", slot)
  expect_equal(unname(neutral$primary_1x2[[1L]]), unname(neutral$primary_1x2[[3L]]), tolerance = 1e-12)
  expect_equal(unname(neutral$theoretical_raw_means), rep(1.1*sqrt(1.25), 2L), tolerance = 1e-12)
  home <- ucl_future_forecast_matchup(equal, "a", "b", fixture_slots()[[1L]])
  expect_gt(home$primary_1x2[[1L]], home$primary_1x2[[3L]])
  expect_true(ab$metadata$fixture_authority)
  expect_match(ab$metadata$forecast_sha256, "^[0-9a-f]{64}$")
})

test_that("dynamic identities and evidence boundaries fail closed", {
  context <- fixture_context(); slot <- fixture_slot()
  expect_error(ucl_future_forecast_matchup(context, "a", "a", slot), "identity_invalid")
  expect_error(ucl_future_forecast_matchup(context, "a", "national_team", slot), "identity_invalid")
  same_time <- fixture_slot(date = context$information_cutoff_utc)
  expect_error(ucl_future_forecast_matchup(context, "a", "b", same_time), "cutoff_violation")
  later_evidence <- ucl_future_fixture_slot("future", "final", 1L, "2027-06-05T00:00:00Z", TRUE,
    evidence_available_at_utc = "2026-11-06T00:00:00Z")
  expect_error(ucl_future_forecast_matchup(context, "a", "b", later_evidence), "cutoff_violation")
  changed <- slot; changed$kickoff_lower_bound_utc <- "2027-06-06T00:00:00Z"
  expect_error(ucl_future_forecast_matchup(context, "a", "b", changed), "slot_evidence_changed")
  changed <- context; changed$theta <- 2
  expect_error(ucl_future_forecast_matchup(changed, "a", "b", slot), "context_integrity_invalid")
})

test_that("ET uses the reviewed NB exposure process without claiming 90-minute calibration", {
  context <- fixture_context(); slot <- fixture_slots()[[2L]]
  full <- ucl_future_forecast_matchup(context, "a", "b", slot)
  extra <- ucl_future_forecast_matchup(context, "a", "b", slot, minutes = 30L)
  expect_equal(extra$theoretical_raw_means * 3, full$theoretical_raw_means, tolerance = 1e-14)
  expect_equal(extra$theoretical_raw_theta * 3, full$theoretical_raw_theta, tolerance = 1e-14)
  expect_identical(extra$metadata$primary_probability_view, "raw_1x2")
  expect_equal(unname(extra$primary_1x2), extra$raw_1x2, tolerance = 1e-12)
  # Independent NB-process identity: three 30-minute zero-goal probabilities
  # multiply to the 90-minute zero-goal probability for each participant.
  for (side in 1:2) expect_equal(stats::dnbinom(0, mu = extra$theoretical_raw_means[[side]], size = extra$theoretical_raw_theta)^3,
    stats::dnbinom(0, mu = full$theoretical_raw_means[[side]], size = full$theoretical_raw_theta), tolerance = 1e-14)
  expect_equal(sum(extra$score_grid$probability), 1, tolerance = 1e-12)
})

test_that("aggregate ties ignore away goals and ET belongs to the second-leg host", {
  context <- fixture_context(); slots <- fixture_slots(); rules <- .ucl_rule_contract()
  seen <- list(); sequence <- list(c(2L, 1L), c(1L, 0L), c(0L, 1L)); i <- 0L
  sampler <- function(f) { i <<- i+1L; seen[[i]] <<- f$metadata; sequence[[i]] }
  tie <- ucl_future_simulate_tie(context, "a", "b", slots, rules, 11L, "round_of_16", "test-r16",
    1L, 8L, score_sampler = sampler)
  expect_identical(tie$resolution$winner, "b")
  expect_true(tie$resolution$extra_time_applied)
  expect_false(tie$resolution$away_goals_used)
  expect_identical(seen[[3L]]$minutes, 30L)
  expect_identical(seen[[3L]]$home_club_id, "a")
  expect_identical(seen[[3L]]$slot_sha256, slots[[2L]]$slot_sha256)
  expect_equal(tie$resolution$aggregate_regulation_home, 2L)
  expect_equal(tie$resolution$aggregate_regulation_away, 2L)
})

test_that("penalties resolve ties without fabricating shootout tallies and preserve RNG", {
  context <- fixture_context(); rules <- .ucl_rule_contract()
  zero <- function(f) c(0L, 0L)
  set.seed(777); before <- .Random.seed
  final <- ucl_future_simulate_tie(context, "a", "b", list(fixture_slot()), rules, 42L, "final", "final-test",
    score_sampler = zero, penalty_sampler = function(home, away) away)
  expect_identical(final$resolution$winner, "b")
  expect_true(final$resolution$extra_time_applied)
  expect_true(final$resolution$penalty_applied)
  expect_true(is.na(final$resolution$penalty_home))
  expect_true(is.na(final$resolution$penalty_away))
  expect_identical(.Random.seed, before)
  expect_true(final$resolution$neutral)
  expect_false(final$resolution$home_advantage)
})

test_that("official AnnexB families keep ranks1/2 on opposite final sides", {
  rankings <- data.frame(club_id = sprintf("c%02d", 1:36), rank = 1:36)
  for (orientation in list(rep(0L, 12L), rep(1L, 12L), rep(c(0L,1L), 6L))) {
    bracket <- ucl_future_fixture_bracket(rankings, orientation)
    expect_silent(ucl_future_validate_bracket(bracket))
    nodes <- bracket$nodes
    rank1 <- nodes$side[nodes$ref_a == "rank:1"]
    rank2 <- nodes$side[nodes$ref_a == "rank:2"]
    expect_setequal(c(rank1, rank2), c("silver", "blue"))
    expect_false(identical(rank1, rank2))
    # Independent published family: top5/6 meets winner11/12 v21/22.
    top5 <- nodes[nodes$ref_a == "rank:5", ]
    parent <- nodes[nodes$node_id == sub("^winner:", "", top5$ref_b), ]
    expect_true(as.integer(sub("rank:", "", parent$ref_a)) %in% 11:12)
    expect_true(as.integer(sub("rank:", "", parent$ref_b)) %in% 21:22)
  }
  original <- ucl_future_fixture_bracket(rankings)
  reversed <- ucl_future_fixture_bracket(rankings[36:1, ])
  expect_identical(original$bracket_sha256, reversed$bracket_sha256)
  changed <- original; changed$nodes$ref_b[[17L]] <- "winner:r16-blue-4"
  expect_error(ucl_future_validate_bracket(changed), "bracket_content_changed")
})

test_that("dynamic knockout sampling conserves stages and reports Monte Carlo uncertainty", {
  clubs <- sprintf("c%02d", 1:36)
  context <- fixture_context(stats::setNames(seq(1650, 1350, length.out = 36), clubs), temperature = 1.1)
  calendar <- list(
    knockout_play_off_1 = fixture_slot("knockout_play_off",1L,"2027-02-16T00:00:00Z"),
    knockout_play_off_2 = fixture_slot("knockout_play_off",2L,"2027-02-23T00:00:00Z"),
    round_of_16_1 = fixture_slot("round_of_16",1L,"2027-03-09T00:00:00Z"),
    round_of_16_2 = fixture_slot("round_of_16",2L,"2027-03-16T00:00:00Z"),
    quarter_final_1 = fixture_slot("quarter_final",1L,"2027-04-06T00:00:00Z"),
    quarter_final_2 = fixture_slot("quarter_final",2L,"2027-04-13T00:00:00Z"),
    semi_final_1 = fixture_slot("semi_final",1L,"2027-04-27T00:00:00Z"),
    semi_final_2 = fixture_slot("semi_final",2L,"2027-05-04T00:00:00Z"),
    final_1 = fixture_slot())
  ranks <- data.frame(iteration = 1L, club_id = clubs, rank = 1:36)
  result <- ucl_future_progression(ranks, context, calendar, .ucl_rule_contract(), 2027L)
  expect_identical(result$status, "ready")
  expect_equal(nrow(result$events), 23L)
  expect_equal(sum(result$progression$probability[result$progression$stage_id == "champion"]), 1)
  totals <- tapply(result$progression$probability, result$progression$stage_id, sum)
  expect_equal(as.numeric(totals[c("direct_round_of_16","knockout_play_off","eliminated","round_of_16","quarter_final","semi_final","final","champion")]), c(8,16,12,16,8,4,2,1))
  expect_true(all(result$events$inherited_winner_seed == pmin(result$events$inherited_seed_a, result$events$inherited_seed_b)))
  nonfinal <- result$events$stage_id != "final"
  expect_true(all(result$events$inherited_seed_a[nonfinal] < result$events$inherited_seed_b[nonfinal]))
  expect_true(all(is.finite(result$uncertainty$mc95_lower)))
  expect_true(all(result$uncertainty$mc95_lower <= result$uncertainty$probability))
  expect_true(all(result$uncertainty$mc95_upper >= result$uncertainty$probability))
  replay <- ucl_future_progression(ranks[36:1, ], context, calendar, .ucl_rule_contract(), 2027L)
  expect_identical(result$progression_sha256, replay$progression_sha256)
  expect_identical(result$event_log_sha256, replay$event_log_sha256)
  expect_true(result$fixture_authority)
  expect_false(result$model_uncertainty_included)
  prototype <- data.frame(club_id = rep(clubs, each = 8L), stage_id = rep(c("direct_round_of_16","knockout_play_off","eliminated","round_of_16","quarter_final","semi_final","final","champion"),36L),
    probability = NA_real_, status = "unresolved", unresolved_reason = "fixture", draw_artifact_sha256 = NA_character_, run_id = "base-fixture")
  simulation <- list(rank_rows = ranks, simulations = ranks, run_id = "base-fixture", progression_probabilities = prototype,
    graph = list(source_bundle_id = "fixture-source"), metadata = list(seed = 2027L, component_hashes = list()))
  attached <- ucl_future_attach_to_simulation(simulation, context, .ucl_rule_contract(), calendar)
  expect_identical(attached$status, "ready")
  expect_equal(nrow(attached$stage_events), 24L)
  expect_true(all(attached$progression_probabilities$status == "resolved"))
  expect_identical(attached$metadata$draw_scope, "unconditioned_regulations_prior")
  expect_match(attached$metadata$forecast_scope_disclosure, "not an official draw")
  expect_false(ucl_future_verify_projection(attached$future_projection, list()))
  expect_true(isTRUE(.ucl_out_validate_stage_events(attached$stage_events, .ucl_rule_contract())$valid))
})

test_that("future mean arithmetic matches real retained and Elo candidate NB objects", {
  source(file.path(root, "scripts/diagnose_club_calibration.R"), local = TRUE)
  source(file.path(root, "R/club/goal_model.R"), local = TRUE)
  saved <- club_diag_read_release(root)
  actual <- list(saved$bundle$refit$model, saved$bundle$evidence$fold_results[[1L]]$candidate$fit)
  for (fit in actual) {
    coefficients <- stats::coef(fit$model)
    if (!"elo_difference_for_team" %in% names(coefficients)) coefficients <- c(coefficients, elo_difference_for_team = 0)
    context <- ucl_future_fixture_context(coefficients, fit$theta, c(a = 1600, b = 1450), home_advantage = 60)
    proposed <- .ucl_future_means(context, "a", "b", fixture_slots()[[1L]])$means
    approved_math <- phase19_club_goal_nb_means(fit, data.frame(rating_difference = 210))
    expect_equal(unname(proposed), c(approved_math$home, approved_math$away), tolerance = 1e-12)
    expect_true(context$fixture_authority)
  }
})

test_that("fixed official coefficient rows validate season sums, floors and all36 identities", {
  table <- utils::read.csv(file.path(review_root,"club_coefficients_2026.csv"),stringsAsFactors=FALSE)
  known <- ucl_future_validate_coefficient_inputs(table,table$club_id)
  expect_length(known$values,36L)
  expect_equal(unname(known$values[c("club_fd_7397","club_fd_546","club_fd_5720")]),c(19.989,16.699,8.247))
  expect_equal(length(unique(known$values)),36L)
  changed <- table; changed$effective_coefficient[changed$club_id=="club_fd_7397"] <- 0
  expect_error(ucl_future_validate_coefficient_inputs(changed,table$club_id),"floor_or_sum_mismatch")
  changed <- table; changed$reference_last_season_year <- 2027L
  expect_error(ucl_future_validate_coefficient_inputs(changed,table$club_id),"reference_or_type_invalid")
  expect_error(ucl_future_validate_coefficient_inputs(table[-1,],table$club_id),"coverage_incomplete")
})

test_that("unknown final discipline is a disclosed weak-order prior and known coefficients stay factual", {
  clubs <- sprintf("c%02d",1:36)
  ranks <- data.frame(iteration=1L,club_id=clubs,rank=1:36,rank_interval_min=1:36,rank_interval_max=1:36,
    rank_status="resolved",qualification_band="fixture",missing_criterion_id=NA_character_)
  ranks$rank[8:9] <- NA_integer_; ranks$rank_interval_min[8:9] <- 8L; ranks$rank_interval_max[8:9] <- 9L
  ranks$missing_criterion_id[8:9] <- "disciplinary_points"
  context <- ucl_future_fixture_context(c("(Intercept)"=0,elo_difference_for_team=.001,venue_rolehome=.1),3,
    stats::setNames(rep(1500,36),clubs),future_tie_policy="exchangeable_final_disciplinary_weak_order_v1",
    club_coefficients=stats::setNames(36:1,clubs))
  expect_equal(.ucl_future_weak_order_counts(4),c(1,1,3,13,75))
  expect_error(ucl_future_resolve_rank_intervals(ranks,context,FALSE,17L),"factual_late_tiebreak_inputs_required")
  strict <- context; strict$future_tie_policy <- "retain_unresolved_intervals"
  expect_error(ucl_future_resolve_rank_intervals(ranks,strict,TRUE,17L),"unresolved_forecast_late_tiebreak")
  absent <- context; absent$club_coefficients <- NULL
  expect_error(ucl_future_resolve_rank_intervals(ranks,absent,TRUE,17L),"known_coefficient_coverage")
  early <- ranks; early$missing_criterion_id[8:9] <- "opponent_points"
  expect_error(ucl_future_resolve_rank_intervals(early,context,TRUE,17L),"not_proven_disciplinary_only")
  set.seed(33); before <- .Random.seed
  a <- ucl_future_resolve_rank_intervals(ranks,context,TRUE,17L)
  b <- ucl_future_resolve_rank_intervals(ranks[36:1,],context,TRUE,17L)
  expect_identical(a$prior_samples,b$prior_samples)
  expect_identical(.Random.seed,before)
  expect_setequal(a$rows$rank,1:36)
  expect_true(all(!a$prior_samples$factual_rank_claimed))
  expect_equal(a$prior_samples$known_club_coefficient,c(29,28))
  # Explicit equal-discipline scenario must prefer the higher known coefficient.
  found <- FALSE
  for(seed in 1:30) {
    x <- ucl_future_resolve_rank_intervals(ranks,context,TRUE,seed)$prior_samples
    if(all(x$coefficient_tiebreak_used)) { expect_equal(x$scenario_rank,c(8L,9L));found<-TRUE;break }
  }
  expect_true(found)
  contribution <- ucl_future_prior_contribution(a$prior_samples,clubs,10L)
  expect_true(all(contribution$all_stage_max_absolute_probability_change_bound==.1))
  expect_equal(sum(contribution$prior_affected_club_iteration_count),2L)
  expect_false(any(contribution$model_uncertainty_included))
  projection <- list(progression_sha256=strrep("a",64),event_log_sha256=strrep("b",64),uncertainty=data.frame(),
    late_tie_prior_samples=a$prior_samples,late_tie_prior_contribution=contribution)
  hash <- .ucl_future_projection_binding(projection,context)
  projection$late_tie_prior_samples$scenario_rank[[1L]] <- 9L
  expect_false(identical(hash,.ucl_future_projection_binding(projection,context)))
})

test_that("packed score lineage is independent of row order and binds probability bytes", {
  grid <- expand.grid(home_goals=0:1,away_goals=0:1);grid$probability<-c(.1,.2,.3,.4)
  hash <- .ucl_joint_grid_hash(grid,"independent-fixture-v1")
  expect_identical(hash,.ucl_joint_grid_hash(grid[c(3,1,4,2),],"independent-fixture-v1"))
  changed <- grid;changed$probability[1:2]<-changed$probability[1:2]+c(1e-12,-1e-12)
  expect_false(identical(hash,.ucl_joint_grid_hash(changed,"independent-fixture-v1")))
  expect_false(identical(hash,.ucl_joint_grid_hash(grid,"other-domain-v1")))
})

test_that("projected Article18 score criteria include future scores without advancing factual cutoff", {
  clubs<-sprintf("c%02d",1:36);row<-0:143
  graph<-list(clubs=data.frame(club_id=clubs),source_bundle_id="fixture-only",
    fixtures=data.frame(home_club_id=clubs[row%%36L+1L],away_club_id=clubs[(row%%36L+row%/%36L+1L)%%36L+1L],
      match_status="completed",regulation_home_goals=0L,regulation_away_goals=0L))
  fields<-c("played","wins","draws","losses","goals_for","goals_against","goal_difference","points")
  actual_source<-graph
  actual_source$fixtures$match_status[73:144]<-"scheduled"
  actual_source$fixtures$regulation_home_goals[73:144]<-NA_integer_;actual_source$fixtures$regulation_away_goals[73:144]<-NA_integer_
  actual_hash<-digest::digest(actual_source);actual_72<-actual_source$fixtures[1:72,]
  current<-data.frame(team_id=clubs);for(field in fields)current[[field]]<-0L
  current$played<-4L;current$draws<-4L;current$points<-4L
  current_hash<-digest::digest(current)
  context<-fixture_context(stats::setNames(rep(1500,36),clubs))
  projected<-ucl_future_complete_score_ranking(list(universal_standings=current),graph,.ucl_rule_contract(),context)
  metrics<-attr(projected,"score_metrics")
  expect_true(all(metrics$played==8L));expect_true(all(metrics$points==8L))
  expect_true(all(metrics$opponent_points==64L))
  expect_true(all(metrics$opponent_goal_difference==0L & metrics$opponent_goals_scored==0L))
  expect_true(all(is.na(projected$rank)))
  trace<-attr(projected,"trace");expect_true(all(trace$criterion_id[trace$evidence_status=="missing"]=="disciplinary_points"))
  # One known counterfactual1-0 changes points by+2/-1 relative to a draw.
  graph$fixtures$regulation_home_goals[[73L]]<-1L
  projected<-ucl_future_complete_score_ranking(list(universal_standings=current),graph,.ucl_rule_contract(),context)
  metrics<-attr(projected,"score_metrics");expect_equal(metrics$points[c(1,4)],c(10L,7L))
  expected<-vapply(clubs,function(club) {
    opponents<-c(graph$fixtures$away_club_id[graph$fixtures$home_club_id==club],graph$fixtures$home_club_id[graph$fixtures$away_club_id==club])
    64+2*("c01"%in%opponents)-("c04"%in%opponents)
  },numeric(1))
  expect_equal(metrics$opponent_points,unname(expected))
  expect_identical(projected$club_id[projected$rank%in%1L],"c01")
  flipped<-graph;flipped$fixtures$regulation_home_goals[[73L]]<-0L;flipped$fixtures$regulation_away_goals[[73L]]<-1L
  other<-ucl_future_complete_score_ranking(list(universal_standings=current),flipped,.ucl_rule_contract(),context)
  expect_identical(other$club_id[other$rank%in%1L],"c04")
  expect_identical(graph$fixtures[1:72,],actual_72)
  expect_identical(flipped$fixtures[1:72,],actual_72)
  expect_identical(digest::digest(actual_source),actual_hash)
  expect_identical(digest::digest(current),current_hash)
  expect_true(all(!projected$observed_source_eligible & !projected$training_eligible))
  expect_true(all(projected$ranking_scope=="counterfactual_complete_league"))
  bad<-current;bad$played<-8L
  expect_error(ucl_future_complete_score_ranking(list(universal_standings=bad),graph,.ucl_rule_contract(),context),"disagree_with_standings")
})
