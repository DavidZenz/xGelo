# Non-WC refresh simulation evidence — 5 November 2026

Run: `20261105T192030Z-054ac634`. **The simulation completed; the overall controller failed at `dashboard_stage`.** The Nations League outcomes stage exited successfully and wrote its candidate inside the private workspace. No successful public deployment is established by this evidence. The private candidate was lost during failure cleanup; these summary files do not replace its full accepted artifact bundle. A successful end-to-end refresh remains required.

## Measured simulation precision and runtime

| Iterations | Workers | Elapsed seconds | Minutes | Numeric events resolved / unavailable | Worst 95% pointwise Wilson half-width | Precision status |
|---:|---:|---:|---:|---:|---:|---|
| 1,000 | 4 | 296.772 | 4.9462 | 966 / 0 | 3.0930 percentage points | Preview only |
| 10,000 | 4 | 2629.273 | 43.8212 | 966 / 0 | 0.9798 percentage points | Production sampling precision |

The counts share the same genuine refreshed input/handoff capture and seed 15017. The selected 10,000 simulation was reused for the private candidate write. The outcomes controller stage, including handoff preparation, both simulation counts and candidate writing/validation, took 3433.799 seconds (57.23 minutes). The simulation timings above isolate the two simulation calls.

The fixed policy requires a maximum 95% **pointwise** Monte Carlo half-width of one percentage point: minimum 9,600 iterations, recommended/default 10,000. These Wilson intervals quantify simulation sampling error for an individual event. They exclude model uncertainty and provide no simultaneous coverage guarantee across every displayed event.

## Observed nested sample changes

Across the same 966 events, the 1,000-to-10,000 absolute change was at most **3.92 percentage points**, with mean **0.4121 points** and 95th percentile **1.7975 points**. These are descriptive fixed-seed sample differences, not model-error bounds or simultaneous convergence guarantees.

All recorded probability audits passed at both counts: bounds, each team's rank mass, each group-position mass, expected knockout participant mass (8 quarter-finalists, 4 semi-finalists, 2 third-place participants, 2 finalists, 1 champion), and nested advancement probabilities. `independent_validation.json` additionally recalculates every counted-event probability, all 1,932 Wilson interval rows, probability masses and the convergence summary directly from the copied CSV files.

## Lineage and files

- Refreshed source cutoff: `2026-11-05T19:20:39Z`.
- Source bundle: `nl-2026-27-official-uefa-v2`.
- Source SHA-256: `6cdb25a02864aea7e342cc7d05f565fcc3942d8d4c01b31cb2be396183c62bfd`.
- Installed canonical state manifest in the private workspace: `5a2a888a547ff15ef1e0383fe1cd2a655cbfd3c67b60c1aab9484e99b7538f21`.
- Frozen simulation input SHA-256: `7f18e52cae03db58bc8f76a023ad0fe2bde717b4c01172f912e0df3b10a4580e`.
- Approved model: `phase14-open-nb-incumbent-calibrated-v1`; R 4.6.2.

`input_manifest.json` and `benchmark_report.json` are unaltered copies. The four `event_probabilities_*.csv` and `event_intervals_*.csv` files preserve every numeric event and its interval at each count. `evidence_manifest.json` binds the copied bytes to their original log paths and SHA-256 values. `controller_status.json` preserves the terminal failure context. The manifests describe the run's refreshed private parents; they do not assert that those parents were promoted into the public dashboard.
