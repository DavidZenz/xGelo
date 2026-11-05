library(testthat)

non_wc_test_root <- normalizePath(if (basename(getwd()) == "testthat") "../.." else ".", mustWork = TRUE)
non_wc_test_runtime <- function() {
  env <- new.env(parent = globalenv())
  sys.source(file.path(non_wc_test_root, "scripts/refresh_competition_dashboards.R"), env)
  sys.source(file.path(non_wc_test_root, "R/competition/nl_simulation_precision.R"), env)
  sys.source(file.path(non_wc_test_root, "R/dashboard/non_wc_publication.R"), env)
  env
}

# Independent temporary publication inputs exercise presentation and readiness;
# they never create source authority, model selectors or production artifacts.
non_wc_test_payloads <- function(env, now = "2026-11-05T12:00:00Z") {
  registry <- env$phase21_default_edition_registry()
  legacy <- list(
    uefa_nations_league_2026_27 = env$phase17_payload_nations_league(env$phase17_fixture_bundle("uefa_nations_league_2026_27")),
    uefa_euro_2028_qualifying = env$phase17_payload_euro(env$phase17_fixture_bundle("uefa_euro_2028_qualifying")))
  p <- lapply(names(legacy), function(id) {
    x <- env$phase21_normalize_phase17_payload(legacy[[id]], registry[registry$edition_id == id, , drop = FALSE])
    x$metadata$last_refresh_at_utc <- now
    x$metadata$source_as_of_utc <- now
    x$metadata$generated_at_utc <- now
    x$metadata$source_status <- "accepted"
    x$metadata$simulation_count <- if (id == "uefa_nations_league_2026_27") 10000L else 0L
    x$metadata$freshness_status <- if (id == "uefa_nations_league_2026_27") "fresh" else "not_applicable_pre_draw"
    x
  })
  names(p) <- names(legacy)
  cl <- env$phase21_blocked_payload("ucl_2026_27", "Team-strength predictions are disabled", registry[3,,drop=FALSE])
  cl$metadata$source_status <- "accepted"; cl$metadata$last_refresh_at_utc <- now
  cl$metadata$source_as_of_utc <- now; cl$metadata$generated_at_utc <- now
  cl$metadata$lifecycle_state <- "league_phase"; cl$metadata$freshness_status <- "fresh"
  cl$sections$fixtures <- env$phase21_section("fixtures", "Upcoming fixtures",
    data.frame(`Kickoff (UTC)`="2026-11-06T20:00:00Z",Home="Home",Away="Away",check.names=FALSE))
  p$ucl_2026_27 <- cl
  list(payloads = p, legacy = legacy, registry = registry, now = now)
}

test_that("non-WC readiness rejects demos, stale data and unaccepted EURO activation", {
  env <- non_wc_test_runtime(); x <- non_wc_test_payloads(env)
  expect_silent(env$phase21_non_wc_validate_ready(x$payloads, x$now))
  expect_true(is.na(env$phase21_non_wc_time("2026-11-05T12:00:00+02:00")))
  expect_true(is.na(env$phase21_non_wc_time("2026-11-05T12:00:00Zextra")))
  bad <- x$payloads; bad$uefa_nations_league_2026_27$metadata$simulation_count <- 100L
  expect_error(env$phase21_non_wc_validate_ready(bad,x$now), "precision|simulations", ignore.case=TRUE)
  bad$uefa_nations_league_2026_27$metadata$simulation_count <- 10000.5
  expect_error(env$phase21_non_wc_validate_ready(bad,x$now), "integer|whole")
  bad <- x$payloads; bad$ucl_2026_27$metadata$last_refresh_at_utc <- "2026-10-27T10:48:30Z"
  expect_error(env$phase21_non_wc_validate_ready(bad,x$now), "stale")
  bad <- x$payloads; bad$uefa_euro_2028_qualifying$sections$fixtures$rows <- list(list(Home="Invented"))
  expect_error(env$phase21_non_wc_validate_ready(bad,x$now), "pre-draw")
  bad <- x$payloads; bad$uefa_euro_2028_qualifying$metadata$lifecycle_state <- "active"
  expect_error(env$phase21_non_wc_validate_ready(bad,x$now), "official structure")
  bad <- x$payloads; bad$ucl_2026_27$sections$fixtures$rows[[1]][["Kickoff (UTC)"]] <- x$now
  expect_error(env$phase21_non_wc_validate_ready(bad,x$now), "Past or invalid")
})

