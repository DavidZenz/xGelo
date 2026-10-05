library(testthat)

nl_article_test_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)
source(file.path(nl_article_test_root, "R/competition/source_contracts.R"), local = TRUE)
source(file.path(nl_article_test_root, "R/competition/uefa_nations_league_adapter.R"), local = TRUE)
nl_article_test_raw <- function() {
  path <- file.path(nl_article_test_root,
    "data/competition/local_raw/uefa_nations_league_2026_27/nl-2026-27-official-uefa-v2/fixtures.json")
  readBin(path, what = "raw", n = file.info(path)$size)
}
nl_article_test_payload <- function() jsonlite::fromJSON(rawToChar(nl_article_test_raw()), simplifyVector = FALSE)
nl_article_test_html <- function(payload) {
  lines <- vapply(payload, function(match) {
    home <- phase14_uefa_nl_team_display_name(match$homeTeam)
    away <- phase14_uefa_nl_team_display_name(match$awayTeam)
    label <- if (identical(match$status, "FINISHED")) {
      paste(home, match$score$total$home, "-", match$score$total$away, away)
    } else paste(home, "vs", away)
    label <- gsub(" ([0-9]+) - ([0-9]+) ", " \\1-\\2 ", label)
    paste0('<a href="/uefanationsleague/match/', match$id, '/">', label, '</a>')
  }, character(1))
  charToRaw(paste0('<html><h1>2026/27 UEFA Nations League: All the league phase fixtures and results</h1>',
    paste(lines, collapse = "\n"), '</html>'))
}

test_that("article fallback replays exact fixture IDs and score changes", {
  payload <- nl_article_test_payload()
  article <- nl_article_test_html(payload)
  next_match <- which(vapply(payload, function(match) identical(match$status, "UPCOMING"), logical(1)))[[1L]]
  id <- as.character(payload[[next_match]]$id)
  article <- charToRaw(sub(
    paste0("/match/", id, "/\">([^<]+) vs ([^<]+)"),
    paste0("/match/", id, "/\">\\1 2-1 \\2"), rawToChar(article)
  ))
  input <- phase14_uefa_nl_live_input(
    fetch_fn = function(...) stop("Phase 13 structured URL capture failed for fixtures after 3 attempt(s): DNS"),
    article_fetch_fn = function(url) list(raw_bytes = article, source_url = url),
    project_root = nl_article_test_root
  )
  expect_identical(input$official_endpoint, phase14_uefa_nl_article_url())
  expect_equal(nrow(input$resources$fixtures), 156L)
  expect_equal(sum(input$resources$results$match_status == "completed"),
    sum(vapply(payload, function(match) identical(match$status, "FINISHED"), logical(1))) + 1L)
  replay <- phase14_uefa_nl_adapt_raw_bytes(input$raw_bytes_by_resource$results, "results")
  expect_identical(replay, input$resources$results)
})

test_that("article fallback rejects incomplete coverage and score regression", {
  payload <- nl_article_test_payload()
  article <- rawToChar(nl_article_test_html(payload))
  article <- sub('<a href="/uefanationsleague/match/[0-9]+/">[^<]+</a>', "", article)
  expect_error(phase14_uefa_nl_overlay_article(payload, charToRaw(article)), "exact accepted fixture IDs")
  finished <- which(vapply(payload, function(match) identical(match$status, "FINISHED"), logical(1)))[[1L]]
  match <- payload[[finished]]
  article <- rawToChar(nl_article_test_html(payload))
  article <- sub(
    paste0('/match/', match$id, '/">', phase14_uefa_nl_team_display_name(match$homeTeam),
      ' [0-9]+-[0-9]+ ', phase14_uefa_nl_team_display_name(match$awayTeam)),
    paste0('/match/', match$id, '/">', phase14_uefa_nl_team_display_name(match$homeTeam),
      ' vs ', phase14_uefa_nl_team_display_name(match$awayTeam)), article
  )
  expect_error(phase14_uefa_nl_overlay_article(payload, charToRaw(article)), "omits a completed")
  payload[[finished]]$status <- "UPCOMING"
  expect_error(phase14_uefa_nl_validate_against_accepted(payload, nl_article_test_root),
    "remove an accepted completed result")
})

test_that("primary schema failure does not invoke the article fallback", {
  article_calls <- 0L
  expect_error(phase14_uefa_nl_live_input(
    fetch_fn = function(...) stop("Phase 13 structured response schema validation failed for fixtures"),
    article_fetch_fn = function(url) { article_calls <<- article_calls + 1L; NULL }
  ), "schema validation failed")
  expect_identical(article_calls, 0L)
})
