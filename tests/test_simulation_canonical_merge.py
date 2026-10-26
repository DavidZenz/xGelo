import base64
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


HELPER = Path(__file__).resolve().parents[1] / "scripts/hash_simulation_canonical.py"
spec = importlib.util.spec_from_file_location("canonical_merge", HELPER)
canonical = importlib.util.module_from_spec(spec)
spec.loader.exec_module(canonical)


def encoded_row(values):
    values = [value.encode("utf-8") for value in values]
    return b"!".join(value.hex().encode("ascii") for value in values) + b"\t" + base64.b64encode(b"\x1f".join(values)) + b"\n"


def write_manifest(root, rows, run_size=3, fan_in=2, columns=None):
    columns = columns if columns is not None else ["a", "z"]
    entries = []
    for index, first in enumerate(range(0, len(rows), run_size), 1):
        path = root / f"field-0001-run-{index:08d}.gz"
        content = b"".join(sorted(encoded_row(row) for row in rows[first:first + run_size]))
        path.write_bytes(gzip.compress(content, compresslevel=1, mtime=0))
        entries.append(dict(path=path.name, rows=len(rows[first:first + run_size]), sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    field = dict(field="table", columns=len(columns), rows=len(rows),
                 header_base64=base64.b64encode("\x1f".join(columns).encode("utf-8")).decode("ascii"), runs=entries)
    manifest = dict(schema="simulation-canonical-runs-v1", fan_in=fan_in, fields=[field])
    path = root / "runs.json"
    path.write_text(json.dumps(manifest), encoding="utf-8")
    return path, manifest


class CanonicalMergeTests(unittest.TestCase):
    def test_multiple_compressed_merge_passes_match_canonical_bytes_and_bound_fan_in(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            choices = ["", "a", "aa", "a\x1fz", "a!", "é", "𝛼", "x\ny", "x\ry", "\t", "\x1e"]
            rows = [(choices[(i * 7) % len(choices)], "unchanged metadata " * 30 + choices[i % len(choices)]) for i in range(97)]
            manifest, _ = write_manifest(root, rows)
            sentinel = root / "unrelated.gz"; sentinel.write_bytes(b"preserve unrelated bytes")
            active = 0; peak = 0
            original = canonical.read_run
            def tracked(run, columns):
                nonlocal active, peak
                active += 1; peak = max(peak, active)
                try:
                    yield from original(run, columns)
                finally:
                    active -= 1
            with mock.patch.object(canonical, "read_run", tracked):
                result = canonical.hash_manifest(manifest, root / "hashes.json")
            ordered = sorted(rows, key=lambda row: tuple(value.encode("utf-8") for value in row))
            payload = b"a\x1fz" + b"".join(b"\x1e" + "\x1f".join(row).encode("utf-8") for row in ordered)
            self.assertEqual(result["fields"][0]["sha256"], hashlib.sha256(payload).hexdigest())
            self.assertEqual(result["fields"][0]["rows"], len(rows))
            self.assertGreater(result["fields"][0]["merge_passes"], 1)
            self.assertLessEqual(peak, 2)
            self.assertEqual(active, 0)
            self.assertEqual(sentinel.read_bytes(), b"preserve unrelated bytes")
            self.assertFalse(list(root.glob("field-*.gz")))
            self.assertFalse(list(root.glob("merge-*.gz")))
            self.assertEqual(set(path.name for path in root.iterdir()), {"runs.json", "hashes.json", "unrelated.gz"})

    def test_empty_fields_and_zero_column_records_keep_original_header_framing(self):
        for rows, columns, payload in [([], ["a", "z"], b"a\x1fz"), ([(), (), ()], [], b"\x1e" * 3)]:
            with self.subTest(rows=rows), tempfile.TemporaryDirectory() as directory:
                root = Path(directory); manifest, _ = write_manifest(root, rows, columns=columns)
                result = canonical.hash_manifest(manifest, root / "hashes.json")
                self.assertEqual(result["fields"][0]["sha256"], hashlib.sha256(payload).hexdigest())
                self.assertEqual(result["fields"][0]["rows"], len(rows))

    def test_invalid_sortedness_decoders_checksums_and_coverage_fail(self):
        records = {
            "unsorted": encoded_row(("z", "x")) + encoded_row(("a", "x")),
            "base64": b"61!78\t***\n" + encoded_row(("b", "x")),
            "hex": b"gg!78\tYQ==\n" + encoded_row(("b", "x")),
            "mismatch": b"61!78\tYh94\n" + encoded_row(("b", "x")),
            "truncated_record": encoded_row(("a", "x")) + encoded_row(("b", "x"))[:-1],
            "missing": encoded_row(("a", "x")),
            "extra": encoded_row(("a", "x")) + encoded_row(("b", "x")) + encoded_row(("c", "x")),
            "columns": encoded_row(("a",)) + encoded_row(("b",)),
        }
        for reason, content in records.items():
            with self.subTest(reason=reason), tempfile.TemporaryDirectory() as directory:
                root = Path(directory); manifest_path, manifest = write_manifest(root, [("a", "x"), ("b", "x")])
                run = root / manifest["fields"][0]["runs"][0]["path"]
                run.write_bytes(gzip.compress(content))
                manifest["fields"][0]["runs"][0]["sha256"] = hashlib.sha256(run.read_bytes()).hexdigest()
                manifest_path.write_text(json.dumps(manifest))
                with self.assertRaises((ValueError, OSError, EOFError)):
                    canonical.hash_manifest(manifest_path, root / "hashes.json")
                self.assertFalse((root / "hashes.json").exists())
                self.assertTrue(run.exists())
        for reason in ("checksum", "gzip"):
            with self.subTest(reason=reason), tempfile.TemporaryDirectory() as directory:
                root = Path(directory); manifest_path, manifest = write_manifest(root, [("a", "x")])
                if reason == "checksum":
                    manifest["fields"][0]["runs"][0]["sha256"] = "0" * 64
                else:
                    run = root / manifest["fields"][0]["runs"][0]["path"]
                    run.write_bytes(run.read_bytes()[:-5])
                    manifest["fields"][0]["runs"][0]["sha256"] = hashlib.sha256(run.read_bytes()).hexdigest()
                manifest_path.write_text(json.dumps(manifest))
                with self.assertRaises((ValueError, OSError, EOFError)):
                    canonical.hash_manifest(manifest_path, root / "hashes.json")

    def test_manifest_inventory_paths_and_limits_fail_without_deleting_unrelated_files(self):
        for reason in ("duplicate", "escape", "missing", "fan_in", "coverage", "schema", "header", "symlink"):
            with self.subTest(reason=reason), tempfile.TemporaryDirectory() as directory:
                root = Path(directory); manifest_path, manifest = write_manifest(root, [("a", "x")])
                field = manifest["fields"][0]
                sentinel = root / "preserve.txt"; sentinel.write_text("keep")
                if reason == "duplicate":
                    field["runs"].append(dict(field["runs"][0])); field["rows"] = 2
                elif reason == "escape": field["runs"][0]["path"] = "../preserve.txt"
                elif reason == "missing": (root / field["runs"][0]["path"]).unlink()
                elif reason == "fan_in": manifest["fan_in"] = canonical.MAX_FAN_IN + 1
                elif reason == "coverage": field["rows"] = 10
                elif reason == "schema": manifest["schema"] = "unknown"
                elif reason == "header": field["header_base64"] = "***"
                elif reason == "symlink":
                    path = root / field["runs"][0]["path"]; path.unlink(); path.symlink_to(sentinel)
                manifest_path.write_text(json.dumps(manifest))
                with self.assertRaises((ValueError, OSError, EOFError)):
                    canonical.hash_manifest(manifest_path, root / "hashes.json")
                self.assertEqual(sentinel.read_text(), "keep")

    def test_cli_returns_success_only_with_a_complete_hash_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); manifest, _ = write_manifest(root, [("é", "x\x1fy")])
            process = subprocess.run([sys.executable, str(HELPER), "--manifest", str(manifest), "--output", str(root / "hashes.json")], capture_output=True, text=True)
            self.assertEqual(process.returncode, 0, process.stderr)
            self.assertEqual(json.loads((root / "hashes.json").read_text())["fields"][0]["rows"], 1)
            # Consumed files cannot be silently reused for another success.
            process = subprocess.run([sys.executable, str(HELPER), "--manifest", str(manifest), "--output", str(root / "other.json")], capture_output=True, text=True)
            self.assertNotEqual(process.returncode, 0)
            self.assertIn("merge failed", process.stderr)
            self.assertFalse((root / "other.json").exists())


if __name__ == "__main__":
    unittest.main()
