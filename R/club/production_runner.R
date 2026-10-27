# Genuine production execution.  V1 fixture diagnostics remain isolated.
# Every role below is derived from the owner-accepted snapshot and fold inventory.

phase19_production_hash <- function(value, tag = "phase19-production-v2") {
  digest::digest(list(tag = tag, value = value), algo = "sha256", serialize = TRUE)
}

phase19_production_abort <- function(reason_code, message) {
  stop(structure(list(message = message, call = NULL, reason_code = reason_code),
    class = c("phase19_club_production_error", "error", "condition")))
}

phase19_production_recipe <- function() {
  recipe <- list(schema_version = "phase19-club-production-recipe-v2",
    rating_engine = "batch_prediction_then_strictly_prior_evidence_updates_v2",
    rating_grid = expand.grid(home_advantage = c(40,60,80), k_factor = c(20,30,40),
      inactivity_factor = c(0.99,0.995,0.999), KEEP.OUT.ATTRS = FALSE),
    tuning_rule = "preferred_80pct_then_first_later_wholebatch_cutoff_with_300_available_fit_60_validation_equal_fixture_rps",
    tuning_minimum_fit_rows = 300L, tuning_minimum_validation_rows = 60L,
    calibration_rule = "preferred_last_max_240_or_20pct_then_first_later_wholebatch_cutoff_with_600_available_fit_240_calibration_rows",
    calibration_partition = "earlier_half_temperature_fit_later_half_view_selection",
    minimum_outer_fit_rows = 600L, minimum_temperature_rows = 60L,
    minimum_class_count = 10L, minimum_selection_rows = 60L,
    inner_oof_rule = "fixed_prior_fit_predicts_two_or_more_later_kickoff_batches",
    assessment_rule = "frozen_pre_season_model_and_ratings_no_assessment_label_updates",
    final_refit_rule = "all_strictly_prior_accepted_history_with_selected_parameters",
    view_selection_rule = "frozen_calibration_gates_on_prior_selection_only",
    retention_rule = "retain_venue_incumbent_only_if_all_absolute_and_integrity_gates_pass",
    candidates = c("club_elo_nb", "club_venue_nb"),
    score_support = 0:40, paired_bootstrap_replicates = 10000L)
  recipe$recipe_sha256 <- phase19_production_hash(recipe, "production-recipe")
  recipe
}

phase19_production_recipe_write <- function(path) {
  recipe <- phase19_production_recipe()
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(recipe, path, auto_unbox = TRUE, pretty = TRUE, digits = 17)
  invisible(recipe)
}

phase19_production_rows <- function(snapshot, ids) {
  ids <- sort(as.character(ids), method = "radix")
  rows <- snapshot$matches[match(ids, snapshot$matches$match_id), , drop = FALSE]
  if (!length(ids) || anyNA(rows$match_id) || anyDuplicated(ids))
    phase19_production_abort("role_membership_invalid", "Role inventory is empty, duplicate, or absent from accepted history")
  rownames(rows) <- NULL
  rows
}

phase19_production_class <- function(rows) {
  home<-as.integer(rows$regulation_home_goals);away<-as.integer(rows$regulation_away_goals)
  ifelse(home > away, "home", ifelse(home == away, "draw", "away"))
}

phase19_production_split <- function(rows, fraction = 0.5) {
  boundary <- phase19_fold_boundary_utc(rows)
  ordered <- order(boundary, rows$match_id, method = "radix")
  split_at <- boundary[ordered[[max(1L, as.integer(floor(nrow(rows)*fraction)))]]]
  list(early = rows[boundary <= split_at, , drop = FALSE],
       later = rows[boundary > split_at, , drop = FALSE])
}

phase19_production_role_inventory <- function(snapshot, fold) {
  fit <- phase19_fold_role_evidence(snapshot, fold, "fit")
  prior <- phase19_fold_role_evidence(snapshot, fold, "calibration")
  split <- phase19_production_split(prior)
  selection_start <- if (nrow(split$later)) min(phase19_fold_boundary_utc(split$later)) else ""
  # Evidence as well as kickoff must precede the later selection window.
  temperature <- split$early[split$early$completion_not_before_utc < selection_start &
    split$early$evidence_available_at_utc < selection_start, , drop = FALSE]
  recipe <- phase19_production_recipe()
  support <- table(factor(phase19_production_class(temperature), c("home","draw","away")))
  if (nrow(fit) < recipe$minimum_outer_fit_rows ||
      nrow(temperature) < recipe$minimum_temperature_rows ||
      any(support < recipe$minimum_class_count) ||
      nrow(split$later) < recipe$minimum_selection_rows ||
      length(unique(phase19_fold_boundary_utc(temperature))) < 2L)
    phase19_production_abort("prior_calibration_support_insufficient", paste("Insufficient frozen prior partitions for", fold$fold_id))
  assessment <- phase19_production_rows(snapshot,
    phase19_fold_parse_id_text(fold$declared_fixture_ids, "declared_fixture_ids"))
  list(fit = fit, temperature = temperature, selection = split$later,
       assessment = assessment, discarded = setdiff(prior$match_id,
         c(temperature$match_id, split$later$match_id)), selection_start = selection_start)
}

# Hashing every intermediate rating state is unnecessary for fitting. This
# numeric engine retains the same simultaneous-batch and delayed-evidence rules,
# and its complete input/output identity is bound to every v2 fitted model.
phase19_production_rating_prepare <- function(history) {
  boundaries<-phase19_club_rating_history_boundaries(history)
  time_num<-function(x)as.numeric(as.POSIXct(x,tz="UTC",format="%Y-%m-%dT%H:%M:%SZ"))
  evidence<-pmax(time_num(history$completion_not_before_utc),time_num(history$evidence_available_at_utc))
  # Prediction batches share a kickoff, but results can arrive from different
  # sources years apart. A late archive must not quarantine already available
  # results from unrelated matches on the same date. Equal evidence instants
  # still update simultaneously, strictly after the prediction boundary.
  indices<-split(seq_len(nrow(history)),paste(boundaries$boundary_id,evidence,sep="|"),drop=TRUE)
  batches<-lapply(indices,function(index)list(
    boundary_utc=boundaries$boundary_utc[index[[1L]]],
    boundary_num=time_num(boundaries$boundary_utc[index[[1L]]]),
    eligible_num=max(evidence[index]),
    rows=history[index[order(history$match_id[index],method="radix")],,drop=FALSE]))
  batches[order(vapply(batches,`[[`,character(1),"boundary_utc"),method="radix")]
}

