# Independent compatibility proof from retained, already validated 10k stores.
# Run only after all scale processes have exited.
if (!identical(Sys.getenv("XGELO_SCALE_JOBS_STOPPED"),"1")) stop("Scale jobs must be stopped")
root<-"/private/tmp/xgelo-active-dashboards";setwd(root)
paths<-file.path(c("/private/tmp/xgelo-cpu-certification/nl","/private/tmp/xgelo-cpu-certification-v2/nl","/private/tmp/xgelo-cpu-certification-v3/nl"),"run-10000")
module<-new.env(parent=globalenv());sys.source("R/common/simulation_execution.R",module)
normalize<-function(x) {
 if(is.environment(x)) {keys<-ls(x,all.names=TRUE,sorted=TRUE);return(list(environment=TRUE,empty_parent=identical(parent.env(x),emptyenv()),values=lapply(mget(keys,x,inherits=FALSE),normalize)))}
 if(is.list(x)) {y<-lapply(x,normalize);attributes(y)<-attributes(x);return(y)}
 x
}
manifests<-lapply(paths,function(p)readRDS(file.path(p,"manifest.rds")))
stopifnot(all(vapply(manifests,function(x)identical(x$count,10000L)&&identical(x$chunk_size,256L),logical(1))))
records<-list(); all_trace_bytes_identical<-TRUE; all_schema_bytes_identical<-TRUE
for(index in seq_len(ceiling(10000/256))) {
 name<-sprintf("chunk-%06d",index)
 commits<-lapply(paths,function(path)readRDS(file.path(path,name,"commit.rds")))
 ids<-seq.int((index-1L)*256L+1L,min(10000L,index*256L))
 stopifnot(all(vapply(commits,function(x)identical(x$ids,ids),logical(1))))
 statistics<-chunks<-vector("list",length(paths))
 for(i in seq_along(paths)) {
  chunk<-module$simulation_stream_read_chunk(file.path(paths[[i]],name),ids,manifests[[i]]$fingerprint,keep=names(commits[[i]]$hashes),auxiliary_fields=manifests[[i]]$auxiliary_fields,expected_schema=manifests[[i]]$schema,expected_statistics_codec=manifests[[i]]$statistics_codec)
  chunks[[i]]<-chunk
  statistics[[i]]<-normalize(module$simulation_statistics_read(chunk$buffers[["statistics.rds"]],chunk$statistics_codec,chunk$statistics_size,chunk$statistics_crc32))
 }
 stopifnot(identical(statistics[[1]],statistics[[2]]),identical(statistics[[1]],statistics[[3]]))
 fields<-c("trace.bin.gz","auxiliary-0001.bin.gz","schema.rds")
 same<-vapply(fields,function(field) identical(commits[[1]]$hashes[[field]],commits[[2]]$hashes[[field]])&&identical(commits[[1]]$hashes[[field]],commits[[3]]$hashes[[field]]),logical(1))
 all_trace_bytes_identical<-all_trace_bytes_identical&&all(same[1:2]);all_schema_bytes_identical<-all_schema_bytes_identical&&same[[3]]
 stopifnot(identical(chunks[[1]]$schema,chunks[[2]]$schema),identical(chunks[[1]]$schema,chunks[[3]]$schema))
 if(!all(same[1:2])) {
  reference<-new.env(parent=emptyenv())
  module$simulation_stream_visit_chunk(chunks[[1]],ids,function(value,id) assign(as.character(id),value,reference))
  for(i in 2:3) module$simulation_stream_visit_chunk(chunks[[i]],ids,function(value,id) stopifnot(identical(value,get(as.character(id),reference,inherits=FALSE))))
  rm(reference)
 }
 records[[index]]<-list(chunk=name,first=min(ids),last=max(ids),football_trace_sha256=unname(commits[[1]]$hashes[["trace.bin.gz"]]),exact_mean_trace_sha256=unname(commits[[1]]$hashes[["auxiliary-0001.bin.gz"]]),schema_sha256=unname(commits[[1]]$hashes[["schema.rds"]]),statistics_identical=TRUE,reconstructed_trace_identical=TRUE,compressed_trace_bytes_identical=all(same[1:2]))
 rm(statistics,chunks);invisible(gc(FALSE))
}
jsonlite::write_json(list(count=10000L,cycles=paths,all_payloads_reverified=TRUE,trace_bytes_identical=all_trace_bytes_identical,reconstructed_traces_identical=TRUE,schema_bytes_identical=all_schema_bytes_identical,statistics_semantically_identical=TRUE,chunks=records),"/private/tmp/xgelo-cpu-checks/retained-10k-parity.json",auto_unbox=TRUE,pretty=TRUE)
cat("ALL_RETAINED_10K_CHUNKS_AND_STATISTICS_IDENTICAL\n")
