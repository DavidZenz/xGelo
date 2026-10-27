library(testthat)
source(file.path(normalizePath(file.path(getwd(),if(basename(getwd())=="testthat")"../.."else".")),
  "tests/testthat/helper_phase19_club_fixture.R"))
phase19_test_load()
for(path in c("R/evaluation/proper_scores.R","R/evaluation/benchmark_scores.R","R/club/evaluation_protocol.R",
  "R/club/rating.R","R/club/goal_model.R","R/club/calibration.R","R/club/evaluation.R","R/club/production_runner.R"))
  source(file.path(phase19_test_root,path),local=.GlobalEnv)

production_test_context<-local({value<-NULL;function(){
  if(is.null(value)) {
    root<-phase19_test_fixture_root("production-runner-regression")
    value<<-list(snapshot=phase19_load_fixture_club_training_snapshot(root),
      current=phase19_load_fixture_current_ucl_club_snapshot(root),
      protocol=phase19_load_fixture_club_evaluation_protocol())
  };value
}})

test_that("character goal columns use numeric regulation outcomes",{
  rows<-data.frame(regulation_home_goals=c("10","2","10"),regulation_away_goals=c("2","10","10"))
  expect_identical(phase19_production_class(rows),c("home","away","draw"))
})

test_that("v2 numeric ratings equal audited delayed-evidence batch replay",{
  context<-production_test_context();p<-phase19_club_rating_parameters()
  audited<-phase19_replay_club_ratings(context$snapshot,context$current,p,
    enforce_current_coverage=FALSE)
  numeric<-phase19_production_rating(context$snapshot$matches,p,context$snapshot$cutoff_utc)
  expected<-audited$predictions$rating_difference[match(context$snapshot$matches$match_id,audited$predictions$fixture_id)]
  expect_equal(numeric$training_difference,expected,tolerance=1e-12)
  expect_equal(numeric$state$rating,audited$state$clubs$rating[match(numeric$state$club_id,audited$state$clubs$club_id)],tolerance=1e-12)
  expect_silent(phase19_validate_club_rating_replay(audited,context$snapshot))
})

test_that("vectorized parameter grid matches independent rating states",{
  context<-production_test_context();history<-context$snapshot$matches
  rows<-history[1:2,,drop=FALSE];rows$match_id<-c("grid-a","grid-b")
  rows$kickoff_utc<-c("2026-06-01T00:00:00Z","2026-12-01T00:00:00Z")
  rows$event_date<-substr(rows$kickoff_utc,1,10);rows$kickoff_precision<-"instant"
  grid<-phase19_production_recipe()$rating_grid[c(1,14,27),]
  together<-phase19_production_rating_grid(history,grid,context$snapshot$cutoff_utc,rows)
  for(i in seq_len(nrow(grid))) {
    parameters<-phase19_club_rating_parameters(home_advantage=grid$home_advantage[[i]],k_factor=grid$k_factor[[i]],inactivity_factor=grid$inactivity_factor[[i]])
    separate<-phase19_production_rating(history,parameters,context$snapshot$cutoff_utc,rows)
    expect_equal(unname(together$training_difference[,i]),separate$training_difference,tolerance=1e-12)
    expect_equal(unname(together$forward_difference[,i]),separate$forward_difference,tolerance=1e-12)
  }
})

