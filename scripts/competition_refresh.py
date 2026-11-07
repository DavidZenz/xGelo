#!/usr/bin/env python3
"""Fixed non-WC refresh controller with staged inputs and durable run evidence."""
from __future__ import annotations

import argparse
import contextlib
import ctypes
import datetime as dt
import fcntl
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import uuid
import urllib.request
from concurrent.futures import ThreadPoolExecutor
# Bind the arithmetic checker to this installed sibling, including when the
# controller is imported by absolute path in crash/recovery probes.
_cl_public_qa_spec = importlib.util.spec_from_file_location(
    "xgelo_cl_public_count_qa", Path(__file__).resolve().with_name("ucl_public_count_qa.py"))
_cl_public_qa = importlib.util.module_from_spec(_cl_public_qa_spec)
_cl_public_qa_spec.loader.exec_module(_cl_public_qa)
UCLPublicCountError = _cl_public_qa.UCLPublicCountError
validate_ucl_public_counts = _cl_public_qa.validate_ucl_public_counts

ROOT = Path(__file__).resolve().parents[1]
PUBLIC = Path("docs/competitions")
SCHEMA = "xgelo-competition-refresh-v1"
ROUTES = {"nations-league":"uefa_nations_league_2026_27",
          "euro-qualifying":"uefa_euro_2028_qualifying", "champions-league":"ucl_2026_27"}
PUBLIC_BASE_URL = "https://davidzenz.github.io/xGelo/competitions/"


def public_paths():
    return [Path(route)/name for route in ROUTES for name in
            ("index.html", "payload.json", "route-manifest.json", "current.json")] + [
            Path("phase21-batch-manifest.json"), Path("current.json")]


def validate_public_bytes(public):
    """Independent exact inventory/hash checks; the R schema/readiness gate also runs."""
    public = Path(public)
    actual = {p.relative_to(public).as_posix() for p in public.rglob("*") if p.is_file() or p.is_symlink()}
    if actual != {p.as_posix() for p in public_paths()}:
        raise RefreshError("Public batch inventory is not the exact14-file non-WC set")
    if any((public/p).is_symlink() or not (public/p).resolve().is_relative_to(public.resolve()) for p in public_paths()):
        raise RefreshError("Public batch contains an unsafe symlink/path")
    manifest, current = read_json(public/"phase21-batch-manifest.json"), read_json(public/"current.json")
    expected = sorted((PUBLIC/p).as_posix() for p in public_paths())
    batch = manifest.get("batch_id")
    if (manifest.get("schema_version") != "phase21-dashboard-v2" or current.get("schema_version") != "phase21-dashboard-v2" or
        not batch or current.get("status") != "accepted" or current.get("batch_id") != batch or
        current.get("manifest_sha256") != sha(public/"phase21-batch-manifest.json") or
        sorted(current.get("inventory", [])) != expected or sorted(manifest.get("inventory", [])) != expected or
        manifest.get("routes") != list(ROUTES)):
        raise RefreshError("Public current pointer/manifest inventory is invalid")
    for route, edition in ROUTES.items():
        rm, rc = read_json(public/route/"route-manifest.json"), read_json(public/route/"current.json")
        payload = read_json(public/route/"payload.json")
        if (rm.get("schema_version") != "phase21-dashboard-v2" or rc.get("schema_version") != "phase21-dashboard-v2" or
            payload.get("schema_version") != "phase21-dashboard-v2" or
            rm.get("route") != "/competitions/"+route+"/" or rc.get("route") != route or
            rc.get("edition_id") != edition or payload.get("metadata", {}).get("batch_id") != batch or
            rm.get("batch_id") != batch or rc.get("batch_id") != batch or
            rm.get("edition_id") != edition or payload.get("edition_id") != edition or
            rm.get("payload_sha256") != sha(public/route/"payload.json") or
            rm.get("html_sha256") != sha(public/route/"index.html") or
            rc.get("payload_sha256") != rm.get("payload_sha256") or
            manifest.get("route_manifests", {}).get(edition) != rm):
            raise RefreshError("Public route hash/identity mismatch: "+route)
    return {p.as_posix():sha(public/p) for p in public_paths()}


