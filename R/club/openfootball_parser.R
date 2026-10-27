# Native football.txt ingestion. Displayed clocks have no declared timezone and
# must not be turned into UTC kickoffs. Source line numbers identify retained
# raw evidence within the separately hashed and commit-pinned source file.

phase18_openfootball_exchange_schema <- function() c(
  "source_match_id", "event_date", "kickoff_utc", "stage", "status",
  "home_name", "away_name", "score_text", "score_semantics", "evidence_updated_at_utc"
)

phase18_openfootball_stage <- function(header, competition_id) {
  value <- tolower(header)
  if (grepl("^(group|gruppe)\\b", value)) return("GROUP_STAGE")
  if (grepl("^league\\b", value)) return("LEAGUE_STAGE")
  if (grepl("^(regular season|matchday|spieltag|jornada|journée)\\b|^[0-9]+\\^ giornata$", value)) return("REGULAR_SEASON")
  if (grepl("^championship(?:,? +matchday| round)", value)) return("CHAMPIONSHIP_LEAGUE_STAGE")
  if (grepl("^relegation(?:,? +matchday| round)", value)) return("RELEGATION_LEAGUE_STAGE")
  if (grepl("^europe,? +matchday|^ecl playoffs,? +matchday", value)) return("EUROPE_LEAGUE_STAGE")
  if (grepl("^[0-9]+\\. round$", value) && !grepl("ucl|champions", competition_id, ignore.case = TRUE)) {
    return("REGULAR_SEASON")
  }
  if (grepl("round of 16", value)) return("LAST_16")
  if (grepl("quarter-?final", value)) return("QUARTER_FINALS")
  if (grepl("semi-?final", value)) return("SEMI_FINALS")
  if (grepl("playoff", value)) return("PLAYOFFS")
  if (grepl("final", value)) return("FINAL")
  if (!nzchar(header) && !grepl("ucl|champions", competition_id, ignore.case = TRUE)) {
    return("REGULAR_SEASON")
  }
  toupper(gsub("[^A-Za-z0-9]+", "_", header))
}

phase18_openfootball_score <- function(value, regulation_only) {
  pair <- "([0-9]+-[0-9]+)"
  extract <- function(pattern) {
    found <- regmatches(value, regexec(pattern, value, perl = TRUE))[[1L]]
    if (length(found)) found[-1L] else character()
  }
  # football.txt lists shootout, then extra-time final, then regulation and
  # half-time scores. A halftime score alone cannot recover regulation goals.
  penalty <- extract(paste0("^", pair, "\\s+pen\\.\\s+", pair,
                            "\\s+a\\.e\\.t\\.\\s+\\(", pair, ",\\s*", pair, "\\)$"))
  if (length(penalty)) return(list(
    text = paste0(penalty[[3L]], "; aet ", penalty[[2L]], "; pens ", penalty[[1L]]),
    semantics = "penalties", reason = ""
  ))
  extra <- extract(paste0("^", pair, "\\s+a\\.e\\.t\\.\\s+\\(", pair, ",\\s*", pair, "\\)$"))
  if (length(extra)) return(list(
    text = paste0(extra[[2L]], "; aet ", extra[[1L]]), semantics = "extra_time", reason = ""
  ))
  plain <- extract(paste0("^", pair, "(?:\\s+\\(", pair, "\\))?$"))
  if (length(plain)) return(list(
    text = plain[[1L]],
    semantics = if (regulation_only) "regulation" else "unresolved_knockout_duration",
    reason = if (regulation_only) "" else "knockout_regulation_duration_not_established"
  ))
  list(text = value, semantics = "unresolved", reason = "unsupported_score_semantics")
}

