library(testthat)

non_wc_navigation_root <- normalizePath(if (basename(getwd())=="testthat") "../.." else ".",mustWork=TRUE)
non_wc_navigation_api <- function() {
  env <- new.env(parent=globalenv())
  sys.source(file.path(non_wc_navigation_root,"scripts/stage_non_wc_dashboards.R"),env)
  env$non_wc_runtime
}

test_that("legacy competition links carry shared wrapping, active and keyboard focus styles", {
  api <- non_wc_navigation_api()
  page <- '<!doctype html><html><head><title>Legacy route</title></head><body><main>Existing rich dashboard</main></body></html>'
  for (id in c("uefa_nations_league_2026_27","uefa_euro_2028_qualifying")) {
    metadata <- api$phase21_default_metadata(id)
    html <- api$phase21_decorate_legacy_html(page,metadata)
    expect_match(html,'<style id="non-wc-competition-navigation">',fixed=TRUE)
    expect_match(html,'.competition-navigation{display:flex;flex-wrap:wrap;',fixed=TRUE)
    expect_match(html,'white-space:normal;overflow-wrap:anywhere',fixed=TRUE)
    expect_match(html,'.competition-navigation a[aria-current="page"]{background:#173f7a;',fixed=TRUE)
    expect_match(html,'.competition-navigation a:focus-visible{outline:3px solid #f2a900;',fixed=TRUE)
    expect_match(html,'@media(max-width:640px){.competition-navigation a',fixed=TRUE)
    route <- if (id=="uefa_nations_league_2026_27") "nations-league" else "euro-qualifying"
    expect_match(html,paste0('href="../',route,'/" aria-current="page"'),fixed=TRUE)
    expect_lt(regexpr('<style id="non-wc-competition-navigation">',html,fixed=TRUE)[[1]],regexpr('</head>',html,fixed=TRUE)[[1]])
    expect_match(html,"Existing rich dashboard",fixed=TRUE)
  }
  cl <- api$phase21_blocked_payload("ucl_2026_27","Awaiting model QA")
  expect_match(api$phase21_render_dashboard(cl),api$phase21_competition_navigation_css(),fixed=TRUE)
})

test_that("NL Monte Carlo limits are visible above all tabbed views", {
  api <- non_wc_navigation_api()
  bundle <- api$phase17_fixture_bundle("uefa_nations_league_2026_27")
  bundle$simulation_count <- 10000L
  payload <- api$phase17_payload_nations_league(bundle)
  html <- api$render_phase17_dashboard(payload)
  hero <- regexpr('class="hero nl-hero"',html,fixed=TRUE)[[1]]
  tabs <- regexpr('<nav class="tabs nl-tabs"',html,fixed=TRUE)[[1]]
  visible <- substr(html,hero,tabs-1L)
  expect_match(visible,api$phase17_nl_mc_precision_note(payload),fixed=TRUE)
  expect_match(visible,"10,000 simulations; 95% pointwise",fixed=TRUE)
  expect_match(visible,"exclude model uncertainty",fixed=TRUE)
  expect_match(visible,"do not provide simultaneous coverage",fixed=TRUE)
  expect_false(grepl("<section",visible,fixed=TRUE))
})
