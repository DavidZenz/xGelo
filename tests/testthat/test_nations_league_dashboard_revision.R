library(testthat)

nl_revision_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
nl_revision_api <- function() {
  api <- new.env(parent = globalenv())
  for (file in c("R/competition/source_contracts.R", "R/competition/publication_hashes.R", "R/competition/standings.R", "R/competition/uefa_nations_league_rules.R", "R/competition/uefa_nations_league_simulation.R", "R/competition/uefa_nations_league_outcomes.R", "R/dashboard/payload_contract.R", "R/dashboard/payload_nations_league.R", "R/dashboard/renderer.R")) sys.source(file.path(nl_revision_root, file), api)
  api
}
nl_revision_interim <- function() {
  rank <- 1:54
  league <- ifelse(rank <= 16, "A", ifelse(rank <= 32, "B", ifelse(rank <= 48, "C", "D")))
  data.frame(team_id = paste0("team_", rank), league = league,
    group_id = paste0(league, ifelse(rank <= 48, (rank - 1) %% 4 + 1, (rank - 49) %% 2 + 1)),
    group_position = ifelse(rank <= 48, ((rank - 1) %% 16) %/% 4 + 1, (rank - 49) %/% 2 + 1),
    interim_rank = rank, computed_rank = rank, ordering_status = "ready", stringsAsFactors = FALSE)
}
nl_revision_results <- function(slots, low_wins = TRUE) {
  selected <- slots[slots$stage_id %in% c("a_b_playoff", "b_c_playoff"), , drop = FALSE]
  data.frame(stage_id = selected$stage_id,
    tie_id = paste(selected$stage_id, selected$higher_league_rank, selected$lower_league_rank, sep = "::"),
    stage_status = "completed", winner_team_id = if (low_wins) selected$lower_league_team_id else selected$higher_league_team_id,
    loser_team_id = if (low_wins) selected$higher_league_team_id else selected$lower_league_team_id, stringsAsFactors = FALSE)
}

test_that("revised UEFA selectors include all D teams and only the legal transition bands", {
  api <- nl_revision_api(); rules <- api$uefa_nl_2026_27_rules()
  expect_identical(rules$ruleset_version, "uefa-nations-league-2026-27-v3")
  expect_identical(rules$rule_evidence$effective_date, "2026-09-15")
  expect_false("c_d_playoff" %in% api$uefa_nl_stage_topology(rules)$stage_id)
  slots <- api$uefa_nl_select_transition_slots(nl_revision_interim(), rules = rules)
  expect_equal(nrow(slots), 24L)
  expect_setequal(slots$team_id[slots$transition_type == "direct_promotion"], paste0("team_", c(17:20,33:36,49:54)))
  expect_setequal(slots$team_id[slots$transition_type == "direct_relegation"], paste0("team_",15:16))
  expect_identical(slots$higher_league_rank[slots$stage_id == "a_b_playoff"], 11:14)
  expect_identical(slots$higher_league_rank[slots$stage_id == "b_c_playoff"], 29:32)
  expect_false(any(slots$stage_id == "c_d_playoff"))
})

test_that("seeded play-off draws are replayable permutations and accepted draws take precedence", {
  api <- nl_revision_api(); rules <- api$uefa_nl_2026_27_rules()
  slots <- api$uefa_nl_select_transition_slots(nl_revision_interim(), rules = rules)
  draw <- function(seed) api$uefa_nl_sim_draw_playoffs(slots, data.frame(), seed, rules)
  expect_identical(draw(25), draw(25))
  draws <- lapply(1:20, draw)
  expect_gt(length(unique(vapply(draws, function(rows) paste(rows$lower_league_team_id[rows$stage_id == "a_b_playoff"], collapse = ":"), character(1)))), 1L)
  for (rows in draws) for (stage in c("a_b_playoff", "b_c_playoff")) {
    selected <- rows[rows$stage_id == stage, , drop = FALSE]
    expect_setequal(selected$lower_league_team_id, slots$lower_league_team_id[slots$stage_id == stage])
    expect_equal(anyDuplicated(selected$lower_league_team_id), 0L)
    expect_identical(selected$first_leg_home_team_id, selected$lower_league_team_id)
  }
  selected <- draw(25)
  pairs <- lapply(c("a_b_playoff", "b_c_playoff"), function(stage) {
    rows <- selected[selected$stage_id == stage, , drop = FALSE]
    frame <- do.call(rbind, lapply(seq_len(nrow(rows)), function(i) {
      pair <- api$uefa_nl_sim_transition_pair(rows[i,,drop=FALSE], rules = rules)
      api$uefa_nl_sim_stage_slots(stage, stage, pair, rules, "official-test", "official_stage_capture")
    }))
    frame$source_fixture_id <- paste(stage,seq_len(nrow(frame)),sep="-")
    frame$stage_status <- "official"
    frame
  })
  official <- do.call(rbind, pairs)
  accepted <- api$uefa_nl_sim_draw_playoffs(slots, official, 999, rules)
  expect_identical(accepted$lower_league_team_id, selected$lower_league_team_id)
  expect_identical(accepted$first_leg_home_team_id, selected$first_leg_home_team_id)
  official$home_team_id[1] <- "team_outsider"
  expect_error(api$uefa_nl_sim_draw_playoffs(slots, official, 999, rules), "contradicts")
})

