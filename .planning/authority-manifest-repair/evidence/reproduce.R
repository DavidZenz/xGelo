setwd("/private/tmp/xgelo-active-dashboards")
module <- new.env(parent = globalenv())
sys.source("R/common/phase18_canonical_hash.R", module)
sys.source("R/competition/ucl_source_acceptance.R", module)
root <- "data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27"
failure <- tryCatch({module$phase18_read_acceptance_set(root); NULL}, error = identity)
stopifnot(inherits(failure, "phase18_acceptance_integrity"),
          grepl("manifest differs from recomputed evidence: review_sha256", conditionMessage(failure), fixed = TRUE))
pointer <- module$phase18_read_acceptance_pointer(file.path(root, "current.json"))
generation <- file.path(root, pointer$generation[[1L]])
read <- function(name) utils::read.csv(file.path(generation, name), stringsAsFactors = FALSE, check.names = FALSE, na.strings = NULL)
manifest <- read("acceptance_manifest.csv")
approved <- read("provider_terms_review.csv")
pending <- utils::read.csv("/private/tmp/xgelo-authority-manifest-repair/historical-pending-review.csv", stringsAsFactors = FALSE, check.names = FALSE, na.strings = NULL)
module$phase18_validate_acceptance_manifest(manifest, read("coverage_matrix.csv"), pending, read("edition_expectations.csv"), read("schema_fingerprint.csv"))
review <- module$phase18_validate_terms_review(approved)
stopifnot(review$valid, identical(review$review_sha256, "50d9abd25277f27247bc871a8fb7216684bc67c916e06399b6e196df000e4686"),
          identical(manifest$review_sha256[[1L]], "d8e20072656750b0891c616d4873871fd7b5c1697e70bdd86714d05c7bfd8f66"))
jsonlite::write_json(list(status = "mismatch_reproduced", message = conditionMessage(failure),
  historical_pending_review_validates_original_manifest = TRUE,
  approved_review_valid = review$valid, old_generation = pointer$generation[[1L]],
  old_manifest_sha256 = manifest$row_sha256[[1L]],
  old_review_sha256 = manifest$review_sha256[[1L]], approved_review_sha256 = review$review_sha256),
  "/private/tmp/xgelo-authority-manifest-repair/baseline.json", auto_unbox = TRUE, pretty = TRUE)
cat("MISMATCH_REPRODUCED_AND_EXACT_HISTORICAL_RESTORATION_VALIDATED\n")
