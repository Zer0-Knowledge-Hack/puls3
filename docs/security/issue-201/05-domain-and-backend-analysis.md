# 05 · Domain and backend analysis

## Domain (`puls3_domain`)

### Rules (`lib/src/feedback.dart`)

| Function | Lines | Rule |
|---|---|---|
| `checkHireRateable` | 35-43 | Fixed order: `status == completed` (`HireNotCompleted`), not `rated` (`HireAlreadyRated`), `matchesHire` (`FeedbackDoesNotMatchHire`) |
| `checkFeedbackAllowed` | 47-56 | The above, then `rejectSelfRating(feedback, owner)` |
| `SubmitFeedback.call` | 70-95 | `matchesHire` = same hire id, agent id and client as consumer; `rated` = `hire.feedbackReference != null`; owner read fails closed (`AgentOwnerUnavailable`) |

These rules are about a hire **puls3 knows**. They take `status` and `rated`
as inputs; the domain does not decide where they come from.

### Entity (`lib/src/entities.dart:313`)

`Feedback { HireId? hireId, AgentId agentId, StellarAddress client, int score
(1..5), String comment (≤ 500) }`. `hireId` is null for a record read from the
registry, "not bound to a puls3 hire (ADR-0005 D5)".

### Registry read model (#202, `lib/src/feedback_record.dart`)

- `FeedbackRecord { agentId, client, index, value, valueDecimals, isRevoked }`
  (`:15-49`). It has **no tags, no URI, no hash, no job**.
- `exclusionOf` (`:70`): only four reasons a record does not count:
  `unreadable`, `revoked`, `notWholeScore`, `outOfScale`.
- `countedFeedback` (`:89`): every record without an exclusion becomes a
  `Feedback` with `hireId: null`.

So **every** well-formed 1..5 record counts, whoever wrote it. There is no
paid-hire rule on the read side. ADR-0005 D5's implementation note records it
as an accepted MVP risk and names the follow-up: "filter reads by clients with
a completed hire".

## Server (`puls3_server`)

### `FeedbackService` (`lib/src/feedback/feedback_service.dart`)

- Feeds the domain rules from the stored hire and the chain (`:141-165`).
- `status` comes from the hire row, derived from confirmed escrow submissions
  (`hire_settlement.dart:16`), not from a live `get_job` read.
- `rated` comes from the server's `chain_submission` table (`_isRated`,
  `:196-201`), not from the registry.
- Consumer check against the stored `consumer` (`_ownedHire`, `:203-209`).
- The owner is read from chain and fails closed (`:187-194`).

The rules are correct for the app path. They cannot constrain a direct
contract call, and they are all applied by the server, which is what #201
says.

### Call builder (`lib/src/feedback/reputation_calls.dart`)

`SorobanReputationCalls.giveFeedback` (`:72-90`) sends:

| Argument | Value | Source |
|---|---|---|
| `caller` | consumer wallet | session |
| `agent_id` | `hire.agentId` | hire |
| `value` | score 1..5 | request |
| `value_decimals` | `0` | constant |
| `tag1`, `tag2`, `endpoint` | `""` | constant |
| `feedback_uri` | `""` | constant |
| `feedback_hash` | 32 zero bytes | constant |

The doc comment (`:44-58`) states it: "The hire is not an argument either: the
registry has no hire field (the paid-hire rule is applied off-chain, ADR-0005
D5)." The `ReputationCalls` interface (`:28-32`) takes `client`, `agent` and
`feedback` only; the job id is not passed to it. `HireRow.jobId` is available
in the service (`hire_lifecycle_store.dart:64-65`).

### Registry reader (`lib/src/ledger/soroban_reputation_registry.dart`)

`recordsOf` reads every client page and every index with `read_feedback`;
`feedbacksOf = countedFeedback(recordsOf)` (`:46-54`). It decodes value,
decimals and revoked; tags are ignored. It does not read `NewFeedback` events.
The server has an event reader (`soroban_registry_event_reader.dart`), but only
for Identity Registry events, and it is designed around the ~7 day RPC window
(`catalog_indexer.dart:46`).

### Verifier tool (#202, `scripts/verify_reputation.dart`)

Recomputes a rating with `countedFeedback` from raw records. It would pick up a
new exclusion rule automatically if the rule lives in `exclusionOf` /
`countedFeedback`, which is why the proposal puts the paid-job rule in the
domain (see [09](09-technical-proposal.md)).

## Frontend (`puls3_flutter`)

The app has **no rating flow today**: no call to `getFeedbackEligibility`,
`prepareFeedback` or `submitFeedback` exists under `puls3_flutter/lib`. The
rating screen is #211 (F7, open). Ratings are produced through the server
endpoint (the e2e tool `puls3_server/tool/e2e_feedback_testnet.dart` exercises
it on testnet). Because the server builds the `give_feedback` arguments, the
app does not need to build `feedback_uri` / `feedback_hash` itself: #201's
change on the write side is server-only, and #211 inherits it.

## Rules present in the domain and absent from the contract

| Rule | Domain/server | Reputation contract | Escrow contract |
|---|---|---|---|
| Rater is the hire's client | Yes (`_ownedHire`, `matchesHire`) | No | Job stores `client` |
| Hire completed (paid and settled) | Yes (status `completed`) | No | `state == Completed` |
| One rating per hire | Yes (`_isRated`, `HireAlreadyRated`) | No | — |
| Rater is not the agent owner | Yes | Yes (`SelfFeedback`) | `client != provider` only |
| Score 1..5, whole | Yes (`Feedback`) | No (any value within the bound) | — |
| Reference to the hire | Server DB only | No | Job id is the key |
