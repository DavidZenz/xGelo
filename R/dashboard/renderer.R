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

phase17_nl_has_resolved_rankings <- function(rows) {
  if (!length(rows)) return(FALSE)
  any(vapply(rows, function(row) {
    status <- tolower(phase17_nl_value(row, c("ranking_status", "status")))
    rank <- phase17_nl_value(row, "rank")
    probability <- phase17_nl_value(row, "probability")
    outcome <- phase17_nl_value(row, "outcome")
    nzchar(rank) || nzchar(probability) ||
      (nzchar(outcome) && nzchar(status) && !status %in% c("unresolved", "unavailable", "blocked"))
  }, logical(1)))
}

phase17_nl_rank_cell <- function(row, field) {
  value <- phase17_nl_value(row, field)
  if (!nzchar(value)) "—" else phase17_html_escape(value)
}

phase17_nl_expected_cell <- function(row, field, digits = 1L) {
  value <- phase17_public_decimal(row[[field]], digits)
  if (!nzchar(value)) "—" else phase17_html_escape(value)
}

phase17_nl_status_copy <- function(payload) {
  standings <- phase17_nl_rows(payload, "standings")
  projected <- phase17_nl_rows(payload, "projected_outcomes")
  if (phase17_nl_has_resolved_rankings(c(standings, projected))) "Forecast standings are available." else
    if (length(c(standings, projected))) "Forecast rank unavailable — xPts and xGD show the accepted expectation inputs." else
      "Forecast unavailable — aggregate standings are unresolved in the accepted outcome bundle."
}

phase17_nl_group_table <- function(payload, definition, context) {
  teams <- phase17_nl_group_team_rows(payload, definition$name, context)
  standings <- phase17_nl_rows(payload, "standings")
  projected <- phase17_nl_rows(payload, "projected_outcomes")
  by_team <- c(standings, projected)
  row_for_team <- function(name) {
    matching <- by_team[vapply(by_team, function(row) {
      identical(phase17_nl_group_key(row, context), definition$name) &&
        identical(phase17_nl_team_name(row, "team", context), name)
    }, logical(1))]
    if (length(matching)) matching[[1L]] else list()
  }
  table_rows <- if (length(teams)) paste(vapply(teams, function(item) {
    row <- if (length(item$row)) item$row else row_for_team(item$name)
    status <- phase17_nl_value(row, c("ranking_status", "status"))
    status_label <- if (nzchar(status)) phase17_public_status(status) else "Not started"
    current_status <- if (nzchar(phase17_nl_value(row, c("points", "rank")))) "Current" else "Not started"
    current_rank <- phase17_nl_value(row, c("current_rank"))
    paste0('<tr><th scope="row">', phase17_html_escape(item$name), '</th>',
           '<td><span class="nl-forecast-value nl-status nl-status-muted">', phase17_html_escape(status_label), '</span><span class="nl-current-value nl-status nl-status-muted" hidden>', phase17_html_escape(current_status), '</span></td>',
           '<td><span class="nl-forecast-value">', phase17_nl_expected_cell(row, "expected_points", 1L), '</span><span class="nl-current-value" hidden>', phase17_nl_expected_cell(row, "points", 1L), '</span></td>',
           '<td><span class="nl-forecast-value">', phase17_nl_expected_cell(row, "expected_goal_difference", 1L), '</span><span class="nl-current-value" hidden>', phase17_nl_expected_cell(row, "goal_difference", 1L), '</span></td>',
           '<td><span class="nl-forecast-value">', phase17_nl_rank_cell(row, "rank"), '</span><span class="nl-current-value" hidden>', if (nzchar(current_rank)) phase17_html_escape(current_rank) else "—", '</span></td></tr>')
  }, character(1)), collapse = "") else
    '<tr><td colspan="5" class="nl-table-empty">Teams will appear when the accepted group roster is available.</td></tr>'
  status_copy <- if (phase17_nl_has_resolved_rankings(by_team)) "Forecast standings available" else "Rank unresolved"
  paste0('<article class="nl-group-card" data-group="', phase17_html_escape(definition$name), '">',
         '<div class="nl-card-heading"><div><p class="eyebrow">', phase17_html_escape(definition$league),
         '</p><h3>', phase17_html_escape(definition$name), '</h3></div>',
         '<span class="nl-card-state">', phase17_html_escape(status_copy), '</span></div>',
         '<div class="nl-view-toggle" role="group" aria-label="', phase17_html_escape(definition$name), ' table view">',
         '<button type="button" class="nl-toggle is-active" data-table-view="forecast">Forecast</button>',
         '<button type="button" class="nl-toggle" data-table-view="current">Current</button></div>',
         '<p class="nl-table-note nl-forecast-view">', phase17_html_escape(phase17_nl_status_copy(payload)), '</p>',
         '<p class="nl-table-note nl-current-view" hidden>No completed results yet. Current standings will appear after the first final matches.</p>',
         '<div class="nl-table-scroll"><table class="nl-group-table"><thead><tr><th scope="col">Team</th><th scope="col">Status</th><th scope="col">xPts Avg</th><th scope="col">xGD Avg</th><th scope="col">Rank</th></tr></thead><tbody>',
         table_rows, '</tbody></table></div></article>')
}

