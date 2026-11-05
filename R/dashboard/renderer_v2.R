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
    time_field <- intersect(c("Kickoff (UTC)", "kickoff_utc", "scheduled_at_utc"), names(row))
    instant <- if (length(time_field)) phase21_safe_scalar(row[[time_field[[1L]]]]) else ""
    paste0("<tr", if (nzchar(instant)) paste0(' data-kickoff-utc="', phase21_html_escape(instant), '"') else "", ">", paste(cells, collapse = ""), "</tr>")
  }, character(1))
  paste0('<div class="table-scroll"><table><thead><tr>', header, '</tr></thead><tbody>', paste(body, collapse = ""), '</tbody></table></div>')
}

phase21_render_metadata <- function(metadata) {
  preferred <- c("source_status", "freshness_status", "source_as_of_utc", "last_refresh_at_utc", "generated_at_utc", "forecast_status",
                 "forecast_model_quality", "model_release_id", "simulation_count")
  populated <- function(field) length(metadata[[field]]) &&
    any(!is.na(metadata[[field]]) & nzchar(as.character(metadata[[field]])))
  fields <- names(metadata)[vapply(names(metadata), populated, logical(1))]
  rows <- function(selected) vapply(selected, function(field) paste0("<div><dt>",
    phase21_html_escape(gsub("_", " ", tools::toTitleCase(field))), '</dt><dd data-metadata-field="', phase21_html_escape(field), '">',
    phase21_display_scalar(metadata[[field]]), "</dd></div>"), character(1))
  primary <- intersect(preferred, fields)
  details <- setdiff(fields, c(primary, "warnings", "competition_display_name"))
  warnings <- as.character(metadata$warnings %||% character())
  warnings <- warnings[!is.na(warnings) & nzchar(warnings)]
  paste0('<dl class="metadata-grid">', paste(rows(primary), collapse = ""), '</dl>',
    if (length(warnings)) paste0('<p class="section-reason">', phase21_html_escape(paste(warnings, collapse = " ")), '</p>') else "",
    if (length(details)) paste0('<details class="source-details"><summary>Source and model details</summary><dl class="metadata-grid">',
      paste(rows(details), collapse = ""), '</dl></details>') else "")
}

phase21_competition_navigation <- function(edition_id, registry = phase21_default_edition_registry()) {
  rows <- phase21_enabled_registry(registry)
  links <- vapply(seq_len(nrow(rows)), function(i) paste0('<a href="../',
    phase21_html_escape(rows$route_slug[[i]]), '/"',
    if (identical(rows$edition_id[[i]], edition_id)) ' aria-current="page"' else "", '>',
    phase21_html_escape(rows$display_name[[i]]), '</a>'), character(1))
  paste0('<nav class="competition-navigation" aria-label="Competitions">', paste(links, collapse = ""), '</nav>')
}

