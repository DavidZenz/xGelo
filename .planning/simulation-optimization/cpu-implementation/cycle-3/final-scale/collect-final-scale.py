"""Collect completed scale receipts, with no simulation or promotion."""
import csv
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

if os.environ.get("XGELO_SCALE_JOBS_STOPPED") != "1":
    raise SystemExit("All scale jobs must have exited")
root = Path("/private/tmp/xgelo-active-dashboards")
private = Path("/private/tmp/xgelo-cpu-certification-v3")
checks = Path("/private/tmp/xgelo-cpu-checks")
destination = root / ".planning/simulation-optimization/cpu-implementation/cycle-3/final-scale"
freeze = json.loads((root / ".planning/simulation-optimization/cpu-implementation/frozen-source-v3.json").read_text())
proof = json.loads((checks / "final-checkpoint-proof.json").read_text())
retained = json.loads((checks / "retained-10k-parity.json").read_text())
assert retained["reconstructed_traces_identical"] and retained["statistics_semantically_identical"]
assert not subprocess.check_output(["git", "diff", "--name-only", "16f81f2", "--", "docs", "data", "outputs"], cwd=root)
tracked_r = subprocess.check_output(["git", "ls-files", "R"], cwd=root, text=True).splitlines()
wc_paths = [p for p in tracked_r if any(s in p.lower() for s in ("/wc", "worldcup", "world_cup"))]
assert wc_paths and not subprocess.check_output(["git", "diff", "--name-only", "16f81f2", "--", *wc_paths], cwd=root)
wc_source_hashes = {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in wc_paths}
wc_hash = hashlib.sha256((root / "docs/wc2026/index.html").read_bytes()).hexdigest()
assert wc_hash == "bc540c9d1014095e5d10b2ddc06b73d105c13cd8db7efee6c46bf2d6e86f56b7"
records = {}
for competition in ("cl", "nl"):
    rows = []
    for count in (1000, 10000, 100000):
        resource = json.loads((private / competition / f"resource-{count}.json").read_text())
        measurement = private / competition / (f"measurement-{count}.csv" if competition == "nl" else f"cl-{count}-4.csv")
        measured = list(csv.DictReader(measurement.open()))
        assert resource["status"] == "passed" and resource["count"] == count
        assert resource["source_snapshot_sha256"] == freeze["source_snapshot_sha256"]
        assert resource["implementation_sha256"] == freeze["implementation_sha256"]
        assert resource["measurement_sha256"] == hashlib.sha256(measurement.read_bytes()).hexdigest()
        assert len(measured) == 1 and measured[0]["validated"] == "TRUE"
        assert int(measured[0]["simulations"]) == count
        assert resource["wall_seconds"] < resource["time_limit_seconds"] == 7200
        assert resource["peak_process_tree_rss_bytes"] < resource["memory_limit_bytes"] == resource["physical_memory_bytes"] // 2
        if competition == "cl":
            assert resource["authority"] == "synthetic_fixture_only" and not resource["production_certified"]
        rows.append({"count": count, "resource": resource, "measurement": measured[0]})
    assert proof[competition]["status"] == "passed" and proof[competition]["iterations"] == 100000 and proof[competition]["chunks"] == 391
    assert rows[0]["resource"]["inputs"] == rows[1]["resource"]["inputs"] == rows[2]["resource"]["inputs"]
    records[competition] = rows
for name in ("gate-after-pilots.json", "gate-before-100000.json"):
    assert json.loads((private / "nl" / name).read_text())["status"] == "passed"
destination.mkdir(parents=True, exist_ok=False)
for competition in ("cl", "nl"):
    target = destination / competition
    target.mkdir()
    for path in sorted((private / competition).iterdir()):
        if path.is_file() and path.suffix in (".json", ".csv"):
            shutil.copyfile(path, target / path.name)
for name in ("final-checkpoint-proof.json", "retained-10k-parity.json", "final-checkpoint-proof.R", "compare-retained-chunks.R"):
    shutil.copyfile(checks / name, destination / name)
shutil.copyfile("/private/tmp/xgelo-cpu-staged-v3.py", destination / "staged-driver.py")
shutil.copyfile(__file__, destination / "collect-final-scale.py")
file_hashes = {str(p.relative_to(destination)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(destination.rglob("*")) if p.is_file()}
index = {
    "status": "both_100k_performance_certified",
    "collected_at_utc": datetime.now(timezone.utc).isoformat(),
    "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
    "source_snapshot_sha256": freeze["source_snapshot_sha256"],
    "implementation_sha256": freeze["implementation_sha256"],
    "workers": 4, "chunk_size": 256,
    "run_limits_unchanged": True,
    "required_candidate_validation_included_in_wall_seconds": True,
    "independent_checkpoint_reverification_after_benchmarks": True,
    "manual_progress_poll_interval_minutes": 30,
    "resource_watchdog_interval_seconds": 1,
    "protected_paths_unchanged_against": "16f81f2",
    "wc_publication_sha256": wc_hash,
    "wc_source_file_sha256": wc_source_hashes,
    "cl_production_eligible": False,
    "public_promotion": False,
    "checkpoint_root": str(private),
    "measurements": records,
    "evidence_file_sha256": file_hashes,
}
(destination / "index.json").write_text(json.dumps(index, indent=2) + "\n")
print(json.dumps({"status": index["status"], "destination": str(destination), "measurements": records}, indent=2))
