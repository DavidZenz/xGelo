# One-off, offline repair of the reviewed data generation; uses existing writers.
setwd("/private/tmp/xgelo-active-dashboards")
workspace <- "/private/tmp/xgelo-authority-manifest-repair"
module <- new.env(parent = globalenv())
sys.source("R/common/phase18_canonical_hash.R", module)
sys.source("R/competition/ucl_source_acceptance.R", module)
sys.source("scripts/accept_ucl_provider.R", module)
root <- "data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27"
baseline <- jsonlite::read_json(file.path(workspace, "baseline.json"), simplifyVector = TRUE)
before <- jsonlite::read_json(file.path(workspace, "before.json"), simplifyVector = TRUE)
pointer <- module$phase18_read_acceptance_pointer(file.path(root, "current.json"))
stopifnot(identical(pointer$generation[[1L]], baseline$old_generation),
  identical(pointer$manifest_sha256[[1L]], baseline$old_manifest_sha256))
old_root <- file.path(root, baseline$old_generation)
approved_path <- file.path(workspace, "approved-review-before.csv")
pending_path <- file.path(workspace, "historical-pending-review.csv")
hash_file <- function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE)
stopifnot(identical(hash_file(approved_path), before$approved_review_file_sha256),
  identical(hash_file(pending_path), before$historical_pending_file_sha256),
  identical(hash_file(file.path(old_root, "provider_terms_review.csv")), before$approved_review_file_sha256))

# Validate a complete restored historical generation before touching production.
historical_stage <- file.path(workspace, "historical-stage")
stopifnot(!dir.exists(historical_stage))
dir.create(historical_stage)
stopifnot(all(file.copy(list.files(old_root, full.names = TRUE), historical_stage)))
stopifnot(file.copy(pending_path, file.path(historical_stage, "provider_terms_review.csv"), overwrite = TRUE))
old <- module$phase18_read_acceptance_generation(historical_stage)
approved <- module$phase18_read_terms_review(approved_path)
review <- module$phase18_validate_terms_review(approved)
stopifnot(review$valid, identical(review$review_sha256, baseline$approved_review_sha256),
  identical(old$manifest$review_sha256[[1L]], baseline$old_review_sha256),
  !old$manifest$automation_enabled[[1L]],
  all(old$machine_checks$execution_mode == "not_run"))

now <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
manifest <- module$phase18_build_acceptance_manifest(old$machine_checks,
  approved, old$edition_expectations, old$schema_fingerprint,
  decision_id = paste0("not_run_review_rebind_ucl_2026_27_", gsub("[^0-9]", "", now)),
  now_utc = now, parser_commit_sha = old$manifest$parser_commit_sha[[1L]])
stopifnot(!manifest$automation_enabled[[1L]],
  identical(manifest$decision[[1L]], "not_run"),
  identical(manifest$reason_code[[1L]], "missing_credential"),
  identical(manifest$credential_status[[1L]], "absent"),
  identical(manifest$review_sha256[[1L]], review$review_sha256))
candidate <- module$phase18_publish_acceptance_generation(
  file.path(workspace, "candidate"), approved, old$edition_expectations,
  old$machine_checks, old$schema_fingerprint, manifest,
  module$phase18_acceptance_markdown(manifest))
stopifnot(identical(hash_file(candidate$paths[["provider_terms_review.csv"]]), before$approved_review_file_sha256))

# Restore original historical bytes first: the existing pointer becomes valid.
staged_review <- tempfile(".historical-review-", tmpdir = root)
stopifnot(file.copy(pending_path, staged_review))
stopifnot(file.rename(staged_review, file.path(old_root, "provider_terms_review.csv")))
restored <- module$phase18_read_acceptance_set(root)
stopifnot(identical(restored$manifest$row_sha256[[1L]], baseline$old_manifest_sha256))

# Install a validated new immutable generation and switch only the pointer.
selected <- module$phase18_publish_acceptance_generation(root, approved,
  old$edition_expectations, old$machine_checks, old$schema_fingerprint,
  manifest, module$phase18_acceptance_markdown(manifest))
stopifnot(identical(selected$manifest, candidate$manifest),
  !identical(selected$current_generation, baseline$old_generation),
  identical(hash_file(selected$paths[["provider_terms_review.csv"]]), before$approved_review_file_sha256))
for (field in c("machine_checks", "edition_expectations", "schema_fingerprint")) {
  stopifnot(identical(selected[[field]], old[[field]]))
}
generations <- list.dirs(file.path(root, "generations"), recursive = FALSE, full.names = TRUE)
for (generation in generations) module$phase18_read_acceptance_generation(generation)
authority <- module$phase18_validate_provider_live_authority(root)
stopifnot(!authority$authorized, identical(authority$reason_code, "missing_credential"))
jsonlite::write_json(list(status = "repaired_and_validated", repaired_at_utc = now,
  base_commit = before$base_commit,
  old_generation = baseline$old_generation,
  old_manifest_sha256 = baseline$old_manifest_sha256,
  historical_pending_source = before$historical_pending_source,
  historical_review_file_sha256 = hash_file(file.path(old_root, "provider_terms_review.csv")),
  new_generation = selected$current_generation,
  new_manifest_sha256 = selected$manifest$row_sha256[[1L]],
  new_pointer_sha256 = selected$pointer$pointer_sha256[[1L]],
  approved_review_sha256 = review$review_sha256,
  approved_review_file_sha256 = hash_file(selected$paths[["provider_terms_review.csv"]]),
  approved_review_bytes_preserved = TRUE,
  machine_edition_schema_evidence_unchanged = TRUE,
  historical_manifest_preserved = TRUE,
  all_generations_valid = TRUE,
  decision = selected$manifest$decision[[1L]], reason_code = authority$reason_code,
  provider_authorized = authority$authorized, automation_enabled = FALSE,
  network_calls = 0L, publication_performed = FALSE),
  file.path(workspace, "repair.json"), auto_unbox = TRUE, pretty = TRUE)
cat("HISTORICAL_AND_SELECTED_GENERATIONS_VALIDATED_AUTOMATION_DISABLED\n")
