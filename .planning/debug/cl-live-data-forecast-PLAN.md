# Champions League live data and forecast repair

Date: 2026-10-27

## Objective

Restore the current Champions League data and forecast path where supported by
real source evidence. Keep model validation and publication evidence inspectable.

## Plan

1. Reproduce the live provider request with the locally configured credential;
   report resource coverage without exposing credentials or persisting raw bytes.
2. Repair concrete acquisition defects revealed by that request and run focused
   regression tests. Prepare real club identity mappings when live coverage exists.
3. Trace accepted history, policy/fold review, evaluation, release staging and
   forecast consumption. Repair executable paths without substituting fixture data
   for production training or silently authorizing an untested model.
4. Verify changed paths, run the production checks, and record remaining external
   blockers with concrete evidence and the next action.

## Initial evidence

- The token is available to normal project R startup through local configuration;
  it is absent from the shell environment and from `--vanilla` R startup.
- R is installed at `/opt/homebrew/opt/r/bin/Rscript`, outside the current PATH.
- The saved live blocked record predates the configured credential and terms review.
- Production club identity registries contain zero rows; historical source pins
  and accepted history are absent; policy and fold reviews remain pending.
- The production evaluation controller hardcodes the fold status as blocked.
- Production release staging ends with an unconditional rejection.

## Verification

- Complete: real provider resource summary and diagnostic projection (36/144/36).
- Complete: full adapter suite, full existing release suite, nine new staging
  assertions, and nineteen bounded acceptance-controller assertions.
- Complete: changed source parsing and diff hygiene.
- Production check: model controller remains `no_accepted_club_history`; no
  approved club selector or accepted live bundle was created by this repair.
- Pending owner review: prepared club mappings and edition expectations. The live
  activation question is pending in chat; no approval has been inferred.
- Remaining production work: fresh provider acceptance generation, historical
  corpus and reviews, production evaluation/promotion implementation and genuine
  forecast release. Broader acceptance tests expose the pre-existing edited
  acceptance-generation review hash and are not reported as passing.
