# 02 · Requirements analysis (state before the fix)

Specification: issue #199 (audit of 2026-10-25, finding R-1, Medium). Each row
was checked against the code on `main` at `dd2a83d`, not against function
names. Line numbers refer to `contracts/contracts/reputation-registry/src/lib.rs`
before the fix.

| # | Requirement | Initial state | Where | Evidence | What was missing |
|---|---|---|---|---|---|
| 1 | Write: `give_feedback` rejects values whose normalization overflows | **PENDING** | `give_feedback`, lines 208–213 | Only `value_decimals > 18` and `\|value\| > 1e38` are rejected. `1e30` with decimals 0 passes and normalizes to `1e48` | A bound on the normalized (WAD) value |
| 2 | Single-record overflow is controlled | **PARTIAL** | `get_summary`, lines 370–373 | `checked_mul` is used, so there is no panic, but the overflow is turned into `AggregateOverflow` and returned with `?`: the whole call fails | Skip the record instead of failing |
| 3 | Cumulative overflow | **PENDING** | `give_feedback` (no bound), `get_summary` lines 374–376 | Two records of `1e20` (decimals 0) each normalize to `1e38`, which fits; their sum does not. `checked_add` returns `AggregateOverflow` with `?` | A write bound that makes the sum safe, plus a read-time skip for stored records |
| 4 | Read protection for problematic stored records | **PENDING** | `get_summary` | Both `?` above abort the call; any client list containing the author of such a record cannot be summarized | Skip records that cannot be added |
| 5 | Safe omission keeps the other valid records | **PENDING** | `get_summary` | No omission exists: one bad record discards the whole result | Count only the records that were added |
| 6 | Normal averages stay correct | **FULFILLED** | `get_summary`, lines 384–407 | `summary_averages_excludes_revoked_and_requires_clients`: 5 and 3 average to 4 | Keep it; extend tests to mixed decimals |
| 7 | Revocation is respected | **FULFILLED** | `get_summary`, line 356 | Revoked records are skipped before normalization; the existing test checks it | Keep the order: revoked records must not be normalized or counted |
| 8 | Compatibility documented (Stellar 8004 deviation) | **PENDING** | `docs/adr/0002-agent-registry-on-soroban.md` | ADR-0002 documents `MAX_ABS_VALUE = 1e38` as in Stellar 8004 and no stricter bound | An ADR note on the new write bound and read behavior |

## What already worked and is not rewritten

- `value_decimals > 18` rejection and the `±1e38` range check.
- Revocation logic (`revoke_feedback`, skip in `get_summary`).
- Tag filtering, the 5-client limit, the mode-decimals rule, the `count == 0`
  result, the averaging arithmetic.
- `checked_mul` / `checked_add` themselves: they already prevent a panic; the
  bug is what is done with their `None`.

## Out of scope, noted

- `count.checked_add(1)` (`u64`) and the `decimal_counts` array cannot overflow
  in practice and stay as they are.
- `get_summary` used to read every index of each of 5 clients in one call, so
  a client with very many records could exhaust the invocation's read budget.
  That is a separate resource-limit concern, not R-1. It was fixed separately
  by #205 (PR #241, audit R-4): `get_summary` now reads at most
  `MAX_SUMMARY_RECORDS = 50` records per call. This PR keeps that cap.
- The off-chain rating (#202) never used `get_summary` and is unaffected.
