## Why

ADR-0005 D7 requires a hard fee ceiling below 10,000 bps so the provider is never paid zero. The escrow merged in #78 protects the client at `fund` time via `max_fee_bps`, but `__constructor` and `set_fee_bps` still accept values up to `BPS_DENOMINATOR` (10,000 bps = 100%), meaning an admin could set a fee that consumes the entire budget. Open item #2 in the `agent-escrow-administration` spec explicitly defers this cap.

## What Changes

- Add a `MAX_FEE_BPS` constant (1,000 bps = 10%) as the hard ceiling for `fee_bps` in the escrow contract.
- Tighten `validate_fee` to reject `fee_bps > MAX_FEE_BPS` instead of `fee_bps > BPS_DENOMINATOR`.
- Replace the `constructor_accepts_fee_of_exactly_10_000` test with boundary tests at and above `MAX_FEE_BPS`.
- Update `fee_setter_validates_bps_and_treasury` and any test that uses 10,000 bps as an accepted fee to use `MAX_FEE_BPS` instead.
- Update the `BPS_DENOMINATOR` doc comment to clarify it is the denominator only, not the fee ceiling.

**Rollback plan**: Revert the commit. No storage migration needed since `MAX_FEE_BPS` is a compile-time constant that constrains input validation only; existing stored `fee_bps` values below the new ceiling remain valid.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `agent-escrow-administration`: Requirements A1 (constructor) and A3 (fee configuration) change from `fee_bps <= 10,000` to `fee_bps <= MAX_FEE_BPS` (1,000 bps = 10%). Resolves open item #2.

## Impact

- **Contracts**: `contracts/contracts/escrow/src/lib.rs` (constant, `validate_fee`), `test.rs` (boundary tests).
- **Affected components**: contracts only. No changes to domain, server, client, or Flutter app.
- **Dependencies**: None. The constant is internal to the escrow contract.
- **Deployment**: Existing testnet deployments use `fee_bps = 0`, so the tighter ceiling has no effect on deployed state. New deployments or `set_fee_bps` calls above 1,000 bps will be rejected.
