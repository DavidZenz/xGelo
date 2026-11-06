library(testthat)
producer_root<-Sys.getenv("XGELO_CL9_READER_PROJECT",unset="")
if(!nzchar(producer_root)){
  producer_root<-normalizePath(getwd(),mustWork=TRUE)
  while(!file.exists(file.path(producer_root,"R/competition/ucl_live_outcome_reader.R"))){
    parent<-dirname(producer_root);if(identical(parent,producer_root))stop("CL producer test root missing");producer_root<-parent
  }
}
if(!nzchar(Sys.getenv("XGELO_PROJECT_ROOT")))Sys.setenv(XGELO_PROJECT_ROOT=producer_root)
Sys.setenv(XGELO_CL9_READER_PROJECT=producer_root)
sys.source(file.path(producer_root,"tests/testthat/ucl_live_outcome_reader_fixture_helper.R"),envir=environment())

producer_with_actual_writer<-function(code){
  scope<-environment(reader_write_fixture);saved<-get("reader_lossless_fixture_tables",envir=scope)
  on.exit(assign("reader_lossless_fixture_tables",saved,envir=scope),add=TRUE)
  assign("reader_lossless_fixture_tables",function(tables,directory)reader_env$.ucl_live_write_tables(tables,directory),envir=scope)
  force(code)
}
producer_actual_final_paths<-function(t){
  e<-t$future_knockout_events[t$future_knockout_events$stage_id=="final",]
  row<-data.frame(stage_id="final",home_club_id=e$participant_a,away_club_id=e$participant_b,neutral=TRUE,
    venue_id="fixture-neutral",regulation_home_goals=2L,regulation_away_goals=0L,stringsAsFactors=FALSE)
  meta<-t$simulation_metadata
  resolution<-reader_env$ucl_resolve_final(row,list(final_policy="single_neutral_match_extra_time_then_penalties",ruleset_sha256=meta$ruleset_sha256))
  for(stage in c("final","champion")){
    result<-reader_env$.ucl_record_stage_event(resolution,stage,stage,seed_slot_id=stage,draw_policy_id=meta$draw_policy_id,
      draw_artifact_id=meta$draw_artifact_id,draw_artifact_sha256=meta$draw_artifact_sha256,source_artifact_ids="fixture-only",
      source_bundle_id=meta$source_bundle_id,simulation_run_id=meta$run_id)
    result$row_sha256<-"";t$knockout_paths[t$knockout_paths$stage_id==stage,]<-result[,names(t$knockout_paths),drop=FALSE]
  };t
}

test_that("versioned hex encoding restores exact IEEE bits typed nulls and text",{
  values<-c(117.14285714285711,2.7755575615628914e-16,5.5511151231257827e-17,2.1094237467877974e-15,
    0,-0,.Machine$double.xmin,2^-1074,-2^-1074,2^-1073,.Machine$double.xmin-2^-1074,.Machine$double.xmax,NA_real_)
  n<-length(values);table<-data.frame(fixture_id=paste0("fixture-",seq_len(n)),value=values,
    count=rep(c(1L,NA_integer_),length.out=n),flag=rep(c(TRUE,FALSE,NA),length.out=n),
    label=rep(c("",NA_character_,"quote\"comma,","line\nbreak","České"),length.out=n),stringsAsFactors=FALSE)
  directory<-tempfile("producer-bits-");dir.create(directory)
  descriptor<-reader_env$.ucl_live_write_tables(list(bits=table),directory)$bits
  restored<-reader_env$.ucl_read_typed(file.path(directory,"bits.csv"),descriptor)
  expect_identical(restored,table)
  expect_identical(writeBin(restored$value,raw(),size=8L,endian="big"),writeBin(values,raw(),size=8L,endian="big"))
  expect_identical(reader_env$.ucl_live_csv_encoding_version,"ucl-typed-csv-hex-double-v1")
  raw<-utils::read.csv(file.path(directory,"bits.csv"),colClasses="character",na.strings=NULL)
  expect_true(all(grepl("^-?0x",raw$value[!is.na(values)])))
  expect_identical(names(descriptor),c("path","sha256","canonical_sha256","rows","column_types_json","null_rows_json"))
  first<-descriptor$sha256;again<-reader_env$.ucl_live_write_tables(list(bits=table),directory)$bits
  expect_identical(first,again$sha256)
})

test_that("actual uncertainty and future provenance pass strict canonical readback",{
  directory<-tempfile("producer-actual-values-");dir.create(directory)
  tables<-reader_fixture_tables$extras[c("monte_carlo_uncertainty","future_matchup_provenance")]
  files<-reader_env$.ucl_live_write_tables(tables,directory)
  for(name in names(files)){
    restored<-reader_env$.ucl_read_typed(file.path(directory,files[[name]]$path),files[[name]])
    expect_identical(restored,tables[[name]])
    expect_identical(reader_env$.ucl_out_artifact_hash(restored),reader_env$.ucl_out_artifact_hash(tables[[name]]))
  }
})