phase17_nl_render_groups <- function(payload, context) {
  definitions <- phase17_nl_group_definitions(payload, context)
  cards <- if (length(definitions)) paste(vapply(definitions, function(definition) phase17_nl_group_table(payload, definition, context), character(1)), collapse = "") else
    '<div class="nl-empty"><strong>No groups available</strong><p>The accepted competition structure has not supplied a group roster yet.</p></div>'
  paste0('<section id="groups" class="nl-view" data-nl-view="groups"><div class="section-heading"><div><p class="eyebrow">Forecast table</p><h2>Groups</h2></div><p class="section-intro">Group tables mirror the World Cup view. Switch between the model forecast and confirmed results as the competition progresses.</p></div><div class="nl-group-grid">', cards, '</div></section>')
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
  forecast_html <- if (length(forecast) && !result) paste0(
    '<div class="nl-probabilities"><span><b>', phase17_public_percentage(phase17_nl_value(forecast, "p_home")), '</b><small>Home</small></span>',
    '<span><b>', phase17_public_percentage(phase17_nl_value(forecast, "p_draw")), '</b><small>Draw</small></span>',
    '<span><b>', phase17_public_percentage(phase17_nl_value(forecast, "p_away")), '</b><small>Away</small></span></div>',
    '<p class="nl-match-meta">xG ', phase17_html_escape(phase17_public_decimal(forecast$expected_home_goals, 2L)), ' – ',
    phase17_html_escape(phase17_public_decimal(forecast$expected_away_goals, 2L)), '</p>') else
    '<p class="nl-match-meta">No match forecast attached</p>'
  paste0('<article class="nl-match-card" data-filter-team="', phase17_html_escape(paste(unique(c(home, away)), collapse = "|")),
         '" data-filter-group="', phase17_html_escape(group), '" data-filter-matchday="', phase17_html_escape(matchday), '" data-filter-date="', phase17_html_escape(date_label),
         '" data-filter-status="', phase17_html_escape(status_label), '"><div class="nl-match-top"><span>',
         phase17_html_escape(date_label), '</span><span>', phase17_html_escape(group), '</span></div><div class="nl-match-teams"><div><strong>',
         phase17_html_escape(home), '</strong><small>Home</small></div><b class="nl-score">', phase17_html_escape(score), '</b><div class="away"><strong>',
         phase17_html_escape(away), '</strong><small>Away</small></div></div><div class="nl-match-bottom"><span class="nl-status nl-status-',
         phase17_html_escape(gsub("[^a-z]+", "-", tolower(status_label))), '">', phase17_html_escape(status_label), '</span>', forecast_html,
         '</div></article>')
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
  paste0('<section id="fixtures" class="nl-view" data-nl-view="fixtures"><div class="section-heading"><div><p class="eyebrow">Match centre</p><h2>Fixtures</h2></div><p class="section-intro">Scheduled matches with the current calibrated 1X2 forecast and expected goals.</p></div><div class="nl-match-grid">', cards, '</div></section>')
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
  paste0('<section id="results" class="nl-view" data-nl-view="results"><div class="section-heading"><div><p class="eyebrow">Match centre</p><h2>Results</h2></div><p class="section-intro">Confirmed scores only. Scheduled matches are kept on the Fixtures tab.</p></div><div class="nl-match-grid">', cards, '</div></section>')
}

