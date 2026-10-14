# Proposal: Feedback end to end on testnet through the server (#179)

## Intent

On a real database no hire ever reaches `completed`, so `FeedbackService` can never accept feedback; one unreadable agent breaks the whole catalog; and registry feedback is mapped to a fake `hireId`. Make the server path release -> completed -> feedback -> reputation work end to end.

## Scope

### In Scope
- Confirmed `release` => hire `completed`; confirmed `claim_refund` => refund recorded (`HireStatus.expired`, exact value pinned in spec). Derived from confirmed submissions (approach A), no migration.
- 3rd failed relay attempt (`maxEscrowCallAttempts`) => record failed with `EscrowCallFailed`.
- 4a: per-agent isolation in `ReputationCatalogReader.list`.
- 4b: decouple `Feedback.hireId` from registry `feedback_index`.
- F7 testnet script in `puls3_server/tool/`.
- Docs: ADR-0005 D5 (reads stay unfiltered, risk recorded) and D6 (`completed` + `feedbackReference`, not "Rated"); `docs/architecture/api.md`.

### Out of Scope
- Agent-signed `submit` (custodied key) — follow-up / other contributor.
- D5 reader filter — follow-up.
- `submitted`/`rejected` persistence (#97 remainder); status column migration.
- Flutter 0.0 rating preview (frontend).
- Ops (post-merge): deploy with `escrowRelaySigningKey`, testnet runs, record tx hashes.

## Capabilities

### New Capabilities
- `escrow-settlement-tracking`: confirmation effects of server-sent `release`/`claim_refund` and `EscrowCallFailed` exhaustion.

### Modified Capabilities
- `hire-payment`: hire status derives `completed`/`expired` from confirmed release/refund.
- `agent-catalog-endpoint`: per-agent reputation failure isolation; reputation documented as unfiltered.
- `hire-feedback`: registry feedback read no longer carries a fabricated `hireId`.

## Approach

- Tracker keeps marking confirmed; hire repository/`HireLifecycleStore` derives terminal status from confirmed submissions (same precedent as derived `feedbackReference`).
- Sender (or tracker, decided in design) writes `EscrowCallFailed` on the 3rd failed record per hire+purpose.
- 4b crosses the ADR-0001 domain boundary (`puls3_domain/lib/src/feedback.dart`); design picks nullable `hireId` vs a `RegistryFeedback` read model.

## Affected Areas

| Area | Impact |
|------|--------|
| `puls3_server/lib/src/chain/{chain_submission_tracker,escrow_server_submit,submission_values}.dart` | Modified |
| `puls3_server/lib/src/hire/{serverpod_hire_repository,hire_lifecycle_store}.dart` | Modified |
| `puls3_server/lib/src/agent/reputation_catalog_reader.dart`, `ledger/soroban_reputation_registry.dart` | Modified |
| `puls3_domain/lib/src/feedback.dart` + tests | Modified (domain boundary) |
| `puls3_server/tool/` F7 script | New |
| `docs/adr/0005-*.md`, `docs/architecture/api.md` | Modified |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Size ~450-700 lines vs 400 budget under `single-pr` | High | sdd-tasks forecasts; needs `size:exception` or chained slices (max 4) |
| 4a "empty-input values" may contradict spec "never fabricated ratings" | Med | Spec phase resolves per-agent failure semantics |
| Unfiltered reads accept any client's score | Med | Recorded in ADR-0005/api.md; filter follow-up |
| Single in-flight relay gate: stuck release blocks all hires | Med | `EscrowCallFailed` exhaustion bounds it |
| Overlap with @XxHugheadxX on #97 effects | Low | No open PR; scope excludes `submit` |

## Rollback Plan

Revert the PR. No migration or generated-protocol change, so status falls back to null/open/funded derivation; docs revert with it.

## Dependencies

- Testnet registry/escrow ids in `contracts/deployments/testnet.json` (script only).

## Success Criteria

- [ ] Unit tests: confirmed release => `completed`; confirmed claim_refund => refund status; 3rd failure => `EscrowCallFailed`.
- [ ] `FeedbackService` accepts feedback on a real-DB-derived `completed` hire (integration).
- [ ] Catalog lists all agents when one agent's reputation read fails.
- [ ] No registry feedback carries an index as `hireId`.
- [ ] Analyze and tests green in `puls3_domain` and `puls3_server`.
