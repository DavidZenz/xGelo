# Corrected CL model evaluation

The genuine production controller completed successfully on 5 November under
R4.6.2. It retained `club_venue_nb` in immutable release
`club-v2-626fedd0dd54b8309923855e`; it did not promote the Elo candidate.
Historical coverage remains16,277 results with all36 current clubs connected.
No folds, role assignments, candidate formulas, tuning domains, assessment
labels or promotion thresholds were changed.

## Defect and result

`phase19_production_select_view()` supplied numeric1 for three integrity flags
consumed by `isTRUE()`. That silently rejected every calibrated view. The fix
supplies logicalTRUE, preserving the gate policy. The new production execution
repeated the exact26 approved folds in two fresh R processes, reproduced their
canonical artifacts, independently checked the fold fits/predictions, and
repeated the final full-history refit before installing the release.

All26 Elo folds now select calibrated1X2. The venue incumbent selects that view
in24 folds; two folds retain their genuine statistical calibration veto.
This mechanical correction does not make the Elo model pass calibration.

The candidate passes23 of24 promotion gates. The failed fixed-bin calibration
error delta is **0.0261580183363702**, against the frozen maximum **0.01**.
Absolute/integrity gates allow retention of the venue incumbent. Production
dashboard forecasts remain explicitly disabled pending team-strength QA;
identical venue probabilities are not presented as team-specific predictions.

## Before/after proper scores

Numbers below are equal-fold means within each of the13-fold families. Lower
is better. These are the accepted assessment rows, not an additional selection
or tuning exercise.

| Family | Elo Brier before | Elo Brier after | Venue Brier after | Elo log loss before | Elo log loss after | Venue log loss after |
|---|---:|---:|---:|---:|---:|---:|
| Chronological |0.601941|0.603741|0.647586|1.008520|1.010473|1.070372|
| Held-out league |0.626713|0.630198|0.647904|1.042173|1.046828|1.070854|

| Family | Elo calibration error before | Elo calibration error after | Venue calibration error after |
|---|---:|---:|---:|
| Chronological |0.064388|0.056665|0.022613|
| Held-out league |0.040228|0.042098|0.023833|

Better Brier/log loss cannot override the failed calibration gate. Seeing these
assessments does not authorize changing the gate to promote the candidate.
All exact values and the controller result are in
`outputs/club_model/diagnostics/2026-11-05/before_after_production.json`.

## Evidence

- `outputs/club_model/production/controller_result.json`: ready, production,
  retained; evaluationSHA
  `72d5397b992692b0ab86b679d93044d0d6bca318d2998420f4fe73b06d7e4d91`.
- `outputs/club_model/production/fold_metrics.csv`:26 exact-fold rows.
- `outputs/club_model/production/promotion_gates.csv`:23 passed, one failed.
- `outputs/releases/club/approved_release.csv`: atomic approved selector.
- New release manifestSHA:
  `41775f27aa1399e4004482f1f1be5d4a8681cd3c22bf5bbc4f6067695060c9e0`.
- Independent Python read-back matched the byte count and SHA256 of all seven
  release artifacts. A separate cold production R resolver completed with
  exit0 and returned the exact selected release and club domain. Direct RDS
  inspection confirmed26 calibrated Elo folds and24 calibrated/two raw venue
  folds.
- All34 protected WC/national/unrelated artifact hashes still match the
  pre-repair baseline.

The local factual CL page was inspected at1440px and390px:72 completed results,
72 future fixtures, zero forecast rows, no page-width overflow on mobile. The
standalone preview cannot prove cross-competition navigation; that remains for
the final three-route staged and published batch. Public CL remains404 until
the separate validated deployment completes.
