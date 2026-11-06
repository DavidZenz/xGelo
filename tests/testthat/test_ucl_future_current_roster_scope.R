library(testthat)
scope_main <- normalizePath(Sys.getenv("XGELO_PROJECT_ROOT",if(basename(getwd())=="testthat")"../.."else"."),mustWork=TRUE)
scope_project <- normalizePath(Sys.getenv("XGELO_CL9_SCOPE_PROJECT",scope_main),mustWork=TRUE)
scope_runtime <- new.env(parent=baseenv());scope_runtime$setNames<-stats::setNames
for(path in c("R/common/phase18_canonical_hash.R"))sys.source(file.path(scope_main,path),envir=scope_runtime)
for(name in c("ucl_joint_score_view.R","ucl_future_matchups.R"))sys.source(file.path(scope_project,"R/competition",name),envir=scope_runtime)
scope_read <- function(name)utils::read.csv(file.path(scope_project,"tests/fixtures/cl9_current_roster_scope",name),stringsAsFactors=FALSE)
scope_coefficient_table <- scope_read("current_coefficient_inputs.csv")
scope_current <- list(clubs=data.frame(club_id=scope_coefficient_table$club_id,stringsAsFactors=FALSE))
scope_ids <- scope_read("historical_club_ids.csv")$club_id
# Only identities come from accepted data. These ratings/counts are explicit
# mechanics fixtures, not a reproduced or independently validated rating state.
scope_state <- list(clubs=data.frame(club_id=scope_ids,rating=seq(1400,1700,length.out=length(scope_ids)),
  prior_match_count=rep(67L,length(scope_ids)),stringsAsFactors=FALSE))
scope_hash <- function(state)digest::digest(list(fixture_only=TRUE,clubs=state$clubs),algo="sha256")
scope_state$state_sha256<-scope_hash(scope_state)
scope_context <- function(state, ratings, rating_at=NULL) {
  lineage<-list(model_release_id="fixture-only-no-production-release",model_sha256=strrep("a",64L),
    calibrator_sha256=strrep("b",64L),source_bundle_sha256=strrep("c",64L),rating_state_sha256=state$state_sha256,
    future_policy_sha256=strrep("d",64L),joint_policy_sha256=strrep("d",64L))
  scope_runtime$.ucl_future_context(c("(Intercept)"=log(1.1),elo_difference_for_team=.0015,venue_rolehome=log(1.25)),
    3,ratings,60,1.2,"calibrated_1x2","2026-11-05T19:00:00Z","2026-11-05T19:00:00Z",lineage,
    authority_mode="fixture",rating_at=rating_at,club_coefficients=scope_runtime$ucl_future_validate_coefficient_inputs(scope_coefficient_table,names(ratings))$values)
}

test_that("343 historical identities scope to the exact current36 coefficient contract", {
  before<-serialize(scope_state,NULL)
  expect_length(scope_ids,343L);expect_length(scope_current$clubs$club_id,36L)
  expect_length(setdiff(scope_ids,scope_current$clubs$club_id),307L)
  # This is the old production assembly's actual contradiction, not a fitted
  # model or a fabricated owner decision.
  expect_error(scope_runtime$ucl_future_validate_coefficient_inputs(scope_coefficient_table,scope_state$clubs$club_id),
    "known_coefficient_coverage_incomplete")
  current<-scope_runtime$.ucl_future_current_roster_ratings(scope_state,scope_current)
  expect_identical(names(current),sort(scope_current$clubs$club_id,method="radix"))
  expect_identical(unname(current),scope_state$clubs$rating[match(names(current),scope_state$clubs$club_id)])
  expect_silent(scope_runtime$ucl_future_validate_coefficient_inputs(scope_coefficient_table,names(current)))
  expect_identical(serialize(scope_state,NULL),before)
  reversed<-scope_state;reversed$clubs<-reversed$clubs[nrow(reversed$clubs):1,,drop=FALSE]
  roster<-scope_current;roster$clubs<-roster$clubs[36:1,,drop=FALSE]
  expect_identical(scope_runtime$.ucl_future_current_roster_ratings(reversed,roster),current)
})

test_that("missing duplicate and foreign current-roster identities remain blocked", {
  x<-scope_current;x$clubs<-x$clubs[-1,,drop=FALSE]
  expect_error(scope_runtime$.ucl_future_current_roster_ratings(scope_state,x),"current_roster_invalid")
  x<-scope_current;x$clubs$club_id[1]<-x$clubs$club_id[2]
  expect_error(scope_runtime$.ucl_future_current_roster_ratings(scope_state,x),"current_roster_invalid")
  x<-scope_current;x$clubs$club_id[1]<-NA_character_
  expect_error(scope_runtime$.ucl_future_current_roster_ratings(scope_state,x),"current_roster_invalid")
  x<-scope_current;x$clubs$club_id[1]<-"national_spain"
  expect_error(scope_runtime$.ucl_future_current_roster_ratings(scope_state,x),"current_roster_invalid")
  x<-scope_current;x$clubs$club_id[1]<-"club_missing_current"
  expect_error(scope_runtime$.ucl_future_current_roster_ratings(scope_state,x),"current_roster_rating_missing")
  # A different historical club is not silently covered by the fixed current
  # coefficient evidence, even when its historical rating exists.
  x<-scope_current;x$clubs$club_id[1]<-setdiff(scope_ids,scope_current$clubs$club_id)[1]
  ratings<-scope_runtime$.ucl_future_current_roster_ratings(scope_state,x)
  expect_error(scope_runtime$ucl_future_validate_coefficient_inputs(scope_coefficient_table,names(ratings)),
    "known_coefficient_coverage_incomplete")
})

