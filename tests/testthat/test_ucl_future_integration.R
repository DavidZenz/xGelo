library(testthat)
root <- normalizePath(Sys.getenv("XGELO_PROJECT_ROOT",if(basename(getwd())=="testthat")"../.." else "."),mustWork=TRUE)
private <- Sys.getenv("XGELO_CL9_MODULE_ROOT",file.path(root,"R/competition"))
review_root <- Sys.getenv("XGELO_CL9_REVIEW_ROOT",file.path(root,"data/competition/rules/reviews/ucl-forecast-policy-v1"))
withr::local_dir(root)
for (path in c("R/common/phase18_canonical_hash.R", "R/competition/source_contracts.R",
    "R/competition/uefa_champions_league_rules.R", "R/competition/uefa_champions_league_state.R")) source(file.path(root,path))
for (path in c("ucl_joint_score_view.R", "uefa_champions_league_simulation.R", "uefa_champions_league_outcomes.R",
    "ucl_live_outcomes.R", "ucl_future_matchups.R")) source(file.path(private,path))
source(file.path(root,"tests/testthat/helper_uefa_champions_league.R"))

test_that("real league simulation feeds dynamic knockout engine and strict outcome validator", {
  graph <- phase20_fixture_graph_36x144()
  times <- gsub("2026-09", "2026-12", graph$fixtures$kickoff_utc, fixed=TRUE)
  times <- gsub("2026-10", "2027-01", times, fixed=TRUE)
  graph$fixtures$kickoff_utc <- graph$fixtures$confirmed_kickoff_at_utc <- times
  cutoff <- "2026-11-05T19:40:00Z"
  rules <- .ucl_rule_contract()
  state <- ucl_build_state(graph, rules=rules, state_cutoff_utc=cutoff)
  expect_identical(state$status,"ready")
  release <- phase20_approved_release_fixture(state$graph)
  ledger <- ucl_build_forecast_ledger(state, release=release, state_cutoff_utc=cutoff)
  ledger <- phase20_fixture_strict_ledger(ledger,state$graph,cutoff=cutoff)
  context <- ucl_future_fixture_context(c("(Intercept)"=log(1.1),elo_difference_for_team=.0015,venue_rolehome=log(1.25)),
    3,stats::setNames(seq(1600,1400,length.out=36),state$graph$clubs$club_id), information_cutoff_utc=cutoff,
    future_tie_policy="exchangeable_final_disciplinary_weak_order_v1",
    club_coefficients=stats::setNames(seq(100,1,length.out=36),state$graph$clubs$club_id))
  calendar <- jsonlite::read_json(file.path(review_root,"calendar.json"),simplifyVector=TRUE)
  slots <- lapply(seq_len(nrow(calendar$slots)),function(i) {
    x <- calendar$slots[i,]; ucl_future_fixture_slot(x$slot_id,x$stage_id,x$leg_number,x$kickoff_lower_bound_utc,x$neutral,x$venue_context,calendar$evidence_available_at_utc)
  }); names(slots)<-calendar$slots$slot_id
  simulation <- ucl_run_simulation(state,ledger,simulations=1L,seed=20260921L,rules=rules,
    information_cutoff_utc=cutoff,future_context=context,future_slots=slots)
  expect_identical(simulation$status,"ready")
  expect_equal(nrow(simulation$future_projection$events),23L)
  expect_true(all(simulation$progression_probabilities$status=="resolved"))
  candidate <- ucl_validate_outcome_candidate(list(state=state,ledger=ledger,simulation=simulation),rules,cutoff)
  expect_true(candidate$valid,info=paste(candidate$failures,collapse=","))
  expect_identical(candidate$status,"mechanics_complete")
  expect_false(candidate$production_eligible)
  expect_true(all(!candidate$artifacts$outcomes_manifest$production_eligible))
})

test_that("completed league source enters an outcome-only ledger without retrospective scores", {
  for(e in parse(file.path(root,"tests/testthat/test_ucl_live_bridge.R")))
    if(!is.call(e)||!identical(e[[1L]],as.name("test_that")))eval(e,.GlobalEnv)
  current <- ucl_live_test_current(function(x) {
    row<-0:143;clubs<-as.character(x$clubs$club_id)
    x$matches$home_club_id<-clubs[row%%36L+1L]
    x$matches$away_club_id<-clubs[(row%%36L+row%/%36L+1L)%%36L+1L]
    x$matches$status<-"FINISHED";x$matches$home_score<-0L;x$matches$away_score<-0L;x
  })
  ucl_bridge_load()
  for(path in c("ucl_joint_score_view.R","uefa_champions_league_simulation.R","uefa_champions_league_outcomes.R","ucl_live_outcomes.R","ucl_future_matchups.R"))source(file.path(private,path))
  bridge<-ucl_live_build_bridge(current,now_utc="2026-09-19T13:00:00Z")
  expect_identical(bridge$graph_validation$status,"ready")
  bridge$model_lineage<-list(model_release_id="fixture-only-not-approved",model_sha256=strrep("a",64),calibrator_sha256=strrep("b",64))
  ledger<-.ucl_live_to_simulation_ledger(bridge,NULL)
  expect_s3_class(ledger,"ucl_forecast_ledger")
  expect_equal(nrow(ledger$ledger),144L)
  expect_true(all(ledger$ledger$forecast_status=="suppressed"))
  expect_true(all(is.na(ledger$ledger$prob_home)))
  expect_true(all(vapply(ledger$ledger$score_grid,is.null,logical(1))))
  expect_equal(nrow(ledger$joint_score_views),0L)
  expect_false(ledger$production_eligible)
  expect_true(.ucl_sim_validate_ledger(ledger,bridge$graph,bridge$information_cutoff_utc)$valid)
})
