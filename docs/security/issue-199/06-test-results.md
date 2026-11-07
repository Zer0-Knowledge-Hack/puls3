# 06 · Test results

All commands run on 2026-11-07, Windows, from `contracts/` (the Cargo
workspace root). Toolchain: `cargo 1.98.1`, `stellar 28.0.0`, target
`wasm32v1-none`.

## New tests (`src/test.rs`)

| Test | Scenario | Checks |
|---|---|---|
| `audit_poc_value_1e30_is_rejected_at_give_feedback` | The audit PoC, `±1e30` with decimals 0 | `ValueOutOfRange`; nothing stored, no event |
| `wad_bound_accepts_the_limit_and_rejects_one_more_for_every_decimals` | Decimals 0, 2, 7, 18 | The exact limit `±1e28 / 10^(18-d)` is accepted, limit + 1 is refused, both signs; the `±1e38` check still applies |
| `the_audit_cumulative_case_is_rejected_at_write_time` | `1e20` with decimals 0 (fits alone, two overflow the sum) | Refused at write time |
| `many_records_at_the_bound_still_sum_without_overflow` | 5 clients × 5 records of `1e10` (the maximum) | `get_summary` returns count 25, value `1e10`: no overflow at the bound (kept small so the committed snapshot stays reviewable; the bound for 393 records is proven in [04](04-technical-design.md)) |
| `a_poisoned_stored_record_is_skipped_and_the_summary_still_returns` | Honest 5 and 3, plus a stored `1e30` record (pre-fix data) | Summary returns count 2, value 4 |
| `stored_records_whose_sum_overflows_are_skipped_not_fatal` | Honest 5, plus two stored `1e20` records | The second large record is skipped; count 2, value `(5 + 1e20) / 2` |
| `a_summary_of_only_poisoned_records_is_empty_not_an_error` | Only a stored `1e30` record | count 0, value 0, decimals 0, no error |
| `revoked_records_are_skipped_before_normalization` | A revoked stored `1e30` and a revoked normal record | Only the remaining valid record counts |
| `normal_values_with_mixed_decimals_still_average_correctly` | 4.5 (dec 1), 3.5 (dec 1), 3 (dec 0) | Mode decimals 1, value 36 (3.6), count 3 |
| `an_empty_client_list_is_still_an_error` | Empty list | `ClientAddressesRequired` is not hidden |

Stored pre-fix records are written with `env.as_contract` and the contract's
own storage helpers (`add_client`, `set_last_index`, `set_feedback`), because the
fixed `give_feedback` refuses them.

## The tests detect the bug

Run against the unfixed `lib.rs` (from `main`, with only the `MAX_ABS_WAD`
constant added so the tests compile):

```
test test::audit_poc_value_1e30_is_rejected_at_give_feedback ... FAILED
test test::a_summary_of_only_poisoned_records_is_empty_not_an_error ... FAILED
test test::a_poisoned_stored_record_is_skipped_and_the_summary_still_returns ... FAILED
test test::the_audit_cumulative_case_is_rejected_at_write_time ... FAILED
test test::stored_records_whose_sum_overflows_are_skipped_not_fatal ... FAILED
test test::wad_bound_accepts_the_limit_and_rejects_one_more_for_every_decimals ... FAILED
test result: FAILED. 14 passed; 6 failed
```

The 6 security tests fail without the fix; the 4 preservation tests (normal
averages, revocation, empty list, records at the bound) pass with and without
it, as intended. The fix was then restored.

## Acceptance commands (with the fix)

```bash
cd contracts
cargo fmt --all -- --check          # exit 0, no output
cargo clippy --all-targets -- -D warnings
#   Finished `dev` profile [unoptimized + debuginfo] target(s) in 3m 46s  (no warning)
cargo test
#   escrow               136 passed; 0 failed
#   identity-registry     23 passed; 0 failed
#   placeholder            1 passed; 0 failed
#   reputation-registry   20 passed; 0 failed
stellar contract build
#   reputation_registry.wasm  18761 bytes optimized, 20 exported functions
#   Wasm Hash: 51572a6551c575dce403984a1ee25792a1f8ba701df393e96166adae862bf32a
#   ✅ Build Complete (every member)
```

## Problems found and fixed while testing

| Problem | Fix |
|---|---|
| The test helper's return type used `soroban_sdk::Error` for the inner result; the generated client returns `ConversionError` | Type alias `GiveResult` with `ConversionError` |
| `cargo test` on the whole workspace rewrote 166 existing snapshot files under escrow, identity, placeholder and reputation | The rewrite was line endings only (`git diff --ignore-cr-at-eol` is empty); those files were restored with `git checkout` so the change carries no unrelated diff |
| The two temporary reproduction tests left snapshot files | Removed with the tests |

## Not covered by tests

- A real deployment: the fix was not deployed to testnet (see
  [05-implementation.md](05-implementation.md)).
- The per-invocation read budget of a `get_summary` over many records is a
  network limit; it is reasoned about in the design, not measured here.
