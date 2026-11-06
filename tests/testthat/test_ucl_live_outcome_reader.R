library(testthat)
reader_test_root<-Sys.getenv("XGELO_CL9_READER_PROJECT",unset="")
if(!nzchar(reader_test_root)){
  reader_test_root<-normalizePath(getwd(),mustWork=TRUE)
  while(!file.exists(file.path(reader_test_root,"R/competition/ucl_live_outcome_reader.R"))){
    parent<-dirname(reader_test_root);if(identical(parent,reader_test_root))stop("CL reader test project root missing");reader_test_root<-parent
  }
}
if(!nzchar(Sys.getenv("XGELO_PROJECT_ROOT")))Sys.setenv(XGELO_PROJECT_ROOT=reader_test_root)
Sys.setenv(XGELO_CL9_READER_PROJECT=reader_test_root)
reader_helper<-file.path(reader_test_root,"tests/testthat/ucl_live_outcome_reader_fixture_helper.R")
sys.source(reader_helper,envir=environment())

test_that("complete immutable17-table fixtures restore types but cannot grant production", {
  f<-reader_write_fixture();out<-reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)
  expect_identical(out$status,"mechanics_valid",info=out$reason_code)
  expect_false(out$production_eligible);expect_true(out$fixture_authority)
  expect_setequal(names(out$tables),reader_env$.ucl_read_inventory())
  expect_true(is.integer(out$tables$league_rank_inputs$rank))
  expect_true(is.logical(out$tables$future_knockout_events$penalty_applied))
  expect_true(all(is.na(out$tables$fixture_forecast_ledger$suppression_reason)))
  expect_identical(out$tables$simulation_metadata,f$tables$simulation_metadata)
  expect_false(reader_env$ucl_validate_live_outcomes_read_result(out))
  forged<-out;forged$status<-"available";forged$production_eligible<-TRUE;forged$fixture_authority<-FALSE
  expect_false(reader_env$ucl_validate_live_outcomes_read_result(forged))
})

test_that("raw byte canonical and incomplete inventories fail closed", {
  f<-reader_write_fixture();path<-file.path(f$generation,"league_rank_inputs.csv")
  cat("\n",file=path,append=TRUE)
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"table_bytes_changed")
  f<-reader_write_fixture();unlink(file.path(f$generation,"late_tie_prior_contribution.csv"))
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"publication_inventory_changed")
  f<-reader_write_fixture();writeLines("unregistered",file.path(f$generation,"extra.csv"))
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"publication_inventory_changed")
})

test_that("empirical probabilities ranks and uncertainty are independently reconciled", {
  f<-reader_write_fixture(mutate=function(t){t$progression_probabilities$probability[1]<-.5;t})
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"empirical_probability_mismatch")
  f<-reader_write_fixture(mutate=function(t){t$league_rank_inputs$rank[1]<-2L;t})
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"rank_permutation_invalid")
  f<-reader_write_fixture(mutate=function(t){t$monte_carlo_uncertainty$mc95_upper[1]<-.123;t})
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"uncertainty_mismatch")
  f<-reader_write_fixture(mutate=function(t){t$late_tie_prior_contribution$all_stage_max_absolute_probability_change_bound[1]<-.1;t})
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"late_prior_contribution_mismatch")
})

test_that("legal DAG paths and query coverage cannot be replaced with shaped tables", {
  f<-reader_write_fixture(mutate=function(t){t$future_knockout_events$participant_b[1]<-t$future_knockout_events$participant_a[1];t})
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"stage_participant_duplicated")
  f<-reader_write_fixture(mutate=function(t){t$future_knockout_events$inherited_winner_seed[1]<-36L;t})
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"inherited_seed_invalid")
  f<-reader_write_fixture(mutate=function(t){t$future_matchup_provenance<-t$future_matchup_provenance[-1,];t})
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"future_provenance_inventory_invalid")
  f<-reader_write_fixture(mutate=function(t){at<-which(t$knockout_paths$stage_event_id=="po-silver-1");t$knockout_paths$aggregate_final_home[at]<-0L;t$knockout_paths$aggregate_final_away[at]<-3L;t$knockout_paths$aggregate_regulation_home[at]<-0L;t$knockout_paths$aggregate_regulation_away[at]<-3L;t})
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"representative_winner_mismatch")
  f<-reader_write_fixture(mutate=function(t){t$knockout_paths$aggregate_final_home[1]<-7L;t})
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"representative_champion_mismatch")
})

test_that("unsafe pointer paths and symlinked immutable files are rejected", {
  f<-reader_write_fixture();pointer<-f$pointer;pointer$generation<-"../escape"
  jsonlite::write_json(pointer,file.path(f$root,"outcomes_current.json"),auto_unbox=TRUE)
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"unsafe_generation_pointer")
  f<-reader_write_fixture();original<-file.path(f$generation,"league_schedule.csv");outside<-tempfile();file.copy(original,outside);unlink(original)
  expect_true(file.symlink(outside,original))
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"unsafe_publication_path")
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(dirname(tempdir()),reader_fixture_time)$reason_code,"fixture_root_not_process_temporary")
})