test_that("late archives do not quarantine timely same-date results",{
  history<-production_test_context()$snapshot$matches[rep(1,3),,drop=FALSE]
  history$match_id<-c("timely","late-archive","later-match")
  history$home_club_id<-c("club_a","club_c","club_a")
  history$away_club_id<-c("club_b","club_d","club_b")
  history$event_date<-c("2021-01-01","2021-01-01","2021-01-03")
  history$kickoff_precision<-"date";history$kickoff_utc<-""
  history$completion_not_before_utc<-paste0(as.Date(history$event_date)+1,"T00:00:00Z")
  history$evidence_available_at_utc<-c("2021-01-02T00:00:00Z","2024-01-01T00:00:00Z","2021-01-04T00:00:00Z")
  history$regulation_home_goals<-2L;history$regulation_away_goals<-0L
  p<-phase19_club_rating_parameters()
  full<-phase19_production_rating(history,p,"2021-01-05T00:00:00Z")
  timely<-phase19_production_rating(history[-2,,drop=FALSE],p,"2021-01-05T00:00:00Z")
  expect_equal(full$training_difference[c(1,3)],timely$training_difference,tolerance=0)
  expect_equal(full$training_difference[1:2],rep(p$home_advantage,2))
  expect_gt(full$training_difference[[3]],p$home_advantage)
  expect_equal(full$state$prior_match_count[full$state$club_id=="club_c"],0L)
  grid<-phase19_production_recipe()$rating_grid[1,,drop=FALSE]
  forward<-history[3,,drop=FALSE];forward$event_date<-"2021-01-06"
  together<-phase19_production_rating_grid(history,grid,"2021-01-05T00:00:00Z",forward)
  scalar<-phase19_production_rating(history,phase19_club_rating_parameters(
    home_advantage=grid$home_advantage,k_factor=grid$k_factor,inactivity_factor=grid$inactivity_factor),
    "2021-01-05T00:00:00Z",forward)
  expect_equal(unname(together$training_difference[,1]),scalar$training_difference,tolerance=1e-12)
})

test_that("decay has one-step versus split-interval equivalence",{
  context<-production_test_context();p<-phase19_club_rating_parameters()
  state<-phase19_replay_club_ratings(context$snapshot,context$current,p,
    enforce_current_coverage=FALSE)$state
  middle<-phase19_club_rating_decay_to(state,"2026-06-01T00:00:00Z")
  split<-phase19_club_rating_decay_to(middle,"2026-12-01T00:00:00Z")
  direct<-phase19_club_rating_decay_to(state,"2026-12-01T00:00:00Z")
  expect_equal(split$clubs$rating,direct$clubs$rating,tolerance=1e-12)
  rows<-context$snapshot$matches[1:2,,drop=FALSE]
  rows$match_id<-c("forward-middle","forward-final")
  rows$kickoff_utc<-c("2026-06-01T00:00:00Z","2026-12-01T00:00:00Z")
  rows$event_date<-substr(rows$kickoff_utc,1,10)
  rows$kickoff_precision<-"instant"
  # Use the same pairing at both dates; labels must never update forward state.
  rows$home_club_id<-rows$home_club_id[[1L]];rows$away_club_id<-rows$away_club_id[[1L]]
  with_middle<-phase19_production_rating(context$snapshot$matches,p,context$snapshot$cutoff_utc,rows)
  direct_numeric<-phase19_production_rating(context$snapshot$matches,p,context$snapshot$cutoff_utc,rows[2,,drop=FALSE])
  expect_equal(with_middle$forward_difference[[2L]],direct_numeric$forward_difference[[1L]],tolerance=1e-12)
  rows$regulation_home_goals<-99L;rows$regulation_away_goals<-0L
  changed<-phase19_production_rating(context$snapshot$matches,p,context$snapshot$cutoff_utc,rows)
  expect_identical(changed$forward_difference,with_middle$forward_difference)
})

