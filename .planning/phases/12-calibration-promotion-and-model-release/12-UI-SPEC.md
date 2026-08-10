---
phase: 12
slug: calibration-promotion-and-model-release
status: approved
shadcn_initialized: false
preset: none
created: 2026-08-10
reviewed_at: 2026-08-10T18:30:23Z
---

# Phase 12 — UI Design Contract

> Visual and interaction contract for the approved-release dashboard and export consumers.
> This phase changes model resolution and release messaging; it does not redesign the
> existing World Cup forecast dashboard.

## Design System

| Property | Value |
|----------|-------|
| Tool | none — existing R-generated static HTML/CSS/vanilla JavaScript |
| Preset | not applicable |
| Component library | none; preserve existing semantic HTML and CSS classes |
| Icon library | none; retain existing inline SVG bracket links and text/emoji flags |
| Font | Arial, Helvetica, sans-serif |

`components.json`, Tailwind, and React/Next/Vite surfaces are absent. Do not initialize
shadcn, add a component library, or add a frontend dependency. The R `targets` pipeline
remains the orchestration boundary and the generated HTML remains the presentation artifact.

## Spacing Scale

Declared values (new Phase 12 UI must use these 4px-multiple tokens):

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Status icon-to-label gap, inline metadata spacing |
| sm | 8px | Chips, compact controls, status content padding |
| md | 16px | Default card/panel spacing and control groups |
| lg | 24px | Header and section padding |
| xl | 32px | Major layout gaps and release-detail separation |
| 2xl | 48px | Major section breaks |
| 3xl | 64px | Page-level spacing only when a report section needs it |

Exceptions: none. New release-status, provenance, loading, and error UI must use the
declared scale.

## Typography

| Role | Size | Weight | Line Height |
|------|------|--------|-------------|
| Body | 14px | 400 | 1.4 |
| Label | 12px | 700 | 1.25 |
| Heading | 16px | 700 | 1.2 |
| Display | 30px | 700 | 1.05 |

Use tabular numerals for percentages, scores, dates, hashes, and IDs. Use only regular
400 and bold 700 for new Phase 12 content; existing heavier numeric emphasis is normalized
to the same visual bold tier when touched. Long explanatory copy wraps at the existing
980px content width.

## Color

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | `#f7f6f2` | Page background and report canvas |
| Secondary (30%) | `#ffffff` | Header, cards, tables, panels, inspector, controls |
| Accent (10%) | `#3573a8` | Approved/active release marker, primary action, active tab, selected forecast path, probability bars |
| Destructive | `#b42318` | Validation failure and blocked-release message only |

Accent reserved for: the approved release status marker, the `Open approved release`
action, the active tab/control state, the primary probability view marker, and existing
forecast bars/selected bracket path. Do not use accent as a blanket color for every link
or data value. Preserve existing semantic colors: `#d29d2b` for draw/attention and
`#3b8754` for away-win/positive route emphasis; neither color means release approval.
Every status also includes visible text and an accessible label, never color alone.

## Copywriting Contract

| Element | Copy |
|---------|------|
| Primary CTA | `Open approved release` |
| Empty state heading | `No approved release available` |
| Empty state body | `Dashboard and export views need an approved release manifest and matching model contract. Publish a versioned release, then reload this page.` |
| Error state | `Release validation failed. The model, contract, or manifest hash does not match the approved release. No forecast was loaded; repair the release bundle and rerun the dashboard/export.` |
| Destructive confirmation | None. Consumers are read-only; never offer a bypass, delete, overwrite, or “use raw model path” confirmation. |
| Loading state | `Validating approved release…` |
| Partial state | `Verified data only. Some report or forecast artifacts are unavailable.` |
| Approved status | `Approved release` |
| Fallback status | `incumbent retained` |

Use `Not available` for a missing value in a valid partial view, never a blank cell that
could be mistaken for zero. Keep the exact machine-facing fallback status `incumbent
retained` in the visible release summary and export metadata.

## Release and Consumer Contract

### Resolution and fail-closed behavior

- Dashboard and export code resolve exactly one approved, versioned release root through
  the release manifest and model contract. They must not select a raw `.rds` path by
  existence, modification time, “latest” naming, or a baseline/hybrid shortcut.
- Validate status, trusted-root-relative paths, candidate/track identity, `G = 40`, model
  hash, contract hash, freeze/final manifest hashes, and required artifact presence before
  forecast generation or export. A mismatch stops the consumer before any forecast card,
  CSV row, or JSON payload is emitted.
- `approved` and `incumbent retained` are both usable release statuses. The latter keeps
  the incumbent as the primary model and exposes challenger results and gate failures only
  in the audit/report view; alternatives never appear as default forecasts.
- Never expose the WC2026 label artifact in the dashboard, normal exports, or client-side
  payload. It remains a scoring/reporting-only artifact.

### Visible release summary

Place a compact release-status panel directly below the existing dashboard metadata and
above the hero metrics. It uses a white surface, 3px left border, 16px internal spacing,
and the existing blue/neutral visual language.

The populated panel must show, as text (not only in a tooltip):

- `Approved release` or exact `incumbent retained` status;
- release version/ID, candidate ID, and track ID;
- primary probability view: `calibrated 1X2` or `raw 1X2`;
- generated timestamp and feature cutoff;
- a shortened model-contract SHA-256 for scanning, with the full hash and trusted release
  root available in a `Release provenance` `<details>` section;
- the `Open approved release` link/button to the versioned benchmark report/model card.

