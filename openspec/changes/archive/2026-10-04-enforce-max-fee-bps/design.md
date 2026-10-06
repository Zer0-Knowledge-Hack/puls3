## Context

The escrow contract's `validate_fee` function (line 760 of `lib.rs`) currently checks `fee_bps > BPS_DENOMINATOR` (10,000) — allowing up to 100% fee. See proposal.md for motivation.

Current code:

```rust
pub const BPS_DENOMINATOR: u32 = 10_000;

fn validate_fee(fee_bps: u32, has_treasury: bool) -> Result<(), EscrowError> {
    if fee_bps > BPS_DENOMINATOR {
        return Err(EscrowError::InvalidFeeBps);
    }
    // ...
}
```

The `agent-escrow-administration` spec lists this as open item #2.

## Goals / Non-Goals

**Goals:**

- Enforce `fee_bps <= MAX_FEE_BPS` (1,000 bps = 10%) in `validate_fee`, used by both `__constructor` and `set_fee_bps`.
- Update boundary tests to cover `MAX_FEE_BPS` and `MAX_FEE_BPS + 1`.
- Keep `BPS_DENOMINATOR` (10,000) unchanged — it is the mathematical denominator in `compute_fee`, not a ceiling.

**Non-Goals:**

- Making `MAX_FEE_BPS` configurable at runtime (it is a compile-time constant).
- Changing `max_fee_bps` in `fund` (client-side protection, orthogonal).
- Storage migration (no stored data changes).

## Decisions

### D1. Constant value: 1,000 bps (10%)

**Choice**: `pub const MAX_FEE_BPS: u32 = 1_000;`

**Rationale**: The issue proposes 1,000 bps = 10% as the ceiling. At 10%, a 100-token budget still pays the provider 90 tokens. This matches ADR-0005 D7's intent to prevent zero-payout scenarios.

**Alternative considered**: 5,000 bps (50%). Rejected — too permissive; a 50% fee contradicts the "never paid zero" invariant for small budgets when combined with rounding.

### D2. Change `validate_fee`, not the callers

**Choice**: Replace the check in the shared `validate_fee` helper from `fee_bps > BPS_DENOMINATOR` to `fee_bps > MAX_FEE_BPS`.

**Rationale**: Both `__constructor` and `set_fee_bps` already delegate to `validate_fee`. Changing one function covers both entry points. No caller changes needed.

### D3. Test constant `MAX_FEE` → `MAX_FEE_BPS`

**Choice**: Update the test harness constant `MAX_FEE` (currently 10,000) to match `MAX_FEE_BPS` (1,000) and update all tests that use it.

**Rationale**: Tests that pass 10,000 as `max_fee_bps` in `fund` or `fee_bps` in the constructor will fail after the validation change. They must use the new ceiling.

## Risks / Trade-offs

- **[Breaking for admin callers above 1,000 bps]** → No current deployment uses `fee_bps > 0`. Acceptable.
- **[Hardened ceiling not upgradeable]** → If a future use case needs > 10% fee, the contract must be redeployed. Acceptable for MVP; governance can deploy a new version.