def utcnow():
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def atomic_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".status-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as handle:
            json.dump(value, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def read_json(path, default=None):
    try:
        return json.loads(Path(path).read_text())
    except (OSError, ValueError):
        return {} if default is None else default


def sha(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def file_inventory(root, paths):
    result = {}
    for relative in paths:
        p = root / relative
        if p.is_file():
            result[str(relative)] = sha(p)
        elif p.is_dir():
            for child in sorted(p.rglob("*")):
                if child.is_file() and not any(x in child.parts for x in ("__pycache__", ".git", "checkpoints")):
                    result[child.relative_to(root).as_posix()] = sha(child)
    return result


class RefreshError(RuntimeError):
    pass


def interrupted(signum, frame):
    raise InterruptedError(f"Refresh interrupted by signal {signum}")


class Run:
    def __init__(self, root, trigger="manual"):
        self.root = Path(root)
        self.base = self.root / "logs/competition-refresh"
        self.base.mkdir(parents=True, exist_ok=True)
        self.id = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ-") + uuid.uuid4().hex[:8]
        self.log = self.base / "runs" / (self.id + ".log")
        self.log.parent.mkdir(parents=True, exist_ok=True)
        last = read_json(self.base / "last-success.json")
        self.record = dict(schema_version=SCHEMA, run_id=self.id, trigger=trigger,
                           status="running", phase="initializing", started_at_utc=utcnow(),
                           process_id=os.getpid(), parent_process_id=os.getppid(),
                           maximum_run_hours=12, last_success_at_utc=last.get("completed_at_utc"),
                           log_path=str(self.log.relative_to(self.root)), stages=[])
        self.save()

    def save(self):
        atomic_json(self.base / "current.json", self.record)
        atomic_json(self.base / "runs" / (self.id + ".json"), self.record)

    def command(self, phase, args, cwd=None, env=None, timeout=7200):
        self.record["phase"] = phase
        self.save()
        started = time.monotonic()
        # Commands contain fixed script names and non-secret numeric/enum options.
        # Provider credentials are inherited/read by R and never included here.
        with self.log.open("a") as output:
            output.write(f"\n[{utcnow()}] {phase}\n")
            output.flush()
            print(f"XGELO_REFRESH phase={phase} run_id={self.id}", flush=True)
            child = subprocess.Popen([str(x) for x in args], cwd=cwd or self.root,
                                     env=env, stdout=output, stderr=subprocess.STDOUT,
                                     start_new_session=True)
            self.record["child_process_id"] = child.pid
            self.save()
            try:
                code = child.wait(timeout=timeout)
            except BaseException as error:
                os.killpg(child.pid, signal.SIGTERM)
                try:
                    child.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(child.pid, signal.SIGKILL)
                    child.wait()
                if isinstance(error, subprocess.TimeoutExpired):
                    raise RefreshError(f"{phase} exceeded its {timeout}s time limit") from error
                raise
        stage = dict(phase=phase, exit_code=code, elapsed_seconds=round(time.monotonic()-started, 3))
        self.record["stages"].append(stage)
        self.record.pop("child_process_id", None)
        self.save()
        if code:
            raise RefreshError(f"{phase} failed (exit {code}); see {self.record['log_path']}")

    def finish(self, status, error=None):
        self.record.update(status=status, completed_at_utc=utcnow())
        self.record.pop("child_process_id", None)
        if error:
            self.record["error"] = str(error) or type(error).__name__
        if status == "success":
            self.record["last_success_at_utc"] = self.record["completed_at_utc"]
            atomic_json(self.base / "last-success.json", self.record)
            public_state = "healthy" if self.record.get("publication") == "verified" else "local_only"
            if public_state == "healthy":
                atomic_json(self.base / "last-public-success.json", self.record)
            atomic_json(self.base / "alert.json", dict(schema_version=SCHEMA, state=public_state,
                                                       run_id=self.id, observed_at_utc=utcnow()))
        elif status == "failed":
            atomic_json(self.base / "alert.json", dict(schema_version=SCHEMA, state="failed",
                run_id=self.id, observed_at_utc=utcnow(), phase=self.record["phase"], error=str(error)))
        self.save()


@contextlib.contextmanager
def exclusive_lock(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a+") as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RefreshError("Another non-WC refresh currently holds the process lock")
        handle.seek(0)
        handle.truncate()
        handle.write(str(os.getpid()) + "\n")
        handle.flush()
        try:
            yield
        finally:
            fcntl.flock(handle, fcntl.LOCK_UN)


def discover_rscript(root, env=None):
    helper = Path(root) / "scripts/lib/rscript_runtime.sh"
    result = subprocess.run(["/bin/bash", "-c", 'source "$1"; xgelo_resolve_rscript && printf "%s\\n" "$R_SCRIPT"',
                             "xgelo-runtime", str(helper)], capture_output=True, text=True,
                            env=env, timeout=20)
    if result.returncode:
        raise RefreshError(result.stderr.strip() or "Rscript discovery failed")
    lines = result.stdout.splitlines()
    if not lines or not Path(lines[-1]).is_file():
        raise RefreshError("Rscript discovery did not return an executable path")
    return lines[-1], result.stderr.strip()


def managed_paths(root):
    """The only roots the controller may install; none include WC artifacts."""
    return [Path("data/competition"),
            Path("outputs/competition/uefa_nations_league_2026_27"),
            Path("outputs/competition/uefa_euro_2028_qualifying"),
            Path("outputs/competition/ucl_2026_27"), PUBLIC]


def copy_workspace(root, destination):
    # A private snapshot prevents source/state/outcome failures from mutating
    # any accepted input or valid public page in the operator checkout.
    for relative in ("R", "scripts", ".planning", "data", "outputs/competition", "outputs/releases", "docs/competitions"):
        src = root / relative
        if src.exists():
            shutil.copytree(src, destination / relative,
                            ignore=shutil.ignore_patterns(".git", "__pycache__", "*.lock", "checkpoints"))
    for name in ("renv.lock", "DESCRIPTION"):
        if (root/name).is_file():
            shutil.copy2(root/name, destination/name)
    # The approved national release callback authenticates the frozen baseline
    # inventory before loading its release, even in accepted-state read mode.
    baseline = Path("outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/manifests/model_manifests.csv")
    if (root/baseline).is_file():
        (destination/baseline).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root/baseline, destination/baseline)


def approved_release_inventory(root, include_club=False):
    inventory = file_inventory(root, [Path("outputs/releases"),
        Path("outputs/benchmarks/rolling_tournaments/phase09-baselines-frozen/manifests/model_manifests.csv")])
    return {path:digest for path,digest in inventory.items()
            if include_club or not path.startswith("outputs/releases/club/")}


@contextlib.contextmanager
def retained_workspace(run):
    staging = run.base / "workspaces"
    staging.mkdir(mode=0o700, exist_ok=True)
    if staging.is_symlink() or staging.stat().st_uid != os.getuid() or staging.stat().st_mode & 0o077:
        raise RefreshError("Refresh workspace directory must be private and owned by the operator")
    parent = Path(tempfile.mkdtemp(prefix="xgelo-refresh-"+run.id+"-", dir=staging))
    parent.chmod(0o700)
    workspace = parent/"project"
    workspace.mkdir()
    run.record.update(private_workspace_path=str(workspace), workspace_retained=True)
    run.save()
    try:
        yield workspace
    finally:
        # Once installed, accepted inputs/outcomes are durable in the operator
        # checkout and a push retry uses the exact install receipt. Before that,
        # keep every failed computation intact for an explicitly validated retry.
        if run.record.get("workspace_installed"):
            try:
                shutil.rmtree(parent)
                run.record["workspace_retained"] = False
            except OSError as error:
                run.record["workspace_cleanup_error"] = str(error)
                run.record["workspace_retained"] = True
        else:
            run.record["workspace_retained"] = True
        run.save()


def resolve_failed_workspace(root, run_id, before, releases):
    if not re.fullmatch(r"\d{8}T\d{6}Z-[0-9a-f]{8}", run_id):
        raise RefreshError("A failed refresh must be identified by its exact run id")
    record = read_json(root/"logs/competition-refresh/runs"/(run_id+".json"))
    completed = any(stage.get("phase")=="nations_league_outcomes" and stage.get("exit_code")==0
                    for stage in record.get("stages", []))
    if (record.get("schema_version") != SCHEMA or record.get("run_id") != run_id or record.get("status") != "failed" or
        not record.get("workspace_retained") or not completed):
        raise RefreshError("No retained failed computation with completed production outcomes exists for that run")
    workspace = Path(record.get("private_workspace_path", ""))
    temporary = Path(tempfile.gettempdir()).resolve()
    staging = root/"logs/competition-refresh/workspaces"
    allowed_roots = {temporary}
    if staging.is_dir() and not staging.is_symlink() and staging.stat().st_uid == os.getuid() and not staging.stat().st_mode & 0o077:
        allowed_roots.add(staging.resolve())
    workspace_base = workspace.parent.parent.resolve()
    if (not workspace.is_absolute() or workspace.is_symlink() or workspace.parent.is_symlink() or not workspace.is_dir() or
        workspace.name!="project" or not workspace.parent.name.startswith("xgelo-refresh-"+run_id+"-") or
        workspace_base not in allowed_roots or not workspace.resolve().is_relative_to(workspace_base) or
        workspace.stat().st_uid!=os.getuid()):
        raise RefreshError("Retained workspace path/ownership is invalid; no recovery attempted")
    if record.get("managed_inputs_before") != before or record.get("approved_releases_before") != releases:
        raise RefreshError("Accepted inputs or approved releases changed after that failed run; recovery would overwrite newer state")
    return workspace


def restore_missing_recovery_inputs(root, workspace, before, releases):
    """Restore recorded dependencies in the recovery copy only."""
    dependencies = dict(releases)
    seed = "data/processed/elo_ratings.csv"
    # Older run receipts did not inventory this read-only input. The saved
    # forecast provenance pins its bytes, and R independently validates and
    # replays that provenance before allowing installation.
    if not (workspace / seed).is_file():
        provenance = read_json(workspace / "outputs/competition/uefa_nations_league_2026_27/forecast_inputs/elo_provenance.json")
        seed_digest = provenance.get("seed_sha256")
        if isinstance(seed_digest, str) and re.fullmatch(r"[0-9a-f]{64}", seed_digest):
            dependencies[seed] = seed_digest
    restored = []
    for relative, digest in {**before, **dependencies}.items():
        target = workspace / relative
        if target.is_file() or relative.startswith("docs/competitions/"):
            continue
        if relative not in dependencies and not relative.startswith("data/competition/local_raw/"):
            raise RefreshError("Retained workspace is missing a required artifact: " + relative)
        source = root / relative
        if not source.is_file() or sha(source) != digest:
            raise RefreshError("Original recovery dependency is unavailable: " + relative)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        if sha(target) != digest:
            raise RefreshError("Restored recovery dependency differs from its recorded hash: " + relative)
        restored.append(relative)
    return restored


def validate_nl_forecast_input_evidence(payload, now):
    """Check input coherence; this alone cannot certify an outcome or a page.

    A recent feed check alone cannot establish that forecasts consumed its
    completed results. This projection is also used by the read-only monitor.
    Actual private CSV/JSON bytes and rating replay are validated by R before
    publication; these public fields cannot grant model/source authority.
    """
    meta = payload.get("metadata", {})
    evidence = payload.get("forecast_input_evidence")

    def fail(reason):
        raise RefreshError("Nations League forecast inputs: " + reason)

    def timestamp(value, label):
        if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z", value):
            fail(label + " must be canonical UTC")
        try:
            return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            fail(label + " is not a valid UTC instant")

    def count(value, label, minimum=0):
        if (isinstance(value, bool) or not isinstance(value, (int, float)) or
                not math.isfinite(value) or not float(value).is_integer() or value < minimum):
            fail(label + " must be an integer >= " + str(minimum))
        return int(value)

    if (meta.get("forecast_input_contract") != "nl-local-elo-v1" or
            meta.get("forecast_input_status") != "validated" or not isinstance(evidence, dict) or
            evidence.get("schema_version") != "nl-local-elo-v1"):
        fail("validated local rating evidence is missing or unsupported")
    hashes = ("forecast_input_sha256", "forecast_input_provenance_sha256", "forecast_input_seed_sha256",
              "forecast_input_results_sha256", "forecast_input_source_bundle_sha256", "forecast_input_policy_sha256")
    for key in hashes:
        value = meta.get(key)
        if not isinstance(value, str) or not re.fullmatch("[0-9a-f]{64}", value) or evidence.get(key) != value:
            fail("missing or inconsistent parent hash: " + key)
    if meta["forecast_input_source_bundle_sha256"] != meta.get("source_bundle_sha256"):
        fail("rating evidence belongs to a different accepted source")

    time_keys = ("forecast_input_as_of_utc", "forecast_input_base_cutoff_utc",
                 "forecast_input_base_latest_evidence_at_utc", "forecast_input_earliest_team_evidence_at_utc",
                 "forecast_input_latest_evidence_at_utc")
    times = {key: timestamp(meta.get(key), key) for key in time_keys}
    as_of, boundary = times[time_keys[0]], times[time_keys[1]]
    for key in ("last_refresh_at_utc", "source_as_of_utc", "accepted_data_cutoff_utc"):
        if timestamp(meta.get(key), key) != as_of:
            fail("rating evidence is not synchronized with " + key)
    if not times["forecast_input_base_latest_evidence_at_utc"] < boundary <= as_of:
        fail("seed evidence must precede the pre-edition boundary and source cutoff")
    if not (times["forecast_input_earliest_team_evidence_at_utc"] <= times["forecast_input_latest_evidence_at_utc"] <=
            as_of <= now + dt.timedelta(minutes=5)):
        fail("rating/source evidence chronology is inconsistent")

    team_count = count(meta.get("forecast_input_team_count"), "team count", minimum=2)
    completed_count = count(meta.get("forecast_input_completed_result_count"), "completed result count")
    teams = evidence.get("per_team")
    if not isinstance(teams, list) or len(teams) != team_count or any(not isinstance(row, dict) for row in teams):
        fail("per-team evidence does not cover the complete roster")
    team_ids = [row.get("team_id") for row in teams]
    if any(not isinstance(team, str) or not re.fullmatch("team_[a-z0-9_]+", team) for team in team_ids):
        fail("per-team national identity is malformed")
    if len(set(team_ids)) != team_count:
        fail("per-team evidence contains duplicate identities")
    standings = payload.get("current_standings")
    if not isinstance(standings, list) or any(not isinstance(row, dict) for row in standings):
        fail("current standings roster is missing")
    roster = [row.get("team_id") for row in standings]
    if len(roster) != team_count or set(roster) != set(team_ids):
        fail("per-team evidence and current standings roster differ")
    results = payload.get("sections", {}).get("results", {}).get("rows")
    if not isinstance(results, list) or any(not isinstance(row, dict) for row in results):
        fail("accepted result evidence is missing")
    participant_dates = {team: [] for team in team_ids}
    fixture_ids, admitted = set(), 0
    for row in results:
        fixture = row.get("fixture_id")
        if not isinstance(fixture, str) or not fixture or fixture in fixture_ids:
            fail("accepted result fixture identities are missing or duplicated")
        fixture_ids.add(fixture)
        if row.get("counts_for_form") is not True:
            continue
        if row.get("match_status") != "completed":
            fail("an unconfirmed result cannot update ratings")
        completion = timestamp(row.get("evidence_completed_at_utc"), "accepted result completion")
        if completion > as_of:
            fail("accepted result evidence is later than the source cutoff")
        if completion <= boundary:
            continue
        home, away = row.get("home_team_id"), row.get("away_team_id")
        if home == away or home not in participant_dates or away not in participant_dates:
            fail("completed result participants do not match the current roster")
        participant_dates[home].append(completion)
        participant_dates[away].append(completion)
        admitted += 1
    seed_times, latest_times, consumed_counts = [], [], []
    for row in teams:
        seed = timestamp(row.get("seed_evidence_at_utc"), "team seed evidence")
        latest = timestamp(row.get("latest_evidence_at_utc"), "team latest evidence")
        consumed = count(row.get("consumed_result_count"), "team consumed result count")
        if not seed < boundary or not seed <= latest <= as_of:
            fail("per-team evidence is outside its causal window")
        if (consumed == 0 and latest != seed) or (consumed > 0 and not boundary < latest):
            fail("per-team evidence does not agree with its consumed results")
        seed_times.append(seed)
        latest_times.append(latest)
        consumed_counts.append(consumed)
    if (max(seed_times) != times["forecast_input_base_latest_evidence_at_utc"] or
            min(latest_times) != times["forecast_input_earliest_team_evidence_at_utc"] or
            max(latest_times) != times["forecast_input_latest_evidence_at_utc"]):
        fail("aggregate evidence dates differ from the per-team dates")
    if sum(consumed_counts) != 2 * completed_count or any(value > completed_count for value in consumed_counts):
        fail("completed-result participant accounting is inconsistent")
    if admitted != completed_count:
        fail("completed-result count differs from accepted result evidence")
    for row, seed, latest, consumed in zip(teams, seed_times, latest_times, consumed_counts):
        actual = participant_dates[row["team_id"]]
        if consumed != len(actual) or latest != max([seed] + actual):
            fail("per-team ratings did not consume their accepted completed results")
    return {key: meta[key] for key in time_keys +
            ("forecast_input_contract", "forecast_input_status", "forecast_input_team_count",
             "forecast_input_completed_result_count") + hashes}


def validate_nl_forecast_inputs(payload, now):
    """Require both synchronized inputs and genuine projection/page chronology."""
    evidence = validate_nl_forecast_input_evidence(payload, now)
    meta = payload["metadata"]
    times = []
    for key in ("projection_generated_at_utc", "generated_at_utc"):
        value = meta.get(key)
        if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z", value):
            raise RefreshError("Nations League forecast inputs: " + key + " must be canonical UTC")
        try:
            times.append(dt.datetime.fromisoformat(value.replace("Z", "+00:00")))
        except ValueError:
            raise RefreshError("Nations League forecast inputs: " + key + " is not a valid UTC instant")
        evidence[key] = value
    as_of = dt.datetime.fromisoformat(evidence["forecast_input_as_of_utc"].replace("Z", "+00:00"))
    if not as_of <= times[0] <= times[1] <= now + dt.timedelta(minutes=5):
        raise RefreshError("Nations League forecast inputs: rating/source/projection/page evidence chronology is inconsistent")
    return evidence


def validate_payloads(public, now=None):
    validate_public_bytes(public)
    now = now or dt.datetime.now(dt.timezone.utc)
    dates = {}
    for route in ("nations-league", "euro-qualifying", "champions-league"):
        p = read_json(public/route/"payload.json")
        if not p or not (public/route/"index.html").is_file():
            raise RefreshError(f"Missing validated route: {route}")
        meta, sections = p.get("metadata", {}), p.get("sections", {})
        dates[route] = {key: meta.get(key) for key in
            ("last_refresh_at_utc", "source_as_of_utc", "accepted_data_cutoff_utc", "generated_at_utc",
             "forecast_status", "forecast_reason_code", "model_release_id", "simulation_count")}
        if route != "euro-qualifying":
            instant = meta.get("last_refresh_at_utc") or meta.get("accepted_data_cutoff_utc")
            if not instant:
                raise RefreshError(f"{route} has no source check timestamp")
            if not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z", instant):
                raise RefreshError(f"{route} source timestamp must be canonical UTC")
            age = (now-dt.datetime.fromisoformat(instant.replace("Z", "+00:00"))).total_seconds()
            limit = 48
            if age < -300 or age > limit*3600:
                raise RefreshError(f"{route} source is stale or future-dated (age {age/3600:.1f}h)")
            dates[route]["source_age_hours"] = round(age/3600, 3)
        if route == "nations-league":
            count = meta.get("simulation_count")
            if isinstance(count, bool) or not isinstance(count, (float, int)) or not float(count).is_integer():
                raise RefreshError("Nations League simulation count is not an integer")
            n = int(count)
            # <=1pp worst-case 95% pointwise MC precision, independently of
            # whether a historical 100-simulation output already exists.
            if n < 9600:
                raise RefreshError(f"Nations League precision gate failed: {n} simulations")
            dates[route].update(validate_nl_forecast_inputs(p, now))
        if route == "euro-qualifying" and meta.get("lifecycle_state") == "pre_draw":
            if any(sections.get(s, {}).get("rows") for s in ("fixtures", "match_forecasts", "projected_outcomes")):
                raise RefreshError("EURO pre-draw route contains invented fixtures or forecasts")
        elif route == "euro-qualifying":
            if not sections.get("structure", {}).get("rows") or not sections.get("fixtures", {}).get("rows"):
                raise RefreshError("EURO activation requires accepted official structure and fixtures")
        if route != "euro-qualifying" and meta.get("source_status") != "accepted":
            raise RefreshError("Public quantitative route has no accepted source: "+route)
        if route == "champions-league":
            try:
                count_check = validate_ucl_public_counts(p)
            except UCLPublicCountError as error:
                raise RefreshError(str(error)) from error
            dates[route]["tournament_count_qa"] = count_check
            rows = sections.get("fixtures", {}).get("rows", []) + sections.get("match_forecasts", {}).get("rows", [])
            for row in rows:
                instant = row.get("Kickoff (UTC)", row.get("kickoff_utc"))
                if not instant or not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z", instant):
                    raise RefreshError("CL kickoff must be complete canonical UTC")
                if dt.datetime.fromisoformat(instant.replace("Z", "+00:00")) <= now:
                    raise RefreshError("Past CL kickoff remains in upcoming fixtures or forecasts")
            predictions = sections.get("match_forecasts", {}).get("rows", [])
            if len(predictions) > 1:
                triples = {tuple(r.get(k) for k in ("Home win", "Draw", "Away win")) for r in predictions}
                reason = str(sections.get("match_forecasts", {}).get("reason", "")).lower()
                if len(triples) == 1 and "baseline" not in reason:
                    raise RefreshError("Identical CL defaults lack an explicit baseline disclosure")
    return dates


def recover_install(root, journal):
    data = read_json(journal)
    if data.get("state") != "installing":
        return
    backup = Path(data["backup_root"])
    allowed = {p.as_posix() for p in managed_paths(root)}
    if {p for p, _ in data["targets"]} != allowed or not backup.resolve().is_relative_to((root/"logs/competition-refresh/backups").resolve()):
        raise RefreshError("Unsafe installation journal; recovery refused")
    if any(existed and not (backup/relative).exists() for relative, existed in data["targets"]):
        raise RefreshError("Incomplete recovery backup; existing files preserved")
    for relative, existed in reversed(data["targets"]):
        target, old = root/relative, backup/relative
        if existed:
            target.parent.mkdir(parents=True, exist_ok=True)
            recovery = target.with_name("."+target.name+"-recovery-"+data["run_id"])
            shutil.rmtree(recovery, ignore_errors=True)
            shutil.copytree(old, recovery)
            if target.exists():
                exchange_directories(target, recovery)
                shutil.rmtree(recovery)
            else:
                os.replace(recovery, target)
        elif target.is_dir():
            shutil.rmtree(target)
        elif target.exists():
            target.unlink()
    data["state"] = "rolled_back"
    atomic_json(journal, data)


def exchange_directories(first, second):
    """Atomically exchange sibling directory names; readers always see a batch."""
    libc = ctypes.CDLL(None, use_errno=True)
    first, second = os.fsencode(first), os.fsencode(second)
    if sys.platform == "darwin":
        operation = libc.renamex_np
        operation.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint]
        result = operation(first, second, 2)  # RENAME_SWAP
    elif sys.platform.startswith("linux") and hasattr(libc, "renameat2"):
        operation = libc.renameat2
        operation.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
        result = operation(-100, first, -100, second, 2)  # AT_FDCWD, RENAME_EXCHANGE
    else:
        raise RefreshError("Atomic directory exchange is unavailable on this runtime")
    if result:
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error))


