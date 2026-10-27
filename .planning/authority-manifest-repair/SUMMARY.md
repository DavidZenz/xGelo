# CL authority manifest repair — 2026-10-27

The provider review/manifest mismatch is repaired. The complete official Phase
18 gate passes in eight fresh processes: 143 tests and 861 assertions, with
zero failed assertions, errors, emitted warnings or skips. All seven CL
authority/simulation suites also pass: 95 tests and 578 assertions. Together
with the Phase 19 domain-contract suite, the fully passing fresh-process
scopes cover 248 tests / 1,544 assertions. The broader Phase 19 targets test
has a separately reproduced environment blocker, described below.

## Repair

Commit `9b06e48` had replaced seven pending review rows with the genuine
September 25 owner approval inside the existing September 20 generation. Its
manifest and pointer still bound the pending review hash, so strict readers
correctly rejected the mixed evidence.

The historical generation's pending review is restored byte-for-byte from
`9b06e48^`. Its original manifest, timestamps, other evidence and canonical
identity remain intact. The approved review is preserved byte-for-byte in a
new generation created and selected through the existing validated generation
writer and atomic pointer writer. No reader, validator or authority policy
was weakened, and no runtime source code changed.

The generated operator explanation's extra blank line at EOF was normalized
before commit. Authority CSVs, manifest/pointer bindings and historical bytes
were unchanged by that formatting cleanup; both generations were revalidated.

| Binding | Value |
| --- | --- |
| Original generation | `generations/g-ad42bc7742eb490b8f7fe8c4b8a3cebd` |
| Original pending review canonical hash | `d8e20072656750b0891c616d4873871fd7b5c1697e70bdd86714d05c7bfd8f66` |
| New selected generation | `generations/g-7c7f9d26712aaf7595cbfcf598266658` |
| New manifest canonical hash | `7c7f9d26712aaf7595cbfcf598266658fa5e048051d550a687dc1b3e998ef374` |
| Approved review canonical hash | `50d9abd25277f27247bc871a8fb7216684bc67c916e06399b6e196df000e4686` |
| Approved review raw-file SHA-256, before and after | `9d57ac6b3d07db5c8eac23d088f114325f83eb40485e8aba0c5d24a6c981bbb7` |

Both generations validate independently. Machine checks, edition expectations
and schema fingerprints are identical to the original evidence. The new
decision timestamp is `2026-10-27T07:41:00Z`; the human review timestamp remains
`2026-09-25T11:14:17Z`. This records a new binding decision without claiming
new provider observations or rewriting when the owner reviewed the terms.

## Verification

- The original integrity failure was reproduced in a fresh R process; the
  original pending Git bytes were independently validated before restoration.
- The production acceptance test now verifies approved review binding while
  preserving the no-key state. A new regression checks both generations,
  unchanged machine/edition/schema evidence, chronological review binding,
  and rejection of a separately rehashed altered review.
- `scripts/verify_phase18_contracts.R` passed all eight suites, including
  acceptance, canonical hashing, identity, source bundles, adapter, refresh,
  history, adversarial, killed-writer and concurrent-reader coverage. It also
  verified that the checks did not mutate durable production evidence.
- The Phase 19 domain-contract suite passed 10 tests and 105 assertions.
- All seven CL suites pass in fresh processes: state authority, final boundary,
  adversarial rules, outcome wiring, simulation, the complete UEFA CL suite
  and prepared execution. Together they cover 95 tests / 578 assertions.
- The three Phase 19 fixture pipeline cases separately passed 30 assertions,
  including the fixture release, root/domain attacks and repeated execution.

## Broader pipeline environment blocker

The initial extended runner passed the domain-contract suite and then stopped
at `test_phase19_club_pipeline.R`. A diagnostic split identified the single
blocked-target case: `targets::tar_make()` refuses to start because `glmnet`
and `ranger` are absent from this R 4.6.1 library. Targets 1.12.0 is installed.
The failure also emits `no non-missing arguments to max; returning -Inf`.

The exact failing case was repeated against an archived `b63acd6` tree with
the original authority data and Git-restored project marker. It gives the
identical package error and warning before target execution. `_targets.R`,
the pipeline test, controller and authority module are byte-identical to that
pre-repair commit. This independently establishes the environment blocker;
it is not caused by the authority-data repair. An earlier archived fixture
attempt lacked its project-root marker and is excluded from this conclusion.

No runtime code, package configuration, or package installation was changed
to bypass the failure. The entire extended Phase 19 pipeline suite therefore
is not claimed green. Its three fixture cases pass, and the provider/CL
authority gates listed above are independently green. Full targets validation
requires installing the two genuine dependencies in the R environment.

The [evidence index](evidence/index.json) records the passing suite counts,
original extended failure, targeted diagnostics, baseline reproduction, and
SHA-256 hashes for every included receipt. The official Phase 18 gate took
401.4 seconds; CL checks ran in fresh processes, and the fixture-only pipeline
diagnostic took 908.3 seconds. The long diagnostic stages were chained
automatically and inspected at the requested cadence, with an additional
status read when asked.

## Preserved boundaries

A before/after SHA-256 inventory covers all published files and 671 tracked
data, output and runtime source files. The only changed original data files
are the authority pointer and the restored historical review; the new
generation adds exactly the existing six-file schema. Published inventory and
bytes, football artifacts, forecast ledgers, model inputs and runtime code are
unchanged. No dashboard publisher or provider transport was invoked by the
repair.

The recorded provider state remains `not_run` / `missing_credential`, with
`automation_enabled=FALSE` and `authorized=FALSE`. Live provider acceptance,
real club/history evidence, production model authority and public promotion
remain separate gates. No milestone phase is marked complete by this repair.

The simulation source snapshot remains
`9bac1d4f6f8c84b4f8d18ba7c11b51c311c63a8da858eec5745cb9680f11e404`;
accepted NL inputs and CL benchmark fixtures are unchanged. The 100k
performance evidence therefore retains its measured source/input identity.
The earlier failure receipts remain historical records and are not rewritten
to claim that this repair had already existed during performance certification.
