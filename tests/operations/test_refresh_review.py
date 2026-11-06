"""Independent publication/concurrency review cases; temporary files and mocked services only."""
import datetime as dt
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import competition_refresh as refresh
import install_competition_scheduler as scheduler

ROUTES = {
    "nations-league": "uefa_nations_league_2026_27",
    "euro-qualifying": "uefa_euro_2028_qualifying",
    "champions-league": "ucl_2026_27",
}
SECTIONS = ("overview", "structure", "standings", "fixtures", "results", "form",
            "match_forecasts", "rank_distributions", "qualification_bands", "knockout_paths",
            "progression_probabilities", "projected_outcomes")
SCHEMA = "phase21-dashboard-v2"


def utc(value):
    return value.isoformat().replace("+00:00", "Z")


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, separators=(",", ":")))


def add_nl_forecast_input_evidence(payload, now, source_as_of=None):
    """Independent two-team evidence fixture; it cannot create R production rights."""
    source = now if source_as_of is None else source_as_of
    meta = payload["metadata"]
    parent_fields = ("forecast_input_sha256", "forecast_input_provenance_sha256",
                     "forecast_input_seed_sha256", "forecast_input_results_sha256",
                     "forecast_input_source_bundle_sha256", "forecast_input_policy_sha256")
    parents = {field: str(index + 1) * 64 for index, field in enumerate(parent_fields)}
    parents["forecast_input_source_bundle_sha256"] = meta["source_bundle_sha256"]
    meta.update(parents)
    meta.update(forecast_input_contract="nl-local-elo-v1", forecast_input_status="validated",
                forecast_input_as_of_utc=utc(source), accepted_data_cutoff_utc=utc(source),
                source_as_of_utc=utc(source), last_refresh_at_utc=utc(source),
                generated_at_utc=utc(now), projection_generated_at_utc=utc(now),
                forecast_input_base_cutoff_utc=utc(source-dt.timedelta(days=2)),
                forecast_input_base_latest_evidence_at_utc=utc(source-dt.timedelta(days=3)),
                forecast_input_earliest_team_evidence_at_utc=utc(source-dt.timedelta(hours=1)),
                forecast_input_latest_evidence_at_utc=utc(source-dt.timedelta(hours=1)),
                forecast_input_team_count=2, forecast_input_completed_result_count=1)
    payload["forecast_input_evidence"] = dict(schema_version="nl-local-elo-v1", **parents,
        per_team=[dict(team_id="team_aaa", seed_evidence_at_utc=utc(source-dt.timedelta(days=4)),
                       latest_evidence_at_utc=utc(source-dt.timedelta(hours=1)), consumed_result_count=1),
                  dict(team_id="team_bbb", seed_evidence_at_utc=utc(source-dt.timedelta(days=3)),
                       latest_evidence_at_utc=utc(source-dt.timedelta(hours=1)), consumed_result_count=1)])
    payload["current_standings"] = [dict(team_id="team_aaa"), dict(team_id="team_bbb")]
    payload["sections"]["results"]["rows"] = [dict(fixture_id="independent-result-1", home_team_id="team_aaa",
        away_team_id="team_bbb", counts_for_form=True, match_status="completed",
        evidence_completed_at_utc=utc(source-dt.timedelta(hours=1)))]
    return payload


def seal_review_batch(public, now):
    """Mechanical manifest fixtures, never source/model authority or public artifacts."""
    batch = "independent-operational-review"
    inventory, manifests = [], {}
    for route, edition in ROUTES.items():
        folder = public / route
        payload = json.loads((folder / "payload.json").read_text())
        payload["metadata"]["batch_id"] = batch
        write_json(folder / "payload.json", payload)
        manifest = dict(schema_version=SCHEMA, edition_id=edition,
                        route="/competitions/" + route + "/", batch_id=batch,
                        payload_sha256=refresh.sha(folder / "payload.json"),
                        html_sha256=refresh.sha(folder / "index.html"))
        manifests[edition] = manifest
        write_json(folder / "route-manifest.json", manifest)
        write_json(folder / "current.json", dict(schema_version=SCHEMA, edition_id=edition,
                   route=route, batch_id=batch, status=payload["metadata"]["lifecycle_state"],
                   payload_sha256=manifest["payload_sha256"]))
        inventory += ["docs/competitions/" + route + "/" + name for name in
                      ("index.html", "payload.json", "route-manifest.json", "current.json")]
    inventory += ["docs/competitions/phase21-batch-manifest.json", "docs/competitions/current.json"]
    write_json(public / "phase21-batch-manifest.json", dict(schema_version=SCHEMA,
               batch_id=batch, generated_at_utc=utc(now), routes=list(ROUTES),
               inventory=inventory, route_manifests=manifests))
    write_json(public / "current.json", dict(schema_version=SCHEMA, batch_id=batch,
               status="accepted", manifest_sha256=refresh.sha(public / "phase21-batch-manifest.json"),
               inventory=inventory))


