#!/usr/bin/env Rscript

# Apply a genuine, package-bound owner decision. This script never supplies or
# infers the human decision itself. Source it safely to inspect the operation.
for (dependency in c("R/common/phase18_canonical_hash.R", "R/competition/source_contracts.R",
  "R/club/identity.R", "R/club/identity_bootstrap.R", "R/club/history_contract.R",
  "R/club/model_contract.R", "R/club/evaluation_protocol.R")) source(dependency)

accept_club_history_review <- function(decision_path,
    review_root = "data/club/identity_reviews/history-2026-10-27") {
  decision <- jsonlite::fromJSON(decision_path, simplifyVector = TRUE)
  fields <- c("schema_version", "decision", "reviewer", "reviewed_at_utc", "review_manifest_sha256")
  if (!identical(names(decision), fields) || decision$schema_version != "club-history-owner-decision-v1" ||
      decision$decision != "accepted" || !nzchar(decision$reviewer)) stop("Exact accepted owner decision is required")
  phase18_history_parse_utc(decision$reviewed_at_utc, "reviewed_at_utc")
  manifest_path <- file.path(review_root, "review_manifest.json")
  sha <- function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE)
  if (!identical(sha(manifest_path), decision$review_manifest_sha256)) stop("Owner decision binds a different package")
  manifest <- jsonlite::fromJSON(manifest_path, simplifyVector = FALSE)
  trusted <- normalizePath(review_root, winslash = "/", mustWork = TRUE)
  allowed_policy <- normalizePath(c(file.path("data/club/model_protocol", c("candidate_registry.csv", "gate_registry.csv",
    "seed_registry.csv", "feature_contract.csv", "policy_review.json")),
    "data/club/production_protocol/production_recipe_v2.json"), winslash = "/", mustWork = TRUE)
  for (file in manifest$files) {
    actual <- normalizePath(file$path, winslash = "/", mustWork = TRUE)
    if (!(startsWith(actual, paste0(trusted, "/")) || actual %in% allowed_policy) ||
        nzchar(Sys.readlink(actual)) || !identical(sha(actual), file$sha256)) stop("Reviewed artifact bytes changed")
  }
  read <- function(name) phase18_history_read_csv(file.path(review_root, paste0(name, ".csv")))
  inventory <- read("proposed_history_sources"); scopes <- read("proposed_history_scopes")
  tokens <- read("proposed_history_tokens"); review <- read("proposed_history_owner_review")
  if (any(review$review_state != "pending") || any(inventory$source_status != "blocked_pending_review"))
    stop("Package is not an exact pending proposal")
  review$review_state <- "approved"; review$reviewer <- decision$reviewer
  review$reviewed_at_utc <- decision$reviewed_at_utc
  review <- phase18_hash_club_review_rows(review)
  inventory$license_review_state <- "approved"
  inventory$license_reviewed_by <- inventory$coverage_reviewed_by <- decision$reviewer
  inventory$license_reviewed_at_utc <- inventory$coverage_reviewed_at_utc <- decision$reviewed_at_utc
  inventory$source_status <- "active"; inventory$blocked_reason <- ""
  inventory$row_sha256 <- phase18_history_row_sha256(inventory)
  phase18_validate_history_sources(inventory, allow_pending = FALSE)
  for (i in seq_len(nrow(inventory))) {
    invisible(phase18_verify_history_source_file(inventory[i, ], "data/club/local_raw"))
    license <- file.path("data/club/local_raw", inventory$source_id[i], inventory$commit_sha[i], "LICENSE.evidence")
    if (!identical(sha(license), inventory$license_sha256[i])) stop("Retained license evidence changed")
  }
  current_tokens <- phase18_history_read_csv("data/club/identity_reviews/current_ucl_tokens.csv")
  current_review <- phase18_history_read_csv("data/club/identity_reviews/current_ucl_owner_review.csv")
  combined_tokens <- rbind(current_tokens, tokens)
  applied <- phase18_apply_club_identity_review(combined_tokens, rbind(current_review, review), phase18_load_club_registries())
  phase18_validate_identity_bootstrap(list(registries = applied$registries, tokens = combined_tokens,
    unresolved = applied$unresolved), current_expectations = list(required = TRUE, expected_tokens = nrow(current_tokens)),
    history_expectations = list(required = TRUE, expected_tokens = nrow(tokens)))
  protocol <- phase19_protocol_components(include_review = FALSE)
  if (!identical(sha("data/club/model_protocol/policy_review.json"),
      sha(file.path(review_root, "policy_review_before.json")))) stop("Policy review changed after package preparation")
  policy <- phase19_protocol_read_review("data/club/model_protocol/policy_review.json")
  policy$reviewer <- decision$reviewer; policy$reviewed_at_utc <- decision$reviewed_at_utc
  policy$decision <- "accepted"; policy$rationale_code <- paste0("owner_history_package:", decision$review_manifest_sha256)
  policy$review_sha256 <- phase19_policy_review_sha256(policy)
  phase19_validate_policy_review(policy, protocol, require_accepted = TRUE)
  targets <- c("data/club/registries/current.json", "data/club/history_sources.csv", "data/club/history_source_scopes.csv",
    "data/club/identity_reviews/historical_inventory_tokens.csv", "data/club/identity_reviews/historical_owner_review.csv",
    "data/club/identity_reviews/unresolved_club_tokens.csv", "data/club/model_protocol/policy_review.json")
  before <- lapply(targets, function(path) if (file.exists(path)) readBin(path, "raw", n = file.info(path)$size) else NULL)
  committed <- FALSE
  on.exit(if (!committed) for (i in seq_along(targets)) {
    if (is.null(before[[i]])) unlink(targets[i]) else writeBin(before[[i]], targets[i])
  }, add = TRUE)
  phase18_write_club_registries_atomic(applied$registries, "data/club/registries")
  phase18_write_csv_atomic(inventory, targets[2L]); phase18_write_csv_atomic(scopes, targets[3L])
  phase18_write_csv_atomic(tokens, targets[4L]); phase18_write_csv_atomic(review, targets[5L])
  phase18_write_csv_atomic(applied$unresolved, targets[6L]); phase19_write_json_atomic(policy, targets[7L])
  if (!file.copy(decision_path, file.path(review_root, "accepted_owner_decision.json"), overwrite = TRUE))
    stop("Could not retain the package-bound owner decision")
  committed <- TRUE
  cat(sprintf("HISTORY_REVIEW accepted_sources=%d accepted_aliases=%d policy=accepted\n", nrow(inventory), nrow(review)))
  invisible(TRUE)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 1L || !startsWith(args, "--decision=")) stop("Use --decision=<accepted-owner-decision.json>")
  accept_club_history_review(sub("^--decision=", "", args))
}