phase17_nl_render_outlook <- function(payload, context) {
  rows <- phase17_nl_rows(payload, "projected_outcomes")
  resolved <- phase17_nl_has_resolved_rankings(rows)
  body <- if (!resolved) '<div class="nl-empty nl-empty-warning"><strong>Forecast unavailable</strong><p>Aggregate standings are unresolved in the accepted outcome bundle, so no finishing-order probabilities are shown.</p></div>' else {
    sorted <- rows[order(vapply(rows, function(row) suppressWarnings(as.numeric(phase17_nl_value(row, "rank"))), numeric(1)), na.last = TRUE)]
    paste0('<div class="nl-table-scroll"><table class="nl-outlook-table"><thead><tr><th scope="col">Group</th><th scope="col">Team</th><th scope="col">Rank</th><th scope="col">Outcome</th><th scope="col">Probability</th></tr></thead><tbody>', paste(vapply(sorted, function(row) paste0('<tr><td>', phase17_html_escape(phase17_nl_group_key(row, context)), '</td><th scope="row">', phase17_html_escape(phase17_nl_team_name(row, "team", context)), '</th><td>', phase17_nl_rank_cell(row, "rank"), '</td><td>', phase17_html_escape(phase17_nl_value(row, "outcome")), '</td><td>', phase17_html_escape(phase17_public_percentage(row$probability)), '</td></tr>'), character(1)), collapse = ""), '</tbody></table></div>')
  }
  paste0('<section id="outlook" class="nl-view" data-nl-view="outlook"><div class="section-heading"><div><p class="eyebrow">Tournament outlook</p><h2>Outlook</h2></div><p class="section-intro">Aggregate finishing paths are shown only when the projection bundle resolves the competition rules.</p></div>', body, '</section>')
}

