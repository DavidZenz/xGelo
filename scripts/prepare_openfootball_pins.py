#!/usr/bin/env python3
"""Materialize native history candidates for review; never activate a source.

Every candidate retains the bytes and LICENSE from its own commit. Git commit
timestamps are recorded evidence, not proof of an earlier public publication.
Renames are followed explicitly so old commits use their historical path.
"""

import argparse
import csv
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile


def git(repo, *args, check=True):
    return subprocess.run(["rtk", "proxy", "git", "-c", "core.quotepath=false", "-C", str(repo),
                           *args], check=check, capture_output=True).stdout


def write_csv(path, rows, fields=None):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields or list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def utc(value):
    return dt.datetime.fromisoformat(value).astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def followed_history(repo, current_path):
    output = git(repo, "log", "--follow", "--find-renames=50%", "--format=PIN:%H%x09%cI",
                 "--name-status", "--", current_path).decode("utf-8")
    records = []
    for block in output.split("PIN:")[1:]:
        lines = block.strip().splitlines()
        commit, timestamp = lines[0].split("\t")
        changes = [line.split("\t") for line in lines[1:] if line.strip()]
        records.append((commit, utc(timestamp), changes))
    historical_path = current_path
    for commit, timestamp, changes in records:
        # At a rename commit the new path exists; earlier commits use the old.
        candidates = [historical_path]
        for change in changes:
            if change[0].startswith("R") and len(change) == 3:
                candidates = [change[2], historical_path, change[1]]
                break
            if len(change) == 2:
                candidates.append(change[1])
        resolved = None
        for path in dict.fromkeys(candidates):
            blob = git(repo, "rev-parse", "--verify", f"{commit}:{path}", check=False).decode().strip()
            if re.fullmatch(r"[a-f0-9]{40}", blob):
                resolved = (path, blob)
                break
        if resolved is None:
            if any(change == ["D", historical_path] for change in changes):
                yield commit, timestamp, historical_path, None
                continue
            raise RuntimeError(f"No explicitly followed source path at {repo.name}:{commit}: {candidates}")
        yield commit, timestamp, *resolved
        for change in changes:
            if change[0].startswith("R") and len(change) == 3:
                historical_path = change[1]
                break


def license_at(repo, commit):
    files = git(repo, "ls-tree", "--name-only", commit).decode().splitlines()
    choices = [name for name in files if name.lower() in ("license.md", "license", "license.txt", "copying")]
    if len(choices) != 1:
        raise RuntimeError(f"Expected one root license at {repo.name}:{commit}, found {choices}")
    path = choices[0]
    return path, git(repo, "show", f"{commit}:{path}")


