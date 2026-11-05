# Proposed conditional Champions League tournament forecast policy v1

**Decision pending. No production authority is granted by this package or its tests.**

This is one review package for the score sampler, dynamic future matchups,
neutral final, extra time, penalties, bracket prior, known preseason
coefficients and unmodelled disciplinary ordering. It does not change the
accepted historical corpus, model folds, frozen evaluation thresholds, model
release, source terms, existing rules evidence, or official draw approval.

The current real release `club-v2-626fedd0dd54b8309923855e` retains the venue
baseline. The Elo candidate fails the fixed calibration gate
(0.0261580183 > 0.01). This policy cannot enable tournaments under that release.
The production factory requires an independently validated, approved club Elo/NB
release, complete connected history for all36 clubs, fresh accepted current data,
strict time boundaries and this exact owner-approved package.

## Factual evidence and time boundaries

The existing accepted 2026/27 Articles17–22 continue to define the factual rules.
The genuine same-edition AnnexB bracket and AnnexC calendar images are pinned
in `evidence/`; `source_manifest.json` records exact observed official resources.
Dates are earliest calendar-day bounds at00:00UTC, never invented kickoff times
or stadiums. Current information and feature cutoffs may be equal, but both
must be strictly before the relevant fixture or potential slot. A slot that has
started cannot be forecast through this pre-round contract.

Preseason club coefficients use 2021/22–2025/26, as established by AnnexD.2.
Nine manually observed official historical-page JSON responses contain415unique
clubs, all with baseSeasonYear2022/targetSeasonYear2026 and last update
2026-07-03T14:22:35Z. The proposed36club UEFA identity crosswalk preserves the
already approved internal club IDs and association identities.35 match exact
UEFA records. Como79946 is a documented first European entrant: zero historical
club points and the official Italian20% association floor19.989 underD.4.
The five seasonal totals reconcile each official club total; effective
coefficients equal max(club total, association floor). All36 effective values
are distinct. A changed roster with equal values requires genuine AnnexD.8
ordering and fails closed until supplied.

The fixed source remains factual. Future sampled league scores enter a distinct
counterfactual final-standings calculation. That calculation derives all score
criteria, including opponent points, goal difference and goals, from the full
accepted opponent graph and sampled scores. It leaves the current factual table,
72 known results and source bytes unchanged. Its rows explicitly have
`observed_source_eligible=FALSE` and `training_eligible=FALSE`. No future sampled
result is backdated, added to training, or published as an observed result.

## Assumptions requiring this single owner decision

1. **Joint score view.** For a released raw NB score mass r(s), outcome class
   o(s), and the selected approved1X2 probability q(o), tournament-only mass is
   j(s)=q(o(s))*r(s)/sum[r(t):o(t)=o(s)]. This is exactly outcome-first selection
   followed by raw NB scores conditional on that outcome. Exact summed1X2 and
   conditional-score equivalence must each pass1e-12 QA. The released raw grid
   and its expected-goals, totals, BTTS and other non1X2 claims remain separate.
   Packed integer32/float64 big-endian cell bytes have a named canonical-v2
   envelope and independent raw/joint hashes.

2. **Dynamic team identities and ratings.** Each knockout query binds its actual
   simulated participants, round, leg, source, cutoff, release, calibrator,
   rating state and slot evidence. Only the frozen approved club-only model is
   used. Ratings decay from the accepted historical state to the potential slot;
   simulated match scores do not update Elo. This is an unconditional matchup
   projection from current knowledge, not a new fitted model or future data feed.

3. **Neutral final.** Remove the Elo home adjustment and centre the frozen venue
   coefficient on the log link for both clubs. Means are
   exp(intercept+venue/2 ± elo_coefficient*(ratingA-ratingB)). This explicit
   intervention has club-swap symmetry. It does not establish separately tested
   neutral-final calibration.

4. **Extra time and penalties.** Independent NB-process increments scale both
   means and shape by1/3 for30minutes, retain the second-leg host context, and
   use raw ET1X2 rather than applying the90minute calibrator to ET. If still
   tied, choose the penalty winner with equal probability. No penalty tallies
   are fabricated. Two-leg resolution sums regulation goals, then second-leg
   extra time and penalties; away goals never break aggregate ties. The final
   is a single neutral match. These are explicit modelling assumptions beyond
   the factual rules about when ET and penalties occur.

5. **Unconditioned bracket prior.** Use the genuine AnnexB topology and Article19
   inherited seeding.12 independent fair pair-orientation bits select valid
   placements, with ranks1/2 on opposite final sides. This new scope is labelled
   `unconditioned_regulations_prior`. It is not an official draw probability law,
   observed draw, or claim that administrative restrictions are known. The
   existing official-draw-conditioned path retains its unresolved same-edition
   procedure gate. This package does not mark that missing evidence accepted.

6. **Unmodelled disciplinary ordering.** The match feed has no disciplinary
   totals, including already-played matches. Coefficients are known facts and
   are never randomly imputed. If a simulated final table reaches criterion9,
   the optional named prior draws uniformly from ordered set partitions
   (weak orders) of the tied clubs. Within each equal-discipline scenario block,
   criterion10 uses the known coefficient. This is an uncalibrated prior over
   the unmodelled final relative disciplinary ordering, not a forecast of card
   counts, a factual ranking or an assertion that all missing cards are
   future-unknown. It cannot bypass any earlier score criterion. A trace must
   prove criterion9 is the only missing criterion. The strict default retains
   typed unresolved intervals. Completed factual league ties always require
   genuine disciplinary inputs and cannot use this prior.

## Reconciliation, replay and uncertainty

Every simulated table is a permutation of36 clubs after explicitly reviewed
scenario resolution. Club band probabilities sum to1. Across clubs, expected
stage sizes must be8direct,16play-off,12eliminated,16round-of-16,8quarter-final,
4semi-final,2final and1champion. Each iteration has23 actual knockout ties and
one additional champion event. The DAG consumes each participant/winner exactly
once; upset winners inherit the higher seed where regulations require it.

Seeds derive from run, iteration and node identities. Reordering input rows does
not change sampled paths. The caller RNG state is restored. All joint views,
rank inputs, scenario prior samples, event logs and uncertainty tables are hash
bound to the production result. Fixture objects cannot authorize publication.

Wilson95% intervals measure independent Monte Carlo sampling error only; they
exclude model and policy uncertainty. `late_tie_prior_contribution` reports the
number/fraction of iterations affected by the disciplinary prior and a
conservative bound: changing only that prior can change any reported stage
probability by at most the affected iteration fraction. That bound is separate
from Monte Carlo confidence intervals and is not a calibrated policy-uncertainty
interval. Small fixture runs validate mechanics, not forecast quality.

## Activation and remaining limits

Approval, if granted, applies only to the exact manifest hashes and assumptions
above. The owner decision remains pending in `owner_review.json`. Source/model
parents are re-read before atomic publication. Any altered code, evidence or
policy invalidates the manifest. Venue baselines and failed challengers remain
ineligible; this package cannot waive a model gate. Until a qualifying release
exists and the complete production path passes QA, tournament sections stay
explicitly incomplete.

This pre-round contract does not yet assimilate observed knockout results or
condition on a later actual draw. Once a potential round begins, it must block
and be extended with genuine observed knockout fixture/result authority. It
cannot silently resimulate past knockout matches.
