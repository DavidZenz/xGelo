# Phase 13: Source Contracts and Competition Registry - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in 13-CONTEXT.md; this log preserves the alternatives considered.

**Date:** 2026-08-13
**Phase:** 13-Source Contracts and Competition Registry
**Areas discussed:** Snapshot shape and acquisition, Provenance and fallback acceptance, Team and edition identity, Registry lifecycle and release slots

---

## Snapshot shape and acquisition

### Q1: Accepted official source artifacts

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Raw artifact plus parsed tables; accept official structured responses or downloaded pages and retain exact bytes. | |
| 2 | Structured sources only; accept JSON/CSV/API-style UEFA data and reject ordinary HTML pages. | [x] |
| 3 | Page capture first; treat official HTML and embedded data as canonical. | |
| 4 | Any official publication, including PDFs with manual tabular extraction. | |

**User's choice:** 2
**Notes:** The source contract is intentionally structured-only.

### Q2: Bundle granularity

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | One edition snapshot bundle with all required resources, per-artifact hashes, and one normalized output. | [x] |
| 2 | Separate accepted snapshots per resource type. | |
| 3 | One consolidated download only. | |
| 4 | Compose the latest accepted resource of each type even when retrieval times differ. | |

**User's choice:** 1

### Q3: Schema or coverage failure

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Reject the candidate, retain the last accepted bundle, and record the failure. | [x] |
| 2 | Publish a degraded bundle with unavailable fields and a warning. | |
| 3 | Backfill missing tables from the prior bundle and mark them stale. | |
| 4 | Route directly to manual fallback. | |

**User's choice:** 1

### Q4: Raw-byte retention

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Retain bytes in an ignored local raw store; commit manifests, hashes, parser version, and compact outputs. | [x] |
| 2 | Commit raw snapshots in Git. | |
| 3 | Retain hashes only. | |
| 4 | Delete raw bytes after parsing. | |

**User's choice:** 1

---

## Provenance and fallback acceptance

### Q1: Provenance level

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Bundle and artifact level, with URL, retrieval time, byte count, raw SHA-256, parser version, and fallback status. | [x] |
| 2 | Bundle-level metadata only. | |
| 3 | Artifact-level metadata only. | |
| 4 | Bundle plus normalized-table provenance rows. | |

**User's choice:** 1

### Q2: Manual fallback review gate

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Require explicit review before publication; record source, retrieval date, reason, note, checksum, and acceptance state. | [x] |
| 2 | Operator acceptance and note are sufficient. | |
| 3 | Publish emergency fallback automatically and review afterward. | |
| 4 | Never publish fallbacks; use them only for investigation. | |

**User's choice:** 1

### Q3: Fallback scope

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Replace a complete edition-wide coherent bundle. | [x] |
| 2 | Replace individual resources independently. | |
| 3 | Let the operator choose whole-bundle or per-resource scope. | |
| 4 | Record fallback metadata only and never substitute data. | |

**User's choice:** 1

### Q4: Parser identity

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Semantic parser version plus Git commit and input schema fingerprint. | |
| 2 | Git commit only. | [x] |
| 3 | Semantic parser version only. | |
| 4 | Runtime/package fingerprint with optional Git commit. | |

**User's choice:** 2
**Notes:** The implementation should not invent a second parser-version scheme; it should expose the Git commit as the parser identity.

---

## Team and edition identity

### Q1: Canonical team key

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | xGelo-owned stable `team_id`, with FIFA code, UEFA ID, display name, and aliases as attributes. | [x] |
| 2 | FIFA code as primary key. | |
| 3 | UEFA source ID as primary key. | |
| 4 | Normalized display name as primary key. | |

**User's choice:** 1

### Q2: Unmapped team behavior

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Reject the snapshot and require an approved mapping. | |
| 2 | Create a provisional unresolved team ID. | |
| 3 | Use normalized display-name matching and record a warning. | [x] |
| 4 | Drop the affected team or fixture. | |

**User's choice:** 3
**Notes:** This is the deliberately permissive identity path; it must remain visible and auditable.

### Q3: Source display-name changes

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Keep identity stable, retain the current source display name per snapshot, and append reviewed aliases. | [x] |
| 2 | Overwrite the canonical name with the latest UEFA name globally. | |
| 3 | Create a new team identity for each material source-name change. | |
| 4 | Keep only the original display name. | |

**User's choice:** 1

### Q4: Competition-edition IDs

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Explicit xGelo registry IDs, preserving source IDs as metadata. | [x] |
| 2 | UEFA source edition ID as canonical key. | |
| 3 | Short human-readable slugs only. | |
| 4 | IDs derived during parsing from display fields. | |

**User's choice:** 1

---

## Registry lifecycle and release slots

### Q1: Lifecycle transitions

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Strict forward state machine with `blocked` reachable from any state and validated recovery. | [x] |
| 2 | Derive lifecycle directly from source status and dates. | |
| 3 | Let an operator set any lifecycle state. | |
| 4 | Keep lifecycle informal and make only freshness strict. | |

**User's choice:** 1

### Q2: Required registry fields

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Require lifecycle, ruleset, source bundle, model release, and output target even for `pre_draw`. | [x] |
| 2 | Defer model and output fields until activation. | |
| 3 | Defer output target only. | |
| 4 | Resolve model and output dynamically from the latest release. | |

**User's choice:** 1

### Q3: Model release resolution

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Pin an approved model-release ID; changes require a new registry revision and audit entry. | [x] |
| 2 | Resolve the latest approved release automatically. | |
| 3 | Permit an unversioned operator override. | |
| 4 | Keep model release outside the competition registry. | |

**User's choice:** 1

### Q4: Blocked refresh behavior

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Keep the last accepted output active, mark the batch blocked, and expose failure metadata. | [x] |
| 2 | Remove the edition output until recovery. | |
| 3 | Publish a partial update with a warning. | |
| 4 | Automatically switch to an unreviewed fallback. | |

**User's choice:** 1

---

## Claude's Discretion

- Concrete R function boundaries, file layout, schema names, validation mechanics, and test fixture implementation.
- Exact mapping warning and confidence fields, subject to visible auditability and no silent ambiguous mapping.

## Deferred Ideas

- Later phases own competition state, rules, forecasts, simulations, dashboards, and hourly operations as documented in 13-CONTEXT.md.