test_that("final Article 19 ranking allocates 18 A, 18 B and all remaining teams to C", {
  api <- nl_revision_api(); rules <- api$uefa_nl_2026_27_rules(); interim <- nl_revision_interim()
  slots <- api$uefa_nl_select_transition_slots(interim, rules = rules)
  qf <- data.frame(stage_id = "league_a_quarter_final", tie_id = paste0("qf-",1:4), stage_status = "completed", winner_team_id = paste0("team_",1:4), loser_team_id = paste0("team_",5:8))
  final <- api$uefa_nl_rank_final_overall(interim, rbind(qf, nl_revision_results(slots)), rules, slots)
  expect_true(all(final$ordering_status == "ready"))
  expect_identical(sort(final$final_overall_rank), 1:54)
  expect_setequal(final$team_id[final$final_overall_rank <= 18], paste0("team_", c(1:10,17:24)))
  expect_setequal(final$team_id[final$final_overall_rank %in% 19:36], paste0("team_",c(11:16,25:28,33:40)))
  expect_equal(sum(final$final_overall_rank >= 37),18L)
})

test_that("total moves use direction-specific play-off outcomes and preserve missing resolution", {
  api <- nl_revision_api(); interim <- nl_revision_interim(); slots <- api$uefa_nl_select_transition_slots(interim)
  paths <- function(interim, slots, results) {
    events <- api$uefa_nl_sim_transition_events(slots, results, 1)
    empty <- data.frame()
    api$uefa_nl_sim_iteration_paths(interim, interim, events, empty, empty, empty, empty, empty, empty, 1)
  }
  low <- paths(interim, slots, nl_revision_results(slots))
  expect_true(all(low$p_promotion[low$team_id %in% paste0("team_",c(17:24,33:40,49:54))] == 1))
  expect_true(all(low$p_relegation[low$team_id %in% paste0("team_",c(11:16,29:32))] == 1))
  expect_true(all(low$p_promotion[low$league == "A"] == 0))
  high <- paths(interim, slots, nl_revision_results(slots,FALSE))
  expect_true(all(high$p_promotion[high$team_id %in% paste0("team_",c(21:24,37:40))] == 0))
  expect_true(all(high$p_relegation[high$team_id %in% paste0("team_",c(11:14,29:32))] == 0))
  unresolved <- paths(interim, slots, data.frame())
  expect_true(all(is.na(unresolved$p_promotion[unresolved$team_id %in% paste0("team_",21:24)])))
  expect_true(all(unresolved$p_playoff_eligibility[unresolved$team_id %in% paste0("team_",21:24)] == 1))
  # The same League B team can enter the promotion path in one simulation
  # and the relegation path in another; totals must be computed before averaging.
  swapped <- interim
  swapped$team_id[c(21,29)] <- swapped$team_id[c(29,21)]
  other_slots <- api$uefa_nl_select_transition_slots(swapped)
  other <- paths(swapped,other_slots,nl_revision_results(other_slots))
  expect_equal(low$p_promotion[low$team_id == "team_21"],1)
  expect_equal(other$p_relegation[other$team_id == "team_21"],1)
  meta <- list(edition_id=api$uefa_nl_edition_id(),projection_run_id="test",simulation_seed=25L,rules=api$uefa_nl_2026_27_rules(),source_bundle_id="test",source_bundle_sha256=paste(rep("a",64),collapse=""),model_release_id="test")
  aggregate <- api$uefa_nl_sim_aggregate_paths(list(list(paths=low),list(paths=other)),interim,2L,meta)
  expect_equal(aggregate$p_promotion[aggregate$team_id=="team_21"],.5)
  expect_equal(aggregate$p_relegation[aggregate$team_id=="team_21"],.5)
  expect_equal(aggregate$p_playoff_eligibility[aggregate$team_id=="team_21"],1)
})