phase17_nl_render_format <- function(payload, context) {
  definitions <- phase17_nl_group_definitions(payload, context)
  grouped <- split(definitions, vapply(definitions, function(definition) definition$league %||% "Other", character(1)))
  league_cards <- if (length(grouped)) paste(vapply(names(grouped), function(league) paste0('<article class="nl-format-card"><p class="eyebrow">', phase17_html_escape(league), '</p><h3>', phase17_html_escape(league), '</h3><p>', length(grouped[[league]]), ' groups</p><ul>', paste(vapply(grouped[[league]], function(definition) paste0('<li>', phase17_html_escape(definition$name), '</li>'), character(1)), collapse = ""), '</ul></article>'), character(1)), collapse = "") else '<div class="nl-empty"><strong>Competition format unavailable</strong><p>The accepted structure has not supplied the league/group roster.</p></div>'
  paste0('<section id="format" class="nl-view" data-nl-view="format"><div class="section-heading"><div><p class="eyebrow">Competition map</p><h2>Format</h2></div><p class="section-intro">The Nations League is organised into four leagues, each split into groups with promotion and relegation paths.</p></div><div class="nl-format-grid">', league_cards, '</div></section>')
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
  fixture_count <- length(phase17_nl_rows(payload, "fixtures"))
  forecast_count <- length(phase17_nl_rows(payload, "match_forecasts"))
  status_label <- phase17_nl_state_label(payload)
  title <- "UEFA Nations League 2026/27 Forecast"
  payload_json <- phase17_json_script_escape(rawToChar(phase17_payload_bytes(payload)))
  tabs <- c(groups = "Groups", fixtures = "Fixtures", results = "Results", outlook = "Outlook", format = "Format")
  tab_html <- paste(vapply(names(tabs), function(id) paste0('<button type="button" class="nl-tab', if (identical(id, "groups")) ' is-active' else '', '" data-nl-tab="', id, '" aria-controls="', id, '" aria-selected="', if (identical(id, "groups")) "true" else "false", '">', tabs[[id]], '</button>'), character(1)), collapse = "")
  contract_labels <- paste(vapply(payload$sections, function(section) phase17_html_escape(section$label), character(1)), collapse = " ")
  paste0('<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>', phase17_html_escape(title), '</title><style>',
    ':root{--ink:#1d1d1f;--muted:#666;--line:#d8d8d8;--paper:#f7f6f2;--panel:#fff;--blue:#3573a8;--blue-dark:#24577e;--blue-soft:#eef6fb;--gold:#d29d2b;--green:#3b8754;--danger:#b23a2f}*{box-sizing:border-box}html{scroll-behavior:smooth}body{font:14px/1.5 Arial,Helvetica,sans-serif;background:var(--paper);color:var(--ink);margin:0}main{max-width:1180px;margin:0 auto;padding:24px}.nl-header{display:flex;justify-content:space-between;gap:24px;align-items:flex-end;padding:12px 0 24px;border-bottom:1px solid var(--line)}.nl-header h1{font-size:34px;line-height:1.05;margin:0 0 8px;letter-spacing:-.02em}.nl-header p{color:var(--muted);margin:0}.nl-status{display:inline-flex;align-items:center;gap:6px;font-size:12px;font-weight:700}.nl-header-status{white-space:nowrap;background:var(--blue-soft);color:var(--blue-dark);padding:8px 12px;border-radius:999px}.nl-header-status:before{content:"";width:8px;height:8px;border-radius:50%;background:var(--green)}.nl-meta{display:flex;gap:20px;flex-wrap:wrap;padding:14px 0;color:var(--muted);font-size:12px}.nl-meta b{color:var(--ink);display:block;font-size:13px}.nl-hero{display:grid;grid-template-columns:repeat(5,1fr);gap:1px;background:var(--line);border:1px solid var(--line);margin:4px 0 20px}.nl-metric{background:var(--panel);padding:16px}.nl-metric span{display:block;color:var(--muted);font-size:11px;text-transform:uppercase;letter-spacing:.08em}.nl-metric strong{display:block;font-size:22px;margin-top:4px}.warning{border-left:4px solid var(--danger);background:#fff;padding:12px 16px;overflow-wrap:anywhere;margin:12px 0}.warning p{margin:4px 0}.nl-tabs{display:flex;gap:5px;flex-wrap:wrap;margin:18px 0 14px;border-bottom:1px solid var(--line)}.nl-tab{border:0;background:transparent;color:var(--muted);padding:12px 16px;min-height:46px;font-weight:700;cursor:pointer}.nl-tab.is-active{background:var(--ink);color:#fff}.nl-tab:hover{color:var(--ink)}.nl-filters{display:flex;gap:10px;align-items:end;flex-wrap:wrap;background:var(--panel);border:1px solid var(--line);padding:14px;margin:0 0 18px}.nl-filters label{font-weight:700;font-size:12px;color:var(--muted)}.nl-filters input,.nl-filters select{display:block;min-width:150px;min-height:42px;margin-top:4px;border:1px solid #aaa;background:#fff;padding:7px 9px;font:inherit;color:var(--ink)}.nl-filters input{min-width:190px}.nl-filters button{min-height:42px;padding:8px 13px;background:#fff;border:1px solid var(--blue);color:var(--ink);font-weight:700;cursor:pointer}.nl-filters p{margin:0 0 8px;color:var(--muted);font-size:12px}.section-heading{display:flex;justify-content:space-between;gap:24px;align-items:end;margin:10px 0 14px}.section-heading h2{font-size:25px;margin:0}.eyebrow{margin:0 0 3px;color:var(--blue);font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.09em}.section-intro{max-width:560px;color:var(--muted);margin:0}.nl-group-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px}.nl-group-card,.nl-format-card,.nl-match-card,.nl-empty{background:var(--panel);border:1px solid var(--line);padding:16px}.nl-card-heading{display:flex;justify-content:space-between;gap:12px;align-items:start}.nl-card-heading h3,.nl-format-card h3{margin:0;font-size:19px}.nl-card-state{color:var(--muted);font-size:11px;text-align:right}.nl-view-toggle{display:flex;gap:0;margin:14px 0 8px;border-bottom:1px solid var(--line)}.nl-toggle{border:0;background:transparent;color:var(--muted);padding:7px 11px;font-weight:700;cursor:pointer}.nl-toggle.is-active{color:var(--blue-dark);border-bottom:3px solid var(--blue)}.nl-table-note{color:var(--muted);font-size:12px;min-height:36px;margin:8px 0}.nl-table-scroll,.nl-table-scroll table{max-width:100%;overflow-x:auto}.nl-group-table,.nl-outlook-table{border-collapse:collapse;width:100%;font-size:13px}.nl-group-table th,.nl-group-table td,.nl-outlook-table th,.nl-outlook-table td{border-bottom:1px solid var(--line);padding:9px 7px;text-align:left;vertical-align:middle}.nl-group-table th:first-child{width:40%}.nl-group-table td:nth-child(n+3),.nl-group-table th:nth-child(n+3){text-align:right}.nl-status-muted{color:var(--muted);font-size:11px}.nl-table-empty{text-align:left!important;color:var(--muted);padding:16px!important}.nl-match-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}.nl-match-card{padding:14px}.nl-match-top,.nl-match-bottom{display:flex;justify-content:space-between;gap:8px;align-items:center;color:var(--muted);font-size:11px}.nl-match-teams{display:grid;grid-template-columns:1fr auto 1fr;align-items:center;gap:10px;padding:15px 0 12px}.nl-match-teams strong{display:block;font-size:16px}.nl-match-teams small{display:block;color:var(--muted);font-size:11px;margin-top:2px}.nl-match-teams .away{text-align:right}.nl-score{font-size:18px;white-space:nowrap}.nl-probabilities{display:flex;gap:10px;margin:8px 0 0}.nl-probabilities span{display:flex;gap:3px;align-items:baseline}.nl-probabilities b{color:var(--blue-dark)}.nl-probabilities small{color:var(--muted);font-size:10px}.nl-match-meta{margin:8px 0 0;color:var(--muted);font-size:11px}.nl-empty{border-left:4px solid var(--gold);padding:18px}.nl-empty strong{font-size:16px}.nl-empty p{color:var(--muted);margin:4px 0 0}.nl-empty-warning{border-left-color:var(--gold)}.nl-format-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px}.nl-format-card ul{list-style:none;padding:0;margin:12px 0 0}.nl-format-card li{border-top:1px solid var(--line);padding:7px 0}.nl-details{margin-top:20px;background:var(--panel);border:1px solid var(--line);padding:14px}.nl-details summary{font-weight:700;cursor:pointer}.nl-details dl{display:grid;grid-template-columns:max-content 1fr;gap:4px 14px;margin:14px 0 0}.nl-details dd{margin:0;overflow-wrap:anywhere}.credits{overflow-wrap:anywhere}.contract-labels{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap}.nl-view[hidden]{display:none!important}a:focus-visible,button:focus-visible,input:focus-visible,select:focus-visible,summary:focus-visible{outline:3px solid var(--blue);outline-offset:2px}@media(max-width:800px){main{padding:16px}.nl-header{display:block}.nl-header-status{display:inline-flex;margin-top:14px}.nl-hero{grid-template-columns:repeat(2,1fr)}.nl-group-grid,.nl-match-grid{grid-template-columns:1fr}.nl-format-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.section-heading{display:block}.section-intro{margin-top:8px}.nl-filters{display:grid;grid-template-columns:1fr}.nl-filters label,.nl-filters input,.nl-filters select,.nl-filters button{width:100%}}@media(max-width:460px){.nl-hero{grid-template-columns:1fr}.nl-format-grid{grid-template-columns:1fr}.nl-header h1{font-size:27px}}@media(prefers-reduced-motion:reduce){*,*:before,*:after{scroll-behavior:auto!important;transition:none!important;animation:none!important}}',
    '</style></head><body><main class="nl-dashboard" data-route="', phase17_html_escape(route), '"><header class="nl-header"><div><p class="eyebrow">UEFA Nations League 2026/27</p><h1>', phase17_html_escape(title), '</h1><p>Forecast-led group tables, fixtures, and tournament outlook.</p></div><p id="dashboard-status" class="nl-header-status" role="status">', phase17_html_escape(status_label), '</p></header>',
    warning_html,
    '<div class="nl-meta"><span><b>Source</b>', phase17_html_escape(phase17_public_scalar(metadata$source_confidence)), '</span><span><b>Last accepted refresh</b>', phase17_html_escape(phase17_nl_date_label(metadata$last_refresh_at_utc)), '</span><span><b>Model release</b>', phase17_html_escape(phase17_public_scalar(metadata$model_release_id)), '</span></div>',
    '<div class="nl-hero"><div class="nl-metric"><span>Leagues</span><strong>4</strong></div><div class="nl-metric"><span>Groups</span><strong>', length(definitions), '</strong></div><div class="nl-metric"><span>Fixtures</span><strong>', fixture_count, '</strong></div><div class="nl-metric"><span>Match forecasts</span><strong>', if (forecast_count) "Available" else "Unavailable", '</strong></div><div class="nl-metric"><span>Aggregate outlook</span><strong>', if (phase17_nl_has_resolved_rankings(phase17_nl_rows(payload, "projected_outcomes"))) "Available" else "Unresolved", '</strong></div></div>',
    phase17_nl_filter_toolbar(payload, context),
    '<nav class="nl-tabs" aria-label="Dashboard sections">', tab_html, '</nav>',
    phase17_nl_render_groups(payload, context), phase17_nl_render_fixtures(payload, context), phase17_nl_render_results(payload, context), phase17_nl_render_outlook(payload, context), phase17_nl_render_format(payload, context),
    '<span class="contract-labels" aria-hidden="true">', contract_labels, '</span>',
    '<details id="source-lineage" class="nl-details"><summary>Source, model, and refresh lineage</summary><dl>', phase17_render_metadata(metadata), '</dl></details>',
    '<details id="data-credits" class="nl-details"><summary>Data credits</summary><div class="credits">', phase17_html_escape(phase17_canonical_json(payload$credits)), '</div></details>',
    '<script id="dashboard-data" type="application/json">', payload_json, '</script>',
    '<script>(function(){const root=document;const tabs=[...root.querySelectorAll("[data-nl-tab]")];const views=[...root.querySelectorAll("[data-nl-view]")];const validTabs=new Set(tabs.map(tab=>tab.dataset.nlTab));function setTab(name,write){const selected=validTabs.has(name)?name:"groups";tabs.forEach(tab=>{const active=tab.dataset.nlTab===selected;tab.classList.toggle("is-active",active);tab.setAttribute("aria-selected",active?"true":"false")});views.forEach(view=>{view.hidden=view.dataset.nlView!==selected});if(write&&location.hash!=="#"+selected)history.replaceState(null,"","#"+selected);applyFilters()}function requestedTab(){const value=location.hash.replace(/^#/,"");return validTabs.has(value)?value:"groups"}tabs.forEach(tab=>tab.addEventListener("click",()=>setTab(tab.dataset.nlTab,true)));window.addEventListener("hashchange",()=>setTab(requestedTab(),false));root.querySelectorAll("[data-table-view]").forEach(button=>button.addEventListener("click",()=>{const card=button.closest(".nl-group-card");if(!card)return;const forecast=button.dataset.tableView==="forecast";card.querySelectorAll("[data-table-view]").forEach(item=>item.classList.toggle("is-active",item===button));card.querySelectorAll(".nl-forecast-view").forEach(item=>{item.hidden=!forecast});card.querySelectorAll(".nl-current-view").forEach(item=>{item.hidden=forecast});card.querySelectorAll(".nl-forecast-value").forEach(item=>{item.hidden=!forecast});card.querySelectorAll(".nl-current-value").forEach(item=>{item.hidden=forecast})}));const search=root.getElementById("nl-team-search"),group=root.getElementById("nl-group-filter"),date=root.getElementById("nl-date-filter"),status=root.getElementById("nl-status-filter"),count=root.getElementById("nl-filter-result-count");function applyFilters(){const query=(search.value||"").trim().toLowerCase(),selectedGroup=group.value,selectedDate=date.value,selectedStatus=status.value;let visible=0;root.querySelectorAll(".nl-match-card").forEach(card=>{const teams=(card.dataset.filterTeam||"").toLowerCase().split("|");const exactTeamMatch=teams.includes(query),show=(!query||exactTeamMatch||teams.some(team=>team.includes(query)))&&(!selectedGroup||card.dataset.filterGroup===selectedGroup)&&(!selectedDate||card.dataset.filterDate===selectedDate)&&(!selectedStatus||card.dataset.filterStatus===selectedStatus);card.hidden=!show;if(show)visible++});count.textContent=visible?"Showing "+visible+" matching matches.":"No matches match the selected filters."}[',
    '"search","group","date","status"].forEach(id=>root.getElementById(id).addEventListener(id==="search"?"input":"change",applyFilters));root.getElementById("nl-clear-filters").addEventListener("click",()=>{search.value="";[group,date,status].forEach(item=>item.value="");applyFilters()});setTab(requestedTab(),false)})();</script></main></body></html>')
}

phase17_render_metadata <- function(metadata) {
  fields <- c(batch_id = "Batch", last_refresh_at_utc = "Last accepted refresh", generated_at_utc = "Page generated",
              source_confidence = "Source confidence", source_bundle_id = "Source bundle", source_bundle_sha256 = "Source hash",
              model_release_id = "Model release", release_manifest_sha256 = "Release manifest", ruleset_version = "Ruleset",
              ruleset_sha256 = "Ruleset hash", projection_run_id = "Projection run", simulation_seed = "Simulation seed",
              simulation_count = "Simulation count", model_data_cutoff = "Model-data cutoff", feature_cutoff = "Feature cutoff")
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
