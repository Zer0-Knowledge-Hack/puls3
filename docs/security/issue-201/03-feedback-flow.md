# 03 · Feedback flow

## Current flow, step by step

| # | Step | Who signs | Contract call | What the server records | Hire reference kept? |
|---|---|---|---|---|---|
| 1 | The consumer requests a hire | — | — | `hire` row: `consumer`, `agentId`, `price`, `manifestVersion`, `expiredAt` (`hire.spy.yaml`) | Hire id (server only) |
| 2 | The server prepares `create_job`; the consumer signs | Consumer (`caller.require_auth()`) | `escrow.create_job(caller, provider = agent wallet, evaluator, expired_at, description, None, agent_id, token, budget)` (`escrow/src/lib.rs:401`) | `jobId` bound once confirmed (unique index `hire_job_id_idx`) | Hire id ↔ job id (server) and job on chain |
| 3 | The consumer funds | Consumer | `escrow.fund(...)` pulls `budget` (`:470`) | `paymentTransaction` | Job on chain, `Funded` |
| 4 | The agent delivers | Agent wallet (provider) | `escrow.submit(...)` (`:516`) | Confirmed `submit` submission | `Submitted` |
| 5 | The consumer approves, or the window closes | Consumer as evaluator, or anyone | `escrow.complete(...)` (`:557`) or `escrow.release(job_id)` (`:576`) | Confirmed `complete` / `release` submission → status `completed` (`hire_settlement.dart:16`) | `Completed` |
| 6 | Eligibility | — | Reads the agent owner (`AgentOwnerReader`) | `FeedbackService.eligibility` (`feedback_service.dart:57`) | Hire id |
| 7 | Prepare the rating | — | Builds `give_feedback` (`reputation_calls.dart:72`) | `EscrowPreparation` with purpose `giveFeedback` (`feedback_service.dart:95`) | **Lost here**: the call carries `agent_id` and `score` only |
| 8 | The consumer signs and the server relays | Consumer (`caller.require_auth()`) | `reputation.give_feedback(caller, agent_id, score, 0, "", "", "", "", 0x00…00)` | `chain_submission` → `hire.feedbackReference` = the transaction hash (`feedback_service.dart:121-136`) | Server only |
| 9 | Rating read | — | `get_clients_paginated`, `get_last_index`, `read_feedback` | `recordsOf` → `countedFeedback` → `reputationOf` | No reference to read |

Server rules applied at steps 6–8 (`feedback_service.dart:141-165`, domain
`feedback.dart:35-56`), in this order:

1. The wallet is the hire's consumer (`_ownedHire`, `:203-209`: `HireNotOwned`).
2. Status is `completed` (`HireNotCompleted`).
3. No live `giveFeedback` submission exists for the hire (`HireAlreadyRated`,
   `_isRated`, `:196-201`).
4. The wallet is not the agent's owner (`FeedbackFromAgentOwner`), read from
   chain and failing closed (`ChainDataUnavailable`).
5. Score 1..5, comment ≤ 500 characters (`InvalidFeedback`).

The rules are re-checked at submit (`:118-120`).

## The bypass path (no app, no server)

| # | Step | Checked by the contract |
|---|---|---|
| 1 | Any funded Stellar account calls `reputation.give_feedback(caller, agent_id, value, …)` directly | `caller.require_auth()`; `value_decimals ≤ 18`; value bound (#199); `agent_exists`; caller is not the owner or an approved operator (`SelfFeedback`) |
| 2 | The record is stored under `(agent_id, caller, index)` | Nothing about hires, payment, completion or uniqueness |
| 3 | The server reads it with `read_feedback` and counts it if `value_decimals == 0` and `1 ≤ value ≤ 5` and not revoked (`feedback_record.dart:70-80`) | — |

Result: the rating puls3 serves moves. This matches the accepted MVP risk in
ADR-0005 D5's implementation note.

## Where the reference must be added

The hire's `jobId` is known to the server at step 7 (`HireRow.jobId`,
`hire_lifecycle_store.dart:64-65`) and is the key of the on-chain job. The
gap is only that step 7 does not put it into the call, and step 9 has no rule
that uses it.

## Proposed flow (summary; details in [09](09-technical-proposal.md))

```
Calificación ──(tag2 + feedback_uri + feedback_hash carry "escrow C… / job N")──▶
Contratación (escrow job N) ──get_job(N)──▶ client == caller, agent_id == agent
                                         ──▶ state == Completed  (funded + settled = pago confirmado)
Reader rule (domain, public): count the record only if all of that holds,
and only the first live record per job.
```