If calibrated output passes D-04, label the primary view `Primary probabilities: calibrated
1X2`. Otherwise label it `Primary probabilities: raw 1X2` and state `Calibration not
promoted; raw probabilities retained.` Preserve the fitted score distribution and label
it `Scoreline distribution: fitted goal model` so match cards, bracket routes, and exports
do not imply that full score distributions were calibrated.

### Forecast, report, and export views

- Preserve the existing top-level tabs and labels: `Groups`, `Matches`, `Bracket`,
  `Teams`, and `Elo Ratings`. Add release identity to the header/metadata, not as a
  competing navigation system.
- Keep current group forecast/current toggles, match search/filter, decided-match divider,
  bracket inspector, team search, and Elo picker. The same approved release identity must
  be used by every view.
- Match cards display the primary 1X2 label once at the section or release-summary level;
  the probability bar and chips must use that same view. Completed matches remain visibly
  `Final`/tournament state, not forecasts.
- The benchmark report is a linked audit surface. It must show raw-versus-calibrated
  comparison, calibration/regression veto evidence, promotion decision, and limitations;
  it must not present audit-only challengers as the selected production forecast.
- JSON payload metadata must include `release_version`, `release_status`, `candidate_id`,
  `track_id`, `primary_probability_view`, `model_contract_sha256`, `release_manifest_sha256`,
  and `generated_at`. CSV exports must carry the same release identity in their metadata
  fields or an adjacent versioned release manifest; no export may contain only a free-form
  `model_version`.

### Interaction and accessibility

- Keep semantic buttons for tabs, toggles, and filters. Preserve visible keyboard focus;
  new release controls use a 2px `#1d1d1f` outline with 2px offset and a minimum 44px
  interactive height where a new control is introduced.
- The release status uses `role="status"` for approved/retained states and `role="alert"`
  for validation failures. Loading and partial messages use `aria-live="polite"`.
- Do not rely on hover-only information. Existing bracket click, Enter/Space activation,
  focus route highlighting, and outside-click dismissal remain available by keyboard and
  pointer. Full hashes and long paths are available in text/details, not only a tooltip.
- Keep external report/data-credit links `target="_blank" rel="noopener"` as in the
  current dashboard.

## UI Considerations

Applicable state considerations resolved: 7 covered, 1 backstop, 0 unresolved.

| Category | Element(s) | Status | Resolution / Reason |
|----------|------------|--------|---------------------|
| empty | release summary, report link, match/team/list collections | ✅ covered | Render the documented `No approved release available` heading/body; do not render forecast cards, exports, or stale raw-model data. |
| loading | release validator, dashboard shell | ✅ covered | Show `Validating approved release…` in the reserved status area with `aria-live="polite"`; do not show unvalidated probabilities while validation is in flight. |
| error | release validator, report/export consumer | ✅ covered | Render the documented validation-failure copy with `role="alert"`, retain the page shell, and fail closed with no forecast payload. |
| populated | release summary, hero, Groups, Matches, Bracket, Teams, Elo Ratings, report link | ✅ covered | Show the approved/retained status, one consistent primary probability view, current dashboard interactions, and provenance details. |
| partial | report artifacts, filtered lists, incomplete forecast rows | ✅ covered | Show `Verified data only`; render verified rows/sections, mark unavailable values `Not available`, and disable only the affected report/export action. A partial or mismatched release contract remains a hard error. |
| overflow | tables, bracket, metadata/hash/path content, narrow screens | ✅ covered | Preserve horizontal scrolling for group/Elo tables and the bracket; wrap controls; ellipsize only compact identifiers with full values in details; prevent viewport-wide clipping. |
| zero-one-many | search results, completed matches, title chances, selected Elo teams | ✅ covered | Use singular/plural copy (`1 matching team`/`N matching teams`, `1 match`/`N matches`), keep zero-result containers visible with the empty copy, and preserve the existing one-to-many card/table layout. |
| long-text | release IDs, candidate/track IDs, hashes, report limitations, team names | 🧪 backstop | A regression fixture with long IDs/copy must confirm wrapping or ellipsis stays inside the panel, full values remain readable in provenance details, and no table/card causes page-level horizontal overflow. |

## Regression-Testable Visual Behavior

Extend the existing `test_worldcup_dashboard.R` HTML/string regression style and add the
Phase 12 release-consumer tests described in `12-RESEARCH.md`:

- Approved fixtures render the release status, version, candidate/track, primary view,
  provenance details, and `Open approved release` copy in the generated HTML.
- A valid `incumbent retained` fixture remains usable, shows the exact status, and keeps
  challengers audit-only; the dashboard/export output uses the incumbent release identity.
- Missing manifest, non-approved status, missing artifact, model hash mismatch, contract
  hash mismatch, wrong candidate, wrong `G`, stale/ambiguous release root, or path escape
  fails before forecast generation and emits the documented error copy.
- Raw and calibrated exports use identical fixture IDs and expose one explicit primary view;
  no dashboard/report/export consumer silently mixes calibrated 1X2 with raw 1X2.
- HTML regressions assert status text, `role="status"`/`role="alert"`, `aria-live`, focusable
  controls, `rel="noopener"`, and preserved tab/search/bracket hooks. Add state fixtures for
  loading, empty, partial, long text, zero results, and horizontal overflow.
- Keep inherited dashboard and retrospective visual assertions green. This artifact does
  not modify production code or generated outputs.

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| none | none | not applicable — no shadcn or third-party registry |

## Checker Sign-Off

- [x] Dimension 1 Copywriting: PASS
- [x] Dimension 2 Visuals: PASS
- [x] Dimension 3 Color: PASS
- [x] Dimension 4 Typography: PASS
- [x] Dimension 5 Spacing: PASS
- [x] Dimension 6 Registry Safety: PASS

**Approval:** approved 2026-08-10
