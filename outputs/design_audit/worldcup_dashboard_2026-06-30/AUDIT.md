# xGelo World Cup Dashboard Design Audit

Date: 2026-06-30
Target: `outputs/dashboard/worldcup_forecast.html` served locally at `http://127.0.0.1:8123/worldcup_forecast.html`
Viewports: 1280x720 desktop, 390x844 mobile
Destination: local folder

## Captured Steps

1. `01-restored-bracket-overview.png` - Returning dashboard state on Bracket. Health: mixed. The hero summary is strong, but the restored bracket state starts users in a wide, horizontally complex view.
2. `02-groups-overview.png` - Groups forecast table. Health: good with density risk. The information is useful and compact, but the columns, symbols, and heat cells need stronger legend support.
3. `03-matches-search-france.png` - Matches tab filtered to France. Health: good. Search works and match cards expose useful probabilities, scorelines, and expected goals.
4. `04-bracket-inspector.png` - Bracket forecast card opened. Health: strong but visually crowded. The inspector is rich, but it overlays the bracket and hero area and lacks an obvious close control.
5. `05-team-search-argentina.png` - Teams tab filtered to Argentina. Health: good. The left result list plus detail pane is efficient, though the search control relies on placeholder text.
6. `06-elo-search-argentina.png` - Elo Ratings filtered to Argentina. Health: good. The filtered chart is readable, but the persistent top content pushes the working area low in the viewport.
7. `07-mobile-groups.png` - Mobile groups view. Health: mixed. Cards and tabs reflow, but the group table overflows horizontally and the affordance is subtle.

## Strengths

- The dashboard has a clear analytical identity: title, model summary, generation metadata, caveat, simulation counts, and data credits are visible.
- The hero metrics give immediate executive-level takeaways before deeper tables.
- The Matches view is one of the clearest surfaces: the search filter, WDL bar, probability chips, expected goals, and scoreline bars create a fast read.
- The Bracket inspector adds valuable context by separating current result, pre-game forecast, advance probabilities, and exact scorelines.
- The Teams and Elo filtered states scale well for known-item lookup. Searching "Argentina" quickly narrows a large tournament field to one usable detail surface.

## UX Risks

- Step 1: A returning user can land directly in Bracket, which is the most spatially demanding tab. Without a short orientation or visible persisted-state cue, this may feel abrupt.
- Steps 1-6: The hero section stays large across all task tabs. On 720px tall desktop captures, users often see filters and only the top of the work surface; repeated analysis tasks may feel vertically cramped.
- Steps 1-6: Some hero copy is confusing. "Strongest qualified favorite" showing "South Africa (A)" with "0.0% group win" reads contradictory without extra context. "Locked group winners ... +9" and "12 at 100.0%" also require interpretation.
- Step 2: Group standings are dense and data-rich, but the check/x symbols and heatmap columns do not have an immediately visible legend in the captured viewport.
- Step 3: Filtered matches do not show an explicit result count or "filtered by France" label beyond the input value.
- Step 4: The bracket inspector covers surrounding content and uses "click outside" as its only visible close instruction. A close button would reduce hesitation and help keyboard and touch users.
- Step 4: The bracket itself is much wider than the viewport. The screenshot shows partial rounds and connector labels, but no persistent cue that horizontal scrolling is expected.
- Step 7: On mobile, tabs wrap and the group table horizontally scrolls. It remains usable, but the user has to discover the hidden columns manually.

## Accessibility Risks

- Inputs and select controls have no associated visible label, `aria-label`, or `aria-labelledby` in the DOM probe. Placeholder-only search labels are fragile for screen reader users and disappear when typing.
- The main nav buttons look like tabs, but they do not expose `role="tab"`, `aria-selected`, or `aria-controls`. Sighted users get the active state; assistive tech may not get the same structure.
- Group Forecast/Current toggles do not expose `aria-pressed` or an equivalent selected state.
- Bracket cards use `div role="button"` with `tabindex="0"`, which is a decent start, but keyboard activation and focus visibility still need live testing.
- Probability heatmaps rely partly on color intensity. Many cells include text, which helps, but contrast should be checked programmatically for the darkest and lightest heat states.
- Screenshot review cannot confirm screen reader reading order, keyboard tab sequence, high-contrast mode, zoom behavior, or whether custom controls handle Enter/Space correctly.

## Recommendations

1. Reduce the persistent hero height after the first tab interaction, or make a compact sticky summary variant for deep analysis tabs.
2. Rewrite ambiguous hero metrics so each card has a self-contained claim, for example "Completed group winners" and "Best remaining favorite" rather than mixing current state and group-win probability.
3. Add visible labels to filters and bind them with `<label for>`, or use `aria-label` where visual labels would be too heavy.
4. Give the tab row proper tab semantics, or make the controls visually and semantically plain navigation buttons with clear active state announcements.
5. Add `aria-pressed` or `aria-selected` state to Forecast/Current group toggles.
6. Add a visible close button to the bracket inspector and keep it anchored away from the hero summary where possible.
7. Add a small "scroll horizontally" cue for Bracket and mobile group tables, especially when content is clipped.
8. Add local legends for group symbols and heat columns near the table, not only through column headers.
9. Add result counts to filtered list views, such as "2 matches" or "1 team", so filtered states confirm what happened.
10. Run a follow-up keyboard and contrast pass against the live page before claiming WCAG compliance.

## Evidence Limits

This audit used screenshots captured in the current run plus a small DOM attribute probe saved as `accessibility-dom-probe.json`. It did not run a full keyboard walkthrough, screen reader test, color contrast scan, or mobile touch interaction test.
