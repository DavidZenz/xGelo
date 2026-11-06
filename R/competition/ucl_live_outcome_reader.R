# Fixed-path read-only CL publication consumer. File flags are integrity data,
# never authority. Only the fixed entry point can issue an in-process receipt
# after independently resolving genuine current parents and approved code.
.ucl_read_authority <- local(list(token=new.env(parent=emptyenv())))
.ucl_read_abort <- function(reason) stop(structure(list(message=reason,call=NULL,reason_code=reason),
  class=c("ucl_live_outcome_read_error","error","condition")))
.ucl_read_need <- function(ok,reason) if(!isTRUE(ok)).ucl_read_abort(reason)
.ucl_read_sha <- function(path)digest::digest(file=path,algo="sha256",serialize=FALSE)
.ucl_read_scalar <- function(x) is.character(x)&&length(x)==1L&&!is.na(x)&&nzchar(x)
.ucl_read_hash <- function(x).ucl_read_scalar(x)&&grepl("^[0-9a-f]{64}$",x)
.ucl_read_project_root <- function() {
  scope<-environment(.ucl_read_project_root)
  .ucl_read_need(exists(".phase19_club_project_root",envir=scope,inherits=FALSE),"runtime_root_not_bound")
  root<-get(".phase19_club_project_root",envir=scope,inherits=FALSE)
  .ucl_read_need(.ucl_read_scalar(root)&&dir.exists(root),"runtime_root_not_bound")
  normalizePath(root,winslash="/",mustWork=TRUE)
}
.ucl_read_time <- function(x) {
  .ucl_read_need(.ucl_read_scalar(x)&&grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$",x),"cutoff_invalid")
  value<-as.numeric(as.POSIXct(x,format="%Y-%m-%dT%H:%M:%SZ",tz="UTC"))
  .ucl_read_need(is.finite(value),"cutoff_invalid");value
}
.ucl_read_now <- function(now) {
  if(is.null(now))now<-format(Sys.time(),"%Y-%m-%dT%H:%M:%SZ",tz="UTC")
  .ucl_read_need(.ucl_read_time(now)<=as.numeric(Sys.time())+60,"cutoff_in_future");now
}
.ucl_read_safe <- function(path,root,kind="file") {
  root<-normalizePath(root,winslash="/",mustWork=TRUE)
  cursor<-path
  repeat {
    link<-Sys.readlink(cursor)
    .ucl_read_need(length(link)==1L&&!is.na(link)&&!nzchar(link),"unsafe_publication_path")
    if(identical(normalizePath(cursor,winslash="/",mustWork=FALSE),root))break
    parent<-dirname(cursor);.ucl_read_need(!identical(parent,cursor),"unsafe_publication_path");cursor<-parent
  }
  value<-normalizePath(path,winslash="/",mustWork=TRUE)
  .ucl_read_need(startsWith(value,paste0(root,"/"))||identical(value,root),"unsafe_publication_path")
  .ucl_read_need(if(kind=="directory")dir.exists(value)else file.exists(value)&&!dir.exists(value),"publication_file_missing")
  value
}
.ucl_read_inventory <- function()c(.ucl_out_inventory,"joint_score_views","monte_carlo_uncertainty",
  "future_knockout_events","future_matchup_provenance","league_rank_inputs","late_tie_prior_samples","late_tie_prior_contribution")
.ucl_read_extra_schemas <- function()list(
  joint_score_views=c("view_version","grid_encoding","fixture_id","model_release_id","primary_probability_view","source_score_distribution_sha256","raw_grid_canonical_sha256","joint_grid_sha256","primary_home","primary_draw","primary_away","raw_home","raw_draw","raw_away","max_1x2_error","max_conditional_error","view_sha256"),
  monte_carlo_uncertainty=c("club_id","stage_id","probability","simulation_count","monte_carlo_se","mc95_lower","mc95_upper","interval_method","uncertainty_scope"),
  future_knockout_events=c("iteration","node_id","stage_id","participant_a","participant_b","inherited_seed_a","inherited_seed_b","winner","loser","inherited_winner_seed","resolution","extra_time_applied","penalty_applied","seed","stage_event_id"),
  future_matchup_provenance=c("context_sha256","home_club_id","away_club_id","slot_sha256","minutes","schema_version","forecast_domain","authority_mode","fixture_authority","model_release_id","model_sha256","calibrator_sha256","source_bundle_sha256","information_cutoff_utc","kickoff_lower_bound_utc","slot_id","stage_id","leg_number","venue_context","schedule_semantics","schedule_evidence_sha256","home_rating_state_sha256","rating_difference","neutral","neutral_policy","exposure_policy","matchup_id","joint_max_1x2_error","joint_max_conditional_error","primary_probability_view","raw_tail_mass","raw_grid_sha256","joint_view_sha256","forecast_sha256","iteration","fixture_id","is_official_fixture"),
  league_rank_inputs=c("run_id","iteration","edition_id","club_id","rank","rank_interval_min","rank_interval_max","rank_status","qualification_band","missing_criterion_id","ranking_scope","observed_source_eligible","training_eligible","article18_score_metrics_sha256"),
  late_tie_prior_samples=c("iteration","club_id","rank_interval_min","rank_interval_max","disciplinary_scenario_order","known_club_coefficient","coefficient_tiebreak_used","scenario_rank","policy","factual_rank_claimed"),
  late_tie_prior_contribution=c("club_id","simulation_count","prior_affected_iteration_count","prior_affected_club_iteration_count","all_stage_max_absolute_probability_change_bound","bound_scope","prior_policy","model_uncertainty_included"))
.ucl_read_typed <- function(path,descriptor) {
  .ucl_read_need(identical(names(descriptor),c("path","sha256","canonical_sha256","rows","column_types_json","null_rows_json")),"table_descriptor_invalid")
  .ucl_read_need(.ucl_read_hash(descriptor$sha256)&&.ucl_read_hash(descriptor$canonical_sha256)&&
    is.numeric(descriptor$rows)&&length(descriptor$rows)==1L&&is.finite(descriptor$rows)&&descriptor$rows>=0&&descriptor$rows==floor(descriptor$rows),"table_descriptor_invalid")
  .ucl_read_need(identical(.ucl_read_sha(path),descriptor$sha256),"table_bytes_changed")
  raw<-utils::read.csv(path,colClasses="character",na.strings=NULL,check.names=FALSE,stringsAsFactors=FALSE)
  types<-jsonlite::fromJSON(descriptor$column_types_json,simplifyVector=FALSE)
  nulls<-jsonlite::fromJSON(descriptor$null_rows_json,simplifyVector=FALSE)
  .ucl_read_need(!anyDuplicated(names(raw))&&identical(names(raw),names(types))&&identical(names(raw),names(nulls)),"typed_columns_invalid")
  for(name in names(raw)){
    type<-types[[name]];values<-raw[[name]];at<-unlist(nulls[[name]],use.names=FALSE)
    .ucl_read_need(.ucl_read_scalar(type)&&type%in%c("character","integer","double","logical"),"typed_columns_invalid")
    .ucl_read_need(!length(at)||(is.numeric(at)&&all(is.finite(at))&&all(at==floor(at)&at>=1&at<=nrow(raw))&&!anyDuplicated(at)),"null_rows_invalid")
    .ucl_read_need(!length(at)||all(values[at]==""),"null_rows_invalid")
    selected<-setdiff(seq_along(values),at);v<-values[selected]
    if(type=="integer").ucl_read_need(all(grepl("^-?(0|[1-9][0-9]*)$",v))&&all(is.finite(suppressWarnings(as.integer(v)))),"typed_integer_invalid")
    if(type=="double").ucl_read_need(all(nzchar(v))&&all(is.finite(suppressWarnings(as.double(v)))),"typed_double_invalid")
    if(type=="logical").ucl_read_need(all(v%in%c("TRUE","FALSE")),"typed_logical_invalid")
  }
  table<-phase18_ucl_read_typed_csv(path,descriptor$column_types_json,descriptor$null_rows_json)
  .ucl_read_need(nrow(table)==descriptor$rows&&identical(.ucl_out_artifact_hash(table),descriptor$canonical_sha256),"table_canonical_hash_changed")
  .ucl_read_need(identical(phase18_ucl_null_rows_json(table),descriptor$null_rows_json),"null_rows_invalid")
  table
}
.ucl_read_load <- function(root) {
  .ucl_read_need(is.environment(.ucl_out_canonical_env)&&
    exists("phase18_hash_table_v2",envir=.ucl_out_canonical_env,inherits=FALSE)&&
    is.function(get("phase18_hash_table_v2",envir=.ucl_out_canonical_env,inherits=FALSE)),"canonical_runtime_unavailable")
  .ucl_read_need(dir.exists(root),"publication_missing")
  .ucl_read_need(file.exists(file.path(root,"outcomes_current.json")),"publication_missing")
  path<-.ucl_read_safe(file.path(root,"outcomes_current.json"),root)
  pointer_sha256<-.ucl_read_sha(path)
  pointer<-jsonlite::read_json(path,simplifyVector=FALSE)
  .ucl_read_need(identical(names(pointer),c("schema_version","edition_id","generation","publication_manifest_sha256","simulation_run_id","source_bundle_sha256","model_release_id","information_cutoff_utc")),"pointer_schema_invalid")
  .ucl_read_need(identical(pointer$schema_version,"ucl-live-outcomes-current-v1")&&identical(pointer$edition_id,"ucl_2026_27"),"publication_domain_invalid")
  .ucl_read_need(.ucl_read_scalar(pointer$generation)&&grepl("^ucl-live-[0-9a-f]{24}$",pointer$generation)&&.ucl_read_hash(pointer$publication_manifest_sha256)&&
    identical(pointer$generation,paste0("ucl-live-",substr(pointer$publication_manifest_sha256,1L,24L))),"unsafe_generation_pointer")
  generation<-.ucl_read_safe(file.path(root,"outcome_generations",pointer$generation),root,"directory")
  manifest_path<-.ucl_read_safe(file.path(generation,"publication_manifest.json"),root)
  .ucl_read_need(identical(.ucl_read_sha(manifest_path),pointer$publication_manifest_sha256),"publication_manifest_changed")
  manifest<-jsonlite::read_json(manifest_path,simplifyVector=FALSE)
  fields<-c("schema_version","edition_id","simulation_run_id","source_bundle_sha256","model_release_id","model_sha256","calibrator_sha256","information_cutoff_utc","sampler_view","forecast_scope","assumptions_policy_id","assumptions_policy_sha256","model_uncertainty_included","production_eligible","files")
  .ucl_read_need(identical(names(manifest),fields)&&identical(manifest$schema_version,"ucl-live-production-publication-v1")&&identical(manifest$edition_id,"ucl_2026_27"),"publication_schema_invalid")
  for(name in c("simulation_run_id","source_bundle_sha256","model_release_id","information_cutoff_utc"))
    .ucl_read_need(identical(manifest[[name]],pointer[[name]]),"pointer_manifest_parent_mismatch")
  .ucl_read_need(all(vapply(manifest[c("source_bundle_sha256","model_sha256","calibrator_sha256","assumptions_policy_sha256")],.ucl_read_hash,logical(1)))&&
    .ucl_read_scalar(manifest$model_release_id)&&.ucl_read_scalar(manifest$simulation_run_id),"publication_lineage_invalid")
  .ucl_read_need(identical(manifest$sampler_view,"ucl-outcome-conditional-nb-v1")&&identical(manifest$forecast_scope,"unconditioned_regulations_prior")&&
    identical(manifest$assumptions_policy_id,"ucl-conditional-tournament-forecast-v1")&&identical(manifest$model_uncertainty_included,FALSE),"forecast_scope_unsupported")
  .ucl_read_need(setequal(names(manifest$files),.ucl_read_inventory())&&!anyDuplicated(names(manifest$files)),"publication_inventory_incomplete")
  expected<-c("publication_manifest.json",paste0(.ucl_read_inventory(),".csv"))
  .ucl_read_need(setequal(list.files(generation,all.files=TRUE,no..=TRUE),expected),"publication_inventory_changed")
  tables<-lapply(names(manifest$files),function(name){
    d<-manifest$files[[name]];.ucl_read_need(identical(d$path,paste0(name,".csv")),"unsafe_table_path")
    .ucl_read_typed(.ucl_read_safe(file.path(generation,d$path),root),d)
  });names(tables)<-names(manifest$files)
  .ucl_read_need(identical(.ucl_read_sha(path),pointer_sha256)&&identical(.ucl_read_sha(manifest_path),pointer$publication_manifest_sha256),"publication_changed_during_read")
  list(root=root,pointer=pointer,pointer_sha256=pointer_sha256,manifest=manifest,tables=tables,generation_root=generation)
}
.ucl_read_equal_table <- function(a,b,reason) .ucl_read_need(identical(.ucl_out_artifact_hash(a),.ucl_out_artifact_hash(b)),reason)
.ucl_read_event_counts <- function(tables,clubs,n,seed) {
  ranks<-tables$league_rank_inputs;events<-tables$future_knockout_events
  .ucl_read_need(nrow(ranks)==36*n&&setequal(ranks$iteration,seq_len(n))&&!anyDuplicated(paste(ranks$iteration,ranks$club_id)),"rank_inventory_invalid")
  .ucl_read_need(all(!ranks$observed_source_eligible&!ranks$training_eligible)&&all(ranks$ranking_scope=="counterfactual_complete_league"),"counterfactual_rank_authority_invalid")
  .ucl_read_need(nrow(events)==23*n&&setequal(events$iteration,seq_len(n))&&!anyDuplicated(events$stage_event_id)&&
    all(events$stage_event_id==paste0("conditional-iteration-",events$iteration,":",events$node_id)),"knockout_event_inventory_invalid")
  stages<-c("direct_round_of_16","knockout_play_off","eliminated","round_of_16","quarter_final","semi_final","final","champion")
  counts<-matrix(0L,36L,8L,dimnames=list(clubs,stages))
  rsplit<-split(seq_len(nrow(ranks)),ranks$iteration);esplit<-split(seq_len(nrow(events)),events$iteration)
  template<-.ucl_future_template_nodes(rep(0L,12L));family_a<-list(11:12,13:14,9:10,15:16);family_b<-list(21:22,19:20,23:24,17:18);top<-list(5:6,3:4,7:8,1:2)
  for(iteration in seq_len(n)){
    r<-ranks[rsplit[[as.character(iteration)]],,drop=FALSE];e<-events[esplit[[as.character(iteration)]],,drop=FALSE]
    .ucl_read_need(setequal(r$club_id,clubs)&&setequal(r$rank,1:36)&&!anyDuplicated(r$rank),"rank_permutation_invalid")
    bands<-ifelse(r$rank<=8L,"direct_round_of_16",ifelse(r$rank<=24L,"knockout_play_off","eliminated"))
    .ucl_read_need(identical(as.character(r$qualification_band),bands),"rank_band_mismatch")
    for(stage in stages[1:3])counts[r$club_id[bands==stage],stage]<-counts[r$club_id[bands==stage],stage]+1L
    .ucl_read_need(setequal(e$node_id,template$node_id)&&!anyDuplicated(e$node_id),"knockout_dag_incomplete")
    for(stage in unique(template$stage_id)){
      stage_rows<-e[e$stage_id==stage,,drop=FALSE];participants<-c(stage_rows$participant_a,stage_rows$participant_b)
      .ucl_read_need(!anyDuplicated(participants),"stage_participant_duplicated")
      if(stage=="knockout_play_off").ucl_read_need(setequal(participants,r$club_id[r$rank%in%9:24]),"playoff_participant_inventory_invalid")
    }
    winners<-list();inherited<-list();rank_of<-stats::setNames(r$rank,r$club_id)
    for(i in seq_len(nrow(template))){
      node<-template[i,];row<-e[match(node$node_id,e$node_id),,drop=FALSE]
      a<-as.character(row$participant_a);b<-as.character(row$participant_b)
      .ucl_read_need(row$stage_id==node$stage_id&&all(c(a,b,row$winner,row$loser)%in%clubs)&&a!=b&&
        row$winner%in%c(a,b)&&row$loser==setdiff(c(a,b),row$winner),"knockout_identity_invalid")
      if(node$stage_id=="knockout_play_off"){
        position<-as.integer(sub(".*-","",node$node_id))
        .ucl_read_need(rank_of[[a]]%in%family_a[[position]]&&rank_of[[b]]%in%family_b[[position]],"annex_b_family_invalid")
        seeds<-c(rank_of[[a]],rank_of[[b]])
      } else if(node$stage_id=="round_of_16"){
        position<-as.integer(sub(".*-","",node$node_id));parent<-paste0("po-",node$side,"-",position)
        .ucl_read_need(rank_of[[a]]%in%top[[position]]&&identical(b,winners[[parent]]),"annex_b_progression_invalid")
        seeds<-c(rank_of[[a]],inherited[[parent]])
      } else {
        parents<-sub("^winner:","",c(node$ref_a,node$ref_b));expected<-vapply(parents,function(id)winners[[id]],character(1))
        seeds<-vapply(parents,function(id)inherited[[id]],numeric(1))
        if(node$stage_id!="final"){at<-order(seeds);expected<-expected[at];seeds<-seeds[at]}
        .ucl_read_need(identical(c(a,b),unname(expected)),"annex_b_progression_invalid")
      }
      .ucl_read_need(all(c(row$inherited_seed_a,row$inherited_seed_b)==seeds)&&row$inherited_winner_seed==min(seeds),"inherited_seed_invalid")
      .ucl_read_need(is.logical(row$extra_time_applied)&&is.logical(row$penalty_applied)&&!anyNA(row[c("extra_time_applied","penalty_applied")])&&
        (!row$penalty_applied||row$extra_time_applied)&&row$resolution%in%c("aggregate","regulation","extra_time","penalties")&&
        is.numeric(row$seed)&&is.finite(row$seed)&&row$seed==floor(row$seed)&&identical(as.integer(row$seed),.ucl_future_child_seed(seed,iteration,node$node_id)),"knockout_resolution_invalid")
      resolution<-if(row$penalty_applied)"penalties"else if(row$extra_time_applied)"extra_time"else if(node$stage_id=="final")"regulation"else"aggregate"
      .ucl_read_need(identical(row$resolution,resolution),"knockout_resolution_invalid")
      winners[[node$node_id]]<-as.character(row$winner);inherited[[node$node_id]]<-min(seeds)
      if(node$stage_id%in%stages[4:7])counts[c(a,b),node$stage_id]<-counts[c(a,b),node$stage_id]+1L
    }
    counts[winners$final,"champion"]<-counts[winners$final,"champion"]+1L
  }
  .ucl_read_need(identical(as.numeric(colSums(counts)),c(8,16,12,16,8,4,2,1)*n),"stage_mass_not_conserved")
  counts
}
.ucl_read_mechanics <- function(bundle,now) {
  t<-bundle$tables;m<-bundle$manifest;meta<-t$simulation_metadata
  cutoff<-.ucl_read_time(m$information_cutoff_utc);instant<-.ucl_read_time(now)
  .ucl_read_need(cutoff<=instant&&instant-cutoff<=48*3600,"publication_cutoff_stale_or_future")
  schemas<-c(.ucl_out_schemas,.ucl_read_extra_schemas())
  for(name in names(t)){
    empty_joint<-name=="joint_score_views"&&nrow(t[[name]])==0L&&identical(names(t[[name]]),"fixture_id")
    .ucl_read_need(empty_joint||identical(names(t[[name]]),schemas[[name]]),paste0("table_schema_invalid:",name))
  }
  for(name in setdiff(.ucl_out_inventory,c("simulation_metadata","outcomes_manifest")))
    .ucl_read_need(.ucl_out_row_hash_valid(t[[name]]),paste0("base_row_hash_invalid:",name))
  check<-.ucl_out_validate_manifest(t$outcomes_manifest);.ucl_read_need(check$valid,"base_manifest_invalid")
  for(name in setdiff(.ucl_out_inventory,"outcomes_manifest")){
    row<-t$outcomes_manifest[t$outcomes_manifest$artifact_path==paste0(name,".csv"),,drop=FALSE]
    .ucl_read_need(nrow(row)==1L&&identical(row$artifact_sha256,.ucl_out_artifact_hash(t[[name]])),"base_manifest_table_mismatch")
  }
  .ucl_read_need(nrow(meta)==1L&&identical(meta$run_sha256,.ucl_out_canonical_hash(meta[,setdiff(names(meta),"run_sha256"),drop=FALSE])),"simulation_metadata_invalid")
  for(name in c("run_id","edition_id","source_bundle_id","ruleset_sha256"))
    .ucl_read_need(all(vapply(t[intersect(names(t),.ucl_out_inventory)],function(x)!name%in%names(x)||all(is.na(x[[name]])|x[[name]]==meta[[name]]),logical(1))),"base_lineage_mismatch")
  .ucl_read_need(identical(meta$run_id,m$simulation_run_id)&&identical(meta$model_release_id,m$model_release_id)&&identical(meta$model_sha256,m$model_sha256)&&
    identical(meta$calibrator_sha256,m$calibrator_sha256)&&identical(meta$information_cutoff_utc,m$information_cutoff_utc)&&meta$status=="ready"&&
    meta$algorithm_version=="ucl-league-plus-dynamic-knockout-v1"&&identical(meta$draw_artifact_sha256,m$assumptions_policy_sha256),"simulation_parent_mismatch")
  n<-meta$simulation_count;.ucl_read_need(is.numeric(n)&&length(n)==1L&&is.finite(n)&&n>=1&&n<=100000&&n==floor(n),"simulation_count_invalid")
  .ucl_read_need(is.numeric(meta$seed)&&length(meta$seed)==1L&&is.finite(meta$seed)&&meta$seed>=0&&meta$seed<=.Machine$integer.max&&meta$seed==floor(meta$seed),"simulation_seed_invalid")
  clubs<-as.character(t$competition_topology$slot_id)
  .ucl_read_need(length(clubs)==36L&&!anyNA(clubs)&&!anyDuplicated(clubs)&&all(nzchar(clubs))&&nrow(t$league_schedule)==144L&&nrow(t$fixture_forecast_ledger)==144L,"league_inventory_invalid")
  schedule<-t$league_schedule;ledger<-t$fixture_forecast_ledger
  invisible(vapply(schedule$kickoff_utc,.ucl_read_time,numeric(1)))
  invisible(vapply(ledger$kickoff_utc,.ucl_read_time,numeric(1)))
  .ucl_read_need(!anyDuplicated(schedule$fixture_id)&&setequal(ledger$fixture_id,schedule$fixture_id)&&!anyDuplicated(ledger$fixture_id)&&
    all(schedule$home_club_id%in%clubs&schedule$away_club_id%in%clubs&schedule$home_club_id!=schedule$away_club_id),"league_identity_invalid")
  .ucl_read_need(all(table(factor(schedule$home_club_id,levels=clubs))==4L)&&all(table(factor(schedule$away_club_id,levels=clubs))==4L),"league_degree_invalid")
  for(club in clubs).ucl_read_need(length(unique(c(schedule$away_club_id[schedule$home_club_id==club],schedule$home_club_id[schedule$away_club_id==club])))==8L,"league_opponents_invalid")
  available<-ledger$forecast_status=="available";.ucl_read_need(!anyNA(available),"forecast_status_invalid")
  if(any(available)){
    x<-ledger[available,,drop=FALSE];probs<-as.matrix(x[c("prob_home","prob_draw","prob_away")])
    .ucl_read_need(all(is.finite(probs))&&all(probs>=0&probs<=1)&&all(abs(rowSums(probs)-1)<1e-12)&&
      all(x$feature_cutoff_utc<=m$information_cutoff_utc&x$feature_cutoff_utc<x$kickoff_utc)&&all(x$kickoff_utc>m$information_cutoff_utc),"forecast_probabilities_or_cutoff_invalid")
    for(name in c("model_release_id","model_sha256","calibrator_sha256")) .ucl_read_need(all(x[[name]]==m[[name]]),"forecast_parent_mismatch")
  }
  .ucl_read_need(all(is.na(as.matrix(ledger[!available,c("prob_home","prob_draw","prob_away")]))),"retrospective_forecast_forbidden")
  j<-t$joint_score_views;.ucl_read_need(nrow(j)==sum(available)&&setequal(j$fixture_id,ledger$fixture_id[available])&&!anyDuplicated(j$fixture_id),"joint_view_coverage_invalid")
  if(nrow(j)){
    class_mass<-as.matrix(j[c("primary_home","primary_draw","primary_away","raw_home","raw_draw","raw_away")])
    .ucl_read_need(is.numeric(class_mass)&&all(is.finite(class_mass))&&all(class_mass>=0&class_mass<=1)&&
      all(abs(rowSums(class_mass[,1:3,drop=FALSE])-1)<=1e-12)&&all(abs(rowSums(class_mass[,4:6,drop=FALSE])-1)<=1e-12)&&
      all(j$max_1x2_error>=0&j$max_1x2_error<=1e-12&j$max_conditional_error>=0&j$max_conditional_error<=1e-12)&&all(j$model_release_id==m$model_release_id),"joint_view_qa_invalid")
    .ucl_read_need(all(vapply(seq_len(nrow(j)),function(i)identical(j$view_sha256[[i]],phase18_hash_row_v2(j[i,setdiff(names(j),"view_sha256"),drop=FALSE],schema_tag="ucl-tournament-joint-view-v1")),logical(1))),"joint_view_hash_invalid")
  }
  ranks<-t$league_rank_inputs;.ucl_read_need(all(ranks$run_id==m$simulation_run_id)&all(ranks$edition_id=="ucl_2026_27"),"rank_parent_mismatch")
  counts<-.ucl_read_event_counts(t,clubs,n,meta$seed)
  p<-t$progression_probabilities;key<-paste(p$club_id,p$stage_id,sep=":");expected<-as.vector(outer(clubs,colnames(counts),paste,sep=":"))
  .ucl_read_need(nrow(p)==288L&&!anyDuplicated(key)&&setequal(key,expected)&&all(p$status=="resolved")&&all(p$simulation_count==n)&&all(p$seed==meta$seed),"progression_inventory_invalid")
  wanted<-mapply(function(club,stage)counts[club,stage]/n,p$club_id,p$stage_id)
  .ucl_read_need(all(is.finite(p$probability))&&all(p$probability>=0&p$probability<=1)&&all(abs(p$probability-wanted)<=1e-12)&&all(p$draw_artifact_sha256==m$assumptions_policy_sha256),"empirical_probability_mismatch")
  expected_uncertainty<-ucl_live_monte_carlo_uncertainty(p)
  .ucl_read_equal_table(t$monte_carlo_uncertainty,expected_uncertainty,"uncertainty_mismatch")
  samples<-t$late_tie_prior_samples
  declared<-ranks$rank_status=="scenario_prior_order_not_official_rank"
  .ucl_read_need(all(ranks$rank_status%in%c("resolved","scenario_prior_order_not_official_rank"))&&
    is.numeric(ranks$rank_interval_min)&&is.numeric(ranks$rank_interval_max)&&all(is.finite(ranks$rank_interval_min))&&all(is.finite(ranks$rank_interval_max))&&
    all(ranks$rank_interval_min>=1&ranks$rank_interval_max<=36&ranks$rank_interval_min<=ranks$rank&ranks$rank_interval_max>=ranks$rank)&&
    all(ranks$rank_interval_min[!declared]==ranks$rank[!declared]&ranks$rank_interval_max[!declared]==ranks$rank[!declared]),"rank_interval_invalid")
  .ucl_read_need(setequal(paste(ranks$iteration[declared],ranks$club_id[declared]),paste(samples$iteration,samples$club_id)),"late_prior_inventory_mismatch")
  if(nrow(samples)){
    .ucl_read_need(all(samples$iteration%in%seq_len(n))&&all(samples$club_id%in%clubs)&&!anyDuplicated(paste(samples$iteration,samples$club_id))&&
      all(!samples$factual_rank_claimed)&all(samples$policy=="exchangeable_final_disciplinary_weak_order_v1"),"late_prior_authority_invalid")
    at<-match(paste(samples$iteration,samples$club_id),paste(ranks$iteration,ranks$club_id))
    .ucl_read_need(!anyNA(at)&&all(samples$scenario_rank==ranks$rank[at])&&all(ranks$missing_criterion_id[at]=="disciplinary_points"),"late_prior_rank_mismatch")
    .ucl_read_need(all(samples$rank_interval_min==ranks$rank_interval_min[at]&samples$rank_interval_max==ranks$rank_interval_max[at])&&
      is.numeric(samples$known_club_coefficient)&&all(is.finite(samples$known_club_coefficient)&samples$known_club_coefficient>=0),"late_prior_interval_invalid")
    groups<-split(seq_len(nrow(samples)),paste(samples$iteration,samples$rank_interval_min,samples$rank_interval_max))
    for(group in groups){
      s<-samples[group,,drop=FALSE];low<-s$rank_interval_min[[1L]];high<-s$rank_interval_max[[1L]];order<-s$disciplinary_scenario_order
      .ucl_read_need(high-low+1L==nrow(s)&&!anyDuplicated(s$known_club_coefficient)&&is.numeric(order)&&!anyNA(order)&&
        all(order==floor(order))&&setequal(unique(order),seq_len(max(order))),"late_prior_weak_order_invalid")
      expected<-integer(nrow(s));expected[base::order(order,-s$known_club_coefficient)]<-seq.int(low,high)
      used<-duplicated(order)|duplicated(order,fromLast=TRUE)
      .ucl_read_need(all(s$scenario_rank==expected)&&identical(s$coefficient_tiebreak_used,used),"late_prior_coefficient_order_invalid")
    }
    .ucl_read_need(any(available),"factual_completed_league_prior_forbidden")
  }
  .ucl_read_equal_table(t$late_tie_prior_contribution,ucl_future_prior_contribution(samples,clubs,n),"late_prior_contribution_mismatch")
  provenance<-t$future_matchup_provenance
  .ucl_read_need(nrow(provenance)==45*n+sum(t$future_knockout_events$extra_time_applied)&&all(provenance$forecast_domain=="club")&&all(!provenance$is_official_fixture)&&
    all(provenance$home_club_id%in%clubs&provenance$away_club_id%in%clubs&provenance$home_club_id!=provenance$away_club_id)&&
    all(provenance$iteration%in%seq_len(n))&&!anyDuplicated(provenance$fixture_id),"future_provenance_inventory_invalid")
  for(name in c("model_release_id","model_sha256","calibrator_sha256","source_bundle_sha256","information_cutoff_utc"))
    .ucl_read_need(all(provenance[[name]]==m[[name]]),"future_provenance_parent_mismatch")
  .ucl_read_need(all(provenance$information_cutoff_utc<provenance$kickoff_lower_bound_utc)&&
    all(provenance$joint_max_1x2_error>=0&provenance$joint_max_1x2_error<=1e-12&provenance$joint_max_conditional_error>=0&provenance$joint_max_conditional_error<=1e-12)&all(provenance$raw_tail_mass>=0&provenance$raw_tail_mass<=1e-8),"future_provenance_qa_invalid")
  core<-setdiff(names(provenance),c("iteration","fixture_id","is_official_fixture","forecast_sha256"))
  unique_metadata<-which(!duplicated(provenance[c(core,"forecast_sha256")]))
  .ucl_read_need(all(vapply(unique_metadata,function(i)identical(provenance$forecast_sha256[[i]],
    .ucl_future_hash(as.list(provenance[i,core,drop=FALSE]),"ucl-dynamic-matchup-forecast-v1")),logical(1))),"future_provenance_hash_invalid")
  identity_fields<-c("context_sha256","home_club_id","away_club_id","slot_sha256","minutes")
  .ucl_read_need(all(vapply(unique_metadata,function(i)identical(provenance$matchup_id[[i]],paste0("potential:",
    .ucl_future_hash(as.list(provenance[i,identity_fields,drop=FALSE]),"ucl-dynamic-matchup-v1"))),logical(1)))&&
    !anyDuplicated(unique(provenance[c("matchup_id","forecast_sha256")])$matchup_id),"future_query_identity_invalid")
  key<-function(iteration,home,away,slot,minutes)paste(iteration,home,away,slot,minutes,sep=":")
  expected_queries<-vector("list",nrow(t$future_knockout_events))
  for(i in seq_len(nrow(t$future_knockout_events))){
    e<-t$future_knockout_events[i,];final<-e$stage_id=="final"
    queries<-if(!final)key(e$iteration,e$participant_b,e$participant_a,paste0(e$stage_id,"_1"),90L)else character()
    leg<-if(final)1L else 2L;slot<-paste0(e$stage_id,"_",leg)
    queries<-c(queries,key(e$iteration,e$participant_a,e$participant_b,slot,90L))
    if(e$extra_time_applied)queries<-c(queries,key(e$iteration,e$participant_a,e$participant_b,slot,30L))
    expected_queries[[i]]<-queries
  }
  expected_queries<-unlist(expected_queries,use.names=FALSE)
  query_keys<-key(provenance$iteration,provenance$home_club_id,provenance$away_club_id,provenance$slot_id,provenance$minutes)
  .ucl_read_need(!anyDuplicated(query_keys)&&setequal(query_keys,expected_queries),"event_query_coverage_mismatch")
  .ucl_read_need(all(provenance$neutral==(provenance$stage_id=="final"))&&all(provenance$leg_number==ifelse(grepl("_1$",provenance$slot_id),1L,2L)),"future_venue_or_leg_invalid")
  paths<-t$knockout_paths
  .ucl_read_need(nrow(paths)==24L&&setequal(paths$stage_event_id,c(.ucl_future_template_nodes(rep(0L,12L))$node_id,"champion"))&&
    all(paths$path_status=="resolved")&&all(paths$draw_artifact_sha256==m$assumptions_policy_sha256),"representative_path_inventory_invalid")
  last<-t$future_knockout_events[t$future_knockout_events$iteration==n,,drop=FALSE]
  for(i in seq_len(nrow(last))){
    e<-last[i,];path<-paths[paths$stage_event_id==e$node_id,,drop=FALSE]
    .ucl_read_need(nrow(path)==1L&&path$participant_a==e$participant_a&&path$participant_b==e$participant_b&&
      path$extra_time_applied==e$extra_time_applied&&path$penalty_applied==e$penalty_applied,"representative_path_mismatch")
    goals<-c(path$aggregate_final_home,path$aggregate_final_away)
    regulation<-c(path$aggregate_regulation_home,path$aggregate_regulation_away)
    .ucl_read_need(all(is.finite(c(goals,regulation)))&&all(c(goals,regulation)>=0&c(goals,regulation)==floor(c(goals,regulation))),"representative_score_missing")
    et<-c(path$extra_time_home,path$extra_time_away);pen<-c(path$penalty_home,path$penalty_away)
    if(e$extra_time_applied){
      .ucl_read_need(regulation[[1L]]==regulation[[2L]]&&all(is.finite(et))&&all(et>=0&et==floor(et))&&all(goals==regulation+et),"representative_extra_time_mismatch")
    }else .ucl_read_need(all(is.na(et))&&all(goals==regulation),"representative_extra_time_mismatch")
    if(e$penalty_applied){
      .ucl_read_need(goals[[1L]]==goals[[2L]]&&(all(is.na(pen))||(all(is.finite(pen))&&all(pen>=0&pen==floor(pen))&&pen[[1L]]!=pen[[2L]])),"representative_penalty_mismatch")
      if(all(is.finite(pen))).ucl_read_need(e$winner==c(e$participant_a,e$participant_b)[which.max(pen)],"representative_winner_mismatch")
    }else .ucl_read_need(goals[[1L]]!=goals[[2L]]&&all(is.na(pen)),"representative_penalty_mismatch")
    if(goals[1]!=goals[2]).ucl_read_need(e$winner==c(e$participant_a,e$participant_b)[which.max(goals)],"representative_winner_mismatch")
  }
  final<-paths[paths$stage_event_id=="final",,drop=FALSE];champion<-paths[paths$stage_event_id=="champion",,drop=FALSE]
  fields<-setdiff(names(paths),c("path_id","stage_event_id","stage_id","seed_slot_id","row_sha256"))
  .ucl_read_equal_table(final[,fields,drop=FALSE],champion[,fields,drop=FALSE],"representative_champion_mismatch")
  bundle$clubs<-clubs;bundle$simulation_count<-n;bundle
}
.ucl_read_parent_identity <- function(bundle,current,release,policy,context) {
  m<-bundle$manifest;c<-release$model_contract
  .ucl_read_need(identical(release$forecast_domain,"club")&&identical(c$forecast_domain,"club")&&identical(c$entity_kind,"club")&&
    identical(c$authority_mode,"production")&&!isTRUE(c$fixture_authority)&&isTRUE(c$production_eligible)&&identical(c$selected_model_id,"club_elo_nb"),"qualifying_club_model_required")
  expected<-list(source_bundle_sha256=as.character(current$accepted$bundle$bundle_sha256[[1L]]),model_release_id=c$release_id,
    model_sha256=c$model_sha256,calibrator_sha256=c$calibrator_sha256,assumptions_policy_sha256=policy$policy_sha256)
  for(name in names(expected)).ucl_read_need(identical(m[[name]],expected[[name]]),"current_parent_mismatch")
  .ucl_read_need(identical(policy$status,"approved")&&ucl_future_context_is_production(context)&&
    identical(context$source_bundle_sha256,m$source_bundle_sha256)&&identical(context$information_cutoff_utc,m$information_cutoff_utc),"current_parent_authority_invalid")
  .ucl_read_need(identical(c$code_sha256,phase19_production_code_identity()),"model_code_parent_changed")
  .ucl_read_need(setequal(bundle$clubs,names(context$ratings)),"current_roster_mismatch")
  invisible(TRUE)
}
.ucl_read_controls <- function(root,policy_package) {
  project<-.ucl_read_project_root()
  paths<-c(file.path(root,"outcomes_current.json"),file.path(project,"data/competition/registries/ucl_source_current.json"),
    file.path(phase19_club_release_production_root(),"approved_release.csv"),
    file.path(policy_package,"owner_review.json"),file.path(policy_package,"review_manifest.csv"))
  stats::setNames(vapply(paths,.ucl_read_sha,character(1)),paths)
}
.ucl_read_storage <- function(bundle) {
  paths<-c(file.path(bundle$root,"outcomes_current.json"),file.path(bundle$generation_root,"publication_manifest.json"),
    vapply(bundle$manifest$files,function(f)file.path(bundle$generation_root,f$path),character(1)))
  expected<-stats::setNames(c(bundle$pointer_sha256,bundle$pointer$publication_manifest_sha256,
    vapply(bundle$manifest$files,`[[`,character(1),"sha256")),paths)
  .ucl_read_need(identical(expected,stats::setNames(vapply(paths,.ucl_read_sha,character(1)),paths)),"storage_changed_during_validation")
  expected
}
.ucl_read_binding <- function(result).ucl_future_hash(list(result$information_cutoff_utc,result$publication,
  result$context_sha256,result$.controls,result$.storage,result$.root,result$.policy_package,result$.pre_round_limit,
  vapply(result$tables,.ucl_out_artifact_hash,character(1))),"ucl-persisted-read-receipt-v1")
.ucl_read_current_fixture_window <- function(bundle, now) {
  ledger <- bundle$tables$fixture_forecast_ledger
  .ucl_read_need(is.data.frame(ledger) && all(c("forecast_status", "kickoff_utc") %in% names(ledger)) &&
    !anyNA(ledger$forecast_status), "current_fixture_window_invalid")
  open <- ledger$forecast_status == "available"
  kickoff <- vapply(as.character(ledger$kickoff_utc[open]), .ucl_read_time, numeric(1))
  .ucl_read_need(all(kickoff > .ucl_read_time(now)), "past_unconfirmed_league_fixture")
  TRUE
}
.ucl_read_production <- function(now) {
  project<-.ucl_read_project_root();old<-getwd();on.exit(setwd(old),add=TRUE);setwd(project)
  root<-file.path(project,"outputs/competition/ucl_2026_27")
  if(dir.exists(root)).ucl_read_safe(root,project,"directory")
  bundle<-.ucl_read_mechanics(.ucl_read_load(root),now);m<-bundle$manifest;t<-bundle$tables
  .ucl_read_need(isTRUE(m$production_eligible)&&identical(t$simulation_metadata$authority_mode,"production")&&isTRUE(t$simulation_metadata$production_eligible)&&
    all(t$outcomes_manifest$authority_mode=="production")&&all(t$outcomes_manifest$production_eligible)&&
    all(!t$future_matchup_provenance$fixture_authority)&&all(t$future_matchup_provenance$authority_mode=="production"),"fixture_publication_forbidden")
  .ucl_read_current_fixture_window(bundle, now)
  policy<-ucl_future_policy_status();.ucl_read_need(identical(policy$status,"approved"),"current_policy_not_approved")
  reviewed<-utils::read.csv(file.path(policy$package,"review_manifest.csv"),stringsAsFactors=FALSE)
  own<-"R/competition/ucl_live_outcome_reader.R";at<-which(reviewed$artifact_path==own)
  .ucl_read_need(length(at)==1L&&identical(reviewed$sha256[[at]],.ucl_read_sha(file.path(project,own))),"reader_code_not_review_bound")
  controls<-.ucl_read_controls(root,policy$package)
  current<-.ucl_live_fixed_current();phase18_validate_ucl_refresh_current(current)
  release<-phase19_resolve_production_club_release()
  context<-ucl_future_production_context(m$information_cutoff_utc)
  .ucl_read_parent_identity(bundle,current,release,policy,context)
  source_at<-.ucl_read_time(as.character(current$accepted$bundle$created_at_utc[[1L]]));cutoff<-.ucl_read_time(m$information_cutoff_utc)
  .ucl_read_need(source_at<=cutoff&&.ucl_read_time(now)-source_at<=48*3600,"current_source_stale_or_unavailable_at_cutoff")
  approved<-as.numeric(as.POSIXct(as.character(release$selector$approved_at_utc[[1L]]),format="%Y-%m-%d %H:%M:%S UTC",tz="UTC"))
  .ucl_read_need(is.finite(approved)&&approved<=cutoff,"release_after_information_cutoff")
  calendar<-jsonlite::read_json(file.path(policy$package,"calendar.json"),simplifyVector=TRUE)
  .ucl_read_need(.ucl_read_time(now)<min(vapply(calendar$slots$kickoff_lower_bound_utc,.ucl_read_time,numeric(1))),"pre_round_publication_expired")
  bridge<-ucl_live_build_bridge(current,now_utc=m$information_cutoff_utc)
  .ucl_read_need(identical(bridge$graph_validation$status,"ready")&&identical(bridge$readiness$source_freshness,"fresh")&&bridge$readiness$result_pending_count==0L,"current_schedule_unavailable")
  rules<-.ucl_rule_contract();state<-ucl_build_state(bridge$graph,rules=rules,state_cutoff_utc=m$information_cutoff_utc)
  .ucl_read_need(identical(state$status,"ready"),"current_state_unavailable")
  expected<-list(competition_topology=.ucl_out_topology(bridge$graph,rules),league_schedule=.ucl_out_schedule(bridge$graph),
    tie_break_trace=.ucl_out_trace(state,rules),projected_standings=.ucl_out_standings(state,rules),projected_rankings=.ucl_out_rankings(state,rules))
  for(name in names(expected)).ucl_read_equal_table(t[[name]],expected[[name]],"accepted_factual_table_mismatch")
  .ucl_read_equal_table(t$outcomes_manifest,.ucl_out_build_manifest(t[setdiff(.ucl_out_inventory,"outcomes_manifest")],bridge$graph,NULL,t$simulation_metadata,
    fixture_authority=FALSE,production_eligible=TRUE),"accepted_base_manifest_mismatch")
  forecasts<-if(all(.ucl_sim_status_completed(bridge$fixtures$match_status)))NULL else phase19_forecast_current_ucl(m$information_cutoff_utc)
  ledger<-ucl_live_build_simulation_ledger(current,forecasts,m$information_cutoff_utc,context)
  .ucl_read_need(inherits(ledger,"ucl_verified_live_ledger")&&.ucl_live_verify_simulation_ledger(ledger,bridge$graph),"current_approved_forecasts_unavailable")
  .ucl_read_equal_table(t$fixture_forecast_ledger,.ucl_out_ledger_table(ledger$ledger),"approved_forecast_table_mismatch")
  .ucl_read_equal_table(t$joint_score_views,ledger$joint_score_views,"approved_joint_views_mismatch")
  p<-t$future_matchup_provenance;extra<-c("iteration","fixture_id","is_official_fixture")
  unique_queries<-!duplicated(p$matchup_id)
  for(i in which(unique_queries)){
    slot<-ucl_future_production_slot(context,p$slot_id[[i]])
    .ucl_read_need(inherits(slot,"ucl_future_slot"),"approved_future_slot_unavailable")
    actual<-ucl_future_forecast_matchup(context,p$home_club_id[[i]],p$away_club_id[[i]],slot,p$minutes[[i]])
    .ucl_read_equal_table(p[i,setdiff(names(p),extra),drop=FALSE],as.data.frame(actual$metadata,stringsAsFactors=FALSE),"approved_future_forecast_mismatch")
  }
  if(nrow(t$late_tie_prior_samples)).ucl_read_need(all(t$late_tie_prior_samples$known_club_coefficient==context$club_coefficients[t$late_tie_prior_samples$club_id]),"known_coefficient_parent_mismatch")
  .ucl_read_need(identical(controls,.ucl_read_controls(root,policy$package)),"parents_changed_during_validation")
  list(bundle=bundle,controls=controls,policy_package=policy$package,context_sha256=context$context_sha256,
    storage=.ucl_read_storage(bundle),pre_round_limit=min(vapply(calendar$slots$kickoff_lower_bound_utc,.ucl_read_time,numeric(1))))
}
.ucl_read_result <- function(error,fixture=FALSE,bundle=NULL)list(schema_version="ucl-live-outcome-read-result-v1",
  status=if(is.null(error))"mechanics_valid"else"blocked",reason_code=error,production_eligible=FALSE,
  fixture_authority=fixture,authority_mode=if(fixture)"fixture"else"production",tables=if(is.null(bundle))list()else bundle$tables)

ucl_read_live_outcomes_fixture <- function(root,now_utc=NULL) {
  tryCatch({
    root<-normalizePath(root,winslash="/",mustWork=TRUE);temporary<-normalizePath(tempdir(),winslash="/",mustWork=TRUE)
    .ucl_read_need(startsWith(root,paste0(temporary,"/")),"fixture_root_not_process_temporary")
    now<-if(is.null(now_utc))format(Sys.time(),"%Y-%m-%dT%H:%M:%SZ",tz="UTC")else now_utc
    .ucl_read_time(now)
    b<-.ucl_read_mechanics(.ucl_read_load(root),now)
    .ucl_read_result(NULL,TRUE,b)
  },error=function(e).ucl_read_result(if(!is.null(e$reason_code))e$reason_code else"publication_invalid",TRUE))
}
ucl_read_live_outcomes <- function(now_utc=NULL) {
  tryCatch({
    now<-.ucl_read_now(now_utc)
    .ucl_read_need(abs(.ucl_read_time(now)-as.numeric(Sys.time()))<=60,"production_reader_requires_current_time")
    verified<-.ucl_read_production(now)
    .ucl_read_need(as.numeric(Sys.time())<verified$pre_round_limit&&as.numeric(Sys.time())-.ucl_read_time(verified$bundle$manifest$information_cutoff_utc)<=48*3600,"publication_expired_during_validation")
    result<-.ucl_read_result(NULL,FALSE,verified$bundle);result$status<-"available";result$production_eligible<-TRUE
    result$.authority_token<-.ucl_read_authority$token;result$.controls<-verified$controls;result$.policy_package<-verified$policy_package
    result$.root<-verified$bundle$root;result$information_cutoff_utc<-verified$bundle$manifest$information_cutoff_utc
    result$publication<-verified$bundle$pointer;result$context_sha256<-verified$context_sha256
    result$.storage<-verified$storage;result$.pre_round_limit<-verified$pre_round_limit
    result$.binding<-.ucl_read_binding(result);result
  },error=function(e).ucl_read_result(if(!is.null(e$reason_code))e$reason_code else"current_publication_authority_unavailable"))
}
ucl_validate_live_outcomes_read_result <- function(result,now_utc=NULL) {
  tryCatch({
    if(!is.list(result)||!identical(result$.authority_token,.ucl_read_authority$token)||
      !identical(result$status,"available")||!isTRUE(result$production_eligible)||isTRUE(result$fixture_authority))return(FALSE)
    .ucl_read_need(identical(result$.binding,.ucl_read_binding(result)),"read_result_changed")
    .ucl_read_need(identical(result$.root,file.path(.ucl_read_project_root(),"outputs/competition/ucl_2026_27")),"read_root_changed")
    .ucl_read_need(identical(result$.controls,.ucl_read_controls(result$.root,result$.policy_package)),"current_parent_changed")
    generation<-file.path(result$.root,"outcome_generations",result$publication$generation)
    .ucl_read_need(setequal(list.files(generation,all.files=TRUE,no..=TRUE),c("publication_manifest.json",paste0(.ucl_read_inventory(),".csv"))),"stored_inventory_changed")
    for(path in names(result$.storage)).ucl_read_safe(path,result$.root)
    .ucl_read_need(identical(result$.storage,stats::setNames(vapply(names(result$.storage),.ucl_read_sha,character(1)),names(result$.storage))),"stored_publication_changed")
    now<-.ucl_read_time(.ucl_read_now(now_utc));age<-now-.ucl_read_time(result$information_cutoff_utc)
    .ucl_read_need(abs(now-as.numeric(Sys.time()))<=60&&age>=0&&age<=48*3600&&now<result$.pre_round_limit,"read_result_stale")
    # A genuine receipt is revalidated against the fixed current resolvers. A
    # cached token/control hash cannot authorize changed code or immutable model
    # contents, nor a payload loaded under different current parents.
    current<-.ucl_read_production(format(as.POSIXct(now,origin="1970-01-01",tz="UTC"),"%Y-%m-%dT%H:%M:%SZ",tz="UTC"))
    .ucl_read_need(identical(current$controls,result$.controls)&&identical(current$storage,result$.storage)&&
      identical(current$context_sha256,result$context_sha256),"read_authority_changed")
    .ucl_read_need(identical(current$bundle$pointer,result$publication)&&identical(current$bundle$manifest$information_cutoff_utc,result$information_cutoff_utc)&&
      identical(vapply(current$bundle$tables,.ucl_out_artifact_hash,character(1)),vapply(result$tables,.ucl_out_artifact_hash,character(1))),"read_tables_differ_from_current_authority")
    .ucl_read_need(as.numeric(Sys.time())<current$pre_round_limit&&as.numeric(Sys.time())-.ucl_read_time(result$information_cutoff_utc)<=48*3600,"read_expired_during_validation")
    TRUE
  },error=function(e)FALSE)
}
