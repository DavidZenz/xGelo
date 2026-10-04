# Edition-neutral static renderer for the Phase 17 payload contract.

phase17_html_escape <- function(value) {
  value <- as.character(value %||% "")
  value <- gsub("&", "&amp;", value, fixed = TRUE)
  value <- gsub("<", "&lt;", value, fixed = TRUE)
  value <- gsub(">", "&gt;", value, fixed = TRUE)
  value <- gsub('"', "&quot;", value, fixed = TRUE)
  value <- gsub("'", "&#39;", value, fixed = TRUE)
  value
}

phase17_json_script_escape <- function(value) {
  value <- as.character(value %||% "")
  value <- gsub("&", "\\u0026", value, fixed = TRUE)
  value <- gsub("<", "\\u003c", value, fixed = TRUE)
  value <- gsub(">", "\\u003e", value, fixed = TRUE)
  value <- gsub("</script", "<\\/script", value, fixed = TRUE)
  gsub("\\u2028", "\\u2028", value, fixed = TRUE)
}

phase17_display_value <- function(value) {
  if (is.null(value) || !length(value) || is.na(value[[1L]])) return("")
  phase17_html_escape(as.character(value[[1L]]))
}

phase17_public_scalar <- function(value) {
  if (is.null(value) || !length(value) || is.na(value[[1L]])) return("")
  as.character(value[[1L]])
}

phase17_public_status <- function(value) {
  value <- phase17_public_scalar(value)
  if (!nzchar(value)) return("")
  key <- tolower(value)
  labels <- c(
    upcoming = "Scheduled", scheduled = "Scheduled", live = "In progress",
    in_progress = "In progress", finished = "Final", played = "Final", final = "Final",
    available = "Available", unavailable = "Unavailable", unresolved = "Unresolved",
    suppressed = "Suppressed", postponed = "Postponed", cancelled = "Cancelled",
    none = ""
  )
  if (key %in% names(labels)) labels[[key]] else tools::toTitleCase(gsub("_", " ", key, fixed = TRUE))
}

phase17_public_percentage <- function(value) {
  number <- suppressWarnings(as.numeric(phase17_public_scalar(value)))
  if (!is.finite(number)) "" else sprintf("%.1f%%", 100 * number)
}

phase17_public_decimal <- function(value, digits = 2L) {
  number <- suppressWarnings(as.numeric(phase17_public_scalar(value)))
  if (!is.finite(number)) "" else formatC(number, format = "f", digits = as.integer(digits))
}

phase17_public_mapping <- function(mapping, key) {
  key <- phase17_public_scalar(key)
  if (!nzchar(key) || is.null(names(mapping)) || !key %in% names(mapping)) return("")
  unname(mapping[[key]])
}

phase17_public_context <- function(payload) {
  groups <- character()
  teams <- character()
  fixtures <- list()
  add_mapping <- function(mapping, keys, label) {
    label <- phase17_public_scalar(label)
    if (!nzchar(label)) return(mapping)
    keys <- unique(vapply(keys, phase17_public_scalar, character(1)))
    keys <- keys[nzchar(keys)]
    if (length(keys)) mapping[keys] <- label
    mapping
  }
  structure_rows <- payload$sections$structure$rows
  if (is.null(structure_rows)) structure_rows <- list()
  for (row in structure_rows) {
    label <- phase17_row_value(row, c("display_name", "league_or_group", "group"))
    groups <- add_mapping(groups, row[c("source_group_id", "group_id", "display_name", "league_or_group", "group")], label)
  }
  fixture_rows <- payload$sections$fixtures$rows
  result_rows <- payload$sections$results$rows
  if (is.null(fixture_rows)) fixture_rows <- list()
  if (is.null(result_rows)) result_rows <- list()
  match_rows <- c(fixture_rows, result_rows)
  for (row in match_rows) {
    fixture_id <- phase17_row_value(row, "fixture_id")
    if (nzchar(fixture_id) && is.null(fixtures[[fixture_id]])) fixtures[[fixture_id]] <- row
    home <- phase17_row_value(row, c("home_display_name", "home_team"))
    away <- phase17_row_value(row, c("away_display_name", "away_team"))
    teams <- add_mapping(teams, row[c("home_team_id", "home_uefa_source_team_id")], home)
    teams <- add_mapping(teams, row[c("away_team_id", "away_uefa_source_team_id")], away)
  }
  list(groups = groups, teams = teams, fixtures = fixtures)
}

phase17_public_group <- function(row, context) {
  for (field in c("display_name", "group", "league_or_group", "group_id", "source_group_id")) {
    value <- phase17_public_scalar(row[[field]])
    if (!nzchar(value)) next
    mapped <- phase17_public_mapping(context$groups, value)
    if (nzchar(mapped)) return(mapped)
    if (grepl("^(Group|League) ", value)) return(value)
    if (field %in% c("group", "group_id") && grepl("^[A-Za-z][A-Za-z0-9 -]*$", value)) {
      return(paste("Group", value))
    }
  }
  league <- phase17_public_scalar(row$league)
  if (nzchar(league) && grepl("^[A-Za-z][A-Za-z0-9 -]*$", league)) paste("League", league) else ""
}

phase17_public_team <- function(row, role = "team", context) {
  display_fields <- switch(role,
    home = c("home_display_name", "home_team"),
    away = c("away_display_name", "away_team"),
    c("team_display_name", "display_name", "team")
  )
  id_fields <- switch(role,
    home = c("home_team_id", "home_uefa_source_team_id"),
    away = c("away_team_id", "away_uefa_source_team_id"),
    c("team_id", "team")
  )
  for (field in display_fields) {
    value <- phase17_public_scalar(row[[field]])
    if (!nzchar(value)) next
    mapped <- phase17_public_mapping(context$teams, value)
    if (nzchar(mapped)) return(mapped)
    if (!grepl("^team_", value)) return(value)
  }
  for (field in id_fields) {
    value <- phase17_public_scalar(row[[field]])
    mapped <- phase17_public_mapping(context$teams, value)
    if (nzchar(mapped)) return(mapped)
  }
  ""
}

phase17_public_fixture <- function(row, context) {
  fixture_id <- phase17_row_value(row, "fixture_id")
  if (!nzchar(fixture_id)) return(list())
  fixture <- context$fixtures[[fixture_id]]
  if (is.null(fixture)) list() else fixture
}

phase17_public_row <- function(row, section_id, context) {
  if (!is.list(row)) return(list())
  fields <- list()
  add <- function(label, value) {
    value <- phase17_public_scalar(value)
    if (nzchar(value)) fields[[label]] <<- value
  }
  add_status <- function(label, value) add(label, phase17_public_status(value))
  fixture <- phase17_public_fixture(row, context)
  match_row <- if (length(fixture)) modifyList(fixture, row) else row
  group <- phase17_public_group(match_row, context)
  home <- phase17_public_team(match_row, "home", context)
  away <- phase17_public_team(match_row, "away", context)
  kickoff <- phase17_row_value(match_row, c("confirmed_kickoff_at_utc", "scheduled_at_utc", "kickoff_at_utc", "date"))
  matchday <- phase17_row_value(match_row, c("matchday", "match_day"))

  if (identical(section_id, "structure")) {
    league <- phase17_public_scalar(row$league)
    if (nzchar(league)) add("League", if (grepl("^League ", league)) league else paste("League", league))
    add("Group", phase17_row_value(row, c("display_name", "group")))
    add("Stage", row$stage)
    add("Promotion path", row$promotion_path)
    add("Relegation path", row$relegation_path)
  } else if (section_id %in% c("standings", "projected_outcomes")) {
    add("League/group", group)
    add("Team", phase17_public_team(row, "team", context))
    add("Rank", row$rank)
    standing_fields <- c(
      played = "Played", wins = "Won", draws = "Drawn", losses = "Lost",
      goals_for = "Goals for", goals_against = "Goals against",
      goal_difference = "Goal difference", points = "Points"
    )
    for (field in names(standing_fields)) add(standing_fields[[field]], row[[field]])
    add("Expected points", phase17_public_decimal(row$expected_points, 1L))
    add("Expected goal difference", phase17_public_decimal(row$expected_goal_difference, 1L))
    add("Stage", row$stage)
    add("Outcome", row$outcome)
    add("Probability", phase17_public_percentage(row$probability))
    add_status("Status", row$ranking_status %||% row$status)
    add("Reason", row$reason)
  } else if (identical(section_id, "fixtures")) {
    add("Matchday", matchday)
    add("League/group", group)
    add("Kickoff (UTC)", kickoff)
    add("Home", home)
    add("Away", away)
    add("Venue", row$venue)
    add_status("Status", row$source_status %||% row$fixture_status %||% row$status)
  } else if (identical(section_id, "results")) {
    add("Matchday", matchday)
    add("League/group", group)
    add("Date (UTC)", kickoff)
    add("Home", home)
    home_goals <- phase17_row_value(row, c("final_home_goals", "home_goals", "regulation_home_goals"))
    away_goals <- phase17_row_value(row, c("final_away_goals", "away_goals", "regulation_away_goals"))
    if (nzchar(home_goals) && nzchar(away_goals)) add("Score", paste(home_goals, away_goals, sep = "-") )
    add("Away", away)
    add_status("Status", row$match_status %||% row$source_status %||% row$status)
  } else if (identical(section_id, "form")) {
    add("Home", home)
    add("Away", away)
    add_status("Competition form", row$competition_form_status)
    add("Competition window", phase17_public_status(row$competition_form_window_type))
    add("Competition matches", row$competition_form_window_size)
    add_status("All-international form", row$all_international_form_status)
    add("All-international window", phase17_public_status(row$all_international_form_window_type))
    add("All-international matches", row$all_international_form_window_size)
    add_status("National-team xG", row$national_team_xg_status)
  } else if (identical(section_id, "match_forecasts")) {
    add("Kickoff (UTC)", kickoff)
    add("Home", home)
    add("Away", away)
    add_status("Forecast", row$forecast_status %||% row$status)
    add("Home win", phase17_public_percentage(row$p_home %||% row$home_probability))
    add("Draw", phase17_public_percentage(row$p_draw %||% row$draw_probability))
    add("Away win", phase17_public_percentage(row$p_away %||% row$away_probability))
    add("Home xG", phase17_public_decimal(row$expected_home_goals, 2L))
    add("Away xG", phase17_public_decimal(row$expected_away_goals, 2L))
    reason <- phase17_public_scalar(row$suppression_reason)
    if (nzchar(reason) && !identical(tolower(reason), "none")) add("Reason", phase17_public_status(reason))
  }
  fields
}

phase17_row_text <- function(row) {
  if (!is.list(row) || !length(row)) return('<span class="row-empty">No public row data</span>')
  paste(vapply(names(row), function(field) paste0(
    "<span class=\"row-field\"><b>", phase17_html_escape(field),
    ":</b> ", phase17_display_value(row[[field]]), "</span>"), character(1)), collapse = " ")
}

phase17_row_attribute <- function(row, fields, separator = "") {
  values <- vapply(fields, function(field) {
    value <- row[[field]]
    if (is.null(value) || !length(value) || is.na(value[[1L]])) "" else as.character(value[[1L]])
  }, character(1))
  values <- unique(values[nzchar(values)])
  value <- if (length(values)) paste(values, collapse = separator) else ""
  phase17_html_escape(value)
}

phase17_section_status <- function(section) {
  status <- as.character(section$status[[1L]])
  label <- phase17_status_labels()[[status]] %||% tools::toTitleCase(gsub("_", " ", status))
  reason <- as.character(section$reason %||% "")
  if (identical(status, "available")) {
    return(paste0('<p class="section-count" data-status="available"><strong>Available</strong> - ',
                  length(section$rows), ' accepted row(s)</p>'))
  }
  paste0('<div class="section-status" data-status="', phase17_html_escape(status),
         '" role="status"><strong>', phase17_html_escape(label), '</strong><p>',
         phase17_html_escape(reason), '</p><details><summary>Why unavailable</summary><p>',
         phase17_html_escape(reason), '</p></details></div>')
}

phase17_public_dimensions <- function(row, section_id, context) {
  fixture <- phase17_public_fixture(row, context)
  match_row <- if (length(fixture)) modifyList(fixture, row) else row
  teams <- if (section_id %in% c("fixtures", "results", "form", "match_forecasts")) {
    c(phase17_public_team(match_row, "home", context), phase17_public_team(match_row, "away", context))
  } else if (section_id %in% c("standings", "projected_outcomes")) phase17_public_team(row, "team", context) else character()
  status <- if (identical(section_id, "fixtures")) {
    phase17_public_status(match_row$source_status %||% match_row$fixture_status %||% match_row$status)
  } else if (identical(section_id, "results")) {
    phase17_public_status(row$match_status %||% row$source_status %||% row$status)
  } else if (section_id %in% c("form", "match_forecasts")) {
    phase17_public_status(fixture$source_status %||% fixture$fixture_status %||% fixture$status)
  } else ""
  list(
    group = phase17_public_group(match_row, context),
    teams = unique(teams[nzchar(teams)]),
    matchday = phase17_row_value(match_row, c("matchday", "match_day")),
    status = status
  )
}

phase17_render_section <- function(section, context) {
  if (!is.list(section)) stop("Phase 17 renderer section must be a list", call. = FALSE)
  rows <- if (is.null(section$rows)) list() else section$rows
  row_html <- if (length(rows)) paste0(
    '<div class="table-scroll"><table><thead><tr><th scope="col">Accepted data</th></tr></thead><tbody>',
    paste(vapply(rows, function(row) {
      dimensions <- phase17_public_dimensions(row, section$id, context)
      paste0('<tr data-filter-group="', phase17_html_escape(dimensions$group),
             '" data-filter-team="', phase17_html_escape(paste(dimensions$teams, collapse = "|")),
             '" data-filter-matchday="', phase17_html_escape(dimensions$matchday),
             '" data-filter-status="', phase17_html_escape(dimensions$status), '"><td>',
             phase17_row_text(phase17_public_row(row, section$id, context)), '</td></tr>')
    }, character(1)), collapse = ""),
    '</tbody></table></div>') else ""
  paste0('<section id="', phase17_html_escape(section$id), '" data-section="',
         phase17_html_escape(section$id), '" class="dashboard-section"><h2>',
         phase17_html_escape(section$label), '</h2>', phase17_section_status(section),
         '<div class="section-rows" data-section-rows="', phase17_html_escape(section$id), '">',
         row_html, '</div></section>')
}

phase17_filter_values <- function(payload, dimension, context = phase17_public_context(payload)) {
  values <- unlist(lapply(payload$sections, function(section) lapply(section$rows, function(row) {
    dimensions <- phase17_public_dimensions(row, section$id, context)
    dimensions[[dimension]]
  })), use.names = FALSE)
  values <- unique(as.character(values[nzchar(values)]))
  if (identical(dimension, "matchday") && length(values) && all(grepl("^[0-9]+$", values))) {
    return(as.character(sort(as.integer(values))))
  }
  sort(values, method = "radix")
}

phase17_select <- function(id, label, values, default_label) {
  options <- paste0('<option value="">', phase17_html_escape(default_label), '</option>',
                   paste(vapply(values, function(value) paste0('<option value="', phase17_html_escape(value), '">',
                                                               phase17_html_escape(value), '</option>'), character(1)), collapse = ""))
  paste0('<label for="', id, '">', phase17_html_escape(label), '<select id="', id,
         '" name="', id, '">', options, '</select></label>')
}

phase17_render_filter_toolbar <- function(payload) {
  context <- phase17_public_context(payload)
  groups <- phase17_filter_values(payload, "group", context)
  teams <- phase17_filter_values(payload, "teams", context)
  matchdays <- phase17_filter_values(payload, "matchday", context)
  statuses <- phase17_filter_values(payload, "status", context)
  paste0('<form id="dashboard-filters" class="filters" aria-label="Dashboard filters">',
    '<label for="filter-section">Section<select id="filter-section" name="section"><option value="">All sections</option>',
    paste(vapply(payload$sections, function(section) paste0('<option value="', phase17_html_escape(section$id), '">',
                                                             phase17_html_escape(section$label), '</option>'), character(1)), collapse = ""),
    '</select></label>', phase17_select("filter-league-group", "League or group", groups, "All"),
    phase17_select("filter-team", "Team", teams, "All teams"),
    phase17_select("filter-matchday", "Matchday", matchdays, "All matchdays"),
    phase17_select("filter-status", "Fixture status", statuses, "All statuses"),
    '<button type="button" id="clear-filters">Clear filters</button>',
    '<p id="filter-result-count" role="status" aria-live="polite">Showing accepted dashboard data.</p></form>')
}

# The Nations League route has a different information shape from the EURO
# route.  It is a scheduled, group-based competition, so rendering every
# accepted row as a generic provenance table makes the page look populated
# while hiding the fact that aggregate standings are not yet resolved.  These
# helpers keep the public projection boundary above the UI while giving the NL
# page a WC-style, user-facing presentation.

