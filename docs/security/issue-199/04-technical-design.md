# 04 · Technical design

## Goal

`get_summary` must always return a summary for valid input, and new feedback
must never be able to break it. Normal averages, revocation and the ABI stay as
they are.

## Numbers that drive the design

- `i128::MAX = 170,141,183,460,469,231,731,687,303,715,884,105,727 ≈ 1.7014e38`.
- WAD: a value with `d` decimals is multiplied by `10^(18-d)`.
- `get_summary` adds the WAD values of the counted records of up to 5 clients,
  with no limit on records per client.

## Alternatives

| Option | Effect | Verdict |
|---|---|---|
| A. Read-time skip only, keep the `1e38` write bound | `get_summary` never fails, but garbage keeps being accepted and silently dropped at read time | Rejected as the only measure (the issue's default is a write bound) |
| B. Write bound `\|wad\| ≤ i128::MAX` (reject only single-record overflow) | Stops the `1e30` case, but two records of `1e20` (dec 0) still overflow the sum | Rejected: does not cover the cumulative case |
| C. Saturating arithmetic in `get_summary` | No failure, but the average becomes wrong without any signal | Rejected: hides a wrong result |
| D. Sum in `I256` | No cumulative overflow at read time | Rejected: more host cost and a larger change for a case the write bound already removes |
| **E. Write bound on the WAD value (`\|wad\| ≤ 1e28`) + read-time skip** | New records can neither overflow alone nor, in any reachable number, together; stored records from before the fix are skipped instead of failing the call | **Chosen** |

## Decision

### Write time (`give_feedback`)

- New constant `MAX_ABS_WAD = 10^28`.
- After the existing checks (`value_decimals ≤ 18`, `|value| ≤ 1e38`), compute
  `wad = value.checked_mul(10^(18 - value_decimals))`. Reject with the existing
  `ValueOutOfRange` (8) when the multiplication overflows or `|wad| > 1e28`.
- In whole units that is `|value| / 10^value_decimals ≤ 10^10`: for example
  `value ≤ 10^10` with `value_decimals = 0`, `value ≤ 10^28` with 18.
- Why `1e28` covers the cumulative case (checked against the live network
  limits, `stellar network settings --network testnet`, 2026-11-07):
  - Overflow needs `|sum| > i128::MAX = 2^127 − 1 ≈ 1.7014e38`, i.e. at least
    `17,014,118,347` counted records of `1e28` in one call.
  - Every record `get_summary` reads is a ledger entry
    (`Feedback(agent, client, index)`) that must be in the transaction
    footprint. Testnet: `tx_max_footprint_entries = 400`,
    `tx_max_disk_read_entries = 200`, `tx_max_instructions = 400,000,000`.
  - So one call can count at most `400 − 2 (instance, code) − 5 (LastIndex)
    = 393` records, a worst sum of `393 × 1e28 = 3.93e30`: about `4.3e7` times
    below `i128::MAX`. It would still be safe if the footprint limit grew
    `10^7` times.
  - The bound is symmetric, so the negative side (`i128::MIN = −2^127`) is the
    same. `count` is a `u64` (max `1.8e19`), far above 393.
  - Intermediates: `to_wad` and the running sum are checked; `sum / count`
    divides by a positive `count ≤ 393` (no `i128::MIN / −1`); the final
    `/ 10^(18 − mode)` divides by a positive power of ten.
  - The cumulative case can therefore not be reached by new records; only
    records stored before the fix can trigger the read-time skip.
- No new error code: `ValueOutOfRange` already means "value not accepted",
  which keeps the error ABI identical to Stellar 8004.

### Read time (`get_summary`)

- A record whose WAD value does not fit (`checked_mul` is `None`) is skipped.
- A record whose addition would overflow the running sum (`checked_add` is
  `None`) is skipped; the sum keeps its previous value.
- A skipped record does not count toward `count` nor toward the mode decimals,
  so the average is computed only over the records that were added.
- After the write bound, skips can only come from records stored before the
  fix. The add-overflow skip depends on reading order; it is acceptable because
  it only applies to such legacy records and the alternative is a failed call.
- Other errors are unchanged: an empty client list is still
  `ClientAddressesRequired`, and the `u64` count overflow still returns
  `AggregateOverflow` (unreachable).

### Unchanged

The `1e38` range check, `value_decimals ≤ 18`, revocation, tag filtering, the
5-client limit, the mode-decimals rule, the result shape, storage layout,
events and error codes.

## Compatibility with Stellar 8004

The function signatures, types, events and error codes stay identical. The
deviation is behavioral and stricter:

- `give_feedback` rejects some values Stellar 8004 accepts (`|value| / 10^dec > 1e10`).
- `get_summary` skips records it cannot normalize or add instead of failing.

A client written for Stellar 8004 keeps working for every value in the new
bound. The deviation is recorded in ADR-0002 (Reputation Registry section).
puls3's own scores are 1 to 5 with `value_decimals = 0`, far inside the bound.
