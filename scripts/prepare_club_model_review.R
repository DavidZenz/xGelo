#!/usr/bin/env Rscript

# Derive exact fold/role memberships from accepted parents before fitting any
# production model. Applying a review requires a separate package-bound human
# decision; preparing this package never accepts its own output.
for (path in c("R/common/phase18_canonical_hash.R", "R/competition/source_contracts.R",
  "R/competition/ucl_source_acceptance.R", "R/competition/edition_registry.R",
  "R/club/identity.R", "R/club/identity_bootstrap.R", "R/competition/football_data_org_adapter.R",
  "R/competition/ucl_source_bundle.R", "R/competition/ucl_source_refresh.R", "R/club/history_contract.R",
  "R/evaluation/proper_scores.R", "R/evaluation/benchmark_scores.R", "R/release/domain_contract.R",
  "R/club/model_contract.R", "R/club/evaluation_protocol.R", "R/club/clubelo.R", "R/club/rating.R",
  "R/club/goal_model.R", "R/club/calibration.R", "R/club/evaluation.R", "R/club/release.R",
  "R/club/production_runner.R")) source(path)

club_model_review_root <- "data/club/production_protocol/review"
club_review_sha <- function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE)

prepare_club_model_review <- function() {
  folds <- phase19_refresh_club_fold_protocol()
  if (!identical(folds$status, "pending_review") || !nrow(folds$fold_registry))
    stop("Accepted sources, identities and policy must support a nonempty pending fold inventory")
  snapshot <- phase19_load_club_training_snapshot()
  roles <- do.call(rbind, lapply(seq_len(nrow(folds$fold_registry)), function(i) {
    fold <- folds$fold_registry[i, , drop = FALSE]
    inventory <- phase19_production_role_inventory(snapshot, fold)
    do.call(rbind, lapply(c("fit", "temperature", "selection", "assessment"), function(role) {
      rows <- inventory[[role]]
      data.frame(fold_id = fold$fold_id, role = role, fixture_count = nrow(rows),
        first_match = min(rows$event_date), last_match = max(rows$event_date),
        latest_evidence = max(rows$evidence_available_at_utc),
        fixture_ids = paste(sort(rows$match_id, method = "radix"), collapse = "|"), stringsAsFactors = FALSE)
    }))
  }))
  dir.create(club_model_review_root, recursive = TRUE, showWarnings = FALSE)
  phase19_write_fold_registry(folds$fold_registry, file.path(club_model_review_root, "fold_registry.csv"))
  phase19_write_json_atomic(folds$fold_review, file.path(club_model_review_root, "fold_review.json"))
  utils::write.csv(roles, file.path(club_model_review_root, "role_inventory.csv"), row.names = FALSE)
  phase19_production_recipe_write(file.path(club_model_review_root, "production_recipe_v2.json"))
  writeLines(c("# Pending club model fold review", "",
    sprintf("%d outer folds; %d held-out fixtures across both fold families.", nrow(folds$fold_registry),
      sum(as.integer(folds$fold_registry$declared_fixture_count))),
    "The inventory freezes exact fit, temperature, primary-view selection and assessment memberships.",
    "Every role uses strict source-availability cutoffs. Held-out competitions are excluded from transport fitting.",
    "Production fitting begins only after this exact inventory and the production recipe are accepted.",
    "Promotion retains the existing frozen statistical gates and the all-36 connected-history requirement."),
    file.path(club_model_review_root, "README.md"))
  paths <- file.path(club_model_review_root, c("fold_registry.csv", "fold_review.json", "role_inventory.csv", "production_recipe_v2.json", "README.md"))
  manifest <- list(schema_version = "club-model-fold-review-package-v1", decision = "pending",
    fold_registry_sha256 = folds$fold_registry_sha256, code_sha256 = phase19_production_code_identity(),
    recipe_sha256 = phase19_production_recipe()$recipe_sha256,
    files = lapply(paths, function(path) list(path = path, sha256 = club_review_sha(path))))
  phase19_write_json_atomic(manifest, file.path(club_model_review_root, "review_manifest.json"))
  cat(sprintf("MODEL_REVIEW pending_folds=%d roles=%d fold_registry_sha256=%s\n", nrow(folds$fold_registry), nrow(roles), folds$fold_registry_sha256))
  invisible(folds)
}

apply_club_model_review <- function(decision_path) {
  decision <- jsonlite::fromJSON(decision_path, simplifyVector = TRUE)
  fields <- c("schema_version", "decision", "reviewer", "reviewed_at_utc", "review_manifest_sha256")
  manifest_path <- file.path(club_model_review_root, "review_manifest.json")
  if (!identical(names(decision), fields) || decision$schema_version != "club-model-fold-owner-decision-v1" ||
      decision$decision != "accepted" || !nzchar(decision$reviewer) ||
      !identical(decision$review_manifest_sha256, club_review_sha(manifest_path))) stop("Exact package-bound owner acceptance is required")
  manifest <- jsonlite::fromJSON(manifest_path, simplifyVector = FALSE)
  for (file in manifest$files) if (!identical(club_review_sha(file$path), file$sha256)) stop("Pending fold review artifact changed")
  folds <- phase19_load_club_fold_protocol()
  if (!identical(folds$status, "pending_review") || !identical(folds$fold_registry_sha256, manifest$fold_registry_sha256) ||
      !identical(phase19_production_code_identity(), manifest$code_sha256) ||
      !identical(phase19_production_recipe()$recipe_sha256, manifest$recipe_sha256)) stop("Pending fold parents or code changed")
  review <- phase19_build_fold_review(folds, "accepted", decision$reviewer, decision$reviewed_at_utc,
    paste0("production_recipe_v2:", manifest$recipe_sha256, ";owner_package:", decision$review_manifest_sha256))
  phase19_apply_club_fold_review(review)
  if (!file.copy(decision_path, file.path(club_model_review_root, "accepted_owner_decision.json"), overwrite = TRUE)) stop("Could not retain owner decision")
  cat("MODEL_REVIEW accepted=true\n")
  invisible(review)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (!length(args)) prepare_club_model_review() else {
    if (length(args) != 1L || !startsWith(args, "--decision=")) stop("Use no arguments to prepare, or --decision=<owner-decision.json> to apply")
    apply_club_model_review(sub("^--decision=", "", args))
  }
}