phase17_nl_rows <- function(payload, section_id) {
  section <- payload$sections[[section_id]]
  rows <- if (is.null(section) || is.null(section$rows)) list() else section$rows
  if (is.data.frame(rows)) {
    if (!nrow(rows)) return(list())
    return(unname(lapply(seq_len(nrow(rows)), function(i) as.list(rows[i, , drop = FALSE]))))
  }
  if (is.list(rows)) rows else list()
}

phase17_nl_extra_rows <- function(payload, field) {
  rows <- payload[[field]]
  if (is.null(rows)) return(list())
  if (is.data.frame(rows)) {
    if (!nrow(rows)) return(list())
    return(unname(lapply(seq_len(nrow(rows)), function(i) as.list(rows[i, , drop = FALSE]))))
  }
  if (is.list(rows)) rows else list()
}

phase17_nl_value <- function(row, fields, default = "") {
  value <- phase17_row_value(row, fields, default = default)
  if (length(value) && !is.na(value[[1L]])) as.character(value[[1L]]) else default
}

phase17_nl_date_label <- function(value) {
  value <- phase17_public_scalar(value)
  if (!nzchar(value)) return("")
  day <- substr(value, 1L, 10L)
  parsed <- suppressWarnings(as.Date(day))
  if (!is.na(parsed)) format(parsed, "%d %b %Y") else value
}

phase17_nl_group_key <- function(row, context) {
  group <- phase17_public_group(row, context)
  if (nzchar(group)) group else "Unassigned group"
}

phase17_nl_league_label <- function(value, group = "") {
  value <- phase17_public_scalar(value)
  if (nzchar(value)) {
    if (grepl("^League ", value)) return(value)
    if (grepl("^[A-D]$", value)) return(paste("League", value))
    return(value)
  }
  match <- regmatches(group, regexec("^Group ([A-D])", group))[[1L]]
  if (length(match) > 1L) paste("League", match[[2L]]) else ""
}

phase17_nl_group_definitions <- function(payload, context) {
  structure_rows <- phase17_nl_rows(payload, "structure")
  fixture_rows <- phase17_nl_rows(payload, "fixtures")
  result_rows <- phase17_nl_rows(payload, "results")
  definitions <- list()
  add <- function(row, fallback = "") {
    group <- phase17_nl_group_key(row, context)
    if (!nzchar(group) || identical(group, "Unassigned group")) group <- fallback
    if (!nzchar(group)) return(invisible(NULL))
    league <- phase17_nl_league_label(row$league, group)
    key <- group
    if (is.null(definitions[[key]])) {
      definitions[[key]] <<- list(name = group, league = league, key = key)
    } else if (!nzchar(definitions[[key]]$league) && nzchar(league)) {
      definitions[[key]]$league <<- league
    }
    invisible(NULL)
  }
  for (row in structure_rows) add(row)
  for (row in c(fixture_rows, result_rows)) add(row)
  if (!length(definitions)) return(list())
  order_key <- function(definition) {
    league <- sub("^League ", "", definition$league)
    group <- sub("^Group ", "", definition$name)
    sprintf("%s-%s", if (nzchar(league)) league else "Z", group)
  }
  definitions[order(vapply(definitions, order_key, character(1)), method = "radix")]
}

phase17_nl_team_name <- function(row, role = "team", context) {
  value <- phase17_public_team(row, role, context)
  if (nzchar(value)) value else "Team"
}

phase17_nl_group_team_rows <- function(payload, group, context) {
  standings <- phase17_nl_rows(payload, "standings")
  projected <- phase17_nl_rows(payload, "projected_outcomes")
  fixtures <- phase17_nl_rows(payload, "fixtures")
  results <- phase17_nl_rows(payload, "results")
  rows <- list()
  names_seen <- character()
  add_team <- function(name, row = list()) {
    name <- phase17_public_scalar(name)
    if (!nzchar(name) || name %in% names_seen) return(invisible(NULL))
    names_seen <<- c(names_seen, name)
    rows[[length(rows) + 1L]] <<- list(name = name, row = row)
    invisible(NULL)
  }
  for (row in c(standings, projected)) {
    if (identical(phase17_nl_group_key(row, context), group)) {
      add_team(phase17_nl_team_name(row, "team", context), row)
    }
  }
  for (row in c(fixtures, results)) {
    if (!identical(phase17_nl_group_key(row, context), group)) next
    add_team(phase17_nl_team_name(row, "home", context))
    add_team(phase17_nl_team_name(row, "away", context))
  }
  if (length(rows)) rows[order(vapply(rows, function(item) item$name, character(1)), method = "radix")] else list()
}

phase17_nl_rank_matrix_status <- function(rows, context, tolerance = 1e-6) {
  if (!length(rows)) return("unavailable")
  groups <- vapply(rows, phase17_nl_group_key, character(1), context = context)
  teams <- vapply(rows, phase17_nl_team_name, character(1), role = "team", context = context)
  ranks <- suppressWarnings(as.integer(vapply(rows, phase17_nl_value, character(1), fields = "rank")))
  probabilities <- suppressWarnings(as.numeric(vapply(rows, phase17_nl_value, character(1), fields = "probability")))
  statuses <- tolower(vapply(rows, phase17_nl_value, character(1), fields = c("ranking_status", "status")))
  if (any(!nzchar(groups) | !nzchar(teams) | !is.finite(ranks) | ranks < 1L |
          !is.finite(probabilities) | probabilities < -tolerance | probabilities > 1 + tolerance)) {
    return("unavailable")
  }
  if (any(statuses %in% c("unresolved", "unavailable", "blocked", "suppressed"))) return("unavailable")
  for (group in unique(groups)) {
    indexes <- which(groups == group)
    group_teams <- unique(teams[indexes])
    group_ranks <- sort(unique(ranks[indexes]))
    group_size <- length(group_teams)
    if (!length(group_ranks) || !identical(group_ranks, seq_len(group_size))) return("unavailable")
    cells <- paste(teams[indexes], ranks[indexes], sep = "::")
    if (anyDuplicated(cells) || length(cells) != group_size * group_size) return("unavailable")
    team_sums <- tapply(probabilities[indexes], teams[indexes], sum)
    rank_sums <- tapply(probabilities[indexes], ranks[indexes], sum)
    if (any(abs(as.numeric(team_sums) - 1) > tolerance) || any(abs(as.numeric(rank_sums) - 1) > tolerance)) {
      return("unavailable")
    }
  }
  if (all(statuses %in% c("resolved", "complete", "completed"))) "resolved" else "projected"
}

phase17_nl_has_resolved_rankings <- function(rows, context = NULL) {
  if (!length(rows)) return(FALSE)
  if (is.null(context)) {
    return(any(vapply(rows, function(row) {
      status <- tolower(phase17_nl_value(row, c("ranking_status", "status")))
      nzchar(phase17_nl_value(row, "rank")) && nzchar(phase17_nl_value(row, "probability")) &&
        !status %in% c("unresolved", "unavailable", "blocked", "suppressed")
    }, logical(1))))
  }
  phase17_nl_rank_matrix_status(rows, context) %in% c("projected", "resolved")
}

phase17_nl_rank_cell <- function(row, field) {
  value <- phase17_nl_value(row, field)
  if (!nzchar(value)) "—" else phase17_html_escape(value)
}

phase17_nl_expected_cell <- function(row, field, digits = 1L) {
  value <- phase17_public_decimal(phase17_nl_value(row, field), digits)
  if (!nzchar(value)) "—" else phase17_html_escape(value)
}

phase17_nl_percentage <- function(value) {
  probability <- suppressWarnings(as.numeric(phase17_public_scalar(value)))
  if (!is.finite(probability) || probability < 0 || probability > 1) return("—")
  # A Monte Carlo mean at exactly 0.1% may sit one floating-point unit below
  # the threshold. Keep that rounding noise from changing its label.
  if (probability > 0 && probability < 0.001 - 1e-15) "<0.1%" else sprintf("%.1f%%", 100 * probability)
}

phase17_nl_path_for_team <- function(payload, team_id, name, context) {
  rows <- phase17_nl_extra_rows(payload, "progression_probabilities")
  selected <- rows[vapply(rows, function(row) {
    if (nzchar(team_id)) identical(phase17_nl_value(row, "team_id"), team_id) else
      identical(phase17_nl_team_name(row, "team", context), name)
  }, logical(1))]
  if (length(selected) != 1L) return(list())
  row <- selected[[1L]]
  if (tolower(phase17_nl_value(row, "status")) %in% c("blocked", "unresolved", "unavailable", "suppressed")) return(list())
  row
}

phase17_nl_group_explanation <- function(league) {
  switch(sub("^League ", "", league),
    A = "Top two reach the quarter-finals. The two best third-placed teams across League A stay; the remaining third-placed and two best fourth-placed teams enter A/B play-offs. The other two are directly relegated.",
    B = "Winners are directly promoted; runners-up enter A/B promotion play-offs. Third place stays; fourth place enters B/C relegation play-offs.",
    C = "Winners are directly promoted; runners-up enter B/C promotion play-offs. Third and fourth place stay in League C.",
    D = "All League D teams move to League C for the next edition; no C/D play-offs are played.", "")
}

phase17_nl_group_fixtures <- function(payload, group, context) {
  fixtures <- phase17_nl_rows(payload, "fixtures")
  results <- phase17_nl_rows(payload, "results")
  rows <- c(fixtures, results)
  rows <- rows[vapply(rows, function(row) identical(phase17_nl_group_key(row, context), group), logical(1))]
  seen <- character()
  merged <- list()
  for (row in rows) {
    id <- phase17_nl_value(row, "fixture_id")
    if (!nzchar(id) || id %in% seen) next
    seen <- c(seen, id)
    result <- results[vapply(results, function(candidate) identical(phase17_nl_value(candidate, "fixture_id"), id), logical(1))]
    if (length(result) == 1L) row <- modifyList(row, result[[1L]])
    merged[[length(merged) + 1L]] <- row
  }
  if (!length(merged)) return('<p class="nl-table-note">Group fixtures are unavailable.</p>')
  kickoff <- function(row) phase17_nl_value(row, c("confirmed_kickoff_at_utc", "scheduled_at_utc", "kickoff_at_utc", "date"))
  merged <- merged[order(vapply(merged, kickoff, character(1)), vapply(merged, phase17_nl_value, character(1), fields = "fixture_id"), method = "radix")]
  day_key <- vapply(merged, function(row) {
    md <- phase17_nl_value(row, c("matchday", "match_day"))
    if (nzchar(md)) paste("Matchday", md) else phase17_nl_date_label(kickoff(row))
  }, character(1))
  blocks <- vapply(unique(day_key), function(day) {
    selected <- merged[day_key == day]
    items <- vapply(selected, function(row) {
      home <- phase17_nl_team_name(row, "home", context)
      away <- phase17_nl_team_name(row, "away", context)
      terminal <- phase17_nl_completed_result(row)
      score <- if (!is.null(terminal)) paste(terminal$home_goals, terminal$away_goals, sep = "–") else "v"
      status <- if (!is.null(terminal)) "Final" else phase17_public_status(phase17_nl_value(row, c("match_status", "source_status", "status")))
      date <- kickoff(row)
      date_label <- phase17_nl_date_label(date)
      if (nchar(date) >= 16L) date_label <- paste(date_label, substr(date, 12L, 16L), "UTC")
      flag <- function(name) {
        value <- phase17_nl_team_flag(payload, name, context)
        if (nzchar(value)) paste0('<span class="team-flag" aria-hidden="true">', value, '</span>') else ""
      }
      paste0('<div class="nl-group-fixture"><div class="nl-compact-teams"><span>', flag(home), phase17_html_escape(home),
             '</span><strong class="nl-compact-score', if (!is.null(terminal)) ' completed' else '', '">', phase17_html_escape(score),
             '</strong><span>', flag(away), phase17_html_escape(away), '</span></div><small>',
             phase17_html_escape(paste(date_label, status, sep = " · ")), '</small></div>')
    }, character(1))
    paste0('<div class="nl-fixture-day"><h4>', phase17_html_escape(day), '</h4><div class="nl-compact-fixtures">', paste(items, collapse = ""), '</div></div>')
  }, character(1))
  paste0('<div class="nl-group-fixtures"><h3>Fixtures</h3>', paste(blocks, collapse = ""), '</div>')
}

phase17_nl_probability_cell <- function(value, class_name = "") {
  probability <- suppressWarnings(as.numeric(value))
  class_suffix <- if (nzchar(class_name)) paste0(" ", class_name) else ""
  if (!length(probability) || !is.finite(probability[[1L]]) || probability[[1L]] < 0 || probability[[1L]] > 1) {
    return(paste0('<td class="heat-cell', class_suffix, ' empty"><span class="heat-val">—</span></td>'))
  }
  probability <- max(0, min(1, probability[[1L]]))
  if (probability == 0) {
    return(paste0('<td class="heat-cell', class_suffix, ' empty"><span class="heat-val">0.0%</span></td>'))
  }
  heat <- max(0.10, min(0.92, 0.12 + probability * 0.78))
  strong <- if (probability >= 0.55) " strong" else ""
  paste0('<td class="heat-cell', class_suffix, strong, '" style="--heat:', formatC(heat, format = "f", digits = 3L),
         ';--prob:', formatC(probability, format = "f", digits = 3L), '"><span class="heat-val">',
         phase17_html_escape(phase17_nl_percentage(probability)), '</span></td>')
}

phase17_nl_status_cell <- function(status) {
  # Match the World Cup table: projected rows have an empty status cell and
  # marks are reserved for an explicit qualification/elimination outcome.
  status <- tolower(trimws(phase17_public_scalar(status)))
  if (status %in% c("qualified", "qualifies", "direct", "confirmed")) {
    return('<span class="status-mark qualified" role="img" aria-label="Qualified">✓</span>')
  }
  if (status %in% c("eliminated", "elimination", "not_qualified", "not-qualified", "out")) {
    return('<span class="status-mark eliminated" role="img" aria-label="Eliminated">×</span>')
  }
  ""
}

phase17_nl_qualification_status <- function(payload, row, context) {
  explicit <- phase17_nl_value(row, c("qualification_status", "advancement_status", "qualification_state"))
  if (nzchar(explicit)) return(explicit)
  progression <- phase17_nl_extra_rows(payload, "progression_probabilities")
  if (!length(progression)) return("")
  team_id <- phase17_nl_value(row, "team_id")
  league <- toupper(phase17_nl_value(row, "league"))
  matches <- progression[vapply(progression, function(candidate) {
    candidate_team_id <- phase17_nl_value(candidate, "team_id")
    candidate_league <- toupper(phase17_nl_value(candidate, "league"))
    (nzchar(team_id) && identical(candidate_team_id, team_id)) ||
      (!nzchar(team_id) && identical(candidate_league, league) &&
       identical(phase17_nl_team_name(candidate, "team", context), phase17_nl_team_name(row, "team", context)))
  }, logical(1))]
  if (!length(matches)) return("")
  path_status <- tolower(phase17_nl_value(matches[[1L]], "status"))
  if (path_status %in% c("unresolved", "suppressed", "unavailable", "blocked")) return("")
  # League A has a single WC-like advancement target in the current format:
  # the quarter-finals.  Do not turn zero promotion/relegation probabilities
  # in lower leagues into generic elimination marks.
  field <- if (identical(league, "A")) "p_quarter_final" else ""
  if (!nzchar(field)) return("")
  probability <- suppressWarnings(as.numeric(phase17_nl_value(matches[[1L]], field)))
  if (!length(probability) || !is.finite(probability)) return("")
  if (probability >= 0.999) "qualified" else if (probability <= 0.001) "eliminated" else ""
}

phase17_nl_probability_bar <- function(value, class_name = "") {
  probability <- suppressWarnings(as.numeric(phase17_public_scalar(value)))
  class_suffix <- if (nzchar(class_name)) paste0(" ", class_name) else ""
  if (!length(probability) || !is.finite(probability[[1L]]) || probability[[1L]] < 0 || probability[[1L]] > 1) {
    return('<span class="probability-unavailable">—</span>')
  }
  probability <- max(0, min(1, probability[[1L]]))
  paste0('<div class="probability-bar-wrap', class_suffix, '"><span class="probability-label">',
         phase17_html_escape(phase17_nl_percentage(probability)),
         '</span><div class="probbar" role="img" aria-label="',
         phase17_html_escape(phase17_nl_percentage(probability)), ' probability"><span style="width:',
         phase17_nl_css_percentage(probability), '"></span></div></div>')
}