test_that("rating identity validity and all36 current-history coverage remain strict", {
  expect_error(scope_runtime$.ucl_future_current_roster_ratings(1,scope_current),"rating_state_roster_invalid")
  at<-match(scope_current$clubs$club_id[1],scope_state$clubs$club_id)
  x<-scope_state;x$clubs<-x$clubs[-at,,drop=FALSE]
  expect_error(scope_runtime$.ucl_future_current_roster_ratings(x,scope_current),"current_roster_rating_missing")
  x<-scope_state;x$clubs<-rbind(x$clubs,x$clubs[at,,drop=FALSE])
  expect_error(scope_runtime$.ucl_future_current_roster_ratings(x,scope_current),"rating_state_roster_invalid")
  for(value in c(NA_real_,Inf)){
    x<-scope_state;x$clubs$rating[at]<-value
    expect_error(scope_runtime$.ucl_future_current_roster_ratings(x,scope_current),"rating_state_roster_invalid")
  }
  x<-scope_state;x$clubs$rating<-as.character(x$clubs$rating)
  expect_error(scope_runtime$.ucl_future_current_roster_ratings(x,scope_current),"rating_state_roster_invalid")
  x<-scope_state;x$clubs$prior_match_count[at]<-0L
  expect_error(scope_runtime$.ucl_future_current_roster_ratings(x,scope_current),"current_roster_history_incomplete")
  for(value in c(-1,1.5,NA_real_)){
    x<-scope_state;x$clubs$prior_match_count[at]<-value
    expect_error(scope_runtime$.ucl_future_current_roster_ratings(x,scope_current),"rating_state_roster_invalid")
  }
})

test_that("noncurrent historical clubs need no current-edition coefficients or current coverage", {
  selected<-scope_runtime$.ucl_future_current_roster_ratings(scope_state,scope_current)
  x<-scope_state;outside<-!x$clubs$club_id%in%scope_current$clubs$club_id
  x$clubs$prior_match_count[outside]<-0L
  expect_identical(scope_runtime$.ucl_future_current_roster_ratings(x,scope_current),selected)
  only_current<-scope_state;only_current$clubs<-only_current$clubs[!outside,,drop=FALSE]
  expect_identical(scope_runtime$.ucl_future_current_roster_ratings(only_current,scope_current),selected)
})

test_that("scoped fixtures retain full replay lineage and unchanged current matchup probabilities", {
  selected<-scope_runtime$.ucl_future_current_roster_ratings(scope_state,scope_current)
  direct<-stats::setNames(scope_state$clubs$rating[match(names(selected),scope_state$clubs$club_id)],names(selected))
  context<-scope_context(scope_state,selected);control<-scope_context(scope_state,direct)
  expect_identical(context$rating_state_sha256,scope_state$state_sha256)
  expect_length(context$ratings,36L);expect_setequal(names(context$ratings),scope_current$clubs$club_id)
  expect_true(context$fixture_authority);expect_false(isTRUE(context$production_eligible))
  expect_false(scope_runtime$ucl_future_context_is_production(context))
  slot<-scope_runtime$ucl_future_fixture_slot("neutral-final","final",1L,"2027-06-05T00:00:00Z",neutral=TRUE)
  clubs<-names(selected)[1:2]
  a<-scope_runtime$ucl_future_forecast_matchup(context,clubs[1],clubs[2],slot)
  b<-scope_runtime$ucl_future_forecast_matchup(control,clubs[1],clubs[2],slot)
  expect_identical(a$primary_1x2,b$primary_1x2);expect_identical(a$score_grid,b$score_grid)
  expect_error(scope_runtime$ucl_future_forecast_matchup(context,clubs[1],setdiff(scope_ids,names(selected))[1],slot),
    "dynamic_matchup_identity_invalid")
  changed<-scope_state;outside<-which(!changed$clubs$club_id%in%names(selected))[1]
  changed$clubs$rating[outside]<-changed$clubs$rating[outside]+1
  changed$state_sha256<-scope_hash(changed)
  changed_context<-scope_context(changed,scope_runtime$.ucl_future_current_roster_ratings(changed,scope_current))
  expect_identical(changed_context$ratings,context$ratings)
  expect_false(identical(changed_context$rating_state_sha256,context$rating_state_sha256))
  expect_false(identical(changed_context$context_sha256,context$context_sha256))
})

test_that("future rating views select current36 but retain the full decayed-state hash", {
  decayed<-scope_state;decayed$clubs$rating<-1500+(decayed$clubs$rating-1500)*.9
  decayed$state_sha256<-scope_hash(decayed)
  rating_at<-function(instant)list(ratings=scope_runtime$.ucl_future_current_roster_ratings(decayed,scope_current),state_sha256=decayed$state_sha256)
  selected<-scope_runtime$.ucl_future_current_roster_ratings(scope_state,scope_current)
  context<-scope_context(scope_state,selected,rating_at)
  slot<-scope_runtime$ucl_future_fixture_slot("neutral-final","final",1L,"2027-06-05T00:00:00Z",neutral=TRUE)
  out<-scope_runtime$ucl_future_forecast_matchup(context,names(selected)[1],names(selected)[2],slot)
  expect_identical(context$rating_state_sha256,scope_state$state_sha256)
  expect_identical(out$metadata$home_rating_state_sha256,decayed$state_sha256)
  expect_length(rating_at(slot$kickoff_lower_bound_utc)$ratings,36L)
  expect_true(out$metadata$fixture_authority)
})