def install_workspace(root, workspace, expected_before, run):
    targets = managed_paths(root)
    if file_inventory(root, targets) != expected_before:
        raise RefreshError("Managed inputs changed during refresh; preserving concurrent edits")
    backup = run.base/"backups"/run.id
    backup.mkdir(parents=True)
    journal = run.base/"install-journal.json"
    entries = []
    atomic_json(journal, dict(state="preparing", run_id=run.id, backup_root=str(backup)))
    for relative in targets:
        source = root/relative
        existed = source.exists()
        if existed:
            shutil.copytree(source, backup/relative) if source.is_dir() else shutil.copy2(source, backup/relative)
        entries.append((relative.as_posix(), existed))
    atomic_json(journal, dict(state="preparing", run_id=run.id, backup_root=str(backup), targets=entries))
    try:
        # Materialize every complete directory beside its destination before
        # swapping. The journal restores every root if any swap/read-back fails.
        stages = {}
        for relative in targets:
            target, source = root/relative, workspace/relative
            stage = target.with_name("."+target.name+"-install-"+run.id)
            shutil.copytree(source, stage)
            stages[relative] = stage
        if file_inventory(root, targets) != expected_before:
            # Nothing was swapped: preserve concurrent edits rather than
            # restoring the older backup over them.
            atomic_json(journal, dict(state="aborted_concurrent_edit", run_id=run.id))
            raise RefreshError("Managed inputs changed during staging; preserving concurrent edits")
        atomic_json(journal, dict(state="installing", run_id=run.id, backup_root=str(backup), targets=entries))
        for relative in targets:
            target, stage = root/relative, stages[relative]
            if target.exists():
                exchange_directories(target, stage)
            else:
                os.replace(stage, target)
        validate_payloads(root/PUBLIC)
        atomic_json(journal, dict(state="committed", run_id=run.id, targets=entries))
        receipt = dict(schema_version=SCHEMA, status="validated", run_id=run.id,
                       installed_at_utc=utcnow(), public_inventory=validate_public_bytes(root/PUBLIC),
                       source_dates=run.record.get("source_dates", {}))
        atomic_json(run.base/"validated-install.json", receipt)
    except BaseException:
        if read_json(journal).get("state") == "installing":
            recover_install(root, journal)
        raise
    finally:
        if read_json(journal).get("state") != "installing":
            shutil.rmtree(backup, ignore_errors=True)
            for relative in targets:
                shutil.rmtree((root/relative).with_name("."+relative.name+"-install-"+run.id), ignore_errors=True)


