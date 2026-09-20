library(testthat)

phase18_fd_test_root <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else "."),
  winslash = "/"
)

phase18_fd_test_load <- function() {
  source(file.path(phase18_fd_test_root, "R/common/phase18_canonical_hash.R"), local = .GlobalEnv)
  source(file.path(phase18_fd_test_root, "R/competition/ucl_source_acceptance.R"), local = .GlobalEnv)
  source(file.path(phase18_fd_test_root, "R/club/identity.R"), local = .GlobalEnv)
  source(file.path(phase18_fd_test_root, "R/club/identity_bootstrap.R"), local = .GlobalEnv)
  adapter <- file.path(phase18_fd_test_root, "R/competition/football_data_org_adapter.R")
  if (file.exists(adapter)) source(adapter, local = .GlobalEnv)
  invisible(TRUE)
}

phase18_fd_test_registries <- function() {
  club_ids <- sprintf("club_%03d", seq_len(36L))
  source_ids <- as.character(1000L + seq_len(36L))
  names <- sprintf("Fixture Club %02d", seq_len(36L))
  registries <- list(
    clubs = data.frame(
      schema_version = phase18_club_identity_schema_version(), club_id = club_ids,
      entity_kind = "club", canonical_name = names, association_code = "FX",
      valid_from_utc = "2020-01-01T00:00:00Z", valid_to_utc = "",
      club_status = "active", row_sha256 = "", stringsAsFactors = FALSE,
      check.names = FALSE
    ),
    source_ids = data.frame(
      schema_version = phase18_club_identity_schema_version(), club_id = club_ids,
      source_system = "football_data_org_v4", source_club_id = source_ids,
      valid_from_utc = "2020-01-01T00:00:00Z", valid_to_utc = "",
      review_state = "approved", source_bundle_id = "fixture-club-review-v1",
      row_sha256 = "", stringsAsFactors = FALSE, check.names = FALSE
    ),
    aliases = data.frame(
      schema_version = phase18_club_identity_schema_version(), club_id = club_ids,
      source_system = "football_data_org_v4", alias = names,
      normalized_alias = phase18_normalize_club_name(names),
      valid_from_utc = "2020-01-01T00:00:00Z", valid_to_utc = "",
      review_state = "approved", reviewed_by = "fixture-reviewer",
      reviewed_at_utc = "2026-09-19T10:00:00Z", row_sha256 = "",
      stringsAsFactors = FALSE, check.names = FALSE
    )
  )
  phase18_hash_club_registry_rows(registries)
}

phase18_fd_test_expectations <- function() {
  phase18_hash_edition_expectations(data.frame(
    schema_version = "phase18-edition-expectation-v1",
    edition_id = "ucl_2026_27", lifecycle = "league_phase",
    expected_club_count = 36L, expected_league_phase_match_count = 144L,
    allowed_stages = "LEAGUE_STAGE|PLAYOFFS|LAST_16|QUARTER_FINALS|SEMI_FINALS|FINAL",
    standings_required = TRUE, expected_standings_rows = 36L,
    reviewer = "fixture-reviewer", reviewed_at_utc = "2026-09-19T10:00:00Z",
    row_sha256 = "", expectation_sha256 = "",
    stringsAsFactors = FALSE, check.names = FALSE
  ))
}

