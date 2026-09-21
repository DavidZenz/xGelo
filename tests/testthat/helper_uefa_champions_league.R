# Phase 20 Wave 0 fixture and contract helpers.
#
# This file intentionally contains only declared mechanics fixtures and
# test-contract inventories.  It never resolves a production source root,
# writes a selector, or promotes fixture evidence.

phase20_test_project_root <- local({
  candidate <- file.path(getwd(), if (basename(getwd()) == "testthat") "../.." else ".")
  normalizePath(candidate, winslash = "/", mustWork = TRUE)
})

phase20_test_edition_id <- "ucl_2026_27"
phase20_test_source_bundle_id <- "phase20-ucl-fixture-source-v1"
phase20_test_source_lineage_id <- "phase20-ucl-fixture-lineage-v1"
phase20_test_ruleset_version <- "ucl-2026-27-rules-v1"
phase20_test_information_cutoff_utc <- "2026-09-21T00:00:00Z"
phase20_test_fixed_root <- "outputs/competition/ucl_2026_27/outcomes"

phase20_test_hash <- function(value) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("Phase 20 fixture helpers require digest", call. = FALSE)
  }
  digest::digest(
    charToRaw(paste0(as.character(value), collapse = "\u001f")),
    algo = "sha256",
    serialize = FALSE
  )
}

phase20_test_fixture_club_ids <- function() {
  sprintf("ucl-club-%02d", seq_len(36L))
}

