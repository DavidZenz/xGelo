---
phase: 16
slug: euro-qualifying-activation-and-play-off-rules
status: verified
threats_open: 0
asvs_level: 1
created: 2026-08-24
---

# Phase 16 - Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| registered source bundle -> activation validator | Official UEFA artifacts, paths, provenance, IDs, hashes, and timestamps are untrusted until the complete bundle contract passes. | Source metadata, raw/canonical hashes, typed tables |
| candidate revision -> accepted state | A correction must not alter accepted content while validation is incomplete or failed. | Candidate and incumbent state envelopes |
| activation -> forecast consumers | Downstream code receives explicit lifecycle/reason and empty or suppressed collections when prerequisites are absent. | Activation status, source lineage, forecast eligibility |
| rankings/hosts/rules -> allocation and simulation | Eligibility, host capacity, draw conditions, and topology control whether a path is admitted. | Stable IDs, ranking evidence, ruleset and draw-condition hashes |
| candidate outcomes -> accepted output root | Candidate files must pass exact-inventory, schema, lineage, and hash validation before replacement. | Nine-file outcomes bundle |
| process replay -> filesystem evidence | Dry-run and replay are read-only and must agree by complete artifact hashes. | Seed, output bytes, baseline fingerprints |

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-16-00-01 | Repudiation | `16-BASELINE.md` | medium | mitigate | Records command, exit status, combined-output hash, known failure text, and capture date. | closed |
| T-16-00-02 | Tampering | focused synthetic fixtures | medium | mitigate | Uses stable IDs and explicit status, host-cardinality, pre-draw, active, and interim-stage assertions. | closed |
| T-16-01 | Tampering | `phase16_validate_euro_source_bundle()` | high | mitigate | Validates registered provenance, all five resources, stable IDs, completeness, kickoff confirmation, and canonical hashes. | closed |
| T-16-02 | Spoofing | source confidence and accepted-bundle metadata | high | mitigate | Binds activation to the known edition/source contract and rejects unknown identities. | closed |
| T-16-03 | Denial of Service | malformed candidate revision | medium | mitigate | Returns bounded structured unavailable or revision-blocked state and retains the accepted reference. | closed |
| T-16-04 | Information Disclosure | candidate rows in activation payload | high | mitigate | Isolates candidate content and exposes only empty unavailable output or incumbent content with warning. | closed |
| T-16-05 | Repudiation | source/rules revision transition | medium | mitigate | Emits deterministic revision IDs, raw/source/rules hashes, reason codes, and warning metadata. | closed |
| T-16-26 | Tampering | Phase 13 transition and accepted refresh row | critical | mitigate | Requires complete activation validation before `pre_draw -> scheduled` and verifies registry reload. | closed |
| T-16-06 | Tampering | EURO group and overall ranking | high | mitigate | Validates stable IDs, preserves evidence/exclusion IDs, and applies the explicit tie-break order. | closed |
| T-16-07 | Tampering | `allocate_euro_places()` | critical | mitigate | Applies direct, host, runner-up, and play-off capacity in one conservation ledger. | closed |
| T-16-08 | Spoofing | host association/rank rows | high | mitigate | Requires accepted lineage and exposes selected, unused, or unresolved slot status. | closed |
| T-16-09 | Denial of Service | incomplete comparison groups/draw conditions | medium | mitigate | Bounds comparisons to declared groups and returns typed unresolved or unsupported states. | closed |
| T-16-10 | Repudiation | topology and rules revision | medium | mitigate | Carries canonical ruleset, draw-condition, source revisions, and deterministic hashes. | closed |
| T-16-11 | Spoofing | Phase 15 to EURO eligibility handoff | high | mitigate | Requires registered manifest/source identity, stable IDs, interim evidence, and exact interim stage. | closed |
| T-16-12 | Tampering | host-capacity and scenario branch selection | critical | mitigate | Derives branches from the validated ledger, selected hosts, completed results, and versioned draw conditions. | closed |
| T-16-13 | Information Disclosure | probability tables for blocked paths | high | mitigate | Gates simulation on active kickoff state, resolved prerequisites, and complete handoff; otherwise emits no rows. | closed |
| T-16-14 | Repudiation | seeded simulation result | medium | mitigate | Persists seed/count, source/rules/model/cutoff lineage, policy identity, and replay hash. | closed |
| T-16-15 | Denial of Service | malformed handoff/draw-condition input | medium | mitigate | Validates bounded schemas before eligibility and stops with unresolved status on invalid input. | closed |
| T-16-16 | Tampering | `phase16_validate_euro_outcomes_bundle()` | high | mitigate | Validates exact inventory, schemas, IDs, statuses, lineage, hashes, topology, and probability admission. | closed |
| T-16-17 | Tampering | Phase 14 EURO state branch | critical | mitigate | Invokes the Phase 16 activation gate before active state construction and retains Phase 14 validation. | closed |
| T-16-18 | Denial of Service | missing or invalid state input | high | mitigate | Returns bounded invalid or pre-draw state with explicit reason and no partial active emission. | closed |
| T-16-19 | Information Disclosure | blocked candidate/state collections | high | mitigate | Keeps candidate and blocked derived rows isolated and exposes only accepted or typed empty state. | closed |
| T-16-20 | Repudiation | state/outcomes lineage | medium | mitigate | Carries source, rules, model, cutoff, and activation hashes through manifest validation. | closed |
| T-16-21 | Spoofing | plan-owned CLI and wrapper | high | mitigate | Binds the edition to registered source/config, Phase 14 state, Phase 15 handoff, rules, model, and output root. | closed |
| T-16-22 | Tampering | `phase16_write_euro_outcomes_bundle()` | critical | mitigate | Validates exact nine-file inventory, schemas, IDs, statuses, parent/content/self hashes, and revision before replacement. | closed |
| T-16-23 | Information Disclosure | pre-draw or rejected candidate output | high | mitigate | Publishes control metadata only and keeps structural, standings, ledger, and probability rows out of accepted output. | closed |
| T-16-24 | Repudiation | manifest and replay | medium | mitigate | Records seed/count, source/rules/model/cutoff, draw policy, scenario, revisions, and complete artifact hashes. | closed |
| T-16-25 | Denial of Service | CLI inputs and baseline comparison | medium | mitigate | Constrains roots to registered paths, validates bounded CSVs, and fails closed on new or unparseable failures. | closed |
| T-16-SC | Tampering | R and test dependencies | high | mitigate | Introduces no package installation; existing dependencies are reused and asserted by the Wave 0 smoke command. | closed |

## Accepted Risks Log

No accepted risks.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-24 | 29 | 29 | 0 | Codex orchestrator, ASVS L1 artifact audit |

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-24