phase18_fd_test_payloads <- function() {
  ids <- 1000L + seq_len(36L)
  club_names <- sprintf("Fixture Club %02d", seq_len(36L))
  teams <- lapply(seq_along(ids), function(index) list(
    id = ids[[index]], name = club_names[[index]], shortName = club_names[[index]],
    tla = sprintf("F%02d", index), crest = paste0("https://img.example/", ids[[index]], ".png"),
    address = NULL, website = NULL, founded = 1900L + index, clubColors = "Blue",
    venue = paste("Fixture Ground", index), lastUpdated = "2026-09-19T11:00:00Z"
  ))
  statuses <- c("SCHEDULED", "TIMED", "FINISHED", "POSTPONED", "SUSPENDED", "CANCELLED", "AWARDED")
  matches <- lapply(seq_len(144L), function(index) {
    home <- ((index - 1L) %% 36L) + 1L
    away <- ((index + 10L) %% 36L) + 1L
    status <- statuses[((index - 1L) %% length(statuses)) + 1L]
    finished <- status %in% c("FINISHED", "AWARDED")
    list(
      id = 2000L + index, utcDate = sprintf("2026-09-%02dT18:00:00Z", ((index - 1L) %% 28L) + 1L),
      status = status, matchday = ((index - 1L) %% 8L) + 1L, stage = "LEAGUE_STAGE",
      lastUpdated = "2026-09-19T11:30:00Z",
      homeTeam = list(id = ids[[home]], name = club_names[[home]], shortName = club_names[[home]], tla = sprintf("F%02d", home)),
      awayTeam = list(id = ids[[away]], name = club_names[[away]], shortName = club_names[[away]], tla = sprintf("F%02d", away)),
      score = list(
        winner = if (finished) "HOME_TEAM" else NULL, duration = "REGULAR",
        fullTime = list(home = if (finished) 2L else NULL, away = if (finished) 1L else NULL),
        halfTime = list(home = if (finished) 1L else NULL, away = if (finished) 0L else NULL)
      )
    )
  })
  table <- lapply(seq_along(ids), function(index) list(
    position = index, team = teams[[index]][c("id", "name", "shortName", "tla", "crest")],
    playedGames = 8L, form = "W,D,L,W,D", won = 4L, draw = 2L, lost = 2L,
    points = 14L, goalsFor = 14L, goalsAgainst = 9L, goalDifference = 5L
  ))
  competition <- list(
    id = 2001L, area = list(id = 2077L, name = "Europe", code = "EUR"),
    name = "UEFA Champions League", code = "CL", type = "CUP",
    currentSeason = list(id = 2026L, startDate = "2026-07-01", endDate = "2027-05-31", currentMatchday = 1L),
    plan = "TIER_ONE", lastUpdated = "2026-09-19T11:45:00Z"
  )
  list(
    competition_metadata = competition,
    teams = list(count = 36L, competition = competition[c("id", "name", "code", "type")],
      season = competition$currentSeason, teams = teams),
    matches = list(filters = list(season = "2026"), resultSet = list(count = 144L, played = 42L),
      competition = competition[c("id", "name", "code", "type")], matches = matches),
    standings = list(filters = list(season = "2026"), competition = competition[c("id", "name", "code", "type")],
      season = competition$currentSeason,
      standings = list(list(stage = "LEAGUE_STAGE", type = "TOTAL", group = NULL, table = table)))
  )
}

phase18_fd_test_performer <- function(payloads, overrides = list(), secret = NULL) {
  calls <- list()
  performer <- function(request, attempt) {
    resource <- as.character(request$resource[[1L]])
    calls[[length(calls) + 1L]] <<- list(resource = resource, url = request$url[[1L]], attempt = attempt)
    body <- charToRaw(enc2utf8(jsonlite::toJSON(payloads[[resource]], auto_unbox = TRUE, null = "null")))
    response <- list(
      status = 200L, content_type = "application/json; charset=utf-8",
      final_url = request$url[[1L]], body = body,
      headers = list(`x-requests-available-minute` = "9"), retryable = FALSE
    )
    for (name in names(overrides)) response[[name]] <- overrides[[name]]
    response
  }
  attr(performer, "calls") <- function() calls
  attr(performer, "secret") <- secret
  performer
}

phase18_fd_test_fetch <- function(payloads = phase18_fd_test_payloads(), overrides = list()) {
  performer <- phase18_fd_test_performer(payloads, overrides)
  now <- as.POSIXct("2026-09-19T12:00:00Z", tz = "UTC")
  clock <- function() now
  sleep <- function(seconds) now <<- now + seconds
  phase18_fd_fetch_window(phase18_fd_request_plan(), performer, clock, sleep)
}

phase18_fd_test_reason <- function(expression) {
  condition <- tryCatch({ force(expression); NULL }, error = identity)
  expect_s3_class(condition, "phase18_fd_error")
  condition$reason_code
}