test_that("identical CL defaults require visible baseline disclosure", {
  env <- non_wc_test_runtime(); x <- non_wc_test_payloads(env)
  rows <- list(list(`Kickoff (UTC)`="2026-11-06T20:00:00Z",`Home win`="44.0%",Draw="24.5%",`Away win`="31.5%"),
    list(`Kickoff (UTC)`="2026-11-07T20:00:00Z",`Home win`="44.0%",Draw="24.5%",`Away win`="31.5%"))
  x$payloads$ucl_2026_27$sections$match_forecasts <- env$phase21_section("match_forecasts","Match forecasts",rows)
  expect_error(env$phase21_non_wc_validate_ready(x$payloads,x$now), "baseline disclosure")
  x$payloads$ucl_2026_27$sections$match_forecasts$reason <- "Venue baseline: does not distinguish team strength."
  expect_silent(env$phase21_non_wc_validate_ready(x$payloads,x$now))
})

test_that("three-route staging preserves rich legacy HTML and atomic rollback", {
  env <- non_wc_test_runtime(); x <- non_wc_test_payloads(env)
  parent <- tempfile("non-wc-publish-");dir.create(parent)
  on.exit(unlink(parent,recursive=TRUE),add=TRUE)
  stage <- file.path(parent,"candidate"); public <- file.path(parent,"competitions")
  result <- env$phase21_non_wc_stage_payloads(x$payloads,x$legacy,stage,x$now)
  expect_true(result$valid)
  expect_equal(length(list.files(stage,recursive=TRUE)),14L)
  nl <- paste(readLines(file.path(stage,"nations-league/index.html"),warn=FALSE),collapse="\n")
  cl <- paste(readLines(file.path(stage,"champions-league/index.html"),warn=FALSE),collapse="\n")
  expect_match(nl,"Nations League",fixed=TRUE)
  expect_match(nl,"nl-dashboard",fixed=TRUE)
  expect_match(nl,"../champions-league/",fixed=TRUE)
  expect_match(cl,"../nations-league/",fixed=TRUE)
  expect_match(cl,"current-freshness-notice",fixed=TRUE)
  expect_match(cl,"Archived past-kickoff rows",fixed=TRUE)
  expect_match(cl,"No upcoming forecasts in this snapshot",fixed=TRUE)
  expect_match(cl,'data-kickoff-utc="2026-11-06T20:00:00Z"',fixed=TRUE)
  expect_true(env$phase21_promote_batch(stage,public,x$registry)$valid)
  pointer_path <- file.path(public,"current.json")
  pointer_bytes <- readBin(pointer_path,"raw",file.info(pointer_path)$size)
  pointer <- env$phase21_read_json(pointer_path); pointer$manifest_sha256 <- strrep("0",64)
  env$phase21_write_json(pointer,pointer_path)
  expect_error(env$phase21_validate_batch(public,x$registry),"bind the accepted batch manifest")
  writeBin(pointer_bytes,pointer_path)
  before <- lapply(list.files(public,recursive=TRUE,full.names=TRUE),function(p)readBin(p,"raw",file.info(p)$size))
  stage <- file.path(parent,"candidate2")
  env$phase21_non_wc_stage_payloads(x$payloads,x$legacy,stage,x$now)
  expect_error(env$phase21_promote_batch(stage,public,x$registry,injectors=list(read_back=function()stop("forced read-back failure"))),"forced read-back")
  after <- lapply(list.files(public,recursive=TRUE,full.names=TRUE),function(p)readBin(p,"raw",file.info(p)$size))
  expect_identical(after,before)
  expect_false(dir.exists(file.path(parent,".phase21-publication.lock")))
  dir.create(file.path(parent,".phase21-publication.lock"))
  expect_error(env$phase21_promote_batch(stage,public,x$registry),"holds the lock")
})

