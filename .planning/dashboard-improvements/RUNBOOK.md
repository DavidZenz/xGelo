# Active dashboard release and recovery

## Scope and prerequisites

Only Nations League and EURO qualifying are part of this change. Do not edit
`docs/wc2026` or migrate the publication to Phase 21. The live incumbent remains
in place until all candidate gates pass. Source payloads, football rules, model
release authority, publication inventory and size limits are unchanged.

Use a working R installation (`/opt/homebrew/opt/r/bin/Rscript` on this host),
the accepted source raw evidence and approved immutable model assets. A fresh
checkout may omit ignored local evidence; restore exact hash-matching existing
assets rather than fabricating or accepting replacement evidence.

## Scale certification

Run these separately in fresh processes from the repository, with a persistent
cache/evidence directory outside the public document root:

```sh
rtk proxy /opt/homebrew/opt/r/bin/Rscript --vanilla scripts/benchmark_nations_league_scale.R . 1000 /private/tmp/nl-scale-certification 4
rtk proxy /opt/homebrew/opt/r/bin/Rscript --vanilla scripts/benchmark_nations_league_scale.R . 10000 /private/tmp/nl-scale-certification 4
rtk proxy /opt/homebrew/opt/r/bin/Rscript --vanilla scripts/benchmark_nations_league_scale.R . 100000 /private/tmp/nl-scale-certification 4
```

Each run validates a candidate and writes compact measurement/artifact CSVs,
without publishing outcomes or dashboards. Do not call an extrapolation a pass.
The benchmark revalidates accepted inputs and binds its expensive forecast cache
to those inputs and implementation hashes. A successful 100,000 measurement
includes the simulator hash, seed, worker count, accepted lineage and validation
result. Supply that file through `XGELO_NL_SCALE_EVIDENCE` to the updater.

The measured 1,000-run simulation took 819.192 seconds plus 31.088 seconds of
candidate validation; 100,000 is estimated near 23 hours, with unverified peak
process memory. See SCALE.md. Full-scale certification is outstanding.

## Candidate acceptance

- Use `--dry-run` for a read-only source probe. Use `--force-rebuild` for an
  explicit rebuild when accepted source contents have not changed.
- Use the existing coordinator to render a staged two-route batch, run all
  source/model/rules/probability checks, validate the envelope and test the real
  staged HTML. Never edit generated public HTML directly.
- Run the registered regression gate without test-description filters. Every
  required suite must execute assertions and contain no failures or errors.
- The browser gate must verify actual 1440x900 and 390x844 viewport dimensions,
  filter/reset/tab/hash behavior, team selection persistence, keyboard navigation,
  labels and page reflow. A desktop-sized screenshot is not mobile evidence.
- Keep byte-identical embedded payloads for presentation-only releases and verify
  the World Cup inventory against baseline-worldcup.json.

## Failure handling

On a failed browser, benchmark, regression, manifest, hash, inventory, size or
read-back check, keep the incumbent public batch and report the concrete failure.
Do not lower the simulation count, inject a successful browser result, remove a
gate, or publish a subset of the two-route batch to make the release pass.

The updater lock lives at `.nations-league-update.lock` with its owner's PID.
Normal exits release it. If it remains after a crash, confirm the owning process
is no longer running before removing it; never remove another active run's lock.

Retain the previous complete publication batch/commit. Roll back both active
routes, their route manifests/current pointers and the batch envelope together.
The existing publisher restores the incumbent if promotion/read-back fails.

## Current acceptance state

Source changes and unit/compatibility tests are available. The HTML candidate is
staged separately from the live publication. The 10,000/100,000 scale checks and
full desktop/mobile release acceptance are not implied by unit test results;
consult SUMMARY.md for the final evidence and blockers from this implementation.
