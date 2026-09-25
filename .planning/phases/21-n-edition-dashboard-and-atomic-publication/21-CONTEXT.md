---
phase: 21-n-edition-dashboard-and-atomic-publication
source: roadmap-and-repository-research
---

# Phase 21 Context

Phase 21 generalizes the existing Phase 17 static dashboard engine from a hard-coded two-edition publisher to a registry-derived 0/1/N edition publisher. Nations League and EURO routes remain compatible through legacy adapters. The Champions League consumes validated Phase 20 artifacts read-only; it must render unresolved or blocked evidence explicitly and must not repair or infer UCL rules.

Locked boundaries:

- The edition registry is the only source for enabled editions, routes, adapters, credits, and output limits.
- A batch is staged and validated as a whole. Any edition or read-back failure preserves the incumbent public tree byte-for-byte.
- The UCL adapter maps Phase 20 artifacts into dashboard sections; it never computes standings, draws, or probabilities.
- Missing Phase 18/19/draw authority remains a typed blocked or unavailable UCL payload, not fabricated rows.
- Existing Phase 17 entrypoints and tests remain compatibility shims while the new generic publisher is introduced.

Out of scope: scheduled refresh hardening, provider retry/backoff, launchd changes, and production source acceptance (Phase 22 / Phases 18–19).
