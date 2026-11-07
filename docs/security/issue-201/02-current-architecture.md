# 02 · Current architecture

## Components involved

| Layer | Component | Path | Role in feedback |
|---|---|---|---|
| Contract | Identity Registry | `contracts/contracts/identity-registry` | Agent ids, owner, agent wallet (`agent_exists`, `is_authorized_or_owner`, `get_agent_wallet`) |
| Contract | Escrow (ERC-8183) | `contracts/contracts/escrow/src/lib.rs` | The hire on chain: `create_job`, `fund`, `submit`, `complete`, `release`, `reject`, `claim_refund`, `get_job` |
| Contract | Reputation Registry (ERC-8004 / Stellar 8004 subset) | `contracts/contracts/reputation-registry/src/lib.rs` | `give_feedback`, `revoke_feedback`, `append_response`, `read_feedback`, `get_summary`, `get_clients_paginated`, `get_last_index` |
| Domain | Feedback rules | `puls3_domain/lib/src/feedback.dart` | `checkHireRateable`, `checkFeedbackAllowed`, `SubmitFeedback` |
| Domain | Feedback entity | `puls3_domain/lib/src/entities.dart:313` | `Feedback(hireId, agentId, client, score 1..5, comment ≤ 500)` |
| Domain | Registry read model (#202) | `puls3_domain/lib/src/feedback_record.dart` | `FeedbackRecord`, `FeedbackExclusion`, `exclusionOf`, `countedFeedback` |
| Server | Feedback service and endpoint | `puls3_server/lib/src/feedback/feedback_service.dart`, `feedback_endpoint.dart` | Eligibility, prepare the unsigned `give_feedback`, relay the signed one |
| Server | Call builder | `puls3_server/lib/src/feedback/reputation_calls.dart` | Builds the 9 `give_feedback` arguments |
| Server | Registry reader | `puls3_server/lib/src/ledger/soroban_reputation_registry.dart` | `recordsOf` (raw), `feedbacksOf = countedFeedback(recordsOf)` |
| Server | Hire storage and status | `puls3_server/lib/src/hire/hire.spy.yaml`, `hire_lifecycle_store.dart`, `hire_settlement.dart` | Hire row with `consumer`, `agentId`, `price`, `jobId`; status derived from confirmed submissions |
| Tool | Verifier (#202) | `scripts/verify_reputation.dart` | Recomputes a rating from raw records |
| App | Flutter | `puls3_flutter/lib` | **No rating screen yet** (no call to `prepareFeedback`/`submitFeedback`; tracked by #211) |

## Source of truth for "paid and completed"

| Fact | On chain | In the server |
|---|---|---|
| The hire exists for this client and agent | Escrow `Job { client, provider, agent_id, … }` written by `create_job` (`escrow/src/lib.rs:401`), client authenticated (`caller.require_auth()`) | `hire` row (`consumer`, `agentId`, `jobId`) |
| The client paid | `fund` pulls exactly `budget` into the escrow (`escrow/src/lib.rs:470`) | `paymentTransaction` (the `fund` hash) |
| The job was delivered and accepted | `submit` then `complete` by the evaluator (the client, ADR-0005 D4) or the permissionless `release` after the approval window (`escrow/src/lib.rs:516, 557, 576`) | Status derived from confirmed `complete` / `release` submissions (`hire_settlement.dart:16`) |
| The provider was paid | `settle` (`escrow/src/lib.rs:849`) sets `state = Completed`, pays the provider or credits a claimable balance | Not stored separately |
| Refunded or cancelled | `Rejected` (`reject`) or `Expired` (`claim_refund`), both terminal | Status `rejected` / `expired` |

**The escrow contract is the source of truth.** `Completed` is terminal and is
reachable only from `Submitted`, which is reachable only from `Funded`. So
`get_job(job_id).state == Completed` proves, on chain, that the job was funded
with its full budget and settled to the provider. The server's status is a
derived copy of the same facts (from submissions it relayed).

One gap in the copy: `release` is permissionless. If someone other than the
server's tracker calls it, the server sees no `release` submission and keeps
the hire `submitted` (`hire_settlement.dart:16-30`). The chain says
`Completed`, the server says `submitted`, and the consumer cannot rate through
the app. This is a liveness divergence, not a provenance hole, and it is
out of scope for #201 (noted in [06](06-security-analysis.md)).

## What links a rating to a hire today

| Place | Link |
|---|---|
| Server database | A `chain_submission` with `purpose = giveFeedback` for `hireId`; its transaction is the hire's `feedbackReference` (`feedback_service.dart:25-28`) |
| Contract storage | **None.** `FeedbackData { value, value_decimals, is_revoked, tag1, tag2 }` (`reputation-registry/src/lib.rs:35`) |
| Contract event | **None in practice.** `NewFeedback` carries `feedback_uri` and `feedback_hash`, but the server sends `""` and 32 zero bytes (`reputation_calls.dart:87-88`) |

The only link is in the server's database, so the rating → hire relation cannot
be checked without trusting the backend.