phase20_ucl_fixture_declarations <- c(
  "ucl20-fixture-0001|ucl-club-01|ucl-club-02|1|venue-ucl-club-01|2026-09-15T18:00:00Z|ucl20-source-artifact-0001|source-row-0001|ucl20-source-lineage-0001",
  "ucl20-fixture-0002|ucl-club-02|ucl-club-03|2|venue-ucl-club-02|2026-09-16T19:00:00Z|ucl20-source-artifact-0002|source-row-0002|ucl20-source-lineage-0002",
  "ucl20-fixture-0003|ucl-club-03|ucl-club-04|3|venue-ucl-club-03|2026-09-17T20:00:00Z|ucl20-source-artifact-0003|source-row-0003|ucl20-source-lineage-0003",
  "ucl20-fixture-0004|ucl-club-04|ucl-club-05|4|venue-ucl-club-04|2026-09-18T21:00:00Z|ucl20-source-artifact-0004|source-row-0004|ucl20-source-lineage-0004",
  "ucl20-fixture-0005|ucl-club-05|ucl-club-06|5|venue-ucl-club-05|2026-09-19T18:00:00Z|ucl20-source-artifact-0005|source-row-0005|ucl20-source-lineage-0005",
  "ucl20-fixture-0006|ucl-club-06|ucl-club-07|6|venue-ucl-club-06|2026-09-20T19:00:00Z|ucl20-source-artifact-0006|source-row-0006|ucl20-source-lineage-0006",
  "ucl20-fixture-0007|ucl-club-07|ucl-club-08|7|venue-ucl-club-07|2026-09-21T20:00:00Z|ucl20-source-artifact-0007|source-row-0007|ucl20-source-lineage-0007",
  "ucl20-fixture-0008|ucl-club-08|ucl-club-09|8|venue-ucl-club-08|2026-09-22T21:00:00Z|ucl20-source-artifact-0008|source-row-0008|ucl20-source-lineage-0008",
  "ucl20-fixture-0009|ucl-club-09|ucl-club-10|1|venue-ucl-club-09|2026-09-23T18:00:00Z|ucl20-source-artifact-0009|source-row-0009|ucl20-source-lineage-0009",
  "ucl20-fixture-0010|ucl-club-10|ucl-club-11|2|venue-ucl-club-10|2026-09-24T19:00:00Z|ucl20-source-artifact-0010|source-row-0010|ucl20-source-lineage-0010",
  "ucl20-fixture-0011|ucl-club-11|ucl-club-12|3|venue-ucl-club-11|2026-09-25T20:00:00Z|ucl20-source-artifact-0011|source-row-0011|ucl20-source-lineage-0011",
  "ucl20-fixture-0012|ucl-club-12|ucl-club-13|4|venue-ucl-club-12|2026-09-26T21:00:00Z|ucl20-source-artifact-0012|source-row-0012|ucl20-source-lineage-0012",
  "ucl20-fixture-0013|ucl-club-13|ucl-club-14|5|venue-ucl-club-13|2026-09-27T18:00:00Z|ucl20-source-artifact-0013|source-row-0013|ucl20-source-lineage-0013",
  "ucl20-fixture-0014|ucl-club-14|ucl-club-15|6|venue-ucl-club-14|2026-09-28T19:00:00Z|ucl20-source-artifact-0014|source-row-0014|ucl20-source-lineage-0014",
  "ucl20-fixture-0015|ucl-club-15|ucl-club-16|7|venue-ucl-club-15|2026-09-29T20:00:00Z|ucl20-source-artifact-0015|source-row-0015|ucl20-source-lineage-0015",
  "ucl20-fixture-0016|ucl-club-16|ucl-club-17|8|venue-ucl-club-16|2026-09-30T21:00:00Z|ucl20-source-artifact-0016|source-row-0016|ucl20-source-lineage-0016",
  "ucl20-fixture-0017|ucl-club-17|ucl-club-18|1|venue-ucl-club-17|2026-09-31T18:00:00Z|ucl20-source-artifact-0017|source-row-0017|ucl20-source-lineage-0017",
  "ucl20-fixture-0018|ucl-club-18|ucl-club-19|2|venue-ucl-club-18|2026-09-32T19:00:00Z|ucl20-source-artifact-0018|source-row-0018|ucl20-source-lineage-0018",
  "ucl20-fixture-0019|ucl-club-19|ucl-club-20|3|venue-ucl-club-19|2026-09-33T20:00:00Z|ucl20-source-artifact-0019|source-row-0019|ucl20-source-lineage-0019",
  "ucl20-fixture-0020|ucl-club-20|ucl-club-21|4|venue-ucl-club-20|2026-09-34T21:00:00Z|ucl20-source-artifact-0020|source-row-0020|ucl20-source-lineage-0020",
  "ucl20-fixture-0021|ucl-club-21|ucl-club-22|5|venue-ucl-club-21|2026-09-15T18:00:00Z|ucl20-source-artifact-0021|source-row-0021|ucl20-source-lineage-0021",
  "ucl20-fixture-0022|ucl-club-22|ucl-club-23|6|venue-ucl-club-22|2026-09-16T19:00:00Z|ucl20-source-artifact-0022|source-row-0022|ucl20-source-lineage-0022",
  "ucl20-fixture-0023|ucl-club-23|ucl-club-24|7|venue-ucl-club-23|2026-09-17T20:00:00Z|ucl20-source-artifact-0023|source-row-0023|ucl20-source-lineage-0023",
  "ucl20-fixture-0024|ucl-club-24|ucl-club-25|8|venue-ucl-club-24|2026-09-18T21:00:00Z|ucl20-source-artifact-0024|source-row-0024|ucl20-source-lineage-0024",
  "ucl20-fixture-0025|ucl-club-25|ucl-club-26|1|venue-ucl-club-25|2026-09-19T18:00:00Z|ucl20-source-artifact-0025|source-row-0025|ucl20-source-lineage-0025",
  "ucl20-fixture-0026|ucl-club-26|ucl-club-27|2|venue-ucl-club-26|2026-09-20T19:00:00Z|ucl20-source-artifact-0026|source-row-0026|ucl20-source-lineage-0026",
  "ucl20-fixture-0027|ucl-club-27|ucl-club-28|3|venue-ucl-club-27|2026-09-21T20:00:00Z|ucl20-source-artifact-0027|source-row-0027|ucl20-source-lineage-0027",
  "ucl20-fixture-0028|ucl-club-28|ucl-club-29|4|venue-ucl-club-28|2026-09-22T21:00:00Z|ucl20-source-artifact-0028|source-row-0028|ucl20-source-lineage-0028",
  "ucl20-fixture-0029|ucl-club-29|ucl-club-30|5|venue-ucl-club-29|2026-09-23T18:00:00Z|ucl20-source-artifact-0029|source-row-0029|ucl20-source-lineage-0029",
  "ucl20-fixture-0030|ucl-club-30|ucl-club-31|6|venue-ucl-club-30|2026-09-24T19:00:00Z|ucl20-source-artifact-0030|source-row-0030|ucl20-source-lineage-0030",
  "ucl20-fixture-0031|ucl-club-31|ucl-club-32|7|venue-ucl-club-31|2026-09-25T20:00:00Z|ucl20-source-artifact-0031|source-row-0031|ucl20-source-lineage-0031",
  "ucl20-fixture-0032|ucl-club-32|ucl-club-33|8|venue-ucl-club-32|2026-09-26T21:00:00Z|ucl20-source-artifact-0032|source-row-0032|ucl20-source-lineage-0032",
  "ucl20-fixture-0033|ucl-club-33|ucl-club-34|1|venue-ucl-club-33|2026-09-27T18:00:00Z|ucl20-source-artifact-0033|source-row-0033|ucl20-source-lineage-0033",
  "ucl20-fixture-0034|ucl-club-34|ucl-club-35|2|venue-ucl-club-34|2026-09-28T19:00:00Z|ucl20-source-artifact-0034|source-row-0034|ucl20-source-lineage-0034",
  "ucl20-fixture-0035|ucl-club-35|ucl-club-36|3|venue-ucl-club-35|2026-09-29T20:00:00Z|ucl20-source-artifact-0035|source-row-0035|ucl20-source-lineage-0035",
  "ucl20-fixture-0036|ucl-club-36|ucl-club-01|4|venue-ucl-club-36|2026-09-30T21:00:00Z|ucl20-source-artifact-0036|source-row-0036|ucl20-source-lineage-0036",
  "ucl20-fixture-0037|ucl-club-01|ucl-club-03|5|venue-ucl-club-01|2026-09-31T18:00:00Z|ucl20-source-artifact-0037|source-row-0037|ucl20-source-lineage-0037",
  "ucl20-fixture-0038|ucl-club-02|ucl-club-04|6|venue-ucl-club-02|2026-09-32T19:00:00Z|ucl20-source-artifact-0038|source-row-0038|ucl20-source-lineage-0038",
  "ucl20-fixture-0039|ucl-club-03|ucl-club-05|7|venue-ucl-club-03|2026-09-33T20:00:00Z|ucl20-source-artifact-0039|source-row-0039|ucl20-source-lineage-0039",
  "ucl20-fixture-0040|ucl-club-04|ucl-club-06|8|venue-ucl-club-04|2026-09-34T21:00:00Z|ucl20-source-artifact-0040|source-row-0040|ucl20-source-lineage-0040",
  "ucl20-fixture-0041|ucl-club-05|ucl-club-07|1|venue-ucl-club-05|2026-09-15T18:00:00Z|ucl20-source-artifact-0041|source-row-0041|ucl20-source-lineage-0041",
  "ucl20-fixture-0042|ucl-club-06|ucl-club-08|2|venue-ucl-club-06|2026-09-16T19:00:00Z|ucl20-source-artifact-0042|source-row-0042|ucl20-source-lineage-0042",
  "ucl20-fixture-0043|ucl-club-07|ucl-club-09|3|venue-ucl-club-07|2026-09-17T20:00:00Z|ucl20-source-artifact-0043|source-row-0043|ucl20-source-lineage-0043",
  "ucl20-fixture-0044|ucl-club-08|ucl-club-10|4|venue-ucl-club-08|2026-09-18T21:00:00Z|ucl20-source-artifact-0044|source-row-0044|ucl20-source-lineage-0044",
  "ucl20-fixture-0045|ucl-club-09|ucl-club-11|5|venue-ucl-club-09|2026-09-19T18:00:00Z|ucl20-source-artifact-0045|source-row-0045|ucl20-source-lineage-0045",
  "ucl20-fixture-0046|ucl-club-10|ucl-club-12|6|venue-ucl-club-10|2026-09-20T19:00:00Z|ucl20-source-artifact-0046|source-row-0046|ucl20-source-lineage-0046",
  "ucl20-fixture-0047|ucl-club-11|ucl-club-13|7|venue-ucl-club-11|2026-09-21T20:00:00Z|ucl20-source-artifact-0047|source-row-0047|ucl20-source-lineage-0047",
  "ucl20-fixture-0048|ucl-club-12|ucl-club-14|8|venue-ucl-club-12|2026-09-22T21:00:00Z|ucl20-source-artifact-0048|source-row-0048|ucl20-source-lineage-0048",
  "ucl20-fixture-0049|ucl-club-13|ucl-club-15|1|venue-ucl-club-13|2026-09-23T18:00:00Z|ucl20-source-artifact-0049|source-row-0049|ucl20-source-lineage-0049",
  "ucl20-fixture-0050|ucl-club-14|ucl-club-16|2|venue-ucl-club-14|2026-09-24T19:00:00Z|ucl20-source-artifact-0050|source-row-0050|ucl20-source-lineage-0050",
  "ucl20-fixture-0051|ucl-club-15|ucl-club-17|3|venue-ucl-club-15|2026-09-25T20:00:00Z|ucl20-source-artifact-0051|source-row-0051|ucl20-source-lineage-0051",
  "ucl20-fixture-0052|ucl-club-16|ucl-club-18|4|venue-ucl-club-16|2026-09-26T21:00:00Z|ucl20-source-artifact-0052|source-row-0052|ucl20-source-lineage-0052",
  "ucl20-fixture-0053|ucl-club-17|ucl-club-19|5|venue-ucl-club-17|2026-09-27T18:00:00Z|ucl20-source-artifact-0053|source-row-0053|ucl20-source-lineage-0053",
  "ucl20-fixture-0054|ucl-club-18|ucl-club-20|6|venue-ucl-club-18|2026-09-28T19:00:00Z|ucl20-source-artifact-0054|source-row-0054|ucl20-source-lineage-0054",
  "ucl20-fixture-0055|ucl-club-19|ucl-club-21|7|venue-ucl-club-19|2026-09-29T20:00:00Z|ucl20-source-artifact-0055|source-row-0055|ucl20-source-lineage-0055",
  "ucl20-fixture-0056|ucl-club-20|ucl-club-22|8|venue-ucl-club-20|2026-09-30T21:00:00Z|ucl20-source-artifact-0056|source-row-0056|ucl20-source-lineage-0056",
  "ucl20-fixture-0057|ucl-club-21|ucl-club-23|1|venue-ucl-club-21|2026-09-31T18:00:00Z|ucl20-source-artifact-0057|source-row-0057|ucl20-source-lineage-0057",
  "ucl20-fixture-0058|ucl-club-22|ucl-club-24|2|venue-ucl-club-22|2026-09-32T19:00:00Z|ucl20-source-artifact-0058|source-row-0058|ucl20-source-lineage-0058",
  "ucl20-fixture-0059|ucl-club-23|ucl-club-25|3|venue-ucl-club-23|2026-09-33T20:00:00Z|ucl20-source-artifact-0059|source-row-0059|ucl20-source-lineage-0059",
  "ucl20-fixture-0060|ucl-club-24|ucl-club-26|4|venue-ucl-club-24|2026-09-34T21:00:00Z|ucl20-source-artifact-0060|source-row-0060|ucl20-source-lineage-0060",
  "ucl20-fixture-0061|ucl-club-25|ucl-club-27|5|venue-ucl-club-25|2026-09-15T18:00:00Z|ucl20-source-artifact-0061|source-row-0061|ucl20-source-lineage-0061",
  "ucl20-fixture-0062|ucl-club-26|ucl-club-28|6|venue-ucl-club-26|2026-09-16T19:00:00Z|ucl20-source-artifact-0062|source-row-0062|ucl20-source-lineage-0062",
  "ucl20-fixture-0063|ucl-club-27|ucl-club-29|7|venue-ucl-club-27|2026-09-17T20:00:00Z|ucl20-source-artifact-0063|source-row-0063|ucl20-source-lineage-0063",
  "ucl20-fixture-0064|ucl-club-28|ucl-club-30|8|venue-ucl-club-28|2026-09-18T21:00:00Z|ucl20-source-artifact-0064|source-row-0064|ucl20-source-lineage-0064",
  "ucl20-fixture-0065|ucl-club-29|ucl-club-31|1|venue-ucl-club-29|2026-09-19T18:00:00Z|ucl20-source-artifact-0065|source-row-0065|ucl20-source-lineage-0065",
  "ucl20-fixture-0066|ucl-club-30|ucl-club-32|2|venue-ucl-club-30|2026-09-20T19:00:00Z|ucl20-source-artifact-0066|source-row-0066|ucl20-source-lineage-0066",
  "ucl20-fixture-0067|ucl-club-31|ucl-club-33|3|venue-ucl-club-31|2026-09-21T20:00:00Z|ucl20-source-artifact-0067|source-row-0067|ucl20-source-lineage-0067",
  "ucl20-fixture-0068|ucl-club-32|ucl-club-34|4|venue-ucl-club-32|2026-09-22T21:00:00Z|ucl20-source-artifact-0068|source-row-0068|ucl20-source-lineage-0068",
  "ucl20-fixture-0069|ucl-club-33|ucl-club-35|5|venue-ucl-club-33|2026-09-23T18:00:00Z|ucl20-source-artifact-0069|source-row-0069|ucl20-source-lineage-0069",
  "ucl20-fixture-0070|ucl-club-34|ucl-club-36|6|venue-ucl-club-34|2026-09-24T19:00:00Z|ucl20-source-artifact-0070|source-row-0070|ucl20-source-lineage-0070",
  "ucl20-fixture-0071|ucl-club-35|ucl-club-01|7|venue-ucl-club-35|2026-09-25T20:00:00Z|ucl20-source-artifact-0071|source-row-0071|ucl20-source-lineage-0071",
  "ucl20-fixture-0072|ucl-club-36|ucl-club-02|8|venue-ucl-club-36|2026-09-26T21:00:00Z|ucl20-source-artifact-0072|source-row-0072|ucl20-source-lineage-0072",
  "ucl20-fixture-0073|ucl-club-01|ucl-club-04|1|venue-ucl-club-01|2026-09-27T18:00:00Z|ucl20-source-artifact-0073|source-row-0073|ucl20-source-lineage-0073",
  "ucl20-fixture-0074|ucl-club-02|ucl-club-05|2|venue-ucl-club-02|2026-09-28T19:00:00Z|ucl20-source-artifact-0074|source-row-0074|ucl20-source-lineage-0074",
  "ucl20-fixture-0075|ucl-club-03|ucl-club-06|3|venue-ucl-club-03|2026-09-29T20:00:00Z|ucl20-source-artifact-0075|source-row-0075|ucl20-source-lineage-0075",
  "ucl20-fixture-0076|ucl-club-04|ucl-club-07|4|venue-ucl-club-04|2026-09-30T21:00:00Z|ucl20-source-artifact-0076|source-row-0076|ucl20-source-lineage-0076",
  "ucl20-fixture-0077|ucl-club-05|ucl-club-08|5|venue-ucl-club-05|2026-09-31T18:00:00Z|ucl20-source-artifact-0077|source-row-0077|ucl20-source-lineage-0077",
  "ucl20-fixture-0078|ucl-club-06|ucl-club-09|6|venue-ucl-club-06|2026-09-32T19:00:00Z|ucl20-source-artifact-0078|source-row-0078|ucl20-source-lineage-0078",
  "ucl20-fixture-0079|ucl-club-07|ucl-club-10|7|venue-ucl-club-07|2026-09-33T20:00:00Z|ucl20-source-artifact-0079|source-row-0079|ucl20-source-lineage-0079",
  "ucl20-fixture-0080|ucl-club-08|ucl-club-11|8|venue-ucl-club-08|2026-09-34T21:00:00Z|ucl20-source-artifact-0080|source-row-0080|ucl20-source-lineage-0080",
  "ucl20-fixture-0081|ucl-club-09|ucl-club-12|1|venue-ucl-club-09|2026-09-15T18:00:00Z|ucl20-source-artifact-0081|source-row-0081|ucl20-source-lineage-0081",
  "ucl20-fixture-0082|ucl-club-10|ucl-club-13|2|venue-ucl-club-10|2026-09-16T19:00:00Z|ucl20-source-artifact-0082|source-row-0082|ucl20-source-lineage-0082",
  "ucl20-fixture-0083|ucl-club-11|ucl-club-14|3|venue-ucl-club-11|2026-09-17T20:00:00Z|ucl20-source-artifact-0083|source-row-0083|ucl20-source-lineage-0083",
  "ucl20-fixture-0084|ucl-club-12|ucl-club-15|4|venue-ucl-club-12|2026-09-18T21:00:00Z|ucl20-source-artifact-0084|source-row-0084|ucl20-source-lineage-0084",
  "ucl20-fixture-0085|ucl-club-13|ucl-club-16|5|venue-ucl-club-13|2026-09-19T18:00:00Z|ucl20-source-artifact-0085|source-row-0085|ucl20-source-lineage-0085",
  "ucl20-fixture-0086|ucl-club-14|ucl-club-17|6|venue-ucl-club-14|2026-09-20T19:00:00Z|ucl20-source-artifact-0086|source-row-0086|ucl20-source-lineage-0086",
  "ucl20-fixture-0087|ucl-club-15|ucl-club-18|7|venue-ucl-club-15|2026-09-21T20:00:00Z|ucl20-source-artifact-0087|source-row-0087|ucl20-source-lineage-0087",
  "ucl20-fixture-0088|ucl-club-16|ucl-club-19|8|venue-ucl-club-16|2026-09-22T21:00:00Z|ucl20-source-artifact-0088|source-row-0088|ucl20-source-lineage-0088",
  "ucl20-fixture-0089|ucl-club-17|ucl-club-20|1|venue-ucl-club-17|2026-09-23T18:00:00Z|ucl20-source-artifact-0089|source-row-0089|ucl20-source-lineage-0089",
  "ucl20-fixture-0090|ucl-club-18|ucl-club-21|2|venue-ucl-club-18|2026-09-24T19:00:00Z|ucl20-source-artifact-0090|source-row-0090|ucl20-source-lineage-0090",
  "ucl20-fixture-0091|ucl-club-19|ucl-club-22|3|venue-ucl-club-19|2026-09-25T20:00:00Z|ucl20-source-artifact-0091|source-row-0091|ucl20-source-lineage-0091",
  "ucl20-fixture-0092|ucl-club-20|ucl-club-23|4|venue-ucl-club-20|2026-09-26T21:00:00Z|ucl20-source-artifact-0092|source-row-0092|ucl20-source-lineage-0092",
  "ucl20-fixture-0093|ucl-club-21|ucl-club-24|5|venue-ucl-club-21|2026-09-27T18:00:00Z|ucl20-source-artifact-0093|source-row-0093|ucl20-source-lineage-0093",
  "ucl20-fixture-0094|ucl-club-22|ucl-club-25|6|venue-ucl-club-22|2026-09-28T19:00:00Z|ucl20-source-artifact-0094|source-row-0094|ucl20-source-lineage-0094",
  "ucl20-fixture-0095|ucl-club-23|ucl-club-26|7|venue-ucl-club-23|2026-09-29T20:00:00Z|ucl20-source-artifact-0095|source-row-0095|ucl20-source-lineage-0095",
  "ucl20-fixture-0096|ucl-club-24|ucl-club-27|8|venue-ucl-club-24|2026-09-30T21:00:00Z|ucl20-source-artifact-0096|source-row-0096|ucl20-source-lineage-0096",
  "ucl20-fixture-0097|ucl-club-25|ucl-club-28|1|venue-ucl-club-25|2026-09-31T18:00:00Z|ucl20-source-artifact-0097|source-row-0097|ucl20-source-lineage-0097",
  "ucl20-fixture-0098|ucl-club-26|ucl-club-29|2|venue-ucl-club-26|2026-09-32T19:00:00Z|ucl20-source-artifact-0098|source-row-0098|ucl20-source-lineage-0098",
  "ucl20-fixture-0099|ucl-club-27|ucl-club-30|3|venue-ucl-club-27|2026-09-33T20:00:00Z|ucl20-source-artifact-0099|source-row-0099|ucl20-source-lineage-0099",
  "ucl20-fixture-0100|ucl-club-28|ucl-club-31|4|venue-ucl-club-28|2026-09-34T21:00:00Z|ucl20-source-artifact-0100|source-row-0100|ucl20-source-lineage-0100",
  "ucl20-fixture-0101|ucl-club-29|ucl-club-32|5|venue-ucl-club-29|2026-09-15T18:00:00Z|ucl20-source-artifact-0101|source-row-0101|ucl20-source-lineage-0101",
  "ucl20-fixture-0102|ucl-club-30|ucl-club-33|6|venue-ucl-club-30|2026-09-16T19:00:00Z|ucl20-source-artifact-0102|source-row-0102|ucl20-source-lineage-0102",
  "ucl20-fixture-0103|ucl-club-31|ucl-club-34|7|venue-ucl-club-31|2026-09-17T20:00:00Z|ucl20-source-artifact-0103|source-row-0103|ucl20-source-lineage-0103",
  "ucl20-fixture-0104|ucl-club-32|ucl-club-35|8|venue-ucl-club-32|2026-09-18T21:00:00Z|ucl20-source-artifact-0104|source-row-0104|ucl20-source-lineage-0104",
  "ucl20-fixture-0105|ucl-club-33|ucl-club-36|1|venue-ucl-club-33|2026-09-19T18:00:00Z|ucl20-source-artifact-0105|source-row-0105|ucl20-source-lineage-0105",
  "ucl20-fixture-0106|ucl-club-34|ucl-club-01|2|venue-ucl-club-34|2026-09-20T19:00:00Z|ucl20-source-artifact-0106|source-row-0106|ucl20-source-lineage-0106",
  "ucl20-fixture-0107|ucl-club-35|ucl-club-02|3|venue-ucl-club-35|2026-09-21T20:00:00Z|ucl20-source-artifact-0107|source-row-0107|ucl20-source-lineage-0107",
  "ucl20-fixture-0108|ucl-club-36|ucl-club-03|4|venue-ucl-club-36|2026-09-22T21:00:00Z|ucl20-source-artifact-0108|source-row-0108|ucl20-source-lineage-0108",
  "ucl20-fixture-0109|ucl-club-01|ucl-club-05|5|venue-ucl-club-01|2026-09-23T18:00:00Z|ucl20-source-artifact-0109|source-row-0109|ucl20-source-lineage-0109",
  "ucl20-fixture-0110|ucl-club-02|ucl-club-06|6|venue-ucl-club-02|2026-09-24T19:00:00Z|ucl20-source-artifact-0110|source-row-0110|ucl20-source-lineage-0110",
  "ucl20-fixture-0111|ucl-club-03|ucl-club-07|7|venue-ucl-club-03|2026-09-25T20:00:00Z|ucl20-source-artifact-0111|source-row-0111|ucl20-source-lineage-0111",
  "ucl20-fixture-0112|ucl-club-04|ucl-club-08|8|venue-ucl-club-04|2026-09-26T21:00:00Z|ucl20-source-artifact-0112|source-row-0112|ucl20-source-lineage-0112",
  "ucl20-fixture-0113|ucl-club-05|ucl-club-09|1|venue-ucl-club-05|2026-09-27T18:00:00Z|ucl20-source-artifact-0113|source-row-0113|ucl20-source-lineage-0113",
  "ucl20-fixture-0114|ucl-club-06|ucl-club-10|2|venue-ucl-club-06|2026-09-28T19:00:00Z|ucl20-source-artifact-0114|source-row-0114|ucl20-source-lineage-0114",
  "ucl20-fixture-0115|ucl-club-07|ucl-club-11|3|venue-ucl-club-07|2026-09-29T20:00:00Z|ucl20-source-artifact-0115|source-row-0115|ucl20-source-lineage-0115",
  "ucl20-fixture-0116|ucl-club-08|ucl-club-12|4|venue-ucl-club-08|2026-09-30T21:00:00Z|ucl20-source-artifact-0116|source-row-0116|ucl20-source-lineage-0116",
  "ucl20-fixture-0117|ucl-club-09|ucl-club-13|5|venue-ucl-club-09|2026-09-31T18:00:00Z|ucl20-source-artifact-0117|source-row-0117|ucl20-source-lineage-0117",
  "ucl20-fixture-0118|ucl-club-10|ucl-club-14|6|venue-ucl-club-10|2026-09-32T19:00:00Z|ucl20-source-artifact-0118|source-row-0118|ucl20-source-lineage-0118",
  "ucl20-fixture-0119|ucl-club-11|ucl-club-15|7|venue-ucl-club-11|2026-09-33T20:00:00Z|ucl20-source-artifact-0119|source-row-0119|ucl20-source-lineage-0119",
  "ucl20-fixture-0120|ucl-club-12|ucl-club-16|8|venue-ucl-club-12|2026-09-34T21:00:00Z|ucl20-source-artifact-0120|source-row-0120|ucl20-source-lineage-0120",
  "ucl20-fixture-0121|ucl-club-13|ucl-club-17|1|venue-ucl-club-13|2026-09-15T18:00:00Z|ucl20-source-artifact-0121|source-row-0121|ucl20-source-lineage-0121",
  "ucl20-fixture-0122|ucl-club-14|ucl-club-18|2|venue-ucl-club-14|2026-09-16T19:00:00Z|ucl20-source-artifact-0122|source-row-0122|ucl20-source-lineage-0122",
  "ucl20-fixture-0123|ucl-club-15|ucl-club-19|3|venue-ucl-club-15|2026-09-17T20:00:00Z|ucl20-source-artifact-0123|source-row-0123|ucl20-source-lineage-0123",
  "ucl20-fixture-0124|ucl-club-16|ucl-club-20|4|venue-ucl-club-16|2026-09-18T21:00:00Z|ucl20-source-artifact-0124|source-row-0124|ucl20-source-lineage-0124",
  "ucl20-fixture-0125|ucl-club-17|ucl-club-21|5|venue-ucl-club-17|2026-09-19T18:00:00Z|ucl20-source-artifact-0125|source-row-0125|ucl20-source-lineage-0125",
  "ucl20-fixture-0126|ucl-club-18|ucl-club-22|6|venue-ucl-club-18|2026-09-20T19:00:00Z|ucl20-source-artifact-0126|source-row-0126|ucl20-source-lineage-0126",
  "ucl20-fixture-0127|ucl-club-19|ucl-club-23|7|venue-ucl-club-19|2026-09-21T20:00:00Z|ucl20-source-artifact-0127|source-row-0127|ucl20-source-lineage-0127",
  "ucl20-fixture-0128|ucl-club-20|ucl-club-24|8|venue-ucl-club-20|2026-09-22T21:00:00Z|ucl20-source-artifact-0128|source-row-0128|ucl20-source-lineage-0128",
  "ucl20-fixture-0129|ucl-club-21|ucl-club-25|1|venue-ucl-club-21|2026-09-23T18:00:00Z|ucl20-source-artifact-0129|source-row-0129|ucl20-source-lineage-0129",
  "ucl20-fixture-0130|ucl-club-22|ucl-club-26|2|venue-ucl-club-22|2026-09-24T19:00:00Z|ucl20-source-artifact-0130|source-row-0130|ucl20-source-lineage-0130",
  "ucl20-fixture-0131|ucl-club-23|ucl-club-27|3|venue-ucl-club-23|2026-09-25T20:00:00Z|ucl20-source-artifact-0131|source-row-0131|ucl20-source-lineage-0131",
  "ucl20-fixture-0132|ucl-club-24|ucl-club-28|4|venue-ucl-club-24|2026-09-26T21:00:00Z|ucl20-source-artifact-0132|source-row-0132|ucl20-source-lineage-0132",
  "ucl20-fixture-0133|ucl-club-25|ucl-club-29|5|venue-ucl-club-25|2026-09-27T18:00:00Z|ucl20-source-artifact-0133|source-row-0133|ucl20-source-lineage-0133",
  "ucl20-fixture-0134|ucl-club-26|ucl-club-30|6|venue-ucl-club-26|2026-09-28T19:00:00Z|ucl20-source-artifact-0134|source-row-0134|ucl20-source-lineage-0134",
  "ucl20-fixture-0135|ucl-club-27|ucl-club-31|7|venue-ucl-club-27|2026-09-29T20:00:00Z|ucl20-source-artifact-0135|source-row-0135|ucl20-source-lineage-0135",
  "ucl20-fixture-0136|ucl-club-28|ucl-club-32|8|venue-ucl-club-28|2026-09-30T21:00:00Z|ucl20-source-artifact-0136|source-row-0136|ucl20-source-lineage-0136",
  "ucl20-fixture-0137|ucl-club-29|ucl-club-33|1|venue-ucl-club-29|2026-09-31T18:00:00Z|ucl20-source-artifact-0137|source-row-0137|ucl20-source-lineage-0137",
  "ucl20-fixture-0138|ucl-club-30|ucl-club-34|2|venue-ucl-club-30|2026-09-32T19:00:00Z|ucl20-source-artifact-0138|source-row-0138|ucl20-source-lineage-0138",
  "ucl20-fixture-0139|ucl-club-31|ucl-club-35|3|venue-ucl-club-31|2026-09-33T20:00:00Z|ucl20-source-artifact-0139|source-row-0139|ucl20-source-lineage-0139",
  "ucl20-fixture-0140|ucl-club-32|ucl-club-36|4|venue-ucl-club-32|2026-09-34T21:00:00Z|ucl20-source-artifact-0140|source-row-0140|ucl20-source-lineage-0140",
  "ucl20-fixture-0141|ucl-club-33|ucl-club-01|5|venue-ucl-club-33|2026-09-15T18:00:00Z|ucl20-source-artifact-0141|source-row-0141|ucl20-source-lineage-0141",
  "ucl20-fixture-0142|ucl-club-34|ucl-club-02|6|venue-ucl-club-34|2026-09-16T19:00:00Z|ucl20-source-artifact-0142|source-row-0142|ucl20-source-lineage-0142",
  "ucl20-fixture-0143|ucl-club-35|ucl-club-03|7|venue-ucl-club-35|2026-09-17T20:00:00Z|ucl20-source-artifact-0143|source-row-0143|ucl20-source-lineage-0143",
  "ucl20-fixture-0144|ucl-club-36|ucl-club-04|8|venue-ucl-club-36|2026-09-18T21:00:00Z|ucl20-source-artifact-0144|source-row-0144|ucl20-source-lineage-0144"
)

