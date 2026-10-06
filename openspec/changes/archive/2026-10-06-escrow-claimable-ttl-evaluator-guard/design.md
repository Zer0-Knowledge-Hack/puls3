# Design: Escrow Claimable TTL and Evaluator Guard (issue #95)

## Technical Approach

This change has two small, additive edits in `contracts/contracts/escrow/src/lib.rs`, plus tests, snapshots and a README note. It implements delta spec R1 (guard), R11/R15 (claimable TTL), R12 (code 117) and R13 (allow-list). It adds no storage migration and makes no change to `extend_ttl(job_id)`, `pay_or_defer`, `withdraw` or `claimable`.

## Architecture Decisions

| Decision | Options | Tradeoff | Choice |
|---|---|---|---|
| Claimable TTL entry point | (a) new `extend_claimable_ttl`; (b) widen `extend_ttl(job_id)`; (c) bump in `claimable`/`withdraw` | (b) Soroban cannot enumerate keys, so coverage would be partial and silent, and the existing footprint would change. (c) A view would write, and `withdraw` removes the key anyway. | **(a)** |
| Missing-entry behavior | revert with an error / silent no-op | `persistent().extend_ttl` panics on a missing key. A new error would add ABI for no benefit. The function mirrors `extend_ttl(job_id)`. | **`has` guard, no-op** |
| Auth | permissionless / recipient auth | A TTL bump moves no value, and keepers must be able to call it. Same as `extend_ttl`. | **no auth** |
| Return and event | `()` with no event / event | No state meaning, and it matches `extend_ttl`. | **`()`, no event** |
| Error code | 117 / reuse 105 | Codes are append-only ABI, and a distinct failure needs a distinct code. | **`EvaluatorIsProvider = 117`** |
| Guard position | right after `ClientIsProvider` / after `verify_provider` | Placing it earlier avoids a cross-contract registry call and keeps both self-dealing checks together. With `caller == provider == evaluator`, 105 still wins, so the existing `client_cannot_be_the_provider` test is unchanged. | **after line 428, before `verify_provider`** |

## Data Flow

    keeper ──extend_claimable_ttl(r,t)──> extend_instance
                                     └─ has(Claimable(r,t))? ──yes──> extend_persistent
                                                              └─no──> return

    client ──create_job──> hook, budget, desc, expiry, token allow-list
                        ──> caller==provider? 105
                        ──> evaluator==provider? 117   (new)
                        ──> verify_provider (registry) ──> save_job, JobCreated

## File Changes

| File | Action | Description |
|---|---|---|
| `contracts/contracts/escrow/src/lib.rs` | Modify | Add the error variant, the guard in `create_job`, and the new pub fn placed directly after `extend_ttl` |
| `contracts/contracts/escrow/src/test.rs` | Modify | Add the new tests and the allow-list entry |
| `contracts/contracts/escrow/test_snapshots/test/*.1.json` | Create | Generated only by `cargo test` for the new tests |
| `contracts/README.md` | Modify | Extend the "Escrow deploy" section |

## Interfaces / Contracts

```rust
// EscrowError, appended after NothingToWithdraw = 116:
/// `create_job`: the evaluator is the provider (a provider cannot approve its own work).
EvaluatorIsProvider = 117,

// create_job, immediately after the ClientIsProvider check:
if evaluator == provider {
    return Err(EscrowError::EvaluatorIsProvider);
}

/// Anyone can call it. Keeps the instance and a deferred payout entry alive. It does
/// nothing to the entry when it is absent, and never credits or moves funds.
pub fn extend_claimable_ttl(e: &Env, recipient: Address, token: Address) {
    extend_instance(e);
    let key = DataKey::Claimable(recipient, token);
    if e.storage().persistent().has(&key) {
        extend_persistent(e, &key);
    }
}
```

The function is declared with exactly four leading spaces (`    pub fn `) so the allow-list test, which parses `lib.rs`, detects it.

## Testing Strategy

Strict TDD applies. Each test is written RED first, then the code is changed to make it pass. All tests are host unit tests in `src/test.rs`.

| Test (new unless noted) | Setup / assertion |
|---|---|
| `evaluator_cannot_be_the_provider` | `setup()` creates `try_create_job(client, provider, provider, ...)`. Assert `err(r) == EvaluatorIsProvider`, `job_count() == 0` and `job_events().events().is_empty()`. |
| `evaluator_is_provider_has_code_117` | `assert_eq!(EscrowError::EvaluatorIsProvider as u32, 117)` |
| `evaluator_equal_to_client_is_accepted` | `ctx.create(...)`, then assert `get_job(id).evaluator == client` |
| `third_party_evaluator_is_stored` (existing) | Regression. Keep it green. |
| `client_cannot_be_the_provider` (existing) | Still returns `ClientIsProvider`, which proves the ordering. |
| `extend_claimable_ttl_restores_a_decayed_entry` | `setup_mock(0)`, then `set_blocked(provider, 1)` and complete, which credits `BUDGET`. Run `age_ledger` and assert TTL `< TTL_THRESHOLD`. Call it with `mock_auths(&[])`, then assert TTL `== TTL_BUMP`, instance TTL `== TTL_BUMP` and `claimable == BUDGET`. Check that the escrow, provider and caller token balances are unchanged and that `job_events()` is empty. Then unblock, `withdraw` and get `BUDGET`. |
| `extend_claimable_ttl_for_an_unknown_entry_only_bumps_the_instance` | `age_ledger`, call it with a random `(recipient, token)`, then assert instance `== TTL_BUMP`, `has(key) == false` (read via `as_contract`) and `claimable == 0`. |
| `contract_exports_exactly_the_specified_functions` (existing) | Add `"extend_claimable_ttl"` to `expected`. |

Calling with `mock_auths(&[])` covers the permissionless scenario.

Gates: `cargo fmt --all -- --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test` (from `contracts/`), and `stellar contract build`.

## Snapshot Handling

`cargo test` writes `test_snapshots/test/<name>.1.json` for each new test. Do not edit them by hand. Contracts are registered natively, so existing snapshots should not change. Review the diff, which should only add files. If an existing snapshot changes, treat that as a behavior regression and investigate it rather than accepting it.

## README

Under `### Escrow deploy`, extend the **TTL** paragraph with `extend_claimable_ttl(recipient, token)`, which keeps an unwithdrawn deferred payout alive. Add a short **Errors** line: `create_job` rejects `evaluator == provider` with `EvaluatorIsProvider` (117). Also note that the deployed Testnet instance gets both only after a redeploy (#84).

## Threat Matrix

N/A. This change has no routing, shell, subprocess, VCS/PR automation, executable-file classification or process-integration boundary.

## Migration / Rollout

No migration is required. Existing deployments are unaffected until the redeploy (#84).

## Open Questions

- None blocking. An entry that is already archived needs a restore operation, not this function. That case is out of scope and is not tested.