# Static publication must not keep claiming freshness or future kickoff after a
# failed later refresh. Browser-time status changes never infer match outcomes.
phase21_freshness_script <- function(metadata) {
  config <- list(lastRefresh = phase21_safe_scalar(metadata$last_refresh_at_utc),
    threshold = as.numeric(metadata$freshness_threshold_seconds %||% (48 * 3600)),
    preDraw = identical(phase21_safe_scalar(metadata$lifecycle_state), "pre_draw"))
  encoded <- phase21_json_script_escape(jsonlite::toJSON(config, auto_unbox = TRUE, null = "null"))
  paste0('<script>(function(){"use strict";const c=', encoded, ';function refresh(){const now=Date.now(),t=Date.parse(c.lastRefresh);',
    'const stale=!c.preDraw&&(!Number.isFinite(t)||now-t>c.threshold*1000||t-now>3600000);',
    'document.querySelectorAll("[data-metadata-field=freshness_status]").forEach(x=>{x.textContent=c.preDraw?"Pre-draw readiness gate":stale?"Stale — refresh required":"Fresh"});',
    'const notice=document.getElementById("current-freshness-notice");if(notice){notice.hidden=!stale;notice.textContent="This data snapshot is stale. Source last checked: "+c.lastRefresh+". Refresh is required before relying on predictions."}',
    'if(stale){["match_forecasts","projected_outcomes","qualification_bands","progression_probabilities"].forEach(id=>{const s=document.getElementById(id);if(!s)return;const b=s.querySelector(".status-badge");if(b){b.textContent="Stale snapshot";b.className="status-badge status-stale"}})}',
    'let nlChanged=false;document.querySelectorAll("[data-nl-expirable=true]").forEach(card=>{const at=Date.parse(card.dataset.nlKickoffUtc);if(!Number.isFinite(at)||at>now)return;nlChanged=true;card.dataset.nlExpirable="false";card.dataset.nlFixtureState="result_pending";card.dataset.nlForecastAvailable="false";const label="Past kickoff — result confirmation pending";card.dataset.filterStatus=label;card.querySelectorAll("[data-nl-current-status]").forEach(x=>{x.textContent=label});const f=card.querySelector("[data-nl-forecast-display]");if(f)f.textContent="Pre-match forecast archived. Result confirmation pending."});',
    'if(nlChanged){const filter=document.getElementById("nl-status-filter");if(filter){const label="Past kickoff — result confirmation pending";if(![...filter.options].some(o=>o.value===label)){const o=document.createElement("option");o.value=label;o.textContent=label;filter.append(o)}filter.dispatchEvent(new Event("change",{bubbles:true}))}}',
    'const nlCards=[...document.querySelectorAll("#fixtures .nl-match-card[data-nl-fixture-state=scheduled]")],nlAvailable=nlCards.filter(x=>x.dataset.nlForecastAvailable==="true").length;document.querySelectorAll("[data-nl-forecast-count]").forEach(x=>{x.textContent=nlCards.length?nlAvailable+"/"+nlCards.length:"—";const note=x.parentElement.querySelector(".note");if(note)note.textContent="Available / future confirmed fixtures"});',
    '["fixtures","match_forecasts"].forEach(id=>{const s=document.getElementById(id);if(!s)return;const live=s.querySelector(":scope > .table-scroll > table > tbody"),past=live?[...live.querySelectorAll("tr[data-kickoff-utc]")].filter(r=>Date.parse(r.dataset.kickoffUtc)<=now):[];if(!past.length)return;',
    'let archive=s.querySelector("details.past-kickoff-archive");if(!archive){archive=document.createElement("details");archive.className="past-kickoff-archive";const title=document.createElement("summary");archive.append(title);const p=document.createElement("p");p.textContent="Past kickoff in this snapshot. These are archived rows; no completed score or result is inferred.";archive.append(p);const original=s.querySelector(".table-scroll>table"),table=document.createElement("table");if(original&&original.tHead)table.append(original.tHead.cloneNode(true));table.append(document.createElement("tbody"));const box=document.createElement("div");box.className="table-scroll";box.append(table);archive.append(box);s.append(archive)}',
    'past.forEach(r=>archive.querySelector("tbody").append(r));archive.querySelector("summary").textContent="Archived past-kickoff rows ("+archive.querySelectorAll("tbody tr").length+")";',
    'const b=s.querySelector(".status-badge");if(!live.querySelector("tr")){if(b){b.textContent="No upcoming rows";b.className="status-badge status-unavailable"}if(id==="match_forecasts")document.querySelectorAll("[data-metadata-field=forecast_status]").forEach(x=>{x.textContent="No upcoming forecasts in this snapshot"})}})}refresh();setInterval(refresh,60000)})();</script>')
}

