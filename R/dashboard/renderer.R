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
  value <- as.character(value)
  value <- gsub("&", "\\u0026", value, fixed = TRUE)
  value <- gsub("<", "\\u003c", value, fixed = TRUE)
  value <- gsub(">", "\\u003e", value, fixed = TRUE)
  value <- gsub("\\u2028", "\\u2028", value, fixed = TRUE)
  gsub("\\u2029", "\\u2029", value, fixed = TRUE)
}

phase17_render_section <- function(section) {
  if (!is.list(section)) stop("Phase 17 renderer section must be a list", call. = FALSE)
  status <- phase17_html_escape(section$status[[1L]])
  reason <- phase17_html_escape(section$reason[[1L]] %||% "")
  rows <- phase17_html_escape(length(section$rows))
  state <- if (identical(status, "available")) {
    paste0('<p class="section-count">', rows, ' accepted row(s)</p>')
  } else {
    paste0('<div class="section-status" data-status="', status, '">',
           '<strong>', phase17_html_escape(tools::toTitleCase(gsub("_", " ", status))), '</strong>',
           '<p>', reason, '</p></div>')
  }
  paste0('<section id="', phase17_html_escape(section$id), '" data-section="', phase17_html_escape(section$id), '">',
         '<h2>', phase17_html_escape(section$label), '</h2>', state, '</section>')
}

phase17_render_filter_toolbar <- function() {
  paste0(
    '<form class="filters" aria-label="Dashboard filters">',
    '<label>League or group<select name="league_or_group"><option>All</option></select></label>',
    '<label>Team<select name="team"><option>All teams</option></select></label>',
    '<label>Matchday<select name="matchday"><option>All matchdays</option></select></label>',
    '<label>Fixture status<select name="fixture_status"><option>All</option></select></label>',
    '<button type="button" id="clear-filters">Clear filters</button>',
    '</form>'
  )
}

render_phase17_dashboard <- function(payload, route = NULL) {
  phase17_validate_payload(payload)
  metadata <- payload$metadata
  route <- route %||% unname(phase17_routes()[[payload$edition_id]])
  route <- phase17_html_escape(route)
  title <- if (identical(payload$edition_id, "uefa_nations_league_2026_27")) {
    "UEFA Nations League 2026/27 Forecast"
  } else {
    "EURO 2028 Qualifying Forecast"
  }
  state <- phase17_html_escape(metadata$lifecycle_state)
  warning_html <- if (length(metadata$warnings)) {
    paste0('<aside class="warning" role="status">', phase17_html_escape(metadata$warnings[[1L]]), '</aside>')
  } else ""
  nav <- paste(vapply(payload$sections, function(section) paste0(
    '<a href="#', phase17_html_escape(section$id), '">', phase17_html_escape(section$label), '</a>'
  ), character(1)), collapse = "")
  sections <- paste(vapply(payload$sections, phase17_render_section, character(1)), collapse = "")
  payload_json <- phase17_json_script_escape(rawToChar(phase17_payload_bytes(payload)))
  paste0(
    '<!doctype html><html lang="en"><head><meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width, initial-scale=1">',
    '<title>', phase17_html_escape(title), '</title><style>',
    'body{font:14px/1.5 Arial,Helvetica,sans-serif;background:#f7f6f2;color:#222;margin:0}',
    'main{max-width:1120px;margin:0 auto;padding:24px}.panel,section,.filters{background:#fff;border:1px solid #d8d8d8;padding:16px;margin:12px 0}',
    'nav{display:flex;gap:8px;flex-wrap:wrap}nav a{color:#3573a8;padding:8px}',
    '.filters{display:flex;gap:8px;flex-wrap:wrap}.filters label{font-weight:700;font-size:12px}.filters select{display:block;min-width:140px;min-height:32px}',
    'button{min-height:32px}.warning{border-left:3px solid #b23a2f;background:#fff;padding:12px}',
    '.section-status{border-left:3px solid #d29d2b;padding:8px;overflow-wrap:anywhere}',
    '@media(max-width:640px){main{padding:16px}.filters label,.filters select{width:100%}}',
    '</style></head><body><main data-route="', route, '">',
    '<header class="panel"><h1>', phase17_html_escape(title), '</h1>',
    '<p data-lifecycle="', state, '">', phase17_html_escape(tools::toTitleCase(gsub("_", " ", state))),
    ' · Forecast: ', phase17_html_escape(metadata$forecast_status), '</p>',
    '<p>Last accepted refresh: ', phase17_html_escape(metadata$last_refresh_at_utc),
    ' · Batch: ', phase17_html_escape(metadata$batch_id), '</p></header>', warning_html,
    '<nav aria-label="Dashboard sections">', nav, '</nav>', phase17_render_filter_toolbar(), sections,
    '<details><summary>Source, model, and refresh lineage</summary><p>',
    phase17_html_escape(paste("Source", metadata$source_bundle_id, "Model", metadata$model_release_id,
                              "Rules", metadata$ruleset_version, "Seed", metadata$simulation_seed)),
    '</p></details><details><summary>Data credits</summary><pre>',
    phase17_html_escape(phase17_canonical_json(payload$credits)), '</pre></details>',
    '<script id="phase17-payload" type="application/json">', payload_json, '</script>',
    '</main></body></html>'
  )
}

phase17_render_dashboard <- render_phase17_dashboard