def write_candidate_rows(project, output, rscript="/opt/homebrew/opt/r/bin/Rscript"):
    """Retain each valid snapshot's eligible rows for first-observation review."""
    script = r'''
args <- commandArgs(trailingOnly=TRUE)
source(file.path(args[[1L]],"R/club/openfootball_parser.R"))
index <- read.csv(file.path(args[[2L]],"candidates.csv"),colClasses="character",check.names=FALSE)
qa <- read.csv(file.path(args[[2L]],"candidate_parser_qa.csv"),colClasses="character",check.names=FALSE)
key <- function(x) paste(x$source_path,x$raw_sha256,sep="|")
qa_index <- match(key(index),key(qa))
if(anyNA(qa_index)) stop("Candidate parser QA is incomplete")
index <- index[qa$errors[qa_index]=="0",,drop=FALSE]
allowed <- c("REGULAR_SEASON","GROUP_STAGE","LEAGUE_STAGE","CHAMPIONSHIP_LEAGUE_STAGE",
             "RELEGATION_LEAGUE_STAGE","EUROPE_LEAGUE_STAGE")
parts <- parallel::mclapply(seq_len(nrow(index)),function(i) {
  item <- index[i,,drop=FALSE]
  parsed <- phase18_read_openfootball_source(item$local_path,item,strict=FALSE)
  if(attr(parsed,"summary")$errors!=0L) stop("Previously valid parser QA changed: ",item$source_path," ",item$raw_sha256)
  keep <- parsed$status=="completed" & parsed$score_semantics=="regulation" & parsed$stage %in% allowed
  if(!any(keep)) return(NULL)
  competition <- item$competition_id
  if(competition=="deutschland") competition <- "germany"
  if(competition=="espana") competition <- "spain"
  meta <- data.frame(source_id=paste0(competition,"-",item$season_id),source_path=item$source_path,
    raw_sha256=item$raw_sha256,commit_sha=item$commit_sha,commit_utc=item$commit_utc,
    is_latest_file_bytes=item$is_latest_file_bytes,competition_id=competition,season_id=item$season_id)
  cbind(meta[rep(1L,sum(keep)),,drop=FALSE],parsed[keep,phase18_openfootball_exchange_schema(),drop=FALSE])
},mc.cores=4L,mc.preschedule=TRUE)
if(any(vapply(parts,inherits,logical(1),"try-error"))) stop("Candidate row parser worker failed")
rows <- do.call(rbind,parts)
write.csv(rows,file.path(args[[2L]],"candidate_rows.csv"),row.names=FALSE)
message("candidate_rows sources=",length(unique(rows$source_path))," snapshots=",length(unique(paste(rows$source_path,rows$raw_sha256)))," eligible_rows=",nrow(rows))
'''
    with tempfile.NamedTemporaryFile("w", suffix=".R", encoding="utf-8") as handle:
        handle.write(script)
        handle.flush()
        subprocess.run(["rtk","proxy",rscript,handle.name,str(project),str(output)],check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--summary", type=Path,
                        default=Path(__file__).resolve().parents[1] / "data/club/history_native_file_inventory.csv")
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--upstream-root", type=Path)
    parser.add_argument("--output-root", type=Path)
    parser.add_argument("--rscript", default="/opt/homebrew/opt/r/bin/Rscript")
    parser.add_argument("--reuse-candidates", action="store_true",
                        help="Reuse materialized candidates and existing parser QA after verifying retained hashes")
    parser.add_argument("--refresh-qa", action="store_true", help="Refresh native parser QA while reusing pinned bytes")
    parser.add_argument("--refresh-qa-pattern", help="Refresh matching source paths plus previously failed candidates; retain other QA")
    args = parser.parse_args()
    project = args.project_root.resolve()
    upstream = (args.upstream_root or project / "data/club/local_raw/upstream").resolve()
    output = (args.output_root or project / "data/club/local_raw/pin_candidates").resolve()
    with args.summary.open(newline="", encoding="utf-8") as handle:
        sources = list(csv.DictReader(handle))
    output.mkdir(parents=True, exist_ok=True)
    (output / "blobs").mkdir(exist_ok=True)
    (output / "licenses").mkdir(exist_ok=True)
    candidates = []
    deletions = []
    cached = []
    if args.reuse_candidates:
        with (output / "candidates.csv").open(newline="", encoding="utf-8") as handle:
            cached = list(csv.DictReader(handle))
        deletion_path = output / "deleted_file_commits.csv"
        if deletion_path.exists():
            with deletion_path.open(newline="", encoding="utf-8") as handle:
                deletions = list(csv.DictReader(handle))
    for source in sources:
        if args.reuse_candidates:
            rows = [row for row in cached if row["source_path"] == source["path"]]
            if not rows:
                raise RuntimeError(f"Cached source missing: {source['path']}")
            for row in rows:
                for local_field, hash_field in (("local_path","raw_sha256"),("license_local_path","license_sha256")):
                    if hashlib.sha256(Path(row[local_field]).read_bytes()).hexdigest() != row[hash_field]:
                        raise RuntimeError(f"Cached bytes changed: {row[local_field]}")
            candidates.extend(rows)
            continue
        repo_name, current_path = source["path"].split("/", 1)
        repo = upstream / repo_name
        latest_hash = hashlib.sha256((repo / current_path).read_bytes()).hexdigest()
        seen = {}
        for commit, timestamp, historical_path, blob in followed_history(repo, current_path):
            if blob is None:
                deletions.append(dict(source_path=source["path"],commit_sha=commit,commit_utc=timestamp,
                                      relative_path=historical_path,state="explicit_file_deletion_no_blob"))
                continue
            raw = git(repo, "cat-file", "blob", blob)
            raw_hash = hashlib.sha256(raw).hexdigest()
            key = raw_hash
            if key in seen and seen[key]["commit_utc"] <= timestamp:
                continue
            license_path, license_bytes = license_at(repo, commit)
            license_hash = hashlib.sha256(license_bytes).hexdigest()
            raw_file = output / "blobs" / f"{raw_hash}.txt"
            license_file = output / "licenses" / f"{license_hash}.md"
            if raw_file.exists() and raw_file.read_bytes() != raw:
                raise RuntimeError(f"Existing raw candidate hash conflict: {raw_file}")
            raw_file.write_bytes(raw)
            license_file.write_bytes(license_bytes)
            row = dict(source_path=source["path"], repository_url=f"https://github.com/openfootball/{repo_name}",
                       current_relative_path=current_path, relative_path=historical_path,
                       commit_sha=commit, commit_utc=timestamp, git_blob_sha=blob,
                       raw_sha256=raw_hash, bytes=len(raw), local_path=str(raw_file),
                       source_url=f"https://github.com/openfootball/{repo_name}/blob/{commit}/{historical_path}",
                       license_relative_path=license_path, license_sha256=license_hash,
                       license_local_path=str(license_file),
                       license_url=f"https://github.com/openfootball/{repo_name}/blob/{commit}/{license_path}",
                       expected_declared_matches=source["declared"],
                       season_id=re.search(r"20\d{2}(?:-\d{2})?", source["path"]).group(),
                       competition_id="ucl" if repo_name == "champions-league" else (
                           current_path.split("/")[0] if repo_name == "europe" else repo_name),
                       is_latest_file_bytes=str(raw_hash == latest_hash).lower())
            seen[key] = row
        source_candidates = sorted(seen.values(), key=lambda row: (row["commit_utc"], row["commit_sha"]))
        if not source_candidates or not any(row["is_latest_file_bytes"] == "true" for row in source_candidates):
            raise RuntimeError(f"Followed history does not contain current bytes: {source['path']}")
        candidates.extend(source_candidates)
        print(f"materialized {source['path']} distinct_blobs={len(source_candidates)}", flush=True)
    candidate_path = output / "candidates.csv"
    write_csv(candidate_path, candidates)
    write_csv(output / "deleted_file_commits.csv", deletions,
              ["source_path","commit_sha","commit_utc","relative_path","state"])
    qa_path = output / "candidate_parser_qa.csv"
    qa_input_path = candidate_path
    qa_output_path = qa_path
    prior_qa_rows = None
    if args.refresh_qa_pattern:
        with qa_path.open(newline="",encoding="utf-8") as handle:
            prior_qa_rows = list(csv.DictReader(handle))
        failures = {(row["source_path"],row["raw_sha256"]) for row in prior_qa_rows if row["errors"]!="0"}
        refresh_rows = [row for row in candidates if re.search(args.refresh_qa_pattern,row["source_path"])
                        or (row["source_path"],row["raw_sha256"]) in failures]
        qa_input_path = output / "qa_refresh_candidates.csv"
        qa_output_path = output / "qa_refreshed.csv"
        write_csv(qa_input_path,refresh_rows)
    qa_script = r'''
args <- commandArgs(trailingOnly = TRUE)
source(file.path(args[[1L]], "R/club/openfootball_parser.R"))
index <- read.csv(args[[2L]], colClasses="character", check.names=FALSE)
results <- vector("list", nrow(index))
for (i in seq_len(nrow(index))) {
  item <- index[i, , drop=FALSE]
  parsed <- tryCatch(phase18_read_openfootball_source(item$local_path, item, strict=FALSE), error=identity)
  if (inherits(parsed,"error")) {
    results[[i]] <- data.frame(source_path=item$source_path,raw_sha256=item$raw_sha256,parsed=0L,declared=NA_integer_,
      completed=0L,scheduled=0L,awarded=0L,resolved=0L,errors=1L,count_matches=FALSE,
      all_fixtures_have_results=FALSE,group_league=0L,group_league_completed=0L,error_message=conditionMessage(parsed))
  } else {
    s <- attr(parsed,"summary")
    results[[i]] <- data.frame(source_path=item$source_path,raw_sha256=item$raw_sha256,parsed=nrow(parsed),
      declared=s$declared_matches,completed=s$completed_matches,scheduled=s$scheduled_matches,
      awarded=s$awarded_matches,resolved=sum(parsed$status=="completed" & parsed$score_semantics %in% c("regulation","extra_time","penalties")),
      errors=s$errors,count_matches=s$declared_count_matches,
      all_fixtures_have_results=s$all_fixtures_have_results,
      group_league=sum(parsed$stage %in% c("GROUP_STAGE","LEAGUE_STAGE")),
      group_league_completed=sum(parsed$stage %in% c("GROUP_STAGE","LEAGUE_STAGE") & parsed$status=="completed" & parsed$score_semantics=="regulation"),error_message="")
  }
}
write.csv(do.call(rbind,results),args[[3L]],row.names=FALSE,na="")
'''
    with tempfile.NamedTemporaryFile("w", suffix=".R", encoding="utf-8") as handle:
        handle.write(qa_script)
        handle.flush()
        if args.refresh_qa or args.refresh_qa_pattern or not (args.reuse_candidates and qa_path.exists()):
            subprocess.run(["rtk", "proxy", args.rscript, handle.name, str(project), str(qa_input_path), str(qa_output_path)], check=True)
    if prior_qa_rows is not None:
        with qa_output_path.open(newline="",encoding="utf-8") as handle:
            refreshed = {(row["source_path"],row["raw_sha256"]):row for row in csv.DictReader(handle)}
        merged = [refreshed.get((row["source_path"],row["raw_sha256"]),row) for row in prior_qa_rows]
        write_csv(qa_path,merged)
    with qa_path.open(newline="", encoding="utf-8") as handle:
        qa_rows = {(row["source_path"], row["raw_sha256"]): row for row in csv.DictReader(handle)}
    for row in candidates:
        row.update({f"qa_{key}": value for key,value in qa_rows[(row["source_path"],row["raw_sha256"])].items()
                    if key not in ("source_path","raw_sha256")})
        row["competition_id"] = {"deutschland":"germany","espana":"spain"}.get(row["competition_id"],row["competition_id"])
        row["source_id"] = f"{row['competition_id']}-{row['season_id']}"
        row["raw_relative_path"] = str(Path(row["local_path"]).relative_to(project / "data/club/local_raw"))
    write_csv(candidate_path,candidates)
    selections=[]
    for source in sources:
        rows = [row for row in candidates if row["source_path"] == source["path"]]
        valid = [row for row in rows if row["qa_errors"] == "0" and row["qa_count_matches"] == "TRUE"
                 and row["qa_parsed"] == row["expected_declared_matches"]]
        complete = [row for row in valid if row["qa_all_fixtures_have_results"] == "TRUE"]
        if rows[0]["competition_id"] == "ucl":
            complete = [row for row in rows if row["qa_errors"] == "0" and row["qa_count_matches"] == "TRUE"
                        and row["qa_group_league"] == source["group_league"]
                        and row["qa_group_league_completed"] == source["group_league"]]
        if complete and source["all_fixtures_have_results"] == "TRUE":
            chosen = min(complete,key=lambda row: (row["commit_utc"],row["commit_sha"]))
            state = "suggested_earliest_full_results_snapshot"
        else:
            partial = [row for row in valid if row["qa_completed"] == source["completed"]
                       and row["qa_awarded"] == source["awarded"]]
            latest = [row for row in rows if row["is_latest_file_bytes"] == "true"]
            chosen = min(partial,key=lambda row:(row["commit_utc"],row["commit_sha"])) if partial else latest[0]
            state = "partial_earliest_same_known_results_count_review_required"
            if chosen not in valid:
                state = "blocked_latest_native_parse_or_declared_count"
        selections.append(dict(selection_state=state,**chosen))
    write_csv(output / "suggested_selections.csv",selections)
    selected_report_script = r'''
args <- commandArgs(trailingOnly = TRUE)
source(file.path(args[[1L]], "R/club/openfootball_parser.R"))
index <- read.csv(args[[2L]], colClasses="character", check.names=FALSE)
name_rows <- exclusion_rows <- scope_rows <- list()
allowed <- c("REGULAR_SEASON","GROUP_STAGE","LEAGUE_STAGE","CHAMPIONSHIP_LEAGUE_STAGE",
             "RELEGATION_LEAGUE_STAGE","EUROPE_LEAGUE_STAGE")
for(i in seq_len(nrow(index))) {
  item <- index[i,,drop=FALSE]
  rows <- phase18_read_openfootball_source(item$local_path,item,strict=TRUE)
  keep <- rows$status=="completed" & rows$score_semantics=="regulation" & rows$stage %in% allowed
  scope_rows[[i]] <- data.frame(source_id=item$source_id,source_path=item$source_path,commit_utc=item$commit_utc,
    all_rows=nrow(rows),scope_matches=sum(keep),excluded_rows=sum(!keep),
    excluded_knockout=sum(!rows$stage %in% allowed),scheduled=sum(rows$status=="scheduled"),awarded=sum(rows$status=="awarded"))
  if(any(keep)) name_rows[[length(name_rows)+1L]] <- data.frame(source_id=item$source_id,source_path=item$source_path,
    raw_name=sort(unique(c(rows$home_name[keep],rows$away_name[keep]))))
  d <- attr(rows,"diagnostics")
  d$scope_included <- d$source_match_id %in% rows$source_match_id[keep]
  d$scope_exclusion_reason <- ifelse(d$scope_included,"",ifelse(d$reason!="",d$reason,"outside_reviewed_training_stage"))
  if(any(!d$scope_included)) {
    d <- d[!d$scope_included,,drop=FALSE]; d$source_id <- item$source_id; d$source_path <- item$source_path
    exclusion_rows[[length(exclusion_rows)+1L]] <- d
  }
}
write.csv(do.call(rbind,name_rows),file.path(args[[3L]],"selected_scope_names.csv"),row.names=FALSE)
write.csv(do.call(rbind,scope_rows),file.path(args[[3L]],"selected_scope_summary.csv"),row.names=FALSE)
write.csv(do.call(rbind,exclusion_rows),file.path(args[[3L]],"selected_scope_exclusions.csv"),row.names=FALSE)
'''
    with tempfile.NamedTemporaryFile("w", suffix=".R", encoding="utf-8") as handle:
        handle.write(selected_report_script)
        handle.flush()
        subprocess.run(["rtk", "proxy", args.rscript, handle.name, str(project),
                        str(output / "suggested_selections.csv"),str(output)],check=True)
    payload=dict(schema_version="openfootball-pin-candidates-v1",authority="review_candidates_only",
                 timestamp_semantics="Git committer UTC; not independently verified public publication time",
                 source_files=len(sources),distinct_candidates=len(candidates),
                 suggested_full_sources=sum(row["selection_state"]=="suggested_earliest_full_results_snapshot" for row in selections),
                 deleted_file_commits=deletions,
                 candidates=candidates,suggested_selections=selections)
    (output / "index.json").write_text(json.dumps(payload,indent=2)+"\n",encoding="utf-8")
    write_candidate_rows(project,output,args.rscript)
    print(json.dumps({key:value for key,value in payload.items() if key not in ("candidates","suggested_selections")}))


if __name__ == "__main__":
    main()