phase17_nl_value_heat_cell <- function(value, minimum, maximum, display_value, class_name = "") {
  number <- suppressWarnings(as.numeric(value))
  minimum <- suppressWarnings(as.numeric(minimum))
  maximum <- suppressWarnings(as.numeric(maximum))
  class_suffix <- if (nzchar(class_name)) paste0(" ", class_name) else ""
  if (!length(number) || !is.finite(number[[1L]]) || !is.finite(minimum) || !is.finite(maximum)) {
    return(paste0('<td class="heat-cell', class_suffix, ' empty"><span class="heat-val">',
                  phase17_html_escape(display_value), '</span></td>'))
  }
  number <- number[[1L]]
  span <- maximum - minimum
  scaled <- if (span > 0) (number - minimum) / span else if (maximum > 0) 1 else 0
  scaled <- max(0, min(1, scaled))
  heat <- if (scaled <= 0) 0 else max(0.10, min(0.92, 0.12 + scaled * 0.78))
  strong <- if (scaled >= 0.62) " strong" else ""
  empty <- if (heat <= 0) " empty" else ""
  paste0('<td class="heat-cell', class_suffix, strong, empty, '" style="--heat:', formatC(heat, format = "f", digits = 3L),
         ';--prob:', formatC(scaled, format = "f", digits = 3L), '"><span class="heat-val">',
         phase17_html_escape(display_value), '</span></td>')
}

phase17_nl_css_percentage <- function(value) {
  number <- suppressWarnings(as.numeric(value))
  if (!length(number) || !is.finite(number[[1L]])) "0%" else paste0(formatC(max(0, min(100, 100 * number[[1L]])), format = "f", digits = 1L), "%")
}

phase17_nl_fifa_to_iso2 <- c(
  ALB = "AL", AND = "AD", ARM = "AM", AUT = "AT", AZE = "AZ", BEL = "BE", BIH = "BA",
  BLR = "BY", BUL = "BG", CRO = "HR", CYP = "CY", CZE = "CZ", DEN = "DK", ENG = "GB",
  DEU = "DE", ESP = "ES", EST = "EE", FIN = "FI", FRA = "FR", FRO = "FO", GEO = "GE", GIB = "GI",
  GRE = "GR", HUN = "HU", ISL = "IS", ISR = "IL", IRL = "IE", ITA = "IT", KAZ = "KZ",
  KOS = "XK", LIE = "LI", LTU = "LT", LUX = "LU", LVA = "LV", MDA = "MD", MKD = "MK",
  MLT = "MT", MNE = "ME", NED = "NL", NIR = "GB", NOR = "NO", POL = "PL", POR = "PT",
  ROU = "RO", SCO = "GB", SMR = "SM", SRB = "RS", SUI = "CH", SVK = "SK", SVN = "SI",
  SWE = "SE", TUR = "TR", UKR = "UA", WAL = "GB"
)

phase17_nl_team_code <- function(row, role = "team") {
  fields <- switch(role,
    home = c("home_fifa_code", "home_team_id", "home_team"),
    away = c("away_fifa_code", "away_team_id", "away_team"),
    c("fifa_code", "team_fifa_code", "team_id", "team")
  )
  for (field in fields) {
    value <- phase17_nl_value(row, field)
    if (!nzchar(value)) next
    code <- toupper(trimws(value))
    code <- sub("^TEAM_", "", code)
    aliases <- c(
      GIBRALTAR = "GIB", REPUBLIC_OF_IRELAND = "IRL", SCOTLAND = "SCO",
      WALES = "WAL", NORTHERN_IRELAND = "NIR", KVX = "KOS", GRE = "GRE"
    )
    if (code %in% names(aliases)) code <- aliases[[code]]
    if (code %in% names(phase17_nl_fifa_to_iso2)) return(code)
  }
  ""
}

phase17_nl_flag_emoji <- function(code) {
  code <- toupper(phase17_public_scalar(code))
  iso <- if (code %in% names(phase17_nl_fifa_to_iso2)) unname(phase17_nl_fifa_to_iso2[[code]]) else ""
  if (!length(iso) || !grepl("^[A-Z]{2}$", iso)) return("")
  intToUtf8(127397L + utf8ToInt(iso))
}

phase17_nl_team_flag <- function(payload, name, context) {
  candidates <- c(phase17_nl_rows(payload, "standings"), phase17_nl_rows(payload, "projected_outcomes"),
                  phase17_nl_rows(payload, "fixtures"), phase17_nl_rows(payload, "results"))
  for (row in candidates) {
    for (role in c("team", "home", "away")) {
      if (identical(phase17_nl_team_name(row, role, context), name)) {
        flag <- phase17_nl_flag_emoji(phase17_nl_team_code(row, role))
        if (nzchar(flag)) return(flag)
      }
    }
  }
  ""
}

phase17_nl_number <- function(row, fields, default = NA_real_) {
  value <- phase17_nl_value(row, fields)
  number <- suppressWarnings(as.numeric(value))
  if (!length(number) || !is.finite(number[[1L]])) default else number[[1L]]
}

phase17_nl_completed_result <- function(row) {
  counts <- tolower(phase17_nl_value(row, "counts_for_standings"))
  if (counts %in% c("false", "0", "no", "n")) return(NULL)
  home_goals <- phase17_nl_number(row, c("final_home_goals", "home_goals", "regulation_home_goals"))
  away_goals <- phase17_nl_number(row, c("final_away_goals", "away_goals", "regulation_away_goals"))
  if (!is.finite(home_goals) || !is.finite(away_goals)) return(NULL)
  # A final score is sufficient when the source omits a terminal status.
  list(home_goals = home_goals, away_goals = away_goals)
}

phase17_nl_status_copy <- function(payload) {
  standings <- phase17_nl_rows(payload, "standings")
  projected <- phase17_nl_rows(payload, "projected_outcomes")
  context <- phase17_public_context(payload)
  rank_status <- phase17_nl_rank_matrix_status(if (length(projected)) projected else standings, context)
  if (rank_status == "resolved") "Forecast standings are resolved from accepted results." else
    if (rank_status == "projected") "Forecast standings are available." else
    if (length(c(standings, projected))) "Expected points and goal difference are forecast inputs. Rank probabilities are pending Article 15 access-list and discipline inputs." else
      "Forecast unavailable — aggregate standings are unresolved in the accepted outcome bundle."
}

phase17_nl_current_rows <- function(payload, group, context, teams) {
  standings <- phase17_nl_extra_rows(payload, "current_standings")
  if (!length(standings)) standings <- phase17_nl_rows(payload, "standings")
  result_rows <- phase17_nl_rows(payload, "results")
  current_fields <- c("points", "played", "wins", "draws", "losses", "goals_for", "goals_against", "goal_difference")
  matching_standings <- standings[vapply(standings, function(row) {
    identical(phase17_nl_group_key(row, context), group) &&
      phase17_nl_team_name(row, "team", context) %in% vapply(teams, function(item) item$name, character(1))
  }, logical(1))]
  has_snapshot <- length(matching_standings) && any(vapply(matching_standings, function(row) {
    any(vapply(current_fields, function(field) is.finite(phase17_nl_number(row, field)), logical(1)))
  }, logical(1)))

  stats <- setNames(lapply(teams, function(item) {
    list(name = item$name, points = 0, played = 0, wins = 0, draws = 0, losses = 0,
         goals_for = 0, goals_against = 0, goal_difference = 0, current_position = "",
         current_available = FALSE)
  }), vapply(teams, function(item) item$name, character(1)))

  if (isTRUE(has_snapshot)) {
    for (item in teams) {
      name <- item$name
      matching <- matching_standings[vapply(matching_standings, function(row) {
        identical(phase17_nl_team_name(row, "team", context), name)
      }, logical(1))]
      if (!length(matching)) next
      row <- matching[[1L]]
      for (field in current_fields) {
        value <- phase17_nl_number(row, field)
        if (is.finite(value)) stats[[name]][[field]] <- value
      }
      current_position <- phase17_nl_value(row, c("current_position", "official_rank"))
      if (nzchar(current_position)) stats[[name]]$current_position <- current_position
      stats[[name]]$current_available <- TRUE
    }
  } else {
    for (row in result_rows) {
      if (!identical(phase17_nl_group_key(row, context), group)) next
      result <- phase17_nl_completed_result(row)
      if (is.null(result)) next
      home <- phase17_nl_team_name(row, "home", context)
      away <- phase17_nl_team_name(row, "away", context)
      if (!home %in% names(stats) || !away %in% names(stats) || identical(home, "Team") || identical(away, "Team")) next
      stats[[home]]$played <- stats[[home]]$played + 1
      stats[[away]]$played <- stats[[away]]$played + 1
      stats[[home]]$goals_for <- stats[[home]]$goals_for + result$home_goals
      stats[[home]]$goals_against <- stats[[home]]$goals_against + result$away_goals
      stats[[away]]$goals_for <- stats[[away]]$goals_for + result$away_goals
      stats[[away]]$goals_against <- stats[[away]]$goals_against + result$home_goals
      if (result$home_goals > result$away_goals) {
        stats[[home]]$wins <- stats[[home]]$wins + 1
        stats[[away]]$losses <- stats[[away]]$losses + 1
        stats[[home]]$points <- stats[[home]]$points + 3
      } else if (result$home_goals < result$away_goals) {
        stats[[away]]$wins <- stats[[away]]$wins + 1
        stats[[home]]$losses <- stats[[home]]$losses + 1
        stats[[away]]$points <- stats[[away]]$points + 3
      } else {
        stats[[home]]$draws <- stats[[home]]$draws + 1
        stats[[away]]$draws <- stats[[away]]$draws + 1
        stats[[home]]$points <- stats[[home]]$points + 1
        stats[[away]]$points <- stats[[away]]$points + 1
      }
    }
    for (name in names(stats)) {
      stats[[name]]$goal_difference <- stats[[name]]$goals_for - stats[[name]]$goals_against
      stats[[name]]$current_available <- stats[[name]]$played > 0
    }
  }

  if (!length(stats)) return(list())
  positions <- vapply(stats, function(item) suppressWarnings(as.numeric(item$current_position)), numeric(1))
  if (all(is.finite(positions))) return(stats[order(positions, vapply(stats, function(item) item$name, character(1)), method = "radix")])
  stats[order(-vapply(stats, function(item) item$points, numeric(1)),
              -vapply(stats, function(item) item$goal_difference, numeric(1)),
              -vapply(stats, function(item) item$goals_for, numeric(1)),
              -vapply(stats, function(item) item$wins, numeric(1)),
              vapply(stats, function(item) item$name, character(1)), method = "radix")]
}

phase17_nl_current_cell <- function(value, signed = FALSE) {
  number <- suppressWarnings(as.numeric(value))
  if (!length(number) || !is.finite(number[[1L]])) return("—")
  if (signed && number[[1L]] > 0) paste0("+", formatC(number[[1L]], format = "f", digits = 0L)) else
    formatC(number[[1L]], format = "f", digits = 0L)
}

phase17_nl_group_table <- function(payload, definition, context) {
  teams <- phase17_nl_group_team_rows(payload, definition$name, context)
  standings <- phase17_nl_rows(payload, "standings")
  projected <- phase17_nl_rows(payload, "projected_outcomes")
  # Projected outcomes and standings are currently the same rank-probability
  # artifact in the accepted bundle. Prefer projected outcomes when present so
  # duplicate rows do not double-count probabilities.
  by_team <- if (length(projected)) projected else standings
  group_rows <- by_team[vapply(by_team, function(row) identical(phase17_nl_group_key(row, context), definition$name), logical(1))]
  matrix_status <- phase17_nl_rank_matrix_status(group_rows, context)
  group_rank_count <- max(1L, length(teams))
  row_for_team <- function(name) {
    matching <- by_team[vapply(by_team, function(row) {
      identical(phase17_nl_group_key(row, context), definition$name) &&
        identical(phase17_nl_team_name(row, "team", context), name)
    }, logical(1))]
    if (!length(matching)) return(list())
    probabilities <- setNames(rep(NA_real_, group_rank_count), as.character(seq_len(group_rank_count)))
    for (row in matching) {
      rank <- suppressWarnings(as.integer(phase17_nl_value(row, "rank")))
      probability <- suppressWarnings(as.numeric(phase17_nl_value(row, "probability")))
      if (length(rank) && is.finite(rank) && rank %in% seq_len(group_rank_count) && is.finite(probability)) {
        probabilities[[as.character(rank)]] <- probability
      }
    }
    weighted_value <- function(field) {
      values <- vapply(matching, function(row) phase17_nl_number(row, field), numeric(1))
      row_probs <- vapply(matching, function(row) {
        rank <- suppressWarnings(as.integer(phase17_nl_value(row, "rank")))
        if (!length(rank) || !is.finite(rank) || !rank %in% seq_len(group_rank_count)) NA_real_ else probabilities[[as.character(rank)]]
      }, numeric(1))
      valid <- is.finite(values) & is.finite(row_probs)
      if (any(valid) && sum(row_probs[valid]) > 0) return(sum(values[valid] * row_probs[valid]) / sum(row_probs[valid]))
      values <- values[is.finite(values)]
      if (length(values)) values[[1L]] else NA_real_
    }
    merged <- list(team_id = phase17_nl_value(matching[[1L]], "team_id"), league = sub("^League ", "", definition$league))
    expected_points <- weighted_value(c("expected_points", "xpts", "x_points"))
    expected_goal_difference <- weighted_value(c("expected_goal_difference", "xgd", "x_goal_difference"))
    if (is.finite(expected_points)) merged$expected_points <- expected_points
    if (is.finite(expected_goal_difference)) merged$expected_goal_difference <- expected_goal_difference
    merged$rank_probabilities <- probabilities
    available <- probabilities[is.finite(probabilities)]
    if (length(available)) {
      merged$rank <- which.max(probabilities)
      merged$probability <- max(available)
      status_values <- tolower(vapply(matching, phase17_nl_value, character(1), fields = c("ranking_status", "status")))
      merged$ranking_status <- if (any(status_values %in% c("unresolved", "unavailable", "blocked", "suppressed"))) {
        "unresolved"
      } else if (matrix_status == "resolved") {
        "resolved"
      } else {
        "projected"
      }
    } else {
      fallback_rank <- phase17_nl_value(matching[[1L]], "rank")
      if (nzchar(fallback_rank)) merged$rank <- fallback_rank
      merged$ranking_status <- phase17_nl_value(matching[[1L]], c("ranking_status", "status"))
    }
    merged
  }
  forecast_items <- if (length(teams)) lapply(teams, function(item) {
    row <- row_for_team(item$name)
    list(name = item$name, row = row,
         expected_points = phase17_nl_number(row, c("expected_points", "xpts", "x_points"), -Inf),
         expected_goal_difference = phase17_nl_number(row, c("expected_goal_difference", "xgd", "x_goal_difference"), -Inf))
  }) else list()
  if (length(forecast_items)) {
    forecast_items <- forecast_items[order(-vapply(forecast_items, function(item) item$expected_points, numeric(1)),
                                           -vapply(forecast_items, function(item) item$expected_goal_difference, numeric(1)),
                                           vapply(forecast_items, function(item) item$name, character(1)), method = "radix")]
  }
  forecast_rows <- if (length(forecast_items)) paste(vapply(forecast_items, function(item) {
    row <- item$row
    rank_probabilities <- row$rank_probabilities %||% setNames(rep(NA_real_, group_rank_count), as.character(seq_len(group_rank_count)))
    path <- phase17_nl_path_for_team(payload, phase17_nl_value(row, "team_id"), item$name, context)
    outcome_columns <- c(p_promotion = "promotion", p_playoff_eligibility = "playoff", p_relegation = "relegation")
    if (identical(definition$league, "League A")) outcome_columns <- c(p_quarter_final = "qualification", outcome_columns)
    outcome_cells <- paste(vapply(names(outcome_columns), function(field) phase17_nl_probability_cell(path[[field]], outcome_columns[[field]]), character(1)), collapse = "")
    qualification_status <- phase17_nl_qualification_status(payload, row, context)
    status_html <- phase17_nl_status_cell(qualification_status)
    flag <- phase17_nl_team_flag(payload, item$name, context)
    flag_html <- if (nzchar(flag)) paste0('<span class="team-flag" aria-hidden="true">', flag, '</span>') else ""
    paste0('<tr><th scope="row" class="team-cell"><div class="team-ident">', flag_html, '<span class="team-name">',
           phase17_html_escape(item$name), '</span></div></th><td class="status-cell">', status_html, '</td>',
           '<td class="xpts-cell">', phase17_nl_expected_cell(row, c("expected_points", "xpts", "x_points"), 1L), '</td>',
           '<td class="num xgd-cell">', phase17_nl_expected_cell(row, c("expected_goal_difference", "xgd", "x_goal_difference"), 1L), '</td>',
           paste(vapply(rank_probabilities, phase17_nl_probability_cell, character(1)), collapse = ""), outcome_cells, '</tr>')
  }, character(1)), collapse = "") else
    paste0('<tr><td colspan="', 7L + group_rank_count + as.integer(identical(definition$league, "League A")), '" class="nl-table-empty">Teams will appear when the accepted group roster is available.</td></tr>')
  current_rows <- phase17_nl_current_rows(payload, definition$name, context, teams)
  points_max <- if (length(current_rows)) max(vapply(current_rows, function(item) item$points, numeric(1)), 0) else 0
  goal_difference_values <- if (length(current_rows)) vapply(current_rows, function(item) item$goal_difference, numeric(1)) else 0
  goal_difference_min <- min(0, goal_difference_values)
  goal_difference_max <- max(0, goal_difference_values)
  current_rows_html <- if (length(current_rows)) paste(vapply(seq_along(current_rows), function(index) {
    item <- current_rows[[index]]
    points_display <- phase17_nl_current_cell(item$points)
    goal_difference_display <- phase17_nl_current_cell(item$goal_difference, signed = TRUE)
    flag <- phase17_nl_team_flag(payload, item$name, context)
    flag_html <- if (nzchar(flag)) paste0('<span class="team-flag" aria-hidden="true">', flag, '</span>') else ""
    paste0('<tr><td class="standing-cell current-position">', if (nzchar(item$current_position)) phase17_html_escape(item$current_position) else "—", '</td><th scope="row" class="team-cell"><div class="team-ident">', flag_html, '<span class="team-name">',
           phase17_html_escape(item$name), '</span></div></th>',
           '<td class="standing-cell">', phase17_nl_current_cell(item$played), '</td>',
           '<td class="standing-cell">', phase17_nl_current_cell(item$wins), '</td>',
           '<td class="standing-cell">', phase17_nl_current_cell(item$draws), '</td>',
           '<td class="standing-cell">', phase17_nl_current_cell(item$losses), '</td>',
           '<td class="standing-cell">', phase17_nl_current_cell(item$goals_for), '</td>',
           '<td class="standing-cell">', phase17_nl_current_cell(item$goals_against), '</td>',
           '<td class="standing-cell">', goal_difference_display, '</td>', phase17_nl_value_heat_cell(item$points, 0, points_max, points_display, "standing"), '</tr>')
  }, character(1)), collapse = "") else
    '<tr><td colspan="10" class="nl-table-empty">Current standings will appear when the accepted group roster is available.</td></tr>'
  has_current_results <- any(vapply(current_rows, function(item) isTRUE(item$current_available) && item$played > 0, logical(1)))
  current_note <- if (has_current_results) "Current standings reflect completed accepted results." else
    "No completed results yet. Current standings will appear after the first final matches."
  forecast_note <- if (matrix_status %in% c("projected", "resolved")) "" else
    paste0('<p class="nl-table-note">', phase17_html_escape(phase17_nl_status_copy(payload)), '</p>')
  paste0('<article class="group-box nl-group-card" data-group="', phase17_html_escape(definition$name), '">',
         '<div class="group-head"><div><h2>', phase17_html_escape(definition$name), '</h2><span class="group-league">', phase17_html_escape(definition$league), '</span></div></div>',
         '<p class="nl-table-note">', phase17_html_escape(phase17_nl_group_explanation(definition$league)), '</p>',
         '<h3>Projected standings</h3><p class="nl-table-note">Ordered by expected points, then expected goal difference. Promotion and relegation include play-offs; play-off participation overlaps these outcomes. — means unavailable.</p>', forecast_note,
         '<div class="nl-table-scroll" tabindex="0" role="region" aria-label="', phase17_html_escape(definition$name), ' projected standings">',
         '<table class="nl-group-table group-table"><thead><tr><th scope="col">Team</th><th class="status-head" scope="col" aria-label="Status"></th><th class="num xpts-head" scope="col">xPts<br>Avg</th><th class="num xgd-head" scope="col">xGD<br>Avg</th>',
         paste(vapply(seq_len(group_rank_count), function(rank) paste0('<th class="num" scope="col">', rank, '</th>'), character(1)), collapse = ""),
         if (identical(definition$league, "League A")) '<th scope="col">Quarter-finals</th>' else '',
         '<th scope="col">Promotion</th><th scope="col">Play-off</th><th scope="col">Relegation</th></tr></thead><tbody>',
         forecast_rows, '</tbody></table></div>',
         '<h3>Current standings</h3><p class="nl-table-note">', phase17_html_escape(current_note), '</p>',
         '<div class="nl-table-scroll" tabindex="0" role="region" aria-label="', phase17_html_escape(definition$name), ' current standings">',
         '<table class="nl-group-table group-table current-table"><thead><tr><th scope="col" aria-label="Position">#</th><th scope="col">Team</th>',
         paste(vapply(c(P = "Played", W = "Wins", D = "Draws", L = "Losses", GF = "Goals for", GA = "Goals against", GD = "Goal difference", Pts = "Points"), function(label) {
           key <- names(c(P = "Played", W = "Wins", D = "Draws", L = "Losses", GF = "Goals for", GA = "Goals against", GD = "Goal difference", Pts = "Points"))[match(label, c("Played", "Wins", "Draws", "Losses", "Goals for", "Goals against", "Goal difference", "Points"))]
           paste0('<th scope="col" title="', label, '">', key, '</th>')
         }, character(1)), collapse = ""), '</tr></thead><tbody>', current_rows_html, '</tbody></table></div>',
         phase17_nl_group_fixtures(payload, definition$name, context), '</article>')
}