phase18_parse_openfootball_text <- function(text, season_id, competition_id, strict = TRUE) {
  if (!is.character(text) || anyNA(text) || length(season_id) != 1L ||
      !grepl("^[0-9]{4}([-/][0-9]{2}([0-9]{2})?)?$", season_id) ||
      length(competition_id) != 1L || is.na(competition_id)) {
    stop("Native OpenFootball parsing requires text, season_id and competition_id", call. = FALSE)
  }
  lines <- if (length(text) == 1L) strsplit(text, "\n", fixed = TRUE)[[1L]] else text
  lines <- sub("\r$", "", lines)
  start_year <- as.integer(substr(season_id, 1L, 4L))
  calendar_year <- nchar(season_id) == 4L
  months <- c("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
  start_month <- 7L
  date_metadata <- grep("^#\\s+Dates?\\s",lines,value=TRUE)
  if(length(date_metadata)) {
    first_month <- regmatches(date_metadata[[1L]],regexec("(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun) ([A-Z][a-z]{2})",date_metadata[[1L]],perl=TRUE))[[1L]]
    if(length(first_month) && !is.na(match(first_month[[2L]],months))) start_month <- min(7L,match(first_month[[2L]],months))
  }
  local_months <- list(c("janvier","janv","jan","janeiro"),c("février","fevrier","févr","fevr","fév","fev","fevereiro"),c("mars","março","marco"),
    c("avril","avr","abril"),c("mai","maio"),c("juin","junho"),c("juillet","juil","julho"),c("août","agosto"),
    c("septembre","sept","set","setembro"),c("octobre","oct","outubro"),c("novembre","nov","novembro"),c("décembre","decembre","déc","dec","dezembro"))
  rows <- list(); diagnostics <- list(); stage_header <- ""; section_header <- ""; event_date <- ""
  scorer_depth <- 0L
  diagnostic <- function(index, status, reason = "", stage = "") {
    diagnostics[[length(diagnostics) + 1L]] <<- data.frame(
      line_number = as.integer(index), source_match_id = sprintf("line_%06d", index),
      stage = stage, stage_header = stage_header,
      leg_ordinal = if (grepl("(first|1st) leg|leg 1\\b", stage_header, ignore.case = TRUE)) "1" else {
        if (grepl("(second|2nd) leg|leg 2\\b", stage_header, ignore.case = TRUE)) "2" else ""
      }, parse_status = status, reason = reason,
      source_line = lines[[index]], stringsAsFactors = FALSE
    )
  }
  count_char <- function(value, char) nchar(value) - nchar(gsub(char, "", value, fixed = TRUE))
  clean_team <- function(value) trimws(sub("\\s+\\([A-Z]{3}\\)$", "", trimws(value)))
  for (index in seq_along(lines)) {
    value <- trimws(lines[[index]])
    if(grepl("^={2,}\\s*",value)) {section_header <- trimws(sub("^=+","",value));next}
    if (!nzchar(value) || grepl("^[=#]", value)) next
    bare_stage <- grepl(paste0("^((?:Matchday|Spieltag|Jornada|Journée) [0-9]+|[0-9]+\\^ Giornata|(?:Group|Gruppe) [A-Z]|Round (?:[0-9]+|of 16)|",
      "(?:Preliminary Round|Playoff Round(?: [0-9]+)?|Quarter-?finals|Semi-?finals|Final|Playoffs|League|Championship|Relegation|Europe|ECL Playoffs|Platzierung|Middle Playoffs|Europa League Finals)",
      "(?:,.*|$))$"), value, perl = TRUE)
    if (grepl("^[▪»]", value) || bare_stage) {
      if (scorer_depth != 0L) diagnostic(index, "error", "unclosed_scorer_annotation")
      stage_header <- trimws(sub("^[▪»[:space:]]+", "", value)); scorer_depth <- 0L; next
    }
    date_value <- if (grepl("^\\[.*\\]$",value)) sub("^\\[(.*)\\]$","\\1",value) else value
    date_value <- sub("([A-Z][a-z]{2})/([0-9])", "\\1 \\2", date_value)
    date_match <- regmatches(date_value, regexec(
      "^(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun) ([A-Z][a-z]{2}) ([0-9]{1,2})(?: ([0-9]{4}))?$",
      date_value, perl = TRUE
    ))[[1L]]
    if (!length(date_match) && grepl("^\\[.*\\]$",value)) {
      numeric_date <- regmatches(date_value,regexec("^[^0-9]+ ([0-9]{1,2})\\.([0-9]{1,2})\\.(?:([0-9]{4}))?$",date_value,perl=TRUE))[[1L]]
      if(length(numeric_date)) {
        month_number <- as.integer(numeric_date[[3L]])
        month_name <- if(month_number %in% 1:12) months[[month_number]] else "Invalid"
        date_match <- c("",month_name,numeric_date[[2L]],numeric_date[[4L]])
      } else {
        named_date <- regmatches(date_value,regexec("^[^0-9]+ ([0-9]{1,2})[./ ]+([^0-9 /]+)(?: ([0-9]{4}))?$",date_value,perl=TRUE))[[1L]]
        if(length(named_date)) {
          month_number <- which(vapply(local_months,function(x) tolower(named_date[[3L]]) %in% x,logical(1)))
          if(length(month_number)==1L) date_match <- c("",months[[month_number]],named_date[[2L]],named_date[[4L]])
        }
      }
    }
    if (length(date_match)) {
      if (scorer_depth != 0L) diagnostic(index, "error", "unclosed_scorer_annotation")
      month <- match(date_match[[2L]], months)
      year <- if (nzchar(date_match[[4L]])) as.integer(date_match[[4L]]) else {
        start_year + as.integer(!calendar_year && !is.na(month) && month < start_month)
      }
      candidate <- sprintf("%04d-%02d-%02d", year, month, as.integer(date_match[[3L]]))
      parsed_date <- suppressWarnings(as.Date(candidate, format = "%Y-%m-%d"))
      if (is.na(parsed_date) || !identical(format(parsed_date, "%Y-%m-%d"), candidate)) {
        diagnostic(index, "error", "invalid_event_date"); event_date <- ""
      } else event_date <- candidate
      scorer_depth <- 0L; next
    }
    # Goalscorer continuation is bracket-delimited, including multiline lists.
    if (scorer_depth > 0L || startsWith(value, "(")) {
      scorer_depth <- scorer_depth + count_char(value, "(") - count_char(value, ")")
      if (scorer_depth < 0L) diagnostic(index, "error", "unbalanced_scorer_annotation")
      next
    }
    stage <- phase18_openfootball_stage(stage_header, competition_id)
    if(grepl("ucl|champions",competition_id,ignore.case=TRUE) && grepl("^Matchday ",stage_header)) {
      stage <- if(grepl("^Group\\b",section_header,ignore.case=TRUE)) "GROUP_STAGE" else {
        if(grepl("^League\\b",section_header,ignore.case=TRUE)) "LEAGUE_STAGE" else "UNRESOLVED_COMPETITION_PHASE"
      }
    }
    body <- sub("^[0-9]{1,2}[:.][0-9]{2}\\s+", "", value, perl = TRUE)
    source_awarded <- grepl("\\[awarded\\]$",body,ignore.case=TRUE)
    source_abandoned <- grepl("\\[abandoned\\]$",body,ignore.case=TRUE)
    source_postponed <- grepl("\\[postponed\\]$",body,ignore.case=TRUE)
    source_cancelled <- grepl("\\[cancelled\\]$",body,ignore.case=TRUE)
    body <- trimws(sub("\\s*\\[(awarded|abandoned|postponed|cancelled)\\]$","",body,ignore.case=TRUE))
    home <- away <- score <- ""; status <- "completed"
    versus <- regmatches(body, regexec("^(.+?)\\s+v\\s+(.+)$", body, perl = TRUE))[[1L]]
    if (length(versus)) {
      home <- versus[[2L]]
      right <- regmatches(versus[[3L]], regexec("^(.+?)\\s+([0-9]+[-:][0-9]+(?:\\s.*)?)$", versus[[3L]], perl = TRUE))[[1L]]
      if (length(right)) { away <- right[[2L]]; score <- trimws(right[[3L]]) } else {
        away <- versus[[3L]]; status <- "scheduled"
        if (grepl("[0-9]+[-:]|a\\.e\\.t|pen\\.", away)) {
          diagnostic(index, "error", "unsupported_result_line", stage); next
        }
      }
    } else {
      pair_pattern <- "[0-9]+[-:][0-9]+"
      extra_pattern <- paste0("(?:",pair_pattern,"\\s+pen\\.\\s+)?",pair_pattern,
        "\\s+a\\.e\\.t\\.(?:\\s+\\(",pair_pattern,"(?:,\\s*",pair_pattern,")?\\))?")
      between <- regmatches(body, regexec(
        paste0("^(.+?)\\s+(",extra_pattern,"|",pair_pattern,"(?:\\s+\\(",pair_pattern,"\\))?)\\s+(.+)$"), body, perl = TRUE
      ))[[1L]]
      if (length(between)) { home <- between[[2L]]; score <- between[[3L]]; away <- between[[4L]] } else {
        scheduled <- regmatches(body,regexec("^(.+?)\\s+-\\s+(.+)$",body,perl=TRUE))[[1L]]
        if(length(scheduled)) {home <- scheduled[[2L]];away <- scheduled[[3L]];status <- "scheduled"} else {
          diagnostic(index, "error", "unsupported_source_line", stage); next
        }
      }
      if (grepl("^(a\\.e\\.t|pen\\.|\\(|\\[)", away)) {
        diagnostic(index, "error", "unsupported_result_line", stage); next
      }
    }
    if (!nzchar(event_date) || !nzchar(stage) || !nzchar(clean_team(home)) || !nzchar(clean_team(away))) {
      diagnostic(index, "error", "missing_date_stage_or_teams", stage); next
    }
    score <- gsub(":","-",score,fixed=TRUE)
    awarded <- source_awarded || grepl("\\[awarded\\]$", score, ignore.case = TRUE)
    if (awarded) status <- "awarded"
    if (source_abandoned) status <- "abandoned"
    if (source_postponed) status <- "postponed"
    if (source_cancelled) status <- "cancelled"
    score_result <- if (awarded) list(
      text = paste(score,"[awarded]"), semantics = "awarded", reason = "awarded_result_not_played_regulation"
    ) else if (status == "completed") phase18_openfootball_score(
      score, stage %in% c("REGULAR_SEASON", "GROUP_STAGE", "LEAGUE_STAGE",
                         "CHAMPIONSHIP_LEAGUE_STAGE", "RELEGATION_LEAGUE_STAGE", "EUROPE_LEAGUE_STAGE") ||
        grepl("(first|1st) leg|leg 1\\b", stage_header, ignore.case = TRUE)
    ) else list(text = "", semantics = "unknown", reason = if(status=="scheduled") "not_completed" else paste0(status,"_not_completed"))
    rows[[length(rows) + 1L]] <- data.frame(
      source_match_id = sprintf("line_%06d", index), event_date = event_date, kickoff_utc = "",
      stage = stage, status = status, home_name = clean_team(home), away_name = clean_team(away),
      score_text = score_result$text, score_semantics = score_result$semantics,
      evidence_updated_at_utc = "", stringsAsFactors = FALSE
    )
    diagnostic(index, if (nzchar(score_result$reason)) "excluded" else "parsed", score_result$reason, stage)
  }
  if (scorer_depth != 0L) diagnostic(length(lines), "error", "unclosed_scorer_annotation")
  result <- if (length(rows)) do.call(rbind, rows) else {
    as.data.frame(setNames(rep(list(character()), length(phase18_openfootball_exchange_schema())),
                           phase18_openfootball_exchange_schema()), stringsAsFactors = FALSE)
  }
  diag <- if (length(diagnostics)) do.call(rbind, diagnostics) else data.frame(
    line_number = integer(), source_match_id = character(), stage = character(), stage_header = character(),
    leg_ordinal = character(), parse_status = character(),
    reason = character(), source_line = character(), stringsAsFactors = FALSE
  )
  declared_line <- grep("^#\\s+Matches\\s+[0-9]+\\s*$", trimws(lines), value = TRUE)
  declared <- if (length(declared_line) == 1L) as.integer(sub("^#\\s+Matches\\s+", "", declared_line)) else NA_integer_
  summary <- list(total_lines = length(lines), declared_matches = declared, parsed_matches = nrow(result),
                  completed_matches = sum(result$status == "completed"),
                  # Aggregate fixtures without a played result, including explicit
                  # postponements/cancellations; row status retains the distinction.
                  scheduled_matches = sum(!result$status %in% c("completed","awarded")),
                  postponed_matches = sum(result$status == "postponed"), cancelled_matches = sum(result$status == "cancelled"),
                  awarded_matches = sum(result$status == "awarded"),
                  all_fixtures_have_results = all(result$status %in% c("completed", "awarded")),
                  errors = sum(diag$parse_status == "error"),
                  excluded_matches = sum(diag$parse_status == "excluded"),
                  declared_count_matches = is.na(declared) || declared == nrow(result))
  attr(result, "diagnostics") <- diag
  attr(result, "exclusions") <- diag[diag$parse_status != "parsed", , drop = FALSE]
  attr(result, "summary") <- summary
  if (strict && (summary$errors > 0L || !summary$declared_count_matches || !nrow(result))) {
    error <- structure(list(message = paste0("Native OpenFootball source is incomplete: ", summary$errors,
      " unparsed lines; declared=", declared, "; parsed=", nrow(result)), call = NULL,
      reason = "incomplete_openfootball_parse", diagnostics = diag, summary = summary),
      class = c("openfootball_parse_error", "error", "condition"))
    stop(error)
  }
  result
}

phase18_read_openfootball_source <- function(path, source_row, strict = TRUE) {
  if (grepl("\\.txt$", path, ignore.case = TRUE)) return(phase18_parse_openfootball_text(
    readLines(path, warn = FALSE, encoding = "UTF-8"), source_row$season_id[[1L]],
    source_row$competition_id[[1L]], strict = strict
  ))
  if (grepl("\\.csv$", path, ignore.case = TRUE)) {
    rows <- read.csv(path, colClasses = "character", check.names = FALSE, stringsAsFactors = FALSE,
                     na.strings = NULL)
    if (identical(names(rows), phase18_openfootball_exchange_schema())) return(rows)
  }
  stop("Unsupported OpenFootball source format: ", basename(path), call. = FALSE)
}
