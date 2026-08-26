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
  title <- if (identical(payload$edition_id, "uefa_nations_league_2026_27")) {
    "UEFA Nations League 2026/27 Forecast"
  } else "EURO 2028 Qualifying Forecast"
  lifecycle <- as.character(metadata$lifecycle_state[[1L]])
  forecast <- as.character(metadata$forecast_status[[1L]])
  warnings <- as.character(metadata$warnings %||% character())
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