def validate_git_index(checkout, expected):
    names = subprocess.check_output(["git", "ls-files", "--", str(PUBLIC)], cwd=checkout, text=True).splitlines()
    paths = {str(PUBLIC/relative): digest for relative, digest in expected.items()}
    if set(names) != set(paths):
        raise RefreshError("Publisher index inventory differs from the validated batch")
    for path, digest in paths.items():
        content = subprocess.check_output(["git", "show", ":"+path], cwd=checkout)
        if hashlib.sha256(content).hexdigest() != digest:
            raise RefreshError("Publisher index bytes differ from the validated batch: "+path)


def validate_git_commit(checkout, expected, commit):
    names = subprocess.check_output(["git", "ls-tree", "-r", "--name-only", commit,
                                     "--", str(PUBLIC)], cwd=checkout, text=True).splitlines()
    paths = {str(PUBLIC/relative): digest for relative, digest in expected.items()}
    if set(names) != set(paths):
        raise RefreshError("Publisher commit inventory differs from the validated batch")
    for path, digest in paths.items():
        content = subprocess.check_output(["git", "show", commit+":"+path], cwd=checkout)
        if hashlib.sha256(content).hexdigest() != digest:
            raise RefreshError("Publisher commit bytes differ from the validated batch: "+path)


def public_readback(expected, run_id):
    def read_one(item):
        path, digest = item
        request = urllib.request.Request(PUBLIC_BASE_URL+path+"?refresh="+run_id,
                                         headers={"User-Agent":"xGelo-dashboard-health/1.0", "Cache-Control":"no-cache"})
        with urllib.request.urlopen(request, timeout=15) as response:
            body = response.read(25*1024*1024+1)
            if response.status != 200 or hashlib.sha256(body).hexdigest() != digest:
                raise RefreshError("Published bytes do not yet match the validated candidate: "+path)
        return path
    with ThreadPoolExecutor(max_workers=6) as pool:
        return list(pool.map(read_one, expected.items()))


