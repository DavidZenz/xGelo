# Edition-neutral Phase 21 static renderer.

`%||%` <- function(left, right) if (is.null(left) || !length(left)) right else left

phase21_html_escape <- function(value) {
  value <- if (is.null(value) || !length(value) || length(value) != 1L || is.na(value[[1L]])) "" else as.character(value[[1L]])
  value <- gsub("&", "&amp;", value, fixed = TRUE)
  value <- gsub("<", "&lt;", value, fixed = TRUE)
  value <- gsub(">", "&gt;", value, fixed = TRUE)
  value <- gsub('"', "&quot;", value, fixed = TRUE)
  gsub("'", "&#39;", value, fixed = TRUE)
}

phase21_json_script_escape <- function(value) {
  value <- as.character(value %||% "")
  value <- gsub("&", "\\u0026", value, fixed = TRUE)
  value <- gsub("<", "\\u003c", value, fixed = TRUE)
  value <- gsub(">", "\\u003e", value, fixed = TRUE)
  gsub("</script", "<\\/script", value, fixed = TRUE)
}

phase21_display_scalar <- function(value) {
  if (is.null(value) || !length(value)) return("")
  if (is.list(value)) return(paste(vapply(value, phase21_display_scalar, character(1)), collapse = ", "))
  if (length(value) > 1L) return(phase21_html_escape(paste(as.character(value), collapse = ", ")))
  if (is.na(value[[1L]])) return("")
  phase21_html_escape(as.character(value[[1L]]))
}

phase21_status_label <- function(status) {
  status <- tolower(as.character(status %||% ""))
  labels <- phase21_status_labels()
  if (status %in% names(labels)) unname(labels[[status]]) else tools::toTitleCase(gsub("_", " ", status, fixed = TRUE))
}

phase21_renderer_row_fields <- function(rows) {
  fields <- unique(unlist(lapply(rows, names), use.names = FALSE))
  fields[nzchar(fields)]
}

phase21_render_table <- function(section) {
  rows <- section$rows %||% list()
  if (!length(rows)) return(sprintf('<div class="empty-state" data-status="%s" role="status">%s</div>', phase21_html_escape(section$status), phase21_html_escape(section$reason)))
  fields <- phase21_renderer_row_fields(rows)
  if (!length(fields)) return('<div class="empty-state" data-status="available">Available, but no scalar fields were supplied.</div>')
  header <- paste0("<th scope=\"col\">", vapply(fields, phase21_html_escape, character(1)), "</th>", collapse = "")
  body <- vapply(rows, function(row) {
    cells <- vapply(fields, function(field) paste0("<td>", phase21_display_scalar(row[[field]]), "</td>"), character(1))
    paste0("<tr>", paste(cells, collapse = ""), "</tr>")
  }, character(1))
  paste0('<div class="table-scroll"><table><thead><tr>', header, '</tr></thead><tbody>', paste(body, collapse = ""), '</tbody></table></div>')
}

phase21_render_metadata <- function(metadata) {
  preferred <- c("source_status", "freshness_status", "last_refresh_at_utc", "information_cutoff_utc",
                 "ruleset_version", "model_release_id", "feature_cutoff_utc", "simulation_seed",
                 "simulation_count", "projection_run_id", "authority_mode", "production_eligible",
                 "batch_id", "showing_last_accepted_snapshot")
  fields <- unique(c(preferred, names(metadata)))
  fields <- fields[fields %in% names(metadata)]
  rows <- vapply(fields, function(field) paste0("<dt>", phase21_html_escape(gsub("_", " ", tools::toTitleCase(field))), "</dt><dd>", phase21_display_scalar(metadata[[field]]), "</dd>"), character(1))
  paste0('<dl class="metadata-grid">', paste(rows, collapse = ""), "</dl>")
}