def review_batch(root, now):
    public = root / refresh.PUBLIC
    for route, edition in ROUTES.items():
        folder = public / route
        folder.mkdir(parents=True, exist_ok=True)
        meta = dict(batch_id="independent-operational-review", edition_id=edition,
                    lifecycle_state="pre_draw" if route == "euro-qualifying" else "active",
                    forecast_status="pre_draw" if route == "euro-qualifying" else "unavailable",
                    source_status="accepted", source_as_of_utc=utc(now),
                    last_refresh_at_utc=utc(now), generated_at_utc=utc(now),
                    source_bundle_id="mechanical-test-only", source_bundle_sha256="0" * 64,
                    model_release_id=None, ruleset_version=None, projection_run_id=None,
                    simulation_seed=15017, simulation_count=10000, freshness_status="fresh",
                    showing_last_accepted_snapshot=False)
        sections = {s: dict(id=s, label=s, status="unavailable", reason="Test-only empty section", rows=[])
                    for s in SECTIONS}
        payload = dict(schema_version=SCHEMA, edition_id=edition, metadata=meta, sections=sections, credits={})
        if route == "nations-league":
            add_nl_forecast_input_evidence(payload, now)
        elif route == "champions-league":
            # Facts-only CL must not carry a fictitious tournament sample count.
            meta.update(simulation_seed=None, simulation_count=None)
        write_json(folder / "payload.json", payload)
        (folder / "index.html").write_text("<!doctype html><title>Independent review " + route + "</title>")
    seal_review_batch(public, now)
    return public


class PublicationReviewTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "project"
        self.root.mkdir()
        self.now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
        self.public = review_batch(self.root, self.now)

    def mutate(self, route, callback):
        path = self.public / route / "payload.json"
        payload = json.loads(path.read_text())
        callback(payload)
        write_json(path, payload)
        seal_review_batch(self.public, self.now)

    def test_valid_byte_bound_batch_is_accepted(self):
        self.assertEqual(set(refresh.validate_payloads(self.public, self.now)), set(ROUTES))

    def test_tampered_html_is_rejected_even_when_payload_is_unchanged(self):
        (self.public / "champions-league/index.html").write_text("unreviewed replacement")
        with self.assertRaises(refresh.RefreshError):
            refresh.validate_payloads(self.public, self.now)

    def test_extra_artifact_is_not_eligible_for_publication(self):
        (self.public / "unintended-artifact.json").write_text("{}")
        with self.assertRaises(refresh.RefreshError):
            refresh.validate_payloads(self.public, self.now)

    def test_fractional_simulation_count_is_rejected(self):
        self.mutate("nations-league", lambda p: p["metadata"].update(simulation_count=10000.5))
        with self.assertRaises(refresh.RefreshError):
            refresh.validate_payloads(self.public, self.now)

    def test_source_freshness_matches_the_r_48_hour_gate(self):
        expired = utc(self.now - dt.timedelta(hours=49))
        self.mutate("nations-league", lambda p: p["metadata"].update(last_refresh_at_utc=expired))
        with self.assertRaises(refresh.RefreshError):
            refresh.validate_payloads(self.public, self.now)

    def test_unaccepted_cl_source_is_rejected(self):
        self.mutate("champions-league", lambda p: p["metadata"].update(source_status="unavailable"))
        with self.assertRaises(refresh.RefreshError):
            refresh.validate_payloads(self.public, self.now)

    def test_past_cl_forecasts_are_rejected_even_with_no_upcoming_fixture_rows(self):
        def past(p):
            p["sections"]["match_forecasts"]["rows"] = [{"Kickoff (UTC)":
                utc(self.now - dt.timedelta(seconds=1)), "Home win":"50%", "Draw":"25%", "Away win":"25%"}]
        self.mutate("champions-league", past)
        with self.assertRaises(refresh.RefreshError):
            refresh.validate_payloads(self.public, self.now)

    def test_active_euro_requires_nonempty_official_structure_and_fixtures(self):
        self.mutate("euro-qualifying", lambda p: p["metadata"].update(lifecycle_state="active", forecast_status="available"))
        with self.assertRaises(refresh.RefreshError):
            refresh.validate_payloads(self.public, self.now)

    def test_publish_only_remains_idempotent_after_a_successful_retry(self):
        inventory = {p.relative_to(self.public).as_posix(): refresh.sha(p)
                     for p in self.public.rglob("*") if p.is_file()}
        refresh.atomic_json(self.root / "logs/competition-refresh/last-success.json",
                            dict(completed_at_utc=utc(self.now), public_inventory=inventory))
        self.install_receipt(inventory)
        args = refresh.parse_args(["--publish-only"])
        def published(root, run):
            run.record["publication"] = "unchanged"
        with mock.patch.object(refresh, "discover_rscript", return_value=("/test/Rscript", "test")), \
             mock.patch.object(refresh, "publish_pages", side_effect=published):
            self.assertEqual(refresh.refresh(args, self.root), 0)
            self.assertEqual(refresh.refresh(args, self.root), 0)
        self.assertEqual(refresh.read_json(self.root / "logs/competition-refresh/last-success.json")["public_inventory"], inventory)

    def install_receipt(self, inventory=None):
        inventory = inventory or {p.relative_to(self.public).as_posix(): refresh.sha(p)
                                  for p in self.public.rglob("*") if p.is_file()}
        refresh.atomic_json(self.root / "logs/competition-refresh/validated-install.json",
                            dict(schema_version=refresh.SCHEMA, status="validated", public_inventory=inventory,
                                 run_id="independent-validated-install", installed_at_utc=utc(self.now)))
        return inventory

    def test_installed_batch_can_retry_publication_before_any_successful_push(self):
        inventory = self.install_receipt()
        args = refresh.parse_args(["--publish-only"])
        calls = 0
        def transient_failure(root, run):
            nonlocal calls
            calls += 1
            if calls == 1:
                raise refresh.RefreshError("injected transient publisher failure")
            run.record["publication"] = "pushed"
        with mock.patch.object(refresh, "discover_rscript", return_value=("/test/Rscript", "test")), \
             mock.patch.object(refresh, "publish_pages", side_effect=transient_failure):
            self.assertEqual(refresh.refresh(args, self.root), 1)
            self.assertFalse((self.root / "logs/competition-refresh/last-success.json").exists())
            self.assertEqual(refresh.refresh(args, self.root), 0)
        self.assertEqual(refresh.read_json(self.root / "logs/competition-refresh/last-success.json")["public_inventory"], inventory)

    def test_missing_or_tampered_install_receipt_never_publishes(self):
        inventory = {p.relative_to(self.public).as_posix(): refresh.sha(p)
                     for p in self.public.rglob("*") if p.is_file()}
        refresh.atomic_json(self.root / "logs/competition-refresh/last-success.json",
                            dict(completed_at_utc=utc(self.now), public_inventory=inventory))
        args = refresh.parse_args(["--publish-only"])
        for state in ("missing", "tampered"):
            if state == "tampered":
                altered = dict(inventory)
                altered["champions-league/index.html"] = "0" * 64
                self.install_receipt(altered)
            with self.subTest(state=state), \
                 mock.patch.object(refresh, "discover_rscript", return_value=("/test/Rscript", "test")), \
                 mock.patch.object(refresh, "publish_pages") as publisher:
                self.assertEqual(refresh.refresh(args, self.root), 1)
                publisher.assert_not_called()

    def test_edit_during_candidate_copy_is_not_overwritten(self):
        for relative in refresh.managed_paths(self.root):
            folder = self.root / relative
            folder.mkdir(parents=True, exist_ok=True)
            (folder / "snapshot.txt").write_text("incumbent")
        before = refresh.file_inventory(self.root, refresh.managed_paths(self.root))
        workspace = Path(self.temp.name) / "workspace"
        review_batch(workspace, self.now)
        for relative in refresh.managed_paths(self.root):
            folder = workspace / relative
            folder.mkdir(parents=True, exist_ok=True)
            (folder / "snapshot.txt").write_text("candidate")
        edited = self.root / "data/competition/snapshot.txt"
        real_copytree = shutil.copytree
        changed = False
        def copy_with_late_edit(src, dst, *args, **kwargs):
            nonlocal changed
            result = real_copytree(src, dst, *args, **kwargs)
            if Path(src) == workspace / "data/competition" and not changed:
                edited.write_text("concurrent edit during staging")
                changed = True
            return result
        run = refresh.Run(self.root)
        with mock.patch.object(refresh.shutil, "copytree", side_effect=copy_with_late_edit), \
             mock.patch.object(refresh, "validate_payloads", return_value={}):
            with self.assertRaisesRegex(refresh.RefreshError, "concurrent|changed"):
                refresh.install_workspace(self.root, workspace, before, run)
        self.assertEqual(edited.read_text(), "concurrent edit during staging")

    def test_crash_during_preparation_does_not_restore_over_a_concurrent_edit(self):
        for relative in refresh.managed_paths(self.root):
            folder = self.root / relative
            folder.mkdir(parents=True, exist_ok=True)
            (folder / "snapshot.txt").write_text("incumbent")
        workspace = Path(self.temp.name) / "workspace"
        review_batch(workspace, self.now)
        for relative in refresh.managed_paths(self.root):
            folder = workspace / relative
            folder.mkdir(parents=True, exist_ok=True)
            (folder / "snapshot.txt").write_text("candidate")
        code = """
import os,sys
from pathlib import Path
sys.path.insert(0,sys.argv[1])
import competition_refresh as r
root, workspace = Path(sys.argv[2]), Path(sys.argv[3])
before = r.file_inventory(root,r.managed_paths(root))
copytree = r.shutil.copytree
def crash_during_copy(src,dst,*args,**kwargs):
    result = copytree(src,dst,*args,**kwargs)
    if Path(src) == workspace/'data/competition':
        (root/'data/competition/snapshot.txt').write_text('concurrent edit before crash')
        os._exit(71)
    return result
r.shutil.copytree = crash_during_copy
r.install_workspace(root,workspace,before,r.Run(root))
"""
        child = subprocess.run([sys.executable,"-c",code,str(ROOT/"scripts"),str(self.root),str(workspace)],
                               capture_output=True,text=True,timeout=20)
        self.assertEqual(child.returncode,71,child.stderr)
        refresh.recover_install(self.root,self.root/"logs/competition-refresh/install-journal.json")
        self.assertEqual((self.root/"data/competition/snapshot.txt").read_text(),"concurrent edit before crash")