def verify_publication(run, expected, attempts=30, interval_seconds=20):
    run.record["phase"] = "published_readback"
    run.save()
    started = time.monotonic()
    for attempt in range(attempts):
        try:
            paths = public_readback(expected, run.id)
            run.record["publication"] = "verified"
            run.record["public_verification"] = dict(verified_at_utc=utcnow(),
                base_url=PUBLIC_BASE_URL, file_count=len(paths), attempts=attempt+1,
                elapsed_seconds=round(time.monotonic()-started, 3))
            run.save()
            return
        except Exception as error:
            run.record["publication_readback_error"] = str(error)
            run.save()
            if attempt+1 == attempts:
                raise RefreshError("Public deployment read-back did not converge: "+str(error)) from error
            time.sleep(interval_seconds)


def publish_pages(root, run):
    """Push only validated competition pages from an isolated Git checkout."""
    with tempfile.TemporaryDirectory(prefix="xgelo-pages-") as temp:
        frozen, checkout = Path(temp)/"frozen", Path(temp)/"publisher"
        shutil.copytree(root/PUBLIC, frozen)
        run.record["source_dates"] = validate_payloads(frozen)
        frozen_hashes = validate_public_bytes(frozen)
        run.command("publication_schema_qa", [run.record["runtime"]["executable"], "--vanilla",
            str(root/"scripts/validate_non_wc_publication.R"), "--public-root", str(frozen)])
        run.command("publisher_clone", ["git", "clone", "--shared", "--no-checkout", str(root), str(checkout)])
        remote = subprocess.check_output(["git", "remote", "get-url", "origin"], cwd=root, text=True).strip()
        run.command("publisher_remote", ["git", "remote", "set-url", "origin", remote], cwd=checkout)
        run.command("publisher_fetch", ["git", "fetch", "origin", "master"], cwd=checkout, timeout=120)
        run.command("publisher_checkout", ["git", "checkout", "--detach", "FETCH_HEAD"], cwd=checkout)
        target = checkout/PUBLIC
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(frozen, target)
        if validate_public_bytes(target) != frozen_hashes:
            raise RefreshError("Copied publisher bytes differ from the validated frozen candidate")
        run.command("publisher_stage", ["git", "add", "--", str(PUBLIC)], cwd=checkout)
        staged = subprocess.check_output(["git", "diff", "--cached", "--name-only"], cwd=checkout, text=True).splitlines()
        if any(not p.startswith("docs/competitions/") for p in staged):
            raise RefreshError("Publisher attempted to change a path outside the competition routes")
        validate_git_index(checkout, frozen_hashes)
        if not staged:
            run.record["publication"] = "unchanged"
            verify_publication(run, frozen_hashes)
            return
        run.command("publisher_diff_check", ["git", "diff", "--cached", "--check"], cwd=checkout)
        if validate_public_bytes(target) != frozen_hashes:
            raise RefreshError("Publication bytes changed before commit")
        run.command("publisher_commit", ["git", "commit", "-m", "Refresh validated non-WC dashboards " + run.id], cwd=checkout)
        run.record["publication_commit"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=checkout, text=True).strip()
        commit = run.record["publication_commit"]
        validate_git_commit(checkout, frozen_hashes, commit)
        run.command("publisher_push", ["git", "push", "origin", commit+":refs/heads/master"], cwd=checkout, timeout=120)
        run.record["publication"] = "pushed"
        run.save()
        verify_publication(run, frozen_hashes)