phase21_decorate_legacy_html <- function(html, metadata, registry = phase21_default_edition_registry()) {
  navigation <- phase21_competition_navigation(phase21_safe_scalar(metadata$edition_id), registry)
  source_as_of <- phase21_safe_scalar(metadata$source_as_of_utc, phase21_safe_scalar(metadata$accepted_data_cutoff_utc, phase21_safe_scalar(metadata$last_refresh_at_utc)))
  banner <- paste0('<div class="non-wc-freshness" style="max-width:1440px;margin:12px auto;padding:12px 24px">', navigation,
    '<p>Source as of: ', phase21_html_escape(source_as_of), ' · Last checked: ', phase21_html_escape(metadata$last_refresh_at_utc),
    ' · Page generated: ', phase21_html_escape(metadata$generated_at_utc), ' (UTC)</p>',
    '<p>Freshness: <strong data-metadata-field="freshness_status">', phase21_html_escape(metadata$freshness_status %||% "unknown"), '</strong></p>',
    '<p id="current-freshness-notice" role="status" hidden></p></div>')
  html <- sub('<body>', paste0('<body>', banner), html, fixed = TRUE)
  sub('</body>', paste0(phase21_freshness_script(metadata), '</body>'), html, fixed = TRUE)
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
           reason, if (!length(section$rows) && nzchar(section$reason %||% "")) "" else phase21_render_table(section), '</section>')
  }, character(1))
  json <- if (requireNamespace("jsonlite", quietly = TRUE)) jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null", na = "null", dataframe = "rows", digits = 16, pretty = FALSE) else "{}"
  json <- phase21_json_script_escape(json)
  paste0('<!doctype html><html lang="en"><head><meta charset="utf-8"><link rel="icon" href="data:,"><meta name="viewport" content="width=device-width, initial-scale=1">',
         '<title>', title, '</title><style>',
         ':root{color-scheme:light;--ink:#132238;--muted:#5b6b7f;--line:#d9e1ea;--surface:#f5f8fb;--accent:#173f7a}',
         '*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;font:16px/1.5 system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:var(--ink);background:var(--surface)}',
         '.shell{max-width:1440px;margin:auto;padding:24px}.hero{background:#fff;border:1px solid var(--line);border-radius:16px;padding:24px;margin-bottom:18px}.eyebrow{color:var(--muted);font-size:.8rem;letter-spacing:.08em;text-transform:uppercase}.hero h1{margin:.2rem 0 .5rem;font-size:clamp(1.7rem,4vw,2.6rem)}.status-badge{display:inline-flex;align-items:center;border-radius:999px;padding:.2rem .65rem;font-size:.8rem;font-weight:650;background:#e8eef7;color:var(--accent)}.status-blocked,.status-unavailable,.status-unresolved,.status-stale{background:#fff0e8;color:#8e3b16}.status-available{background:#e6f5eb;color:#1c6336}.status-pre_draw{background:#fff8d9;color:#775d00}',
         'nav{display:flex;gap:.5rem;overflow:auto;padding:4px 0 16px;scrollbar-width:thin}nav a{color:var(--accent);white-space:nowrap;text-decoration:none;border:1px solid var(--line);border-radius:999px;padding:.4rem .7rem;background:#fff}nav a:focus-visible,button:focus-visible,a:focus-visible{outline:3px solid #f2a900;outline-offset:2px}.metadata-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px;margin:18px 0 0}.metadata-grid dt{color:var(--muted);font-size:.78rem;text-transform:capitalize}.metadata-grid dd{margin:0;font-weight:600;overflow-wrap:anywhere}.dashboard-section{background:#fff;border:1px solid var(--line);border-radius:16px;padding:20px;margin:18px 0;scroll-margin-top:12px}.section-heading{display:flex;gap:12px;align-items:center;justify-content:space-between;flex-wrap:wrap}.section-heading h2{margin:0;font-size:1.25rem}.section-reason{color:var(--muted);margin:.7rem 0}.table-scroll{overflow-x:auto;margin-top:12px}table{border-collapse:collapse;width:100%;min-width:640px;font-size:.92rem}th,td{text-align:left;vertical-align:top;border-bottom:1px solid var(--line);padding:9px 10px}th{background:#f0f4f8;position:sticky;top:0}.empty-state{border:1px dashed var(--line);border-radius:10px;color:var(--muted);padding:14px;margin-top:12px}.credits{color:var(--muted);font-size:.9rem}.visually-hidden{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0}@media (max-width:700px){.shell{padding:12px}.hero,.dashboard-section{border-radius:12px;padding:16px}.metadata-grid{grid-template-columns:repeat(2,minmax(0,1fr))}}@media (prefers-reduced-motion:reduce){html{scroll-behavior:auto}}',
         '</style></head><body><main class="shell" data-route="', route, '">', phase21_competition_navigation(payload$edition_id), '<header class="hero"><div class="eyebrow">xGelo competition dashboard</div><h1>', title, '</h1><span class="status-badge">', status, '</span>', phase21_render_metadata(payload$metadata), '<p id="current-freshness-notice" role="status" hidden></p><p class="credits">', phase21_html_escape(paste(unlist(payload$credits), collapse = " · ")), '</p></header><nav aria-label="Dashboard sections">', paste(nav, collapse = ""), '</nav>', paste(panels, collapse = ""), '<script type="application/json" id="dashboard-payload">', json, '</script>', phase21_freshness_script(payload$metadata), '</main></body></html>')
}

phase21_render_route_html <- phase21_render_dashboard