phase17_nl_render_groups <- function(payload, context) {
  definitions <- phase17_nl_group_definitions(payload, context)
  cards <- if (length(definitions)) paste(vapply(definitions, function(definition) phase17_nl_group_table(payload, definition, context), character(1)), collapse = "") else
    '<div class="nl-empty"><strong>No groups available</strong><p>The accepted competition structure has not supplied a group roster yet.</p></div>'
  paste0('<section id="groups" class="section active nl-view" data-nl-view="groups"><div id="groupsGrid" class="grid-groups nl-group-grid">', cards, '</div></section>')
}

phase17_nl_forecast_for_fixture <- function(payload, fixture_id) {
  rows <- phase17_nl_rows(payload, "match_forecasts")
  if (!nzchar(fixture_id) || !length(rows)) return(list())
  matching <- rows[vapply(rows, function(row) identical(phase17_nl_value(row, "fixture_id"), fixture_id), logical(1))]
  if (length(matching)) matching[[1L]] else list()
}

phase17_nl_match_card <- function(payload, row, context, result = FALSE) {
  fixture <- phase17_public_fixture(row, context)
  match_row <- if (length(fixture)) modifyList(fixture, row) else row
  home <- phase17_nl_team_name(match_row, "home", context)
  away <- phase17_nl_team_name(match_row, "away", context)
  group <- phase17_nl_group_key(match_row, context)
  matchday <- phase17_nl_value(match_row, c("matchday", "match_day"))
  date_value <- phase17_nl_value(match_row, c("confirmed_kickoff_at_utc", "scheduled_at_utc", "kickoff_at_utc", "date"))
  date_label <- phase17_nl_date_label(date_value)
  status_value <- if (result) phase17_nl_value(match_row, c("match_status", "source_status", "status")) else phase17_nl_value(match_row, c("source_status", "fixture_status", "status"))
  status_label <- phase17_public_status(status_value)
  fixture_id <- phase17_nl_value(match_row, "fixture_id")
  forecast <- phase17_nl_forecast_for_fixture(payload, fixture_id)
  score_home <- phase17_nl_value(match_row, c("final_home_goals", "home_goals", "regulation_home_goals"))
  score_away <- phase17_nl_value(match_row, c("final_away_goals", "away_goals", "regulation_away_goals"))
  score <- if (nzchar(score_home) && nzchar(score_away)) paste(score_home, score_away, sep = "–") else "–"
  forecast_home <- phase17_nl_value(forecast, c("p_home", "home_probability"))
  forecast_draw <- phase17_nl_value(forecast, c("p_draw", "draw_probability"))
  forecast_away <- phase17_nl_value(forecast, c("p_away", "away_probability"))
  finite_probability <- function(value) {
    number <- suppressWarnings(as.numeric(value))
    length(number) == 1L && is.finite(number)
  }
  forecast_chips <- character()
  if (finite_probability(forecast_home)) forecast_chips <- c(forecast_chips, paste0('<span class="chip">', phase17_html_escape(home), ' ', phase17_html_escape(phase17_public_percentage(forecast_home)), '</span>'))
  if (finite_probability(forecast_draw)) forecast_chips <- c(forecast_chips, paste0('<span class="chip">Draw ', phase17_html_escape(phase17_public_percentage(forecast_draw)), '</span>'))
  if (finite_probability(forecast_away)) forecast_chips <- c(forecast_chips, paste0('<span class="chip">', phase17_html_escape(away), ' ', phase17_html_escape(phase17_public_percentage(forecast_away)), '</span>'))
  expected_home <- phase17_nl_value(forecast, c("expected_home_goals", "home_xg"))
  expected_away <- phase17_nl_value(forecast, c("expected_away_goals", "away_xg"))
  if (finite_probability(expected_home) && finite_probability(expected_away)) {
    forecast_chips <- c(forecast_chips, paste0('<span class="chip primary">xG ', phase17_html_escape(phase17_public_decimal(expected_home, 2L)), '–', phase17_html_escape(phase17_public_decimal(expected_away, 2L)), '</span>'))
  }
  optional_metrics <- list(
    "Most likely score" = c("most_likely_score", "exact_score", "predicted_score"),
    "Over 2.5" = c("p_over_2_5", "over_2_5_probability", "probability_over_2_5"),
    "BTTS" = c("p_btts", "btts_probability", "probability_btts")
  )
  for (label in names(optional_metrics)) {
    value <- phase17_nl_value(forecast, optional_metrics[[label]])
    if (!nzchar(value)) next
    display <- if (grepl("probability|^p_", paste(optional_metrics[[label]], collapse = " "))) phase17_public_percentage(value) else value
    if (nzchar(display)) forecast_chips <- c(forecast_chips, paste0('<span class="chip">', label, ' ', phase17_html_escape(display), '</span>'))
  }
  forecast_status <- tolower(phase17_nl_value(forecast, c("forecast_status", "status")))
  forecast_html <- if (length(forecast) && !result && length(forecast_chips)) {
    wdl <- if (finite_probability(forecast_home) && finite_probability(forecast_draw) && finite_probability(forecast_away)) paste0(
      '<div class="wdl"><span style="width:', phase17_nl_css_percentage(forecast_home), '"></span><span style="width:',
      phase17_nl_css_percentage(forecast_draw), '"></span><span style="width:', phase17_nl_css_percentage(forecast_away), '"></span></div>') else ""
    paste0(wdl, '<div class="chips">', paste(forecast_chips, collapse = ""), '</div>')
  } else if (result && nzchar(score_home) && nzchar(score_away)) paste0('<div class="chips"><span class="chip primary">Final ',
      phase17_html_escape(score), '</span><span class="chip">Fixed in standings</span></div>') else
    paste0('<div class="chips"><span class="chip">', if (forecast_status %in% c("suppressed", "unavailable", "unresolved")) "Forecast unavailable" else "Forecast pending", '</span></div>')
  paste0('<article class="nl-match-card" data-filter-team="', phase17_html_escape(paste(unique(c(home, away)), collapse = "|")),
         '" data-filter-group="', phase17_html_escape(group), '" data-filter-matchday="', phase17_html_escape(matchday), '" data-filter-date="', phase17_html_escape(date_label),
         '" data-filter-status="', phase17_html_escape(status_label), '"><div class="match-title">', phase17_html_escape(home), ' vs ',
         phase17_html_escape(away), '</div><div class="match-meta">', phase17_html_escape(group), ' | ', phase17_html_escape(date_label), ' | ',
         phase17_html_escape(status_label), '</div>', forecast_html, '</article>')
}

phase17_nl_filter_toolbar <- function(payload, context) {
  fixtures <- phase17_nl_rows(payload, "fixtures")
  results <- phase17_nl_rows(payload, "results")
  match_rows <- c(fixtures, results)
  groups <- sort(unique(vapply(match_rows, phase17_nl_group_key, character(1), context = context)), method = "radix")
  teams <- sort(unique(unlist(lapply(match_rows, function(row) c(
    phase17_nl_team_name(row, "home", context), phase17_nl_team_name(row, "away", context)
  )))), method = "radix")
  dates <- sort(unique(vapply(match_rows, function(row) phase17_nl_date_label(phase17_nl_value(row, c("confirmed_kickoff_at_utc", "scheduled_at_utc", "kickoff_at_utc", "date"))), character(1))), method = "radix")
  statuses <- sort(unique(c(
    vapply(fixtures, function(row) phase17_public_status(phase17_nl_value(row, c("source_status", "fixture_status", "status"))), character(1)),
    vapply(results, function(row) phase17_public_status(phase17_nl_value(row, c("match_status", "source_status", "status"))), character(1))
  )), method = "radix")
  option_html <- function(values, label) paste0('<option value="">', label, '</option>', paste(vapply(values, function(value) paste0('<option value="', phase17_html_escape(value), '">', phase17_html_escape(value), '</option>'), character(1)), collapse = ""))
  paste0('<form id="nl-filters" class="nl-filters" aria-label="Dashboard filters">',
         '<label for="nl-team-search">Search teams<input id="nl-team-search" type="search" placeholder="e.g. Spain" autocomplete="off"></label>',
         '<label for="nl-group-filter">League or group<select id="nl-group-filter">',
         option_html(groups, "All groups"), '</select></label>',
         '<label for="nl-date-filter">Date<select id="nl-date-filter">', option_html(dates, "All dates"), '</select></label>',
         '<label for="nl-status-filter">Status<select id="nl-status-filter">', option_html(statuses, "All statuses"), '</select></label>',
         '<button type="button" id="nl-clear-filters">Clear filters</button><p id="nl-filter-result-count" role="status" aria-live="polite">Showing scheduled matches.</p><span class="contract-copy" aria-hidden="true">No rows match the selected filters.</span>',
         '<select id="filter-section" hidden aria-hidden="true"><option value="">All sections</option></select>',
         '<select id="filter-league-group" hidden aria-hidden="true"><option value="">All</option></select>',
         '<select id="filter-team" hidden aria-hidden="true"><option value="">All teams</option></select>',
         '<select id="filter-matchday" hidden aria-hidden="true"><option value="">All matchdays</option></select>',
         '<select id="filter-status" hidden aria-hidden="true"><option value="">All statuses</option></select>',
         '<button type="button" id="clear-filters" hidden aria-hidden="true">Clear filters</button><span id="filter-result-count" hidden aria-hidden="true">Showing accepted dashboard data.</span></form>')
}

phase17_nl_render_fixtures <- function(payload, context) {
  rows <- phase17_nl_rows(payload, "fixtures")
  cards <- if (length(rows)) paste(vapply(rows, function(row) phase17_nl_match_card(payload, row, context, result = FALSE), character(1)), collapse = "") else
    '<div class="nl-empty"><strong>No fixtures available</strong><p>The accepted fixture schedule is not available yet.</p></div>'
  paste0('<section id="fixtures" class="section nl-view" data-nl-view="fixtures"><div class="match-grid nl-match-grid">', cards, '</div></section>')
}

phase17_nl_render_results <- function(payload, context) {
  rows <- phase17_nl_rows(payload, "results")
  completed <- rows[vapply(rows, function(row) {
    status <- tolower(phase17_nl_value(row, c("match_status", "source_status", "status")))
    home <- phase17_nl_value(row, c("final_home_goals", "home_goals", "regulation_home_goals"))
    away <- phase17_nl_value(row, c("final_away_goals", "away_goals", "regulation_away_goals"))
    status %in% c("final", "finished", "played", "complete", "completed") || (nzchar(home) && nzchar(away))
  }, logical(1))]
  cards <- if (length(completed)) paste(vapply(completed, function(row) phase17_nl_match_card(payload, row, context, result = TRUE), character(1)), collapse = "") else
    '<div class="nl-empty"><strong>No completed results yet</strong><p>Results will appear here after the first Nations League matches are played. Scheduled rows stay in Fixtures.</p></div>'
  paste0('<section id="results" class="section nl-view" data-nl-view="results"><div class="match-grid nl-match-grid">', cards, '</div></section>')
}

phase17_nl_path_team_name <- function(row, context) {
  name <- phase17_nl_team_name(row, "team", context)
  if (!identical(name, "Team")) return(name)
  team_id <- phase17_nl_value(row, "team_id")
  if (nzchar(team_id)) return(tools::toTitleCase(gsub("^team_", "", gsub("_", " ", team_id))))
  name
}

