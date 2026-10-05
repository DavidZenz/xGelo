# EURO 2028 safety net implementation

Approved 5 October 2026. Read-only EURO 2028 tab in the Nations League dashboard; queue now, qualification routes later. No manual scenario calculator.

- [x] Pin Article 16 priority policy; calculate joint per-iteration group winners/interim ranks without RNG changes.
- [x] Aggregate per-metric availability, winner chances, interim/queue means and 10–90% range.
- [x] Implement the hashed queue artifact pipeline with policy/source/model lineage; recognize exact archived inventory.
- [x] Add scoped searchable/filterable responsive EURO 2028 tab and accessible explanations/disclosures.
- [ ] Verify policy, queue conservation, unavailable inputs, replay, compatibility, desktop/mobile and existing dashboard regression.
- [ ] Rebuild, stage, validate, atomically publish and read back; record verification and commit verified changes.

Queue order: A/B/C winners by interim rank, highest-ranked D winner, remaining teams by interim rank, before exclusions for other routes. The D fallback is conditional; queue positions are not entry probabilities. Keep the EURO companion pre-draw and UCL untouched. Existing approved model, seed 15017 and 1,000 simulations are retained.

Publication is awaiting the user's cutoff decision. The existing simulator drops ten accepted results on the last completed matchday because it parses an RFC3339 timestamp as midnight. Correcting it changes existing forecasts; preserving them requires unavailable priority aggregates. See `euro-safety-net-VERIFICATION.md`. The outdated-cutoff full rebuild was stopped; approved inputs and forecast handoff remain cached in `/private/tmp/euro-safety-inputs.rds` for the resumed rebuild.