test_that("fixed request plan exposes exactly four competition-scoped HTTPS resources", {
  phase18_fd_test_load()
  expect_true(exists("phase18_fd_request_plan", mode = "function"))
  plan <- phase18_fd_request_plan()
  expect_identical(plan$resource, c("competition_metadata", "teams", "matches", "standings"))
  expect_identical(plan$url, c(
    "https://api.football-data.org/v4/competitions/CL",
    "https://api.football-data.org/v4/competitions/CL/teams?season=2026",
    "https://api.football-data.org/v4/competitions/CL/matches?season=2026",
    "https://api.football-data.org/v4/competitions/CL/standings?season=2026"
  ))
  expect_false(any(grepl("token|auth|secret", names(plan), ignore.case = TRUE)))
  expect_error(phase18_fd_request_plan(2025L), "season|2026")
})

test_that("fetch window preserves exact bytes and validates every transport boundary", {
  phase18_fd_test_load()
  payloads <- phase18_fd_test_payloads()
  performer <- phase18_fd_test_performer(payloads)
  now <- as.POSIXct("2026-09-19T12:00:00Z", tz = "UTC")
  sleeps <- numeric()
  fetched <- phase18_fd_fetch_window(
    phase18_fd_request_plan(), performer, function() now,
    function(seconds) { sleeps <<- c(sleeps, seconds); now <<- now + seconds }
  )
  expect_identical(names(fetched), c("competition_metadata", "teams", "matches", "standings"))
  expect_equal(length(attr(performer, "calls")()), 4L)
  expect_true(all(vapply(fetched, function(item) is.raw(item$body), logical(1))))
  expect_true(all(vapply(fetched, function(item) grepl("^[0-9a-f]{64}$", item$raw_sha256), logical(1))))
  expect_lte(length(sleeps), 3L)

  expect_identical(phase18_fd_test_reason(phase18_fd_test_fetch(overrides = list(status = 401L))), "blocked_http_status")
  expect_identical(phase18_fd_test_reason(phase18_fd_test_fetch(overrides = list(content_type = "text/html"))), "blocked_content_type")
  expect_identical(phase18_fd_test_reason(phase18_fd_test_fetch(overrides = list(final_url = "https://evil.example/v4/competitions/CL"))), "blocked_redirect_host")
  expect_identical(phase18_fd_test_reason(phase18_fd_test_fetch(overrides = list(body = charToRaw("null")))), "blocked_null_resource")
})

test_that("complete fictional UCL window projects deterministic canonical tables through club identity", {
  phase18_fd_test_load()
  projected <- phase18_fd_project_resources(
    phase18_fd_test_fetch(), "ucl_2026_27", phase18_fd_test_registries(),
    phase18_fd_test_expectations(), now_utc = "2026-09-19T12:00:00Z"
  )
  expect_equal(nrow(projected$competition), 1L)
  expect_equal(nrow(projected$clubs), 36L)
  expect_equal(nrow(projected$matches), 144L)
  expect_equal(nrow(projected$standings), 36L)
  expect_equal(nrow(projected$lifecycle), 1L)
  expect_true(all(grepl("^club_", projected$clubs$club_id)))
  expect_true(all(projected$matches$home_club_id %in% projected$clubs$club_id))
  expect_true(all(projected$matches$away_club_id %in% projected$clubs$club_id))
  expect_identical(projected$coverage$club_count, 36L)
  expect_identical(projected$coverage$league_phase_match_count, 144L)
  expect_true(projected$coverage$identity_passed)
  expect_true(projected$coverage$pagination_complete)
})