test_that("fast finite-support NB probabilities match the complete score grid",{
  set.seed(1903001)
  history<-data.frame(match_id=sprintf("match-%03d",1:200),regulation_home_goals=rnbinom(200,mu=1.7,size=3),
    regulation_away_goals=rnbinom(200,mu=1.1,size=3))
  ratings<-data.frame(rating_difference=seq(-250,250,length.out=200))
  model<-phase19_club_goal_nb_fit(goals~elo_difference_for_team+venue_role,
    phase19_club_goal_long_training(history,ratings,phase19_club_goal_active_features("club_elo_nb")),"club_elo_nb")$model
  p<-phase19_production_probabilities(model,model$theta,c(-200,0,200),"club_elo_nb")
  fit<-list(model_id="club_elo_nb",theta=model$theta,support_max=40L,
    tail_policy="truncate_0_40_then_joint_renormalize_once",fit_sha256=paste(rep("a",64),collapse=""))
  for(i in 1:3) {
    grid<-phase19_club_goal_distribution(fit,paste0("fixture-",i),p$expected_home_goals[[i]],p$expected_away_goals[[i]])
    markets<-phase19_club_goal_grid_markets(grid)
    expect_equal(unname(as.numeric(p[i,1:3])),unname(unlist(markets[c("p_home","p_draw","p_away")])),tolerance=1e-12)
    expect_equal(nrow(grid),1681L)
  }
})

test_that("saved NB family environments do not change fitted model contents",{
  set.seed(1903001)
  h<-data.frame(match_id=sprintf("saved-%03d",1:200),
    regulation_home_goals=rnbinom(200,mu=1.7,size=3),regulation_away_goals=rnbinom(200,mu=1.1,size=3))
  fit<-phase19_club_goal_nb_fit(goals~venue_role,
    phase19_club_goal_long_training(h,data.frame(rating_difference=rep(60,200)),"venue_role"),"club_venue_nb")
  attr(fit$model$terms,".Environment")<-baseenv()
  attr(fit$model$model,"terms")<-fit$model$terms
  standalone<-tempfile();bundle<-tempfile()
  on.exit(unlink(c(standalone,bundle)),add=TRUE)
  saveRDS(fit,standalone);saveRDS(list(fit=fit),bundle)
  a<-readRDS(standalone);b<-readRDS(bundle)$fit
  expect_true(identical(a,b,ignore.environment=TRUE))
  expect_identical(phase19_club_goal_nested_hash(a$model,"test"),phase19_club_goal_nested_hash(b$model,"test"))
  b$model$theta<-b$model$theta+1
  expect_false(identical(a,b,ignore.environment=TRUE))
})

test_that("incumbent retention never bypasses absolute coverage or integrity gates",{
  protocol<-production_test_context()$protocol
  values<-as.list(rep(1,length(phase19_club_evaluation_metric_names())));names(values)<-phase19_club_evaluation_metric_names()
  values$equal_fold_rps_delta<-0;values$paired_rps_ci_upper<-.01
  values$rolling_origin_fold_breadth<-0;values$heldout_league_fold_breadth<-0
  values$worst_fold_rps_regression<-0;values$equal_fold_brier_relative_regression<-0
  values$equal_fold_log_loss_relative_regression<-0;values$fixed_bin_calibration_delta<-0
  retained<-phase19_production_decision(values,protocol)
  expect_identical(retained$selected_model_id,"club_venue_nb")
  expect_identical(retained$promotion_status,"retained")
  values$current_ucl_club_coverage<-35/36
  blocked<-phase19_production_decision(values,protocol)
  expect_identical(blocked$promotion_status,"blocked")
  expect_false(blocked$absolute_gates_passed)
  expect_true("current_ucl_club_coverage"%in%blocked$failed_gate_ids)
})

test_that("production refuses diagnostic parents and unapproved recipe",{
  context<-production_test_context()
  expect_error(phase19_production_assert_parents(context$snapshot,context$current,context$protocol,list()),
    class="phase19_club_contract_error")
  recipe<-phase19_production_recipe()
  expect_equal(nrow(recipe$rating_grid),27L)
  expect_identical(recipe,phase19_production_recipe())
})

