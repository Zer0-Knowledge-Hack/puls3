# 04 · Contract analysis

## Reputation Registry (`contracts/contracts/reputation-registry/src/lib.rs`)

### `give_feedback` (line 199)

```rust
pub fn give_feedback(e, caller: Address, agent_id: u32, value: i128,
    value_decimals: u32, tag1: String, tag2: String, endpoint: String,
    feedback_uri: String, feedback_hash: BytesN<32>) -> Result<(), ReputationError>
```

Checks, in order:

| Line | Check | Error |
|---|---|---|
| 211 | `caller.require_auth()` | auth failure |
| 213 | `value_decimals ≤ 18` | `InvalidValueDecimals` (3) |
| 216 | `|value| ≤ 1e38` | `ValueOutOfRange` (8) |
| 221 | WAD value within `±1e28` (#199) | `ValueOutOfRange` (8) |
| 227 | `identity.agent_exists(agent_id)` | `AgentNotFound` (6) |
| 230 | caller is not owner or approved operator (`is_authorized_or_owner`) | `SelfFeedback` (1) |

Nothing else. There is **no** hire, job, payment, completion, time or
uniqueness check. The same caller can rate the same agent any number of times:
each call gets the next `feedback_index` (`:238-239`).

### What is stored and what is only emitted

| Data | Stored (`FeedbackData`, `:35`, key `Feedback(agent_id, caller, index)`) | Emitted (`NewFeedback`, `:113`) | Returned by `read_feedback` (`:332`) |
|---|---|---|---|
| `value`, `value_decimals` | Yes | Yes | Yes |
| `is_revoked` | Yes | — (`FeedbackRevoked` on revoke) | Yes |
| `tag1` | Yes | Yes (topic) | Yes |
| `tag2` | Yes | Yes | Yes |
| `endpoint` | **No** | Yes | No |
| `feedback_uri` | **No** | Yes | No |
| `feedback_hash` | **No** | Yes | No |
| client address, agent id, index | In the key | Yes (topics / data) | Inputs |

Consequences for #201:

- A reference in `feedback_uri` / `feedback_hash` is **on chain** (in the
  transaction's event, part of the ledger history), but it is **not in contract
  state**. `read_feedback` and `get_summary` never see it.
- Reading it later requires the event. Public Stellar RPC keeps about 7 days of
  events and transactions; the repository itself relies on that limit
  (`puls3_server/lib/src/agent/catalog_indexer.dart:46`,
  `registry_event_reader.dart:14`, `docs/spikes/payments-and-wallets.md:57`).
  After that, the event is available only from history archives or an indexer
  that persisted it.
- `tag1` and `tag2` are the **only free-form fields that are stored** and
  returned by `read_feedback`. `get_summary` uses them as equality filters
  when non-empty (`:376-381`); puls3 sends both empty today and never filters.
- No length limit is applied to `tag1`, `tag2`, `endpoint`, `feedback_uri`
  (no `len()` check in `give_feedback`). Storage size is bounded only by
  Soroban's entry and transaction limits.

### Other functions

| Function | Line | Relevance |
|---|---|---|
| `revoke_feedback` | 270 | Only the submitter (`require_auth`, record keyed by caller). Sets `is_revoked`. A revoked record stays stored |
| `append_response` | 299 | Anyone can append; only counts responses. Not relevant to provenance |
| `read_feedback` | 332 | Returns `FeedbackData` (value, decimals, revoked, tags) |
| `get_summary` | 350 | Average of non-revoked records of ≤ 5 clients, tag filters. puls3 does not use it for the served rating |
| `get_clients_paginated`, `get_last_index` | 429, 445 | Enumeration used by the server reader |

### Storage lifetime

Records are persistent entries extended to `TTL_BUMP = 1,036,800` ledgers
(about 60 days) when below `TTL_THRESHOLD` (`:17-19`). An archived entry can be
restored; it is not lost.

## Escrow (`contracts/contracts/escrow/src/lib.rs`)

### Job (line 88)

`Job { client, provider, evaluator, agent_id, token, budget, fee_bps,
expired_at, description, state, submitted_at, approval_deadline, deliverable }`,
key `Job(job_id)`, persistent, ~60 days TTL, `extend_ttl(job_id)` is
permissionless (`:758`).

### Lifecycle and what each state proves

| Function | Line | Guard | Resulting state |
|---|---|---|---|
| `create_job` | 401 | `caller.require_auth()` (caller becomes `client`); `caller != provider` (`ClientIsProvider`, :429); `evaluator != provider` (:432); `provider == identity.get_agent_wallet(agent_id)` (`verify_provider`, :434, :819) | `Open` |
| `fund` | 470 | Client only; pulls exactly `budget` | `Funded` |
| `submit` | 516 | Provider only; state must be `Funded` | `Submitted` |
| `complete` | 557 | Evaluator only; state must be `Submitted` | `Completed` via `settle` |
| `release` | 576 | Anyone; `Submitted` and approval window passed | `Completed` via `settle` |
| `reject` | 589 | Client (`Open`) or evaluator (`Funded`/`Submitted`); full refund | `Rejected` |
| `claim_refund` | 642 | Anyone; `Funded` only, after expiry | `Expired` |
| `get_job` | 694 | Read, no auth | — |

`settle` (`:849`) sets `Completed` and pays the provider (or defers to a
claimable balance). **`Completed` is terminal and reachable only through
`Funded → Submitted`**, so it proves that the client paid the full budget and
that the provider was paid. `Rejected` and `Expired` prove a refund.

### What the escrow does not prove

- That the client is independent from the agent's owner. `create_job` only
  forbids `client == provider` (the agent wallet). An owner can use a second
  wallet as client (see [06](06-security-analysis.md), S11).
- That a job was hired through puls3. Any account can call `create_job`
  directly; it is still a real paid job on the canonical escrow.

## No link between the two contracts

The Reputation Registry knows only the Identity Registry
(`IdentityRegistryClient`, `:226`). It has no escrow address and makes no
escrow call, and the escrow does not call the Reputation Registry. A contract
gate would need a new cross-contract dependency (alternative C in
[09](09-technical-proposal.md)).
