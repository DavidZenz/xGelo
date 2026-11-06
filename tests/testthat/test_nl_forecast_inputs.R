library(testthat)
audit_root <- normalizePath(if (basename(getwd()) == "testthat") "../.." else ".", mustWork = TRUE)
module <- file.path(audit_root, "R/competition/nl_forecast_inputs.R")
local_api <- new.env(parent = baseenv()); sys.source(module, local_api)

local_fixture <- function() {
  policy <- local_api$nl_elo_policy(audit_root)
  teams <- data.frame(team_id = paste0("team_", letters[1:4]), canonical_name = c("Alpha", "Beta", "Gamma", "Delta"), stringsAsFactors = FALSE)
  map <- data.frame(canonical_name = teams$canonical_name, fifa_code = LETTERS[1:4])
  history <- data.frame(date = as.Date("2025-01-01") + seq_len(22) * 20,
    home_team_canonical = rep(c("Alpha", "Gamma", "Alpha"), length.out = 22),
    away_team_canonical = rep(c("Beta", "Delta", "Beta"), length.out = 22),
    home_score = rep(c(2, 0, 1), length.out = 22), away_score = rep(c(0, 1, 1), length.out = 22), neutral = FALSE)
  history$result <- ifelse(history$home_score > history$away_score, 1, ifelse(history$home_score == history$away_score, .5, 0))
  history$is_home <- TRUE
  seed <- suppressMessages(policy$functions$compute_elo_optimized(history, map))$ratings_history
  results <- data.frame(fixture_id = paste0("fixture-", 1:4), home_team_id = teams$team_id[c(1, 3, 2, 4)],
    away_team_id = teams$team_id[c(2, 4, 3, 1)], scheduled_at_utc = rep(c("2026-09-24T16:00:00Z", "2026-09-27T16:00:00Z"), each = 2),
    evidence_completed_at_utc = rep(c("2026-09-24T18:00:00.125Z", "2026-09-27T18:00:00.250Z"), each = 2),
    match_status = "completed", counts_for_standings = TRUE, counts_for_form = TRUE, final_home_goals = c(1L, 0L, 2L, 3L), final_away_goals = c(0L, 0L, 1L, 1L), stringsAsFactors = FALSE)
  list(policy = policy, teams = teams, map = map, history = history, seed = seed, results = results, as_of = "2026-09-28T00:00:00Z")
}

test_that("local continuation equals the frozen full national policy with causal same-kickoff batches", {
  f <- local_fixture()
  actual <- local_api$nl_elo_build(f$seed, f$results, f$teams, f$as_of, f$policy)
  extra <- data.frame(date = as.Date(substr(f$results$scheduled_at_utc, 1, 10)),
    home_team_canonical = f$teams$canonical_name[match(f$results$home_team_id, f$teams$team_id)],
    away_team_canonical = f$teams$canonical_name[match(f$results$away_team_id, f$teams$team_id)],
    home_score = f$results$final_home_goals, away_score = f$results$final_away_goals, neutral = FALSE)
  extra$result <- ifelse(extra$home_score > extra$away_score, 1, ifelse(extra$home_score == extra$away_score, .5, 0)); extra$is_home <- TRUE
  reference <- suppressMessages(f$policy$functions$compute_elo_optimized(rbind(f$history, extra), f$map))$current_ratings
  for (team in f$teams$canonical_name) {
    rows <- actual$ratings[actual$ratings$team == team, ]
    expect_equal(utils::tail(rows$rating, 1), reference$rating[reference$team == team], tolerance = 1e-12)
  }
  reversed <- local_api$nl_elo_build(f$seed, f$results[4:1, ], f$teams, f$as_of, f$policy)
  expect_identical(actual$ratings, reversed$ratings)
  expect_identical(actual$per_team, reversed$per_team)
  expect_equal(sum(vapply(actual$per_team, `[[`, integer(1), "consumed_result_count")), 8L)
  expect_true(all(vapply(actual$per_team, function(x) local_api$nl_elo_time(x$latest_evidence_at_utc) > local_api$nl_elo_time(actual$provenance$base_cutoff_utc), logical(1))))
})

