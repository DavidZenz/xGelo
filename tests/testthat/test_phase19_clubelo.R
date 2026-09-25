library(testthat)

clubelo_test_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/", mustWork = TRUE
)
source(file.path(clubelo_test_root, "R/common/phase18_canonical_hash.R"), local = .GlobalEnv)
source(file.path(clubelo_test_root, "R/club/clubelo.R"), local = .GlobalEnv)

clubelo_test_csv <- function(reversed = FALSE) {
  rows <- data.frame(
    Rank = c(12L, 7L, 21L),
    Club = c("Alpha FC", "Beta FC", "Gamma FC"),
    Elo = c(1842, 1910, 1765),
    From = c("2026-01-01", "2026-02-01", "2025-08-01"),
    To = c("", "", "2026-01-31"),
    Country = c("AAA", "BBB", "CCC"),
    Level = c(1L, 1L, 1L),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  if (reversed) rows <- rows[rev(seq_len(nrow(rows))), , drop = FALSE]
  paste(capture.output(write.csv(rows, row.names = FALSE, quote = TRUE)), collapse = "\n")
}

clubelo_test_performer <- function(reversed = FALSE, override = list()) {
  function(request) {
    response <- list(
      status = 200L,
      content_type = "text/csv; charset=utf-8",
      final_url = as.character(request$url[[1L]]),
      body = charToRaw(clubelo_test_csv(reversed)),
      retryable = FALSE
    )
    for (name in names(override)) response[[name]] <- override[[name]]
    response
  }
}

clubelo_test_reason <- function(expression) {
  condition <- tryCatch({ force(expression); NULL }, error = identity)
  expect_s3_class(condition, "phase19_clubelo_error")
  condition$reason_code
}

test_that("ClubElo request plans are fixed, explicit, and secret-free", {
  plan <- phase19_clubelo_request_plan("2026-09-24", c("RealMadrid", "ManCity"))
  expect_identical(names(plan), c("request_id", "source_kind", "requested_as_of_date", "clubelo_key", "url"))
  expect_identical(plan$source_kind, c("snapshot", "history", "history"))
  expect_identical(plan$url[[1L]], "http://api.clubelo.com/2026-09-24")
  expect_identical(plan$url[[2L]], "http://api.clubelo.com/RealMadrid")
  expect_false(any(grepl("token|secret|authorization", names(plan), ignore.case = TRUE)))
  expect_identical(clubelo_test_reason(phase19_clubelo_request_plan()), "invalid_request")
  expect_identical(clubelo_test_reason(phase19_clubelo_request_plan("2026-02-30")), "invalid_request")
  expect_identical(clubelo_test_reason(phase19_clubelo_request_plan("2026-09-24", "Real/Madrid")), "invalid_request")
})

test_that("ClubElo CSV responses are validated and canonicalized", {
  plan <- phase19_clubelo_request_plan("2026-09-24")
  first <- phase19_clubelo_fetch(
    plan, clubelo_test_performer(),
    clock_fn = function() as.POSIXct("2026-09-24T12:00:00Z", tz = "UTC")
  )[[1L]]
  second <- phase19_clubelo_fetch(
    plan, clubelo_test_performer(reversed = TRUE),
    clock_fn = function() as.POSIXct("2026-09-24T12:00:00Z", tz = "UTC")
  )[[1L]]
  expect_identical(first$schema_version, "phase19-clubelo-snapshot-v1")
  expect_equal(first$row_count, 3L)
  expect_true(all(grepl("^[0-9a-f]{64}$", first$ratings$row_sha256)))
  expect_identical(first$table_sha256, second$table_sha256)
  semantic <- setdiff(names(first$ratings), "source_raw_sha256")
  expect_identical(first$ratings[semantic], second$ratings[semantic])
  expect_false(identical(first$raw_sha256, second$raw_sha256))
  expect_identical(
    names(first$ratings),
    phase19_clubelo_normalized_columns()
  )
})

test_that("ClubElo transport and schema failures are typed", {
  plan <- phase19_clubelo_request_plan("2026-09-24")
  now <- function() as.POSIXct("2026-09-24T12:00:00Z", tz = "UTC")
  expect_identical(
    clubelo_test_reason(phase19_clubelo_fetch(plan, clubelo_test_performer(
      override = list(status = 404L)
    ), now)),
    "blocked_http_status"
  )
  expect_identical(
    clubelo_test_reason(phase19_clubelo_fetch(plan, clubelo_test_performer(
      override = list(content_type = "application/json")
    ), now)),
    "blocked_content_type"
  )
  expect_identical(
    clubelo_test_reason(phase19_clubelo_fetch(plan, clubelo_test_performer(
      override = list(final_url = "http://evil.example/data.csv")
    ), now)),
    "blocked_redirect_host"
  )
  https_redirect <- clubelo_test_performer(
    override = list(final_url = "https://api.clubelo.com/2026-09-24")
  )
  expect_silent(phase19_clubelo_fetch(plan, https_redirect, now))
  expect_identical(
    clubelo_test_reason(phase19_clubelo_fetch(plan, clubelo_test_performer(
      override = list(body = charToRaw("Rank,Club\n1,broken"))
    ), now)),
    "blocked_schema"
  )
  malformed <- charToRaw(paste(
    'Rank,Club,Elo,From,To,Country,Level',
    '1,Alpha FC,1842,2026-02-30,,AAA,1', sep = "\n"
  ))
  expect_identical(
    clubelo_test_reason(phase19_clubelo_fetch(plan, clubelo_test_performer(
      override = list(body = malformed)
    ), now)),
    "blocked_schema"
  )
})

test_that("ClubElo ratings can be selected by date and mapped only through explicit names", {
  plan <- phase19_clubelo_request_plan("2026-09-24")
  snapshot <- phase19_clubelo_fetch(
    plan, clubelo_test_performer(),
    clock_fn = function() as.POSIXct("2026-09-24T12:00:00Z", tz = "UTC")
  )[[1L]]
  selected <- phase19_clubelo_select_as_of(snapshot, "2026-02-15")
  expect_identical(selected$clubelo_club, c("Alpha FC", "Beta FC", "Gamma FC"))
  expect_equal(selected$clubelo_elo, c(1842, 1910, 1765))
  mapping <- data.frame(
    club_id = c("club_alpha", "club_beta"),
    clubelo_club = c("Alpha FC", "Beta FC"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  prior <- phase19_clubelo_prior(snapshot, mapping, "2026-02-15")
  expect_identical(prior$club_id, c("club_alpha", "club_beta"))
  expect_equal(prior$rating, c(1842, 1910))
  expect_true(all(grepl("^[0-9a-f]{64}$", prior$prior_sha256)))
  features <- phase19_clubelo_rating_features(
    prior,
    data.frame(
      fixture_id = "fixture-1", home_club_id = "club_alpha",
      away_club_id = "club_beta", stringsAsFactors = FALSE
    ),
    home_advantage = 60
  )
  expect_equal(features$clubelo_rating_difference, 1842 + 60 - 1910)
  expect_true(grepl("^[0-9a-f]{64}$", features$clubelo_source_table_sha256))
  missing <- rbind(mapping, data.frame(club_id = "club_delta", clubelo_club = "Delta FC"))
  expect_identical(
    clubelo_test_reason(phase19_clubelo_prior(snapshot, missing, "2026-02-15")),
    "unresolved_club"
  )
  duplicate <- rbind(mapping, data.frame(club_id = "club_gamma", clubelo_club = "Alpha FC"))
  expect_identical(
    clubelo_test_reason(phase19_clubelo_prior(snapshot, duplicate, "2026-02-15")),
    "invalid_mapping"
  )
})
