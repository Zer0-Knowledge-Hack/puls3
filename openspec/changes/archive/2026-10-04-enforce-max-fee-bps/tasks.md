## 1. Add constant and update validation

- [x] 1.1 Add `pub const MAX_FEE_BPS: u32 = 1_000;` in `lib.rs` after `BPS_DENOMINATOR`
- [x] 1.2 Update `BPS_DENOMINATOR` doc comment: change "and the highest accepted `fee_bps`" to just "Basis-point denominator (used in `compute_fee`)"
- [x] 1.3 Update `validate_fee` to check `fee_bps > MAX_FEE_BPS` instead of `fee_bps > BPS_DENOMINATOR`; update the doc comment accordingly

## 2. Update tests

- [x] 2.1 Replace `constructor_accepts_fee_of_exactly_10_000` with `constructor_accepts_fee_at_max_fee_bps` (deploy with `MAX_FEE_BPS`, assert `fee_bps()` returns 1,000)
- [x] 2.2 Update `constructor_rejects_fee_above_10_000` to use `MAX_FEE_BPS + 1` (1,001) as the rejected value; rename to `constructor_rejects_fee_above_max_fee_bps`
- [x] 2.3 Update `fee_setter_validates_bps_and_treasury` to use `MAX_FEE_BPS` (1,000) where it currently uses 10,000 as the accepted upper boundary
- [x] 2.4 Update test harness constant `MAX_FEE` from `10_000` to `MAX_FEE_BPS` (1,000) and fix its doc comment
- [x] 2.5 Update any remaining test that sets `fee_bps` to 10,000 (search for `10_000` in `test.rs`) to use `MAX_FEE_BPS`

## 3. Verify

- [x] 3.1 Run `cargo fmt --all -- --check` in `contracts/`
- [x] 3.2 Run `cargo clippy --all-targets -- -D warnings` in `contracts/`
- [x] 3.3 Run `cargo test` in `contracts/` — all tests pass
- [x] 3.4 Run `stellar contract build` for the escrow contract (WSL if on Windows)