test_that("routine feed refresh preserves stable roster binding and changed clubs block it",{
  current<-production_test_context()$current
  refreshed<-current
  refreshed$bundle_id<-"new-accepted-live-generation"
  refreshed$source_generation_id<-"new-generation"
  refreshed$bundle_sha256<-paste(rep("e",64),collapse="")
  expect_identical(phase19_production_roster_identity(current),phase19_production_roster_identity(refreshed))
  refreshed$clubs$club_id[[1L]]<-"club_changed_roster_member"
  expect_false(identical(phase19_production_roster_identity(current),phase19_production_roster_identity(refreshed)))
  refreshed<-current;refreshed$identity_registry_sha256<-paste(rep("f",64),collapse="")
  expect_false(identical(phase19_production_roster_identity(current),phase19_production_roster_identity(refreshed)))
})

production_test_large_fixture <- function() {
  context<-production_test_context();snapshot<-context$snapshot
  set.seed(1903001)
  rows<-snapshot$matches[rep(1:6,length.out=1200),,drop=FALSE]
  day<-as.Date("2021-01-01")+seq_len(nrow(rows))-1L
  rows$match_id<-sprintf("v2_diagnostic_%04d",seq_len(nrow(rows)))
  rows$source_match_id<-rows$match_id
  rows$event_date<-as.character(day);rows$kickoff_utc<-paste0(day,"T18:00:00Z")
  rows$kickoff_precision<-"instant"
  rows$completion_not_before_utc<-paste0(day,"T20:00:00Z")
  rows$evidence_available_at_utc<-paste0(day,"T20:00:00Z")
  rows$regulation_home_goals<-as.integer(rnbinom(nrow(rows),mu=1.6,size=3))
  rows$regulation_away_goals<-as.integer(rnbinom(nrow(rows),mu=1.2,size=3))
  rows$row_sha256<-"";rows$row_sha256<-phase18_history_row_sha256(rows)
  rows<-phase18_history_canonical_table(rows,c("source_id","source_match_id","match_id"))
  snapshot$matches<-rows;snapshot$row_count<-as.integer(nrow(rows))
  snapshot$phase19_matches_sha256<-phase18_hash_table_v2(rows,key=c("source_id","source_match_id","match_id"),schema_tag="phase19-club-training-matches-v1")
  snapshot$snapshot_sha256<-phase19_training_snapshot_sha256(snapshot)
  phase19_validate_club_training_snapshot(snapshot,"fixture")
  chronology<-rows[order(rows$kickoff_utc,method="radix"),,drop=FALSE]
  fit<-chronology[1:800,,drop=FALSE];calibration<-chronology[801:1040,,drop=FALSE];assessment<-chronology[1041:1200,,drop=FALSE]
  fold<-as.data.frame(setNames(as.list(rep("",length(phase19_fold_registry_schema()))),phase19_fold_registry_schema()),stringsAsFactors=FALSE)
  fold$schema_version<-"phase19-club-fold-v1";fold$hash_encoding_version<-phase18_canonical_encoding_v2()
  fold$forecast_domain<-"club";fold$authority_mode<-"fixture";fold$fixture_authority<-TRUE
  fold$fold_id<-"club__rolling_origin_league_season__diagnostic__2024"
  fold$fold_family<-"rolling_origin_league_season";fold$assessment_competition_id<-"diagnostic";fold$assessment_season_id<-"2024"
  fold$assessment_start_utc<-min(assessment$kickoff_utc);fold$assessment_end_utc<-max(assessment$kickoff_utc)
  fold$training_cutoff_exclusive<-min(calibration$kickoff_utc);fold$calibration_cutoff_exclusive<-min(assessment$kickoff_utc)
  for(role in c("training","calibration","declared")) {
    inventory<-switch(role,training=fit$match_id,calibration=calibration$match_id,declared=assessment$match_id)
    fold[[paste0(role,"_fixture_ids")]]<-phase19_fold_id_text(inventory,paste0(role,"_fixture_ids"))
    fold[[paste0(role,"_fixture_count")]]<-as.integer(length(inventory))
    fold[[paste0(role,"_fixture_sha256")]]<-phase19_fold_id_sha256(sort(inventory,method="radix"),role)
  }
  fold$eligibility_status<-"eligible";fold$accepted_generation_id<-snapshot$accepted_generation_id
  fold$corpus_manifest_sha256<-snapshot$corpus_manifest_sha256;fold$snapshot_sha256<-snapshot$snapshot_sha256
  fold$protocol_sha256<-context$protocol$protocol_sha256;fold$policy_review_sha256<-context$protocol$policy_review$review_sha256
  fold$calibration_recipe_sha256<-phase19_expected_calibration_recipe()$recipe_sha256;fold$row_sha256<-phase19_fold_row_sha256(fold)
  list(snapshot=snapshot,current=context$current,protocol=context$protocol,fold=fold)
}

