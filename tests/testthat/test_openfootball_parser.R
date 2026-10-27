library(testthat)

openfootball_test_root <- normalizePath(file.path(
  getwd(), if (basename(getwd()) == "testthat") "../.." else "."
), winslash = "/")
source(file.path(openfootball_test_root, "R/club/openfootball_parser.R"))

test_that("native domestic results preserve dates, names and missing UTC clocks", {
  text <- c("= Deutsche Bundesliga 2021/22", "# Matches 3", "▪ Matchday 1", "Fri Aug 13",
    "  20:30 Borussia Mönchengladbach  1-1 (1-1)  FC Bayern München",
    "Sat Jan 8 2022", "       1. FC Union Berlin  2-0 (1-0)  TSG 1899 Hoffenheim",
    "▪ Matchday 2", "Sun Aug 15", "  15:30 1. FC Köln  3-1 (1-1)  Hertha BSC")
  rows <- phase18_parse_openfootball_text(text, "2021-22", "germany")
  expect_identical(names(rows), phase18_openfootball_exchange_schema())
  expect_identical(rows$event_date, c("2021-08-13", "2022-01-08", "2021-08-15"))
  expect_identical(rows$source_match_id, c("line_000005", "line_000007", "line_000010"))
  expect_identical(rows$home_name, c("Borussia Mönchengladbach", "1. FC Union Berlin", "1. FC Köln"))
  expect_identical(rows$away_name[[1L]], "FC Bayern München")
  expect_true(all(rows$kickoff_utc == "" & rows$evidence_updated_at_utc == ""))
  expect_true(all(rows$score_semantics == "regulation"))
  expect_equal(attr(rows, "summary")$parsed_matches, 3L)
  expect_identical(attr(rows, "diagnostics")$source_line, text[c(5L, 7L, 10L)])
  expect_identical(rows, phase18_parse_openfootball_text(text, "2021-22", "germany"))
})

test_that("European stages and explicit ET and shootout scores keep regulation separate", {
  rows <- phase18_parse_openfootball_text(c(
    "# Matches 4", "▪ Group A", "Wed Sep 15 2021",
    "21:00 Manchester City (ENG) v RB Leipzig (GER) 6-3 (3-1)",
    "▪ Quarterfinals", "Tue Apr 12 2022",
    "21:00 Real Madrid (ESP) v Chelsea FC (ENG) 2-3 a.e.t. (1-3, 0-1)",
    "▪ Semifinals", "Wed May 4",
    "21:00 Liverpool FC (ENG) v Paris Saint-Germain FC (FRA) 1-4 pen. 0-1 a.e.t. (0-1, 0-1)",
    "21:00 FC Internazionale Milano (ITA) v FC Barcelona (ESP) 4-3 (2-0)"
  ), "2021-22", "ucl")
  expect_identical(rows$home_name[[1L]], "Manchester City")
  expect_identical(rows$stage, c("GROUP_STAGE", "QUARTER_FINALS", "SEMI_FINALS", "SEMI_FINALS"))
  expect_identical(rows$score_text, c("6-3", "1-3; aet 2-3", "0-1; aet 0-1; pens 1-4", "4-3"))
  expect_identical(rows$score_semantics,
    c("regulation", "extra_time", "penalties", "unresolved_knockout_duration"))
  expect_identical(attr(rows, "exclusions")$reason, "knockout_regulation_duration_not_established")
})

test_that("calendar seasons and scheduled rows never fabricate completed scores", {
  rows <- phase18_parse_openfootball_text(c("# Matches 2", "▪ Matchday 1", "Sat Mar 29 2025",
    "16:00 Strømsgodset IF v Rosenborg BK 1-2 (0-1)", "Wed Jul 16",
    "19:00 Fredrikstad FK v FK Bodø/Glimt"), "2025", "norway")
  expect_identical(rows$event_date, c("2025-03-29", "2025-07-16"))
  expect_identical(rows$status, c("completed", "scheduled"))
  expect_identical(rows$score_text, c("1-2", ""))
  expect_equal(attr(rows, "summary")$completed_matches, 1L)
  expect_identical(attr(rows, "exclusions")$reason, "not_completed")
})

test_that("multiline scorer annotations cannot become matches", {
  rows <- phase18_parse_openfootball_text(c("# Matches 2", "▪ Regular Season - 1", "Fri Aug 15 2025",
    "19:00 Liverpool 4-2 (1-0) Bournemouth", " (Hugo EKITIKE 37', Cody GAKPO 49';",
    "  Antoine SEMENYO 64', 76')", "Sat Aug 16", "12:30 Aston Villa 0-0 (0-0) Newcastle United"
  ), "2025-26", "england")
  expect_equal(nrow(rows), 2L)
  expect_equal(attr(rows, "summary")$errors, 0L)
  expect_identical(rows$source_match_id, c("line_000004", "line_000008"))
})

