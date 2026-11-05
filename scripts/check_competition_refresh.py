#!/usr/bin/env python3
"""Read-only health inspection, with an optional durable alert observation."""
import argparse
import datetime as dt
import json
import fcntl
import math
import os
from pathlib import Path
from competition_refresh import ROOT, SCHEMA, atomic_json, read_json, utcnow, validate_payloads


def observe_controller(current, base, now):
    """Keep a denied PID probe distinct from proof of a missing process."""
    problems, observations = [], []
    evidence = dict(process_state="unobserved", lock_state="unobserved")
    try:
        pid = int(current["process_id"])
        if pid <= 0 or str(current["process_id"]) != str(pid):
            raise ValueError("process_id must be a positive integer")
        started = dt.datetime.fromisoformat(current["started_at_utc"].replace("Z", "+00:00"))
        age = (now-started).total_seconds()/3600
        maximum = float(current.get("maximum_run_hours", 12))
        if not math.isfinite(maximum) or maximum <= 0 or age < 0:
            raise ValueError("run age and maximum_run_hours must be valid")
        evidence.update(process_id=pid, run_age_hours=age, maximum_run_hours=maximum)
    except (ValueError, TypeError, KeyError, AttributeError) as error:
        problems.append("Running controller record is invalid: "+str(error))
        return False, False, evidence, problems, observations

    gap = False
    try:
        os.kill(pid, 0)
        evidence["process_state"] = "observed"
    except ProcessLookupError:
        evidence["process_state"] = "absent"
        problems.append("Run record says running but its controller process is absent")
    except PermissionError:
        evidence["process_state"] = "permission_denied"
        gap = True
        observations.append("Controller process observation is denied; held-lock evidence cannot independently confirm its PID identity")
    except OSError as error:
        evidence["process_state"] = "observation_error"
        gap = True
        observations.append("Controller process observation failed: "+str(error))

    running = False
    try:
        with (base/"refresh.lock").open("a+") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX|fcntl.LOCK_NB)
            except BlockingIOError:
                lock.seek(0)
                if lock.read().strip() != str(pid):
                    evidence["lock_state"] = "held_by_other_pid"
                    problems.append("Refresh lock belongs to a different process")
                else:
                    evidence["lock_state"] = "held_with_matching_pid"
                    running = evidence["process_state"] != "absent"
            else:
                fcntl.flock(lock, fcntl.LOCK_UN)
                evidence["lock_state"] = "unheld"
                problems.append("Controller does not hold the refresh lock")
    except OSError as error:
        evidence["lock_state"] = "observation_error"
        problems.append("Cannot inspect the refresh lock: "+str(error))
    if age > maximum:
        running = False
        problems.append(f"Refresh exceeded its maximum run age ({age:.1f}h)")
    return running, gap, evidence, problems, observations


def inspect_health(root=ROOT, now=None, max_success_hours=48):
    root = Path(root)
    now = now or dt.datetime.now(dt.timezone.utc)
    base = root/"logs/competition-refresh"
    current, last = read_json(base/"current.json"), read_json(base/"last-success.json")
    problems, observations = [], []
    running = observation_gap = False
    controller = dict(process_state="not_running", lock_state="unobserved")
    if current.get("status") == "running":
        running, observation_gap, controller, issues, notes = observe_controller(current, base, now)
        problems.extend(issues)
        observations.extend(notes)
    elif current.get("status") == "failed":
        problems.append(current.get("phase", "unknown")+": "+current.get("error", "run failed"))
    if last.get("completed_at_utc"):
        age = (now-dt.datetime.fromisoformat(last["completed_at_utc"].replace("Z", "+00:00"))).total_seconds()/3600
        if age > max_success_hours:
            problems.append(f"Last successful refresh is {age:.1f}h old")
        if last.get("publication") != "verified":
            problems.append("Last local refresh has no verified public deployment")
    elif not running or observation_gap:
        problems.append("No successful non-WC refresh has been recorded")
    try:
        source_dates = validate_payloads(root/"docs/competitions", now)
    except Exception as error:
        source_dates = {}
        problems.append(str(error))
    return dict(schema_version=SCHEMA, observed_at_utc=now.isoformat(),
                state="failed" if problems else "observation_gap" if observation_gap else "running" if running else "healthy",
                run_id=current.get("run_id"), last_success_at_utc=last.get("completed_at_utc"),
                publication=last.get("publication"), problems=problems, source_dates=source_dates,
                controller_observation=controller, observations=observations)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write-observation", action="store_true")
    args = parser.parse_args()
    result = inspect_health()
    if args.write_observation:
        atomic_json(ROOT/"logs/competition-refresh/health.json", result)
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result["state"] in ("healthy", "running") else 1)
