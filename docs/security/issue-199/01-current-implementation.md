# 01 · Current implementation (before the fix)

Contract: `contracts/contracts/reputation-registry/src/lib.rs` (crate
`reputation-registry`, `#![no_std]`, Soroban). Tests: `src/test.rs`. Inspected
on `main` at `dd2a83d`.

## What the contract is

An ERC-8004 Reputation Registry aligned with the Stellar 8004 ABI (ADR-0002,
amended by ADR-0005 D5 to drop-in). It stores raw feedback records and offers a
simple on-chain aggregate. The puls3 reputation formula (#11, Bayesian average)
runs off chain and does **not** use `get_summary`: the server reads records one
by one (`get_clients_paginated`, `get_last_index`, `read_feedback`, see #202).
`get_summary` is part of the public ABI that third-party Stellar 8004 tooling
(explorer, SDK) calls.

## Storage

| Key (`DataKey`) | Value | Written by |
|---|---|---|
| `Feedback(agent_id, client, index)` | `FeedbackData { value: i128, value_decimals: u32, is_revoked, tag1, tag2 }` | `give_feedback`, `revoke_feedback` (flag only) |
| `LastIndex(agent_id, client)` | `u64`, last index used by that client | `give_feedback` |
| `ClientCount`, `ClientAtIndex`, `ClientExists` | the list of clients of an agent | `add_client` on a client's first feedback |
| `ResponseCount(agent_id, client, index)` | `u32` | `append_response` |

All persistent entries have their TTL extended on write and on read.

## Flow: from feedback to summary

1. **`give_feedback(caller, agent_id, value, value_decimals, tag1, tag2, endpoint, feedback_uri, feedback_hash)`**
   - `caller.require_auth()`.
   - Rejects `value_decimals > 18` → `InvalidValueDecimals` (3).
   - Rejects `value` outside `±MAX_ABS_VALUE` (`1e38`) → `ValueOutOfRange` (8).
   - Cross-contract: the agent must exist in the Identity Registry
     (`AgentNotFound`, 6) and the caller must not be its owner or approved
     (`SelfFeedback`, 1).
   - Adds the caller to the agent's client list on first feedback, stores the
     record at `last_index + 1`, emits `NewFeedback`.
   - **No check that the value can be normalized**: the only bound is `|value| ≤ 1e38`.
2. **`revoke_feedback(caller, agent_id, index)`**: sets `is_revoked = true` on the
   caller's own record; a second revoke or another caller's record is
   `FeedbackNotFound` (2). The record stays in storage.
3. **`read_feedback`**: returns the stored record as is.
4. **`get_summary(agent_id, client_addresses, tag1, tag2)`**
   - Empty client list → `ClientAddressesRequired` (9).
   - Reads at most `MAX_SUMMARY_CLIENTS = 5` clients, and **every** index
     `1..=last_index` of each.
   - Skips missing, revoked and tag-mismatched records.
   - **Normalization** (lines 365–373): clamps `value_decimals` to 18, then
     `normalized = value.checked_mul(10^(18 - dec))`, mapping an overflow to
     `AggregateOverflow` and **returning it with `?`**.
   - **Aggregation** (lines 374–376): `sum_wad.checked_add(normalized)`, an
     overflow also **returns `AggregateOverflow`**.
   - Counts each record's `dec` to pick the mode decimals (ties → lowest).
   - Result: `count`, `summary_value = (sum_wad / count) / 10^(18 - mode)`,
     `summary_value_decimals = mode`; `count == 0` returns zeros.

## Numeric limits

- `i128::MAX ≈ 1.7014 × 10^38`.
- WAD scale: every value is brought to 18 decimals, so a value with `d`
  decimals is multiplied by `10^(18-d)`. With `d = 0` that is `10^18`.
- Any `|value| > 1.7014 × 10^20` with `d = 0` overflows when normalized, yet
  `give_feedback` accepts up to `10^38`.

## Relevant tests before the fix

`value_decimals_and_range_are_checked` covers `decimals = 19` and
`MAX_ABS_VALUE + 1`; `summary_averages_excludes_revoked_and_requires_clients`
covers a normal average and revocation. No test covers a value that is in range
but overflows when normalized, nor a sum that overflows.

## Dependencies outside the contract

- The puls3 server reads raw records and applies its own rules (#202); it never
  calls `get_summary`, so the server rating was not affected by this bug.
- The app does not call the contract directly for reputation.
- The impact is on `get_summary` callers: Stellar 8004 tooling and any third
  party that reads the on-chain aggregate.