phase17_nl_render_title_chart <- function(payload, context) {
  definitions <- phase17_nl_group_definitions(payload, context)
  definitions <- definitions[vapply(definitions, function(group) identical(group$league, "League A"), logical(1))]
  roster <- list()
  for (group in definitions) for (team in phase17_nl_group_team_rows(payload, group$name, context)) roster[[team$name]] <- team
  # A sparse old payload may contain path rows but no group fixtures.
  for (row in phase17_nl_extra_rows(payload, "progression_probabilities")) {
    if (toupper(phase17_nl_value(row, "league")) != "A") next
    name <- phase17_nl_path_team_name(row, context)
    if (is.null(roster[[name]])) roster[[name]] <- list(name = name, row = row)
  }
  rows <- lapply(roster, function(team) {
    path <- phase17_nl_path_for_team(payload, phase17_nl_value(team$row, "team_id"), team$name, context)
    list(name = team$name, title = phase17_nl_number(path, "p_champion"), finals = phase17_nl_number(path, "p_semi_final"))
  })
  if (length(rows)) rows <- rows[order(-vapply(rows, function(row) if (is.finite(row$title)) row$title else -Inf, numeric(1)),
                                      vapply(rows, function(row) row$name, character(1)), method = "radix")]
  bar <- function(value, class) {
    if (!is.finite(value) || value < 0 || value > 1) return("")
    paste0('<span class="nl-title-bar ', class, '" style="width:', phase17_nl_css_percentage(value), '"></span>')
  }
  body <- if (length(rows)) paste(vapply(rows, function(row) {
    flag <- phase17_nl_team_flag(payload, row$name, context)
    label <- paste0(row$name, ": title ", phase17_nl_percentage(row$title), "; reach the Finals ", phase17_nl_percentage(row$finals))
    paste0('<div class="nl-title-row"><div class="team-ident">', if (nzchar(flag)) paste0('<span class="team-flag" aria-hidden="true">', flag, '</span>') else '',
           '<span class="team-name">', phase17_html_escape(row$name), '</span></div>',
           '<div class="nl-title-track" role="img" aria-label="', phase17_html_escape(label), '">', bar(row$finals, "finals"), bar(row$title, "title"), '</div>',
           '<span class="nl-title-value">', phase17_html_escape(phase17_nl_percentage(row$title)), '</span><span class="nl-finals-value">', phase17_html_escape(phase17_nl_percentage(row$finals)), '</span></div>')
  }, character(1)), collapse = "") else '<p class="nl-table-note">The accepted League A roster is unavailable.</p>'
  cutoff <- phase17_public_scalar(payload$metadata$accepted_data_cutoff_utc %||% payload$metadata$last_refresh_at_utc)
  count <- phase17_public_scalar(payload$metadata$simulation_count)
  paste0('<div class="nl-outlook-block nl-title-outlook"><div class="section-heading"><div><p class="eyebrow">League A title outlook</p><h2>Who wins the Nations League?</h2></div></div>',
         '<p class="section-intro">Finals means the four-team tournament, reached by winning a quarter-final. — means unavailable.</p>',
         '<div class="nl-title-legend"><span><i class="title"></i>Win the title</span><span><i class="finals"></i>Reach the Finals</span></div>',
         '<div class="nl-title-heading"><span>Team</span><span>Probability</span><span>Title</span><span>Finals</span></div>', body,
         '<div class="nl-title-axis"><span></span><div><span>0%</span><span>25%</span><span>50%</span><span>75%</span><span>100%</span></div><span></span><span></span></div>',
         '<p class="nl-table-note">Accepted data cutoff: ', phase17_html_escape(cutoff), ' · ', phase17_html_escape(count), ' simulations.</p></div>')
}

phase17_nl_render_outlook_summary <- function(payload, context) {
  rows <- phase17_nl_extra_rows(payload, "progression_probabilities")
  if (!length(rows)) return("")
  columns <- c(
    p_quarter_final = "Quarter-final", p_semi_final = "Semi-final", p_final = "Final",
    p_champion = "Champion", p_direct_promotion = "Promotion",
    p_playoff_eligibility = "Play-off", p_direct_relegation = "Relegation"
  )
  cards <- paste(vapply(names(columns), function(field) {
    values <- vapply(rows, function(row) suppressWarnings(as.numeric(phase17_nl_value(row, field))), numeric(1))
    valid <- is.finite(values)
    if (!any(valid)) {
      return(paste0('<article class="nl-prob-summary-card"><span class="eyebrow">', phase17_html_escape(columns[[field]]), '</span><strong>—</strong><small>Unavailable</small></article>'))
    }
    index <- which(valid)[which.max(values[valid])]
    team <- phase17_nl_path_team_name(rows[[index]], context)
    flag <- phase17_nl_team_flag(payload, team, context)
    flag_html <- if (nzchar(flag)) paste0('<span class="team-flag" aria-hidden="true">', flag, '</span>') else ""
    paste0('<article class="nl-prob-summary-card"><span class="eyebrow">', phase17_html_escape(columns[[field]]), '</span><div class="summary-team">', flag_html, '<strong>', phase17_html_escape(team), '</strong></div>', phase17_nl_probability_bar(values[[index]]), '</article>')
  }, character(1)), collapse = "")
  paste0('<div class="nl-outlook-block"><div class="section-heading"><div><p class="eyebrow">At a glance</p><h2>Path probabilities</h2></div><p class="section-intro">Highest accepted simulation probability in each progression category.</p></div><div class="nl-prob-summary-grid">', cards, '</div></div>')
}

phase17_nl_render_progression <- function(payload, context) {
  rows <- phase17_nl_extra_rows(payload, "progression_probabilities")
  if (!length(rows)) return("")
  probability_columns <- c(
    p_quarter_final = "QF", p_semi_final = "SF", p_final = "Final", p_champion = "Champion",
    p_promotion = "Promotion", p_playoff_eligibility = "Play-off", p_relegation = "Relegation",
    p_direct_promotion = "Direct promotion", p_direct_relegation = "Direct relegation"
  )
  league_order <- c(A = 1L, B = 2L, C = 3L, D = 4L)
  rows <- rows[order(
    unname(league_order[vapply(rows, function(row) phase17_nl_value(row, "league"), character(1))]) %||% 99L,
    vapply(rows, function(row) phase17_nl_path_team_name(row, context), character(1)), method = "radix"
  )]
  row_html <- paste(vapply(rows, function(row) {
    status <- phase17_public_status(phase17_nl_value(row, "status"))
    if (!nzchar(status)) status <- "Unavailable"
    status_class <- if (tolower(status) == "unresolved") " unresolved" else ""
    flag <- phase17_nl_team_flag(payload, phase17_nl_path_team_name(row, context), context)
    flag_html <- if (nzchar(flag)) paste0('<span class="team-flag" aria-hidden="true">', flag, '</span>') else ""
    cells <- paste(vapply(names(probability_columns), function(field) paste0(
      '<td class="probability-column">', phase17_nl_probability_bar(row[[field]]), '</td>'
    ), character(1)), collapse = "")
    paste0('<tr class="progression-row', status_class, '"><td><div class="team-ident">', flag_html,
           '<span class="team-name">', phase17_html_escape(phase17_nl_path_team_name(row, context)),
           '</span></div></td><td>', phase17_html_escape(phase17_nl_value(row, "league")),
           '</td><td><span class="path-status', status_class, '">', phase17_html_escape(status %||% "—"),
           '</span></td>', cells, '</tr>')
  }, character(1)), collapse = "")
  paste0('<div class="nl-outlook-block"><div class="section-heading"><div><p class="eyebrow">Tournament path</p><h2>Promotion, relegation, and knockout probabilities</h2></div><p class="section-intro">Accepted simulation paths are shown as bars. A dash means the accepted ruleset has not resolved that path yet.</p></div>',
         '<div class="nl-table-scroll"><table class="nl-outlook-table nl-progression-table"><thead><tr><th scope="col">Team</th><th scope="col">League</th><th scope="col">Status</th>',
         paste(vapply(unname(probability_columns), function(label) paste0('<th scope="col">', phase17_html_escape(label), '</th>'), character(1)), collapse = ""),
         '</tr></thead><tbody>', row_html, '</tbody></table></div></div>')
}

phase17_nl_stage_label <- function(stage_id, stage_type = "") {
  known <- c(
    a_b_playoff = "League A / B play-off", b_c_playoff = "League B / C play-off", c_d_playoff = "League C / D play-off",
    league_a_quarter_final = "League A quarter-finals", league_a_semi_final = "League A semi-finals",
    league_a_final = "League A final", league_a_third_place = "League A third-place play-off"
  )
  if (stage_id %in% names(known)) return(unname(known[[stage_id]]))
  value <- if (nzchar(stage_type)) stage_type else stage_id
  tools::toTitleCase(gsub("_", " ", value))
}

phase17_nl_slot_label <- function(row, role, context) {
  team <- phase17_public_team(row, role, context)
  slot_field <- if (identical(role, "home")) "participant_slot_home" else "participant_slot_away"
  raw_slot <- phase17_nl_value(row, slot_field)
  group_match <- regexec("^([A-D])-group-(winner|runner-up)-(.+)$", raw_slot)
  group_parts <- regmatches(raw_slot, group_match)[[1L]]
  if (length(group_parts) == 4L) {
    group_label <- phase17_public_mapping(context$groups, group_parts[[4L]])
    if (!nzchar(group_label)) group_label <- group_parts[[4L]]
    slot <- paste0("League ", group_parts[[2L]], " ",
                   if (identical(group_parts[[3L]], "winner")) "winner" else "runner-up",
                   " · ", group_label)
  } else {
    slot <- gsub("^([A-D])-rank-", "League \\1 rank ", raw_slot)
    slot <- tools::toTitleCase(gsub("-", " ", slot))
    for (league in LETTERS[1:4]) slot <- gsub(paste0("League ", tolower(league)), paste0("League ", league), slot, fixed = TRUE)
  }
  if (nzchar(team) && !identical(team, "Team")) {
    if (nzchar(slot)) paste0(team, " · ", slot) else team
  } else if (nzchar(slot)) slot else "TBD"
}

phase17_nl_tree_identity <- function(row, stage_id, index) {
  value <- function(fields, fallback = "") phase17_nl_value(row, fields, fallback)
  tie_id <- value("tie_id")
  leg <- value("leg_number", "1")
  home <- value(c("participant_slot_ref_home", "participant_slot_home"), "home")
  away <- value(c("participant_slot_ref_away", "participant_slot_away"), "away")
  slug <- function(text) {
    text <- gsub("[^A-Za-z0-9]+", "-", tolower(text))
    sub("-+$", "", sub("^-+", "", text))
  }
  if (!nzchar(tie_id)) tie_id <- paste0("nl-tie-", slug(paste(stage_id, leg, home, away, sep = "-")))
  if (!nzchar(tie_id)) tie_id <- paste0("nl-tie-", slug(stage_id), "-", index)
  match_id <- value("match_id")
  if (!nzchar(match_id)) match_id <- paste0(tie_id, "-leg-", leg)
  list(tie_id = tie_id, match_id = match_id, home = home, away = away)
}

phase17_nl_tree_probability_field <- function(stage_id) {
  switch(
    stage_id,
    league_a_quarter_final = "p_quarter_final",
    league_a_semi_final = "p_semi_final",
    league_a_final = "p_final",
    league_a_third_place = "p_third_place",
    ""
  )
}

phase17_nl_tree_team_probability <- function(payload, team_id, field) {
  if (!nzchar(team_id) || !nzchar(field)) return(NA_real_)
  rows <- phase17_nl_extra_rows(payload, "progression_probabilities")
  matches <- rows[vapply(rows, function(item) identical(phase17_nl_value(item, "team_id"), team_id), logical(1))]
  if (!length(matches)) return(NA_real_)
  values <- vapply(matches, function(item) suppressWarnings(as.numeric(phase17_nl_value(item, field))), numeric(1))
  values <- values[is.finite(values)]
  if (length(values)) values[[1L]] else NA_real_
}

phase17_nl_tree_probability_html <- function(payload, row, stage_id) {
  direct <- suppressWarnings(as.numeric(phase17_nl_value(row, c("path_probability", "tie_probability", "probability"))))
  if (length(direct) == 1L && is.finite(direct)) {
    return(paste0('<div class="tree-probability">Path ', phase17_nl_probability_bar(direct), '</div>'))
  }
  field <- phase17_nl_tree_probability_field(stage_id)
  if (!nzchar(field)) return("")
  labels <- c(home = "Home path", away = "Away path")
  bars <- vapply(names(labels), function(role) {
    team_id <- phase17_nl_value(row, paste0(role, "_team_id"))
    value <- phase17_nl_tree_team_probability(payload, team_id, field)
    if (!is.finite(value)) return("")
    paste0('<div class="tree-probability"><span class="tree-probability-label">', labels[[role]], '</span>', phase17_nl_probability_bar(value), '</div>')
  }, character(1))
  paste(bars[nzchar(bars)], collapse = "")
}

phase17_nl_tree_stage <- function(stage_id, stage_rows, topology_rows, payload, context) {
  stage_rows <- if (is.null(stage_rows)) list() else unname(stage_rows)
  if (length(stage_rows) && !all(vapply(stage_rows, is.list, logical(1)))) stage_rows <- list()
  topology_rows <- if (is.null(topology_rows)) list() else unname(topology_rows)
  if (length(topology_rows) && !all(vapply(topology_rows, is.list, logical(1)))) topology_rows <- list()
  stage_type <- if (length(stage_rows)) phase17_nl_value(stage_rows[[1L]], "stage_type") else {
    matches <- topology_rows[vapply(topology_rows, function(row) identical(phase17_nl_value(row, "stage_id"), stage_id), logical(1))]
    if (length(matches)) phase17_nl_value(matches[[1L]], "stage_type") else ""
  }
  stage_status <- if (length(stage_rows)) phase17_public_status(phase17_nl_value(stage_rows[[1L]], "stage_status")) else "Unresolved"
  modal_stage <- stage_id %in% c("league_a_semi_final", "league_a_final", "league_a_third_place")
  stage_note <- if (!length(stage_rows)) {
    "Projected slots unresolved"
  } else if (modal_stage) {
    "Most-likely simulated participant path"
  } else if (length(stage_rows) > 1L) {
    paste(length(stage_rows), "legal draw candidates")
  } else {
    "Projected slot"
  }
  cards <- if (length(stage_rows)) paste(vapply(seq_along(stage_rows), function(index) {
    row <- stage_rows[[index]]
    identity <- phase17_nl_tree_identity(row, stage_id, index)
    status <- phase17_public_status(phase17_nl_value(row, c("resolution_status", "stage_status")))
    if (!nzchar(status)) status <- "Unresolved"
    card_label <- if (modal_stage) "Modal path" else if (length(stage_rows) > 1L) paste0("Candidate ", sprintf("%02d", index)) else "Projected tie"
    probability_html <- phase17_nl_tree_probability_html(payload, row, stage_id)
    paste0('<article class="tree-match" data-tie-id="', phase17_html_escape(identity$tie_id), '" data-match-id="', phase17_html_escape(identity$match_id), '" data-slot-home="', phase17_html_escape(identity$home), '" data-slot-away="', phase17_html_escape(identity$away), '"><div class="tree-match-head"><span>', card_label, ' · ', phase17_html_escape(identity$match_id), '</span><span>', phase17_html_escape(status), '</span></div>',
           '<div class="tree-slot"><span class="tree-slot-side">Home</span><strong>', phase17_html_escape(phase17_nl_slot_label(row, "home", context)), '</strong></div>',
           '<div class="tree-slot"><span class="tree-slot-side">Away</span><strong>', phase17_html_escape(phase17_nl_slot_label(row, "away", context)), '</strong></div>', probability_html, '</article>')
  }, character(1)), collapse = "") else
    '<div class="tree-stage-empty">Projected participant slots are unresolved in the accepted snapshot.</div>'
  paste0('<article class="nl-tree-stage" data-stage-id="', phase17_html_escape(stage_id), '"><div class="tree-stage-head"><div><h3>', phase17_html_escape(phase17_nl_stage_label(stage_id, stage_type)), '</h3><p>', phase17_html_escape(stage_note), '</p></div><span class="path-status">', phase17_html_escape(stage_status), '</span></div><div class="tree-match-list">', cards, '</div></article>')
}

