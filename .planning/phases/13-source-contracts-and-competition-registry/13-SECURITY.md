---
phase: 13
slug: source-contracts-and-competition-registry
status: verified
threats_open: 0
asvs_level: 1
created: 2026-08-15
---

# Phase 13 - Security

Per-phase security contract for the source snapshot and competition registry
boundary. The security auditor verified 49 mitigate dispositions. The 12
low-severity package-install risks are documented as accepted risks below.

## Trust Boundaries

| Boundary | Description | Data Crossing |
|---|---|---|
| External UEFA resource to local candidate | Structured responses and URL metadata enter deterministic validators. | JSON payloads, URLs, timestamps, raw bytes |
| Local raw bytes to committed registries | Exact response bodies remain local while hashes and compact metadata enter Git. | SHA-256, byte counts, provenance |
| Source identity to xGelo identity | Untrusted team IDs and names resolve to durable internal IDs. | IDs, display names, aliases, warnings |
| Accepted bundle to edition registry | Bundle identity and lifecycle state control downstream publication. | Edition rows, hashes, release pins, status |

## Threat Register

| Plan | Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|---|---|---|---|---|---|---|---|
| 13-01 | T-13-01 | Tampering | Raw artifact hashing | high | mitigate | Exact-byte SHA-256 and byte-count validation | closed |
| 13-01 | T-13-02 | Repudiation | Provenance rows | medium | mitigate | URL, retrieval, parser SHA, fallback, and self-hash metadata | closed |
| 13-01 | T-13-03 | Spoofing | Team identity fallback | high | mitigate | Source-ID-first resolution and ambiguity rejection | closed |
| 13-01 | T-13-04 | Tampering | Manual fallback path | high | mitigate | Edition-wide reviewed fallback and mixed-provenance rejection | closed |
| 13-01 | T-13-05 | Denial of Service | Candidate schema drift | medium | mitigate | Fail closed and retain the last accepted bundle | closed |
| 13-01 | T-13-SC | Tampering | Package installation | low | accept | No package-manager install tasks; existing R dependencies are reused | closed |
| 13-02 | T-13-02-01 | Tampering | Artifact hashing | high | mitigate | Exact raw and canonical hash validation | closed |
| 13-02 | T-13-02-02 | Repudiation | Status provenance | high | mitigate | Explicit or derived source-artifact lineage and parser metadata | closed |
| 13-02 | T-13-02-03 | Spoofing | Structured-only gate | high | mitigate | JSON validation and HTML/PDF rejection | closed |
| 13-02 | T-13-02-04 | Tampering | Fallback metadata | high | mitigate | Complete review fields and mixed-status rejection | closed |
| 13-02 | T-13-02-SC | Tampering | Package installation | low | accept | No package-manager install tasks; existing R dependencies are reused | closed |
| 13-03 | T-13-10 | Spoofing | Team identity registry | high | mitigate | Visible fallback metadata and ambiguous-alias rejection | closed |
| 13-03 | T-13-11 | Tampering | Identity registry CSV | medium | mitigate | Uniqueness and row-hash validation | closed |
| 13-03 | T-13-12 | Elevation of Privilege | Model release pin | high | mitigate | Trusted-root Phase 12 release preflight | closed |
| 13-03 | T-13-13 | Tampering | Edition lifecycle | high | mitigate | Forward transitions, blocked overlay, and stable row hashes | closed |
| 13-03 | T-13-14 | Information Disclosure | EURO pre-draw registry | medium | mitigate | Explicit pre-draw state and no fabricated structures | closed |
| 13-03 | T-13-SC | Tampering | Package installation | low | accept | No package-manager install tasks; existing R dependencies are reused | closed |
| 13-04 | T-13-04-01 | Spoofing | Fixture identity resolver | high | mitigate | Source-ID-first resolution and unresolved/ambiguous rejection | closed |
| 13-04 | T-13-04-02 | Tampering | Result normalization | high | mitigate | Exact fixture foreign key and recomputed hashes | closed |
| 13-04 | T-13-04-03 | Information Disclosure | Accepted CSV publication | medium | mitigate | Compact tables only; raw bytes remain ignored | closed |
| 13-04 | T-13-04-04 | Denial of Service | EURO pre-draw normalization | medium | mitigate | Exact empty schemas and schema-drift rejection | closed |
| 13-04 | T-13-04-SC | Tampering | Package installation | low | accept | No package-manager install tasks | closed |
| 13-05 | T-13-05-01 | Tampering | Accepted snapshot loader | high | mitigate | Required files, paths, schemas, hashes, and foreign keys | closed |
| 13-05 | T-13-05-02 | Tampering | Manifest links | high | mitigate | Bundle/artifact, parser, fallback, and canonical hash cross-checks | closed |
| 13-05 | T-13-05-03 | Spoofing | Identity loader | high | mitigate | Source-bundle foreign-key validation | closed |
| 13-05 | T-13-05-04 | Denial of Service | Incomplete accepted edition | medium | mitigate | Fail closed on missing or incomplete snapshots | closed |
| 13-05 | T-13-05-SC | Tampering | Package installation | low | accept | No package-manager install tasks; existing R dependencies are reused | closed |
| 13-06 | T-13-06-01 | Tampering | Blocked edition overlay | high | mitigate | Staged registry update, validation, row hash, and atomic publish | closed |
| 13-06 | T-13-06-02 | Tampering | Refresh sidecar/history | high | mitigate | Paired staging, matching batch linkage, and validation | closed |
| 13-06 | T-13-06-03 | Denial of Service | Failed candidate publication | high | mitigate | Backup/rollback handling for every registry-side write | closed |
| 13-06 | T-13-06-04 | Repudiation | Failure audit fields | medium | mitigate | Reason, timestamp, parser, batch, lineage, event, and row hashes | closed |
| 13-06 | T-13-06-05 | Elevation of Privilege | Blocked recovery | high | mitigate | Explicit operator action and validation before recovery | closed |
| 13-06 | T-13-06-SC | Tampering | Package installation | low | accept | No package-manager install tasks; existing R dependencies are reused | closed |
| 13-07 | T-13-07-01 | Tampering | Capture URL/input path | high | mitigate | Bounded HTTPS, five resource classes, and structured validation | closed |
| 13-07 | T-13-07-02 | Repudiation | Source registries | high | mitigate | URL, retrieval, raw/parser hashes, review, and lineage metadata | closed |
| 13-07 | T-13-07-03 | Information Disclosure | Local raw store | medium | mitigate | Ignored raw root and tracked-path assertion | closed |
| 13-07 | T-13-07-04 | Tampering | Reviewed fallback branch | high | mitigate | Complete review metadata and no mixed provenance | closed |
| 13-07 | T-13-07-SC | Tampering | Package installation | low | accept | No package-manager install tasks; existing R dependencies are reused | closed |
| 13-08 | T-13-08-01 | Spoofing | Historical identity resolution | high | mitigate | Source-ID-first aliases and ambiguity rejection | closed |
| 13-08 | T-13-08-02 | Tampering | Historical edition lookup | high | mitigate | Complete unique match coverage and changed-map rejection | closed |
| 13-08 | T-13-08-03 | Information Integrity | Future-row and score invariants | high | mitigate | Append, reorder, future, and score-only regression tests | closed |
| 13-08 | T-13-08-04 | Tampering | Durable history target | high | mitigate | Preprocess, provenance, schema, hash, and targets seam validation | closed |
| 13-08 | T-13-08-SC | Tampering | Package installation | low | accept | No package-manager install tasks | closed |
| 13-09 | T-13-09-01 | Tampering | Accepted directory promotion | high | mitigate | Stage, validate, and atomically promote all six files | closed |
| 13-09 | T-13-09-02 | Denial of Service | Failed candidate publication | high | mitigate | Leave prior accepted output untouched on failure | closed |
| 13-09 | T-13-09-03 | Repudiation | Accepted source manifest | medium | mitigate | Mirror registry provenance and status lineage | closed |
| 13-09 | T-13-09-SC | Tampering | Package installation | low | accept | No package-manager install tasks | closed |
| 13-10 | T-13-10-01 | Tampering | EURO pre-draw files | high | mitigate | Complete headers, links, hashes, and zero-row contract | closed |
| 13-10 | T-13-10-02 | Repudiation | EURO status provenance | medium | mitigate | Explicit or derived source-artifact lineage | closed |
| 13-10 | T-13-10-03 | Denial of Service | Pre-draw schema drift | medium | mitigate | Fail closed rather than manufacture rows | closed |
| 13-10 | T-13-10-SC | Tampering | Package installation | low | accept | No package-manager install tasks | closed |
| 13-11 | T-13-11-01 | Tampering | Canonical hashes | high | mitigate | Recompute staged row and complete CSV-content hashes | closed |
| 13-11 | T-13-11-02 | Tampering | Manifest and bundle hashes | high | mitigate | Exact five-artifact and self-hash agreement | closed |
| 13-11 | T-13-11-03 | Repudiation | Parser/source metadata | medium | mitigate | Preserve URL, retrieval, parser, raw hash, review, and IDs | closed |
| 13-11 | T-13-11-SC | Tampering | Package installation | low | accept | No package-manager install tasks | closed |
| 13-12 | T-13-12-01 | Tampering | Normalized target vector | critical | mitigate | Trusted 14-file vector and complete graph validation | closed |
| 13-12 | T-13-12-02 | Denial of Service | Transaction boundary | high | mitigate | Lock, sibling staging, injected failures, and full restore | closed |
| 13-12 | T-13-12-03 | Tampering | Canonical/manifest hash chain | high | mitigate | Ordered helpers and stale-hash rejection | closed |
| 13-12 | T-13-12-04 | Information Integrity | Normalized fixtures/results | high | mitigate | Stable identity resolver and mutation rejection | closed |
| 13-12 | T-13-12-05 | Tampering | Refresh-batch scope | high | mitigate | Exclude refresh history from transaction targets | closed |
| 13-12 | T-13-12-SC | Tampering | Package installation | low | accept | No package-manager install tasks | closed |

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---|---|---|---|---|
| AR-13-SC-01 | 13-01/T-13-SC | Phase 13 performs no package-manager installation; existing R dependencies are reused. | Phase 13 plan disposition | 2026-08-15 |
| AR-13-SC-02 | 13-02/T-13-02-SC | Phase 13 performs no package-manager installation; existing R dependencies are reused. | Phase 13 plan disposition | 2026-08-15 |
| AR-13-SC-03 | 13-03/T-13-SC | Phase 13 performs no package-manager installation; existing R dependencies are reused. | Phase 13 plan disposition | 2026-08-15 |
| AR-13-SC-04 | 13-04/T-13-04-SC | Phase 13 performs no package-manager installation. | Phase 13 plan disposition | 2026-08-15 |
| AR-13-SC-05 | 13-05/T-13-05-SC | Phase 13 performs no package-manager installation; validation uses existing R dependencies. | Phase 13 plan disposition | 2026-08-15 |
| AR-13-SC-06 | 13-06/T-13-06-SC | Phase 13 performs no package-manager installation; the existing R runtime is used. | Phase 13 plan disposition | 2026-08-15 |
| AR-13-SC-07 | 13-07/T-13-07-SC | Phase 13 performs no package-manager installation; existing R dependencies are reused. | Phase 13 plan disposition | 2026-08-15 |
| AR-13-SC-08 | 13-08/T-13-08-SC | Phase 13 performs no package-manager installation. | Phase 13 plan disposition | 2026-08-15 |
| AR-13-SC-09 | 13-09/T-13-09-SC | Phase 13 performs no package-manager installation. | Phase 13 plan disposition | 2026-08-15 |
| AR-13-SC-10 | 13-10/T-13-10-SC | Phase 13 performs no package-manager installation. | Phase 13 plan disposition | 2026-08-15 |
| AR-13-SC-11 | 13-11/T-13-11-SC | Phase 13 performs no package-manager installation. | Phase 13 plan disposition | 2026-08-15 |
| AR-13-SC-12 | 13-12/T-13-12-SC | Phase 13 performs no package-manager installation. | Phase 13 plan disposition | 2026-08-15 |

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|---|---:|---:|---:|---|
| 2026-08-15 | 61 | 61 | 0 blocking | gsd-security-auditor; orchestrator |

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-15
