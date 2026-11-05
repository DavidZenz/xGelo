# CL provider schema contract migration

The existing v2 fingerprint describes the complete observed JSON shape, including
every array index, cardinality and null/scalar leaf. Consequently a scheduled
fixture becoming a result, a referee being assigned, or an unconsumed squad edit
invalidates the accepted fingerprint. This prevents routine live refreshes.

A bounded genuine four-endpoint probe on 2026-11-05 found 72 finished and 72 timed
matches. Competition metadata and standings had exactly their accepted 2026-10-27
v2 fingerprints under R 4.6.2, so this is not a general R-version/hash change.
Matches changed from `55b23c8aecc34ab500fcd2842575d31170e58bfb908d3b5dd9d2f7172a1804fe`
to `63bb2eaa1025869fbba10c1179d8b6dfc5c0a744bf7a1a3619e016f6a338042a`.
Teams changed from `64afb606ef4e38c6ca9249967265bbf20761fdf47ff44ab5827209067722f6ec`
to `9c6461e425a2594002f64b529c9b89c108899f8f1f336c60ce72d21c8e903876`.
The approved no-durable-raw-cache disposition means the old full JSON shapes
cannot be reconstructed for an exact field-level comparison. No claim is made
that every unconsumed old/new metadata difference was individually reviewed.

The explicit migration is `phase18-fd-consumed-json-contract-v3`, implemented in
`R/competition/football_data_org_adapter.R`. It validates every consumed nested
field in every array element before scalar/integer coercion. Required fields must
be present; designated nullable leaves permit JSON null but not an absent field.
Whole JSON numbers are accepted independently of R integer/double representation.
Arrays bind their element contract instead of their current index/count. The
resulting fingerprint hashes the versioned resource/path/type/nullability/
optionality contract using the existing canonical v2 byte encoding.

Squads, coaches, staff, referees and other extra object fields are explicitly
outside the normalized data contract. They cannot establish fixture/model
authority. Adding a consumed field requires updating the versioned contract;
missing consumed fields or wrong consumed types fail closed. Existing closed
status/stage checks, exact 36-club/144-league-match expectations, reviewed identity
joins, pagination completeness, HTTP freshness and standings/result reconciliation
remain separate required gates.

The exact v2 observed-shape function is retained for historic evidence. Existing
acceptance/source generations and hashes are preserved. The bundle comparator
still requires exact accepted fingerprint equality. Old machine acceptance
therefore rejects v3 until a genuine new four-resource live acceptance probe
creates its own generation. There is no fallback that substitutes old hashes.

The actual owner-review schema covers application scope, display rights,
normalized display, attribution, raw-cache disposition, retention and provider
exit. Reviewed club identities and the 36/144 expectation are unchanged. No
separate owner schema-review field is required by that contract. The existing
`live_acceptance_probe` path produces fresh machine evidence using those existing
owner decisions; it does not create a new owner decision.

Verification under R 4.6.2: the complete focused football-data adapter suite and
source-bundle suite pass. Regressions cover lifecycle/array-order/roster
invariance, a wrong consumed type in the final array element, fractional goal
types, absent nullable score keys, nested-object type drift, pagination types,
and preservation of exact 36/144 and existing source-authority gates. The bundle
suite's initial subprocess discovery failure was resolved by placing the
explicit R 4.6.2 bin directory on its child PATH; the actual suite then passed.

The genuine fixed-window probe succeeded at `2026-11-05T18:53:23Z` with decision
`live_acceptance_probe_ucl_2026_27_20261105185323`, generation
`g-179fd5658cbe6ee057aafd613d45d06a`, and acceptance manifest SHA256
`179fd5658cbe6ee057aafd613d45d06a41378c171bf57f657d5147ee7e143c1e`.
The previous generation remains on disk. This is fresh machine acceptance with
the unchanged existing owner review, not a manufactured new owner decision.

Provider keys and raw responses were never printed or written by this work.
Source refresh and production model evaluation are separate subsequent steps.
