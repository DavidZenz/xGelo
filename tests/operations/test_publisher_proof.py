"""Real local Git publication/recovery faults; no provider or external push."""
import datetime as dt
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests/operations"))
sys.path.insert(0, str(ROOT / "scripts"))
from test_refresh_review import review_batch, seal_review_batch

import competition_refresh as refresh


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args], stderr=subprocess.STDOUT, text=True).strip()


class PublisherProofTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.root = self.folder / "operator"
        self.remote = self.folder / "remote.git"
        self.root.mkdir()
        subprocess.run(["git", "init", "--bare", "--quiet", str(self.remote)], check=True)
        git(self.root, "init", "--quiet", "--initial-branch=master")
        git(self.root, "config", "user.email", "publication-fixture@example.invalid")
        git(self.root, "config", "user.name", "Publication Fixture")
        self.now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
        self.public = review_batch(self.root, self.now)
        self.wc = self.root / "docs/wc2026/index.html"
        self.wc.parent.mkdir()
        self.wc.write_text("protected published WC")
        self.code = self.root / "R/unrelated.R"
        self.code.parent.mkdir()
        self.code.write_text("published code\n")
        git(self.root, "add", ".")
        git(self.root, "commit", "--quiet", "-m", "incumbent")
        git(self.root, "remote", "add", "origin", str(self.remote))
        git(self.root, "push", "--quiet", "origin", "master")
        self.original_head = git(self.remote, "rev-parse", "master")
        # Real operator changes must not be staged, reverted or pushed.
        self.wc.write_text("private operator WC edit")
        self.code.write_text("unrelated unfinished code\n")
        (self.root / "private-note.txt").write_text("untracked operator edit")
        (self.public / "nations-league/index.html").write_text("<!doctype html><title>validated candidate</title>")
        seal_review_batch(self.public, self.now)
        self.expected = refresh.validate_public_bytes(self.public)
        self.operator_before = {"wc": self.wc.read_bytes(), "code": self.code.read_bytes(),
                                "head": git(self.root, "rev-parse", "HEAD")}
        self.run = refresh.Run(self.root)
        self.run.record["runtime"] = {"executable": "/test-only/Rscript"}
        self.command = self.run.command

    def no_fixture_authority(self, phase, args, **kwargs):
        if phase == "publication_schema_qa":
            # A mechanical Git test is not a genuine source/model approval.
            # That separate production gate is deliberately mocked here.
            return
        return self.command(phase, args, **kwargs)

    def assert_operator_preserved(self):
        self.assertEqual(self.wc.read_bytes(), self.operator_before["wc"])
        self.assertEqual(self.code.read_bytes(), self.operator_before["code"])
        self.assertEqual(git(self.root, "rev-parse", "HEAD"), self.operator_before["head"])
        self.assertTrue((self.root / "private-note.txt").is_file())
        self.assertEqual(refresh.validate_public_bytes(self.public), self.expected)

    def publish(self, callback=None):
        def verified(run, expected):
            self.assertEqual(expected, self.expected)
            run.record["publication"] = "verified"
        with mock.patch.object(self.run, "command", side_effect=callback or self.no_fixture_authority), \
             mock.patch.object(refresh, "verify_publication", side_effect=verified):
            refresh.publish_pages(self.root, self.run)

    def test_real_push_changes_only_competitions_and_preserves_dirty_operator(self):
        self.publish()
        head = git(self.remote, "rev-parse", "master")
        changed = git(self.remote, "diff", "--name-only", self.original_head, head).splitlines()
        self.assertTrue(changed)
        self.assertTrue(all(p.startswith("docs/competitions/") for p in changed))
        self.assertEqual(git(self.remote, "show", head+":docs/wc2026/index.html"), "protected published WC")
        self.assertEqual(git(self.remote, "show", head+":R/unrelated.R"), "published code")
        refresh.validate_git_commit(self.remote, self.expected, head)
        self.assert_operator_preserved()

    def test_real_remote_rejection_preserves_incumbent_and_all_operator_bytes(self):
        hook = self.remote / "hooks/pre-receive"
        hook.write_text("#!/bin/sh\nexit 71\n")
        hook.chmod(0o755)
        with self.assertRaisesRegex(refresh.RefreshError, "publisher_push failed"):
            self.publish()
        self.assertEqual(git(self.remote, "rev-parse", "master"), self.original_head)
        self.assert_operator_preserved()

    def test_commit_hook_cannot_publish_bytes_outside_the_validated_candidate(self):
        hooks = self.folder / "global-hooks"
        hooks.mkdir()
        hook = hooks / "pre-commit"
        hook.write_text("#!/bin/sh\nprintf 'hook replacement' > docs/competitions/nations-league/index.html\ngit add -- docs/competitions/nations-league/index.html\n")
        hook.chmod(0o755)
        with mock.patch.dict(os.environ, {"GIT_CONFIG_COUNT":"1", "GIT_CONFIG_KEY_0":"core.hooksPath", "GIT_CONFIG_VALUE_0":str(hooks)}):
            with self.assertRaisesRegex(refresh.RefreshError, "commit bytes"):
                self.publish()
        self.assertEqual(git(self.remote, "rev-parse", "master"), self.original_head)
        self.assert_operator_preserved()

    def test_push_uses_the_verified_commit_even_if_head_moves_after_proof(self):
        pushed = []
        def move_head(phase, args, **kwargs):
            if phase == "publisher_push":
                pushed.append(args[-1])
                git(kwargs["cwd"], "checkout", "--detach", "HEAD~1")
            return self.no_fixture_authority(phase, args, **kwargs)
        self.publish(move_head)
        self.assertEqual(pushed, [self.run.record["publication_commit"]+":refs/heads/master"])
        self.assertEqual(git(self.remote, "rev-parse", "master"), self.run.record["publication_commit"])
        self.assert_operator_preserved()


