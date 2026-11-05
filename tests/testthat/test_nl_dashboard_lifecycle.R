library(testthat)

nl_lifecycle_root <- normalizePath(if (basename(getwd())=="testthat") "../.." else ".",mustWork=TRUE)
nl_lifecycle_api <- function() {
  env <- new.env(parent=globalenv())
  for (path in c("R/dashboard/payload_contract.R", "R/competition/nl_simulation_precision.R",
      "R/dashboard/payload_nations_league.R", "R/dashboard/renderer.R",
      "R/dashboard/edition_registry_v2.R", "R/dashboard/payload_contract_v2.R", "R/dashboard/renderer_v2.R"))
    sys.source(file.path(nl_lifecycle_root,path),env)
  env
}

test_that("NL presentation suppresses expired and unconfirmed forecasts without inferring results", {
  env <- nl_lifecycle_api()
  payload <- env$phase17_payload_nations_league(env$phase17_fixture_bundle("uefa_nations_league_2026_27"))
  payload$metadata$generated_at_utc <- "2026-11-05T12:00:00Z"
  fixture <- function(id,date,status="scheduled") list(fixture_id=id,group_id="A1",league="A",
    home_team="Alpha",away_team="Beta",scheduled_at_utc=date,source_status=status)
  rows <- list(fixture("past","2026-11-05T12:00:00Z"),fixture("future","2026-11-06T18:00:00Z"),
    fixture("unknown",""),fixture("postponed","2026-11-04T18:00:00Z","postponed"),
    fixture("completed","2026-11-04T18:00:00Z"),
    c(fixture("live","2026-11-05T11:00:00Z","in_play"),list(home_goals=0,away_goals=0,counts_for_standings=FALSE)))
  payload$sections$fixtures$rows <- rows
  payload$sections$results$rows <- list(c(rows[[5]],list(match_status="completed",final_home_goals=0,
    final_away_goals=0,counts_for_standings=TRUE)))
  payload$sections$match_forecasts$rows <- lapply(rows,function(row) list(fixture_id=row$fixture_id,
    p_home=.55,p_draw=.25,p_away=.2,forecast_status="available"))
  context <- env$phase17_public_context(payload)
  cards <- lapply(rows,function(row) env$phase17_nl_match_card(payload,row,context))
  expect_match(cards[[1]],"Past kickoff — result confirmation pending",fixed=TRUE)
  expect_false(grepl("55.0%",cards[[1]],fixed=TRUE))
  expect_match(cards[[2]],'data-nl-expirable="true"',fixed=TRUE)
  expect_match(cards[[2]],"55.0%",fixed=TRUE)
  expect_match(cards[[3]],"Kickoff unconfirmed",fixed=TRUE)
  expect_false(grepl('data-nl-kickoff-utc=',cards[[3]],fixed=TRUE))
  expect_false(grepl("55.0%",cards[[3]],fixed=TRUE))
  expect_match(cards[[4]],"Postponed",fixed=TRUE)
  expect_false(grepl("Past kickoff",cards[[4]],fixed=TRUE))
  expect_false(grepl("55.0%",cards[[4]],fixed=TRUE))
  expect_match(cards[[5]],"Final 0–0",fixed=TRUE)
  expect_match(cards[[5]],'data-nl-fixture-state="completed"',fixed=TRUE)
  expect_false(grepl("Final 0",cards[[6]],fixed=TRUE))
  expect_false(grepl("55.0%",cards[[6]],fixed=TRUE))
  compact <- env$phase17_nl_group_fixtures(payload,"Group A1",context)
  expect_match(compact,'data-nl-fixture-state="result_pending"',fixed=TRUE)
  expect_match(compact,'data-nl-fixture-state="completed"',fixed=TRUE)
})

test_that("NL browser-time lifecycle updates status, forecast chips, counts and filters", {
  node <- Sys.which("node")
  skip_if(!nzchar(node),"Node is required for the independent browser-time script test")
  env <- nl_lifecycle_api()
  script <- env$phase21_freshness_script(list(last_refresh_at_utc="2026-11-05T12:00:00Z"))
  script <- sub("^<script>","",sub("</script>$","",script))
  setup <- '
const assert=require("node:assert/strict");let now=Date.parse("2026-11-05T12:00:00Z"),tick;
Date.now=()=>now;global.setInterval=f=>{tick=f};
function card(at,state="scheduled"){const status={textContent:state},forecast={textContent:"55.0%"};return {dataset:{nlKickoffUtc:at,nlFixtureState:state,nlExpirable:state==="scheduled"?"true":"false",nlForecastAvailable:"true"},status,forecast,querySelectorAll:s=>s==="[data-nl-current-status]"?[status]:[],querySelector:s=>s==="[data-nl-forecast-display]"?forecast:null}}
const past=card("2026-11-05T12:00:00Z"),future=card("2026-11-06T18:00:00Z"),completed=card("2026-11-04T18:00:00Z","completed"),postponed=card("2026-11-04T18:00:00Z","postponed"),unknown=card("","kickoff_unconfirmed"),cards=[past,future,completed,postponed,unknown];
const filter={options:[],events:0,append(x){this.options.push(x)},dispatchEvent(){this.events++}},note={},count={parentElement:{querySelector:()=>note}},notice={};
global.document={querySelectorAll(s){if(s==="[data-nl-expirable=true]")return cards.filter(x=>x.dataset.nlExpirable==="true");if(s==="#fixtures .nl-match-card[data-nl-fixture-state=scheduled]")return cards.filter(x=>x.dataset.nlFixtureState==="scheduled");if(s==="[data-nl-forecast-count]")return[count];return[]},getElementById(s){return s==="nl-status-filter"?filter:s==="current-freshness-notice"?notice:null},createElement:()=>({})};
'
  checks <- '
assert.equal(past.dataset.nlFixtureState,"result_pending");assert.match(past.status.textContent,/Past kickoff/);assert.match(past.forecast.textContent,/archived/);
assert.equal(future.forecast.textContent,"55.0%");assert.equal(completed.status.textContent,"completed");assert.equal(postponed.status.textContent,"postponed");assert.equal(unknown.status.textContent,"kickoff_unconfirmed");assert.equal(count.textContent,"1/1");assert.equal(filter.options.length,1);assert.equal(filter.events,1);
now+=3*86400000;tick();assert.equal(future.dataset.nlFixtureState,"result_pending");assert.equal(count.textContent,"—");assert.equal(filter.options.length,1);assert.equal(completed.status.textContent,"completed");
'
  path <- tempfile("nl-lifecycle-",fileext=".js");on.exit(unlink(path),add=TRUE)
  writeLines(c(setup,script,checks),path,useBytes=TRUE)
  output <- system2(node,shQuote(path),stdout=TRUE,stderr=TRUE)
  expect_true(is.null(attr(output,"status")),info=paste(output,collapse="\n"))
})