test_that("fixed staging CLI rejects alternate publication roots and nonempty stages", {
  e <- new.env(parent=globalenv())
  sys.source(file.path(non_wc_test_root,"scripts/stage_non_wc_dashboards.R"),e)
  expect_error(e$stage_non_wc_dashboards_main(c("--public-root","docs/wc2026")),"Use --stage-root")
  expect_error(e$stage_non_wc_dashboards_main(c("--stage-root","relative/path")),"absolute")
  stage <- tempfile("non-wc-nonempty-");dir.create(stage);writeLines("preserve",file.path(stage,"incumbent.txt"))
  on.exit(unlink(stage,recursive=TRUE),add=TRUE)
  expect_error(e$stage_non_wc_dashboards_main(c("--stage-root",stage,"--cl-forecasts=disabled")),"empty")
  expect_identical(readLines(file.path(stage,"incumbent.txt")),"preserve")
})

test_that("publication lineage checks compare accepted parents and retained rows", {
  env <- non_wc_test_runtime(); x <- non_wc_test_payloads(env)
  expected <- list(source_bundle_sha256 = strrep("a",64), model_release_id="accepted-model")
  expect_silent(env$phase21_non_wc_assert_lineage(expected,expected,names(expected),"test"))
  altered <- expected; altered$source_bundle_sha256 <- strrep("b",64)
  expect_error(env$phase21_non_wc_assert_lineage(altered,expected,names(expected),"test"),"source_bundle_sha256")
  p <- x$payloads$ucl_2026_27
  expect_silent(env$phase21_non_wc_assert_rows(p,p,"test","fixtures"))
  altered <- p; altered$sections$fixtures$rows[[1L]]$Home <- "Changed after acceptance"
  expect_error(env$phase21_non_wc_assert_rows(altered,p,"test","fixtures"),"rows differ")
})

test_that("read-only production gate plumbing stays accepted and fails closed", {
  env <- non_wc_test_runtime()
  called <- character()
  gate_ids <- c("phase13_validate_source_bundle", "phase13_validate_accepted_snapshot",
    "phase13_validate_competition_edition_registries", "phase14_build_competition_state_candidate",
    "phase14_resolve_approved_release", "phase15_validate_nl_outcomes_bundle",
    "phase16_validate_euro_source_bundle", "validate_euro_activation", "phase16_validate_euro_outcomes_bundle",
    "phase17_validate_probability_inputs")
  # Temporary mechanical callbacks only: this verifies dispatch/failure behavior,
  # not production authority, and creates no accepted registry or release.
  env$phase17_load_accepted_production_bundles <- function(project_root) list(mechanical_test_only=TRUE)
  env$phase17_production_callbacks <- function(bundles,project_root,now,phase14_state_mode) {
    expect_identical(phase14_state_mode,"accepted")
    setNames(lapply(gate_ids,function(id) local({ name <- id; function() {
      called <<- c(called,name); list(valid=TRUE)
    }})),gate_ids)
  }
  expect_identical(env$phase21_non_wc_load_accepted_inputs(non_wc_test_root,"2026-11-05T12:00:00Z"),
    list(mechanical_test_only=TRUE))
  expect_identical(called,gate_ids)
  env$phase17_production_callbacks <- function(...) setNames(lapply(gate_ids,function(id)
    function() list(valid=FALSE,failure_reason="blocked accepted parent")),gate_ids)
  expect_error(env$phase21_non_wc_load_accepted_inputs(non_wc_test_root,"2026-11-05T12:00:00Z"),"blocked accepted parent")
})

