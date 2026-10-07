# Proposal: Escrow Claimable TTL and Evaluator Guard (issue #95)

## Intent

- `DataKey::Claimable(recipient, token)` is bumped only when written. A deferred payout untouched for ~60 days (`TTL_BUMP`) is archived, and nothing permissionless can keep it alive.
- `create_job` accepts `evaluator == provider`, which lets a provider approve its own work. That is self-dealing, the same class of problem `ClientIsProvider` already blocks (ADR-0005 D4).

## Scope

### In Scope
- New permissionless `extend_claimable_ttl(recipient, token)`: bumps instance TTL, then the Claimable entry only if it exists. It never reverts, credits nothing, and emits no event.
- New `EscrowError::EvaluatorIsProvider = 117`, checked right after `ClientIsProvider` and before `verify_provider`.
- Strict TDD tests: a decayed claimable is restored to `TTL_BUMP` and can still be withdrawn with an unchanged balance; a missing claimable bumps only the instance; evaluator==provider is rejected (no job, count unchanged, no event); evaluator==client and third-party evaluators still pass; the exported-functions allowlist is updated.
- Regenerated `test_snapshots` (via `cargo test`, never edited by hand).
- A minimal Escrow section in `contracts/README.md` listing the new function and error.

### Out of Scope
- `refund_client` fallback.
- Redeploying the Testnet instance (#84).
- Changing `extend_ttl(job_id)`.
- Mapping code 117 in Serverpod/Flutter (#77 consumers).

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `agent-escrow-lifecycle`: R11 adds `extend_claimable_ttl` and a scenario; `create_job` validation gains the `EvaluatorIsProvider` guard; the R12 error catalogue gains `EvaluatorIsProvider` (117).

## Approach

Exploration approach 1, as confirmed: add a dedicated, correctly keyed entry point and leave `extend_ttl` unchanged. Soroban cannot enumerate keys, so folding this into `extend_ttl` would only cover part of the cases, silently. The function reuses the existing `extend_instance` and `extend_persistent` helpers behind a `has` guard. The error guard is a single comparison next to the existing self-dealing check. Error codes are append-only, so 117 is the next free code.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `contracts/contracts/escrow/src/lib.rs` | Modified | New fn, new error variant, guard in `create_job` |
| `contracts/contracts/escrow/src/test.rs` | Modified | New tests, allowlist update |
| `contracts/contracts/escrow/test_snapshots/` | New | Snapshots generated for the new tests |
| `contracts/README.md` | Modified | Minimal Escrow section |
| domain, server, client, app | None | No changes |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| The deployed instance lacks the new fn/error until redeploy | High | Tracked in #84 |
| Code 117 collides with another open branch | Low | Confirm it is free before merge |
| Unexpected snapshot churn | Low | Diff only new snapshot files |
| Off-chain consumers do not know code 117 | Med | Follow-up against #77 |
| The base spec lives in the unarchived `agent-escrow-payment` change, not `openspec/specs/` | Med | Write the delta against that change's spec |

## Rollback Plan

Revert the commit. It adds no storage migration or state changes. Already-deployed instances are unaffected until #84 redeploys.

## Dependencies

- None blocking. The redeploy (#84) is a follow-up.

## Success Criteria

- [ ] A claimable TTL can be extended without crediting it, and the entry stays withdrawable (tested).
- [ ] `create_job` with evaluator==provider returns `EvaluatorIsProvider` (tested).
- [ ] `test_snapshots` are updated.
- [ ] `cargo fmt --all -- --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test` and `stellar contract build` pass.
- [ ] `contracts/README.md` lists `extend_claimable_ttl` and `EvaluatorIsProvider`.
