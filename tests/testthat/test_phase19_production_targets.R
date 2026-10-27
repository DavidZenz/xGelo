library(testthat)
production_targets_root<-normalizePath(file.path(getwd(),if(basename(getwd())=="testthat")"../.."else"."))

production_targets_test_pending <- function(reason,before) {
  helpers<-new.env(parent=.GlobalEnv)
  for(expression in parse(file.path(production_targets_root,"_targets.R"))) {
    if(is.call(expression) && identical(expression[[1L]],as.name("<-")) &&
       is.symbol(expression[[2L]]) && startsWith(as.character(expression[[2L]]),"phase19_targets_"))
      eval(expression,envir=helpers)
  }
  calls<-0L
  original_run<-phase19_run_club_production_pipeline
  original_resolve<-phase19_resolve_production_club_release
  on.exit({
    assign("phase19_run_club_production_pipeline",original_run,envir=.GlobalEnv)
    assign("phase19_resolve_production_club_release",original_resolve,envir=.GlobalEnv)
  },add=TRUE)
  sentinel<-function(...) {
    calls<<-calls+1L
    stop("Production evaluation/resolution must not run before all parent approvals")
  }
  assign("phase19_run_club_production_pipeline",sentinel,envir=.GlobalEnv)
  assign("phase19_resolve_production_club_release",sentinel,envir=.GlobalEnv)
  state<-helpers$phase19_targets_production_state(list(status="ready"),list(status="ready"),
    list(status="ready"),helpers$phase19_targets_blocked(reason))
  expect_identical(state$status,"blocked")
  expect_true(state$reason_code%in%c("protocol_policy_not_approved","fold_inventory_not_approved"))
  expect_identical(calls,0L)
  expect_identical(file.exists("outputs/releases/club/approved_release.csv"),before)
}

test_that("production targets expose the accepted runtime folds and stable roster execution",{
  withr::local_dir(production_targets_root)
  manifest<-targets::tar_manifest(fields=c(name,command,format),callr_function=NULL,script="_targets.R")
  command<-function(name)as.character(manifest$command[manifest$name==name])
  expect_true(all(c("club_current_roster_authority","club_production_execution")%in%manifest$name))
  expect_match(command("club_fold_registry_file"),"phase19_targets_fold_files",fixed=TRUE)
  expect_match(command("club_fold_review_file"),"phase19_targets_fold_files",fixed=TRUE)
  expect_match(command("club_production_execution"),"club_current_roster_authority",fixed=TRUE)
  expect_false(grepl("club_current_ucl_authority",command("club_production_execution"),fixed=TRUE))
  expect_match(command("club_production_execution"),"phase19_targets_production_state",fixed=TRUE)
  for(name in c("club_model_candidates","club_fold_predictions","club_fold_scores","club_evaluation_set","club_promotion_decision","club_release_state")) {
    expect_match(command(name),"phase19_targets_production_projection",fixed=TRUE)
    expect_false(grepl("passthrough_block",command(name),fixed=TRUE))
  }
  club<-manifest[grepl("^club_",manifest$name),,drop=FALSE]
  expect_false(any(grepl("phase12_approved_release|national|worldcup|fifa",club$command,ignore.case=TRUE)))
})

test_that("unapproved production parents complete as blocked targets without mutation",{
  withr::local_dir(production_targets_root)
  before<-file.exists("outputs/releases/club/approved_release.csv")
  # A pending runtime state can be tested from its exact metadata without
  # repeatedly validating the large accepted corpus or ever running a writer.
  pending_path<-file.path(phase19_club_fold_runtime_root(),"protocol_current.json")
  history_path<-phase19_club_fixed_history_paths()$current
  if(file.exists(pending_path) && file.exists(history_path)) {
    pointer<-jsonlite::read_json(pending_path,simplifyVector=TRUE)
    generation<-as.character(pointer$generation_id)
    if(length(generation)==1L && grepl("^[A-Za-z0-9._-]+$",generation)) {
      state_path<-file.path(phase19_club_fold_runtime_root(),"generations",generation,"protocol_state.json")
      if(file.exists(state_path)) {
        pending<-phase19_read_json_exact(state_path,phase19_protocol_state_schema(),"protocol_state_invalid")
        history_pointer<-jsonlite::read_json(history_path,simplifyVector=TRUE)
        policy_review<-jsonlite::read_json("data/club/model_protocol/policy_review.json",simplifyVector=TRUE)
        if(identical(pending$state,"pending_review") && identical(history_pointer$acceptance_state,"accepted") &&
           identical(policy_review$decision,"accepted")) {
          expect_silent(phase19_validate_protocol_state(pending))
          expect_identical(pending$state_sha256,as.character(pointer$protocol_state_sha256))
          production_targets_test_pending("fold_inventory_not_approved",before)
          return(invisible(NULL))
        }
      }
    }
  }
  history<-phase19_load_club_training_snapshot()
  policy<-phase19_load_club_evaluation_protocol()
  folds<-phase19_load_club_fold_protocol()
  if(identical(history$status,"ready") && identical(policy$status,"ready") && identical(folds$status,"ready")) {
    # Unit verification must not initiate a second genuine model evaluation.
    expect_identical(history$authority_mode,"production")
    expect_identical(folds$fold_review$decision,"accepted")
    if(isTRUE(before)) {
      release<-phase19_resolve_production_club_release()
      expect_identical(release$forecast_domain,"club")
      expect_true(nzchar(release$release_id))
    }
    expect_identical(file.exists("outputs/releases/club/approved_release.csv"),before)
  } else if(identical(history$status,"ready")) {
    # Accepted production history is read-only test evidence. Exercise the
    # pending-parent branch without allowing tar_make to reach any real writer.
    reason<-if(!identical(policy$status,"ready"))"protocol_policy_not_approved"else "fold_inventory_not_approved"
    production_targets_test_pending(reason,before)
  } else {
    targets::tar_make(names=c("club_release_state","club_selector_state"),callr_function=NULL,reporter="silent",script="_targets.R")
    release<-targets::tar_read(club_release_state)
    selector<-targets::tar_read(club_selector_state)
    if(!isTRUE(before)) {
      expect_identical(release$status,"blocked")
      expect_identical(selector$status,"blocked")
      expect_false(file.exists("outputs/releases/club/approved_release.csv"))
      expect_true(release$reason_code%in%c("no_accepted_club_history","no_accepted_current_ucl","current_ucl_identity_incomplete","protocol_policy_not_approved","fold_inventory_not_approved","production_recipe_not_approved"))
    }
  }
})