test_that("approved forecast contexts cover both legs of every A/B and B/C pair", {
  api <- nl_revision_api()
  api$interactive <- function() TRUE
  api$commandArgs <- function(trailingOnly=FALSE) if (trailingOnly) character() else paste0("--file=",file.path(nl_revision_root,"scripts/build_nations_league_outcomes.R"))
  sys.source(file.path(nl_revision_root,"scripts/build_nations_league_outcomes.R"),api)
  contexts <- api$phase15_nl_knockout_stage_contexts(nl_revision_interim())
  for (stage in c("a_b_playoff","b_c_playoff")) {
    selected <- contexts[contexts$stage_id==stage,,drop=FALSE]
    expect_equal(nrow(selected),512L)
    expect_equal(anyDuplicated(paste(selected$home_team_id,selected$away_team_id)),0L)
    expect_equal(sum(selected$leg_number==1L),256L)
    expect_true(all(selected$participant_slot_home=="*" & selected$participant_slot_away=="*"))
  }
})

test_that("dashboard displays stacked tables, deduplicated fixtures and the Finals chart", {
  api <- nl_revision_api(); bundle <- api$phase17_fixture_bundle("uefa_nations_league_2026_27",lifecycle_state="active")
  bundle$artifacts$structure <- data.frame(league="A",display_name="Group A1",group_id="A1")
  bundle$artifacts$fixtures <- data.frame(fixture_id="one",group_id="A1",home_team_id="team_alpha",away_team_id="team_beta",home_display_name="Alpha",away_display_name="Beta",scheduled_at_utc="2026-10-03T18:00:00Z",status="scheduled")
  bundle$artifacts$results <- transform(bundle$artifacts$fixtures,match_status="completed",final_home_goals=2,final_away_goals=1,counts_for_standings=TRUE)
  bundle$artifacts$projected_outcomes <- data.frame(group_id="A1",league="A",team_id=rep(c("team_alpha","team_beta"),each=2),rank=rep(1:2,2),probability=c(.8,.2,.2,.8),expected_points=c(10,10,7,7),expected_goal_difference=c(2,2,0,0),ranking_status="projected")
  bundle$artifacts$progression_probabilities <- data.frame(team_id=c("team_alpha","team_beta"),league="A",p_quarter_final=c(1,1),p_semi_final=c(.8,.3),p_final=c(.4,.2),p_champion=c(.25,.0005),p_promotion=0,p_relegation=c(.01,.2),p_playoff_eligibility=c(.1,.5),status="projected")
  bundle$artifacts$fixtures$matchday <- 3L
  payload <- api$phase17_payload_nations_league(bundle); html <- api$render_phase17_dashboard(payload)
  expect_true(grepl("Matchday 3",html,fixed=TRUE))
  for (label in c("Projected standings","Current standings","Fixtures","Quarter-finals","Promotion","Play-off","Relegation","Who wins the Nations League?","Reach the Finals","<details")) expect_true(grepl(label,html,fixed=TRUE),info=label)
  expect_false(grepl("data-group-view=",html,fixed=TRUE))
  expect_equal(lengths(regmatches(html,gregexpr('class="nl-group-fixture"',html,fixed=TRUE))),1L)
  expect_true(grepl('class="nl-title-bar finals" style="width:80.0%"',html,fixed=TRUE))
  expect_true(grepl('class="nl-title-bar title" style="width:25.0%"',html,fixed=TRUE))
  expect_true(grepl("&lt;0.1%",html,fixed=TRUE))
  expect_true(grepl('activeView.querySelectorAll(".nl-match-card")',html,fixed=TRUE))
  expect_true(grepl('.nl-tab:not(.is-active):hover',html,fixed=TRUE))
  expect_identical(api$phase17_nl_percentage(0),"0.0%")
  expect_identical(api$phase17_nl_percentage(NA_real_),"—")
  expect_identical(api$phase17_nl_percentage(1.01),"—")
  expect_identical(api$phase17_nl_percentage(.0005),"<0.1%")
  expect_identical(api$phase17_nl_percentage(.001 - .Machine$double.eps * .001),"0.1%")
  bundle$artifacts$progression_probabilities$p_promotion <- NULL
  old <- api$phase17_nl_group_table(api$phase17_payload_nations_league(bundle),list(name="Group A1",league="League A"),api$phase17_public_context(payload))
  expect_true(grepl('heat-cell promotion empty',old,fixed=TRUE))
})