test_that("future, missing, ambiguous or overlapping evidence cannot update local ratings", {
  f <- local_fixture()
  expect_error(local_api$nl_elo_build(f$seed, f$results, f$teams, "2026-09-25T00:00:00Z", f$policy), "after source as-of")
  bad <- f$results; bad$home_team_id[[2]] <- bad$home_team_id[[1]]
  expect_error(local_api$nl_elo_build(f$seed, bad, f$teams, f$as_of, f$policy), "same-kickoff")
  bad <- f$results; bad$scheduled_at_utc[3:4] <- "2026-09-24T17:00:00Z"
  expect_error(local_api$nl_elo_build(f$seed, bad, f$teams, f$as_of, f$policy), "strictly prior")
  expect_error(local_api$nl_elo_build(f$seed[f$seed$team != "Alpha", ], f$results, f$teams, f$as_of, f$policy), "lacks a pre-edition")
  bad <- f$results; bad$final_home_goals[[1]] <- NA
  expect_error(local_api$nl_elo_build(f$seed, bad, f$teams, f$as_of, f$policy), "score/evidence")
  unknown <- f$results; unknown$counts_for_standings <- FALSE; unknown$counts_for_form <- FALSE; unknown$match_status <- "scheduled"
  untouched <- local_api$nl_elo_build(f$seed, unknown, f$teams, f$as_of, f$policy)
  expect_equal(untouched$provenance$completed_result_count, 0L)
  expect_true(all(vapply(untouched$per_team, function(x) x$latest_evidence_at_utc == x$seed_evidence_at_utc, logical(1))))
})

test_that("cold readonly readers verify genuine parent hashes, replay and semantic authority", {
  f <- local_fixture(); project <- tempfile("local-elo-contract-"); dir.create(project)
  on.exit(unlink(project, recursive = TRUE), add = TRUE)
  paths <- c("R/elo", "data/processed", "data/competition/accepted/uefa_nations_league_2026_27", "data/competition/registries")
  for (path in paths) dir.create(file.path(project, path), recursive = TRUE)
  file.copy(file.path(audit_root, "R/elo/runner_optimized.R"), file.path(project, "R/elo/runner_optimized.R"))
  utils::write.csv(f$seed, file.path(project, "data/processed/elo_ratings.csv"), row.names = FALSE)
  utils::write.csv(f$results, file.path(project, "data/competition/accepted/uefa_nations_league_2026_27/results.csv"), row.names = FALSE)
  utils::write.csv(f$teams, file.path(project, "data/competition/registries/team_identity.csv"), row.names = FALSE)
  source <- list(results = f$results, source_bundle_sha256 = paste(rep("a", 64), collapse = ""), as_of_utc = f$as_of)
  built <- local_api$nl_elo_build_from_project(project, source, f$teams, f$as_of)
  state <- file.path(project, "outputs/competition/uefa_nations_league_2026_27")
  written <- local_api$nl_elo_write(built, state)
  manifest <- data.frame(validation_status = rep("valid", 11), elo_input_sha256 = written$ratings_sha256, elo_input_provenance_sha256 = written$provenance_sha256)
  verified <- local_api$nl_elo_read_validate(project, state, source, f$teams, manifest)
  expect_equal(verified$ratings$rating, built$ratings$rating, tolerance = 1e-12)
  bad <- manifest; bad$validation_status <- "invalid"
  expect_error(local_api$nl_elo_read_validate(project, state, source, f$teams, bad), "semantic candidate")
  bad <- manifest; bad$elo_input_sha256 <- paste(rep("b", 64), collapse = "")
  expect_error(local_api$nl_elo_read_validate(project, state, source, f$teams, bad), "not bound")
  path <- file.path(state, "forecast_inputs/elo_ratings.csv")
  original <- readBin(path, "raw", file.info(path)$size)
  changed <- verified$ratings; changed$rating[[1]] <- changed$rating[[1]] + 1
  utils::write.csv(changed, path, row.names = FALSE)
  expect_error(local_api$nl_elo_read_validate(project, state, source, f$teams, manifest), "provenance/hash")
  writeBin(original, path)
  seed_path <- file.path(project, "data/processed/elo_ratings.csv"); cat("\n", file = seed_path, append = TRUE)
  expect_error(local_api$nl_elo_read_validate(project, state, source, f$teams, manifest), "stale or altered: seed_sha256")
  unlink(path)
  expect_error(local_api$nl_elo_read_validate(project, state, source, f$teams, manifest), "requires genuine local")
})

