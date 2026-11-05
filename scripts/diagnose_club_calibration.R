#!/usr/bin/env Rscript

# Read-only model diagnosis. Counterfactual view selection below uses stored
# strictly-prior gate evidence, never assessment outcomes. It is not release
# authority: fitting/replay under the current interpreter remains mandatory.
club_diag_scores <- function(probabilities, classes) {
  p <- as.matrix(probabilities[,c("p_home","p_draw","p_away"),drop=FALSE])
  stopifnot(nrow(p)==length(classes),all(is.finite(p)),all(p>=0),
    all(abs(rowSums(p)-1)<1e-10),all(classes%in%c("home","draw","away")))
  y <- outer(classes,c("home","draw","away"),`==`)
  data.frame(rps=rowMeans(cbind((p[,1]-y[,1])^2,(p[,1]+p[,2]-y[,1]-y[,2])^2)),
    brier=rowSums((p-y)^2),log_loss=-log(pmax(p[cbind(seq_len(nrow(p)),
      match(classes,c("home","draw","away")))],1e-15)))
}

club_diag_ece <- function(probabilities,classes) {
  p <- as.matrix(probabilities[,c("p_home","p_draw","p_away"),drop=FALSE])
  y <- outer(classes,c("home","draw","away"),`==`)
  sum(vapply(1:3,function(j)sum(vapply(0:9,function(bin) {
    take<-p[,j]>=bin/10 & (p[,j]<(bin+1)/10 | (bin==9 & p[,j]<=1))
    if(!any(take))0 else mean(take)/3*abs(mean(p[take,j])-mean(y[take,j]))
  },numeric(1))),numeric(1)))
}

club_diag_correct_prior_gates <- function(view) {
  gates<-view$gates
  fields<-c("probability_integrity","distribution_integrity","cutoff_integrity")
  for(field in fields) {
    at<-which(gates$gate_id==field)
    stopifnot(length(at)==1L)
    value<-view$metrics[[field]]
    # This diagnostic recognizes the old producer's explicit numeric 1 as the
    # logical TRUE it intended. FALSE/0 is never turned into passing evidence.
    valid<-isTRUE(value) || (is.numeric(value)&&length(value)==1L&&!is.na(value)&&identical(as.numeric(value),1))
    gates$value[at]<-as.numeric(valid)
    gates$passed[at]<-identical(as.numeric(gates$value[at]),as.numeric(gates$threshold[at]))
  }
  list(gates=gates,view=if(all(gates$passed))"calibrated_1x2" else "raw_1x2")
}

club_diag_transform <- function(p,temperature) {
  stopifnot(length(temperature)==1L,is.finite(temperature),temperature>0)
  values<-as.matrix(p[,c("p_home","p_draw","p_away"),drop=FALSE])
  z<-log(pmax(values,1e-15))/temperature
  z<-exp(z-apply(z,1L,max));z<-z/rowSums(z)
  result<-p;result[,c("p_home","p_draw","p_away")]<-z;result
}

club_diag_read_release <- function(root,release_id=NULL) {
  trusted<-file.path(root,"outputs/releases/club")
  selector<-utils::read.csv(file.path(trusted,"approved_release.csv"),colClasses="character")
  stopifnot(nrow(selector)==1L,identical(selector$forecast_domain,"club"))
  if(is.null(release_id))release_id<-selector$release_id
  stopifnot(length(release_id)==1L,grepl("^club-v2-[a-z0-9-]+$",release_id))
  release<-file.path(trusted,release_id)
  manifest_path<-file.path(release,"release_manifest.csv")
  file_sha<-function(p)digest::digest(file=p,algo="sha256",serialize=FALSE)
  if(identical(release_id,selector$release_id))stopifnot(identical(file_sha(manifest_path),selector$manifest_sha256))
  manifest<-utils::read.csv(manifest_path,colClasses="character")
  stopifnot(all(manifest$forecast_domain=="club"),all(manifest$release_id==release_id))
  entry<-manifest[manifest$relative_path=="production_evidence.rds",,drop=FALSE]
  stopifnot(nrow(entry)==1L,identical(file_sha(file.path(release,entry$relative_path)),entry$sha256))
  list(bundle=readRDS(file.path(release,entry$relative_path)),release_id=release_id,
    evidence_file_sha256=entry$sha256,manifest_sha256=file_sha(manifest_path))
}