test_that("complete diagnostic fold refits twice with prior-only temperature and view selection",{
  context<-production_test_large_fixture()
  first<-phase19_production_one_fold(context$snapshot,context$current,context$protocol,context$fold)
  second<-phase19_production_one_fold(context$snapshot,context$current,context$protocol,context$fold)
  expect_identical(first$execution_sha256,second$execution_sha256)
  expect_equal(nrow(first$tuning$table),27L)
  expect_false(first$candidate$fit$production_eligible)
  expect_false(first$candidate$calibrator$production_eligible)
  expect_true(max(first$candidate$calibration_source$evidence_available_at_utc)<first$candidate$calibrator$calibration_cutoff_exclusive)
  expect_length(intersect(first$role_ids$temperature,first$role_ids$selection),0L)
  expect_length(intersect(first$role_ids$assessment,unlist(first$role_ids[c("fit","temperature","selection")])),0L)
  # Changing outer outcomes can alter scores, but cannot enter tuning, fitting,
  # temperature estimation or the frozen prior probability-view decision.
  changed<-context$snapshot
  take<-changed$matches$match_id%in%first$role_ids$assessment
  changed$matches$regulation_home_goals[take]<-9L;changed$matches$regulation_away_goals[take]<-0L
  changed$matches$row_sha256<-"";changed$matches$row_sha256<-phase18_history_row_sha256(changed$matches)
  changed$phase19_matches_sha256<-phase18_hash_table_v2(changed$matches,key=c("source_id","source_match_id","match_id"),schema_tag="phase19-club-training-matches-v1")
  changed$snapshot_sha256<-phase19_training_snapshot_sha256(changed)
  changed_fold<-context$fold;changed_fold$snapshot_sha256<-changed$snapshot_sha256
  changed_fold$row_sha256<-phase19_fold_row_sha256(changed_fold)
  perturbed<-phase19_production_one_fold(changed,context$current,context$protocol,changed_fold)
  expect_identical(first$tuning,perturbed$tuning)
  expect_identical(first$candidate$fit$coefficients,perturbed$candidate$fit$coefficients)
  expect_identical(first$candidate$calibrator$temperature,perturbed$candidate$calibrator$temperature)
  expect_identical(first$candidate$view_selection$primary_probability_view,perturbed$candidate$view_selection$primary_probability_view)
  expect_equal(first$candidate$predictions[,1:3],perturbed$candidate$predictions[,1:3],tolerance=0)
  expect_false(identical(first$candidate$scores,perturbed$candidate$scores))
})

test_that("tuning skips count-supported but rank-deficient archive windows",{
  context<-production_test_large_fixture()
  h<-context$snapshot$matches
  h<-h[order(h$kickoff_utc,method="radix"),,drop=FALSE][1:800,,drop=FALSE]
  archive_time<-h$evidence_available_at_utc[[660L]]
  h$evidence_available_at_utc[1:660]<-archive_time
  tuned<-phase19_production_tune(h,context$protocol)
  expect_gt(tuned$cutoff,archive_time)
  expect_true(all(is.finite(tuned$table$rps)))
  expect_equal(nrow(tuned$table),27L)
  expect_true(all(h$evidence_available_at_utc[match(tuned$fit_ids,h$match_id)]<tuned$cutoff))
  expect_length(intersect(tuned$fit_ids,tuned$selection_ids),0L)
})