api <- new.env(parent=globalenv())
api$commandArgs <- function(trailingOnly=FALSE)if(trailingOnly)character()else paste0("--file=",file.path(audit_root,"scripts/build_competition_state.R"))
api$interactive <- function()TRUE
sys.source(file.path(audit_root,"scripts/build_competition_state.R"),api)
sys.source(module,api)

state_authority_fixture <- function() {
 f <- local_fixture(); project <- tempfile("nl-authority-fixture-"); dir.create(project)
 for(path in c("R/elo","data/processed","data/competition/registries","data/competition/accepted/uefa_nations_league_2026_27"))dir.create(file.path(project,path),recursive=TRUE)
 file.copy(file.path(audit_root,"R/elo/runner_optimized.R"),file.path(project,"R/elo/runner_optimized.R"))
 future <- f$results[1,,drop=FALSE];future$fixture_id <- "future-1";future$scheduled_at_utc <- "2026-09-30T16:00:00Z";future$match_status <- "scheduled";future$counts_for_standings <- FALSE;future$counts_for_form <- FALSE;future$final_home_goals <- NA_integer_;future$final_away_goals <- NA_integer_;future$evidence_completed_at_utc <- NA_character_
 results <- rbind(f$results,future)
 utils::write.csv(results,file.path(project,"data/competition/accepted/uefa_nations_league_2026_27/results.csv"),row.names=FALSE,na="")
 utils::write.csv(f$seed,file.path(project,"data/processed/elo_ratings.csv"),row.names=FALSE,na="")
 utils::write.csv(f$teams,file.path(project,"data/competition/registries/team_identity.csv"),row.names=FALSE,na="")
 source <- list(results=results,source_bundle_sha256=paste(rep("a",64),collapse=""),as_of_utc=f$as_of)
 input <- api$nl_elo_build_from_project(project,source,f$teams,f$as_of)
 root <- file.path(project,"outputs/competition/uefa_nations_league_2026_27")
 hashes <- api$nl_elo_write(input,root)
 fixture <- results;fixture$source_status <- c(rep("FINISHED",4),"UPCOMING")
 status <- data.frame(fixture_id=fixture$fixture_id,forecast_status=c(rep("suppressed",4),"available"),suppression_reason=c(rep("status_ineligible",4),"none"))
 clock <- "2026-09-28T10:00:00Z"
 forecasts <- data.frame(fixture_id="future-1",feature_cutoff_utc="2026-09-30T15:59:59Z",kickoff_utc=future$scheduled_at_utc,latest_evidence_at_utc="2026-09-27T18:00:00.250Z",generated_at_utc=clock)
 manifest <- data.frame(validation_status=rep("valid",11),elo_input_sha256=hashes$ratings_sha256,elo_input_provenance_sha256=hashes$provenance_sha256,source_bundle_sha256=source$source_bundle_sha256,generated_at_utc=clock)
 facts <- data.frame(team_id=f$teams$team_id)
 artifacts <- list("audit/state_manifest.csv"=manifest,"state/canonical_matches.csv"=fixture,"state/forecasts.csv"=forecasts,"state/forecast_status.csv"=status,"state/standings.csv"=facts,"state/competition_form.csv"=facts,"state/all_international_form.csv"=facts,"audit/standings_reconciliation.csv"=facts)
 list(project=project,source=source,state=list(artifacts=artifacts,state_manifest=manifest,state_manifest_sha256=paste(rep("b",64),collapse="")),teams=f$teams,input=input)
}

