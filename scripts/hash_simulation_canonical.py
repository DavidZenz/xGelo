#!/usr/bin/env python3
"""Merge private sorted gzip runs into the unchanged football canonical hash.

Only one record per input run is retained. Intermediate runs stay compressed;
the final canonical payload is hashed incrementally and never written to disk.
"""
import argparse
import base64
from contextlib import ExitStack
import gzip
import hashlib
import heapq
import json
from pathlib import Path
import re
import sys
from typing import NamedTuple


MAX_FAN_IN = 32
MAX_LINE_BYTES = 16 * 1024 * 1024
HEX_KEY = re.compile(rb"[0-9a-f]*(?:![0-9a-f]*)*\Z")
SHA256 = re.compile(r"[0-9a-f]{64}\Z")
INITIAL_RUN = re.compile(r"field-[0-9]{4}-run-[0-9]{8}\.gz\Z")


class Run(NamedTuple):
    path: Path
    rows: int
    sha256: str
    validated: bool = False


class HashedIO:
    def __init__(self, raw):
        self.raw = raw
        self.digest = hashlib.sha256()

    def read(self, size=-1):
        data = self.raw.read(size)
        self.digest.update(data)
        return data

    def write(self, data):
        written = self.raw.write(data)
        self.digest.update(data[:written])
        return written

    def flush(self):
        self.raw.flush()


def integer(value, label, minimum=0, maximum=None):
    if isinstance(value, bool) or not isinstance(value, int) or value < minimum or (maximum is not None and value > maximum):
        raise ValueError(f"Invalid {label}")
    return value


def record_parts(line):
    if len(line) > MAX_LINE_BYTES or not line.endswith(b"\n") or line.count(b"\t") != 1:
        raise ValueError("Invalid canonical run record framing or size")
    return line[:-1].split(b"\t")


def decode_record(line, columns, verify_key=True):
    key, encoded = record_parts(line)
    try:
        payload = base64.b64decode(encoded, validate=True)
    except ValueError as error:
        raise ValueError("Invalid canonical base64 payload") from error
    if not verify_key:
        return payload
    if not HEX_KEY.fullmatch(key):
        raise ValueError("Invalid canonical hexadecimal sort key")
    pieces = key.split(b"!") if columns else []
    if len(pieces) != columns or (not columns and key) or any(len(piece) % 2 for piece in pieces):
        raise ValueError("Canonical key column coverage mismatch")
    try:
        expected = b"\x1f".join(bytes.fromhex(piece.decode("ascii")) for piece in pieces)
    except (ValueError, UnicodeError) as error:
        raise ValueError("Invalid canonical base64/hex payload") from error
    if base64.b64encode(payload) != encoded or payload != expected:
        raise ValueError("Canonical key/payload mismatch")
    return payload


def read_run(run, columns, decode_payload=True):
    count = 0
    previous = None
    with run.path.open("rb") as raw:
        hashed = HashedIO(raw)
        with gzip.GzipFile(fileobj=hashed, mode="rb") as source:
            while True:
                line = source.readline(MAX_LINE_BYTES + 1)
                if not line:
                    break
                if run.validated and not decode_payload:
                    record_parts(line)
                    payload = None
                else:
                    payload = decode_record(line, columns, verify_key=not run.validated)
                    if not decode_payload:
                        payload = None
                if previous is not None and line < previous:
                    raise ValueError("Canonical input run is not sorted")
                previous = line
                count += 1
                if count > run.rows:
                    raise ValueError("Canonical run row coverage mismatch")
                yield line, payload
        if count != run.rows:
            raise ValueError("Canonical run row coverage mismatch")
        if hashed.digest.hexdigest() != run.sha256:
            raise ValueError("Canonical compressed run checksum mismatch")


def merge_records(runs, columns, consume, decode_payload=True):
    heap = []
    count = 0
    previous = None
    with ExitStack() as stack:
        for index, run in enumerate(runs):
            iterator = read_run(run, columns, decode_payload=decode_payload)
            stack.callback(iterator.close)
            first = next(iterator, None)
            if first is not None:
                heapq.heappush(heap, (first[0], index, first[1], iterator))
        while heap:
            line, index, payload, iterator = heapq.heappop(heap)
            if previous is not None and line < previous:
                raise ValueError("Canonical merge order mismatch")
            previous = line
            consume(line, payload)
            count += 1
            following = next(iterator, None)
            if following is not None:
                heapq.heappush(heap, (following[0], index, following[1], iterator))
    if count != sum(run.rows for run in runs):
        raise ValueError("Canonical merged row coverage mismatch")
    return count