class InterruptedInstallTests(unittest.TestCase):
    def test_actual_process_death_after_each_swap_restores_every_root_and_wc(self):
        for stop_after in (1, 5):
            with self.subTest(stop_after=stop_after), tempfile.TemporaryDirectory() as folder:
                root, workspace = Path(folder)/"operator", Path(folder)/"candidate"
                now = dt.datetime.now(dt.timezone.utc)
                review_batch(root, now)
                review_batch(workspace, now)
                for relative in refresh.managed_paths(root):
                    for base, label in ((root, "incumbent"), (workspace, "candidate")):
                        p=base/relative;p.mkdir(parents=True, exist_ok=True)
                        if relative != refresh.PUBLIC:
                            (p/"snapshot.txt").write_text(label)
                (workspace/refresh.PUBLIC/"nations-league/index.html").write_text("candidate")
                seal_review_batch(workspace/refresh.PUBLIC, now)
                wc=root/"docs/wc2026/index.html";wc.parent.mkdir();wc.write_text("protected WC")
                before=refresh.file_inventory(root, refresh.managed_paths(root))
                code = """
import importlib.util,os,sys
from pathlib import Path
spec=importlib.util.spec_from_file_location('candidate',sys.argv[1]);r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
root,workspace=Path(sys.argv[2]),Path(sys.argv[3]);limit=int(sys.argv[4]);count=0;exchange=r.exchange_directories
def die_after_swap(a,b):
 global count
 exchange(a,b);count+=1
 if count==limit: os._exit(73)
r.exchange_directories=die_after_swap
r.install_workspace(root,workspace,r.file_inventory(root,r.managed_paths(root)),r.Run(root))
"""
                child=subprocess.run([sys.executable,"-c",code,str(ROOT/"scripts/competition_refresh.py"),
                                      str(root),str(workspace),str(stop_after)],capture_output=True,text=True,timeout=20)
                self.assertEqual(child.returncode,73,child.stderr)
                self.assertEqual(refresh.read_json(root/"logs/competition-refresh/install-journal.json")["state"],"installing")
                refresh.recover_install(root, root/"logs/competition-refresh/install-journal.json")
                self.assertEqual(refresh.file_inventory(root,refresh.managed_paths(root)),before)
                self.assertEqual(wc.read_text(),"protected WC")
                refresh.recover_install(root, root/"logs/competition-refresh/install-journal.json")
                self.assertEqual(refresh.file_inventory(root,refresh.managed_paths(root)),before)


if __name__ == "__main__":
    unittest.main()