test_that("dashboard matchdays come from hash-verified accepted UEFA evidence", {
  api <- nl_revision_api()
  sys.source(file.path(nl_revision_root, "R/dashboard/production_provider.R"), api)
  root <- tempfile("nl-matchdays-"); dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  path <- file.path(root, "fixtures.json")
  jsonlite::write_json(list(list(id="1",matchday=list(sequenceNumber="3")),
                           list(id="2",matchday=list(sequenceNumber="4"))), path)
  source <- list(tables=list(fixtures=data.frame(uefa_source_fixture_id=c("2","1"))),
    manifest=data.frame(artifact_type="fixtures",relative_local_raw_path="fixtures.json",raw_sha256=digest::digest(file=path,algo="sha256")))
  expect_identical(api$phase17_provider_nl_fixtures(root,source)$matchday,c(4L,3L))
  writeLines("[]",path)
  expect_error(api$phase17_provider_nl_fixtures(root,source),"accepted hash")
})


test_that("pinned transition evidence agrees with the active rules", {
  api <- nl_revision_api(); rules <- api$uefa_nl_2026_27_rules()
  evidence <- jsonlite::fromJSON(file.path(nl_revision_root,"data/competition/rules/nl_2026_27_transition_evidence_v3.json"))
  expect_identical(evidence$ruleset_version, rules$ruleset_version)
  expect_identical(evidence$effective_date, rules$rule_evidence$effective_date)
  expect_identical(evidence$sources$article_16, rules$rule_evidence$article_16)
  expect_identical(evidence$sources$article_19, rules$rule_evidence$article_19)
})


test_that("indexed score lookup preserves raw-grid sampling and hashes", {
  api <- nl_revision_api()
  grid <- expand.grid(home_goals=0:2, away_goals=0:2)
  grid$probability <- rep(1/9,9)
  grid$score_distribution_id <- "pair__score"
  normalized <- api$uefa_nl_sim_normalize_score_distributions(grid)
  expect_true(!is.null(attr(normalized,"uefa_nl_grid_rows")))
  forecast <- data.frame(fixture_id="pair",score_distribution_id="pair__score")
  indexed <- api$uefa_nl_sim_fixture_grid(normalized,forecast)
  attr(normalized,"uefa_nl_grid_rows") <- NULL
  raw <- api$uefa_nl_sim_fixture_grid(normalized,forecast)
  attr(indexed,"uefa_nl_grid_rows") <- NULL
  expect_identical(indexed,raw)
  expect_identical(api$uefa_nl_sim_hash_data(grid),api$uefa_nl_sim_hash_data(api$uefa_nl_sim_normalize_score_distributions(grid)))
})


test_that("title outlook orders ties alphabetically and unavailable teams last", {
  api <- nl_revision_api()
  bundle <- api$phase17_fixture_bundle("uefa_nations_league_2026_27",lifecycle_state="active")
  bundle$artifacts$structure <- data.frame(league="A",display_name="Group A1",group_id="A1")
  bundle$artifacts$fixtures <- data.frame(fixture_id=c("one","two"),group_id="A1",home_team_id=c("team_zeta","team_alpha"),away_team_id=c("team_beta","team_missing"),home_display_name=c("Zeta","Alpha"),away_display_name=c("Beta","Missing"),scheduled_at_utc="2026-10-03T18:00:00Z",status="scheduled")
  bundle$artifacts$progression_probabilities <- data.frame(team_id=c("team_zeta","team_alpha","team_beta","team_missing"),league="A",p_semi_final=c(.8,.7,.3,NA),p_champion=c(.4,.4,.2,NA),status="projected")
  payload <- api$phase17_payload_nations_league(bundle)
  chart <- api$phase17_nl_render_title_chart(payload,api$phase17_public_context(payload))
  positions <- vapply(c("Alpha","Zeta","Beta","Missing"),function(name) regexpr(paste0('class="team-name">',name,'</span>'),chart,fixed=TRUE)[[1]],integer(1))
  expect_true(all(positions>0))
  expect_identical(order(positions),1:4)
  expect_true(grepl('Missing: title —; reach the Finals —',chart,fixed=TRUE))
})


test_that("explicit archived rules keep their own lineage version", {
  api <- nl_revision_api()
  legacy <- api$uefa_nl_2026_27_legacy_rules()
  lineage <- api$phase15_nl_rules_lineage(legacy)
  expect_identical(lineage$ruleset_version,"uefa-nations-league-2026-27-v2")
  expect_identical(lineage$ruleset_sha256,api$uefa_nl_ruleset_sha256(legacy))
})