test_that("completed suppression is legitimate only with real accepted completed facts", {
 f <- state_authority_fixture();on.exit(unlink(f$project,recursive=TRUE),add=TRUE)
 expect_silent(api$nl_elo_validate_accepted_state(f$project,f$source,f$state,f$teams))
 status <- f$state$artifacts[["state/forecast_status.csv"]]; fixtures <- f$state$artifacts[["state/canonical_matches.csv"]]
 expected <- api$phase14_state_bundle_expected_completed_suppression(status,fixtures,f$source$results,"uefa_nations_league_2026_27",data.frame(retrieved_at_utc=f$source$as_of_utc))
 expect_identical(expected,c(TRUE,TRUE,TRUE,TRUE,FALSE))
 bad <- f$state;bad$artifacts[["state/forecast_status.csv"]]$forecast_status[[5]] <- "suppressed"
 expect_error(api$nl_elo_validate_accepted_state(f$project,f$source,bad,f$teams),"future forecast suppression")
 bad <- f$state;bad$state_manifest$validation_status <- "invalid"
 expect_error(api$nl_elo_validate_accepted_state(f$project,f$source,bad,f$teams),"semantic candidate")
 bad_results <- f$source$results;bad_results$final_home_goals[[1]] <- NA
 expect_false(api$phase14_state_bundle_expected_completed_suppression(status,fixtures,bad_results,"uefa_nations_league_2026_27",data.frame(retrieved_at_utc=f$source$as_of_utc))[[1]])
 bad <- f$state;bad$artifacts[["state/standings.csv"]] <- data.frame(team_id=character())
 expect_error(api$nl_elo_validate_accepted_state(f$project,f$source,bad,f$teams),"factual/form")
 bad <- f$state;bad$artifacts[["state/forecasts.csv"]]$latest_evidence_at_utc <- "2026-09-24T18:00:00.125Z"
 expect_error(api$nl_elo_validate_accepted_state(f$project,f$source,bad,f$teams),"actual prior local ratings")
 bad <- f$state;bad$artifacts[["state/forecasts.csv"]]$generated_at_utc <- "2026-06-10T00:00:00Z"
 expect_error(api$nl_elo_validate_accepted_state(f$project,f$source,bad,f$teams),"operational timestamps")
})

test_that("feature evidence is per fixture, fractional and strictly prior", {
 table <- data.frame(fixture_id=c("a","b"),elo_diff__evidence_at_utc=c("2026-09-01T17:00:00.125Z","2026-09-02T17:00:00.250Z"))
 features <- list(feature_table=table,active_predictors="elo_diff",latest_evidence_at_utc=table$elo_diff__evidence_at_utc[[2]])
 adapted <- data.frame(fixture_id="a",feature_cutoff_utc="2026-09-03T00:00:00Z")
 expect_identical(api$phase14_forecast_fixture_evidence_text(adapted,features),table$elo_diff__evidence_at_utc[[1]])
 adapted$fixture_id <- "b"
 expect_identical(api$phase14_forecast_fixture_evidence_text(adapted,features),table$elo_diff__evidence_at_utc[[2]])
 adapted$feature_cutoff_utc <- table$elo_diff__evidence_at_utc[[2]]
 expect_error(api$phase14_forecast_fixture_evidence_text(adapted,features),"strictly prior")
 ratings <- data.frame(team="Alpha",rating=1500,date="2026-09-02",evidence_at_utc="2026-09-02T00:00:00Z",evidence_precision="date")
 expect_equal(nrow(api$phase14_forecast_elo_rows_before(ratings,"Alpha","2026-09-02T19:00:00Z")),0)
 expect_equal(nrow(api$phase14_forecast_elo_rows_before(ratings,"Alpha","2026-09-03T19:00:00Z")),1)
 ratings$evidence_precision <- "timestamp";ratings$evidence_at_utc <- "2026-09-02T17:00:00.250Z"
 expect_equal(nrow(api$phase14_forecast_elo_rows_before(ratings,"Alpha","2026-09-02T17:00:00.250Z")),0)
 expect_equal(nrow(api$phase14_forecast_elo_rows_before(ratings,"Alpha","2026-09-02T17:00:00.251Z")),1)
})