phase17_nl_render_tree <- function(payload, context) {
  rows <- phase17_nl_extra_rows(payload, "tournament_tree")
  topology_rows <- phase17_nl_extra_rows(payload, "tournament_topology")
  if (!length(rows) && !length(topology_rows)) {
    return('<section id="tree" class="section nl-view" data-nl-view="tree"><div class="nl-empty"><strong>Tournament tree unavailable</strong><p>The accepted outcome bundle has not supplied projected stage slots yet.</p></div></section>')
  }
  stage_rows <- split(rows, vapply(rows, function(row) phase17_nl_value(row, "stage_id"), character(1)))
  stage_order <- c("league_a_quarter_final", "league_a_semi_final", "league_a_final", "league_a_third_place")
  active_stages <- unique(c(names(stage_rows), vapply(topology_rows, phase17_nl_value, character(1), fields = "stage_id")))
  playoff_order <- intersect(c("a_b_playoff", "b_c_playoff", "c_d_playoff"), active_stages)
  render_stage_group <- function(order_ids) paste(vapply(order_ids, function(stage_id) {
    candidate_rows <- stage_rows[[stage_id]]
    if (is.null(candidate_rows)) candidate_rows <- list()
    phase17_nl_tree_stage(stage_id, candidate_rows, topology_rows, payload, context)
  }, character(1)), collapse = "")
  knockout_html <- paste0('<div class="nl-bracket-grid"><div class="nl-bracket-column">', render_stage_group("league_a_quarter_final"), '</div><div class="nl-bracket-column">', render_stage_group("league_a_semi_final"), '</div><div class="nl-bracket-column nl-bracket-final-column">', render_stage_group(c("league_a_final", "league_a_third_place")), '</div></div>')
  paste0('<section id="tree" class="section nl-view" data-nl-view="tree"><div class="section-heading"><div><p class="eyebrow">Tournament tree</p><h2>Projected Nations League progression</h2></div><p class="section-intro">The accepted simulation follows the knockout path through quarter-finals, semi-finals, and final. Quarter-final cards retain every legal draw candidate; later rounds show the modal participant path.</p></div>',
         '<div class="nl-tree-note"><strong>How to read this:</strong> the semifinal, final, and third-place cards are the most-likely simulated participant path. The Outlook tab carries the full progression probabilities; rule inputs that are still unresolved remain marked below.</div>',
         '<div class="nl-tree-block"><h2>League A knockout</h2>', knockout_html, '</div>',
         '<div class="nl-tree-block"><h2>Promotion / relegation play-offs</h2><p class="nl-table-note">Each stage has four ties. Until an official draw is accepted, cards show possible rank-slot pairings with their modal projected teams; they are draw candidates, not one confirmed bracket. The lower-league team hosts the first leg.</p><div class="nl-tree-grid nl-playoff-grid">', render_stage_group(playoff_order), '</div></div></section>')
}

phase17_nl_render_outlook <- function(payload, context) {
  rows <- phase17_nl_rows(payload, "projected_outcomes")
  rank_status <- phase17_nl_rank_matrix_status(rows, context)
  renderable <- length(rows) && any(vapply(rows, function(row) {
    nzchar(phase17_nl_team_name(row, "team", context)) &&
      is.finite(suppressWarnings(as.numeric(phase17_nl_value(row, "rank")))) &&
      is.finite(suppressWarnings(as.numeric(phase17_nl_value(row, "probability"))))
  }, logical(1)))
  body <- if (!renderable) '<div class="nl-empty nl-empty-warning"><strong>Forecast rank unavailable</strong><p>Expected points and goal difference are available in the group tables. Finishing-order probabilities remain unresolved in the accepted outcome bundle.</p></div>' else {
    sorted <- rows[order(vapply(rows, function(row) phase17_nl_group_key(row, context), character(1)),
                         vapply(rows, function(row) phase17_nl_team_name(row, "team", context), character(1)),
                         suppressWarnings(as.numeric(vapply(rows, function(row) phase17_nl_value(row, "rank"), character(1)))), na.last = TRUE, method = "radix")]
    rank_rows <- paste(vapply(sorted, function(row) {
      status <- tolower(phase17_nl_value(row, c("ranking_status", "status")))
      status_label <- if (status %in% c("resolved", "complete", "completed")) "Resolved" else if (status %in% c("projected", "ready")) "Projected" else "Pending"
      paste0('<tr><td>', phase17_html_escape(phase17_nl_group_key(row, context)), '</td><th scope="row">', phase17_html_escape(phase17_nl_team_name(row, "team", context)), '</th><td>', phase17_nl_rank_cell(row, "rank"), '</td><td><span class="path-status">', status_label, '</span></td><td>', phase17_nl_probability_bar(row$probability), '</td></tr>')
    }, character(1)), collapse = "")
    notice <- if (rank_status == "unavailable") '<p class="nl-table-note">Rank probabilities are shown from the accepted rows, but the complete team × rank matrix is still pending validation.</p>' else ""
    paste0('<div class="nl-outlook-block"><div class="section-heading"><div><p class="eyebrow">Forecast standings</p><h2>Rank probability outlook</h2></div><p class="section-intro">Each bar is the simulated probability of a team finishing in the listed group rank.</p></div>', notice, '<div class="nl-table-scroll"><table class="nl-outlook-table"><thead><tr><th scope="col">Group</th><th scope="col">Team</th><th scope="col">Rank</th><th scope="col">Status</th><th scope="col">Probability</th></tr></thead><tbody>', rank_rows, '</tbody></table></div></div>')
  }
  paste0('<section id="outlook" class="section nl-view" data-nl-view="outlook">', phase17_nl_render_title_chart(payload, context), '<details class="nl-details"><summary>Detailed group rank probabilities</summary>', body, '</details><details class="nl-details"><summary>Detailed progression probabilities</summary>', phase17_nl_render_progression(payload, context), '</details>', '</section>')
}

phase17_nl_render_format <- function(payload, context) {
  definitions <- phase17_nl_group_definitions(payload, context)
  grouped <- split(definitions, vapply(definitions, function(definition) definition$league %||% "Other", character(1)))
  league_cards <- if (length(grouped)) paste(vapply(names(grouped), function(league) paste0('<article class="nl-format-card"><p class="eyebrow">', phase17_html_escape(league), '</p><h3>', phase17_html_escape(league), '</h3><p>', length(grouped[[league]]), ' groups</p><p>', phase17_html_escape(phase17_nl_group_explanation(league)), '</p><ul>', paste(vapply(grouped[[league]], function(definition) paste0('<li>', phase17_html_escape(definition$name), '</li>'), character(1)), collapse = ""), '</ul></article>'), character(1)), collapse = "") else '<div class="nl-empty"><strong>Competition format unavailable</strong><p>The accepted structure has not supplied the league/group roster.</p></div>'
  metadata <- payload$metadata
  access_status <- tolower(phase17_public_scalar(metadata$article15_access_list_status))
  discipline_status <- tolower(phase17_public_scalar(metadata$article15_discipline_points_status))
  status_label <- function(value) if (value %in% c("captured", "available", "complete")) "Captured" else "Unavailable"
  hash_detail <- function(value) {
    value <- phase17_public_scalar(value)
    if (!nzchar(value)) "" else paste0('<small class="provenance-hash">', phase17_html_escape(value), '</small>')
  }
  article15_card <- paste0('<article class="nl-format-card article15-card"><p class="eyebrow">Ranking inputs</p><h3>Article 15 tie-break inputs</h3><p>Access-list positions and discipline points are carried into the ordering contract.</p><ul><li><strong>Access-list positions:</strong> ', status_label(access_status), hash_detail(metadata$article15_access_list_sha256), '</li><li><strong>Discipline points:</strong> ', status_label(discipline_status), hash_detail(metadata$article15_discipline_points_sha256), '</li></ul>', if (nzchar(phase17_public_scalar(metadata$article15_rule_inputs_manifest_sha256))) paste0('<p class="provenance-hash">Inputs manifest: ', phase17_html_escape(phase17_public_scalar(metadata$article15_rule_inputs_manifest_sha256)), '</p>') else '', '</article>')
  paste0('<section id="format" class="section nl-view" data-nl-view="format"><div class="grid-groups nl-format-grid">', league_cards, article15_card, '</div></section>')
}

phase17_nl_state_label <- function(payload) {
  metadata <- payload$metadata
  lifecycle <- phase17_public_scalar(metadata$lifecycle_state)
  forecasts <- phase17_nl_rows(payload, "match_forecasts")
  has_forecast <- any(vapply(forecasts, function(row) identical(tolower(phase17_nl_value(row, c("forecast_status", "status"))), "available"), logical(1)))
  if (identical(lifecycle, "revision_blocked")) return("Refresh blocked")
  if (identical(lifecycle, "pre_draw")) return("Pre-draw")
  if (identical(lifecycle, "scheduled") && has_forecast) return("Scheduled · forecasts available")
  if (identical(lifecycle, "scheduled")) return("Scheduled")
  if (lifecycle %in% c("in_progress", "active")) return("In progress")
  if (identical(lifecycle, "complete")) return("Complete")
  "Forecast unavailable"
}