club_diag_run <- function(root=normalizePath(getwd()),release_id=NULL,output_dir=NULL) {
  src<-club_diag_read_release(root,release_id);e<-src$bundle$evidence
  stopifnot(identical(e$forecast_domain,"club"),identical(e$authority_mode,"production"),!isTRUE(e$fixture_authority))
  generation<-src$bundle$refit$lineage$training_snapshot_sha256
  history_id<-src$bundle$refit$model$training_snapshot_sha256
  stopifnot(identical(generation,history_id))
  # The evidence itself keeps exact role/assessment IDs. Accepted corpus labels
  # are checked against their canonical manifest before computing diagnostics.
  history_generation<-unique(vapply(e$fold_results,function(x)as.character(x$fold$accepted_generation_id),character(1)))
  history_manifest<-unique(vapply(e$fold_results,function(x)as.character(x$fold$corpus_manifest_sha256),character(1)))
  stopifnot(length(history_generation)==1L,grepl("^club-history-[A-Za-z0-9-]+$",history_generation),length(history_manifest)==1L)
  history_root<-file.path(root,"data/club/history_generations",history_generation,"accepted")
  matches<-utils::read.csv(file.path(history_root,"matches.csv"),colClasses="character",na.strings="")
  corpus<-utils::read.csv(file.path(history_root,"corpus_manifest.csv"),colClasses="character")
  sys.source(file.path(root,"R/common/phase18_canonical_hash.R"),envir=environment())
  sys.source(file.path(root,"R/club/history_contract.R"),envir=environment())
  stopifnot(nrow(corpus)==1L,identical(corpus$manifest_sha256,history_manifest))
  stopifnot(identical(phase18_history_table_sha256(matches,c("source_id","source_match_id","match_id")),corpus$matches_sha256))
  fold_rows<-list();metric_rows<-list();index<-0L
  for(fold in e$fold_results)for(role in c("candidate","incumbent")) {
    a<-fold[[role]];raw<-a$raw_predictions
    ids<-match(raw$fixture_id,matches$match_id);stopifnot(!anyNA(ids))
    labels<-matches[ids,,drop=FALSE]
    home<-as.integer(labels$regulation_home_goals);away<-as.integer(labels$regulation_away_goals)
    classes<-ifelse(home>away,"home",ifelse(home==away,"draw","away"))
    corrected<-club_diag_correct_prior_gates(a$view_selection)
    counterfactual<-if(identical(corrected$view,"calibrated_1x2"))club_diag_transform(raw,a$calibrator$temperature) else raw
    index<-index+1L
    integrity_ids<-c("probability_integrity","distribution_integrity","cutoff_integrity")
    old<-a$view_selection$gates
    fold_rows[[index]]<-data.frame(fold_id=fold$fold$fold_id,fold_family=fold$fold$fold_family,
      role=role,model_id=a$fit$model_id,assessment_rows=nrow(raw),
      assessment_first=min(labels$event_date),assessment_last=max(labels$event_date),
      temperature=a$calibrator$temperature,stored_view=a$view_selection$primary_probability_view,
      diagnostic_corrected_prior_view=corrected$view,
      old_integrity_veto=paste(old$gate_id[old$gate_id%in%integrity_ids & !old$passed],collapse="|"),
      remaining_prior_veto=paste(corrected$gates$gate_id[!corrected$gates$passed],collapse="|"),
      stringsAsFactors=FALSE)
    for(view in c("stored","diagnostic_corrected_prior")) {
      p<-if(view=="stored")a$predictions else counterfactual
      scores<-club_diag_scores(p,classes)
      if(view=="stored")for(metric in c("rps","brier","log_loss"))
        stopifnot(abs(mean(scores[[metric]])-fold$summary[[paste0(role,"_",metric)]])<1e-12)
      metric_rows[[length(metric_rows)+1L]]<-data.frame(fold_id=fold$fold$fold_id,
        fold_family=fold$fold$fold_family,role=role,model_id=a$fit$model_id,
        view=view,fixture_count=nrow(raw),rps=mean(scores$rps),brier=mean(scores$brier),
        log_loss=mean(scores$log_loss),calibration_error=club_diag_ece(p,classes),
        stringsAsFactors=FALSE)
    }
  }
  folds<-do.call(rbind,fold_rows);metrics<-do.call(rbind,metric_rows)
  groups<-split(metrics,interaction(metrics$fold_family,metrics$role,metrics$view,drop=TRUE))
  summary<-do.call(rbind,lapply(groups,function(x)data.frame(fold_family=x$fold_family[1L],
    role=x$role[1L],view=x$view[1L],fold_count=nrow(x),assessment_rows=sum(x$fixture_count),
    rps=mean(x$rps),brier=mean(x$brier),log_loss=mean(x$log_loss),
    calibration_error=mean(x$calibration_error),stringsAsFactors=FALSE)))
  rownames(summary)<-NULL
  if(is.null(output_dir))output_dir<-file.path(root,"outputs/club_model/diagnostics/2026-11-05")
  dir.create(output_dir,recursive=TRUE,showWarnings=FALSE)
  utils::write.csv(folds,file.path(output_dir,"prior_view_diagnostics.csv"),row.names=FALSE)
  utils::write.csv(metrics,file.path(output_dir,"fold_metrics_before_and_diagnostic.csv"),row.names=FALSE)
  utils::write.csv(summary,file.path(output_dir,"family_metrics_before_and_diagnostic.csv"),row.names=FALSE)
  metadata<-list(schema_version="club-calibration-diagnostic-v1",diagnostic_only=TRUE,
    release_id=src$release_id,evidence_file_sha256=src$evidence_file_sha256,
    release_manifest_sha256=src$manifest_sha256,stored_runtime=e$isolated_execution$r_version,
    diagnostic_runtime=as.character(getRversion()),evaluation_sha256=e$evaluation_sha256,
    source_labels_manifest_sha256=corpus$manifest_sha256,
    retained_model_id=e$decision$selected_model_id,
    stored_failed_gates=e$decision$failed_gate_ids,
    assertion="No fitting, source activation, release installation, or selector write occurs; corrected view is selected only using stored prior gates. Fresh current-runtime model replay is required before promotion.")
  jsonlite::write_json(metadata,file.path(output_dir,"diagnostic_metadata.json"),auto_unbox=TRUE,pretty=TRUE)
  lines<-c("# CL calibration diagnosis", "",paste("Historical selected release:",src$release_id),
    paste("Stored runtime:",e$isolated_execution$r_version,"; diagnostic runtime:",as.character(getRversion())),"",
    "The production view producer used numeric 1 for integrity evidence while the frozen calibration gate applies isTRUE(). Numeric 1 therefore became a failed integrity gate. Every saved candidate and incumbent fold selected the raw view.",
    "The producer now supplies logical TRUE. The associated regression permits a valid calibrated view while preserving proper-score vetoes. No threshold, role membership or model formula changed.","",
    "The diagnostic corrected-prior columns reapply the intended boolean values to stored prior selection gates and, only where those gates pass, apply the already-fitted prior temperature. Assessment outcomes do not choose that view. These values are explanatory evidence, not approved replacement predictions or release authority.","",
    "A fresh code-bound dual evaluation under R 4.6.2 is required. The old 4.6.1 byte-replay evidence does not authorize the new runtime.","",
    "Tournament readiness additionally needs a verified provider-to-state schema bridge, a mixed completed/suppressed/future forecast ledger, accepted same-edition draw procedure evidence, and an authorized production outcome writer. Missing inputs must remain explicit.")
  writeLines(lines,file.path(output_dir,"README.md"))
  print(summary);invisible(list(metadata=metadata,folds=folds,metrics=metrics,summary=summary))
}

if(sys.nframe()==0L) {
  args<-commandArgs(trailingOnly=TRUE)
  if(length(args))stop("This read-only diagnostic CLI takes no arguments")
  club_diag_run()
}