test_that("publication QA rejects a resealed payload that changes accepted lineage or facts", {
  env <- non_wc_test_runtime(); x <- non_wc_test_payloads(env)
  root <- tempfile("non-wc-authority-dispatch-");dir.create(root)
  on.exit(unlink(root,recursive=TRUE),add=TRUE)
  # Private mechanical authority stand-ins test comparisons after the separate
  # accepted-input gate. They cannot install or create production authority.
  env$phase21_non_wc_load_accepted_inputs <- function(...) list(mechanical_test_only=TRUE)
  env$phase21_non_wc_prepare_national_payloads <- function(...) list(payloads=x$payloads[c(
    "uefa_nations_league_2026_27","uefa_euro_2028_qualifying")])
  env$phase18_read_ucl_refresh_current <- function(...) list(mechanical_test_only=TRUE)
  env$phase18_validate_ucl_refresh_current <- function(...) invisible(TRUE)
  env$phase21_payload_ucl_live_source <- function(...) x$payloads$ucl_2026_27
  stage <- file.path(root,"valid")
  env$phase21_non_wc_stage_payloads(x$payloads,x$legacy,stage,x$now)
  result <- env$phase21_non_wc_validate_production_publication(stage,non_wc_test_root,x$now)
  expect_true(result$production_authority_valid)
  altered <- x$payloads
  altered$uefa_nations_league_2026_27$metadata$source_bundle_sha256 <- strrep("b",64)
  stage <- file.path(root,"changed-lineage")
  env$phase21_non_wc_stage_payloads(altered,x$legacy,stage,x$now)
  expect_error(env$phase21_non_wc_validate_production_publication(stage,non_wc_test_root,x$now),"source_bundle_sha256")
  altered <- x$payloads
  altered$ucl_2026_27$sections$fixtures$rows[[1L]]$Home <- "Unaccepted fixture edit"
  stage <- file.path(root,"changed-facts")
  env$phase21_non_wc_stage_payloads(altered,x$legacy,stage,x$now)
  expect_error(env$phase21_non_wc_validate_production_publication(stage,non_wc_test_root,x$now),"rows differ")
})

test_that("real cold authority imports cannot coerce custom route renderer functions", {
  env <- non_wc_test_runtime()
  # The real dependency import installs EURO's scalar coalescer. Renderer
  # dispatch must support functions independently of that scalar helper.
  env$phase17_provider_source_authorities(non_wc_test_root)
  x <- non_wc_test_payloads(env)
  root <- tempfile("non-wc-cold-renderers-");dir.create(root)
  on.exit(unlink(root,recursive=TRUE),add=TRUE)
  candidate <- env$phase21_non_wc_stage_payloads(x$payloads,x$legacy,file.path(root,"candidate"),x$now)
  expect_true(candidate$valid)
  expect_true(env$phase21_validate_batch(file.path(root,"candidate"))$valid)
  html <- paste(readLines(file.path(root,"candidate/nations-league/index.html"),warn=FALSE),collapse="\n")
  expect_match(html,"nl-dashboard",fixed=TRUE)
})

test_that("legacy rendering uses current human section reasons without changing rows or labels", {
  env <- non_wc_test_runtime();x <- non_wc_test_payloads(env)
  id <- "uefa_euro_2028_qualifying"
  internal <- "INTERNAL_SECTION_REASON | expected_draw_date=2026-12-06 | last_refresh_at_utc=2026-08-14T15:10:13Z"
  human <- "Forecasting is inactive until official EURO groups and fixtures are accepted."
  common <- intersect(names(x$legacy[[id]]$sections),names(x$payloads[[id]]$sections))
  for (section_id in common) {
    x$legacy[[id]]$sections[[section_id]]$reason <- internal
    x$payloads[[id]]$sections[[section_id]]$reason <- human
  }
  root <- tempfile("non-wc-human-reasons-");dir.create(root)
  on.exit(unlink(root,recursive=TRUE),add=TRUE)
  env$phase21_non_wc_stage_payloads(x$payloads,x$legacy,file.path(root,"candidate"),x$now)
  html <- paste(readLines(file.path(root,"candidate/euro-qualifying/index.html"),warn=FALSE),collapse="\n")
  expect_match(html,human,fixed=TRUE)
  expect_false(grepl("INTERNAL_SECTION_REASON",html,fixed=TRUE))
  encoded <- regmatches(html,regexec('<script id="dashboard-data" type="application/json">(.*?)</script>',html,perl=TRUE))[[1L]][[2L]]
  rendered <- jsonlite::fromJSON(encoded,simplifyVector=FALSE)
  for (section_id in common) {
    expect_identical(rendered$sections[[section_id]]$reason,human)
    expect_identical(rendered$sections[[section_id]]$label,x$legacy[[id]]$sections[[section_id]]$label)
    expect_identical(env$phase21_canonical_value_bytes(rendered$sections[[section_id]]$rows),
      env$phase21_canonical_value_bytes(x$legacy[[id]]$sections[[section_id]]$rows))
  }
})
