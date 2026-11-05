#!/usr/bin/env python3
"""Read-only health inspection, with an optional durable alert observation."""
import argparse
import datetime as dt
import json
import fcntl
import os
from pathlib import Path
from competition_refresh import ROOT, SCHEMA, atomic_json, read_json, utcnow, validate_payloads


def inspect_health(root=ROOT, now=None, max_success_hours=48):
    root = Path(root)
    now = now or dt.datetime.now(dt.timezone.utc)
    base = root/"logs/competition-refresh"
    current, last = read_json(base/"current.json"), read_json(base/"last-success.json")
    problems = []
    running = False
    if current.get("status") == "running":
        try:
            os.kill(int(current["process_id"]), 0)
            started=dt.datetime.fromisoformat(current["started_at_utc"].replace("Z", "+00:00"))
            age=(now-started).total_seconds()/3600
            with (base/"refresh.lock").open("a+") as lock:
                try:
                    fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
                    fcntl.flock(lock,fcntl.LOCK_UN)
                    problems.append("Controller PID exists but does not hold the refresh lock")
                except BlockingIOError:
                    lock.seek(0)
                    if lock.read().strip()!=str(current["process_id"]):
                        problems.append("Refresh lock belongs to a different process")
                    elif age>float(current.get("maximum_run_hours",12)):
                        problems.append(f"Refresh exceeded its maximum run age ({age:.1f}h)")
                    else:
                        running = True
        except (OSError, ValueError, TypeError, KeyError):
            problems.append("Run record says running but its controller process is absent")
    elif current.get("status") == "failed":
        problems.append(current.get("phase", "unknown")+": "+current.get("error", "run failed"))
    if last.get("completed_at_utc"):
        age = (now-dt.datetime.fromisoformat(last["completed_at_utc"].replace("Z", "+00:00"))).total_seconds()/3600
        if age > max_success_hours:
            problems.append(f"Last successful refresh is {age:.1f}h old")
        if last.get("publication") != "verified":
            problems.append("Last local refresh has no verified public deployment")
    elif not running:
        problems.append("No successful non-WC refresh has been recorded")
    try:
        source_dates = validate_payloads(root/"docs/competitions", now)
    except Exception as error:
        source_dates = {}
        problems.append(str(error))
    return dict(schema_version=SCHEMA, observed_at_utc=now.isoformat(),
                state="failed" if problems else "running" if running else "healthy",
                run_id=current.get("run_id"), last_success_at_utc=last.get("completed_at_utc"),
                publication=last.get("publication"), problems=problems, source_dates=source_dates)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write-observation", action="store_true")
    args = parser.parse_args()
    result = inspect_health()
    if args.write_observation:
        atomic_json(ROOT/"logs/competition-refresh/health.json", result)
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result["state"] in ("healthy", "running") else 1)