phase21_render_dashboard <- function(payload, route = NULL) {
  phase21_validate_payload(payload)
  route <- phase21_html_escape(route %||% "")
  title <- phase21_html_escape(payload$metadata$competition_display_name %||% payload$edition_id)
  status <- phase21_html_escape(phase21_status_label(payload$metadata$source_status %||% payload$metadata$lifecycle_state))
  nav <- vapply(payload$sections, function(section) paste0('<a href="#', phase21_html_escape(section$id), '">', phase21_html_escape(section$label), '</a>'), character(1))
  panels <- vapply(payload$sections, function(section) {
    section_status <- phase21_status_label(section$status)
    reason <- if (nzchar(as.character(section$reason %||% ""))) paste0('<p class="section-reason">', phase21_html_escape(section$reason), '</p>') else ""
    paste0('<section id="', phase21_html_escape(section$id), '" class="dashboard-section" data-status="', phase21_html_escape(section$status), '">',
           '<div class="section-heading"><h2>', phase21_html_escape(section$label), '</h2><span class="status-badge status-', phase21_html_escape(section$status), '" role="status">', phase21_html_escape(section_status), '</span></div>',
           reason, phase21_render_table(section), '</section>')
  }, character(1))
  json <- if (requireNamespace("jsonlite", quietly = TRUE)) jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null", na = "null", dataframe = "rows", digits = 16, pretty = FALSE) else "{}"
  json <- phase21_json_script_escape(json)
  paste0('<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">',
         '<title>', title, '</title><style>',
         ':root{color-scheme:light;--ink:#132238;--muted:#5b6b7f;--line:#d9e1ea;--surface:#f5f8fb;--accent:#173f7a}',
         '*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;font:16px/1.5 system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:var(--ink);background:var(--surface)}',
         '.shell{max-width:1440px;margin:auto;padding:24px}.hero{background:#fff;border:1px solid var(--line);border-radius:16px;padding:24px;margin-bottom:18px}.eyebrow{color:var(--muted);font-size:.8rem;letter-spacing:.08em;text-transform:uppercase}.hero h1{margin:.2rem 0 .5rem;font-size:clamp(1.7rem,4vw,2.6rem)}.status-badge{display:inline-flex;align-items:center;border-radius:999px;padding:.2rem .65rem;font-size:.8rem;font-weight:650;background:#e8eef7;color:var(--accent)}.status-blocked,.status-unavailable,.status-unresolved,.status-stale{background:#fff0e8;color:#8e3b16}.status-available{background:#e6f5eb;color:#1c6336}.status-pre_draw{background:#fff8d9;color:#775d00}',
         'nav{display:flex;gap:.5rem;overflow:auto;padding:4px 0 16px;scrollbar-width:thin}nav a{color:var(--accent);white-space:nowrap;text-decoration:none;border:1px solid var(--line);border-radius:999px;padding:.4rem .7rem;background:#fff}nav a:focus-visible,button:focus-visible,a:focus-visible{outline:3px solid #f2a900;outline-offset:2px}.metadata-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px;margin:18px 0 0}.metadata-grid dt{color:var(--muted);font-size:.78rem;text-transform:capitalize}.metadata-grid dd{margin:0;font-weight:600;overflow-wrap:anywhere}.dashboard-section{background:#fff;border:1px solid var(--line);border-radius:16px;padding:20px;margin:18px 0;scroll-margin-top:12px}.section-heading{display:flex;gap:12px;align-items:center;justify-content:space-between;flex-wrap:wrap}.section-heading h2{margin:0;font-size:1.25rem}.section-reason{color:var(--muted);margin:.7rem 0}.table-scroll{overflow-x:auto;margin-top:12px}table{border-collapse:collapse;width:100%;min-width:640px;font-size:.92rem}th,td{text-align:left;vertical-align:top;border-bottom:1px solid var(--line);padding:9px 10px}th{background:#f0f4f8;position:sticky;top:0}.empty-state{border:1px dashed var(--line);border-radius:10px;color:var(--muted);padding:14px;margin-top:12px}.credits{color:var(--muted);font-size:.9rem}.visually-hidden{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0}@media (max-width:700px){.shell{padding:12px}.hero,.dashboard-section{border-radius:12px;padding:16px}.metadata-grid{grid-template-columns:repeat(2,minmax(0,1fr))}}@media (prefers-reduced-motion:reduce){html{scroll-behavior:auto}}',
         '</style></head><body><main class="shell" data-route="', route, '"><header class="hero"><div class="eyebrow">xGelo competition dashboard</div><h1>', title, '</h1><span class="status-badge">', status, '</span>', phase21_render_metadata(payload$metadata), '<p class="credits">', phase21_html_escape(paste(unlist(payload$credits), collapse = " · ")), '</p></header><nav aria-label="Dashboard sections">', paste(nav, collapse = ""), '</nav>', paste(panels, collapse = ""), '<script type="application/json" id="dashboard-payload">', json, '</script></main></body></html>')
}

phase21_render_route_html <- phase21_render_dashboard