test_that("unsupported lines and declared count mismatches fail closed with diagnostics", {
  bad <- c("# Matches 2", "▪ Matchday 1", "Fri Aug 13 2021", "A FC 1-0 B FC", "C FC 2~1 D FC")
  error <- tryCatch(phase18_parse_openfootball_text(bad, "2021-22", "england"), error = identity)
  expect_s3_class(error, "openfootball_parse_error")
  expect_equal(error$summary$errors, 1L)
  expect_identical(error$diagnostics$source_line[[2L]], "C FC 2~1 D FC")
  expect_equal(error$diagnostics$line_number[[2L]], 5L)
  partial <- phase18_parse_openfootball_text(bad, "2021-22", "england", strict = FALSE)
  expect_false(attr(partial, "summary")$declared_count_matches)
  expect_error(phase18_parse_openfootball_text(bad[1:4], "2021-22", "england"), class = "openfootball_parse_error")
  expect_error(phase18_parse_openfootball_text(c("▪ Matchday 1", "Fri Feb 30 2022", "A 1-0 B"),
    "2021-22", "england"), class = "openfootball_parse_error")
  middle_et <- phase18_parse_openfootball_text(c("▪ Quarterfinals", "Fri Aug 13 2021",
    "A 2-3 a.e.t. (1-1, 0-0) B"), "2021-22", "ucl")
  expect_identical(middle_et$score_text,"1-1; aet 2-3")
  expect_identical(middle_et$away_name,"B")
  ambiguous_et <- phase18_parse_openfootball_text(c("▪ Quarterfinals", "Fri Aug 13 2021",
    "A 1-0 a.e.t. (0-0) B"), "2021-22", "ucl")
  expect_identical(ambiguous_et$score_semantics,"unresolved")
  expect_error(phase18_parse_openfootball_text(c("▪ Matchday 1", "Fri Aug 13 2021",
    "A 1-0 B", "(Scorer 44'", "Sat Aug 14", "C 1-0 D"), "2021-22", "england"),
    class = "openfootball_parse_error")
})

test_that("explicit first legs alone establish ordinal and regulation scope", {
  rows <- phase18_parse_openfootball_text(c("# Matches 2", "▪ Round 1, First Leg", "Tue Jul 9 2024",
    "17:30 A (LTU) v B (FIN) 3-0 (1-0)", "▪ Round 1, Second Leg", "Tue Jul 16",
    "17:30 B (FIN) v A (LTU) 1-0 (1-0)"), "2024-25", "ucl_qualifying")
  expect_identical(attr(rows, "diagnostics")$leg_ordinal, c("1", "2"))
  expect_identical(rows$score_semantics, c("regulation", "unresolved_knockout_duration"))
  no_ordinal <- phase18_parse_openfootball_text(c("▪ Round 1", "Tue Jul 9 2024",
    "A (LTU) v B (FIN) 3-0 (1-0)"), "2024-25", "ucl_qualifying")
  expect_identical(attr(no_ordinal, "diagnostics")$leg_ordinal, "")
  expect_identical(no_ordinal$score_semantics, "unresolved_knockout_duration")
})

test_that("native domestic phase headers retain league scope and awarded exclusions", {
  rows <- phase18_parse_openfootball_text(c("# Matches 6", "▪ 1. Round", "Fri Aug 15 2025", "A v B 1-0 (1-0)",
    "▪ Championship, Matchday 23", "A v B 2-0 (1-0)",
    "▪ Relegation Round - 2", "A v B 3-0 (1-0)",
    "▪▪ Matchday 24", "A v B 4-0 (1-0)",
    "▪ ECL Playoffs, Matchday 1", "A v B 5-0 (1-0)", "A v B 3-0 [awarded]"), "2025-26", "greece")
  expect_true(all(rows$score_semantics[1:5] == "regulation"))
  expect_identical(rows$stage[2:3], c("CHAMPIONSHIP_LEAGUE_STAGE", "RELEGATION_LEAGUE_STAGE"))
  expect_identical(rows$status[[6L]], "awarded")
  expect_identical(rows$score_semantics[[6L]], "awarded")
  expect_identical(attr(rows, "exclusions")$reason, "awarded_result_not_played_regulation")
  expect_equal(attr(rows, "summary")$awarded_matches, 1L)
  expect_true(attr(rows, "summary")$all_fixtures_have_results)
})

