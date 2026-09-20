# Phase 18: User Setup Required

**Generated:** 2026-09-20
**Phase:** 18-club-and-ucl-source-contracts
**Status:** Incomplete

The provider-decision contract is installed and safely disabled. Enabling automated UCL acquisition requires access to the football-data.org account and an owner review of the current terms.

## Environment Variables

| Status | Variable | Source | Add to |
|--------|----------|--------|--------|
| [ ] | `FOOTBALL_DATA_API_TOKEN` | football-data.org account for the single registered xGelo UCL dashboard application | Operator environment only; never a committed file |

## Account Setup

- [ ] **Create or confirm the football-data.org application**
  - URL: https://www.football-data.org/
  - Scope: one key registered only to the xGelo UCL dashboard application
  - Skip if: the application and key already exist

## Dashboard and Terms Review

- [ ] **Review the current provider terms and application scope**
  - Location: football-data.org account plus the current terms/about pages
  - Record: reviewer, UTC review time, terms URL and content hash, application scope, rights, normalized-display permission, exact attribution text and placement, raw-cache policy, retention/termination policy, and provider-exit disposition
  - Update: `data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27/provider_terms_review.csv`
  - Requirement: all seven dimensions must be explicitly approved before the live probe can enable automation

## Verification

After the account owner supplies the key and completes the review, the operator runs the bounded acceptance entrypoint. It permits only the four competition-scoped endpoints and stores no credential bytes:

```bash
Rscript --vanilla scripts/accept_ucl_provider.R \
  --provider-id football_data_org_v4 \
  --edition-id ucl_2026_27 \
  --review-path data/competition/provider_acceptance/football_data_org_v4/ucl_2026_27/provider_terms_review.csv \
  --evidence-root data/competition/provider_acceptance
```

Expected result after a successful live probe:

- `acceptance_manifest.csv` independently validates.
- `decision=accepted` and `automation_enabled=TRUE`.
- Exactly four resource calls are evidenced and bound to the reviewed 36-club/144-match expectations.
- No token, authorization header, or request object appears in durable artifacts.

Until then, the correct production state remains `not_run_missing_credential` with automation disabled.

---

**Once all items complete:** Mark status as "Complete" at the top of this file.
