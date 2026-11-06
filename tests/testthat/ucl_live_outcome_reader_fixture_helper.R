reader_main<-normalizePath(Sys.getenv("XGELO_PROJECT_ROOT"),mustWork=TRUE)
reader_private<-normalizePath(Sys.getenv("XGELO_CL9_READER_PROJECT"),mustWork=TRUE)
reader_env<-new.env(parent=baseenv());reader_env$setNames<-stats::setNames
for(path in c("R/common/phase18_canonical_hash.R","R/competition/source_contracts.R","R/competition/ucl_source_bundle.R",
 "R/competition/uefa_champions_league_simulation.R","R/competition/ucl_joint_score_view.R",
 "R/competition/uefa_champions_league_outcomes.R","R/competition/ucl_live_outcomes.R","R/competition/ucl_future_matchups.R"))
 sys.source(file.path(reader_main,path),envir=reader_env)
sys.source(file.path(reader_private,"R/competition/ucl_live_outcome_reader.R"),envir=reader_env)
reader_bound_root<-tempfile("reader-bound-runtime-");dir.create(reader_bound_root);reader_bound_root<-normalizePath(reader_bound_root,mustWork=TRUE)
reader_env$.phase19_club_project_root<-reader_bound_root
reader_evidence_root<-Sys.getenv("XGELO_CL9_READER_EVIDENCE",unset=tempfile("reader-evidence-"));dir.create(reader_evidence_root,recursive=TRUE,showWarnings=FALSE)
reader_fixture_time<-"2026-11-05T23:00:00Z"
reader_fixture_tables<-local({
  e<-reader_env;clubs<-sprintf("club_fixture_%02d",1:36);source<-"fixture-declared-league";run<-paste0("ucl-full-",strrep("1",32))
  policy<-strrep("d",64);rules<-list(edition_id="ucl_2026_27",ruleset_version="fixture-rules",ruleset_sha256=strrep("e",64),draw_policy_id="ucl-annex-b-unconditioned-orientation-prior-v1")
  row<-0:143;home<-clubs[row%%36+1L];away<-clubs[(row%%36+row%/%36+1L)%%36+1L]
  fixtures<-data.frame(edition_id="ucl_2026_27",fixture_id=paste0("fixture-",1:144),matchday=rep(1:8,each=18),
    home_club_id=home,away_club_id=away,venue_id=paste0("fixture-home:",home),kickoff_utc="2026-12-15T20:00:00Z",match_status="scheduled",
    regulation_home_goals=NA_integer_,regulation_away_goals=NA_integer_,final_home_goals=NA_integer_,final_away_goals=NA_integer_,
    shootout_home_goals=NA_integer_,shootout_away_goals=NA_integer_,source_bundle_id=source,source_row_sha256=strrep("a",64),stringsAsFactors=FALSE)
  graph<-list(edition_id="ucl_2026_27",clubs=data.frame(club_id=clubs),fixtures=fixtures,source_bundle_id=source)
  rankings<-data.frame(club_id=clubs,rank=1:36,rank_interval_min=1:36,rank_interval_max=1:36,rank_status="resolved",
    qualification_band=ifelse(1:36<=8,"direct_round_of_16",ifelse(1:36<=24,"knockout_play_off","eliminated")),stringsAsFactors=FALSE)
  standing<-data.frame(team_id=clubs,played=0L,wins=0L,draws=0L,losses=0L,goals_for=0L,goals_against=0L,goal_difference=0L,points=0L)
  state<-list(edition_id="ucl_2026_27",source_bundle_id=source,universal_standings=standing,standings=rankings)
  context<-e$ucl_future_fixture_context(c("(Intercept)"=log(1.1),elo_difference_for_team=.0015,venue_rolehome=log(1.25)),3,
    stats::setNames(seq(1600,1400,length.out=36),clubs),temperature=1.2,primary_probability_view="calibrated_1x2",information_cutoff_utc=reader_fixture_time)
  context$source_bundle_sha256<-strrep("c",64)
  # Use the normal fixture constructor's genuine content hash/lineage, not fake
  # production metadata. All outcomes below are declared, never sampled.
  context$context_sha256<-e$.ucl_future_hash(e$.ucl_future_payload(context),"ucl-future-context-v1")
  release<-context$model_release_id;model<-context$model_sha256;calibrator<-context$calibrator_sha256
  slots<-list();days<-c(knockout_play_off=30,round_of_16=60,quarter_final=90,semi_final=120,final=150)
  for(stage in names(days))for(leg in if(stage=="final")1L else 1:2){
    at<-format(as.POSIXct(reader_fixture_time,tz="UTC")+86400*(days[[stage]]+7*(leg-1)),"%Y-%m-%dT%H:%M:%SZ",tz="UTC")
    id<-paste0(stage,"_",leg);slots[[id]]<-e$ucl_future_fixture_slot(id,stage,leg,at,stage=="final",evidence_available_at_utc=reader_fixture_time)
  }
  nodes<-e$.ucl_future_template_nodes(rep(0L,12L));known<-list();seed_rank<-list();events<-list();paths<-list();provenance<-list();seed<-15017L
  resolve<-function(ref){if(startsWith(ref,"rank:")){rank<-as.integer(sub("rank:","",ref));return(list(club=clubs[[rank]],seed=rank))};id<-sub("winner:","",ref);list(club=known[[id]],seed=seed_rank[[id]])}
  for(i in seq_len(nrow(nodes))){
    node<-nodes[i,];a<-resolve(node$ref_a);b<-resolve(node$ref_b);final<-node$stage_id=="final"
    if(!final&&a$seed>b$seed){swap<-a;a<-b;b<-swap}
    known[[node$node_id]]<-a$club;seed_rank[[node$node_id]]<-min(a$seed,b$seed)
    events[[i]]<-data.frame(iteration=1L,node_id=node$node_id,stage_id=node$stage_id,participant_a=a$club,participant_b=b$club,
      inherited_seed_a=as.integer(a$seed),inherited_seed_b=as.integer(b$seed),winner=a$club,loser=b$club,inherited_winner_seed=as.integer(min(a$seed,b$seed)),
      resolution=if(final)"regulation"else"aggregate",extra_time_applied=FALSE,penalty_applied=FALSE,
      seed=e$.ucl_future_child_seed(seed,1L,node$node_id),stage_event_id=paste0("conditional-iteration-1:",node$node_id),stringsAsFactors=FALSE)
    resolution<-list(status="resolved",participant_a=a$club,participant_b=b$club,winner=a$club,loser=b$club,
      aggregate_regulation_home=if(final)2L else 3L,aggregate_regulation_away=0L,aggregate_final_home=if(final)2L else 3L,aggregate_final_away=0L,
      extra_time_applied=FALSE,penalty_applied=FALSE,leg_order=if(final)"single_neutral"else"seeded_return_leg",
      leg_1_venue_id=if(final)"fixture-neutral"else paste0("fixture-home:",b$club),leg_2_venue_id=if(final)NA_character_ else paste0("fixture-home:",a$club),ruleset_sha256=rules$ruleset_sha256)
    paths[[i]]<-e$.ucl_record_stage_event(resolution,node$stage_id,node$node_id,seed_slot_id=node$node_id,draw_policy_id=rules$draw_policy_id,
      draw_artifact_id="fixture-prior",draw_artifact_sha256=policy,source_artifact_ids="fixture-only",source_bundle_id=source,simulation_run_id=run)
    query<-function(home,away,leg){f<-e$ucl_future_forecast_matchup(context,home,away,slots[[paste0(node$stage_id,"_",leg)]]);as.data.frame(f$metadata,stringsAsFactors=FALSE)}
    if(!final)provenance[[length(provenance)+1L]]<-query(b$club,a$club,1L)
    provenance[[length(provenance)+1L]]<-query(a$club,b$club,if(final)1L else 2L)
  }
  finalpath<-paths[[length(paths)]];finalpath$stage_id<-"champion";finalpath$path_id<-finalpath$stage_event_id<-finalpath$seed_slot_id<-"champion";paths[[24L]]<-finalpath
  eventtable<-do.call(rbind,events);provenance<-do.call(rbind,provenance)
  provenance$iteration<-1L;provenance$fixture_id<-paste0("conditional-simulation-1-query-",seq_len(nrow(provenance)));provenance$is_official_fixture<-FALSE
  ranks<-data.frame(run_id=run,iteration=1L,edition_id="ucl_2026_27",club_id=clubs,rank=1:36,rank_interval_min=1:36,rank_interval_max=1:36,
    rank_status="resolved",qualification_band=rankings$qualification_band,missing_criterion_id=NA_character_,ranking_scope="counterfactual_complete_league",
    observed_source_eligible=FALSE,training_eligible=FALSE,article18_score_metrics_sha256=strrep("b",64),stringsAsFactors=FALSE)
  stages<-c("direct_round_of_16","knockout_play_off","eliminated","round_of_16","quarter_final","semi_final","final","champion")
  progression<-do.call(rbind,lapply(clubs,function(club){
    rank<-match(club,clubs);band<-c(rank<=8,rank%in%9:24,rank>=25)
    later<-vapply(stages[4:7],function(stage)club%in%c(eventtable$participant_a[eventtable$stage_id==stage],eventtable$participant_b[eventtable$stage_id==stage]),logical(1))
    data.frame(edition_id="ucl_2026_27",club_id=club,stage_id=stages,probability=as.numeric(c(band,later,club==known$final)),status="resolved",
      source_bundle_id=source,ruleset_sha256=rules$ruleset_sha256,draw_artifact_sha256=policy,simulation_count=1L,seed=seed,run_id=run,row_sha256="",stringsAsFactors=FALSE)
  }))
  ledger<-data.frame(edition_id="ucl_2026_27",fixture_id=fixtures$fixture_id,home_club_id=home,away_club_id=away,kickoff_utc=fixtures$kickoff_utc,
    forecast_status="available",suppression_reason=NA_character_,model_release_id=release,model_sha256=model,calibrator_sha256=calibrator,
    feature_cutoff_utc=reader_fixture_time,prob_home=.5,prob_draw=.25,prob_away=.25,xg_home=1.5,xg_away=1.1,likely_score="1-0",source_bundle_id=source,row_sha256="",stringsAsFactors=FALSE)
  raw<-expand.grid(home_goals=0:40,away_goals=0:40);raw$probability<-1/nrow(raw)
  joint<-e$ucl_tournament_score_view(raw,c(.5,.25,.25),ledger$fixture_id[[1L]],release,"calibrated_1x2",strrep("a",64))$provenance
  joints<-joint[rep(1L,144L),];joints$fixture_id<-ledger$fixture_id
  joints$view_sha256<-vapply(seq_len(144L),function(i)e$phase18_hash_row_v2(joints[i,setdiff(names(joints),"view_sha256"),drop=FALSE],schema_tag="ucl-tournament-joint-view-v1"),character(1))
  meta<-data.frame(run_id=run,edition_id="ucl_2026_27",source_bundle_id=source,ruleset_version=rules$ruleset_version,ruleset_sha256=rules$ruleset_sha256,
    model_release_id=release,model_sha256=model,calibrator_sha256=calibrator,draw_policy_id=rules$draw_policy_id,draw_artifact_id="fixture-prior",draw_artifact_sha256=policy,
    information_cutoff_utc=reader_fixture_time,algorithm_version="ucl-league-plus-dynamic-knockout-v1",simulation_count=1L,seed=seed,
    path_policy_id=rules$draw_policy_id,path_policy_count=16L,authority_mode="fixture",production_eligible=FALSE,status="ready",run_sha256="",stringsAsFactors=FALSE)
  simulation<-list(knockout_paths=do.call(rbind,paths),run_id=run,metadata=list(source_bundle_id=source))
  base<-list(competition_topology=e$.ucl_out_topology(graph,rules),league_schedule=e$.ucl_out_schedule(graph),tie_break_trace=e$.ucl_out_empty(e$.ucl_out_schemas$tie_break_trace),
    projected_standings=e$.ucl_out_standings(state,rules),projected_rankings=e$.ucl_out_rankings(state,rules),knockout_paths=e$.ucl_out_paths(simulation,rules),
    progression_probabilities=progression,fixture_forecast_ledger=ledger,simulation_metadata=meta)
  extras<-list(joint_score_views=joints,monte_carlo_uncertainty=e$ucl_live_monte_carlo_uncertainty(progression),future_knockout_events=eventtable,
    future_matchup_provenance=provenance,league_rank_inputs=ranks,late_tie_prior_samples=e$.ucl_future_empty_prior_samples(),
    late_tie_prior_contribution=e$ucl_future_prior_contribution(e$.ucl_future_empty_prior_samples(),clubs,1L))
  list(base=base,extras=extras,graph=graph,context=context,policy=policy,slots=slots)
})
reader_baseline_writer_diagnostic<-local({
  results<-lapply(c("monte_carlo_uncertainty","future_matchup_provenance"),function(name){
    directory<-tempfile("original-writer-");dir.create(directory)
    value<-reader_fixture_tables$extras[[name]]
    observed<-tryCatch({reader_env$.ucl_live_write_tables(stats::setNames(list(value),name),directory);"passed"},error=function(e)conditionMessage(e))
    restored<-reader_env$phase18_ucl_read_typed_csv(file.path(directory,paste0(name,".csv")),reader_env$phase18_ucl_column_types_json(value),reader_env$phase18_ucl_null_rows_json(value))
    changed<-names(value)[!vapply(names(value),function(field)identical(value[[field]],restored[[field]]),logical(1))]
    list(table=name,status=observed,changed_double_columns=changed,original_canonical_sha256=reader_env$.ucl_out_artifact_hash(value),restored_canonical_sha256=reader_env$.ucl_out_artifact_hash(restored))
  })
  jsonlite::write_json(results,file.path(reader_evidence_root,"original_writer_roundtrip_diagnostic.json"),auto_unbox=TRUE,pretty=TRUE)
  results
})
reader_row_cache<-new.env(parent=emptyenv())
reader_storage_cache<-new.env(parent=emptyenv())
reader_lossless_fixture_tables<-function(tables,directory){
  result<-lapply(names(tables),function(name){
    table<-tables[[name]];key<-digest::digest(table,algo="sha256");path<-file.path(directory,paste0(name,".csv"))
    if(!exists(key,envir=reader_storage_cache,inherits=FALSE)){
      encoded<-as.data.frame(lapply(table,function(column){
        value<-if(is.double(column))sprintf("%a",column)else as.character(column)
        value[is.na(column)]<-"";value
      }),stringsAsFactors=FALSE,check.names=FALSE)
      utils::write.csv(encoded,path,row.names=FALSE,quote=TRUE,na="")
      descriptor<-list(path=basename(path),sha256=reader_env$.ucl_read_sha(path),canonical_sha256=reader_env$.ucl_out_artifact_hash(table),rows=nrow(table),
        column_types_json=reader_env$phase18_ucl_column_types_json(table),null_rows_json=reader_env$phase18_ucl_null_rows_json(table))
      restored<-reader_env$phase18_ucl_read_typed_csv(path,descriptor$column_types_json,descriptor$null_rows_json)
      if(!identical(reader_env$.ucl_out_artifact_hash(restored),descriptor$canonical_sha256)){
        changed<-names(table)[!vapply(names(table),function(field)identical(table[[field]],restored[[field]]),logical(1))]
        proof<-lapply(changed,function(field){
          x<-table[[field]];y<-restored[[field]];at<-which(x!=y)[1L]
          list(field=field,original_class=class(x),restored_class=class(y),original_names=names(x),restored_names=names(y),row=at,
            decimal=if(is.numeric(x))sprintf("%.17g",x[at])else NULL,
            restored_decimal=if(is.numeric(y))sprintf("%.17g",y[at])else NULL,
            hex=if(is.numeric(x))sprintf("%a",x[at])else NULL,
            direct_decimal_roundtrip=if(is.numeric(x))identical(as.double(sprintf("%.17g",x)),x)else NULL,
            direct_hex_roundtrip=if(is.numeric(x))identical(as.double(sprintf("%a",x)),x)else NULL)
        })
        jsonlite::write_json(proof,file.path(reader_evidence_root,"lossless_format_probe.json"),auto_unbox=TRUE,pretty=TRUE)
        stop(paste("Lossless fixture readback",name,"changed",paste(changed,collapse=",")),call.=FALSE)
      }
      raw<-readBin(path,"raw",n=file.info(path)$size);assign(key,list(raw=raw,descriptor=descriptor),envir=reader_storage_cache)
    } else {
      cached<-get(key,envir=reader_storage_cache,inherits=FALSE);writeBin(cached$raw,path)
      descriptor<-cached$descriptor;descriptor$path<-basename(path)
    }
    descriptor
  });names(result)<-names(tables);result
}
reader_rehash<-function(tables){
  for(name in setdiff(reader_env$.ucl_out_inventory,c("simulation_metadata","outcomes_manifest"))){
    table<-tables[[name]];key<-digest::digest(table,algo="sha256")
    if(exists(key,envir=reader_row_cache,inherits=FALSE))table<-get(key,envir=reader_row_cache,inherits=FALSE)else{
      table$row_sha256<-vapply(seq_len(nrow(table)),function(i)reader_env$.ucl_out_canonical_hash(table[i,setdiff(names(table),"row_sha256"),drop=FALSE]),character(1))
      assign(key,table,envir=reader_row_cache)
    };tables[[name]]<-table
  }
  meta<-tables$simulation_metadata;meta$run_sha256<-reader_env$.ucl_out_canonical_hash(meta[,setdiff(names(meta),"run_sha256"),drop=FALSE]);tables$simulation_metadata<-meta
  tables$outcomes_manifest<-reader_env$.ucl_out_build_manifest(tables,reader_fixture_tables$graph,NULL,meta,
    fixture_authority=!isTRUE(meta$production_eligible),production_eligible=isTRUE(meta$production_eligible))
  tables
}
reader_write_fixture<-function(root=tempfile("reader-fixture-"),mutate=NULL){
  dir.create(root,recursive=TRUE,showWarnings=FALSE);stage<-file.path(root,"stage");dir.create(stage)
  tables<-c(reader_fixture_tables$base,list(outcomes_manifest=data.frame()),reader_fixture_tables$extras)
  if(!is.null(mutate))tables<-mutate(tables)
  tables<-reader_rehash(tables)
  # Fixture-only serializer demonstrates the existing declared CSV contract
  # without weakening exact IEEE canonical hashes. Main writer is unchanged.
  files<-reader_lossless_fixture_tables(tables,stage);meta<-tables$simulation_metadata
  manifest<-list(schema_version="ucl-live-production-publication-v1",edition_id="ucl_2026_27",simulation_run_id=meta$run_id,
    source_bundle_sha256=reader_fixture_tables$context$source_bundle_sha256,model_release_id=meta$model_release_id,model_sha256=meta$model_sha256,
    calibrator_sha256=meta$calibrator_sha256,information_cutoff_utc=reader_fixture_time,sampler_view="ucl-outcome-conditional-nb-v1",
    forecast_scope="unconditioned_regulations_prior",assumptions_policy_id="ucl-conditional-tournament-forecast-v1",assumptions_policy_sha256=reader_fixture_tables$policy,
    model_uncertainty_included=FALSE,production_eligible=isTRUE(meta$production_eligible),files=files)
  jsonlite::write_json(manifest,file.path(stage,"publication_manifest.json"),auto_unbox=TRUE,null="null",pretty=TRUE)
  hash<-reader_env$.ucl_read_sha(file.path(stage,"publication_manifest.json"));generation<-paste0("ucl-live-",substr(hash,1L,24L))
  dir.create(file.path(root,"outcome_generations"));destination<-file.path(root,"outcome_generations",generation);stopifnot(file.rename(stage,destination))
  pointer<-list(schema_version="ucl-live-outcomes-current-v1",edition_id="ucl_2026_27",generation=generation,publication_manifest_sha256=hash,
    simulation_run_id=meta$run_id,source_bundle_sha256=manifest$source_bundle_sha256,model_release_id=meta$model_release_id,information_cutoff_utc=reader_fixture_time)
  jsonlite::write_json(pointer,file.path(root,"outcomes_current.json"),auto_unbox=TRUE,pretty=TRUE)
  list(root=root,generation=destination,tables=tables,pointer=pointer,manifest=manifest)
}
reader_declared_final_extra_time<-function(t,penalties=FALSE){
  at<-which(t$future_knockout_events$stage_id=="final");e<-t$future_knockout_events[at,]
  t$future_knockout_events$extra_time_applied[at]<-TRUE;t$future_knockout_events$penalty_applied[at]<-penalties
  t$future_knockout_events$resolution[at]<-if(penalties)"penalties"else"extra_time"
  at<-which(t$knockout_paths$stage_id%in%c("final","champion"))
  t$knockout_paths$aggregate_regulation_home[at]<-1L;t$knockout_paths$aggregate_regulation_away[at]<-1L
  t$knockout_paths$extra_time_home[at]<-1L;t$knockout_paths$extra_time_away[at]<-if(penalties)1L else 0L
  t$knockout_paths$aggregate_final_home[at]<-2L;t$knockout_paths$aggregate_final_away[at]<-if(penalties)2L else 1L
  t$knockout_paths$extra_time_applied[at]<-TRUE;t$knockout_paths$penalty_applied[at]<-penalties
  f<-reader_env$ucl_future_forecast_matchup(reader_fixture_tables$context,e$participant_a,e$participant_b,reader_fixture_tables$slots$final_1,30L)
  row<-as.data.frame(f$metadata,stringsAsFactors=FALSE);row$iteration<-1L;row$fixture_id<-"conditional-simulation-1-query-46";row$is_official_fixture<-FALSE
  t$future_matchup_provenance<-rbind(t$future_matchup_provenance,row);t
}
reader_declared_late_prior<-function(t){
  clubs<-reader_fixture_tables$graph$clubs$club_id[35:36];at<-match(clubs,t$league_rank_inputs$club_id)
  t$league_rank_inputs$rank_interval_min[at]<-35L;t$league_rank_inputs$rank_interval_max[at]<-36L
  t$league_rank_inputs$rank_status[at]<-"scenario_prior_order_not_official_rank";t$league_rank_inputs$missing_criterion_id[at]<-"disciplinary_points"
  t$late_tie_prior_samples<-data.frame(iteration=1L,club_id=clubs,rank_interval_min=35L,rank_interval_max=36L,disciplinary_scenario_order=1L,
    known_club_coefficient=c(10,9),coefficient_tiebreak_used=TRUE,scenario_rank=35:36,policy="exchangeable_final_disciplinary_weak_order_v1",factual_rank_claimed=FALSE,stringsAsFactors=FALSE)
  t$late_tie_prior_contribution<-reader_env$ucl_future_prior_contribution(t$late_tie_prior_samples,reader_fixture_tables$graph$clubs$club_id,1L);t
}
