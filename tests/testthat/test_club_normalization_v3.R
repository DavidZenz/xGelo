library(testthat)
normalizer_core_root <- normalizePath(if(basename(getwd())=="testthat")"../.."else".",mustWork=TRUE)
normalizer_repair_root <- file.path(normalizer_core_root,".planning/operations/cl-normalization-repair-2026-11-05")
if(!dir.exists(normalizer_repair_root))normalizer_repair_root<-normalizePath(file.path(normalizer_core_root,".."),mustWork=TRUE)
normalizer_core <- new.env(parent=baseenv());normalizer_core$setNames<-stats::setNames
for(path in c("R/common/phase18_canonical_hash.R","R/club/identity.R"))sys.source(file.path(normalizer_core_root,path),envir=normalizer_core)
normalizer_read <- function(path)utils::read.csv(path,colClasses="character",na.strings=character(),check.names=FALSE,stringsAsFactors=FALSE)

test_that("actual core normalizer uses the explicit reviewed ICU contract", {
  expect_identical(normalizer_core$phase18_club_normalization_contract()$version,"phase18-club-normalization-v3-icu-latin-ascii")
  expect_identical(normalizer_core$phase18_club_normalization_contract()$stringi_version,"1.8.7")
  expect_identical(normalizer_core$phase18_club_normalization_contract()$icu_version,"74.1")
  name<-"Dynamo České Budějovice";expected<-"dynamo ceske budejovice"
  expect_identical(unique(replicate(1000,normalizer_core$phase18_normalize_club_name(name))),expected)
  forms<-c(name,stringi::stri_trans_nfd(name),toupper(name),tolower(name),paste0("  ",name,"  "))
  expect_identical(normalizer_core$phase18_normalize_club_name(forms),rep(expected,length(forms)))
  expect_identical(normalizer_core$phase18_normalize_club_name(c(NA_character_,"","  ","1. FC Köln","İstanbul Başakşehir","Səbail FK")),c(NA_character_,"","","1 fc koln","istanbul basaksehir","sbail fk"))
  expect_identical(normalizer_core$phase18_normalize_club_name(character()),character())
  bad<-rawToChar(as.raw(255));Encoding(bad)<-"UTF-8"
  expect_error(normalizer_core$phase18_normalize_club_name(bad),"valid UTF-8")
})

test_that("actual core preserves all approved identities and exact derived-key deltas", {
  baseline<-file.path(normalizer_repair_root,"baseline_inputs");candidate<-file.path(normalizer_repair_root,"candidate_inputs")
  aliases<-normalizer_read(file.path(baseline,"registry_aliases.csv"))
  vector<-normalizer_core$phase18_normalize_club_name(aliases$alias)
  scalar<-vapply(aliases$alias,normalizer_core$phase18_normalize_club_name,character(1))
  expect_identical(vector,unname(scalar));expect_equal(sum(vector!=aliases$normalized_alias),42L)
  registries<-list(clubs=normalizer_read(file.path(baseline,"registry_clubs.csv")),source_ids=normalizer_read(file.path(baseline,"registry_source_ids.csv")),aliases=normalizer_read(file.path(candidate,"proposed_registry_aliases.csv")))
  expect_silent(normalizer_core$phase18_validate_club_registries(registries))
  review<-normalizer_read(file.path(candidate,"preserved_approved_identity_review.csv"))
  expect_equal(nrow(review),407L);expect_equal(length(unique(review$club_id)),343L)
  expected_review<-normalizer_read(file.path(baseline,"identity_review.csv"));expect_identical(review,expected_review)
  actual<-vapply(seq_len(nrow(review)),function(i){a<-review[i,];key<-paste0("name:",gsub(" ","_",normalizer_core$phase18_normalize_club_name(a$display_value),fixed=TRUE));
    normalizer_core$phase18_resolve_club_identity(registries,a$source_system,key,a$display_value,a$valid_from_utc,.validated=TRUE,.registry_sha256="diagnostic-fixture-only")$club_id[[1L]]},character(1))
  expect_identical(actual,review$club_id)
  keys<-paste0("name:",gsub(" ","_",normalizer_core$phase18_normalize_club_name(review$display_value),fixed=TRUE))
  expect_equal(sum(keys!=review$source_club_id),39L)
  summary<-jsonlite::read_json(file.path(normalizer_repair_root,"evidence/migration_summary.json"),simplifyVector=TRUE)
  expect_equal(summary$cross_club_lookup_collisions,0L);expect_equal(summary$equivalent_alias_rows_collapsed,0L)
})

test_that("lookup normalization leaves canonical raw Unicode source hashing byte-sensitive", {
  a<-"České";b<-stringi::stri_trans_nfd(a)
  expect_identical(normalizer_core$phase18_normalize_club_name(a),normalizer_core$phase18_normalize_club_name(b))
  hash<-function(x)normalizer_core$phase18_hash_sequence_v2(list(x),"raw-source-byte-regression",names="value",types="character")
  expect_false(identical(hash(a),hash(b)))
})

test_that("actual core Czech normalization repeats identically in fresh Rscript processes", {
  wrapper<-tempfile("normalizer-cold-",fileext=".R");on.exit(unlink(wrapper),add=TRUE)
  writeLines(c('root<-commandArgs(trailingOnly=TRUE)[[1L]]',
    'e<-new.env(parent=baseenv());e$setNames<-stats::setNames',
    'sys.source(file.path(root,"R/common/phase18_canonical_hash.R"),envir=e)',
    'sys.source(file.path(root,"R/club/identity.R"),envir=e)',
    'values<-vapply(seq_len(128),function(i)e$phase18_normalize_club_name("Dynamo České Budějovice"),character(1))',
    'stopifnot(identical(unique(values),"dynamo ceske budejovice"))',
    'cat("CORE_COLD_OK\\n")'),wrapper)
  for(i in seq_len(3)){
    result<-system2(file.path(R.home("bin"),"Rscript"),c("--vanilla",shQuote(wrapper),shQuote(normalizer_core_root)),stdout=TRUE,stderr=TRUE)
    expect_null(attr(result,"status"));expect_true(any(grepl("CORE_COLD_OK",result,fixed=TRUE)))
  }
})

test_that("the actual isolated production CLI imports its diagnostic dependencies", {
  loader<-new.env(parent=baseenv())
  sys.source(file.path(normalizer_core_root,"scripts/build_uefa_champions_league_outcomes.R"),envir=loader)
  runtime<-loader$phase20_ucl_runtime
  expect_identical(runtime$tail,utils::tail)
  expect_identical(runtime$capture.output,utils::capture.output)
  expect_identical(evalq(tail(1:3,2L),runtime),2:3)
  expect_identical(evalq(capture.output(cat("CLI_DIAGNOSTIC_OK")),runtime),"CLI_DIAGNOSTIC_OK")
})
