# 08 · Final report

## Original problem

Issue #199, audit finding R-1 (Medium): one feedback with a huge `value` (up to
`1e38` was accepted) made `get_summary` revert for any client list including its
author, because normalizing to 18 decimals overflowed `i128` and the overflow
was returned as `AggregateOverflow`. One transaction fee made an agent's
on-chain summary unreadable.

## Initial state

| Requirement | Before |
|---|---|
| Write validation of normalization overflow | Pending |
| Single-record overflow | Partial (checked, but fatal) |
| Cumulative overflow | Pending |
| Read protection for stored records | Pending |
| Safe omission | Pending |
| Normal averages | Fulfilled |
| Revocation | Fulfilled |
| Stellar 8004 deviation documented | Pending |

Reproduced on the unfixed contract: both the `1e30` case and the cumulative
`2 × 1e20` case returned `AggregateOverflow`
([03](03-vulnerability-reproduction.md)).

## Solution

- **Write:** `give_feedback` rejects, with `ValueOutOfRange`, any value whose
  WAD form does not fit or exceeds `MAX_ABS_WAD = 1e28` (`1e10` whole units).
  This also removes any reachable cumulative overflow.
- **Read:** `get_summary` skips, without counting, a stored record it cannot
  normalize or add, instead of failing.
- **Docs:** ADR-0002 records the stricter bound and the read behavior as a
  behavioral deviation from Stellar 8004 (ABI unchanged).

## Files changed

- `contracts/contracts/reputation-registry/src/lib.rs`
- `contracts/contracts/reputation-registry/src/test.rs`
- `contracts/contracts/reputation-registry/test_snapshots/test/` (10 new files)
- `docs/adr/0002-agent-registry-on-soroban.md`
- `docs/security/issue-199/` (this folder)

## Evidence

- 10 new tests; 6 of them fail on the unfixed contract and pass with the fix
  ([06](06-test-results.md)).
- `cargo fmt --all -- --check`: pass. `cargo clippy --all-targets -- -D warnings`:
  pass, no warning. `cargo test`: 180 passed (reputation-registry 20, escrow 136,
  identity-registry 23, placeholder 1). `stellar contract build`: pass.

## Acceptance criteria of #199

- [x] Regression test: `value = 1e30, decimals = 0` is rejected at `give_feedback`
  (`audit_poc_value_1e30_is_rejected_at_give_feedback`).
- [x] Regression test: a poisoned stored record is skipped by `get_summary`,
  which still returns a result
  (`a_poisoned_stored_record_is_skipped_and_the_summary_still_returns`).
- [x] Regression test: normal values still average correctly
  (`normal_values_with_mixed_decimals_still_average_correctly`, plus the existing
  `summary_averages_excludes_revoked_and_requires_clients`).
- [x] `cargo fmt --all -- --check`, `cargo clippy --all-targets -- -D warnings`,
  `cargo test`, `stellar contract build` all pass.
- [x] Bounds deviation recorded in ADR-0002.

## Result

R-1 is fixed in the contract source: new feedback cannot break `get_summary`,
and stored pre-fix feedback no longer can either.

## Pending

- Deploy: upgrade the testnet registry (timelocked `propose_upgrade` /
  `execute_upgrade`) or redeploy. Not part of this change.
- Out of scope, noted in [07](07-security-review.md): reporting skipped records
  in the summary (would change the shared result shape), and the read budget of
  `get_summary`: a client with more than ~393 records exceeds testnet's
  400-entry footprint and makes the call fail (pre-existing, resource limit, not
  overflow; recommended as a separate issue).
- Team review and merge of the pull request. The contract is **not deployed**:
  the testnet registry keeps the old WASM until the upgrade above.