test_that("old schemas foreign editions and national-model provenance cannot authorize CL", {
  f<-reader_write_fixture();pointer<-f$pointer;pointer$schema_version<-"legacy-outcomes-v0"
  jsonlite::write_json(pointer,file.path(f$root,"outcomes_current.json"),auto_unbox=TRUE)
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"publication_domain_invalid")
  f<-reader_write_fixture();pointer<-f$pointer;pointer$edition_id<-"uefa_nations_league_2026_27"
  jsonlite::write_json(pointer,file.path(f$root,"outcomes_current.json"),auto_unbox=TRUE)
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"publication_domain_invalid")
  f<-reader_write_fixture(mutate=function(t){t$future_matchup_provenance$forecast_domain<-"national";t})
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"future_provenance_inventory_invalid")
})

test_that("stored cutoff future provenance and direct fixture promotion are gated", {
  f<-reader_write_fixture()
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,"2026-11-08T00:00:00Z")$reason_code,"publication_cutoff_stale_or_future")
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,"2026-11-05T22:00:00Z")$reason_code,"publication_cutoff_stale_or_future")
  f<-reader_write_fixture(mutate=function(t){t$future_matchup_provenance$raw_tail_mass[1]<-.2;t})
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"future_provenance_qa_invalid")
  expect_error(reader_env$ucl_read_live_outcomes(root=f$root),"unused argument")
  expect_error(reader_env$ucl_read_live_outcomes(release=list(production_eligible=TRUE)),"unused argument")
})

test_that("production routing is fixed to the bound runtime root and never caller cwd", {
  unrelated<-tempfile("unrelated-project-");dir.create(unrelated)
  old<-getwd();on.exit(setwd(old),add=TRUE);setwd(unrelated)
  expect_identical(reader_env$.ucl_read_project_root(),reader_bound_root)
  out<-reader_env$ucl_read_live_outcomes()
  expect_identical(out$reason_code,"publication_missing")
  expect_false(out$production_eligible)
  expect_identical(reader_env$ucl_read_live_outcomes(reader_fixture_time)$reason_code,"production_reader_requires_current_time")
})

test_that("current-parent comparison rejects changed parents and fixture contexts", {
  f<-reader_write_fixture();b<-reader_env$.ucl_read_mechanics(reader_env$.ucl_read_load(f$root),reader_fixture_time)
  c<-list(forecast_domain="club",entity_kind="club",authority_mode="production",fixture_authority=FALSE,production_eligible=TRUE,selected_model_id="club_elo_nb",
    release_id=b$manifest$model_release_id,model_sha256=b$manifest$model_sha256,calibrator_sha256=b$manifest$calibrator_sha256)
  release<-list(forecast_domain="club",model_contract=c)
  current<-list(accepted=list(bundle=data.frame(bundle_sha256=b$manifest$source_bundle_sha256)))
  policy<-list(status="approved",policy_sha256=b$manifest$assumptions_policy_sha256)
  # These are comparison-only fixture inputs. This helper cannot issue a token,
  # and the real factory must independently resolve all parents before calling it.
  changed<-current;changed$accepted$bundle$bundle_sha256<-strrep("0",64)
  expect_error(reader_env$.ucl_read_parent_identity(b,changed,release,policy,reader_fixture_tables$context),"current_parent_mismatch")
  changed<-release;changed$model_contract$model_sha256<-strrep("0",64)
  expect_error(reader_env$.ucl_read_parent_identity(b,current,changed,policy,reader_fixture_tables$context),"current_parent_mismatch")
  changed<-policy;changed$policy_sha256<-strrep("0",64)
  expect_error(reader_env$.ucl_read_parent_identity(b,current,release,changed,reader_fixture_tables$context),"current_parent_mismatch")
  changed<-release;changed$forecast_domain<-"national"
  expect_error(reader_env$.ucl_read_parent_identity(b,current,changed,policy,reader_fixture_tables$context),"qualifying_club_model_required")
  expect_error(reader_env$.ucl_read_parent_identity(b,current,release,policy,reader_fixture_tables$context),"current_parent_authority_invalid")
})

test_that("late-prior inputs contribution and coefficient order are checked independently",{
  f<-reader_write_fixture(mutate=reader_declared_late_prior);out<-reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)
  expect_identical(out$status,"mechanics_valid",info=out$reason_code);expect_false(out$production_eligible)
  expect_equal(out$tables$late_tie_prior_contribution$all_stage_max_absolute_probability_change_bound,rep(1,36))
  f<-reader_write_fixture(mutate=function(t){t<-reader_declared_late_prior(t);t$late_tie_prior_samples$known_club_coefficient<-c(9,10);t})
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"late_prior_coefficient_order_invalid")
  f<-reader_write_fixture(mutate=function(t){t<-reader_declared_late_prior(t);t$late_tie_prior_samples$factual_rank_claimed[1]<-TRUE;t})
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"late_prior_authority_invalid")
})

