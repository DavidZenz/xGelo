library(testthat)
production_targets_root<-normalizePath(file.path(getwd(),if(basename(getwd())=="testthat")"../.."else"."))

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
  history<-phase19_load_club_training_snapshot()
  policy<-phase19_load_club_evaluation_protocol()
  folds<-phase19_load_club_fold_protocol()
  if(identical(history$status,"ready") && identical(policy$status,"ready") && identical(folds$status,"ready"))
    skip("Production parents are accepted; genuine evaluation runs through the production controller")
  targets::tar_make(names=c("club_release_state","club_selector_state"),callr_function=NULL,reporter="silent",script="_targets.R")
  release<-targets::tar_read(club_release_state)
  selector<-targets::tar_read(club_selector_state)
  if(!isTRUE(before)) {
    expect_identical(release$status,"blocked")
    expect_identical(selector$status,"blocked")
    expect_false(file.exists("outputs/releases/club/approved_release.csv"))
    expect_true(release$reason_code%in%c("no_accepted_club_history","no_accepted_current_ucl","current_ucl_identity_incomplete","protocol_policy_not_approved","fold_inventory_not_approved","production_recipe_not_approved"))
  }
})
