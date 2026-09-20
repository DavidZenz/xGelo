#!/usr/bin/env Rscript

source("R/common/phase18_canonical_hash.R", local = .GlobalEnv)

if (!exists("phase18_verify_contract_gate", mode = "function")) {
  stop("Phase 18 contract gate implementation is missing", call. = FALSE)
}

phase18_verify_contract_gate()