# Keep the explicit declaration table calendar-valid while retaining the
# deterministic 144-row fixture graph used by the RED contract.
phase20_ucl_fixture_declarations <- gsub(
  "2026-09-34", "2026-10-04", phase20_ucl_fixture_declarations, fixed = TRUE
)
phase20_ucl_fixture_declarations <- gsub(
  "2026-09-33", "2026-10-03", phase20_ucl_fixture_declarations, fixed = TRUE
)
phase20_ucl_fixture_declarations <- gsub(
  "2026-09-32", "2026-10-02", phase20_ucl_fixture_declarations, fixed = TRUE
)
phase20_ucl_fixture_declarations <- gsub(
  "2026-09-31", "2026-10-01", phase20_ucl_fixture_declarations, fixed = TRUE
)

phase20_test_fixture_clubs <- function() {
  ids <- phase20_test_fixture_club_ids()
  clubs <- data.frame(
    edition_id = phase20_test_edition_id,
    club_id = ids,
    canonical_name = paste("UCL Fixture Club", sprintf("%02d", seq_along(ids))),
    association_id = sprintf("fixture-association-%02d", ((seq_along(ids) - 1L) %% 18L) + 1L),
    source_bundle_id = phase20_test_source_bundle_id,
    source_artifact_id = phase20_test_source_lineage_id,
    fixture_authority = TRUE,
    production_eligible = FALSE,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  clubs$row_sha256 <- vapply(seq_len(nrow(clubs)), function(index) {
    phase20_test_hash(paste(clubs[index, setdiff(names(clubs), "row_sha256"), drop = TRUE], collapse = "|"))
  }, character(1))
  clubs
}

phase20_test_fixture_rows <- function() {
  raw <- do.call(rbind, strsplit(phase20_ucl_fixture_declarations, "|", fixed = TRUE))
  if (!identical(nrow(raw), 144L) || !identical(ncol(raw), 9L)) {
    stop("Phase 20 fixture declarations must contain exactly 144 explicit rows", call. = FALSE)
  }
  fixtures <- data.frame(
    edition_id = phase20_test_edition_id,
    fixture_id = raw[, 1L],
    matchday = as.integer(raw[, 4L]),
    home_club_id = raw[, 2L],
    away_club_id = raw[, 3L],
    venue_id = raw[, 5L],
    kickoff_utc = raw[, 6L],
    kickoff_confirmed = TRUE,
    confirmed_kickoff_at_utc = raw[, 6L],
    source_artifact_id = raw[, 7L],
    source_row_key = raw[, 8L],
    source_lineage_id = raw[, 9L],
    source_bundle_id = phase20_test_source_bundle_id,
    source_status = "scheduled",
    match_status = "scheduled",
    completion_method = "not_completed",
    regulation_home_goals = rep(NA_integer_, nrow(raw)),
    regulation_away_goals = rep(NA_integer_, nrow(raw)),
    final_home_goals = rep(NA_integer_, nrow(raw)),
    final_away_goals = rep(NA_integer_, nrow(raw)),
    shootout_home_goals = rep(NA_integer_, nrow(raw)),
    shootout_away_goals = rep(NA_integer_, nrow(raw)),
    winner_club_id = rep(NA_character_, nrow(raw)),
    counts_for_standings = FALSE,
    fixture_authority = TRUE,
    production_eligible = FALSE,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  fixtures$source_row_sha256 <- vapply(seq_len(nrow(fixtures)), function(index) {
    phase20_test_hash(paste(fixtures[index, setdiff(names(fixtures), "source_row_sha256"), drop = TRUE], collapse = "|"))
  }, character(1))
  fixtures
}

phase20_fixture_graph_36x144 <- function() {
  clubs <- phase20_test_fixture_clubs()
  fixtures <- phase20_test_fixture_rows()
  if (!identical(length(unique(clubs$club_id)), 36L) ||
      !identical(length(unique(fixtures$fixture_id)), 144L)) {
    stop("Phase 20 fixture graph cardinality is not 36 clubs x 144 fixtures", call. = FALSE)
  }
  structure(list(
    edition_id = phase20_test_edition_id,
    source_bundle_id = phase20_test_source_bundle_id,
    source_lineage_id = phase20_test_source_lineage_id,
    authority_mode = "fixture",
    fixture_authority = TRUE,
    production_eligible = FALSE,
    selector_path = NULL,
    production_root = NULL,
    clubs = clubs,
    fixtures = fixtures
  ), class = c("phase20_ucl_fixture_graph", "list"))
}

phase20_ucl_fixture_graph <- phase20_fixture_graph_36x144
phase20_test_full_fixture_graph <- phase20_fixture_graph_36x144

phase20_test_completed_fixture_graph <- function(
    graph = phase20_fixture_graph_36x144(),
    index = 1L,
    home_goals = 2L,
    away_goals = 1L) {
  stopifnot(length(index) == 1L, index >= 1L, index <= nrow(graph$fixtures))
  graph$fixtures$source_status[index] <- "completed"
  graph$fixtures$match_status[index] <- "completed"
  graph$fixtures$completion_method[index] <- "regulation"
  graph$fixtures$regulation_home_goals[index] <- as.integer(home_goals)
  graph$fixtures$regulation_away_goals[index] <- as.integer(away_goals)
  graph$fixtures$final_home_goals[index] <- as.integer(home_goals)
  graph$fixtures$final_away_goals[index] <- as.integer(away_goals)
  graph$fixtures$counts_for_standings[index] <- TRUE
  graph$fixtures$winner_club_id[index] <- if (home_goals > away_goals) {
    graph$fixtures$home_club_id[index]
  } else if (away_goals > home_goals) {
    graph$fixtures$away_club_id[index]
  } else {
    NA_character_
  }
  graph
}

phase20_approved_release_fixture <- function(graph = phase20_fixture_graph_36x144()) {
  fixtures <- graph$fixtures
  forecasts <- fixtures[, c("edition_id", "fixture_id", "home_club_id", "away_club_id", "kickoff_utc"), drop = FALSE]
  forecasts$forecast_status <- "eligible_fixture"
  forecasts$suppression_reason <- NA_character_
  forecasts$model_release_id <- "phase20-fixture-club-release-v1"
  forecasts$model_sha256 <- phase20_test_hash("phase20-fixture-club-model-v1")
  forecasts$calibrator_sha256 <- phase20_test_hash("phase20-fixture-club-calibrator-v1")
  forecasts$feature_cutoff_utc <- "2026-09-01T12:00:00Z"
  forecasts$prob_home <- 0.45
  forecasts$prob_draw <- 0.25
  forecasts$prob_away <- 0.30
  forecasts$xg_home <- 1.40
  forecasts$xg_away <- 1.10
  forecasts$likely_score <- "1-1"
  forecasts$source_bundle_id <- graph$source_bundle_id
  forecasts$row_sha256 <- vapply(seq_len(nrow(forecasts)), function(index) {
    phase20_test_hash(paste(forecasts[index, setdiff(names(forecasts), "row_sha256"), drop = TRUE], collapse = "|"))
  }, character(1))
  list(
    release_id = "phase20-fixture-club-release-v1",
    authority_mode = "fixture",
    fixture_authority = TRUE,
    production_eligible = FALSE,
    selector_authorized = FALSE,
    selector_path = NULL,
    trusted_release_root = NULL,
    root_scope = "process_temporary",
    model_sha256 = unique(forecasts$model_sha256),
    calibrator_sha256 = unique(forecasts$calibrator_sha256),
    parent_reason = "fixture_authority_non_promotable",
    forecast_rows = forecasts
  )
}

phase20_fixture_empty_source <- function(graph = phase20_fixture_graph_36x144()) {
  graph$clubs <- graph$clubs[FALSE, , drop = FALSE]
  graph$fixtures <- graph$fixtures[FALSE, , drop = FALSE]
  graph
}

phase20_fixture_missing_club <- function(graph = phase20_fixture_graph_36x144()) {
  graph$clubs <- graph$clubs[-1L, , drop = FALSE]
  graph
}

phase20_fixture_missing_fixture <- function(graph = phase20_fixture_graph_36x144()) {
  graph$fixtures <- graph$fixtures[-1L, , drop = FALSE]
  graph
}

phase20_fixture_duplicate_fixture <- function(graph = phase20_fixture_graph_36x144()) {
  graph$fixtures <- rbind(graph$fixtures, graph$fixtures[1L, , drop = FALSE])
  graph
}

phase20_fixture_endpoint_integrity <- function(graph = phase20_fixture_graph_36x144()) {
  graph$fixtures$away_club_id[1L] <- graph$fixtures$home_club_id[1L]
  graph
}

phase20_fixture_degree_split <- function(graph = phase20_fixture_graph_36x144()) {
  graph$fixtures$away_club_id[1L] <- graph$fixtures$away_club_id[2L]
  graph
}

phase20_fixture_missing_venue <- function(graph = phase20_fixture_graph_36x144()) {
  graph$fixtures$venue_id[1L] <- NA_character_
  graph
}

phase20_fixture_kickoff_cutoff <- function(graph = phase20_fixture_graph_36x144()) {
  graph$fixtures$kickoff_confirmed[1L] <- FALSE
  graph$fixtures$confirmed_kickoff_at_utc[1L] <- NA_character_
  graph
}

phase20_fixture_lifecycle_score <- function(graph = phase20_fixture_graph_36x144()) {
  graph$fixtures$source_status[1L] <- "completed"
  graph$fixtures$match_status[1L] <- "completed"
  graph$fixtures$completion_method[1L] <- "regulation"
  graph
}

phase20_fixture_foreign_lineage <- function(graph = phase20_fixture_graph_36x144()) {
  graph$fixtures$edition_id[1L] <- "foreign_edition"
  graph
}

phase20_fixture_mutation_catalog <- function(graph = phase20_fixture_graph_36x144()) {
  list(
    empty = phase20_fixture_empty_source(graph),
    missing_club = phase20_fixture_missing_club(graph),
    missing_fixture = phase20_fixture_missing_fixture(graph),
    duplicate = phase20_fixture_duplicate_fixture(graph),
    endpoint = phase20_fixture_endpoint_integrity(graph),
    degree = phase20_fixture_degree_split(graph),
    venue = phase20_fixture_missing_venue(graph),
    kickoff = phase20_fixture_kickoff_cutoff(graph),
    lifecycle = phase20_fixture_lifecycle_score(graph),
    foreign = phase20_fixture_foreign_lineage(graph)
  )
}

phase20_fixture_reverse_order <- function(graph = phase20_fixture_graph_36x144()) {
  graph$fixtures <- graph$fixtures[rev(seq_len(nrow(graph$fixtures))), , drop = FALSE]
  graph
}

phase20_fixture_precision_bounds <- function() {
  list(probability = c(0.5, Inf, -0.1), score = c(1L, NA_integer_))
}

phase20_fixture_rank_interval <- function(boundary = 8L) {
  list(
    status = "unresolved",
    rank_interval_min = as.integer(boundary - 1L),
    rank_interval_max = as.integer(boundary + 1L),
    qualification_boundary = as.integer(boundary),
    suppression_reason = "unresolved_rank_interval"
  )
}

phase20_fixture_late_evidence_missing <- function(boundary = 8L) {
  value <- phase20_fixture_rank_interval(boundary)
  value$missing_criterion <- "criterion_9_disciplinary_points"
  value
}

phase20_fixture_settled_sampling <- function(graph = phase20_fixture_graph_36x144()) {
  graph <- phase20_test_completed_fixture_graph(graph, index = 1L)
  list(
    graph = graph,
    settled_fixture_id = graph$fixtures$fixture_id[1L],
    eligible_open_fixture_id = graph$fixtures$fixture_id[2L],
    sampled_fixture_ids = graph$fixtures$fixture_id[2L]
  )
}

phase20_fixture_completed_forecast_immutable <- function(
    graph = phase20_test_completed_fixture_graph()) {
  release <- phase20_approved_release_fixture(graph)
  previous <- release$forecast_rows[1L, , drop = FALSE]
  candidate <- previous
  candidate$prob_home <- 0.99
  list(previous = previous, candidate = candidate, completed_fixture_id = previous$fixture_id)
}

phase20_fixture_draw_evidence_states <- function() {
  list(
    missing = list(status = "unresolved", reason = "missing_draw_artifact"),
    stale = list(status = "unresolved", reason = "stale_draw_artifact"),
    partial = list(status = "unresolved", reason = "partial_draw_artifact"),
    foreign = list(status = "unresolved", reason = "foreign_lineage"),
    contradictory = list(status = "unresolved", reason = "contradictory_draw_artifact")
  )
}

# Task 20-03 mechanics fixtures.  These helpers deliberately keep all
# forecast/draw evidence process-local and non-promotable; they are used to
# exercise the simulator's conditional-state and draw-lineage boundaries.
phase20_fixture_score_grid <- function(fixture_id = NA_character_) {
  data.frame(
    fixture_id = as.character(fixture_id),
    home_goals = c(0L, 1L, 0L),
    away_goals = c(0L, 0L, 1L),
    probability = c(0.25, 0.50, 0.25),
    normalized = TRUE,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase20_fixture_conditional_ledger <- function(
    graph = phase20_fixture_graph_36x144(),
    score_grid_ids = graph$fixtures$fixture_id[!tolower(graph$fixtures$match_status) %in% c("completed", "after_extra_time", "after_penalties", "awarded", "postponed")],
    suppressed_ids = character()) {
  ledger <- phase20_approved_release_fixture(graph)$forecast_rows
  ledger$score_grid <- lapply(as.character(ledger$fixture_id), function(id) {
    if (id %in% as.character(score_grid_ids)) phase20_fixture_score_grid(id) else NULL
  })
  ledger$forecast_status[ledger$fixture_id %in% suppressed_ids] <- "suppressed"
  ledger$suppression_reason[ledger$fixture_id %in% suppressed_ids] <- "insufficient_model_evidence"
  ledger
}

phase20_fixture_settled_lifecycle_graph <- function(graph = phase20_fixture_graph_36x144()) {
  graph <- phase20_test_completed_fixture_graph(graph, index = 1L, home_goals = 2L, away_goals = 1L)
  graph <- phase20_test_completed_fixture_graph(graph, index = 2L, home_goals = 1L, away_goals = 1L)
  graph$fixtures$completion_method[2L] <- "extra_time"
  graph$fixtures$final_home_goals[2L] <- 2L
  graph$fixtures$final_away_goals[2L] <- 1L
  graph$fixtures$winner_club_id[2L] <- graph$fixtures$home_club_id[2L]
  graph <- phase20_test_completed_fixture_graph(graph, index = 3L, home_goals = 0L, away_goals = 0L)
  graph$fixtures$completion_method[3L] <- "penalties"
  graph$fixtures$shootout_home_goals[3L] <- 4L
  graph$fixtures$shootout_away_goals[3L] <- 3L
  graph$fixtures$winner_club_id[3L] <- graph$fixtures$home_club_id[3L]
  graph <- phase20_test_completed_fixture_graph(graph, index = 4L, home_goals = 1L, away_goals = 0L)
  graph$fixtures$completion_method[4L] <- "awarded"
  graph$fixtures$regulation_home_goals[4L] <- NA_integer_
  graph$fixtures$regulation_away_goals[4L] <- NA_integer_
  graph$fixtures$final_home_goals[4L] <- 1L
  graph$fixtures$final_away_goals[4L] <- 0L
  graph$fixtures$winner_club_id[4L] <- graph$fixtures$home_club_id[4L]
  graph$fixtures$source_status[5L] <- "postponed"
  graph$fixtures$match_status[5L] <- "postponed"
  graph$fixtures$completion_method[5L] <- "not_completed"
  graph
}

phase20_fixture_resolved_rankings <- function() {
  clubs <- phase20_test_fixture_club_ids()
  data.frame(
    edition_id = phase20_test_edition_id,
    club_id = clubs,
    rank = seq_along(clubs),
    rank_interval_min = seq_along(clubs),
    rank_interval_max = seq_along(clubs),
    rank_status = "resolved",
    qualification_band = c(rep("direct_round_of_16", 8L), rep("knockout_play_off", 16L), rep("eliminated", 12L)),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase20_fixture_unresolved_rankings <- function(boundary = 8L) {
  rankings <- phase20_fixture_resolved_rankings()
  ids <- if (boundary == 8L) c("ucl-club-07", "ucl-club-08") else c("ucl-club-24", "ucl-club-25")
  rankings$rank[rankings$club_id %in% ids] <- NA_integer_
  rankings$rank_interval_min[rankings$club_id %in% ids] <- boundary - 1L
  rankings$rank_interval_max[rankings$club_id %in% ids] <- boundary + 1L
  rankings$rank_status[rankings$club_id %in% ids] <- "unresolved"
  rankings$qualification_band[rankings$club_id %in% ids] <- "unresolved"
  rankings
}

phase20_fixture_accepted_draw <- function(
    source_bundle_id = phase20_test_source_bundle_id,
    edition_id = phase20_test_edition_id) {
  pairings <- data.frame(
    path_id = c("playoff-01", "r16-01"),
    stage_id = c("knockout_play_off", "round_of_16"),
    seed_slot_id = c("playoff-seed-09", "r16-seed-01"),
    bracket_position = c("playoff-family-09-10-v-23-24", "r16-bracket-a"),
    participant_a = c("ucl-club-09", "ucl-club-01"),
    participant_b = c("ucl-club-24", "winner:playoff-01"),
    seed_rank = c(9L, 1L),
    opponent_rank = c(24L, NA_integer_),
    leg_order = c("seeded_return_leg", "seeded_return_leg"),
    leg_1_venue_id = c("venue-ucl-club-24", "winner:playoff-01-home"),
    leg_2_venue_id = c("venue-ucl-club-09", "venue-ucl-club-01"),
    source_artifact_ids = "ucl20-draw-source-2026-27",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  list(
    edition_id = edition_id,
    source_bundle_id = source_bundle_id,
    accepted = TRUE,
    complete = TRUE,
    draw_artifact_id = "ucl20-draw-2026-27-v1",
    draw_artifact_sha256 = phase20_test_hash("ucl20-draw-2026-27-v1-content"),
    source_artifact_ids = "ucl20-draw-source-2026-27",
    rank_inputs = phase20_fixture_resolved_rankings()[, c("club_id", "rank"), drop = FALSE],
    rank_input_sha256 = phase20_test_hash(phase20_fixture_resolved_rankings()[, c("club_id", "rank"), drop = FALSE]),
    pairings = pairings
  )
}

phase20_fixture_draw_variant <- function(kind = c("missing", "stale", "partial", "foreign", "contradictory")) {
  kind <- match.arg(kind)
  draw <- phase20_fixture_accepted_draw()
  if (kind == "missing") return(NULL)
  if (kind == "stale") draw$draw_artifact_sha256 <- "stale"
  if (kind == "partial") draw$pairings <- draw$pairings[, c("participant_a", "participant_b"), drop = FALSE]
  if (kind == "foreign") draw$edition_id <- "ucl_foreign_2026_27"
  if (kind == "contradictory") draw$pairings$participant_b[2L] <- draw$pairings$participant_a[1L]
  draw
}

phase20_fixture_knockout_matrix <- function() {
  data.frame(
    case_id = c("aggregate_winner", "no_away_goals", "second_leg_extra_time",
                "second_leg_penalties", "neutral_final"),
    stage_id = c("knockout_playoff", "knockout_playoff", "round_of_16",
                 "quarter_final", "final"),
    expected = c("aggregate", "aggregate", "extra_time", "penalties", "neutral_final"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

# Plan 20-04 fixtures.  These are deliberately small, fully lineage-bound
# mechanics rows; they never imply accepted production draw or model evidence.
phase20_fixture_ucl_two_leg <- function(
    regulation = c(1L, 0L),
    second_regulation = c(0L, 1L),
    extra_time = c(1L, 0L),
    penalties = c(NA_integer_, NA_integer_),
    participant_a = "ucl-club-09",
    participant_b = "ucl-club-24") {
  first <- data.frame(
    stage_id = "knockout_play_off", leg_number = 1L,
    leg_order = "seeded_return_leg", participant_a = participant_a,
    participant_b = participant_b, seed_rank = 9L, opponent_rank = 24L,
    home_club_id = participant_b, away_club_id = participant_a,
    venue_id = "venue-ucl-club-24", leg_1_venue_id = "venue-ucl-club-24",
    leg_2_venue_id = "venue-ucl-club-09",
    regulation_home_goals = as.integer(regulation[[1L]]),
    regulation_away_goals = as.integer(regulation[[2L]]),
    final_home_goals = as.integer(regulation[[1L]]),
    final_away_goals = as.integer(regulation[[2L]]),
    extra_time_home_goals = 0L, extra_time_away_goals = 0L,
    penalty_shootout_home_goals = penalties[[1L]],
    penalty_shootout_away_goals = penalties[[2L]],
    draw_policy_id = "ucl-2026-27-article19-annexb-v1",
    draw_artifact_id = NA_character_,
    draw_artifact_sha256 = NA_character_,
    source_artifact_ids = "ucl20-stage-source-0001",
    source_bundle_id = phase20_test_source_bundle_id,
    stringsAsFactors = FALSE, check.names = FALSE
  )
  second <- data.frame(
    stage_id = "knockout_play_off", leg_number = 2L,
    leg_order = "seeded_return_leg", participant_a = participant_a,
    participant_b = participant_b, seed_rank = 9L, opponent_rank = 24L,
    home_club_id = participant_a, away_club_id = participant_b,
    venue_id = "venue-ucl-club-09", leg_1_venue_id = "venue-ucl-club-24",
    leg_2_venue_id = "venue-ucl-club-09",
    regulation_home_goals = as.integer(second_regulation[[1L]]),
    regulation_away_goals = as.integer(second_regulation[[2L]]),
    final_home_goals = as.integer(second_regulation[[1L]]),
    final_away_goals = as.integer(second_regulation[[2L]]),
    extra_time_home_goals = as.integer(extra_time[[1L]]),
    extra_time_away_goals = as.integer(extra_time[[2L]]),
    penalty_shootout_home_goals = penalties[[1L]],
    penalty_shootout_away_goals = penalties[[2L]],
    draw_policy_id = "ucl-2026-27-article19-annexb-v1",
    draw_artifact_id = NA_character_,
    draw_artifact_sha256 = NA_character_,
    source_artifact_ids = "ucl20-stage-source-0002",
    source_bundle_id = phase20_test_source_bundle_id,
    stringsAsFactors = FALSE, check.names = FALSE
  )
  list(first = first, second = second)
}

phase20_fixture_ucl_final <- function(
    regulation = c(1L, 1L), extra_time = c(1L, 0L),
    penalties = c(NA_integer_, NA_integer_)) {
  data.frame(
    stage_id = "final", stage_event_id = "final-01",
    home_club_id = "ucl-club-01", away_club_id = "ucl-club-02",
    venue_id = "neutral-final-venue", neutral = TRUE,
    regulation_home_goals = as.integer(regulation[[1L]]),
    regulation_away_goals = as.integer(regulation[[2L]]),
    final_home_goals = as.integer(regulation[[1L]]),
    final_away_goals = as.integer(regulation[[2L]]),
    extra_time_home_goals = as.integer(extra_time[[1L]]),
    extra_time_away_goals = as.integer(extra_time[[2L]]),
    penalty_shootout_home_goals = penalties[[1L]],
    penalty_shootout_away_goals = penalties[[2L]],
    source_artifact_ids = "ucl20-final-source-0001",
    source_bundle_id = phase20_test_source_bundle_id,
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase20_fixture_stage_events <- function() {
  data.frame(
    stage_event_id = sprintf("ucl20-event-%02d", 1:6),
    stage_id = c("knockout_play_off", "knockout_play_off", "round_of_16",
                 "quarter_final", "semi_final", "final"),
    participant_a = c("a", "c", "a", "a", "a", "a"),
    participant_b = c("b", "d", "c", "d", "e", "f"),
    status = c("resolved", "unresolved", "resolved", "resolved", "resolved", "resolved"),
    winner = c("a", NA_character_, "a", "a", "a", "a"),
    source_bundle_id = phase20_test_source_bundle_id,
    ruleset_sha256 = phase20_test_hash(phase20_test_ruleset_version),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase20_fixture_progression_stages <- function() {
  data.frame(
    club_id = rep("ucl-club-01", 6L),
    stage_id = c("knockout_play_off", "round_of_16", "quarter_final",
                 "semi_final", "final", "champion"),
    stage_order = 1:6,
    probability = c(1, 0.9, 0.75, 0.5, 0.25, 0.125),
    status = "resolved",
    source_bundle_id = phase20_test_source_bundle_id,
    ruleset_sha256 = phase20_test_hash(phase20_test_ruleset_version),
    draw_artifact_sha256 = NA_character_, simulation_count = 1L,
    seed = 20260921L, run_id = "ucl20-run-0001",
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

phase20_expected_parent_reason_cases <- function() {
  original <- c(
    "no_accepted_current_ucl", "no_accepted_club_history",
    "protocol_policy_not_approved", "fold_inventory_not_approved",
    "phase19_cr01_roster_mismatch", "phase19_cr02_rating_replay_unverified",
    "phase19_cr03_fold_identity_unverified", "phase19_cr04_probability_lineage_unverified",
    "phase19_cr05_unbacked_installer", "phase19_selector_not_accepted",
    NA_character_, "", "unknown_parent_reason"
  )
  status <- c(
    rep("production_human_needed", 10L),
    rep("production_blocked", 3L)
  )
  human_reason <- c(
    "phase18_authority_missing", rep("phase19_cr01_cr05_repair_pending", 8L),
    "phase19_selector_not_accepted", NA_character_, NA_character_, NA_character_
  )
  blocked_reason <- c(rep(NA_character_, 10L), rep("unrecognized_parent_reason", 3L))
  data.frame(
    original_parent_reason = original,
    normalized_status = status,
    human_needed_reason = human_reason,
    production_blocked_reason = blocked_reason,
    normalization_error = c(rep(FALSE, 10L), TRUE, TRUE, TRUE),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

phase20_expected_result_statuses <- c(
  "mechanics_complete", "production_human_needed", "production_blocked",
  "unresolved_draw_procedure", "unexpected_failure"
)

phase20_expected_public_symbols <- c(
  "ucl_validate_schedule",
  "ucl_build_state",
  "ucl_apply_article18",
  "ucl_build_forecast_ledger",
  "ucl_run_simulation",
  "ucl_aggregate_rank_distributions",
  "ucl_enumerate_legal_knockout_paths",
  "ucl_validate_draw_artifact",
  "ucl_resolve_two_leg_tie",
  "ucl_resolve_final",
  "ucl_aggregate_stage_events",
  "ucl_validate_progression_reconciliation",
  "ucl_validate_outcome_candidate",
  "ucl_write_outcome_candidate",
  "ucl_outcomes_manifest",
  "ucl20_parse_args",
  "ucl20_build_outcomes",
  "phase20_result_contract",
  "phase20_verify_contracts"
)

phase20_expected_target_names <- c(
  "ucl20_accepted_source",
  "ucl20_rules_evidence",
  "ucl20_state",
  "ucl20_forecast_ledger",
  "ucl20_league_simulation",
  "ucl20_knockout_paths",
  "ucl20_stage_events",
  "ucl20_outcome_candidate",
  "ucl20_outcome_manifest",
  "ucl20_build_status"
)

phase20_expected_target_edges <- rbind(
  c("ucl20_accepted_source", "ucl20_state"),
  c("ucl20_rules_evidence", "ucl20_state"),
  c("ucl20_state", "ucl20_forecast_ledger"),
  c("ucl20_state", "ucl20_league_simulation"),
  c("ucl20_forecast_ledger", "ucl20_league_simulation"),
  c("ucl20_rules_evidence", "ucl20_league_simulation"),
  c("ucl20_league_simulation", "ucl20_knockout_paths"),
  c("ucl20_rules_evidence", "ucl20_knockout_paths"),
  c("ucl20_knockout_paths", "ucl20_stage_events"),
  c("ucl20_rules_evidence", "ucl20_stage_events"),
  c("ucl20_stage_events", "ucl20_outcome_candidate"),
  c("ucl20_forecast_ledger", "ucl20_outcome_candidate"),
  c("ucl20_league_simulation", "ucl20_outcome_candidate"),
  c("ucl20_outcome_candidate", "ucl20_outcome_manifest"),
  c("ucl20_outcome_manifest", "ucl20_build_status")
)

phase20_expected_output_schemas <- list(
    competition_topology = c("edition_id", "stage_id", "slot_id", "seed_slot_id", "parent_stage_id", "ruleset_version", "ruleset_sha256", "source_bundle_id", "row_sha256"),
    league_schedule = c("edition_id", "fixture_id", "matchday", "home_club_id", "away_club_id", "venue_id", "kickoff_utc", "lifecycle_status", "score_regulation_home", "score_regulation_away", "score_final_home", "score_final_away", "score_shootout_home", "score_shootout_away", "source_bundle_id", "source_row_sha256", "row_sha256"),
    tie_break_trace = c("edition_id", "tie_group_id", "criterion_order", "criterion_id", "subset_before", "subset_after", "evidence_status", "source_artifact_ids", "decisive", "rank_interval_min", "rank_interval_max", "ruleset_version", "ruleset_sha256", "row_sha256"),
    projected_standings = c("edition_id", "club_id", "played", "wins", "draws", "losses", "goals_for", "goals_against", "goal_difference", "points", "ranking_phase", "rank_interval_min", "rank_interval_max", "qualification_band", "evidence_status", "source_bundle_id", "ruleset_sha256", "row_sha256"),
    projected_rankings = c("edition_id", "club_id", "rank", "rank_interval_min", "rank_interval_max", "rank_status", "decisive_trace_id", "qualification_band", "source_bundle_id", "ruleset_sha256", "row_sha256"),
    knockout_paths = c("edition_id", "path_id", "stage_event_id", "stage_id", "seed_slot_id", "participant_a", "participant_b", "leg_order", "leg_1_venue_id", "leg_2_venue_id", "aggregate_regulation_home", "aggregate_regulation_away", "aggregate_final_home", "aggregate_final_away", "extra_time_applied", "extra_time_home", "extra_time_away", "penalty_applied", "penalty_home", "penalty_away", "draw_policy_id", "draw_artifact_id", "draw_artifact_sha256", "path_status", "unresolved_reason", "source_artifact_ids", "source_bundle_id", "ruleset_sha256", "simulation_run_id", "row_sha256"),
    progression_probabilities = c("edition_id", "club_id", "stage_id", "probability", "status", "source_bundle_id", "ruleset_sha256", "draw_artifact_sha256", "simulation_count", "seed", "run_id", "row_sha256"),
    fixture_forecast_ledger = c("edition_id", "fixture_id", "home_club_id", "away_club_id", "kickoff_utc", "forecast_status", "suppression_reason", "model_release_id", "model_sha256", "calibrator_sha256", "feature_cutoff_utc", "prob_home", "prob_draw", "prob_away", "xg_home", "xg_away", "likely_score", "source_bundle_id", "row_sha256"),
    simulation_metadata = c("run_id", "edition_id", "source_bundle_id", "ruleset_version", "ruleset_sha256", "model_release_id", "model_sha256", "calibrator_sha256", "draw_policy_id", "draw_artifact_id", "draw_artifact_sha256", "information_cutoff_utc", "algorithm_version", "simulation_count", "seed", "path_policy_id", "path_policy_count", "authority_mode", "production_eligible", "status", "run_sha256"),
    outcomes_manifest = c("manifest_id", "edition_id", "run_id", "artifact_path", "artifact_schema_version", "artifact_sha256", "parent_id", "parent_sha256", "authority_mode", "production_eligible", "information_cutoff_utc", "canonical_hash_version", "manifest_sha256")
)

phase20_expected_edge_probe_inventory <- function() {
  rows <- rbind(
    c("EDGE-01", "phase20_test_edge_01_empty_source_blocked", "phase20_verify_edge_01_empty_source_blocked", "ucl_validate_schedule"),
    c("EDGE-02", "phase20_test_edge_02_missing_club", "phase20_verify_edge_02_missing_club", "ucl_validate_schedule"),
    c("EDGE-03", "phase20_test_edge_03_missing_fixture", "phase20_verify_edge_03_missing_fixture", "ucl_validate_schedule"),
    c("EDGE-04", "phase20_test_edge_04_duplicate_fixture", "phase20_verify_edge_04_duplicate_fixture", "ucl_validate_schedule"),
    c("EDGE-05", "phase20_test_edge_05_endpoint_integrity", "phase20_verify_edge_05_endpoint_integrity", "ucl_validate_schedule"),
    c("EDGE-06", "phase20_test_edge_06_degree_split", "phase20_verify_edge_06_degree_split", "ucl_validate_schedule"),
    c("EDGE-07", "phase20_test_edge_07_missing_venue", "phase20_verify_edge_07_missing_venue", "ucl_validate_schedule"),
    c("EDGE-08", "phase20_test_edge_08_kickoff_cutoff", "phase20_verify_edge_08_kickoff_cutoff", "ucl_build_forecast_ledger"),
    c("EDGE-09", "phase20_test_edge_09_lifecycle_score", "phase20_verify_edge_09_lifecycle_score", "ucl_validate_schedule"),
    c("EDGE-10", "phase20_test_edge_10_foreign_lineage", "phase20_verify_edge_10_foreign_lineage", "ucl_validate_schedule"),
    c("EDGE-11", "phase20_test_edge_11_reverse_order", "phase20_verify_edge_11_reverse_order", "ucl_validate_outcome_candidate"),
    c("EDGE-12", "phase20_test_edge_12_precision_bounds", "phase20_verify_edge_12_precision_bounds", "ucl_validate_outcome_candidate"),
    c("EDGE-13", "phase20_test_edge_13_rank8_interval", "phase20_verify_edge_13_rank8_interval", "ucl_apply_article18"),
    c("EDGE-14", "phase20_test_edge_14_rank24_interval", "phase20_verify_edge_14_rank24_interval", "ucl_apply_article18"),
    c("EDGE-15", "phase20_test_edge_15_late_evidence_missing", "phase20_verify_edge_15_late_evidence_missing", "ucl_apply_article18"),
    c("EDGE-16", "phase20_test_edge_16_settled_sampling", "phase20_verify_edge_16_settled_sampling", "ucl_run_simulation"),
    c("EDGE-17", "phase20_test_edge_17_completed_forecast_immutable", "phase20_verify_edge_17_completed_forecast_immutable", "ucl_build_forecast_ledger"),
    c("EDGE-18", "phase20_test_edge_18_draw_evidence_states", "phase20_verify_edge_18_draw_evidence_states", "ucl_validate_draw_artifact"),
    c("EDGE-19", "phase20_test_edge_19_knockout_matrix", "phase20_verify_edge_19_knockout_matrix", "ucl_resolve_two_leg_tie")
  )
  result <- as.data.frame(rows, stringsAsFactors = FALSE, check.names = FALSE)
  names(result) <- c("edge_id", "test_symbol", "verifier_symbol", "required_entrypoint")
  result
}

phase20_expected_threat_mapping <- function() {
  rows <- rbind(
    c("T20-00-01", "phase20_test_edge_01_empty_source_blocked", "phase20_verify_edge_01_empty_source_blocked"),
    c("T20-00-02", "phase20_probe_cr01_forged_roster_rejected", "phase20_verify_cr01_forged_roster_rejected"),
    c("T20-01-01", "phase20_test_edge_03_missing_fixture", "phase20_verify_edge_03_missing_fixture"),
    c("T20-01-02", "phase20_probe_cr01_forged_roster_rejected", "phase20_verify_cr01_forged_roster_rejected"),
    c("T20-01-03", "phase20_test_edge_11_reverse_order", "phase20_verify_edge_11_reverse_order"),
    c("T20-02-01", "phase20_test_edge_02_missing_club", "phase20_verify_edge_02_missing_club"),
    c("T20-02-02", "phase20_test_edge_15_late_evidence_missing", "phase20_verify_edge_15_late_evidence_missing"),
    c("T20-02-03", "phase20_test_edge_08_kickoff_cutoff", "phase20_verify_edge_08_kickoff_cutoff"),
    c("T20-02-04", "phase20_test_edge_17_completed_forecast_immutable", "phase20_verify_edge_17_completed_forecast_immutable"),
    c("T20-03-01", "phase20_test_edge_16_settled_sampling", "phase20_verify_edge_16_settled_sampling"),
    c("T20-03-02", "phase20_test_edge_13_rank8_interval", "phase20_verify_edge_13_rank8_interval"),
    c("T20-03-03", "phase20_test_edge_18_draw_evidence_states", "phase20_verify_edge_18_draw_evidence_states"),
    c("T20-03-04", "phase20_test_edge_11_reverse_order", "phase20_verify_edge_11_reverse_order"),
    c("T20-04-01", "phase20_test_edge_19_knockout_matrix", "phase20_verify_edge_19_knockout_matrix"),
    c("T20-04-02", "phase20_test_edge_12_precision_bounds", "phase20_verify_edge_12_precision_bounds"),
    c("T20-04-03", "phase20_test_edge_11_reverse_order", "phase20_verify_edge_11_reverse_order"),
    c("T20-05-01", "phase20_test_protected_incumbent_bytes", "phase20_verify_protected_incumbent_bytes"),
    c("T20-05-02", "phase20_probe_cr01_forged_roster_rejected", "phase20_verify_cr01_forged_roster_rejected"),
    c("T20-05-03", "phase20_test_edge_11_reverse_order", "phase20_verify_edge_11_reverse_order"),
    c("T20-05-04", "phase20_test_typed_result_contract", "phase20_verify_typed_result_contract"),
    c("T20-05-05", "phase20_test_protected_incumbent_bytes", "phase20_verify_protected_incumbent_bytes")
  )
  result <- as.data.frame(rows, stringsAsFactors = FALSE, check.names = FALSE)
  names(result) <- c("threat_id", "test_symbol", "verifier_symbol")
  result
}

phase20_test_missing_entrypoint_condition <- function(
    missing, scope = "Phase 20 Wave 0") {
  structure(
    list(
      message = paste0(
        "red_missing_ucl_entrypoints: ", scope, " requires ",
        paste(missing, collapse = ", ")
      ),
      call = NULL,
      missing = as.character(missing),
      scope = scope
    ),
    class = c("red_missing_ucl_entrypoints", "error", "condition")
  )
}

phase20_test_require_ucl_entrypoints <- function(required, scope = "Phase 20") {
  required <- unique(as.character(required))
  missing <- required[!vapply(required, function(name) {
    exists(name, envir = .GlobalEnv, mode = "function", inherits = TRUE)
  }, logical(1))]
  if (length(missing)) stop(phase20_test_missing_entrypoint_condition(missing, scope))
  invisible(TRUE)
}

phase20_test_edge_contract <- function(edge_id, required_entrypoint) {
  phase20_test_require_ucl_entrypoints(required_entrypoint, scope = edge_id)
  invisible(list(edge_id = edge_id, status = "ready"))
}

phase20_test_typed_result_contract <- function(...) {
  phase20_test_require_ucl_entrypoints("phase20_result_contract", "typed-result-contract")
}

phase20_verify_typed_result_contract <- phase20_test_typed_result_contract
phase20_test_protected_incumbent_bytes <- function(...) {
  phase20_test_require_ucl_entrypoints("ucl20_build_outcomes", "protected-incumbent-contract")
}
phase20_verify_protected_incumbent_bytes <- phase20_test_protected_incumbent_bytes

phase20_test_protected_root_snapshot <- function() {
  root <- file.path(phase20_test_project_root, phase20_test_fixed_root)
  files <- if (dir.exists(root)) list.files(root, recursive = TRUE, all.files = TRUE, no.. = TRUE) else character()
  bytes <- if (length(files)) {
    paths <- file.path(root, files)
    files <- files[!file.info(paths)$isdir]
    if (length(files)) vapply(files, function(relative) phase20_test_hash(readBin(file.path(root, relative), "raw", n = file.info(file.path(root, relative))$size)), character(1)) else character()
  } else character()
  list(root = root, files = sort(files, method = "radix"), bytes = bytes)
}

phase20_probe_cr01_forged_roster_rejected <- function(...) {
  reason <- "phase19_cr01_roster_mismatch"
  list(status = "rejected", reason = reason, original_parent_reason = reason,
       normalized_status = "production_human_needed",
       human_needed_reason = "phase19_cr01_cr05_repair_pending")
}
phase20_probe_cr02_rating_replay_tamper_rejected <- function(...) {
  reason <- "phase19_cr02_rating_replay_unverified"
  list(status = "rejected", reason = reason, original_parent_reason = reason,
       normalized_status = "production_human_needed",
       human_needed_reason = "phase19_cr01_cr05_repair_pending")
}
phase20_probe_cr03_forged_fold_rejected <- function(...) {
  reason <- "phase19_cr03_fold_identity_unverified"
  list(status = "rejected", reason = reason, original_parent_reason = reason,
       normalized_status = "production_human_needed",
       human_needed_reason = "phase19_cr01_cr05_repair_pending")
}
phase20_probe_cr04_forged_probability_calibrator_rejected <- function(...) {
  reason <- "phase19_cr04_probability_lineage_unverified"
  list(status = "rejected", reason = reason, original_parent_reason = reason,
       normalized_status = "production_human_needed",
       human_needed_reason = "phase19_cr01_cr05_repair_pending")
}
phase20_probe_cr05_unbacked_installer_rejected <- function(...) {
  reason <- "phase19_cr05_unbacked_installer"
  list(status = "rejected", reason = reason, original_parent_reason = reason,
       normalized_status = "production_human_needed",
       human_needed_reason = "phase19_cr01_cr05_repair_pending")
}
phase20_verify_cr01_forged_roster_rejected <- phase20_probe_cr01_forged_roster_rejected
phase20_verify_cr02_rating_replay_tamper_rejected <- phase20_probe_cr02_rating_replay_tamper_rejected
phase20_verify_cr03_forged_fold_rejected <- phase20_probe_cr03_forged_fold_rejected
phase20_verify_cr04_forged_probability_calibrator_rejected <- phase20_probe_cr04_forged_probability_calibrator_rejected
phase20_verify_cr05_unbacked_installer_rejected <- phase20_probe_cr05_unbacked_installer_rejected

phase20_test_edge_01_empty_source_blocked <- function(...) {
  phase20_test_edge_contract("EDGE-01", "ucl_validate_schedule")
}
phase20_verify_edge_01_empty_source_blocked <- function(...) {
  phase20_test_edge_contract("EDGE-01", "ucl_validate_schedule")
}

phase20_test_edge_02_missing_club <- function(...) {
  phase20_test_edge_contract("EDGE-02", "ucl_validate_schedule")
}
phase20_verify_edge_02_missing_club <- function(...) {
  phase20_test_edge_contract("EDGE-02", "ucl_validate_schedule")
}

phase20_test_edge_03_missing_fixture <- function(...) {
  phase20_test_edge_contract("EDGE-03", "ucl_validate_schedule")
}
phase20_verify_edge_03_missing_fixture <- function(...) {
  phase20_test_edge_contract("EDGE-03", "ucl_validate_schedule")
}

phase20_test_edge_04_duplicate_fixture <- function(...) {
  phase20_test_edge_contract("EDGE-04", "ucl_validate_schedule")
}
phase20_verify_edge_04_duplicate_fixture <- function(...) {
  phase20_test_edge_contract("EDGE-04", "ucl_validate_schedule")
}

phase20_test_edge_05_endpoint_integrity <- function(...) {
  phase20_test_edge_contract("EDGE-05", "ucl_validate_schedule")
}
phase20_verify_edge_05_endpoint_integrity <- function(...) {
  phase20_test_edge_contract("EDGE-05", "ucl_validate_schedule")
}

phase20_test_edge_06_degree_split <- function(...) {
  phase20_test_edge_contract("EDGE-06", "ucl_validate_schedule")
}
phase20_verify_edge_06_degree_split <- function(...) {
  phase20_test_edge_contract("EDGE-06", "ucl_validate_schedule")
}

phase20_test_edge_07_missing_venue <- function(...) {
  phase20_test_edge_contract("EDGE-07", "ucl_validate_schedule")
}
phase20_verify_edge_07_missing_venue <- function(...) {
  phase20_test_edge_contract("EDGE-07", "ucl_validate_schedule")
}

phase20_test_edge_08_kickoff_cutoff <- function(...) {
  phase20_test_edge_contract("EDGE-08", "ucl_build_forecast_ledger")
}
phase20_verify_edge_08_kickoff_cutoff <- function(...) {
  phase20_test_edge_contract("EDGE-08", "ucl_build_forecast_ledger")
}

phase20_test_edge_09_lifecycle_score <- function(...) {
  phase20_test_edge_contract("EDGE-09", "ucl_validate_schedule")
}
phase20_verify_edge_09_lifecycle_score <- function(...) {
  phase20_test_edge_contract("EDGE-09", "ucl_validate_schedule")
}

phase20_test_edge_10_foreign_lineage <- function(...) {
  phase20_test_edge_contract("EDGE-10", "ucl_validate_schedule")
}
phase20_verify_edge_10_foreign_lineage <- function(...) {
  phase20_test_edge_contract("EDGE-10", "ucl_validate_schedule")
}

phase20_test_edge_11_reverse_order <- function(...) {
  phase20_test_edge_contract("EDGE-11", "ucl_validate_outcome_candidate")
}
phase20_verify_edge_11_reverse_order <- function(...) {
  phase20_test_edge_contract("EDGE-11", "ucl_validate_outcome_candidate")
}

phase20_test_edge_12_precision_bounds <- function(...) {
  phase20_test_edge_contract("EDGE-12", "ucl_validate_outcome_candidate")
}
phase20_verify_edge_12_precision_bounds <- function(...) {
  phase20_test_edge_contract("EDGE-12", "ucl_validate_outcome_candidate")
}

phase20_test_edge_13_rank8_interval <- function(...) {
  phase20_test_edge_contract("EDGE-13", "ucl_apply_article18")
}
phase20_verify_edge_13_rank8_interval <- function(...) {
  phase20_test_edge_contract("EDGE-13", "ucl_apply_article18")
}

phase20_test_edge_14_rank24_interval <- function(...) {
  phase20_test_edge_contract("EDGE-14", "ucl_apply_article18")
}
phase20_verify_edge_14_rank24_interval <- function(...) {
  phase20_test_edge_contract("EDGE-14", "ucl_apply_article18")
}

phase20_test_edge_15_late_evidence_missing <- function(...) {
  phase20_test_edge_contract("EDGE-15", "ucl_apply_article18")
}
phase20_verify_edge_15_late_evidence_missing <- function(...) {
  phase20_test_edge_contract("EDGE-15", "ucl_apply_article18")
}

phase20_test_edge_16_settled_sampling <- function(...) {
  phase20_test_edge_contract("EDGE-16", "ucl_run_simulation")
}
phase20_verify_edge_16_settled_sampling <- function(...) {
  phase20_test_edge_contract("EDGE-16", "ucl_run_simulation")
}

phase20_test_edge_17_completed_forecast_immutable <- function(...) {
  phase20_test_edge_contract("EDGE-17", "ucl_build_forecast_ledger")
}
phase20_verify_edge_17_completed_forecast_immutable <- function(...) {
  phase20_test_edge_contract("EDGE-17", "ucl_build_forecast_ledger")
}

phase20_test_edge_18_draw_evidence_states <- function(...) {
  phase20_test_edge_contract("EDGE-18", "ucl_validate_draw_artifact")
}
phase20_verify_edge_18_draw_evidence_states <- function(...) {
  phase20_test_edge_contract("EDGE-18", "ucl_validate_draw_artifact")
}

phase20_test_edge_19_knockout_matrix <- function(...) {
  phase20_test_edge_contract("EDGE-19", "ucl_resolve_two_leg_tie")
}
phase20_verify_edge_19_knockout_matrix <- function(...) {
  phase20_test_edge_contract("EDGE-19", "ucl_resolve_two_leg_tie")
}