def owned_path(workspace, name):
    if not isinstance(name, str) or not name or Path(name).name != name:
        raise ValueError("Canonical run is outside its private workspace")
    path = workspace / name
    if path.is_symlink() or path.resolve().parent != workspace:
        raise ValueError("Canonical run is outside its private workspace")
    return path


def hash_manifest(manifest_path, output_path):
    manifest_path = Path(manifest_path).resolve(strict=True)
    workspace = manifest_path.parent
    output_path = Path(output_path)
    if output_path.exists() or output_path.is_symlink() or output_path.resolve().parent != workspace:
        raise ValueError("Canonical output is outside its private workspace")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("schema") != "simulation-canonical-runs-v1":
        raise ValueError("Unknown canonical run manifest")
    fan_in = integer(manifest.get("fan_in"), "canonical merge fan-in", 2, MAX_FAN_IN)
    fields = manifest.get("fields")
    if not isinstance(fields, list):
        raise ValueError("Invalid canonical fields")
    inventory = set()
    names = set()
    prepared = []
    for field in fields:
        name = field.get("field")
        if not isinstance(name, str) or not name or name in names:
            raise ValueError("Invalid or duplicate canonical field")
        names.add(name)
        columns = integer(field.get("columns"), "canonical column count")
        rows = integer(field.get("rows"), "canonical field row count")
        header = base64.b64decode(field.get("header_base64"), validate=True)
        if base64.b64encode(header).decode("ascii") != field["header_base64"]:
            raise ValueError("Invalid canonical header encoding")
        if not isinstance(field.get("runs"), list):
            raise ValueError("Invalid canonical run inventory")
        runs = []
        for entry in field["runs"]:
            run_name = entry.get("path")
            if not isinstance(run_name, str) or not INITIAL_RUN.fullmatch(run_name):
                raise ValueError("Canonical input is not a private generated run")
            path = owned_path(workspace, run_name)
            if path in inventory or not path.is_file():
                raise ValueError("Missing or duplicate canonical run")
            inventory.add(path)
            count = integer(entry.get("rows"), "canonical run row count", 1)
            checksum = entry.get("sha256")
            if not isinstance(checksum, str) or not SHA256.fullmatch(checksum):
                raise ValueError("Invalid canonical run checksum")
            runs.append(Run(path, count, checksum))
        if sum(run.rows for run in runs) != rows:
            raise ValueError("Canonical field row coverage mismatch")
        prepared.append((name, columns, rows, header, runs))
    results = []
    for field_index, (name, columns, rows, header, runs) in enumerate(prepared):
        level = 0
        while len(runs) > fan_in:
            following = []
            for group_index, first in enumerate(range(0, len(runs), fan_in)):
                group = runs[first:first + fan_in]
                if len(group) == 1:
                    following.extend(group)
                    continue
                path = owned_path(workspace, f"merge-{field_index:04d}-{level:04d}-{group_index:08d}.gz")
                if path in inventory:
                    raise ValueError("Canonical intermediate path overlaps an input run")
                inventory.add(path)
                with path.open("xb") as raw:
                    hashed = HashedIO(raw)
                    with gzip.GzipFile(fileobj=hashed, mode="wb", compresslevel=1, mtime=0) as destination:
                        count = merge_records(group, columns, lambda line, payload: destination.write(line), decode_payload=False)
                    hashed.flush()
                    checksum = hashed.digest.hexdigest()
                # This flag is created only here, never from manifest input.
                # Every line was validated before being written verbatim, and
                # later reads still verify its exact compressed SHA/CRC/order/
                # coverage before a success receipt can be emitted.
                following.append(Run(path, count, checksum, validated=True))
                for consumed in group:
                    consumed.path.unlink()
            runs = following
            level += 1
        digest = hashlib.sha256(header)
        def consume(line, payload):
            digest.update(b"\x1e")
            digest.update(payload)
        count = merge_records(runs, columns, consume)
        if count != rows:
            raise ValueError("Canonical final row coverage mismatch")
        for consumed in runs:
            consumed.path.unlink()
        results.append(dict(field=name, rows=count, sha256=digest.hexdigest(), merge_passes=level + bool(runs)))
    result = dict(schema="simulation-canonical-hashes-v1", fan_in=fan_in, fields=results)
    temporary = owned_path(workspace, output_path.name + ".next")
    with temporary.open("x", encoding="utf-8") as destination:
        json.dump(result, destination, separators=(",", ":"))
        destination.write("\n")
    temporary.replace(output_path)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    try:
        hash_manifest(args.manifest, args.output)
    except (OSError, EOFError, ValueError, TypeError, KeyError) as error:
        print(f"Canonical simulation merge failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
