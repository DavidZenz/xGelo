# Phase 16 full-suite baseline

This is a regression fingerprint, not a claim that the full repository suite is green.
Phase 16 acceptance uses the focused/relevant suites plus the comparison rule below:
a persistent recorded failure remains non-green, while only new or unparseable failures gate the comparator.

## Capture

- Capture date (UTC): `2026-08-24T08:07:01Z`
- Full-suite command: `Rscript --vanilla -e 'testthat::test_dir("tests/testthat", reporter="summary")'`
- Child-process exit status: `1`
- Capture disposition: `record persisted`
- Combined stdout/stderr SHA-256: `4f123bfc5edb83fac3b5ba6606ca6dba1971208793f7c2f11a2254b915c9a98c`
- Output normalization: `sorted unique test_file::test_name entries`
- Normalization status: `parsed`

## Known baseline disposition

- Allowed pre-existing disposition: exactly the recorded failure identity and known signature below.
- A nonzero child status is retained as evidence; capture success means only that this record was written.
- Output-hash drift is reported evidence and is not a standalone comparison failure.
- Known failure signature: `156 fixture IDs paired with zero-length normalized source columns`
- Known failing test identities:
- `test_phase13_publication_hashes.R::EURO pre_draw normalize`
- `test_phase13_publication_hashes.R::canonical content is or`
- `test_phase13_publication_hashes.R::canonical refresh rewri`
- `test_phase13_publication_hashes.R::malformed source-artifa`
- `test_phase13_publication_hashes.R::resource target validat`
- `test_phase13_publication_manifests.R::EURO pre_draw status`
- `test_phase13_publication_manifests.R::accepted manifests a`
- `test_phase13_publication_manifests.R::derived hashes are s`
- `test_phase13_publication_manifests.R::duplicate artifacts`
- `test_phase13_publication_manifests.R::stale canonical valu`

## Comparison policy

- Exit zero when the current suite has no failures.
- Exit zero, while reporting `persistent known baseline (non-green)`, when current identities and signature exactly match this record.
- Exit nonzero for a new identity, a missing known signature, an unparseable failure, or a helper/launch/read failure.

## Recorded signature

`156 fixture IDs paired with zero-length normalized source columns`