test_that("fresh local inputs cannot certify old outcomes or fabricated projection clocks", {
 f <- state_authority_fixture();on.exit(unlink(f$project,recursive=TRUE),add=TRUE)
 meta <- data.frame(state_manifest_sha256=f$state$state_manifest_sha256,source_bundle_sha256=f$source$source_bundle_sha256,generated_at_utc="2026-09-28T11:00:00Z")
 out <- list(manifest=meta,artifacts=list("outcomes/simulation_metadata.csv"=meta))
 expect_silent(api$nl_elo_validate_projection(f$state,out,f$source))
 bad <- out;bad$manifest$state_manifest_sha256 <- paste(rep("c",64),collapse="")
 expect_error(api$nl_elo_validate_projection(f$state,bad,f$source),"actual current forecast state")
 bad <- out;bad$manifest$generated_at_utc <- "";bad$artifacts[[1]]$generated_at_utc <- ""
 expect_error(api$nl_elo_validate_projection(f$state,bad,f$source),"valid UTC")
 bad <- out;bad$manifest$generated_at_utc <- "2026-06-10T00:00:00Z";bad$artifacts[[1]]$generated_at_utc <- bad$manifest$generated_at_utc
 expect_error(api$nl_elo_validate_projection(f$state,bad,f$source),"predates")
})


test_that("model/source dates cannot fill a missing operational generation receipt", {
  clocks <- new.env(parent=baseenv())
  sys.source(file.path(audit_root,"R/dashboard/payload_contract.R"),clocks)
  bundle <- clocks$phase17_fixture_bundle("uefa_nations_league_2026_27")
  expect_identical(clocks$phase17_normalize_metadata(bundle)$generated_at_utc,"2026-08-25T00:00:00Z")
  bundle$generated_at_utc <- NULL
  expect_identical(clocks$phase17_normalize_metadata(bundle)$generated_at_utc,"")
  bundle$source_retrieved_at_utc <- NULL
  expect_identical(clocks$phase17_normalize_metadata(bundle)$last_refresh_at_utc,"")
})

test_that("coordinated CSV/JSON/manifest tampering still fails independent causal replay", {
  f <- state_authority_fixture();on.exit(unlink(f$project,recursive=TRUE),add=TRUE)
  root <- file.path(f$project,"outputs/competition/uefa_nations_league_2026_27")
  changed <- f$input;changed$ratings$rating[[1L]] <- changed$ratings$rating[[1L]]+10
  written <- api$nl_elo_write(changed,root)
  manifest <- f$state$state_manifest
  manifest$elo_input_sha256 <- written$ratings_sha256;manifest$elo_input_provenance_sha256 <- written$provenance_sha256
  expect_error(api$nl_elo_read_validate(f$project,root,f$source,f$teams,manifest),"disagree with causal replay")
  api$nl_elo_write(f$input,root)
  bad_source <- f$source;bad_source$as_of_utc <- "2026-09-29T00:00:00Z"
  expect_error(api$nl_elo_read_validate(f$project,root,bad_source,f$teams),"source as-of")
  path <- file.path(f$project,"data/competition/accepted/uefa_nations_league_2026_27/results.csv")
  cat("\n",file=path,append=TRUE)
  expect_error(api$nl_elo_read_validate(f$project,root,f$source,f$teams),"results_sha256")
})


test_that("outcome metadata uses explicit computation time and never the fitted model clock", {
  sys.source(file.path(audit_root,"R/competition/uefa_euro_priority.R"),api)
  sys.source(file.path(audit_root,"R/competition/uefa_nations_league_outcomes.R"),api)
  simulation <- list(metadata=list(),output_hashes=list())
  state <- list(state_manifest=data.frame(generated_at_utc="2026-06-10T00:00:00Z"),state_manifest_sha256=paste(rep("b",64),collapse=""))
  common <- list(projection_run_id="independent-clock-fixture",simulation_seed=7L,simulation_count=10000L,source_bundle_id="fixture",source_bundle_sha256=paste(rep("a",64),collapse=""),model_release_id="fixture-release")
  lineage <- list(ruleset_version="fixture-rules",ruleset_sha256=paste(rep("c",64),collapse=""))
  actual <- api$phase15_nl_build_simulation_metadata(simulation,state,list(),lineage,common,generated_at_utc="2026-11-05T23:00:00Z")
  expect_identical(actual$generated_at_utc,"2026-11-05T23:00:00Z")
  missing <- api$phase15_nl_build_simulation_metadata(simulation,state,list(),lineage,common)
  expect_identical(missing$generated_at_utc,"")
  expect_identical(actual$simulation_seed,missing$simulation_seed)
  expect_identical(actual$simulation_count,missing$simulation_count)
  expect_identical(actual$output_sha256,missing$output_sha256)
})
