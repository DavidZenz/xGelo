library(testthat)

active_dashboard_root <- normalizePath(file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."))
active_dashboard_api <- function() {
  api <- new.env(parent = globalenv())
  for (file in c("payload_contract.R", "payload_nations_league.R", "payload_euro.R", "renderer.R")) {
    sys.source(file.path(active_dashboard_root, "R/dashboard", file), api)
  }
  api
}
active_dashboard_bundle <- function(api) {
  bundle <- api$phase17_fixture_bundle("uefa_nations_league_2026_27", lifecycle_state = "active")
  bundle$artifacts$structure <- data.frame(league = "A", group_id = c("A1", "A2"), display_name = c("Group A1", "Group A2"))
  bundle$artifacts$fixtures <- data.frame(
    fixture_id = c("future", "finished"), group_id = c("A1", "A2"),
    home_team_id = c("team_france", "team_austria"), away_team_id = c("team_austria", "team_france"),
    home_display_name = c("France", "Austria"), away_display_name = c("Austria", "France"),
    scheduled_at_utc = c("2026-11-15T19:45:00Z", "2026-10-12T18:00:00Z"), status = c("scheduled", "completed"))
  bundle$artifacts$results <- transform(bundle$artifacts$fixtures[2L, , drop = FALSE],
    match_status = "completed", final_home_goals = 1L, final_away_goals = 2L, counts_for_standings = TRUE)
  bundle$artifacts$projected_outcomes <- data.frame(team_id = c("team_france", "team_austria"),
    group_id = "A1", league = "A", rank = c(1L, 2L), probability = c(1, 0), ranking_status = "projected")
  bundle$artifacts$progression_probabilities <- data.frame(team_id = c("team_france", "team_austria"),
    league = "A", p_quarter_final = c(1, 0), p_semi_final = c(.6, .2), p_final = c(.3, .1),
    p_champion = c(.2, .01), status = "projected")
  bundle
}
active_dashboard_embedded_json <- function(html) {
  sub('</script>.*$', '', sub('^.*<script id="dashboard-data" type="application/json">', '', html))
}
active_dashboard_visible_text <- function(html) {
  html <- gsub('<script[^>]*>.*?</script>|<style[^>]*>.*?</style>', '', html, perl = TRUE)
  gsub('<[^>]*>', '', html)
}

test_that("sampled extremes never confirm advancement without accepted evidence", {
  api <- active_dashboard_api(); payload <- api$phase17_payload_nations_league(active_dashboard_bundle(api))
  context <- api$phase17_public_context(payload)
  for (team in c("team_france", "team_austria")) {
    row <- list(team_id = team, league = "A")
    expect_identical(api$phase17_nl_qualification_status(payload, row, context), "")
    row$qualification_status <- if (team == "team_france") "qualified" else "eliminated"
    expect_identical(api$phase17_nl_qualification_status(payload, row, context), row$qualification_status)
  }
  html <- api$render_phase17_dashboard(payload)
  expect_false(grepl('class="status-mark qualified"', html, fixed = TRUE))
  expect_false(grepl('class="status-mark eliminated"', html, fixed = TRUE))
  confirmed <- active_dashboard_bundle(api)
  confirmed$artifacts$projected_outcomes$qualification_status <- c("qualified", "eliminated")
  confirmed_html <- api$render_phase17_dashboard(api$phase17_payload_nations_league(confirmed))
  expect_true(grepl('class="status-mark qualified"', confirmed_html, fixed = TRUE))
  expect_true(grepl('class="status-mark eliminated"', confirmed_html, fixed = TRUE))
})

test_that("active dashboard navigation has native controls and one match filter toolbar", {
  api <- active_dashboard_api(); payload <- api$phase17_payload_nations_league(active_dashboard_bundle(api))
  html <- api$render_phase17_dashboard(payload)
  for (id in c("nl-selected-team", "nl-selected-group", "nl-team-search", "nl-clear-filters")) {
    expect_equal(lengths(regmatches(html, gregexpr(paste0('id="', id, '"'), html, fixed = TRUE))), 1L, info = id)
  }
  expect_match(html, '<select[^>]*id="nl-selected-team"')
  expect_match(html, '<select[^>]*id="nl-selected-group"')
  expect_true(grepl('value="team_france"', html, fixed = TRUE))
  expect_true(grepl('value="team_austria"', html, fixed = TRUE))
  for (obsolete in c("filter-section", "filter-league-group", "filter-team", "filter-matchday", "filter-status")) {
    expect_false(grepl(paste0('id="', obsolete, '"'), html, fixed = TRUE))
  }
  expect_true(grepl('data-team-id="team_france', html, fixed = TRUE))
  expect_true(grepl('data-group-name="Group A1"', html, fixed = TRUE))
  expect_true(grepl("is-selected-team", html, fixed = TRUE))
  expect_true(grepl("[hidden]{display:none!important}", html, fixed = TRUE))
  expect_true(grepl('activeView.querySelectorAll(".nl-match-card")', html, fixed = TRUE))
  expect_true(grepl("UTC", html, fixed = TRUE))
  expect_false(grepl("No rows match the selected filters", html, fixed = TRUE))
  expect_identical(active_dashboard_embedded_json(html), api$phase17_json_script_escape(rawToChar(api$phase17_payload_bytes(payload))))
})

test_that("EURO pre-draw is a single waiting experience while active data still renders", {
  api <- active_dashboard_api()
  bundle <- api$phase17_fixture_bundle("uefa_euro_2028_qualifying")
  payload <- api$phase17_payload_euro(bundle); html <- api$render_phase17_dashboard(payload)
  expect_true(grepl("euro-predraw", html, fixed = TRUE))
  expect_false(grepl('id="filter-section"', html, fixed = TRUE))
  expect_false(grepl('data-section=', html, fixed = TRUE))
  expect_false(grepl("No rows match", html, fixed = TRUE))
  expect_match(html, 'href="[^\"]*nations[^\"]*#euro-2028"')
  expect_true(grepl('id="source-lineage"', html, fixed = TRUE))
  expect_identical(active_dashboard_embedded_json(html), api$phase17_json_script_escape(rawToChar(api$phase17_payload_bytes(payload))))
  active <- api$phase17_fixture_bundle("uefa_euro_2028_qualifying", lifecycle_state = "active")
  active$artifacts$structure <- data.frame(group_id = "A", display_name = "Group A")
  active_html <- api$render_phase17_dashboard(api$phase17_payload_euro(active))
  expect_false(grepl('class="euro-predraw', active_html, fixed = TRUE))
  expect_true(grepl("Group A", active_html, fixed = TRUE))
})

test_that("fixtures exclude completed accepted matches even when the source status is stale", {
  api <- active_dashboard_api(); bundle <- active_dashboard_bundle(api)
  bundle$artifacts$fixtures$status <- "scheduled"
  # The separate, accepted final result must override the fixture's stale state.
  bundle$artifacts$fixtures <- rbind(bundle$artifacts$fixtures, bundle$artifacts$fixtures[1L, , drop = FALSE])
  payload <- api$phase17_payload_nations_league(bundle); context <- api$phase17_public_context(payload)
  fixtures <- api$phase17_nl_render_fixtures(payload, context)
  results <- api$phase17_nl_render_results(payload, context)
  expect_true(grepl("France vs Austria", fixtures, fixed = TRUE))
  expect_false(grepl("Austria vs France", fixtures, fixed = TRUE))
  expect_equal(lengths(regmatches(fixtures, gregexpr('class="nl-match-card"', fixtures, fixed = TRUE))), 1L)
  expect_true(grepl("Austria vs France", results, fixed = TRUE))
  expect_false(grepl("France vs Austria", results, fixed = TRUE))
  expect_equal(lengths(regmatches(results, gregexpr('class="nl-match-card"', results, fixed = TRUE))), 1L)
})

test_that("legacy fixtures without IDs retain readable match cards", {
  api <- active_dashboard_api(); bundle <- active_dashboard_bundle(api)
  bundle$artifacts$fixtures <- bundle$artifacts$fixtures[1L, , drop = FALSE]
  bundle$artifacts$fixtures$fixture_id <- NULL
  bundle$artifacts$results <- NULL
  payload <- api$phase17_payload_nations_league(bundle)
  fixtures <- api$phase17_nl_render_fixtures(payload, api$phase17_public_context(payload))
  expect_true(grepl("France vs Austria", fixtures, fixed = TRUE))
  bundle$artifacts$fixtures <- data.frame(group_id = c("A1", "A1"),
    home_team = c("France", "Germany"), away_team = c("Austria", "Italy"),
    date = c("2026-11-15", "2026-11-16"), status = "scheduled")
  payload <- api$phase17_payload_nations_league(bundle)
  fixtures <- api$phase17_nl_render_fixtures(payload, api$phase17_public_context(payload))
  expect_true(grepl("France vs Austria", fixtures, fixed = TRUE))
  expect_true(grepl("Germany vs Italy", fixtures, fixed = TRUE))
  expect_equal(length(api$phase17_nl_match_rows(payload)), 2L)
})

test_that("explicit live state with a running score never renders as a final result", {
  api <- active_dashboard_api(); bundle <- active_dashboard_bundle(api)
  bundle$artifacts$fixtures <- bundle$artifacts$fixtures[1L, , drop = FALSE]
  bundle$artifacts$fixtures$status <- "live"
  bundle$artifacts$fixtures$home_goals <- 1L
  bundle$artifacts$fixtures$away_goals <- 0L
  bundle$artifacts$results <- NULL
  payload <- api$phase17_payload_nations_league(bundle)
  expect_length(api$phase17_nl_match_rows(payload, completed = FALSE), 1L)
  expect_length(api$phase17_nl_match_rows(payload, completed = TRUE), 0L)
  results <- api$phase17_nl_render_results(payload, api$phase17_public_context(payload))
  expect_false(grepl("Final 1", results, fixed = TRUE))
})

test_that("legacy accepted final scores override stale fixture state without a result status", {
  api <- active_dashboard_api(); bundle <- active_dashboard_bundle(api)
  bundle$artifacts$fixtures$status <- "scheduled"
  bundle$artifacts$results <- bundle$artifacts$results[, c("fixture_id", "final_home_goals", "final_away_goals", "counts_for_standings")]
  payload <- api$phase17_payload_nations_league(bundle)
  expect_length(api$phase17_nl_match_rows(payload, completed = FALSE), 1L)
  expect_length(api$phase17_nl_match_rows(payload, completed = TRUE), 1L)
  expect_identical(api$phase17_nl_match_rows(payload, completed = TRUE)[[1L]]$match_status, "final")
})

test_that("tree probabilities name the marginal event and internal identities remain attributes", {
  api <- active_dashboard_api(); bundle <- active_dashboard_bundle(api)
  bundle$artifacts$tournament_tree <- data.frame(stage_id = "league_a_quarter_final", stage_type = "quarter_final",
    stage_status = "projected", resolution_status = "projected", tie_id = c("internal-long-tie-0001", "internal-long-tie-0002"),
    match_id = c("internal-long-match-0001", "internal-long-match-0002"),
    home_team_id = "team_france", away_team_id = "team_austria",
    participant_slot_home = "A-group-winner-A1", participant_slot_away = "A-group-runner-up-A1")
  payload <- api$phase17_payload_nations_league(bundle)
  tree <- api$phase17_nl_render_tree(payload, api$phase17_public_context(payload))
  expect_true(grepl("France reaches quarter-finals", tree, fixed = TRUE))
  expect_false(grepl("Home path", tree, fixed = TRUE))
  expect_true(grepl('data-tie-id="internal-long-tie-0001"', tree, fixed = TRUE))
  expect_true(grepl('data-match-id="internal-long-match-0001"', tree, fixed = TRUE))
  expect_false(grepl("internal-long", active_dashboard_visible_text(tree), fixed = TRUE))
  expect_true(grepl("<details", tree, fixed = TRUE))
  expect_true(grepl("legal draw candidates", tree, fixed = TRUE))
  expect_true(grepl("internal-long-tie-0002", tree, fixed = TRUE))
  expect_true(grepl("do not form one joint bracket", tree, fixed = TRUE))
  bundle$artifacts$tournament_tree$stage_status <- "official"
  bundle$artifacts$tournament_tree$resolution_status <- "confirmed"
  official_payload <- api$phase17_payload_nations_league(bundle)
  official <- api$phase17_nl_render_tree(official_payload, api$phase17_public_context(official_payload))
  expect_false(grepl('class="tree-candidates"', official, fixed = TRUE))
  expect_false(grepl("Candidate 01", official, fixed = TRUE))
  expect_true(grepl('data-tie-id="internal-long-tie-0001"', official, fixed = TRUE))
  expect_true(grepl('data-tie-id="internal-long-tie-0002"', official, fixed = TRUE))
})

test_that("missing forecasts and blocked old bundles remain safe and escaped", {
  api <- active_dashboard_api(); bundle <- active_dashboard_bundle(api)
  bundle$lifecycle_state <- "revision_blocked"
  bundle$showing_last_accepted_snapshot <- TRUE
  bundle$warnings <- "<script>unsafe-refresh</script>"
  bundle$artifacts$progression_probabilities <- NULL
  html <- api$render_phase17_dashboard(api$phase17_payload_nations_league(bundle))
  expect_true(grepl("Refresh blocked", html, fixed = TRUE))
  expect_true(grepl("Showing last accepted snapshot", html, fixed = TRUE))
  expect_false(grepl("<script>unsafe-refresh</script>", html, fixed = TRUE))
  expect_true(grepl("&lt;script&gt;unsafe-refresh&lt;/script&gt;", html, fixed = TRUE))
  expect_true(grepl("Forecast pending", html, fixed = TRUE))
})
