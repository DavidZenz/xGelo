# Recheck durable post-validation bytes, without rerunning simulations.
if(!identical(Sys.getenv("XGELO_SCALE_JOBS_STOPPED"),"1"))stop("Scale jobs must be stopped")
setwd("/private/tmp/xgelo-active-dashboards")
module<-new.env(parent=globalenv());sys.source("R/common/simulation_execution.R",module)
code<-module$simulation_repository_identity(".")
implementation<-digest::digest(code,algo="sha256")
stopifnot(identical(implementation,"32cd661dd3aa7eb22d195bf45ac1f56355592a47fcd5a70b4d02c9675f1a0762"))
records<-list()
for(competition in c("cl","nl")) {
 directory<-file.path("/private/tmp/xgelo-cpu-certification-v3",competition)
 resource<-jsonlite::read_json(file.path(directory,"resource-100000.json"),simplifyVector=TRUE)
 stopifnot(identical(resource$status,"passed"),resource$count==100000,resource$wall_seconds<7200,resource$peak_process_tree_rss_bytes<resource$physical_memory_bytes/2,identical(resource$implementation_sha256,implementation))
 run<-file.path(directory,"run-100000");manifest<-readRDS(file.path(run,"manifest.rds"))
 bare<-manifest;bare$fingerprint<-NULL
 stopifnot(identical(digest::digest(bare,algo="sha256"),manifest$fingerprint),identical(manifest$identity$code,code),identical(manifest$count,100000L),identical(manifest$chunk_size,256L))
 paths<-sprintf("chunk-%06d",1:391)
 stopifnot(setequal(list.files(run,pattern="^chunk-"),paths))
 chunks<-vector("list",391L);covered<-0L
 for(index in 1:391) {
  first<-(index-1L)*256L+1L;last<-min(100000L,index*256L);ids<-seq.int(first,last)
  marker<-module$simulation_stream_validate_chunk(file.path(run,paths[[index]]),ids,manifest$fingerprint,manifest$auxiliary_fields,expected_schema=manifest$schema,expected_statistics_codec=manifest$statistics_codec)
  chunks[[index]]<-list(chunk=paths[[index]],first=first,last=last,hashes=as.list(marker$hashes),statistics_uncompressed_bytes=marker$statistics_uncompressed_bytes,statistics_crc32=marker$statistics_crc32)
  covered<-covered+length(ids)
 }
 stopifnot(covered==100000L)
 records[[competition]]<-list(status="passed",iterations=covered,chunks=length(chunks),implementation_sha256=implementation,manifest_fingerprint=manifest$fingerprint,manifest_fingerprint_valid=TRUE,all_payload_hashes_reverified=TRUE,full_semantic_validation_in_benchmark=TRUE,authority=resource$authority,public_promotion=FALSE,coverage=chunks)
}
jsonlite::write_json(records,"/private/tmp/xgelo-cpu-checks/final-checkpoint-proof.json",auto_unbox=TRUE,pretty=TRUE)
cat("BOTH_100K_DURABLE_CHECKPOINTS_REVERIFIED\n")