test_that("declared extra time and penalties preserve legal resolution without invented tallies",{
  f<-reader_write_fixture(mutate=reader_declared_final_extra_time);out<-reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)
  expect_identical(out$status,"mechanics_valid",info=out$reason_code);expect_false(out$production_eligible)
  f<-reader_write_fixture(mutate=function(t)reader_declared_final_extra_time(t,TRUE));out<-reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)
  expect_identical(out$status,"mechanics_valid",info=out$reason_code);expect_true(all(is.na(out$tables$knockout_paths$penalty_home)))
  f<-reader_write_fixture(mutate=function(t){t<-reader_declared_final_extra_time(t);t$future_knockout_events$resolution[t$future_knockout_events$stage_id=="final"]<-"regulation";t})
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"knockout_resolution_invalid")
  f<-reader_write_fixture(mutate=function(t){t<-reader_declared_final_extra_time(t);t$knockout_paths$extra_time_home[t$knockout_paths$stage_id=="final"]<-2L;t})
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"representative_extra_time_mismatch")
})

test_that("typed null contracts reject truncation nonfinite numbers and incorrect canonical bytes",{
  root<-tempfile("strict-types-");dir.create(root)
  table<-data.frame(i=1L,d=.123,flag=TRUE,label=NA_character_);d<-reader_lossless_fixture_tables(list(value=table),root)$value;path<-file.path(root,"value.csv")
  expect_identical(reader_env$.ucl_read_typed(path,d),table)
  raw<-utils::read.csv(path,colClasses="character",na.strings=NULL);raw$i<-"1.5";utils::write.csv(raw,path,row.names=FALSE,quote=TRUE);d$sha256<-reader_env$.ucl_read_sha(path)
  expect_error(reader_env$.ucl_read_typed(path,d),"typed_integer_invalid")
  raw$i<-"1";raw$d<-"Inf";utils::write.csv(raw,path,row.names=FALSE,quote=TRUE);d$sha256<-reader_env$.ucl_read_sha(path)
  expect_error(reader_env$.ucl_read_typed(path,d),"typed_double_invalid")
  raw$d<-sprintf("%a",.123);raw$flag<-"1";utils::write.csv(raw,path,row.names=FALSE,quote=TRUE);d$sha256<-reader_env$.ucl_read_sha(path)
  expect_error(reader_env$.ucl_read_typed(path,d),"typed_logical_invalid")
  d<-reader_lossless_fixture_tables(list(value=table),root)$value;d$canonical_sha256<-strrep("0",64)
  expect_error(reader_env$.ucl_read_typed(path,d),"table_canonical_hash_changed")
  d<-reader_lossless_fixture_tables(list(value=table),root)$value;raw<-utils::read.csv(path,colClasses="character",na.strings=NULL);raw$label<-"not-null"
  utils::write.csv(raw,path,row.names=FALSE,quote=TRUE);d$sha256<-reader_env$.ucl_read_sha(path)
  expect_error(reader_env$.ucl_read_typed(path,d),"null_rows_invalid")
})

test_that("self-stamped fixture metadata cannot grant current production authority",{
  f<-reader_write_fixture(mutate=function(t){t$simulation_metadata$authority_mode<-"production";t$simulation_metadata$production_eligible<-TRUE
    t$future_matchup_provenance$authority_mode<-"production";t$future_matchup_provenance$fixture_authority<-FALSE
    core<-setdiff(names(t$future_matchup_provenance),c("iteration","fixture_id","is_official_fixture","forecast_sha256"))
    t$future_matchup_provenance$forecast_sha256<-vapply(seq_len(nrow(t$future_matchup_provenance)),function(i)reader_env$.ucl_future_hash(as.list(t$future_matchup_provenance[i,core,drop=FALSE]),"ucl-dynamic-matchup-forecast-v1"),character(1));t})
  # The mechanical fixture reader always reports fixture authority regardless
  # of serialized claims, and the fixed reader has no caller-root parameter.
  out<-reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)
  expect_identical(out$status,"mechanics_valid",info=out$reason_code);expect_false(out$production_eligible);expect_true(out$fixture_authority)
  expect_false(reader_env$ucl_validate_live_outcomes_read_result(out))
  expect_false(reader_env$ucl_validate_live_outcomes_read_result(unserialize(serialize(out,NULL))))
  f<-reader_write_fixture();changed<-f$pointer;changed$model_release_id<-"national-or-new-release"
  jsonlite::write_json(changed,file.path(f$root,"outcomes_current.json"),auto_unbox=TRUE)
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"pointer_manifest_parent_mismatch")
})

test_that("the reader refuses an unbound canonical runtime instead of falling back",{
  f<-reader_write_fixture();saved<-reader_env$.ucl_out_canonical_env
  on.exit(reader_env$.ucl_out_canonical_env<-saved,add=TRUE)
  reader_env$.ucl_out_canonical_env<-new.env(parent=baseenv())
  expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"canonical_runtime_unavailable")
  expect_false(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$production_eligible)
})
