# 05 · Implementation

Branch `fix/199-poisoned-feedback-summary`, from `main` at `dd2a83d`. Only the
Reputation Registry contract, its tests, ADR-0002 and this folder change. No
Flutter, server, domain or other contract code is touched.

## Files

| File | Change |
|---|---|
| `contracts/contracts/reputation-registry/src/lib.rs` | Write bound, read-time skip, `to_wad` helper |
| `contracts/contracts/reputation-registry/src/test.rs` | 10 regression and preservation tests |
| `contracts/contracts/reputation-registry/test_snapshots/test/*.json` | 10 new snapshots, one per new test (the crate commits its test snapshots) |
| `docs/adr/0002-agent-registry-on-soroban.md` | #199 amendment in the Reputation Registry section; `MAX_ABS_WAD` and the `get_summary` doc in the interface listing |
| `docs/security/issue-199/` | This record |

## Changes in `lib.rs`

### 1. `MAX_ABS_WAD` (line 30)

```rust
pub const MAX_ABS_WAD: i128 = 10_000_000_000_000_000_000_000_000_000; // 1e28
```

The largest absolute value a record may have once normalized to 18 decimals.
Why: one record must fit the WAD scale, and the sum of every record one
`get_summary` call can read must fit an `i128` (see
[04-technical-design.md](04-technical-design.md)). Public, like `MAX_ABS_VALUE`,
so tests and integrators can read it.

### 2. `give_feedback` write bound (lines 219–224)

```rust
match to_wad(value, value_decimals) {
    Some(wad) if (-MAX_ABS_WAD..=MAX_ABS_WAD).contains(&wad) => {}
    _ => return Err(ReputationError::ValueOutOfRange),
}
```

Runs after the existing `value_decimals ≤ 18` and `±1e38` checks and before any
cross-contract call or storage write, so a refused value stores nothing and
emits nothing. Both an overflowing multiplication (`None`) and an out-of-bound
WAD value return the existing `ValueOutOfRange` (8): no new error code.

### 3. `get_summary` read-time skip (lines 387–396)

Before:

```rust
let normalized = fb.value.checked_mul(pow10(18 - dec))
    .ok_or(ReputationError::AggregateOverflow)?;
sum_wad = sum_wad.checked_add(normalized)
    .ok_or(ReputationError::AggregateOverflow)?;
```

After:

```rust
let Some(normalized) = to_wad(fb.value, dec) else { continue; };
let Some(next_sum) = sum_wad.checked_add(normalized) else { continue; };
sum_wad = next_sum;
```

A record that cannot be normalized or added is skipped. Because `continue`
happens before `decimal_counts` and `count` are updated, the skipped record
counts nowhere: the average and the mode decimals are computed over the added
records only. Missing, revoked and tag-mismatched records are still skipped
earlier, as before, so a revoked record is never normalized.

### 4. `to_wad` helper (line 777)

```rust
fn to_wad(value: i128, decimals: u32) -> Option<i128> {
    value.checked_mul(pow10(18 - decimals))
}
```

The one place where a value is scaled to 18 decimals, shared by the write and
the read path so both agree on what "fits" means. Callers pass `decimals ≤ 18`
(`give_feedback` checked it; `get_summary` clamps it).

## What did not change

`MAX_ABS_VALUE`, the error enum, events, storage keys, `FeedbackData`,
`SummaryResult`, `MAX_SUMMARY_CLIENTS`, the mode-decimals rule, revocation,
`append_response`, ownership and upgrade code, `CONTRACT_VERSION`.

## Deployment note

The deployed testnet registry runs the old WASM. This change takes effect only
after the timelocked upgrade (`propose_upgrade`, wait `TIMELOCK_LEDGERS`,
`execute_upgrade`) or a redeploy; deploying is outside this issue and was not
done.
