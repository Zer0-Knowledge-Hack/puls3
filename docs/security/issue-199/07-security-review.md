# 07 · Security review

## Abuse cases

| # | Attack | Before | After |
|---|---|---|---|
| 1 | One feedback with `value = 1e30`, decimals 0, to block an agent's summary | Accepted; `get_summary` fails for any list with the attacker | Refused at write time (`ValueOutOfRange`) |
| 2 | Same with a negative value (`-1e30`) | Same as 1 | Refused |
| 3 | Several in-range records whose sum overflows (`1e20` each, decimals 0) | Accepted; the sum overflows and `get_summary` fails | Refused at write time: each exceeds `1e10` whole units |
| 4 | Many records at the new bound to overflow the sum | n/a | Needs `17,014,118,347` records counted in one call; the footprint limit (400 entries on testnet) caps a call at 393, a worst sum of `3.93e30`, ~`4.3e7` times below `i128::MAX`. A test sums 25 records at the bound without overflow |
| 5 | Records stored before the fix (already on chain) | Make `get_summary` fail | Skipped and not counted; the summary of the remaining records is returned |
| 6 | Use decimals to slip a large value past the bound | `value_decimals ≤ 18` and `±1e38` only | The bound is on the normalized value, so every decimals setting maps to the same `1e10` whole-unit limit (tested for 0, 2, 7, 18) |
| 7 | Revoke tricks: revoke a poisoned record, or poison then revoke | Revoked records were already skipped before normalization | Unchanged; a revoked stored `1e30` is never normalized (tested) |

## Overflow review

| Operation | Location | Guard |
|---|---|---|
| `value * 10^(18 - d)` at write | `give_feedback` → `to_wad` | `checked_mul`; `None` is refused |
| WAD bound at write | `give_feedback` | `\|wad\| ≤ 1e28` |
| `value * 10^(18 - d)` at read | `get_summary` → `to_wad` | `checked_mul`; `None` skips the record |
| `sum_wad + normalized` | `get_summary` | `checked_add`; `None` skips the record |
| `count + 1` (`u64`) | `get_summary` | `checked_add` → `AggregateOverflow`, unreachable, left as is (not a hidden error) |
| `decimal_counts[dec] += 1` | `get_summary` | `dec ≤ 18` by clamp; a `u64` counter cannot overflow in practice |
| `sum_wad / count`, `avg_wad / 10^(18 - mode)` | `get_summary` | `count > 0` checked before; divisors are positive |
| `pow10(18 - d)` | `to_wad` | `d ≤ 18` by both callers, so no underflow or out-of-bounds index |

## Correctness of results

- A skipped record is excluded from `count` and from the mode decimals, so the
  average is the exact average of the records that were added (tested with a
  poisoned record next to valid ones: 5 and 3 still give 4).
- No saturation: the summary is never computed from a clipped value.
- Errors unrelated to overflow are not hidden: an empty client list still
  returns `ClientAddressesRequired` (tested).

## Revocation review

Revocation is checked before normalization, as before the fix, and only the
submitter can revoke (existing tests). The write bound does not affect
`revoke_feedback`, so a submitter can still revoke a pre-fix poisoned record;
and even without revocation, `get_summary` now skips it.

## Residual risks

1. **Order dependence for pre-fix data.** When several stored pre-fix records
   overflow the sum together, which one is skipped depends on reading order.
   This only affects records accepted before the fix, and the alternative is a
   failed call.
2. **Silent omission for pre-fix data.** `get_summary` does not report how many
   records it skipped (the `SummaryResult` shape is shared with Stellar 8004 and
   was not extended). Auditors can still read every record with
   `read_feedback` (see `docs/verification/reputation.md`).
3. **Not yet deployed.** The testnet registry runs the old WASM until the
   timelocked upgrade or a redeploy.
4. **Read budget, out of scope (pre-existing).** `get_summary` reads every
   record of up to 5 clients in one call, and each record is a footprint entry.
   With testnet's `tx_max_footprint_entries = 400`, a client with more than
   about 393 records makes any `get_summary` that includes it exceed the
   resource limits and fail, which is a denial of service that costs ~400
   feedback transactions. It is a resource limit, not an arithmetic overflow,
   it existed before this change, and fixing it needs a paginated or bounded
   read (an ABI change). Recommended as a separate issue; not changed here.
5. **Stellar 8004 divergence.** Values above the bound that Stellar 8004
   accepts are refused here. puls3 writes scores 1 to 5; third-party writers
   using larger scales above `1e10` whole units are affected. Recorded in
   ADR-0002.

## Off-chain impact

The puls3 server reads raw records and applies its own rules (#202); it does not
call `get_summary`. Its rating was not affected by R-1 and does not change with
this fix: a value above `1e10` was never a puls3 score (1 to 5).