phase19_production_rating <- function(history, parameters, cutoff, predict_rows = NULL,
    prepared = NULL) {
  phase19_validate_club_rating_parameters(parameters)
  ids <- sort(unique(c(history$home_club_id, history$away_club_id,
    predict_rows$home_club_id, predict_rows$away_club_id)), method = "radix")
  rating <- setNames(rep(parameters$base_rating, length(ids)), ids)
  count <- setNames(integer(length(ids)), ids)
  last <- setNames(rep(NA_real_, length(ids)), ids)
  cutoff_num <- as.numeric(as.POSIXct(cutoff, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"))
  batches <- if(is.null(prepared))phase19_production_rating_prepare(history)else prepared
  predicted <- setNames(rep(NA_real_, nrow(history)), history$match_id)
  applied <- rep(FALSE, length(batches))
  time_num <- function(x) as.numeric(as.POSIXct(x, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"))
  eligible <- vapply(batches, `[[`, numeric(1), "eligible_num")
  decayed_at <- NA_real_
  decay <- function(at) {
    active <- !is.na(last)
    reference <- if (is.na(decayed_at)) last[active] else rep(decayed_at,sum(active))
    rating[active] <<- parameters$base_rating + (rating[active] - parameters$base_rating) *
      parameters$inactivity_factor ^ ((at-reference)/86400/365)
    decayed_at <<- at
  }
  update_before <- function(at) {
    due <- which(!applied & eligible < at)
    for (evidence_time in sort(unique(eligible[due]))) {
      indices <- which(!applied & eligible == evidence_time)
      rows <- do.call(rbind, lapply(batches[indices], `[[`, "rows"))
      rows <- rows[order(rows$match_id, method = "radix"), , drop = FALSE]
      decay(evidence_time)
      expected <- phase19_club_rating_expected_home(rating[rows$home_club_id],
        rating[rows$away_club_id], parameters$home_advantage)
      home_goals<-as.integer(rows$regulation_home_goals);away_goals<-as.integer(rows$regulation_away_goals)
      actual <- ifelse(home_goals > away_goals, 1,ifelse(home_goals == away_goals, .5, 0))
      delta <- parameters$k_factor * (actual-expected)
      contributions <- data.frame(id = c(rows$home_club_id,rows$away_club_id), delta = c(delta,-delta))
      contributions <- contributions[order(contributions$id, contributions$delta, method = "radix"), ]
      for (club in sort(unique(contributions$id), method = "radix")) {
        rating[club] <<- rating[club] + sum(contributions$delta[contributions$id == club])
        count[club] <<- count[club] + sum(contributions$id == club)
        last[club] <<- evidence_time
      }
      applied[indices] <<- TRUE
    }
  }
  for (batch in batches) {
    at <- batch$boundary_num
    if (at >= cutoff_num) next
    update_before(at)
    decay(at)
    predicted[batch$rows$match_id] <- rating[batch$rows$home_club_id] +
      parameters$home_advantage - rating[batch$rows$away_club_id]
  }
  update_before(cutoff_num)
  decay(cutoff_num)
  state <- data.frame(club_id = ids, rating = as.numeric(rating), prior_match_count = as.integer(count),
    last_evidence_available = as.numeric(last), stringsAsFactors = FALSE)
  forward <- numeric()
  if (!is.null(predict_rows) && nrow(predict_rows)) {
    forward <- setNames(rep(NA_real_, nrow(predict_rows)), predict_rows$match_id)
    boundaries <- phase19_fold_boundary_utc(predict_rows)
    for (boundary in sort(unique(boundaries), method = "radix")) {
      at <- time_num(boundary)
      if (at < cutoff_num) phase19_production_abort("prediction_cutoff_invalid", "Prediction precedes fit cutoff")
      decay(at)
      rows <- predict_rows[boundaries == boundary, , drop = FALSE]
      forward[rows$match_id] <- rating[rows$home_club_id] + parameters$home_advantage - rating[rows$away_club_id]
    }
  }
  list(training_difference = unname(predicted[history$match_id]),
    forward_difference = unname(forward[predict_rows$match_id]), state = state,
    history_fixture_sha256 = phase19_fold_id_sha256(sort(history$match_id, method = "radix"), "training"),
    parameter_sha256 = parameters$parameter_sha256, cutoff = cutoff)
}

phase19_production_probabilities <- function(model, theta, difference, model_id) {
  fit <- list(model = model, model_id = model_id)
  means <- phase19_club_goal_nb_means(fit, data.frame(rating_difference = difference))
  goals <- 0:40
  home <- vapply(means$home, function(mu) stats::dnbinom(goals, size = theta, mu = mu), numeric(41L))
  away <- vapply(means$away, function(mu) stats::dnbinom(goals, size = theta, mu = mu), numeric(41L))
  if (is.null(dim(home))) home <- matrix(home,nrow=41L)
  if (is.null(dim(away))) away <- matrix(away,nrow=41L)
  mass <- colSums(home)*colSums(away)
  draw <- colSums(home*away)/mass
  away_cdf_below <- apply(away,2L,cumsum)-away
  if (is.null(dim(away_cdf_below))) away_cdf_below <- matrix(away_cdf_below,nrow=41L)
  win <- colSums(home*away_cdf_below)/mass
  result <- data.frame(p_home = win, p_draw = draw, p_away = 1-win-draw,
    expected_home_goals = means$home, expected_away_goals = means$away,
    raw_tail_mass = pmax(0,1-mass), stringsAsFactors = FALSE)
  if (any(!is.finite(as.matrix(result))) || any(result[,1:3] < -1e-12))
    phase19_production_abort("probability_integrity_failed", "Invalid finite NB probabilities")
  result
}

# Replay the frozen parameter grid together. Each column is an independent
# state; sharing batch preparation avoids 27 copies of R event-loop overhead.
phase19_production_rating_grid <- function(history,grid,cutoff,predict_rows,prepared=NULL) {
  if(is.null(prepared))prepared<-phase19_production_rating_prepare(history)
  ids<-sort(unique(c(history$home_club_id,history$away_club_id,predict_rows$home_club_id,predict_rows$away_club_id)),method="radix")
  width<-nrow(grid);rating<-matrix(1500,nrow=length(ids),ncol=width,dimnames=list(ids,NULL))
  last<-rep(NA_real_,length(ids));names(last)<-ids
  training<-matrix(NA_real_,nrow=nrow(history),ncol=width,dimnames=list(history$match_id,NULL))
  forward<-matrix(NA_real_,nrow=nrow(predict_rows),ncol=width,dimnames=list(predict_rows$match_id,NULL))
  eligible<-vapply(prepared,`[[`,numeric(1),"eligible_num");applied<-rep(FALSE,length(prepared))
  time_num<-function(x)as.numeric(as.POSIXct(x,tz="UTC",format="%Y-%m-%dT%H:%M:%SZ"))
  decayed_at<-NA_real_
  decay<-function(at) {
    active<-!is.na(last)
    reference<-if(is.na(decayed_at))last[active]else rep(decayed_at,sum(active))
    factor<-exp(outer((at-reference)/86400/365,log(grid$inactivity_factor)))
    rating[active,] <<- 1500+(rating[active,,drop=FALSE]-1500)*factor
    decayed_at<<-at
  }
  differences<-function(rows)sweep(rating[rows$home_club_id,,drop=FALSE],2L,grid$home_advantage,"+")-rating[rows$away_club_id,,drop=FALSE]
  update_before<-function(at) {
    due<-which(!applied & eligible<at)
    for(evidence_time in sort(unique(eligible[due]))) {
      indices<-which(!applied & eligible==evidence_time)
      rows<-do.call(rbind,lapply(prepared[indices],`[[`,"rows"))
      rows<-rows[order(rows$match_id,method="radix"),,drop=FALSE]
      decay(evidence_time)
      expected<-1/(1+10^(-differences(rows)/400))
      home_goals<-as.integer(rows$regulation_home_goals);away_goals<-as.integer(rows$regulation_away_goals)
      actual<-ifelse(home_goals>away_goals,1,ifelse(home_goals==away_goals,.5,0))
      delta<-sweep(actual-expected,2L,grid$k_factor,"*")
      for(club in sort(unique(c(rows$home_club_id,rows$away_club_id)),method="radix")) {
        contributions<-rbind(delta[rows$home_club_id==club,,drop=FALSE],-delta[rows$away_club_id==club,,drop=FALSE])
        rating[club,] <<- rating[club,]+colSums(contributions)
        last[club]<<-evidence_time
      }
      applied[indices]<<-TRUE
    }
  }
  cutoff_num<-time_num(cutoff)
  for(batch in prepared) {
    if(batch$boundary_num>=cutoff_num)next
    update_before(batch$boundary_num);decay(batch$boundary_num)
    training[batch$rows$match_id,]<-differences(batch$rows)
  }
  update_before(cutoff_num);decay(cutoff_num)
  boundaries<-phase19_fold_boundary_utc(predict_rows)
  for(boundary in sort(unique(boundaries),method="radix")) {
    decay(time_num(boundary));rows<-predict_rows[boundaries==boundary,,drop=FALSE]
    forward[rows$match_id,]<-differences(rows)
  }
  list(training_difference=training[history$match_id,,drop=FALSE],forward_difference=forward[predict_rows$match_id,,drop=FALSE])
}

phase19_production_scores <- function(probabilities, classes) {
  p <- as.matrix(probabilities[,c("p_home","p_draw","p_away")])
  index <- match(classes,c("home","draw","away"))
  actual <- matrix(0,nrow(p),3L); actual[cbind(seq_len(nrow(p)),index)] <- 1
  data.frame(rps = rowMeans(cbind((p[,1]-actual[,1])^2,
    (p[,1]+p[,2]-actual[,1]-actual[,2])^2)),
    brier = rowSums((p-actual)^2), log_loss = -log(pmax(p[cbind(seq_len(nrow(p)),index)],1e-15)))
}

phase19_production_calibration_error <- function(probabilities, classes) {
  p <- as.matrix(probabilities[,c("p_home","p_draw","p_away")])
  actual <- outer(classes,c("home","draw","away"),`==`)
  errors <- numeric()
  for (column in 1:3) for (bin in 0:9) {
    take <- p[,column] >= bin/10 & (p[,column] < (bin+1)/10 | (bin == 9 & p[,column] <= 1))
    if (any(take)) errors <- c(errors, sum(take)/nrow(p)/3 * abs(mean(p[take,column])-mean(actual[take,column])))
  }
  sum(errors)
}

phase19_production_tune <- function(history, protocol, recipe = phase19_production_recipe()) {
  split <- phase19_production_split(history,.8)
  cutoff <- if (nrow(split$later)) min(phase19_fold_boundary_utc(split$later)) else ""
  boundary<-phase19_fold_boundary_utc(history)
  candidates<-sort(unique(boundary[boundary>=cutoff]),method="radix")
  supported<-candidates[vapply(candidates,function(at) {
    sum(boundary<at & history$completion_not_before_utc<at & history$evidence_available_at_utc<at)>=recipe$tuning_minimum_fit_rows &&
      sum(boundary>=at)>=recipe$tuning_minimum_validation_rows
  },logical(1))]
  if(length(supported)) {
    # Row counts alone do not make the registered design estimable: archives
    # first published after their matches can have entirely base Elo features.
    # Training differences depend only on strictly earlier available evidence,
    # so compute them once and choose the first full-rank prior fit window.
    probe<-phase19_production_rating(history,phase19_club_rating_parameters(),
      max(history$completion_not_before_utc,history$evidence_available_at_utc))$training_difference
    supported<-supported[vapply(supported,function(at) {
      take<-boundary<at & history$completion_not_before_utc<at & history$evidence_available_at_utc<at
      design<-data.frame(elo=c(probe[take],-probe[take]),venue=rep(c(1,0),each=sum(take)))
      qr(cbind(1,as.matrix(design)))$rank==3L
    },logical(1))]
    if(!length(supported))phase19_production_abort("tuning_design_not_estimable",
      "No prior tuning window supports the full registered Elo and venue design")
  }
  if(length(supported)) {
    cutoff<-supported[[1L]]
    split<-list(early=history[boundary<cutoff,,drop=FALSE],later=history[boundary>=cutoff,,drop=FALSE])
  }
  fit_rows <- split$early[split$early$completion_not_before_utc < cutoff &
    split$early$evidence_available_at_utc < cutoff, , drop = FALSE]
  if (nrow(fit_rows) < recipe$tuning_minimum_fit_rows || nrow(split$later) < recipe$tuning_minimum_validation_rows)
    phase19_production_abort("tuning_support_insufficient", "Prior tuning split has insufficient support")
  registration <- protocol$candidate_registry[protocol$candidate_registry$model_id == "club_elo_nb", ]
  prepared<-phase19_production_rating_prepare(fit_rows)
  grid_ratings<-phase19_production_rating_grid(fit_rows,recipe$rating_grid,cutoff,split$later,prepared)
  rows <- lapply(seq_len(nrow(recipe$rating_grid)), function(i) {
    grid <- recipe$rating_grid[i,]
    parameter <- phase19_club_rating_parameters(home_advantage = grid$home_advantage,
      k_factor = grid$k_factor, inactivity_factor = grid$inactivity_factor)
    rating<-list(training_difference=grid_ratings$training_difference[,i],
      forward_difference=grid_ratings$forward_difference[,i])
    long <- phase19_club_goal_long_training(fit_rows,
      data.frame(rating_difference = rating$training_difference), phase19_club_goal_active_features("club_elo_nb"))
    attempt <- tryCatch({
      model <- phase19_club_goal_nb_fit(stats::as.formula(registration$formula),long,"club_elo_nb")$model
      p <- phase19_production_probabilities(model,model$theta,rating$forward_difference,"club_elo_nb")
      mean(phase19_production_scores(p,phase19_production_class(split$later))$rps)
    }, error = function(e) Inf)
    data.frame(home_advantage=grid$home_advantage,k_factor=grid$k_factor,
      inactivity_factor=grid$inactivity_factor,parameter_sha256=parameter$parameter_sha256,rps=attempt)
  })
  table <- do.call(rbind,rows)
  table <- table[order(table$rps,table$parameter_sha256,method="radix"), ,drop=FALSE]
  rownames(table) <- NULL
  if (!is.finite(table$rps[[1L]])) phase19_production_abort("tuning_failed", "No frozen grid parameter converged")
  best <- table[1,]
  list(parameters=phase19_club_rating_parameters(home_advantage=best$home_advantage,
    k_factor=best$k_factor,inactivity_factor=best$inactivity_factor),table=table,
    fit_ids=sort(fit_rows$match_id,method="radix"),selection_ids=sort(split$later$match_id,method="radix"),cutoff=cutoff)
}

# Construct the existing audited goal-fit contract from the explicitly scoped
# v2 rating engine; accepted snapshot identities are retained as parents.
phase19_production_fit <- function(history, rating, parameters, registration,
    snapshot, current, protocol, cutoff, excluded_competition_id = "") {
  registration <- phase19_club_goal_registration(registration, protocol)
  # The orchestrator and installer independently validate the immutable parent
  # once. Scope rows here without repeatedly rehashing the whole corpus for
  # each of the 27 tuning candidates and every paired fold.
  if(cutoff>snapshot$cutoff_utc)
    phase19_production_abort("fit_cutoff_invalid","Fit cutoff exceeds the accepted snapshot cutoff")
  eligible <- phase19_fold_eligible_before(snapshot$matches,cutoff,excluded_competition_id)
  if (any(!history$match_id %in% eligible$match_id) ||
      (nzchar(excluded_competition_id) && any(history$competition_id == excluded_competition_id)))
    phase19_production_abort("fit_role_invalid", "Fit role contains future or held-out evidence")
  model_id <- as.character(registration$model_id)
  active <- phase19_club_goal_active_features(model_id)
  long <- phase19_club_goal_long_training(history,
    data.frame(rating_difference = rating$training_difference), active)
  fitted <- phase19_club_goal_nb_fit(stats::as.formula(registration$formula),long,model_id)
  model <- fitted$model
  # Formula environments otherwise capture the full runner frame (including
  # snapshots and the model itself), bloating every checkpoint and RDS release.
  attr(model$terms,".Environment")<-baseenv()
  if(!is.null(attr(model$model,"terms")))attr(model$model,"terms")<-model$terms
  coefficients <- data.frame(term=names(stats::coef(model)),estimate=as.numeric(stats::coef(model)),stringsAsFactors=FALSE)
  coefficients <- coefficients[order(coefficients$term,method="radix"),,drop=FALSE];rownames(coefficients)<-NULL
  empty_grid <- data.frame(home_goals=integer(),away_goals=integer(),probability=numeric())
  unavailable <- phase19_club_goal_unavailable_ids(protocol$feature_contract)
  fit <- list(schema_version="phase19-club-goal-fit-v1",hash_encoding_version=phase18_canonical_encoding_v2(),
    forecast_domain="club",authority_mode=snapshot$authority_mode,fixture_authority=isTRUE(snapshot$fixture_authority),
    promotion_eligible=isTRUE(protocol$production_eligible) && identical(snapshot$authority_mode,"production"),
    model_id=model_id,registry_role=as.character(registration$registry_role),selection_role=as.character(registration$selection_role),
    model_family=as.character(registration$model_family),formula=as.character(registration$formula),
    output_capability=as.character(registration$output_capability),goal_distribution_declared=TRUE,promotion_comparable=TRUE,
    support_min=0L,support_max=40L,tail_policy="truncate_0_40_then_joint_renormalize_once",cutoff_utc=cutoff,
    fit_row_count=as.integer(nrow(history)),max_completion_not_before_utc=max(history$completion_not_before_utc),
    max_evidence_available_at_utc=max(history$evidence_available_at_utc),active_features=active,
    active_features_text=paste(active,collapse="|"),dropped_features=character(),dropped_features_text="",
    converged=TRUE,convergence_status="converged",fallback_status="none",theta=as.numeric(model$theta),
    theta_text=sprintf("%.17g",model$theta),training_snapshot_sha256=snapshot$snapshot_sha256,
    current_snapshot_sha256=current$snapshot_sha256,rating_parameter_sha256=parameters$parameter_sha256,
    rating_evidence_sha256=phase19_production_hash(list(ids=history$match_id,rating=rating),"scoped-ratings"),
    candidate_registry_sha256=protocol$candidate_registry_sha256,feature_contract_sha256=protocol$feature_contract_sha256,
    protocol_sha256=protocol$protocol_sha256,training_rows_sha256=phase18_hash_table_v2(
      history[,c("match_id","row_sha256"),drop=FALSE],key="match_id",schema_tag="phase19-production-fit-rows-v2"),
    coefficient_sha256=phase19_club_goal_coefficients_hash(coefficients),empirical_grid_sha256="",
    model_sha256=phase19_club_goal_nested_hash(model,"phase19-club-goal-model-v1"),
    registration_sha256=phase19_club_goal_registration_hash(registration),mass_package_version=as.character(utils::packageVersion("MASS")),
    unavailable_feature_ids=unavailable,unavailable_feature_ids_text=paste(unavailable,collapse="|"),
    registration=registration,model=model,coefficients=coefficients,empirical_grid=empty_grid,fit_warnings=fitted$warnings,
    production_eligible=isTRUE(protocol$production_eligible) && identical(snapshot$authority_mode,"production"),
    training_fixture_sha256=phase19_fold_id_sha256(sort(history$match_id,method="radix"),"training"),
    excluded_competition_id=excluded_competition_id,rating_engine=phase19_production_recipe()$rating_engine,
    rating_parameters=parameters,fit_sha256="")
  fit$fit_sha256<-phase19_club_goal_fit_hash(fit)
  class(fit)<-c("phase19_club_goal_fit","list")
  phase19_validate_club_goal_fit(fit)
  fit
}

phase19_production_prediction <- function(fit, rows, difference, cutoff) {
  p <- phase19_production_probabilities(fit$model,fit$theta,difference,fit$model_id)
  p$fixture_id <- as.character(rows$match_id)
  p$kickoff_utc <- phase19_fold_boundary_utc(rows)
  p$evidence_cutoff_exclusive <- cutoff
  p$rating_difference <- difference
  p$distribution_sha256 <- vapply(seq_len(nrow(rows)),function(i) phase19_production_hash(
    list(fixture=rows$match_id[[i]],fit=fit$fit_sha256,home=p$expected_home_goals[[i]],
      away=p$expected_away_goals[[i]],theta=fit$theta,support=0:40,
      tail_policy=fit$tail_policy),"complete-nb-grid-0-40"),character(1))
  p
}

phase19_production_temperature_fold <- function(fold, roles) {
  result<-fold
  replace_ids<-function(role,ids) {
    result[[paste0(role,"_fixture_ids")]] <<- phase19_fold_id_text(ids,paste0(role,"_fixture_ids"))
    result[[paste0(role,"_fixture_count")]] <<- as.integer(length(ids))
    result[[paste0(role,"_fixture_sha256")]] <<- phase19_fold_id_sha256(ids,role)
  }
  replace_ids("calibration",sort(roles$temperature$match_id,method="radix"))
  replace_ids("declared",sort(roles$selection$match_id,method="radix"))
  result$calibration_cutoff_exclusive<-roles$selection_start
  result$assessment_start_utc<-roles$selection_start
  result$assessment_end_utc<-max(phase19_fold_boundary_utc(roles$selection))
  result$row_sha256<-phase19_fold_row_sha256(result)
  result
}

phase19_production_temperature_source <- function(prediction, rows, fold, model_id) {
  boundary<-phase19_fold_boundary_utc(rows)
  batches<-sort(unique(boundary),method="radix")
  inner<-ifelse(boundary <= batches[[max(1L,as.integer(floor(length(batches)/2)))]],"inner_prior_1","inner_prior_2")
  result<-data.frame(fixture_id=as.character(rows$match_id),candidate_id=model_id,
    outer_fold_id=as.character(fold$fold_id),inner_fold_id=inner,evidence_role="inner_out_of_fold",
    competition_id=as.character(rows$competition_id),event_date=as.character(rows$event_date),
    kickoff_utc=as.character(rows$kickoff_utc),kickoff_precision=as.character(rows$kickoff_precision),
    completion_not_before_utc=as.character(rows$completion_not_before_utc),evidence_available_at_utc=as.character(rows$evidence_available_at_utc),
    counts_for_model=rep(TRUE,nrow(rows)),p_home_raw=prediction$p_home,p_draw_raw=prediction$p_draw,p_away_raw=prediction$p_away,
    observed_class=phase19_production_class(rows),source_grid_sha256=prediction$distribution_sha256,
    source_prediction_sha256="",stringsAsFactors=FALSE,check.names=FALSE)
  result$source_prediction_sha256<-phase19_club_calibration_source_row_sha256(result)
  result
}

phase19_production_transform <- function(p, calibrator) {
  transformed<-t(vapply(seq_len(nrow(p)),function(i) unname(phase19_club_temperature_transform(
    c(home=p$p_home[[i]],draw=p$p_draw[[i]],away=p$p_away[[i]]),calibrator$temperature)),numeric(3L)))
  p[,c("p_home","p_draw","p_away")]<-transformed
  p
}

phase19_production_select_view <- function(raw, calibrator, rows, protocol) {
  calibrated<-phase19_production_transform(raw,calibrator)
  classes<-phase19_production_class(rows)
  a<-phase19_production_scores(raw,classes);b<-phase19_production_scores(calibrated,classes)
  relative<-function(x,y) if(y==0) if(x<=y) 0 else Inf else x/y-1
  metrics<-list(rps_delta=mean(b$rps)-mean(a$rps),
    brier_relative_regression=relative(mean(b$brier),mean(a$brier)),
    log_loss_relative_regression=relative(mean(b$log_loss),mean(a$log_loss)),
    calibration_delta=phase19_production_calibration_error(calibrated,classes)-phase19_production_calibration_error(raw,classes),
    declared_fixture_coverage=1,probability_integrity=1,distribution_integrity=1,cutoff_integrity=1)
  gate<-phase19_club_calibration_gate_decision(metrics,protocol)
  result<-list(primary_probability_view=as.character(gate$primary_probability_view),metrics=metrics,gates=gate$gates,
    selection_fixture_ids=sort(rows$match_id,method="radix"),
    latest_selection_evidence=max(rows$evidence_available_at_utc),
    calibrator_sha256=calibrator$calibrator_sha256,
    raw_predictions_sha256=phase19_production_hash(raw,"selection-raw"),
    outcomes_sha256=phase19_production_hash(rows[,c("match_id","regulation_home_goals","regulation_away_goals")],"selection-outcomes"))
  result$decision_sha256<-phase19_production_hash(result,"prior-view-selection")
  result
}

phase19_production_summary <- function(fold, roles, artifacts) {
  candidate<-artifacts$candidate;incumbent<-artifacts$incumbent
  data.frame(fold_id=fold$fold_id,fold_family=fold$fold_family,
    assessment_competition_id=fold$assessment_competition_id,assessment_season_id=fold$assessment_season_id,
    fixture_count=nrow(roles$assessment),candidate_rps=mean(candidate$scores$rps),incumbent_rps=mean(incumbent$scores$rps),
    rps_delta=mean(candidate$scores$rps-incumbent$scores$rps),candidate_brier=mean(candidate$scores$brier),
    incumbent_brier=mean(incumbent$scores$brier),candidate_log_loss=mean(candidate$scores$log_loss),
    incumbent_log_loss=mean(incumbent$scores$log_loss),
    candidate_calibration_error=phase19_production_calibration_error(candidate$predictions,phase19_production_class(roles$assessment)),
    incumbent_calibration_error=phase19_production_calibration_error(incumbent$predictions,phase19_production_class(roles$assessment)),stringsAsFactors=FALSE)
}

phase19_production_one_fold <- function(snapshot,current,protocol,fold,progress=function(...)NULL) {
  progress(paste("Fitting",fold$fold_id))
  roles<-phase19_production_role_inventory(snapshot,fold)
  tuning<-phase19_production_tune(roles$fit,protocol)
  forward_rows<-rbind(roles$temperature,roles$selection,roles$assessment)
  rating<-phase19_production_rating(roles$fit,tuning$parameters,fold$training_cutoff_exclusive,forward_rows)
  fit_rating<-rating;fit_rating$forward_difference<-numeric()
  temperature_fold<-phase19_production_temperature_fold(fold,roles)
  artifacts<-lapply(c("club_elo_nb","club_venue_nb"),function(id) {
    registration<-protocol$candidate_registry[protocol$candidate_registry$model_id==id,,drop=FALSE]
    fit<-phase19_production_fit(roles$fit,fit_rating,tuning$parameters,registration,snapshot,current,protocol,
      fold$training_cutoff_exclusive,fold$held_out_competition_id)
    predictions<-phase19_production_prediction(fit,forward_rows,rating$forward_difference,fold$training_cutoff_exclusive)
    temperature_predictions<-predictions[match(roles$temperature$match_id,predictions$fixture_id),,drop=FALSE]
    source<-phase19_production_temperature_source(temperature_predictions,roles$temperature,temperature_fold,id)
    calibrator<-phase19_fit_club_calibrator(source,temperature_fold,registration,protocol)
    phase19_validate_club_calibrator(calibrator,require_fitted=TRUE)
    selection<-predictions[match(roles$selection$match_id,predictions$fixture_id),,drop=FALSE]
    choice<-phase19_production_select_view(selection,calibrator,roles$selection,protocol)
    assessment<-predictions[match(roles$assessment$match_id,predictions$fixture_id),,drop=FALSE]
    raw<-assessment
    if(identical(choice$primary_probability_view,"calibrated_1x2")) assessment<-phase19_production_transform(assessment,calibrator)
    list(fit=fit,calibrator=calibrator,calibration_source=source,temperature_fold=temperature_fold,
      view_selection=choice,raw_predictions=raw,predictions=assessment,
      scores=phase19_production_scores(assessment,phase19_production_class(roles$assessment)))
  });names(artifacts)<-c("candidate","incumbent")
  summary<-phase19_production_summary(fold,roles,artifacts)
  role_ids<-lapply(roles[c("fit","temperature","selection","assessment")],function(rows)sort(rows$match_id,method="radix"))
  result<-list(fold=fold,role_ids=role_ids,discarded_calibration_ids=roles$discarded,tuning=tuning,
    candidate=artifacts$candidate,incumbent=artifacts$incumbent,summary=summary,
    recipe_sha256=phase19_production_recipe()$recipe_sha256)
  result$execution_sha256<-phase19_production_fold_identity(result)
  result
}

phase19_production_fold_identity <- function(result) {
  identities<-lapply(result[c("candidate","incumbent")],function(a)list(fit=a$fit$fit_sha256,
    calibrator=a$calibrator$calibrator_sha256,selection=a$view_selection$decision_sha256,
    predictions=a$predictions,scores=a$scores))
  phase19_production_hash(list(fold=result$fold$row_sha256,roles=result$role_ids,tuning=result$tuning,
    summary=result$summary,identities=identities,recipe=result$recipe_sha256),"complete-fold-execution-v2")
}

phase19_production_code_identity <- function() {
  paths<-c("R/common/phase18_canonical_hash.R","R/club/identity.R","R/club/identity_bootstrap.R",
    "R/club/history_contract.R","R/club/model_contract.R",
    "R/club/production_runner.R","R/club/goal_model.R","R/club/rating.R",
    "R/club/calibration.R","R/club/evaluation_protocol.R","R/club/evaluation.R","R/club/release.R")
  root<-.phase19_club_project_root
  hashes<-vapply(file.path(root,paths),function(path)digest::digest(file=path,algo="sha256"),character(1))
  phase19_production_hash(setNames(hashes,paths),"production-code")
}

phase19_production_evaluation_identity <- function(evidence) {
  payload<-evidence[setdiff(names(evidence),c("fold_results","evaluation_sha256","isolated_execution"))]
  payload$isolation<-list(engine="fresh_callr_R_processes",run_count=evidence$isolated_execution$run_count,
    r_version=evidence$isolated_execution$r_version)
  phase19_production_hash(payload,"production-evaluation")
}

phase19_production_parent_identity <- function(snapshot,current,protocol,folds) {
  list(history_snapshot_sha256=snapshot$snapshot_sha256,current_snapshot_sha256=current$snapshot_sha256,
    protocol_sha256=protocol$protocol_sha256,policy_review_sha256=protocol$policy_review$review_sha256,
    fold_registry_sha256=folds$fold_registry_sha256,fold_review_sha256=folds$fold_review$review_sha256,
    recipe_sha256=phase19_production_recipe()$recipe_sha256,code_sha256=phase19_production_code_identity())
}

phase19_production_roster_identity <- function(snapshot) {
  fields<-intersect(c("club_id","provider_club_id","association_code"),names(snapshot$clubs))
  clubs<-snapshot$clubs[order(snapshot$clubs$club_id,method="radix"),fields,drop=FALSE]
  rownames(clubs)<-NULL
  phase19_production_hash(list(edition_id=snapshot$edition_id,
    identity_registry_sha256=snapshot$identity_registry_sha256,clubs=clubs),"approved-roster-identity")
}

phase19_production_validate_frozen_current <- function(frozen,fresh) {
  phase19_validate_current_ucl_club_snapshot(fresh,"production")
  if(!inherits(frozen,"phase19_current_ucl_authority_result") ||
     !identical(frozen$status,"ready") || !identical(frozen$authority_mode,"production") ||
     isTRUE(frozen$fixture_authority) || !isTRUE(frozen$promotion_eligible) ||
     !identical(frozen$snapshot_sha256,phase19_current_snapshot_sha256(frozen)) ||
     !identical(frozen$edition_id,fresh$edition_id) ||
     !identical(frozen$identity_registry_sha256,fresh$identity_registry_sha256) ||
     !identical(phase19_production_roster_identity(frozen),phase19_production_roster_identity(fresh)) ||
     !identical(sort(frozen$clubs$club_id,method="radix"),sort(fresh$clubs$club_id,method="radix")) ||
     nrow(frozen$clubs)!=36L || nrow(fresh$clubs)!=36L)
    phase19_production_abort("current_roster_changed","Current approved 36-club roster or reviewed identities differ from the fitted roster")
  fixed<-phase19_club_fixed_current_paths()
  roots<-phase18_ucl_refresh_roots(fixed$accepted,fixed$registries)
  generation<-phase18_ucl_refresh_safe_id(frozen$accepted_generation_id,"frozen accepted generation")
  path<-file.path(roots$accepted_generations_root,generation)
  inventory<-phase18_ucl_refresh_inventory(path)
  if(!identical(inventory$sha256,frozen$accepted_generation_sha256))
    phase19_production_abort("frozen_current_source_invalid","Original accepted current-club source generation changed")
  candidate<-phase18_read_ucl_candidate(path)
  phase18_validate_ucl_source_bundle(candidate)
  clubs<-phase19_current_ucl_canonical_clubs(candidate$tables$clubs,frozen$edition_id,"Frozen accepted current UCL")
  if(!identical(frozen$bundle_sha256,as.character(candidate$bundle$bundle_sha256[[1L]])) ||
     !identical(frozen$source_authority_sha256,as.character(candidate$authority$authority_sha256[[1L]])) ||
     !identical(frozen$source_clubs,clubs) || !identical(frozen$clubs,clubs) ||
     !identical(frozen$source_club_table_sha256,phase19_current_ucl_source_clubs_sha256(clubs)))
    phase19_production_abort("frozen_current_source_invalid","Original fitted current-club source lineage changed")
  # Display names or source timestamps may refresh, while canonical club IDs
  # and their provider mapping retain the same reviewed identity semantics.
  fields<-intersect(c("club_id","provider_club_id","association_code"),names(clubs))
  if(!identical(frozen$clubs[,fields,drop=FALSE],fresh$clubs[,fields,drop=FALSE]))
    phase19_production_abort("current_roster_changed","Current provider-to-canonical club mapping changed")
  invisible(TRUE)
}

phase19_production_assert_parents <- function(snapshot,current,protocol,folds,fresh_current=NULL) {
  phase19_validate_club_training_snapshot(snapshot,"production")
  if(is.null(fresh_current))phase19_validate_current_ucl_club_snapshot(current,"production") else
    phase19_production_validate_frozen_current(current,fresh_current)
  if(!identical(protocol$status,"ready") || !identical(protocol$authority_mode,"production") ||
      !isTRUE(protocol$production_eligible) || isTRUE(protocol$fixture_authority))
    phase19_production_abort("protocol_policy_not_approved","Accepted production policy is required")
  phase19_assert_production_fold_protocol(folds)
  phase19_validate_fold_registry(folds$fold_registry,snapshot,protocol,"production")
  recipe<-phase19_production_recipe()
  binding<-paste0("production_recipe_v2:",recipe$recipe_sha256)
  if(!grepl(binding,folds$fold_review$rationale_code,fixed=TRUE))
    phase19_production_abort("production_recipe_not_approved","The exact v2 prior-selection recipe must be included in owner fold review")
  audit<-phase19_club_rating_component_audit(snapshot,current,snapshot$matches)
  if(!isTRUE(audit$coverage_passed) || audit$current_club_count != 36L)
    phase19_production_abort("current_ucl_identity_incomplete","All 36 accepted current clubs must have history in one connected rating component")
  invisible(audit)
}

phase19_production_execute_folds <- function(snapshot,current,protocol,folds,run_label,
    cache_root,progress=function(message)message(message),use_cache=TRUE,hashes_only=FALSE) {
  parents<-phase19_production_parent_identity(snapshot,current,protocol,folds)
  parent_hash<-phase19_production_hash(parents,"execution-parents")
  cache<-file.path(cache_root,parent_hash,run_label)
  dir.create(cache,recursive=TRUE,showWarnings=FALSE)
  result<-vector("list",nrow(folds$fold_registry))
  for(i in seq_len(nrow(folds$fold_registry))) {
    fold<-folds$fold_registry[i,,drop=FALSE]
    path<-file.path(cache,paste0(phase19_production_hash(fold$row_sha256,"fold-cache"),".rds"))
    stored<-if(isTRUE(use_cache) && file.exists(path))tryCatch(readRDS(path),error=function(e)NULL)else NULL
    if(!is.null(stored) && identical(stored$parents,parents) &&
       identical(stored$fold$execution_sha256,phase19_production_fold_identity(stored$fold))) {
      result[[i]]<-stored$fold
      progress(paste(run_label,"reusing completed fold",i,"of",nrow(folds$fold_registry)))
    } else {
      result[[i]]<-phase19_production_one_fold(snapshot,current,protocol,fold,progress)
      saveRDS(list(parents=parents,fold=result[[i]]),path,version=3)
    }
    if(isTRUE(hashes_only))result[[i]]<-result[[i]]$execution_sha256
  }
  names(result)<-as.character(folds$fold_registry$fold_id)
  result
}

phase19_production_isolated_folds <- function(snapshot,current,protocol,folds,run_label,cache_root,hashes_only=FALSE) {
  if(!requireNamespace("callr",quietly=TRUE))
    phase19_production_abort("production_dependency_missing","callr is required for fresh-process evaluation replay")
  callr::r(function(root,snapshot,current,protocol,folds,run_label,cache_root,hashes_only) {
    setwd(root)
    dependencies<-c("R/common/phase18_canonical_hash.R","R/competition/source_contracts.R",
      "R/competition/ucl_source_acceptance.R","R/competition/edition_registry.R",
      "R/club/identity.R","R/club/identity_bootstrap.R","R/competition/football_data_org_adapter.R",
      "R/competition/ucl_source_bundle.R","R/competition/ucl_source_refresh.R","R/club/history_contract.R",
      "R/evaluation/proper_scores.R","R/evaluation/benchmark_scores.R","R/release/domain_contract.R",
      "R/club/model_contract.R","R/club/evaluation_protocol.R","R/club/clubelo.R","R/club/rating.R",
      "R/club/goal_model.R","R/club/calibration.R","R/club/evaluation.R","R/club/release.R","R/club/production_runner.R")
    for(path in dependencies)source(path,local=.GlobalEnv)
    result<-phase19_production_execute_folds(snapshot,current,protocol,folds,run_label,cache_root,
      progress=function(message)cat(paste0("PHASE19_PROGRESS ",message,"\n")),hashes_only=hashes_only)
    list(folds=result,process_id=as.integer(Sys.getpid()),r_version=as.character(getRversion()))
  },args=list(root=.phase19_club_project_root,snapshot=snapshot,current=current,protocol=protocol,
    folds=folds,run_label=run_label,cache_root=cache_root,hashes_only=hashes_only),show=TRUE,spinner=FALSE)
}

phase19_production_final_refit <- function(snapshot,current,protocol,folds,selected,progress=function(...)NULL) {
  # Final temperature/selection use the latest reviewed rolling-origin fold;
  # every one of those labels precedes this final full-history refit cutoff.
  registry<-folds$fold_registry
  eligible<-which(registry$fold_family=="rolling_origin_league_season")
  order_ids<-order(registry$assessment_start_utc[eligible],registry$fold_id[eligible],method="radix")
  index<-eligible[tail(order_ids,1L)]
  fold<-registry[index,,drop=FALSE]
  roles<-phase19_production_role_inventory(snapshot,fold)
  prior<-phase19_production_one_fold(snapshot,current,protocol,fold,progress)
  supported<-if(identical(selected,"club_elo_nb"))prior$candidate else prior$incumbent
  tuning<-prior$tuning
  eligible_rows<-phase19_club_goal_eligible_history(snapshot,snapshot$cutoff_utc)$rows
  if(max(supported$view_selection$latest_selection_evidence) >= snapshot$cutoff_utc)
    phase19_production_abort("final_refit_leakage","Final selection evidence is not strictly prior")
  rating<-phase19_production_rating(eligible_rows,tuning$parameters,snapshot$cutoff_utc)
  registration<-protocol$candidate_registry[protocol$candidate_registry$model_id==selected,,drop=FALSE]
  fit<-phase19_production_fit(eligible_rows,rating,tuning$parameters,registration,snapshot,current,protocol,snapshot$cutoff_utc)
  lineage<-list(schema_version="phase19-club-final-refit-v2",model_id=selected,
    fit_sha256=fit$fit_sha256,training_snapshot_sha256=snapshot$snapshot_sha256,
    current_snapshot_sha256=current$snapshot_sha256,protocol_sha256=protocol$protocol_sha256,
    training_fixture_ids=sort(eligible_rows$match_id,method="radix"),cutoff_exclusive=snapshot$cutoff_utc,
    parameter_sha256=tuning$parameters$parameter_sha256,tuning=prior$tuning,
    calibration_fold_id=fold$fold_id,calibration_source=supported$calibration_source,
    temperature_fold=supported$temperature_fold,view_selection=supported$view_selection,
    calibrator_sha256=supported$calibrator$calibrator_sha256,
    recipe_sha256=phase19_production_recipe()$recipe_sha256)
  lineage$lineage_sha256<-phase19_production_hash(lineage,"final-refit-lineage")
  list(model=fit,calibrator=supported$calibrator,rating_parameters=tuning$parameters,
    primary_probability_view=supported$view_selection$primary_probability_view,lineage=lineage)
}

phase19_production_integrity <- function(fold_results,snapshot,current,protocol,folds,first_hash,second_hash,fresh_current=NULL) {
  probability<-distribution<-cutoff<-identity<-feature<-TRUE
  for(result in fold_results) {
    expected<-phase19_production_role_inventory(snapshot,result$fold)
    if(!identical(result$role_ids,lapply(expected[c("fit","temperature","selection","assessment")],
        function(rows)sort(rows$match_id,method="radix")))) cutoff<-FALSE
    for(a in result[c("candidate","incumbent")]) {
      phase19_validate_club_goal_fit(a$fit)
      phase19_validate_club_calibrator(a$calibrator,require_fitted=TRUE)
      p<-as.matrix(a$predictions[,c("p_home","p_draw","p_away")])
      probability<-probability && all(is.finite(p)) && all(p>=0) && all(p<=1) && all(abs(rowSums(p)-1)<1e-10)
      distribution<-distribution && a$fit$support_min==0L && a$fit$support_max==40L &&
        a$fit$theta>0 && all(is.finite(a$raw_predictions$expected_home_goals)) &&
        all(a$raw_predictions$expected_home_goals>0) && all(a$raw_predictions$expected_away_goals>0) &&
        identical(a$fit$tail_policy,"truncate_0_40_then_joint_renormalize_once")
      cutoff<-cutoff && a$fit$max_evidence_available_at_utc<a$fit$cutoff_utc &&
        a$fit$max_completion_not_before_utc<a$fit$cutoff_utc &&
        a$calibrator$max_evidence_available_at_utc<a$calibrator$calibration_cutoff_exclusive &&
        a$view_selection$latest_selection_evidence<result$fold$calibration_cutoff_exclusive &&
        !length(intersect(a$view_selection$selection_fixture_ids,result$role_ids$assessment))
      identity<-identity && identical(sort(a$predictions$fixture_id,method="radix"),result$role_ids$assessment) &&
        identical(a$fit$training_fixture_sha256,result$fold$training_fixture_sha256) &&
        identical(a$fit$excluded_competition_id,result$fold$held_out_competition_id)
      feature<-feature && identical(a$fit$active_features,phase19_club_goal_active_features(a$fit$model_id))
    }
  }
  # The source and license flags follow independent accepted-snapshot validators,
  # rather than caller-provided scalar assertions.
  phase19_validate_club_training_snapshot(snapshot,"production")
  if(is.null(fresh_current))phase19_validate_current_ucl_club_snapshot(current,"production") else
    phase19_production_validate_frozen_current(current,fresh_current)
  phase19_validate_feature_contract(protocol$feature_contract)
  phase19_validate_seed_registry(protocol$seed_registry)
  audit<-phase19_club_rating_component_audit(snapshot,current,snapshot$matches)
  list(current_ucl_club_coverage=as.numeric(audit$missing_current_club_count==0L && audit$current_club_count==36L),
    common_rating_component_coverage=as.numeric(isTRUE(audit$coverage_passed)),
    byte_reproducibility=as.numeric(identical(first_hash,second_hash)),
    probability_integrity=as.numeric(probability),distribution_integrity=as.numeric(distribution),
    cutoff_integrity=as.numeric(cutoff),identity_integrity=as.numeric(identity),source_integrity=1,license_integrity=1,
    feature_integrity=as.numeric(feature),seed_integrity=1,
    checksum_integrity=as.numeric(all(vapply(fold_results,function(x)identical(x$execution_sha256,phase19_production_fold_identity(x)),logical(1)))),
    domain_integrity=as.numeric(identical(snapshot$model_domain,"club") && identical(current$model_domain,"club")),
    model_card_integrity=as.numeric(all(vapply(fold_results,function(r)all(vapply(r[c("candidate","incumbent")],function(a)isTRUE(a$fit$converged),logical(1))),logical(1)))))
}

phase19_production_decision <- function(metrics,protocol) {
  gates<-phase19_apply_club_promotion_gates(metrics,protocol,"production")
  comparison<-protocol$gate_registry$applicability=="candidate_vs_club_venue_nb"
  # Data, coverage, reproducibility and integrity gates apply equally when
  # retaining the predeclared incumbent. Relative superiority gates do not.
  absolute_pass<-all(gates$passed[!comparison])
  candidate_pass<-all(gates$passed)
  selected<-if(candidate_pass)"club_elo_nb" else "club_venue_nb"
  result<-list(schema_version="phase19-club-production-decision-v2",forecast_domain="club",
    authority_mode="production",fixture_authority=FALSE,candidate_id="club_elo_nb",incumbent_id="club_venue_nb",
    selected_model_id=selected,diagnostic_gate_outcome=if(candidate_pass)"pass" else "fail",
    authority_eligibility=if(absolute_pass)"production" else "production_blocked",
    promotion_status=if(!absolute_pass)"blocked" else if(candidate_pass)"promoted" else "retained",
    absolute_gates_passed=absolute_pass,gates=gates,metrics=metrics,
    failed_gate_ids=gates$gate_id[!gates$passed],protocol_sha256=protocol$protocol_sha256)
  result$decision_sha256<-phase19_production_hash(result,"production-decision")
  result
}

phase19_run_club_production_pipeline <- function(progress=function(message)message(message)) {
  snapshot<-phase19_load_club_training_snapshot()
  if(!identical(snapshot$status,"ready"))phase19_production_abort("no_accepted_club_history","Historical source and identity review is required")
  current<-phase19_load_current_ucl_club_snapshot()
  if(!identical(current$status,"ready"))phase19_production_abort("no_accepted_current_ucl","Current UCL source and identities are required")
  protocol<-phase19_load_club_evaluation_protocol()
  if(!identical(protocol$status,"ready"))phase19_production_abort("protocol_policy_not_approved","Owner policy review is required")
  folds<-phase19_load_club_fold_protocol()
  if(!identical(folds$status,"ready"))phase19_production_abort(
    if(is.null(folds$reason_code)||!nzchar(folds$reason_code))"fold_inventory_not_approved"else folds$reason_code,
    "Owner review of the exact historical fold inventory is required")
  phase19_production_assert_parents(snapshot,current,protocol,folds)
  root<-file.path(.phase19_club_project_root,"outputs","club_model","production")
  dir.create(root,recursive=TRUE,showWarnings=FALSE)
  phase19_production_recipe_write(file.path(root,"production_recipe_v2.json"))
  isolated_a<-phase19_production_isolated_folds(snapshot,current,protocol,folds,"run-a",file.path(root,"checkpoints"))
  isolated_b<-phase19_production_isolated_folds(snapshot,current,protocol,folds,"run-b",file.path(root,"checkpoints"),hashes_only=TRUE)
  first<-isolated_a$folds;second<-isolated_b$folds
  first_hash<-phase19_production_hash(vapply(first,`[[`,character(1),"execution_sha256"),"full-production-execution")
  second_hashes<-vapply(second,identity,character(1))
  second_hash<-phase19_production_hash(second_hashes,"full-production-execution")
  summaries<-do.call(rbind,lapply(first,`[[`,"summary"));rownames(summaries)<-NULL
  bootstrap<-phase19_club_evaluation_bootstrap(summaries$rps_delta,
    phase19_club_evaluation_seed(protocol,"club_paired_bootstrap_v1")$seed[[1L]],10000L)
  metrics<-phase19_club_evaluation_metrics_from_summaries(summaries,bootstrap)
  integrity<-phase19_production_integrity(first,snapshot,current,protocol,folds,first_hash,second_hash)
  metrics[names(integrity)]<-integrity
  decision<-phase19_production_decision(metrics,protocol)
  evidence<-list(schema_version="phase19-club-production-evaluation-v2",forecast_domain="club",authority_mode="production",
    fixture_authority=FALSE,parents=phase19_production_parent_identity(snapshot,current,protocol,folds),
    frozen_current_snapshot=current,
    recipe=phase19_production_recipe(),fold_results=first,fold_summaries=summaries,paired_bootstrap=bootstrap,
    first_execution_sha256=first_hash,second_execution_sha256=second_hash,
    isolated_execution=list(run_a_process_id=isolated_a$process_id,run_b_process_id=isolated_b$process_id,
      r_version=isolated_a$r_version,run_count=2L),
    second_fold_execution_sha256=second_hashes,integrity=integrity,decision=decision)
  evidence$evaluation_sha256<-phase19_production_evaluation_identity(evidence)
  saveRDS(evidence,file.path(root,"evaluation.rds"),version=3)
  utils::write.csv(summaries,file.path(root,"fold_metrics.csv"),row.names=FALSE)
  utils::write.csv(decision$gates,file.path(root,"promotion_gates.csv"),row.names=FALSE)
  if(!isTRUE(decision$absolute_gates_passed))return(list(status="blocked",reason_code="production_absolute_gates_failed",decision=decision,evidence=evidence,release_mutated=FALSE,selector_mutated=FALSE))
  progress(paste("Final full-history refit of",decision$selected_model_id))
  refit_a<-phase19_production_final_refit(snapshot,current,protocol,folds,decision$selected_model_id,progress)
  refit_b<-phase19_production_final_refit(snapshot,current,protocol,folds,decision$selected_model_id,progress)
  refit_identity<-function(x)phase19_production_hash(list(fit=x$model$fit_sha256,calibrator=x$calibrator$calibrator_sha256,
    lineage=x$lineage$lineage_sha256,view=x$primary_probability_view),"final-refit-execution")
  if(!identical(refit_identity(refit_a),refit_identity(refit_b)))phase19_production_abort("byte_reproducibility_failed","Final fit/calibration/tuning reruns differed")
  release<-phase19_install_club_production_v2(evidence,refit_a,snapshot,current,protocol,folds)
  list(status="ready",reason_code="",decision=decision,evidence=evidence,release=release,release_mutated=TRUE,selector_mutated=TRUE)
}

phase19_validate_club_production_v2 <- function(evidence, refit, snapshot, current, protocol, folds,
    verify_fold_predictions=TRUE) {
  fresh_current<-current
  current<-evidence$frozen_current_snapshot
  phase19_production_assert_parents(snapshot,current,protocol,folds,fresh_current=fresh_current)
  if(!identical(evidence$schema_version,"phase19-club-production-evaluation-v2") ||
      !identical(evidence$parents,phase19_production_parent_identity(snapshot,current,protocol,folds)) ||
      !identical(evidence$recipe,phase19_production_recipe()) ||
      !identical(evidence$evaluation_sha256,phase19_production_evaluation_identity(evidence)))
    phase19_production_abort("production_evidence_invalid","Production evidence parents, recipe, code or checksum changed")
  if(!identical(names(evidence$fold_results),as.character(folds$fold_registry$fold_id)))
    phase19_production_abort("fold_inventory_invalid","Evaluation does not cover the complete reviewed fold inventory")
  pids<-c(evidence$isolated_execution$run_a_process_id,evidence$isolated_execution$run_b_process_id)
  if(!is.integer(pids) || length(pids)!=2L || anyNA(pids) || any(pids<=0L) ||
     !identical(evidence$isolated_execution$run_count,2L) ||
     identical(evidence$isolated_execution$run_a_process_id,evidence$isolated_execution$run_b_process_id))
    phase19_production_abort("byte_reproducibility_failed","Evaluation replay did not use two separate fresh R processes")
  for(i in seq_along(evidence$fold_results)) {
    r<-evidence$fold_results[[i]]
    if(!identical(r$fold,folds$fold_registry[i,,drop=FALSE]) ||
       !identical(r$execution_sha256,phase19_production_fold_identity(r)))
      phase19_production_abort("production_evidence_invalid","Frozen fold content or execution identity drifted")
    roles<-phase19_production_role_inventory(snapshot,r$fold)
    expected_summary<-phase19_production_summary(r$fold,roles,r[c("candidate","incumbent")])
    if(!identical(r$summary,expected_summary))
      phase19_production_abort("assessment_summary_invalid","Stored fold summary differs from paired predictions and accepted outcomes")
    if(isTRUE(verify_fold_predictions)) {
      forward<-rbind(roles$temperature,roles$selection,roles$assessment)
      rating<-phase19_production_rating(roles$fit,r$tuning$parameters,r$fold$training_cutoff_exclusive,forward)
      for(a in r[c("candidate","incumbent")]) {
        if(!identical(a$fit$training_snapshot_sha256,snapshot$snapshot_sha256) ||
           !identical(a$fit$current_snapshot_sha256,current$snapshot_sha256) ||
           !identical(a$fit$protocol_sha256,protocol$protocol_sha256))
          phase19_production_abort("fit_parent_invalid","Outer fit is not bound to accepted production parents")
        scoped_rating<-rating;scoped_rating$forward_difference<-numeric()
        expected_fit<-phase19_production_fit(roles$fit,scoped_rating,r$tuning$parameters,a$fit$registration,
          snapshot,current,protocol,r$fold$training_cutoff_exclusive,r$fold$held_out_competition_id)
        if(!identical(a$fit$fit_sha256,expected_fit$fit_sha256))
          phase19_production_abort("fit_parameters_invalid","Stored NB parameters differ from an independent fit of exact scoped rows")
        long<-phase19_club_goal_long_training(roles$fit,data.frame(rating_difference=rating$training_difference),a$fit$active_features)
        expected_data<-long[,setdiff(names(long),"match_id"),drop=FALSE]
        if(!isTRUE(all.equal(a$fit$model$model,expected_data,tolerance=0,check.attributes=FALSE)))
          phase19_production_abort("fit_role_invalid","Stored model was fitted on different goal/rating rows")
        predictions<-phase19_production_prediction(a$fit,forward,rating$forward_difference,r$fold$training_cutoff_exclusive)
        source<-phase19_production_temperature_source(predictions[match(roles$temperature$match_id,predictions$fixture_id),,drop=FALSE],
          roles$temperature,a$temperature_fold,a$fit$model_id)
        phase19_validate_club_calibrator_source(a$calibrator,source,a$temperature_fold,a$fit$registration,protocol,require_production=TRUE)
        selection<-predictions[match(roles$selection$match_id,predictions$fixture_id),,drop=FALSE]
        expected_choice<-phase19_production_select_view(selection,a$calibrator,roles$selection,protocol)
        if(!identical(a$calibration_source,source) || !identical(a$view_selection,expected_choice))
          phase19_production_abort("view_selection_invalid","Calibration or probability view is not derived from its prior partition")
        raw<-predictions[match(roles$assessment$match_id,predictions$fixture_id),,drop=FALSE]
        chosen<-if(identical(expected_choice$primary_probability_view,"calibrated_1x2"))phase19_production_transform(raw,a$calibrator)else raw
        if(!identical(a$raw_predictions,raw) || !identical(a$predictions,chosen) ||
           !identical(a$scores,phase19_production_scores(chosen,phase19_production_class(roles$assessment))))
          phase19_production_abort("assessment_invalid","Assessment probabilities or scores differ from the frozen prior model/view")
      }
    }
  }
  first<-phase19_production_hash(vapply(evidence$fold_results,`[[`,character(1),"execution_sha256"),"full-production-execution")
  second<-phase19_production_hash(evidence$second_fold_execution_sha256,"full-production-execution")
  integrity<-phase19_production_integrity(evidence$fold_results,snapshot,current,protocol,folds,first,second,fresh_current=fresh_current)
  summaries<-do.call(rbind,lapply(evidence$fold_results,`[[`,"summary"));rownames(summaries)<-NULL
  bootstrap<-phase19_club_evaluation_bootstrap(summaries$rps_delta,
    phase19_club_evaluation_seed(protocol,"club_paired_bootstrap_v1")$seed[[1L]],10000L)
  metrics<-phase19_club_evaluation_metrics_from_summaries(summaries,bootstrap)
  metrics[names(integrity)]<-integrity
  expected_decision<-phase19_production_decision(metrics,protocol)
  if(!identical(evidence$first_execution_sha256,first) || !identical(evidence$second_execution_sha256,second) ||
     !identical(evidence$decision,expected_decision) || !isTRUE(expected_decision$absolute_gates_passed))
    phase19_production_abort("production_gates_failed","Production decision fails immutable absolute/integrity gates")
  phase19_validate_club_goal_fit(refit$model)
  phase19_validate_club_calibrator(refit$calibrator,require_fitted=TRUE)
  lineage<-refit$lineage
  supported_fold<-evidence$fold_results[[as.character(lineage$calibration_fold_id)]]
  supported<-if(identical(expected_decision$selected_model_id,"club_elo_nb"))supported_fold$candidate else supported_fold$incumbent
  if(is.null(supported) || !identical(lineage$calibration_source,supported$calibration_source) ||
     !identical(lineage$temperature_fold,supported$temperature_fold) ||
     !identical(lineage$view_selection,supported$view_selection) ||
     !identical(refit$calibrator,supported$calibrator) ||
     !identical(lineage$tuning,supported_fold$tuning) ||
     !identical(refit$rating_parameters,supported_fold$tuning$parameters))
    phase19_production_abort("final_refit_invalid","Final calibration/selection/parameters differ from the evaluated prior lineage")
  if(!identical(lineage$lineage_sha256,phase19_production_hash(lineage[setdiff(names(lineage),"lineage_sha256")],"final-refit-lineage")) ||
     !identical(lineage$fit_sha256,refit$model$fit_sha256) ||
     !identical(lineage$calibrator_sha256,refit$calibrator$calibrator_sha256) ||
     !identical(refit$model$model_id,expected_decision$selected_model_id) ||
     !identical(refit$model$training_snapshot_sha256,snapshot$snapshot_sha256) ||
     !identical(refit$model$current_snapshot_sha256,current$snapshot_sha256) ||
     !identical(refit$model$protocol_sha256,protocol$protocol_sha256) ||
     !identical(refit$model$cutoff_utc,snapshot$cutoff_utc) ||
     !identical(refit$model$rating_parameters,refit$rating_parameters) ||
     !identical(refit$primary_probability_view,lineage$view_selection$primary_probability_view) ||
     !isTRUE(refit$model$production_eligible) || !isTRUE(refit$calibrator$production_eligible))
    phase19_production_abort("final_refit_invalid","Final full-history model, calibration and selected lineage do not agree")
  rows<-phase19_club_goal_eligible_history(snapshot,snapshot$cutoff_utc)$rows
  if(!identical(lineage$training_fixture_ids,sort(rows$match_id,method="radix")) ||
      !identical(refit$model$training_fixture_sha256,phase19_fold_id_sha256(lineage$training_fixture_ids,"training")))
    phase19_production_abort("final_refit_invalid","Final fit is not an exact full eligible-history refit")
  if(isTRUE(verify_fold_predictions)) {
    rating<-phase19_production_rating(rows,refit$rating_parameters,snapshot$cutoff_utc)
    expected_fit<-phase19_production_fit(rows,rating,refit$rating_parameters,refit$model$registration,
      snapshot,current,protocol,snapshot$cutoff_utc)
    if(!identical(refit$model$fit_sha256,expected_fit$fit_sha256))
      phase19_production_abort("final_refit_invalid","Final parameters differ from independently refitted full-history NB parameters")
    long<-phase19_club_goal_long_training(rows,data.frame(rating_difference=rating$training_difference),refit$model$active_features)
    if(!isTRUE(all.equal(refit$model$model$model,long[,setdiff(names(long),"match_id"),drop=FALSE],tolerance=0,check.attributes=FALSE)))
      phase19_production_abort("final_refit_invalid","Final goal fit rows differ from exact eligible-history ratings")
  }
  invisible(TRUE)
}

phase19_install_club_production_v2 <- function(evidence,refit,snapshot,current,protocol,folds) {
  # Independently regenerate source-backed predictions before touching selector.
  phase19_validate_club_production_v2(evidence,refit,snapshot,current,protocol,folds)
  root<-phase19_club_release_production_root()
  dir.create(root,recursive=TRUE,showWarnings=FALSE)
  lock<-file.path(root,".approved_release_v2.lock")
  if(!dir.create(lock,showWarnings=FALSE))phase19_production_abort("selector_locked","Another production publisher holds the selector lock")
  on.exit(unlink(lock,recursive=TRUE,force=TRUE),add=TRUE)
  release_id<-paste0("club-v2-",substr(phase19_production_hash(list(evidence=evidence$evaluation_sha256,
    lineage=refit$lineage$lineage_sha256),"production-release"),1,24))
  final<-file.path(root,release_id)
  stage<-tempfile(".club-v2-stage-",tmpdir=root)
  dir.create(stage);on.exit(if(dir.exists(stage))unlink(stage,recursive=TRUE,force=TRUE),add=TRUE)
  dir.create(file.path(stage,"model"));dir.create(file.path(stage,"reports"))
  saveRDS(refit$model,file.path(stage,"model","approved_model.rds"),version=3)
  saveRDS(refit$calibrator,file.path(stage,"model","calibrator.rds"),version=3)
  saveRDS(list(evidence=evidence,refit=refit),file.path(stage,"production_evidence.rds"),version=3)
  utils::write.csv(evidence$fold_summaries,file.path(stage,"reports","fold_metrics.csv"),row.names=FALSE)
  utils::write.csv(evidence$decision$gates,file.path(stage,"reports","promotion_gates.csv"),row.names=FALSE)
  card<-c("# Club forecast model",paste("Selected model:",refit$model$model_id),
    paste("Decision:",evidence$decision$promotion_status),paste("Historical matches:",refit$model$fit_row_count),
    paste("Final exclusive cutoff:",refit$model$cutoff_utc),paste("Primary view:",refit$primary_probability_view),
    "Model family: independent negative-binomial home/away goals; complete 0–40 joint support, renormalized once.",
    "Calibration and probability-view selection use separate strictly prior windows. Assessment labels never select parameters or views.",
    "Ratings use simultaneous kickoff batches with results applied only after completion and evidence availability.",
    "All 36 current UCL clubs have accepted history in one connected component.",
    "Limitations: historical results contain no xG, injuries, lineups or odds; goal expectations and score/binary markets remain uncalibrated NB outputs.",
    "Future predictions require approved pre-kickoff current fixtures and explicit supported venue semantics.",
    paste("Production recipe:",evidence$recipe$recipe_sha256))
  writeLines(card,file.path(stage,"reports","model_card.md"),useBytes=TRUE)
  contract<-list(schema_version="phase19-club-release-v2",forecast_domain="club",entity_kind="club",authority_mode="production",
    fixture_authority=FALSE,production_eligible=TRUE,release_id=release_id,selected_model_id=refit$model$model_id,
    candidate_id="club_elo_nb",incumbent_id="club_venue_nb",diagnostic_gate_outcome=evidence$decision$diagnostic_gate_outcome,
    authority_eligibility="production",promotion_status=evidence$decision$promotion_status,
    history_generation_id=snapshot$accepted_generation_id,history_snapshot_sha256=snapshot$snapshot_sha256,
    current_ucl_snapshot_sha256=current$snapshot_sha256,protocol_sha256=protocol$protocol_sha256,
    policy_review_sha256=protocol$policy_review$review_sha256,fold_registry_sha256=folds$fold_registry_sha256,
    fold_review_sha256=folds$fold_review$review_sha256,gate_registry_sha256=protocol$gate_registry_sha256,
    seed_registry_sha256=protocol$seed_registry_sha256,evaluation_set_sha256=evidence$evaluation_sha256,
    promotion_decision_sha256=evidence$decision$decision_sha256,model_artifact="model/approved_model.rds",
    model_sha256=phase19_club_release_file_sha256(file.path(stage,"model","approved_model.rds")),
    calibrator_artifact="model/calibrator.rds",calibrator_sha256=phase19_club_release_file_sha256(file.path(stage,"model","calibrator.rds")),
    score_support_g=40L,primary_probability_view=refit$primary_probability_view,feature_contract_sha256=protocol$feature_contract_sha256,
    unavailable_feature_ids=refit$model$unavailable_feature_ids,labels_embedded=FALSE,
    final_refit_sha256=refit$lineage$lineage_sha256,production_recipe_sha256=evidence$recipe$recipe_sha256,
    code_sha256=evidence$parents$code_sha256,fit_sha256=refit$model$fit_sha256,
    fitted_calibrator_sha256=refit$calibrator$calibrator_sha256)
  jsonlite::write_json(contract,file.path(stage,"model_contract.json"),auto_unbox=TRUE,pretty=TRUE,digits=17)
  files<-sort(list.files(stage,recursive=TRUE),method="radix")
  manifest<-data.frame(schema_version="phase19-club-release-manifest-v2",forecast_domain="club",release_id=release_id,
    relative_path=files,bytes=as.character(file.info(file.path(stage,files))$size),
    sha256=vapply(file.path(stage,files),phase19_club_release_file_sha256,character(1)),stringsAsFactors=FALSE)
  utils::write.csv(manifest,file.path(stage,"release_manifest.csv"),row.names=FALSE)
  phase19_validate_club_production_release_v2(stage,validate_authority=TRUE)
  if(dir.exists(final)) {
    existing<-phase19_validate_club_production_release_v2(final,validate_authority=TRUE)
    if(!identical(existing$model_contract$final_refit_sha256,contract$final_refit_sha256))
      phase19_production_abort("immutable_release_conflict","Existing immutable release differs")
  } else if(!file.rename(stage,final))phase19_production_abort("release_install_failed","Could not atomically install immutable release")
  phase19_club_release_write_selector(root,release_id,paste0(release_id,"/release_manifest.csv"),
    phase19_club_release_file_sha256(file.path(final,"release_manifest.csv")))
  phase19_resolve_production_club_release()
}

phase19_validate_club_production_release_v2 <- function(root,validate_authority=TRUE,load_models=TRUE) {
  root<-phase19_club_release_real_root(root)
  manifest_path<-file.path(root,"release_manifest.csv")
  manifest<-utils::read.csv(manifest_path,stringsAsFactors=FALSE,colClasses="character",check.names=FALSE)
  if(!identical(names(manifest),c("schema_version","forecast_domain","release_id","relative_path","bytes","sha256")) ||
      !nrow(manifest) || anyNA(manifest) || anyDuplicated(manifest$relative_path) ||
      any(manifest$schema_version!="phase19-club-release-manifest-v2") || any(manifest$forecast_domain!="club"))
    phase19_production_abort("release_manifest_invalid","Invalid v2 production release manifest")
  required<-c("model_contract.json","model/approved_model.rds","model/calibrator.rds","production_evidence.rds", "reports/model_card.md","reports/fold_metrics.csv","reports/promotion_gates.csv")
  if(!setequal(required,manifest$relative_path) ||
      !setequal(c(required,"release_manifest.csv"),list.files(root,recursive=TRUE)))
    phase19_production_abort("release_manifest_invalid","Production artifact inventory differs from the complete required set")
  for(i in seq_len(nrow(manifest))) {
    path<-phase19_club_release_path_under_root(root,manifest$relative_path[[i]],must_work=TRUE)
    if(!identical(phase19_club_release_file_sha256(path),manifest$sha256[[i]]) ||
       !identical(as.character(file.info(path)$size),manifest$bytes[[i]]))
      phase19_production_abort("release_checksum_invalid","Production release bytes drifted")
  }
  contract<-jsonlite::read_json(file.path(root,"model_contract.json"),simplifyVector=TRUE)
  if(!identical(contract$schema_version,"phase19-club-release-v2") || !identical(contract$forecast_domain,"club") ||
     !identical(contract$authority_mode,"production") || isTRUE(contract$fixture_authority) || !isTRUE(contract$production_eligible) ||
     !contract$promotion_status %in% c("promoted","retained") || !identical(contract$authority_eligibility,"production") ||
     !identical(contract$model_artifact,"model/approved_model.rds") || !identical(contract$calibrator_artifact,"model/calibrator.rds") ||
     !identical(contract$model_sha256,manifest$sha256[manifest$relative_path==contract$model_artifact]) ||
     !identical(contract$calibrator_sha256,manifest$sha256[manifest$relative_path==contract$calibrator_artifact]) ||
     !all(manifest$release_id==contract$release_id))
    phase19_production_abort("release_contract_invalid","Production model contract is invalid")
  if(!isTRUE(load_models))return(list(model=NULL,calibrator=NULL,model_contract=contract,
    release_manifest=manifest,release_root=root))
  # Metadata and byte inventory are validated before any RDS is deserialized.
  bundle<-readRDS(file.path(root,"production_evidence.rds"))
  model<-readRDS(file.path(root,contract$model_artifact));calibrator<-readRDS(file.path(root,contract$calibrator_artifact))
  if(!identical(bundle$refit$model,model) || !identical(bundle$refit$calibrator,calibrator) ||
     !identical(model$fit_sha256,contract$fit_sha256) || !identical(calibrator$calibrator_sha256,contract$fitted_calibrator_sha256) ||
     !identical(contract$primary_probability_view,bundle$refit$primary_probability_view) ||
     !identical(contract$selected_model_id,model$model_id) || !identical(contract$final_refit_sha256,bundle$refit$lineage$lineage_sha256))
    phase19_production_abort("release_lineage_invalid","Published model/calibrator differ from final refit lineage")
  if(isTRUE(validate_authority)) {
    snapshot<-phase19_load_club_training_snapshot();current<-phase19_load_current_ucl_club_snapshot()
    protocol<-phase19_load_club_evaluation_protocol();folds<-phase19_load_club_fold_protocol()
    phase19_validate_club_production_v2(bundle$evidence,bundle$refit,snapshot,current,protocol,folds,verify_fold_predictions=FALSE)
  }
  list(model=model,calibrator=calibrator,model_contract=contract,release_manifest=manifest,
    rating_parameters=bundle$refit$rating_parameters,release_root=root)
}

phase19_resolve_club_production_v2 <- function(trusted_root,selector_path=NULL) {
  if(!identical(normalizePath(trusted_root,winslash="/",mustWork=FALSE),phase19_club_release_production_root()))
    phase19_production_abort("production_root_invalid","Production resolver requires the fixed club release root")
  if(is.null(selector_path))selector_path<-file.path(trusted_root,"approved_release.csv")
  selected<-phase19_read_club_selector(selector_path,trusted_root,"club")
  resolved<-phase19_validate_club_production_release_v2(selected$release_root)
  fresh<-phase19_read_club_selector(selector_path,trusted_root,"club")
  if(!identical(selected$selector,fresh$selector))phase19_production_abort("selector_changed_during_resolution","Production selector changed during validation")
  c(resolved,list(release_id=selected$release_id,selector=fresh$selector,
    release_manifest_path=selected$release_manifest_path,forecast_domain="club",metadata=resolved$model_contract))
}