class SchedulerReviewTests(unittest.TestCase):
    def test_failed_post_bootstrap_check_restores_loaded_service_and_disk_config(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            directory = root / "agents"
            directory.mkdir()
            target = directory / "com.xgelo.competition-dashboards.plist"
            old = b"previous scheduler definition"
            target.write_bytes(old)
            state = {"loaded": old, "new_started": False}
            def launchctl(args, **kwargs):
                if args[0] != "launchctl":
                    raise AssertionError(args)
                action = args[1]
                if action == "print" and state["new_started"]:
                    raise subprocess.CalledProcessError(1, args, stderr="injected verification failure")
                if action == "bootout":
                    state["loaded"] = None
                if action == "bootstrap":
                    if state["loaded"] is not None:
                        return subprocess.CompletedProcess(args, 5, "", "service already loaded")
                    state["loaded"] = target.read_bytes()
                    state["new_started"] = state["loaded"] != old
                return subprocess.CompletedProcess(args, 0, "service configured, no running pid", "")
            with mock.patch.object(scheduler, "ROOT", root), \
                 mock.patch.object(scheduler, "discover_rscript", return_value=("/test/Rscript", "test")), \
                 mock.patch.object(scheduler.subprocess, "run", side_effect=launchctl):
                with self.assertRaises(subprocess.CalledProcessError):
                    scheduler.install(directory=directory)
            self.assertEqual(target.read_bytes(), old)
            self.assertEqual(state["loaded"], old)


if __name__ == "__main__":
    unittest.main()