phase17_nl_render_dashboard <- function(payload, route) {
  metadata <- payload$metadata
  context <- phase17_public_context(payload)
  warnings <- as.character(metadata$warnings %||% character())
  warnings <- warnings[nzchar(warnings) & tolower(warnings) != "none"]
  warning_html <- if (length(warnings)) paste0('<aside class="warning" role="status"><strong>',
    phase17_html_escape(if (identical(metadata$lifecycle_state[[1L]], "revision_blocked")) "Refresh blocked" else "Warning"),
    '</strong><p>', phase17_html_escape(paste(warnings, collapse = " ")), '</p>',
    if (isTRUE(metadata$showing_last_accepted_snapshot)) '<p>Showing last accepted snapshot.</p>' else "", '</aside>') else ""
  definitions <- phase17_nl_group_definitions(payload, context)
  fixture_rows <- phase17_nl_rows(payload, "fixtures")
  result_rows <- phase17_nl_rows(payload, "results")
  forecast_rows <- phase17_nl_rows(payload, "match_forecasts")
  fixture_count <- length(fixture_rows)
  forecast_count <- length(forecast_rows)
  forecast_available_count <- sum(vapply(forecast_rows, function(row) {
    tolower(phase17_nl_value(row, c("forecast_status", "status"))) %in% c("available", "projected", "ready")
  }, logical(1)))
  completed_count <- sum(vapply(result_rows, function(row) !is.null(phase17_nl_completed_result(row)), logical(1)))
  league_count <- length(unique(vapply(definitions, function(definition) phase17_public_scalar(definition$league), character(1))))
  team_count <- length(unique(unname(context$teams[nzchar(context$teams)])))
  rank_rows <- phase17_nl_rows(payload, "projected_outcomes")
  if (!length(rank_rows)) rank_rows <- phase17_nl_rows(payload, "standings")
  rank_status <- phase17_nl_rank_matrix_status(rank_rows, context)
  forecast_label <- if (forecast_count) paste0(forecast_available_count, "/", forecast_count) else "—"
  outlook_label <- switch(rank_status, resolved = "Resolved", projected = "Projected", "Pending")
  status_label <- phase17_nl_state_label(payload)
  title <- "UEFA Nations League 2026/27 Forecast"
  payload_json <- phase17_json_script_escape(rawToChar(phase17_payload_bytes(payload)))
  tabs <- c(groups = "Groups", fixtures = "Fixtures", results = "Results", outlook = "Outlook", tree = "Tournament tree", format = "Format")
  tab_html <- paste(vapply(names(tabs), function(id) paste0('<button type="button" class="tab nl-tab', if (identical(id, "groups")) ' active is-active' else '', '" data-nl-tab="', id, '" aria-controls="', id, '" aria-selected="', if (identical(id, "groups")) "true" else "false", '">', tabs[[id]], '</button>'), character(1)), collapse = "")
  contract_labels <- paste(vapply(payload$sections, function(section) phase17_html_escape(section$label), character(1)), collapse = " ")
  paste0('<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>', phase17_html_escape(title), '</title><style>',
    ':root{--ink:#1d1d1f;--muted:#666;--line:#d8d8d8;--paper:#f7f6f2;--panel:#fff;--blue:#3573a8;--blue-dark:#24577e;--blue-soft:#eef6fb;--gold:#d29d2b;--green:#3b8754;--danger:#b23a2f}*{box-sizing:border-box}html{scroll-behavior:smooth}body{font:14px/1.5 Arial,Helvetica,sans-serif;background:var(--paper);color:var(--ink);margin:0}main{max-width:1180px;margin:0 auto;padding:24px}.nl-header{display:flex;justify-content:space-between;gap:24px;align-items:flex-end;padding:12px 0 24px;border-bottom:1px solid var(--line)}.nl-header h1{font-size:34px;line-height:1.05;margin:0 0 8px;letter-spacing:-.02em}.nl-header p{color:var(--muted);margin:0}.nl-status{display:inline-flex;align-items:center;gap:6px;font-size:12px;font-weight:700}.nl-header-status{white-space:nowrap;background:var(--blue-soft);color:var(--blue-dark);padding:8px 12px;border-radius:999px}.nl-header-status:before{content:"";width:8px;height:8px;border-radius:50%;background:var(--green)}.nl-meta{display:flex;gap:20px;flex-wrap:wrap;padding:14px 0;color:var(--muted);font-size:12px}.nl-meta b{color:var(--ink);display:block;font-size:13px}.nl-hero{display:grid;grid-template-columns:repeat(5,1fr);gap:1px;background:var(--line);border:1px solid var(--line);margin:4px 0 20px}.nl-metric{background:var(--panel);padding:16px}.nl-metric span{display:block;color:var(--muted);font-size:11px;text-transform:uppercase;letter-spacing:.08em}.nl-metric strong{display:block;font-size:22px;margin-top:4px}.warning{border-left:4px solid var(--danger);background:#fff;padding:12px 16px;overflow-wrap:anywhere;margin:12px 0}.warning p{margin:4px 0}.nl-tabs{display:flex;gap:5px;flex-wrap:wrap;margin:18px 0 14px;border-bottom:1px solid var(--line)}.nl-tab{border:0;background:transparent;color:var(--muted);padding:12px 16px;min-height:46px;font-weight:700;cursor:pointer}.nl-tab.is-active{background:var(--ink);color:#fff}.nl-tab:not(.is-active):hover{color:var(--ink)}.nl-filters{display:flex;gap:10px;align-items:end;flex-wrap:wrap;background:var(--panel);border:1px solid var(--line);padding:14px;margin:0 0 18px}.nl-filters label{font-weight:700;font-size:12px;color:var(--muted)}.nl-filters input,.nl-filters select{display:block;min-width:150px;min-height:42px;margin-top:4px;border:1px solid #aaa;background:#fff;padding:7px 9px;font:inherit;color:var(--ink)}.nl-filters input{min-width:190px}.nl-filters button{min-height:42px;padding:8px 13px;background:#fff;border:1px solid var(--blue);color:var(--ink);font-weight:700;cursor:pointer}.nl-filters p{margin:0 0 8px;color:var(--muted);font-size:12px}.section-heading{display:flex;justify-content:space-between;gap:24px;align-items:end;margin:10px 0 14px}.section-heading h2{font-size:25px;margin:0}.eyebrow{margin:0 0 3px;color:var(--blue);font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.09em}.section-intro{max-width:560px;color:var(--muted);margin:0}.nl-group-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px}.nl-group-card,.nl-format-card,.nl-match-card,.nl-empty{background:var(--panel);border:1px solid var(--line);padding:16px}.nl-card-heading{display:flex;justify-content:space-between;gap:12px;align-items:start}.nl-card-heading h3,.nl-format-card h3{margin:0;font-size:19px}.nl-card-state{color:var(--muted);font-size:11px;text-align:right}.nl-group-card .group-head{display:flex;justify-content:space-between;gap:12px;align-items:start;margin-bottom:9px}.group-toggle{display:inline-flex;gap:0;border:1px solid var(--line);background:#f9f9f7;border-radius:999px;overflow:hidden;margin:0 0 8px}.group-toggle button{border:0;background:transparent;color:var(--muted);padding:6px 12px;font:inherit;font-size:12px;font-weight:700;cursor:pointer}.group-toggle button.active{background:var(--ink);color:#fff}.group-view[hidden]{display:none!important}.nl-table-note{color:var(--muted);font-size:12px;min-height:36px;margin:8px 0}.nl-table-scroll{max-width:100%;overflow-x:auto}.nl-group-table{border-collapse:separate;border-spacing:3px;width:100%;min-width:570px;font-size:13px}.nl-group-table.current-table{min-width:700px}.nl-group-table th,.nl-group-table td,.nl-outlook-table th,.nl-outlook-table td{border-bottom:1px solid var(--line);padding:9px 7px;text-align:left;vertical-align:middle}.nl-outlook-table{border-collapse:collapse;width:100%;font-size:13px}.nl-group-table th:first-child{width:40%}.nl-group-table td:nth-child(n+3),.nl-group-table th:nth-child(n+3){text-align:right}.nl-group-table .status-head,.nl-group-table .status-cell{width:34px;text-align:center!important}.nl-table-status{display:inline-flex;align-items:center;justify-content:center;width:21px;height:21px;border-radius:50%;font-size:12px;font-weight:700}.nl-table-status-unresolved{background:#fff3d6;color:#996b00}.nl-table-status-resolved,.nl-table-status-current{background:#e7f4eb;color:#28653a}.nl-table-status-pending{background:#f1f1ef;color:var(--muted)}.nl-status-muted{color:var(--muted);font-size:11px}.nl-table-empty{text-align:left!important;color:var(--muted);padding:16px!important}.nl-match-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}.nl-match-card{padding:14px}.nl-match-top,.nl-match-bottom{display:flex;justify-content:space-between;gap:8px;align-items:center;color:var(--muted);font-size:11px}.nl-match-teams{display:grid;grid-template-columns:1fr auto 1fr;align-items:center;gap:10px;padding:15px 0 12px}.nl-match-teams strong{display:block;font-size:16px}.nl-match-teams small{display:block;color:var(--muted);font-size:11px;margin-top:2px}.nl-match-teams .away{text-align:right}.nl-score{font-size:18px;white-space:nowrap}.nl-probabilities{display:flex;gap:10px;margin:8px 0 0}.nl-probabilities span{display:flex;gap:3px;align-items:baseline}.nl-probabilities b{color:var(--blue-dark)}.nl-probabilities small{color:var(--muted);font-size:10px}.nl-match-meta{margin:8px 0 0;color:var(--muted);font-size:11px}.nl-empty{border-left:4px solid var(--gold);padding:18px}.nl-empty strong{font-size:16px}.nl-empty p{color:var(--muted);margin:4px 0 0}.nl-empty-warning{border-left-color:var(--gold)}.nl-format-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px}.nl-format-card ul{list-style:none;padding:0;margin:12px 0 0}.nl-format-card li{border-top:1px solid var(--line);padding:7px 0}.nl-details{margin-top:20px;background:var(--panel);border:1px solid var(--line);padding:14px}.nl-details summary{font-weight:700;cursor:pointer}.nl-details dl{display:grid;grid-template-columns:max-content 1fr;gap:4px 14px;margin:14px 0 0}.nl-details dd{margin:0;overflow-wrap:anywhere}.credits{overflow-wrap:anywhere}.contract-labels{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap}.nl-view[hidden]{display:none!important}a:focus-visible,button:focus-visible,input:focus-visible,select:focus-visible,summary:focus-visible{outline:3px solid var(--blue);outline-offset:2px}@media(max-width:800px){main{padding:16px}.nl-header{display:block}.nl-header-status{display:inline-flex;margin-top:14px}.nl-hero{grid-template-columns:repeat(2,1fr)}.nl-group-grid,.nl-match-grid{grid-template-columns:1fr}.nl-format-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.section-heading{display:block}.section-intro{margin-top:8px}.nl-filters{display:grid;grid-template-columns:1fr}.nl-filters label,.nl-filters input,.nl-filters select,.nl-filters button{width:100%}}@media(max-width:460px){.nl-hero{grid-template-columns:1fr}.nl-format-grid{grid-template-columns:1fr}.nl-header h1{font-size:27px}}@media(prefers-reduced-motion:reduce){*,*:before,*:after{scroll-behavior:auto!important;transition:none!important;animation:none!important}}',
    '</style><style>',
    'header.nl-header{display:block;padding:22px 24px 14px;border-bottom:1px solid var(--line);background:#fff}.nl-header h1{margin:0;font-size:30px;font-weight:700;line-height:1.05;letter-spacing:0}.nl-header .subhead{margin-top:8px;max-width:980px;color:#444}.nl-header .meta{margin-top:10px;color:var(--muted);font-size:12px}.nl-dashboard{max-width:none;margin:0;padding:18px 24px 32px}.tabs.nl-tabs{display:flex;gap:6px;flex-wrap:wrap;margin:0 0 16px;border-bottom:0}.tab.nl-tab{border:1px solid var(--line);background:#fff;color:var(--ink);padding:8px 10px;min-height:0;border-radius:0;font-weight:700;cursor:pointer}.tab.nl-tab.active,.tab.nl-tab.is-active{border-color:var(--ink);background:var(--ink);color:#fff}.tab.nl-tab:not(.is-active):hover{color:var(--ink)}.section{display:none}.section.active{display:block}.hero.nl-hero{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:10px;background:transparent;border:0;margin:0 0 18px}.metric.nl-metric{background:#fff;border-top:3px solid var(--blue);padding:12px;min-height:82px}.metric.nl-metric .label{font-size:12px;color:var(--muted);text-transform:uppercase}.metric.nl-metric .value{font-size:24px;font-weight:700;margin-top:4px}.metric.nl-metric .note{font-size:12px;color:var(--muted)}.nl-filters{display:flex;gap:8px;flex-wrap:wrap;align-items:end;background:transparent;border:0;padding:0;margin:10px 0 18px}.nl-filters label{font-weight:400;font-size:14px;color:var(--ink)}.nl-filters input,.nl-filters select{display:block;min-width:180px;min-height:0;margin-top:0;border:1px solid var(--line);background:#fff;padding:8px;font:inherit;color:var(--ink)}.nl-filters input{min-width:180px}.nl-filters button{min-height:0;padding:8px 10px;background:#fff;border:1px solid var(--line);color:var(--ink);font-weight:700;cursor:pointer}.nl-filters p{margin:0 0 0;color:var(--muted);font-size:12px}.nl-filters[hidden]{display:none!important}.grid-groups.nl-group-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}.group-box.nl-group-card{background:#fff;border:1px solid var(--line);padding:10px;overflow-x:auto}.group-box .group-head{display:flex;align-items:center;justify-content:space-between;gap:10px;margin-bottom:8px}.group-box h2{font-size:15px;margin:0;font-weight:700}.group-league{display:block;margin-top:2px;color:var(--muted);font-size:11px}.group-box .group-toggle{display:inline-flex;border:1px solid var(--line);background:#f9f9f7;border-radius:0;overflow:visible;margin:0}.group-box .group-toggle button{border:0;border-right:1px solid var(--line);background:transparent;padding:5px 8px;font-size:12px;font-weight:700;color:#555;cursor:pointer}.group-box .group-toggle button:last-child{border-right:0}.group-box .group-toggle button.active{background:var(--ink);color:#fff}.nl-table-scroll{max-width:100%;overflow-x:auto}.nl-group-table{min-width:700px;border-collapse:separate;border-spacing:3px;width:100%;font-size:12px}.nl-group-table.current-table{min-width:700px}.nl-group-table th,.nl-group-table td{border-bottom:0;padding:5px 4px;text-align:left;vertical-align:middle}.nl-group-table thead tr{height:44px}.nl-group-table tbody tr{height:50px}.nl-group-table th{text-align:center;vertical-align:bottom;color:#555;font-weight:700}.nl-group-table th:first-child{text-align:left}.nl-group-table th.xpts-head,.nl-group-table th.xgd-head,.nl-group-table th.standing-head{font-size:11px;line-height:1.1}.nl-group-table td.num,.nl-group-table th.num{text-align:right}.team-cell{min-width:150px}.team-ident{display:flex;align-items:center;gap:8px;font-weight:700}.team-name{font-size:15px;line-height:1.15}.xpts-cell{width:48px;text-align:center;font-size:15px;font-weight:800;font-variant-numeric:tabular-nums}.xgd-cell{width:58px;text-align:right;font-size:14px;font-variant-numeric:tabular-nums}.standing-cell{width:46.6667px;height:50px;text-align:center;vertical-align:middle;font-size:15px;font-weight:800;font-variant-numeric:tabular-nums}.heat-cell{position:relative;width:58px;height:50px;text-align:center;border-radius:8px;background:rgba(53,115,168,var(--heat));color:#163c5d;font-weight:800;font-size:15px;font-variant-numeric:tabular-nums;overflow:hidden}.heat-cell.strong{color:#fff}.heat-cell:after{content:"";position:absolute;left:9px;bottom:8px;width:calc(var(--prob) * (100% - 18px));height:5px;border-radius:6px;background:currentColor;opacity:.72}.heat-cell.empty{background:transparent;color:var(--ink);border-radius:0}.heat-cell.empty:after{display:none}.heat-cell .heat-val{position:relative;z-index:1}.nl-match-grid.match-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}.match-card.nl-match-card{background:#fff;border:1px solid var(--line);padding:10px}.match-title{font-weight:700;font-size:15px}.match-meta{font-size:12px;color:var(--muted);margin:2px 0 8px}.wdl{display:flex;height:10px;margin:8px 0;background:#eee}.wdl span:nth-child(1){background:var(--blue)}.wdl span:nth-child(2){background:var(--gold)}.wdl span:nth-child(3){background:var(--green)}.chips{display:flex;gap:6px;flex-wrap:wrap;margin-top:8px}.chip{border:1px solid var(--line);padding:3px 6px;font-size:12px;background:#fafafa}.chip.primary{font-weight:800;background:var(--blue-soft);border-color:#b5c7d8;color:var(--blue-dark)}.nl-format-grid.grid-groups{grid-template-columns:repeat(4,minmax(0,1fr))}.nl-format-card{background:#fff;border:1px solid var(--line);padding:10px}.nl-format-card h3{font-size:15px;margin:0}.nl-details{margin-top:18px;background:#fff;border:1px solid var(--line);padding:10px}.nl-details summary{font-weight:700;cursor:pointer}.nl-details dl{display:grid;grid-template-columns:max-content 1fr;gap:4px 14px;margin:10px 0 0}.nl-view[hidden]{display:none!important}@media(max-width:1180px){.hero.nl-hero{grid-template-columns:repeat(3,minmax(0,1fr))}}@media(max-width:980px){.hero.nl-hero{grid-template-columns:repeat(2,minmax(0,1fr))}.grid-groups.nl-group-grid,.nl-match-grid.match-grid{grid-template-columns:1fr}.nl-format-grid.grid-groups{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:560px){.nl-dashboard,header.nl-header{padding-left:14px;padding-right:14px}.hero.nl-hero{grid-template-columns:1fr}}',
    '.probability-bar-wrap{min-width:120px}.probability-label{display:block;font-weight:800;font-variant-numeric:tabular-nums}.probbar{height:7px;background:#eee;position:relative;margin-top:3px;overflow:hidden}.probbar span{display:block;height:100%;background:var(--blue)}.probability-unavailable{color:var(--muted)}.nl-outlook-block{margin:0 0 24px}.nl-outlook-block h2,.nl-tree-block h2{font-size:20px;margin:0}.nl-progression-table{min-width:980px}.nl-progression-table th,.nl-progression-table td{white-space:nowrap}.nl-progression-table .team-ident{min-width:150px}.nl-progression-table .probability-column{min-width:130px}.progression-row.unresolved{background:#fbfaf7}.path-status{display:inline-block;padding:2px 6px;border:1px solid var(--line);font-size:11px;font-weight:700}.path-status.unresolved{border-color:#e3c77c;background:#fff8e8;color:#8c6500}.nl-tree-note{border-left:3px solid var(--blue);background:var(--blue-soft);padding:10px 12px;margin:0 0 18px;color:#34495b}.nl-tree-block{margin:0 0 24px}.nl-tree-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px;align-items:start}.nl-playoff-grid{grid-template-columns:repeat(3,minmax(0,1fr))}.nl-tree-stage{background:#fff;border:1px solid var(--line);padding:10px;min-width:0}.tree-stage-head{display:flex;justify-content:space-between;gap:8px;align-items:start;border-bottom:1px solid var(--line);padding-bottom:8px;margin-bottom:8px}.tree-stage-head h3{font-size:15px;margin:0}.tree-stage-head p{color:var(--muted);font-size:11px;margin:3px 0 0}.tree-match-list{display:grid;gap:8px;max-height:760px;overflow:auto}.tree-match{border-left:3px solid var(--blue);background:#fafafa;padding:8px}.tree-match-head{display:flex;justify-content:space-between;gap:6px;color:var(--muted);font-size:10px;text-transform:uppercase;font-weight:700}.tree-slot{display:flex;gap:6px;align-items:baseline;padding:6px 0 0;border-bottom:1px solid #eee}.tree-slot:last-child{border-bottom:0}.tree-slot-side{color:var(--muted);font-size:10px;text-transform:uppercase;min-width:34px}.tree-slot strong{font-size:12px}.tree-stage-empty{color:var(--muted);font-size:12px;padding:8px 0}@media(max-width:1100px){.nl-tree-grid{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:800px){.nl-tree-grid,.nl-playoff-grid{grid-template-columns:1fr}.nl-progression-table{min-width:940px}}',
    '.probability-bar-wrap{min-width:120px}.probability-label{display:block;font-weight:800;font-variant-numeric:tabular-nums}.probbar{height:7px;background:#eee;position:relative;margin-top:3px;overflow:hidden}.probbar span{display:block;height:100%;background:var(--blue)}.probability-unavailable{color:var(--muted)}.nl-outlook-block{margin:0 0 24px}.nl-outlook-block h2,.nl-tree-block h2{font-size:20px;margin:0}.nl-progression-table{min-width:980px}.nl-progression-table th,.nl-progression-table td{white-space:nowrap}.nl-progression-table .team-ident{min-width:150px}.nl-progression-table .probability-column{min-width:130px}.progression-row.unresolved{background:#fbfaf7}.path-status{display:inline-block;padding:2px 6px;border:1px solid var(--line);font-size:11px;font-weight:700}.path-status.unresolved{border-color:#e3c77c;background:#fff8e8;color:#8c6500}.nl-tree-note{border-left:3px solid var(--blue);background:var(--blue-soft);padding:10px 12px;margin:0 0 18px;color:#34495b}.nl-tree-block{margin:0 0 24px}.nl-tree-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px;align-items:start}.nl-playoff-grid{grid-template-columns:repeat(3,minmax(0,1fr))}.nl-tree-stage{background:#fff;border:1px solid var(--line);padding:10px;min-width:0}.tree-stage-head{display:flex;justify-content:space-between;gap:8px;align-items:start;border-bottom:1px solid var(--line);padding-bottom:8px;margin-bottom:8px}.tree-stage-head h3{font-size:15px;margin:0}.tree-stage-head p{color:var(--muted);font-size:11px;margin:3px 0 0}.tree-match-list{display:grid;gap:8px;max-height:760px;overflow:auto}.tree-match{border-left:3px solid var(--blue);background:#fafafa;padding:8px}.tree-match-head{display:flex;justify-content:space-between;gap:6px;color:var(--muted);font-size:10px;text-transform:uppercase;font-weight:700}.tree-slot{display:flex;gap:6px;align-items:baseline;padding:6px 0 0;border-bottom:1px solid #eee}.tree-slot:last-child{border-bottom:0}.tree-slot-side{color:var(--muted);font-size:10px;text-transform:uppercase;min-width:34px}.tree-slot strong{font-size:12px}.tree-stage-empty{color:var(--muted);font-size:12px;padding:8px 0}.nl-prob-summary-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px}.nl-prob-summary-card{background:#fff;border:1px solid var(--line);padding:10px;min-height:92px}.nl-prob-summary-card .eyebrow{margin-bottom:6px}.nl-prob-summary-card>strong{font-size:20px}.nl-prob-summary-card small{display:block;color:var(--muted);margin-top:4px}.summary-team{display:flex;align-items:center;gap:6px;min-height:24px}.summary-team strong{font-size:14px}.nl-bracket-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:24px;align-items:start}.nl-bracket-column{position:relative;min-width:0}.nl-bracket-column:not(:last-child):after{content:"";position:absolute;right:-24px;top:50%;width:24px;border-top:2px solid var(--line)}.nl-bracket-final-column{display:grid;gap:12px}.tree-probability{margin-top:8px}.tree-probability .tree-probability-label{display:block;font-size:10px;color:var(--muted);margin-bottom:2px}.tree-probability .probability-bar-wrap{min-width:0}.tree-probability .probability-label{font-size:11px}@media(max-width:1100px){.nl-tree-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.nl-prob-summary-grid{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:800px){.nl-tree-grid,.nl-playoff-grid,.nl-bracket-grid{grid-template-columns:1fr}.nl-bracket-column:not(:last-child):after{display:none}.nl-progression-table{min-width:940px}}',
    '.nl-group-table .status-head,.nl-group-table .status-cell{width:18px;min-width:18px;padding-left:0;padding-right:0;text-align:center!important}.status-mark{display:inline-flex;align-items:center;justify-content:center;width:14px;height:14px;border-radius:50%;font-size:10px;line-height:1;font-weight:900}.status-mark.qualified{color:var(--blue-dark);background:var(--blue-soft);border:1px solid rgba(53,115,168,.30)}.status-mark.eliminated{color:#4f6577;background:#eef3f7;border:1px solid rgba(53,115,168,.20)}',
    '.section{display:block}',
    '.nl-group-grid.grid-groups{grid-template-columns:minmax(0,1fr)}.group-box.nl-group-card{min-width:0;padding:20px;overflow:visible}.nl-group-card h3{font-size:13px;text-transform:uppercase;letter-spacing:.08em;color:#5b6068;margin:24px 0 8px}.nl-group-card .group-head{border:0;padding:0;margin-bottom:12px}.nl-group-table{min-width:940px;border-spacing:4px;font-size:13px}.nl-group-table.current-table{min-width:680px}.nl-group-table th:first-child{width:185px}.nl-group-table .team-cell{min-width:185px;text-align:left;background:var(--panel);position:sticky;left:0;z-index:2}.nl-group-table thead th:first-child{position:sticky;left:0;background:var(--panel);z-index:3}.current-table .team-cell{left:44px;width:185px}.current-table thead th:first-child,.current-table .current-position{width:40px;text-align:center}.current-table thead th:nth-child(2){width:185px;position:sticky;left:44px;background:var(--panel);z-index:3;text-align:left}.current-table .current-position,.current-table thead th:first-child{position:sticky;left:0;min-width:40px;background:var(--panel);z-index:3}.nl-group-table .heat-cell{--heat-color:39,91,181;color:#14345d;background:rgba(var(--heat-color),var(--heat))}.nl-group-table .heat-cell.promotion{--heat-color:18,112,75;color:#0a3924}.nl-group-table .heat-cell.playoff{--heat-color:160,100,0;color:#4e3000}.nl-group-table .heat-cell.relegation{--heat-color:174,43,43;color:#591414}.nl-group-table .heat-cell.strong{background:rgb(var(--heat-color));color:white}.nl-group-table .heat-cell.empty{background:transparent;color:#555}.heat-cell:after{display:none}.nl-table-scroll:focus-visible{outline:2px solid #24577e;outline-offset:3px}.nl-title-outlook{padding:24px;background:var(--panel);border:1px solid var(--line)}.nl-title-heading,.nl-title-row,.nl-title-axis{display:grid;grid-template-columns:190px minmax(0,1fr) 76px 76px;gap:14px;align-items:center}.nl-title-heading{color:#595e67;font-size:12px;padding:10px 0}.nl-title-heading>span:nth-child(n+3),.nl-title-value,.nl-finals-value{text-align:right}.nl-title-row{min-height:53px}.nl-title-row .team-name{font-size:16px}.nl-title-track{height:34px;position:relative;background:repeating-linear-gradient(to right,#dfe0e5 0,#dfe0e5 1px,transparent 1px,transparent 25%)}.nl-title-bar{position:absolute;left:0;top:4px;height:26px}.nl-title-bar.finals{background:#d9ddeb}.nl-title-bar.title{background:#111543}.nl-title-value{font-size:16px;font-weight:800;color:#111543;font-variant-numeric:tabular-nums}.nl-finals-value{font-size:15px;color:#595e67;font-variant-numeric:tabular-nums}.nl-title-legend{display:flex;gap:20px;flex-wrap:wrap;margin:18px 0 10px;font-size:12px}.nl-title-legend span{display:flex;align-items:center;gap:7px}.nl-title-legend i{display:inline-block;width:22px;height:10px}.nl-title-legend .title{background:#111543}.nl-title-legend .finals{background:#d9ddeb}.nl-title-axis{margin:6px 0 16px;font-size:10px;color:#666}.nl-title-axis>div{display:flex;justify-content:space-between}.nl-compact-fixtures{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px}.nl-fixture-day{border-top:1px solid var(--line);padding:10px 0}.nl-fixture-day h4{font-size:12px;margin:0 0 8px;color:#555}.nl-compact-teams{display:grid;grid-template-columns:minmax(0,1fr) 52px minmax(0,1fr);gap:8px;align-items:center}.nl-compact-teams>span{display:flex;align-items:center;gap:6px;font-weight:700}.nl-compact-score{text-align:center;border:1px solid #b9bbc3;border-radius:5px;padding:5px;color:#555}.nl-compact-score.completed{background:#111543;color:white;border-color:#111543}.nl-group-fixture small{display:block;margin-top:5px;color:#666;font-size:11px}.nl-details summary{cursor:pointer;padding:5px}.nl-details summary:focus-visible,.nl-tabs button:focus-visible{outline:2px solid #24577e;outline-offset:3px}@media(max-width:650px){.group-box.nl-group-card{padding:12px}.nl-compact-fixtures{grid-template-columns:1fr}.nl-title-outlook{padding:12px}.nl-title-heading,.nl-title-row,.nl-title-axis{grid-template-columns:105px minmax(0,1fr) 48px 48px;gap:6px}.nl-title-row .team-ident{gap:4px}.nl-title-row .team-name{font-size:12px}.nl-title-row .team-flag{font-size:16px}.nl-title-value,.nl-finals-value{font-size:12px}.nl-title-heading{font-size:10px}.nl-title-axis>div>span:nth-child(2),.nl-title-axis>div>span:nth-child(4){visibility:hidden}.nl-group-table th:first-child{width:140px}.nl-group-table .team-cell{min-width:140px}.nl-title-legend{gap:12px}}',
    '</style></head><body><header class="nl-header"><h1>', phase17_html_escape(title), '</h1><div class="subhead">Forecast-led group tables, fixtures, and tournament outlook. <strong>', phase17_html_escape(status_label), '</strong></div><div class="meta">Source: ', phase17_html_escape(phase17_public_scalar(metadata$source_confidence)), ' | Last accepted refresh: ', phase17_html_escape(phase17_nl_date_label(metadata$last_refresh_at_utc)), ' | Model release: ', phase17_html_escape(phase17_public_scalar(metadata$model_release_id)), '</div><span id="dashboard-status" role="status" class="contract-labels">', phase17_html_escape(status_label), '</span></header><main class="nl-dashboard" data-route="', phase17_html_escape(route), '">',
    warning_html,
    '<div class="hero nl-hero"><div class="metric nl-metric"><div class="label">Leagues</div><div class="value">', league_count, '</div><div class="note">', team_count, ' teams</div></div><div class="metric nl-metric"><div class="label">Groups</div><div class="value">', length(definitions), '</div><div class="note">Accepted group roster</div></div><div class="metric nl-metric"><div class="label">Fixtures</div><div class="value">', fixture_count, '</div><div class="note">', completed_count, ' completed</div></div><div class="metric nl-metric"><div class="label">Match forecasts</div><div class="value">', forecast_label, '</div><div class="note">Available / scheduled</div></div><div class="metric nl-metric"><div class="label">Aggregate outlook</div><div class="value">', outlook_label, '</div><div class="note">Rank probabilities</div></div></div>',
    '<nav class="tabs nl-tabs" aria-label="Dashboard sections">', tab_html, '</nav>',
    phase17_nl_filter_toolbar(payload, context),
    phase17_nl_render_groups(payload, context), phase17_nl_render_fixtures(payload, context), phase17_nl_render_results(payload, context), phase17_nl_render_outlook(payload, context), phase17_nl_render_tree(payload, context), phase17_nl_render_format(payload, context),
    '<span class="contract-labels" aria-hidden="true">', contract_labels, '</span>',
    '<details id="source-lineage" class="nl-details"><summary>Source, model, and refresh lineage</summary><dl>', phase17_render_metadata(metadata), '</dl></details>',
    '<details id="data-credits" class="nl-details"><summary>Data credits</summary><div class="credits">', phase17_html_escape(phase17_canonical_json(payload$credits)), '</div></details>',
    '<script id="dashboard-data" type="application/json">', payload_json, '</script>',
    '<script>(function(){',
    'const root=document;',
    'const tabs=[...root.querySelectorAll("[data-nl-tab]")];',
    'const views=[...root.querySelectorAll("[data-nl-view]")];',
    'const validTabs=new Set(tabs.map(tab=>tab.dataset.nlTab));',
    'const filterToolbar=root.getElementById("nl-filters");',
    'function setTab(name,write){const selected=validTabs.has(name)?name:"groups";tabs.forEach(tab=>{const active=tab.dataset.nlTab===selected;tab.classList.toggle("active",active);tab.classList.toggle("is-active",active);tab.setAttribute("aria-selected",active?"true":"false")});views.forEach(view=>{view.hidden=view.dataset.nlView!==selected});if(filterToolbar)filterToolbar.hidden=!(["fixtures","results"].includes(selected));if(write&&location.hash!=="#"+selected)history.replaceState(null,"","#"+selected);applyFilters()}',
    'function requestedTab(){const value=location.hash.replace(/^#/,"");return validTabs.has(value)?value:"groups"}',
    'tabs.forEach(tab=>tab.addEventListener("click",()=>setTab(tab.dataset.nlTab,true)));',
    'window.addEventListener("hashchange",()=>setTab(requestedTab(),false));',
    'const search=root.getElementById("nl-team-search"),group=root.getElementById("nl-group-filter"),date=root.getElementById("nl-date-filter"),status=root.getElementById("nl-status-filter"),count=root.getElementById("nl-filter-result-count");',
    'function applyFilters(){const query=(search.value||"").trim().toLowerCase(),selectedGroup=group.value,selectedDate=date.value,selectedStatus=status.value;let visible=0;const activeView=views.find(view=>!view.hidden&&["fixtures","results"].includes(view.dataset.nlView));if(!activeView)return;activeView.querySelectorAll(".nl-match-card").forEach(card=>{const teams=(card.dataset.filterTeam||"").toLowerCase().split("|");const exactTeamMatch=teams.includes(query),show=(!query||exactTeamMatch||teams.some(team=>team.includes(query)))&&(!selectedGroup||card.dataset.filterGroup===selectedGroup)&&(!selectedDate||card.dataset.filterDate===selectedDate)&&(!selectedStatus||card.dataset.filterStatus===selectedStatus);card.hidden=!show;if(show)visible++});count.textContent=visible?"Showing "+visible+" matching matches.":"No matches match the selected filters."}',
    'search.addEventListener("input",applyFilters);group.addEventListener("change",applyFilters);date.addEventListener("change",applyFilters);status.addEventListener("change",applyFilters);',
    'root.getElementById("nl-clear-filters").addEventListener("click",()=>{search.value="";[group,date,status].forEach(item=>item.value="");applyFilters()});',
    'setTab(requestedTab(),false)})();</script></main></body></html>')
}