def refresh(args, root=ROOT):
    run = None
    base = root/"logs/competition-refresh"
    with exclusive_lock(base/"refresh.lock"):
        recover_install(root, base/"install-journal.json")
        run = Run(root, "scheduled" if args.scheduled else "manual")
        try:
            run.record["phase"] = "runtime_discovery"
            run.save()
            executable, diagnostic = discover_rscript(root)
            run.record["runtime"] = dict(executable=executable, diagnostic=diagnostic)
            run.save()
            if args.dry_run:
                run.finish("dry_run")
                print(json.dumps(run.record))
                return 0
            if args.publish_only:
                run.record["source_dates"] = validate_payloads(root/PUBLIC)
                receipt = read_json(run.base/"validated-install.json")
                inventory = validate_public_bytes(root/PUBLIC)
                if (receipt.get("schema_version") != SCHEMA or receipt.get("status") != "validated" or
                    receipt.get("public_inventory") != inventory):
                    raise RefreshError("Publish-only requires the exact inventory of a validated installed refresh")
                run.record["public_inventory"] = inventory
                run.record["validated_install_run_id"] = receipt.get("run_id")
                publish_pages(root, run)
                run.finish("success")
                return 0
            targets = managed_paths(root)
            before = file_inventory(root, targets)
            code_before = file_inventory(root, [Path("R"), Path("scripts")])
            releases_before = approved_release_inventory(root, args.cl_forecasts=="approved")
            run.record["managed_inputs_before"] = before
            run.record["approved_releases_before"] = releases_before
            resume = resolve_failed_workspace(root, args.resume_failed, before, releases_before) if args.resume_failed else None
            with retained_workspace(run) as workspace:
                run.record["phase"] = "workspace_snapshot"
                run.save()
                copy_workspace(resume or root, workspace)
                if resume:
                    # Preserve the original failed candidate; retry with the
                    # current tested runtime while retaining exact source times,
                    # model/outcome identities and real completed MC evidence.
                    for relative in ("R", "scripts"):
                        if (workspace/relative).exists():
                            shutil.rmtree(workspace/relative)
                        shutil.copytree(root/relative, workspace/relative,
                                        ignore=shutil.ignore_patterns("__pycache__"))
                    run.record["restored_recovery_inputs"] = restore_missing_recovery_inputs(
                        root, workspace, before, releases_before)
                    run.record["resumed_failed_run_id"] = args.resume_failed
                normal_env = os.environ.copy()
                # Acquisition records a genuine immutable parser Git commit;
                # the private workspace does not need or modify its own .git.
                git_dir = subprocess.check_output(["git","-C",str(root),"rev-parse","--absolute-git-dir"],text=True).strip()
                stage_env = dict(os.environ, GIT_DIR=git_dir, GIT_WORK_TREE=str(workspace), GIT_OPTIONAL_LOCKS="0")
                normal_env.update(stage_env)
                if (root/".Renviron").is_file():
                    normal_env["R_ENVIRON_USER"] = str(root/".Renviron")
                run.record["reused_accepted_outcomes"] = bool(args.restage_only or resume)
                if args.restage_only or resume:
                    receipt = read_json(run.base/"validated-install.json")
                    run.record["reused_install_run_id"] = receipt.get("run_id")
                    run.save()
                else:
                    run.command("nations_league_source", [executable,"--vanilla","scripts/acquire_uefa_snapshot.R",
                        "--official-uefa-nations-league","--edition-id","uefa_nations_league_2026_27",
                        "--operator","automation","--operator-action","validated non-WC refresh",
                        "--validation-passed","true","--publish-accepted"], cwd=workspace, env=stage_env)
                    run.command("champions_league_source", [executable,"--no-init-file","--no-site-file",
                        "scripts/update_ucl_live_source.R","--source-only"], cwd=workspace, env=normal_env)
                    run.command("nations_league_state", [executable,"--vanilla","scripts/refresh_nations_league_state.R"], cwd=workspace, env=stage_env)
                    report_dir = workspace/"outputs/non-wc-precision-evidence"
                    try:
                        run.command("nations_league_outcomes", [executable,"--vanilla","scripts/build_nations_league_outcomes.R",
                            "--edition-id","uefa_nations_league_2026_27","--simulations",str(args.simulations),
                            "--workers",str(args.workers),"--seed","15017","--write",
                            "--precision-report-dir",str(report_dir)], cwd=workspace, env=stage_env)
                    finally:
                        if report_dir.is_dir():
                            evidence = run.base/"benchmarks"/run.id
                            shutil.copytree(report_dir,evidence,dirs_exist_ok=True)
                            run.record["precision_report_dir"] = evidence.relative_to(root).as_posix()
                            run.save()
                run.command("dashboard_stage", [executable,"--vanilla","scripts/stage_non_wc_dashboards.R",
                    "--stage-root",str(workspace/"docs/non-wc-candidate"),
                    "--cl-forecasts="+args.cl_forecasts,"--publish"], cwd=workspace, env=stage_env)
                run.command("candidate_authority_qa", [executable,"--vanilla",
                    str(workspace/"scripts/validate_non_wc_publication.R"),
                    "--public-root",str(workspace/PUBLIC)],cwd=workspace,env=stage_env)
                run.record["source_dates"] = validate_payloads(workspace/PUBLIC)
                run.record["public_inventory"] = validate_public_bytes(workspace/PUBLIC)
                # Keep the existing standalone CL preview synchronized with the
                # validated route, rather than performing a second inference.
                preview = workspace/"outputs/competition/ucl_2026_27/dashboard"
                preview.mkdir(parents=True, exist_ok=True)
                for name in ("index.html", "payload.json"):
                    shutil.copy2(workspace/PUBLIC/"champions-league"/name, preview/name)
                if file_inventory(root, [Path("R"), Path("scripts")]) != code_before:
                    raise RefreshError("Runtime code changed during refresh; candidate not installed")
                if approved_release_inventory(root, args.cl_forecasts=="approved") != releases_before:
                    raise RefreshError("Approved releases changed during refresh; candidate not installed")
                run.record["phase"] = "validated_install"
                run.save()
                install_workspace(root, workspace, before, run)
                run.record["workspace_installed"] = True
            if not args.skip_push:
                publish_pages(root, run)
            else:
                run.record["publication"] = "local_only"
            run.finish("success")
            print("XGELO_REFRESH status=success run_id="+run.id, flush=True)
            return 0
        except BaseException as error:
            run.finish("failed", error)
            print("XGELO_REFRESH status=failed "+str(error), file=sys.stderr, flush=True)
            return 1