test_that("semantic shortfall excess enum pagination freshness and identity failures are typed", {
  phase18_fd_test_load()
  expect_reason <- function(payloads, expected) {
    actual <- phase18_fd_test_reason(phase18_fd_project_resources(
      phase18_fd_test_fetch(payloads), "ucl_2026_27", phase18_fd_test_registries(),
      phase18_fd_test_expectations(), now_utc = "2026-09-19T12:00:00Z"
    ))
    expect_identical(actual, expected)
  }
  for (count in c(35L, 37L)) {
    payloads <- phase18_fd_test_payloads()
    payloads$teams$teams <- payloads$teams$teams[seq_len(min(count, 36L))]
    if (count == 37L) payloads$teams$teams[[37L]] <- within(payloads$teams$teams[[1L]], { id <- 9999L; name <- "Extra Club" })
    payloads$teams$count <- count
    expect_reason(payloads, "blocked_cardinality")
  }
  for (count in c(143L, 145L)) {
    payloads <- phase18_fd_test_payloads()
    if (count == 143L) payloads$matches$matches <- payloads$matches$matches[-144L]
    if (count == 145L) payloads$matches$matches[[145L]] <- within(payloads$matches$matches[[1L]], id <- 999999L)
    payloads$matches$resultSet$count <- count
    expect_reason(payloads, "blocked_cardinality")
  }
  payloads <- phase18_fd_test_payloads(); payloads$matches$matches[[1L]]$stage <- "INVENTED_STAGE"
  expect_reason(payloads, "blocked_unknown_stage")
  payloads <- phase18_fd_test_payloads(); payloads$matches$matches[[1L]]$status <- "INVENTED_STATUS"
  expect_reason(payloads, "blocked_unknown_status")
  payloads <- phase18_fd_test_payloads(); payloads$matches$matches[[2L]]$id <- payloads$matches$matches[[1L]]$id
  expect_reason(payloads, "blocked_duplicate_id")
  payloads <- phase18_fd_test_payloads(); payloads$matches$matches[[1L]]$homeTeam <- NULL
  expect_reason(payloads, "blocked_missing_team")
  payloads <- phase18_fd_test_payloads(); payloads$teams$teams <- list(); payloads$teams$count <- 0L
  expect_reason(payloads, "blocked_empty_resource")
  payloads <- phase18_fd_test_payloads(); payloads$matches$pagination <- list(currentPage = 1L, totalPages = 2L)
  expect_reason(payloads, "blocked_incomplete_pagination")
  payloads <- phase18_fd_test_payloads(); payloads$competition_metadata$lastUpdated <- "2026-09-10T00:00:00Z"
  expect_reason(payloads, "blocked_stale_resource")
  payloads <- phase18_fd_test_payloads(); payloads$competition_metadata$code <- "PL"
  expect_reason(payloads, "blocked_edition_identity")
  payloads <- phase18_fd_test_payloads(); payloads$competition_metadata$currentSeason$startDate <- "2025-07-01"
  expect_reason(payloads, "blocked_edition_identity")
  payloads <- phase18_fd_test_payloads(); payloads$teams$teams[[1L]]$id <- 9999L
  expect_reason(payloads, "blocked_unresolved_club")
  for (count in c(35L, 37L)) {
    payloads <- phase18_fd_test_payloads()
    table <- payloads$standings$standings[[1L]]$table
    if (count == 35L) table <- table[-36L]
    if (count == 37L) table[[37L]] <- within(table[[1L]], { position <- 37L; team$id <- 9999L })
    payloads$standings$standings[[1L]]$table <- table
    expect_reason(payloads, "blocked_standings")
  }
})

test_that("sentinel token cannot escape the live performer boundary or fetched projection", {
  phase18_fd_test_load()
  sentinel <- "phase18-super-secret-sentinel"
  old <- Sys.getenv("FOOTBALL_DATA_API_TOKEN", unset = NA_character_)
  on.exit(if (is.na(old)) Sys.unsetenv("FOOTBALL_DATA_API_TOKEN") else Sys.setenv(FOOTBALL_DATA_API_TOKEN = old), add = TRUE)
  Sys.setenv(FOOTBALL_DATA_API_TOKEN = sentinel)
  payloads <- phase18_fd_test_payloads()
  performer <- phase18_fd_test_performer(payloads, secret = sentinel)
  fetched <- phase18_fd_fetch_window(
    phase18_fd_request_plan(), performer,
    function() as.POSIXct("2026-09-19T12:00:00Z", tz = "UTC"), function(...) invisible(NULL)
  )
  serialized <- paste(capture.output(str(fetched)), collapse = "\n")
  expect_false(grepl(sentinel, serialized, fixed = TRUE))
  expect_false(any(grepl("token|authorization|request_object", names(fetched[[1L]]), ignore.case = TRUE)))
  expect_silent(phase18_fd_assert_secret_absent(fetched, sentinel))
})
