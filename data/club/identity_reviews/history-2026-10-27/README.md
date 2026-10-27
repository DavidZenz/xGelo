# Proposed club historical training and model policy review

Prepared 2026-10-27T12:37:29Z. Acceptance remains pending.

- 432 pinned source snapshots; 16277 selected regulation results; 119680 other source rows, including repeated snapshots.
- 407 proposed name mappings; 343 canonical clubs.
- Current roster: 36/36 clubs have played history; 36/36 share one historical component.

The source inventory binds full Git commits, original repository paths, raw bytes and pinned CC0 license evidence.
Each final regulation result is retained once, from the earliest successfully parsed retained snapshot containing that same canonical fixture and final score.
Later result or date corrections use their own later first-observed evidence; publication is never backdated.
The scope inventory binds the exact selected rows: domestic league stages and UCL group/league stages only.
Missing results, awarded matches and knockout stages remain in the exclusion reports and never become training results.
Incomplete season files contribute only their explicitly counted played subset; they are not represented as complete seasons.
Date-only results become usable no earlier than the next UTC day and the pinned commit timestamp.

Identity approval covers the exact proposed mappings and the stated 2021-01-01 to 2027-07-01 validity interval.
Existing current club IDs are preserved; compatible canonical validity intervals extend to cover approved history.

The frozen model policy compares club Elo plus negative-binomial goals against the venue-only negative-binomial incumbent.
Calibration fitting, primary-view selection and outer assessment use separate chronological rows.
Promotion requires all predeclared proper-score, breadth, uncertainty, coverage and integrity gates.
The venue incumbent can be retained only when all absolute coverage and integrity gates pass.
All 36 current clubs must have connected history before any forecasts are enabled.
This review authorizes the source/mapping/policy inputs. Exact derived folds require their existing separate owner review before production fitting.

Inspect source_coverage_summary.csv, current_club_history_coverage.csv and proposed_historical_club_identities.csv first.
The exact acceptance payloads are proposed_history_sources.csv, proposed_history_scopes.csv and proposed_history_owner_review.csv.
Frozen model inputs are data/club/model_protocol/{candidate,gate,seed}_registry.csv and data/club/production_protocol/production_recipe_v2.json.