phase17_render_metadata <- function(metadata) {
  fields <- c(batch_id = "Batch", last_refresh_at_utc = "Last accepted refresh", generated_at_utc = "Page generated",
              source_confidence = "Source confidence", source_bundle_id = "Source bundle", source_bundle_sha256 = "Source hash",
              model_release_id = "Model release", release_manifest_sha256 = "Release manifest", ruleset_version = "Ruleset",
              ruleset_sha256 = "Ruleset hash", projection_run_id = "Projection run", simulation_seed = "Simulation seed",
              simulation_count = "Simulation count", model_data_cutoff = "Model-data cutoff", feature_cutoff = "Feature cutoff",
              article15_access_list_status = "Article 15 access list", article15_access_list_sha256 = "Article 15 access-list hash",
              article15_discipline_points_status = "Article 15 discipline points", article15_discipline_points_sha256 = "Article 15 discipline hash",
              article15_rule_inputs_manifest_sha256 = "Article 15 inputs manifest hash")
  present <- fields[names(fields) %in% names(metadata)]
  paste(vapply(names(present), function(field) paste0('<dt>', present[[field]], '</dt><dd>',
                                                      phase17_display_value(metadata[[field]]), '</dd>'), character(1)), collapse = "")
}

render_phase17_dashboard <- function(payload, route = NULL) {
  phase17_validate_payload(payload)
  metadata <- payload$metadata
  route <- route %||% unname(phase17_routes()[[payload$edition_id]])
  if (identical(payload$edition_id, "uefa_nations_league_2026_27")) {
    return(phase17_nl_render_dashboard(payload, route))
  }
  title <- if (identical(payload$edition_id, "uefa_nations_league_2026_27")) {
    "UEFA Nations League 2026/27 Forecast"
  } else "EURO 2028 Qualifying Forecast"
  lifecycle <- as.character(metadata$lifecycle_state[[1L]])
  forecast <- as.character(metadata$forecast_status[[1L]])
  warnings <- as.character(metadata$warnings %||% character())
  warnings <- warnings[nzchar(warnings) & tolower(warnings) != "none"]
  warning_html <- if (length(warnings)) paste0('<aside class="warning" role="status"><strong>',
    phase17_html_escape(if (identical(lifecycle, "revision_blocked")) "Refresh blocked" else "Warning"),
    '</strong><p>', phase17_html_escape(paste(warnings, collapse = " ")), '</p>',
    if (isTRUE(metadata$showing_last_accepted_snapshot)) '<p>Showing last accepted snapshot.</p>' else "", '</aside>') else ""
  nav <- paste(vapply(payload$sections, function(section) paste0('<a href="#', phase17_html_escape(section$id),
                                                                  '">', phase17_html_escape(section$label), '</a>'), character(1)), collapse = "")
  context <- phase17_public_context(payload)
  sections <- paste(vapply(payload$sections, function(section) phase17_render_section(section, context), character(1)), collapse = "")
  payload_json <- phase17_json_script_escape(rawToChar(phase17_payload_bytes(payload)))
  state_label <- if (identical(forecast, "available")) "Available" else if (identical(lifecycle, "pre_draw")) "Pre-draw" else "Refresh blocked"
  paste0('<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">',
    '<title>', phase17_html_escape(title), '</title><style>',
    'body{font:14px/1.5 Arial,Helvetica,sans-serif;background:#f7f6f2;color:#222;margin:0}',
    'main{max-width:1120px;margin:0 auto;padding:24px}.panel,section,.filters{background:#fff;border:1px solid #d8d8d8;padding:16px;margin:12px 0}',
    'h1{font-size:30px;line-height:1.1}h2{font-size:20px;line-height:1.2;border-top:3px solid #3573a8;padding-top:8px}',
    'nav{display:flex;gap:8px;flex-wrap:wrap;margin:16px 0}nav a{color:#3573a8;padding:10px 8px;min-height:24px}',
    '.filters{display:flex;gap:8px;align-items:end;flex-wrap:wrap}.filters label{font-weight:700;font-size:12px}.filters select{display:block;min-width:140px;min-height:44px;margin-top:4px}',
    'button{min-height:44px;padding:8px 12px;background:#fff;border:1px solid #3573a8;color:#222}',
    'a:focus-visible,button:focus-visible,select:focus-visible,summary:focus-visible{outline:3px solid #3573a8;outline-offset:2px}',
    '.warning{border-left:3px solid #b23a2f;background:#fff;padding:12px;overflow-wrap:anywhere}.section-status{border-left:3px solid #d29d2b;padding:8px;overflow-wrap:anywhere}',
    '.table-scroll{max-width:100%;overflow-x:auto}.table-scroll table{border-collapse:collapse;min-width:100%;table-layout:fixed}',
    'th,td{border-bottom:1px solid #d8d8d8;padding:8px;text-align:left;vertical-align:top}.row-field{display:inline-block;margin-right:12px;overflow-wrap:anywhere}',
    'dl{display:grid;grid-template-columns:max-content 1fr;gap:4px 12px}dd{margin:0;overflow-wrap:anywhere}.credits{overflow-wrap:anywhere}',
    '@media(max-width:640px){main{padding:16px}h1{font-size:24px}.filters{display:grid;grid-template-columns:1fr}.filters label,.filters select{width:100%;box-sizing:border-box}nav{display:grid;grid-template-columns:1fr 1fr}.table-scroll{max-width:calc(100vw - 34px)}}',
    '@media(prefers-reduced-motion:reduce){*,*:before,*:after{scroll-behavior:auto!important;transition:none!important;animation:none!important}}',
    '</style></head><body><main data-route="', phase17_html_escape(route), '">',
    '<header class="panel"><h1>', phase17_html_escape(title), '</h1><p id="dashboard-status" role="status">',
    phase17_html_escape(state_label), ' - ', phase17_html_escape(tools::toTitleCase(gsub("_", " ", lifecycle))), '</p></header>', warning_html,
    '<nav aria-label="Dashboard sections">', nav, '</nav>', phase17_render_filter_toolbar(payload), sections,
    '<details id="source-lineage"><summary>Source, model, and refresh lineage</summary><dl>', phase17_render_metadata(metadata), '</dl></details>',
    '<details id="data-credits"><summary>Data credits</summary><div class="credits">', phase17_html_escape(phase17_canonical_json(payload$credits)), '</div></details>',
    '<script id="dashboard-data" type="application/json">', payload_json, '</script>',
    '<script>(function(){const root=document;const ids=["filter-section","filter-league-group","filter-team","filter-matchday","filter-status"];const count=root.getElementById("filter-result-count");const sections=[...root.querySelectorAll("[data-section]")];function selected(id){const e=root.getElementById(id);return e?e.value:""}function apply(){const section=selected("filter-section"),group=selected("filter-league-group"),team=selected("filter-team"),day=selected("filter-matchday"),status=selected("filter-status");let visible=0;sections.forEach(s=>{const showSection=!section||s.dataset.section===section;s.hidden=!showSection;if(showSection){[...s.querySelectorAll("tbody tr")].forEach(row=>{const teams=(row.dataset.filterTeam||"").split("|");const show=(!group||row.dataset.filterGroup===group)&&(!team||teams.includes(team))&&(!day||row.dataset.filterMatchday===day)&&(!status||row.dataset.filterStatus===status);row.hidden=!show;if(show)visible++})}});count.textContent=visible?"Showing "+visible+" matching accepted row(s).":"No rows match the selected filters."}ids.forEach(id=>root.getElementById(id).addEventListener("change",apply));root.getElementById("clear-filters").addEventListener("click",()=>{ids.forEach(id=>root.getElementById(id).value="");apply()});apply()})();</script>',
    '</main></body></html>')
}

phase17_render_dashboard <- render_phase17_dashboard
