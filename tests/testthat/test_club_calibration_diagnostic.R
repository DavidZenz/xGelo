library(testthat)
diagnostic_test_root<-normalizePath(if(basename(getwd())=="testthat")"../.."else".")
source(file.path(diagnostic_test_root,"scripts/diagnose_club_calibration.R"))

test_that("diagnostic proper scores agree with hand-computed uniform forecasts",{
  p<-data.frame(p_home=rep(1/3,3),p_draw=rep(1/3,3),p_away=rep(1/3,3))
  labels<-c("home","draw","away")
  scores<-club_diag_scores(p,labels)
  expect_equal(mean(scores$rps),2/9,tolerance=1e-12)
  expect_equal(mean(scores$brier),2/3,tolerance=1e-12)
  expect_equal(mean(scores$log_loss),log(3),tolerance=1e-12)
  expect_equal(club_diag_ece(p,labels),0,tolerance=1e-12)
  p$p_home[1]<--.1
  expect_error(club_diag_scores(p,labels))
})

test_that("diagnostic correction changes only intended integrity evidence",{
  ids<-c("proper_score_veto","probability_integrity","distribution_integrity","cutoff_integrity")
  view<-list(metrics=list(probability_integrity=1,distribution_integrity=1,cutoff_integrity=1),
    gates=data.frame(gate_id=ids,value=c(0,0,0,0),threshold=c(.01,1,1,1),passed=c(TRUE,FALSE,FALSE,FALSE)))
  corrected<-club_diag_correct_prior_gates(view)
  expect_identical(corrected$view,"calibrated_1x2")
  expect_equal(corrected$gates$value,c(0,1,1,1))
  expect_identical(view$gates$value,c(0,0,0,0))
  view$gates$passed[1]<-FALSE
  expect_identical(club_diag_correct_prior_gates(view)$view,"raw_1x2")
  view$gates$passed[1]<-TRUE;view$metrics$cutoff_integrity<-FALSE
  expect_identical(club_diag_correct_prior_gates(view)$view,"raw_1x2")
})

test_that("temperature diagnostic preserves identity and normalizes probabilities",{
  p<-data.frame(p_home=c(.7,.1),p_draw=c(.2,.3),p_away=c(.1,.6))
  expect_equal(club_diag_transform(p,1),p,tolerance=1e-12)
  adjusted<-club_diag_transform(p,2)
  expect_equal(rowSums(adjusted),c(1,1),tolerance=1e-12)
  expect_lt(adjusted$p_home[1],p$p_home[1])
  expect_error(club_diag_transform(p,0))
})