def parse_args(arguments=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scheduled", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--skip-push", action="store_true")
    parser.add_argument("--publish-only", action="store_true")
    parser.add_argument("--restage-only", action="store_true")
    parser.add_argument("--resume-failed", metavar="RUN_ID")
    parser.add_argument("--simulations", type=int, default=int(os.environ.get("XGELO_NL_SIMULATIONS", "10000")))
    parser.add_argument("--workers", type=int, default=int(os.environ.get("XGELO_NL_WORKERS", "4")))
    parser.add_argument("--cl-forecasts", choices=("disabled", "approved"), default="disabled")
    args = parser.parse_args(arguments)
    if args.simulations < 9600 or args.workers < 1:
        parser.error("Production requires >=9,600 simulations and >=1 worker")
    if args.restage_only and (args.publish_only or args.scheduled or args.dry_run):
        parser.error("--restage-only is a manual rendering retry; use --skip-push to defer publication")
    if args.resume_failed and (args.restage_only or args.publish_only or args.scheduled or args.dry_run):
        parser.error("--resume-failed is a manual validated recovery; use --skip-push to defer publication")
    if args.publish_only and (args.skip_push or args.dry_run):
        parser.error("--publish-only cannot be combined with --skip-push or --dry-run")
    return args


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, interrupted)
    try:
        sys.exit(refresh(parse_args()))
    except Exception as error:
        print("XGELO_REFRESH startup_failed: "+str(error), file=sys.stderr)
        sys.exit(1)
