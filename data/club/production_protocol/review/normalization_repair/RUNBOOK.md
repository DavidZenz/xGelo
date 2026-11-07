# Portable verification and deferred deployment

Nothing here installs the repair, records an owner decision or starts fitting.
The live NL controller must finish its install/CAS window before any managed
code or data is changed. Preserve WC code, inputs, outputs and scheduler bytes.

## Runtime contract

The reviewed runtime is R 4.6.2, stringi 1.8.7 and ICU 74.1. The proposed core
checks the latter two versions and fails closed on a different combination.
There is no renv.lock in this project: package restoration is not implied by
this package. Verify the installed versions explicitly before deployment or
any fresh evaluation. There is no native-iconv fallback.

From the repository root, with `repair` set to this directory:

```sh
repair=.planning/operations/cl-normalization-repair-2026-11-05
repair_rscript="$(rtk proxy bash -c 'source scripts/lib/rscript_runtime.sh; xgelo_resolve_rscript || exit 1; printf "%s\n" "$R_SCRIPT"')"
rtk proxy "$repair_rscript" --vanilla -e 'stopifnot(getRversion() == "4.6.2", as.character(utils::packageVersion("stringi")) == "1.8.7", stringi::stri_info()$ICU.version == "74.1")'
rtk proxy "$repair_rscript" --vanilla "$repair/evidence/test_normalization_v3.R"
rtk proxy "$repair_rscript" --vanilla "$repair/verify_repair.R"
rtk proxy "$repair_rscript" --vanilla "$repair/verify_repair.R" --full-hash
rtk proxy "$repair_rscript" --vanilla "$repair/verify_candidate_readers.R" --full
rtk proxy python3 "$repair/verify_manifest.py"
rtk proxy python3 "$repair/tools/run_cold_probes.py" --rscript "$repair_rscript"
rtk proxy python3 "$repair/tools/test_staged_apply.py"
```

The existing shared resolver checks the configured executable, PATH and its
standard installation fallbacks. These commands do not require `Rscript` on
PATH or assume a Homebrew location. Keep the resolved path quoted; the cold
probe runner receives that same executable explicitly.

The first two commands use the actual proposed R/club module under `snapshots`,
not a reimplementation. The full-hash option additionally recomputes every
candidate match row hash. The optional candidate-reader command reconstructs
a disposable project and runs the genuine fixed-root history/fold readers; it
takes several minutes and performs no fitting or acceptance. The fixed cold
workload runs ten fresh processes and
1,000 scalar calls per variant; it records every outcome once, without retries.
It writes to a new temporary directory. A short portability check can use
`--processes 1 --repetitions 128`. Proof paths are relative to this package;
the package can be moved intact without the original private workspace.

## Exact review and installation sequence

1. Review the single pending replacement package in `replacement_fold_review`.
   Its exact manifest also binds the repair code, new registry/history parents,
   pending fold generation and technical evidence. It does not ask for the 407
   unchanged raw identity decisions again. No accepted receipt is supplied.
2. After the controller releases its freeze, verify `deployment/preconditions.json`
   against the real repository. Any mismatch requires investigation, rather
   than overwriting another worker's change. Archive the previous review tree
   and owner receipt. Never rewrite an old immutable generation.
3. Stage all new generation directories from `deployment/files` first. With
   refresh/model jobs stopped, install the proposed core, CLI dependency fix,
   test and review files, then the new registry/history/pending-fold pointers.
   Treat these as one coordinated migration; an intermediate mix deliberately
   fails closed. The old model selection is retained and becomes ineligible
   until a fresh release validates the new code and parents.
4. Run the core regression against the installed module and independently load
   the proposed history and pending fold inventory through the real readers.
   The private actual-reader preparation has already passed; this installed
   verification is still required. Require pending_review, exactly 26 folds,
   exactly 104 role sets, identical membership bytes and no production release.
5. Only after a real owner decision accepts the exact replacement manifest,
   use the existing `scripts/prepare_club_model_review.R --decision=...` path.
   Its code validates every bound artifact, current code hash and exact pending
   parents before applying the review. Do not regenerate the pending package
   after its manifest is accepted, or copy the old accepted decision onto it.
6. After the cost and timing are agreed, acquire a genuinely fresh CL source
   through the authorized source-only updater and run the real production
   controller: `rtk proxy "$repair_rscript" --no-init-file --no-site-file scripts/run_phase19_club_evaluation.R`.
   It must perform both genuine 26-fold executions, independent replay and final
   refit under unchanged statistical gates. Do not pass fixture paths or reuse
   run16939's numerical artifacts as the new execution.

The source updater uses the existing ignored local API configuration; never
copy that key or raw provider responses into this package. Source freshness is
a separate gate. Tournament policy approval and model quality remain separate:
this normalization repair neither accepts the proposed CL9 policy nor promises
that Elo passes its fixed calibration gate. Keep tournament outputs blocked
until their genuine model and policy authority both pass.

The application utility defaults to a read-only preflight. Only after the
coordinator releases the live controller's freeze, and using this exact reviewed
package, the staged commands from the repository root are:

```sh
repair=.planning/operations/cl-normalization-repair-2026-11-05
backup=.planning/operations/cl-normalization-backup-20261105
rtk proxy python3 "$repair/apply_staged_repair.py" --project .
rtk proxy python3 "$repair/apply_staged_repair.py" --project . --apply --backup "$backup"
```

The preflight checks every expected old byte and all twelve pinned core files.
The installer stores a rollback journal, writes new immutable generations first,
installs the pending review and code, and switches pointers last. It archives
the previous owner receipt and removes that old receipt from the new pending
review's active directory. It leaves the model selector untouched and does not
accept the review. The backup directory must be new and outside this sealed
package. The fixture test exercises this real payload in a temporary project,
including concurrent-byte rejection and protected rollback.

If an installed migration must be rolled back before any later model/fold
transition, stop the refresh jobs and use:

```sh
rtk proxy python3 "$repair/apply_staged_repair.py" --project . --rollback "$backup"
```

Rollback refuses to overwrite later edits or a later owner receipt. It restores
the previous files and pointers, retains the newly created immutable generations
as unselected evidence, and performs no model selection or publication. These
commands have only been exercised in temporary fixtures; main installation has
not occurred.

## Hash labels and historical diagnostic evidence

`evidence/history_role_preservation_summary.json` was a fixture-level diagnostic.
Its field `new_registry_sha256` denotes the **club identity registry**, a7eece….
The final **fold registry** is 3c6146… in `evidence/replacement_fold_summary.json`.
They are distinct objects, not two versions of one hash. The old diagnostic is
retained unchanged. `FINAL_IDENTITIES.json` names every final parent explicitly.

The private candidate generation's accepted-format tables are mechanically
derived from the unchanged genuine raw approvals and independently audited;
they are not a live pointer or a new owner decision. The old pointer's bytes
and hash remain provenance. The old legacy aliases cannot be semantically
re-audited using a different normalization contract, so the migration preserves
their immutable generation and stages a new, fully validated generation. No
existing semantic validator was weakened or bypassed in preparing the new
folds: the unmodified production preparation script read the new corpus twice
through its normal audit/accepted reader and left the fold review pending.