test_that("zero-row tables retain their exact declared types",{
  table<-data.frame(fixture_id=character(),d=double(),i=integer(),flag=logical(),stringsAsFactors=FALSE)
  directory<-tempfile("producer-empty-");dir.create(directory)
  descriptor<-reader_env$.ucl_live_write_tables(list(empty=table),directory)$empty
  restored<-reader_env$.ucl_read_typed(file.path(directory,"empty.csv"),descriptor)
  expect_identical(restored,table)
})

test_that("nonfinite and unsupported durable values fail closed",{
  directory<-tempfile("producer-invalid-");dir.create(directory)
  for(value in list(NaN,Inf,-Inf))expect_error(reader_env$.ucl_live_write_tables(list(invalid=data.frame(fixture_id="fixture-a",value=value)),directory),"finite or explicit NA")
  expect_error(reader_env$.ucl_live_write_tables(list(invalid=data.frame(fixture_id="fixture-a",value=factor("x"))),directory),"Unsupported CL durable table type")
  expect_error(reader_env$.ucl_live_write_tables(list(invalid=data.frame(fixture_id="fixture-a",value=as.Date("2026-11-05"))),directory),"Unsupported CL durable table type")
})

test_that("actual final and champion records share regulation ET and penalty semantics",{
  for(mode in c("regulation","extra_time","penalties")){
    row<-data.frame(stage_id="final",home_club_id="club_fixture_a",away_club_id="club_fixture_b",neutral=TRUE,
      venue_id="fixture-neutral",regulation_home_goals=if(mode=="regulation")2L else 1L,regulation_away_goals=if(mode=="regulation")0L else 1L)
    if(mode!="regulation"){row$extra_time_home_goals<-1L;row$extra_time_away_goals<-if(mode=="penalties")1L else 0L}
    resolution<-reader_env$ucl_resolve_final(row,list(final_policy="single_neutral_match_extra_time_then_penalties",ruleset_sha256=strrep("a",64)),
      penalty_winner=if(mode=="penalties")"club_fixture_a"else NULL)
    final<-reader_env$.ucl_record_stage_event(resolution,"final","final");champion<-reader_env$.ucl_record_stage_event(resolution,"champion","champion")
    fields<-setdiff(names(final),c("path_id","stage_event_id","stage_id"))
    expect_identical(final[,fields,drop=FALSE],champion[,fields,drop=FALSE])
    expect_identical(champion$leg_order,"single_neutral");expect_true(is.na(champion$leg_2_venue_id))
    expect_identical(resolution$resolution,mode);expect_identical(resolution$winner,"club_fixture_a")
    if(mode=="penalties")expect_true(all(is.na(c(champion$penalty_home,champion$penalty_away))))
  }
})

test_that("two-leg stage records retain explicit home and return-leg context",{
  resolution<-list(status="resolved",participant_a="club_fixture_a",participant_b="club_fixture_b",leg_order="seeded_return_leg",
    leg_1_venue_id="fixture-b-home",leg_2_venue_id="fixture-a-home",aggregate_regulation_home=3L,aggregate_regulation_away=2L,
    aggregate_final_home=3L,aggregate_final_away=2L,extra_time_applied=FALSE,penalty_applied=FALSE)
  for(stage in c("knockout_play_off","round_of_16","quarter_final","semi_final")){
    result<-reader_env$.ucl_record_stage_event(resolution,stage,"fixture-node")
    expect_identical(result$leg_order,"seeded_return_leg")
    expect_identical(result$leg_1_venue_id,"fixture-b-home");expect_identical(result$leg_2_venue_id,"fixture-a-home")
  }
})

test_that("actual table writer and final recorder feed the sealed17-table reader",{
  producer_with_actual_writer({
    f<-reader_write_fixture(mutate=producer_actual_final_paths)
    out<-reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)
    expect_identical(out$status,"mechanics_valid",info=out$reason_code)
    expect_false(out$production_eligible);expect_true(out$fixture_authority)
    expect_false(reader_env$ucl_validate_live_outcomes_read_result(out))
    expect_identical(out$tables$future_matchup_provenance,f$tables$future_matchup_provenance)
    expect_identical(out$tables$monte_carlo_uncertainty,f$tables$monte_carlo_uncertainty)
    expected_paths<-f$tables$knockout_paths;rownames(expected_paths)<-NULL
    # CSV deliberately omits R-only row names; every column/type/value remains exact.
    expect_identical(out$tables$knockout_paths,expected_paths)
  })
})

test_that("actual writer roundtrip never bypasses byte or semantic corruption",{
  producer_with_actual_writer({
    f<-reader_write_fixture(mutate=producer_actual_final_paths);cat("\n",file=file.path(f$generation,"future_matchup_provenance.csv"),append=TRUE)
    expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"table_bytes_changed")
    f<-reader_write_fixture(mutate=function(t){t<-producer_actual_final_paths(t);t$knockout_paths$leg_2_venue_id[t$knockout_paths$stage_id=="champion"]<-"invented-second-final";t})
    expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"representative_champion_mismatch")
    f<-reader_write_fixture(mutate=function(t){t<-producer_actual_final_paths(t);t$monte_carlo_uncertainty$mc95_upper[1]<-.2;t})
    expect_identical(reader_env$ucl_read_live_outcomes_fixture(f$root,reader_fixture_time)$reason_code,"uncertainty_mismatch")
  })
})
