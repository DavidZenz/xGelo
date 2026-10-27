"""Verify the allowed data migration and unchanged published/runtime bytes."""
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess

root = Path("/private/tmp/xgelo-active-dashboards")
workspace = Path("/private/tmp/xgelo-authority-manifest-repair")
before = json.loads((workspace / "before.json").read_text())
repair = json.loads((workspace / "repair.json").read_text())
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
acceptance = Path("data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27")
changed = [p for p,h in before["protected_before"].items() if sha(root/p) != h]
allowed = {str(acceptance/"current.json"), before["approved_review_path"]}
assert set(changed) == allowed, changed
generation = acceptance / repair["new_generation"]
expected = {"provider_terms_review.csv", "edition_expectations.csv", "coverage_matrix.csv",
            "schema_fingerprint.csv", "acceptance_manifest.csv", "ACCEPTANCE.md"}
assert {p.name for p in (root/generation).iterdir()} == expected
assert sha(root/generation/"provider_terms_review.csv") == before["approved_review_file_sha256"]
assert sha(root/before["approved_review_path"]) == before["historical_pending_file_sha256"]
old = root/Path(before["approved_review_path"]).parent
for filename in ("edition_expectations.csv", "coverage_matrix.csv", "schema_fingerprint.csv"):
    assert (root/generation/filename).read_bytes() == (old/filename).read_bytes(), filename
docs = {str(p.relative_to(root)): sha(p) for p in (root/"docs").rglob("*") if p.is_file()}
expected_docs = {p:h for p,h in before["protected_before"].items() if p.startswith("docs/")}
assert docs == expected_docs
assert not subprocess.check_output(["git", "diff", "--name-only", before["base_commit"], "--", "tests/fixtures"], cwd=root)
spec = importlib.util.spec_from_file_location("scale", root/"scripts/validate_simulation_scale.py")
scale = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scale)
freeze = json.loads((root/".planning/simulation-optimization/cpu-implementation/frozen-source-v3.json").read_text())
assert scale.source_snapshot(root) == freeze["source_snapshot_sha256"]
report = dict(status="passed", base_commit=before["base_commit"],
              changed_original_data_paths=changed,
              added_generation_files={str(generation/n):sha(root/generation/n) for n in sorted(expected)},
              approved_review_bytes_preserved=True, historical_review_bytes_restored_exactly=True,
              historical_machine_edition_schema_bytes_preserved=True,
              published_files_sha256=docs, published_inventory_and_bytes_unchanged=True,
              all_other_original_data_outputs_runtime_source_unchanged=True,
              fixture_inputs_unchanged=True, simulation_source_snapshot_sha256=freeze["source_snapshot_sha256"],
              simulation_source_unchanged=True, public_promotion=False)
(workspace/"scope.json").write_text(json.dumps(report,indent=2)+"\n")
print(json.dumps({k:v for k,v in report.items() if k not in ("published_files_sha256","added_generation_files")},indent=2))