test_that("legacy native dates, bare stage headers and dot clocks retain source evidence", {
  text <- c("= English Premier League 2021/22", "Matchday 1", "[Fri Aug/13]",
    "20.00 Brentford FC 2-0 (1-0) Arsenal FC", "Matchday 2", "[Sat Jan/8 2022]",
    "12.30 Aston Villa FC 1-0 Everton FC")
  rows <- phase18_parse_openfootball_text(text,"2021-22","england")
  expect_identical(rows$event_date,c("2021-08-13","2022-01-08"))
  expect_identical(rows$home_name,c("Brentford FC","Aston Villa FC"))
  expect_true(all(rows$kickoff_utc==""))
  expect_identical(rows$source_match_id,c("line_000004","line_000007"))
  expect_true(is.na(attr(rows,"summary")$declared_matches))
  expect_identical(attr(rows,"diagnostics")$source_line,text[c(4L,7L)])
  cl <- phase18_parse_openfootball_text(c("Group A","[Wed Sep/15]",
    "21.00 Manchester City (ENG) v RB Leipzig (GER) 6-3 (3-1)"),"2021-22","ucl")
  expect_identical(cl$stage,"GROUP_STAGE")
  section <- phase18_parse_openfootball_text(c("== Group","Matchday 1","[Wed Sep/15]",
    "21.00 Manchester City (ENG) v RB Leipzig (GER) 6-3 (3-1)"),"2021-22","ucl")
  expect_identical(section$stage,"GROUP_STAGE")
  unknown_phase <- phase18_parse_openfootball_text(c("Matchday 1","[Wed Sep/15]",
    "21.00 A v B 1-0"),"2021-22","ucl")
  expect_identical(unknown_phase$score_semantics,"unresolved_knockout_duration")
})

test_that("verified localized native grammars preserve actual date and score fields", {
  samples <- list(
    c("Spieltag 1","[Fr 13.8.]","20.30 Bor. Mönchengladbach 1:1 (1:1) Bayern München"),
    c("1^ Giornata","[Sab. 21.8.]","18.30 Hellas Verona 2-3 US Sassuolo Calcio"),
    c("Jornada 1","[Vie. 13.8.]","21.00 Valencia CF 1-0 (1-0) Getafe CF"),
    c("Journée 1","[Ven 6. Août]","21.00 AS Monaco 1-1 (1-1) FC Nantes"),
    c("Jornada 1","[Sex, 11/Agosto]","20.15 SC Braga 1-2 (1-0) FC Famalicão"))
  dates <- c("2021-08-13","2021-08-21","2021-08-13","2021-08-06","2021-08-11")
  for(i in seq_along(samples)) {
    rows <- phase18_parse_openfootball_text(samples[[i]],"2021-22","england")
    expect_identical(rows$event_date,dates[[i]])
    expect_identical(rows$stage,"REGULAR_SEASON")
    expect_identical(rows$score_semantics,"regulation")
  }
  scheduled <- phase18_parse_openfootball_text(c("» Matchday 1","[Fri Aug/15]","20.00 A - B"),"2025-26","england")
  expect_identical(scheduled$status,"scheduled")
  expect_identical(scheduled$home_name,"A")
  expect_identical(scheduled$away_name,"B")
  flagged <- phase18_parse_openfootball_text(c("» Matchday 1","[Fri Aug/15]",
    "20.00 A v OFI Heraklion [postponed]","20.00 C - SC Heerenveen [cancelled]"),"2025-26","england")
  expect_identical(flagged$away_name,c("OFI Heraklion","SC Heerenveen"))
  expect_identical(flagged$status,c("postponed","cancelled"))
  expect_equal(attr(flagged,"summary")$scheduled_matches,2L)
  expect_equal(attr(flagged,"summary")$postponed_matches,1L)
  expect_equal(attr(flagged,"summary")$cancelled_matches,1L)
  portugal_set <- phase18_parse_openfootball_text(c("Jornada 1","[Sex, 1/Set]","A 1-0 B"),"2023-24","portugal")
  expect_identical(portugal_set$event_date,"2023-09-01")
  playoff_number <- phase18_parse_openfootball_text(c("Playoff Round 1","[Tue Aug/16]","A 1-0 B"),"2022-23","ucl")
  expect_identical(playoff_number$stage,"PLAYOFFS")
})

test_that("native file boundary permits only declared formats", {
  path <- tempfile(fileext = ".txt")
  on.exit(unlink(path))
  writeLines(c("▪ Matchday 1", "Fri Aug 13 2021", "A 1-0 B"), path)
  rows <- phase18_read_openfootball_source(path, data.frame(season_id = "2021-22", competition_id = "england"))
  expect_equal(nrow(rows), 1L)
  csv <- tempfile(fileext = ".csv")
  on.exit(unlink(csv), add = TRUE)
  write.csv(rows, csv, row.names = FALSE)
  expect_identical(names(phase18_read_openfootball_source(csv, NULL)), names(rows))
  expect_error(phase18_read_openfootball_source("source.json", NULL), "Unsupported")
})
