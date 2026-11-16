# 11 · Implementation

Alternative B of [09](09-technical-proposal.md), with the product decision on
existing ratings: **ratings without a verifiable paid job no longer count**
(strict exclusion, decided 2026-11-07). No contract, ABI, event or error code
changed. Nothing was deployed.

## Write side (server)

| File | Change |
|---|---|
| `puls3_server/lib/src/feedback/reputation_calls.dart` | `ReputationCalls.giveFeedback` takes the hire's `jobId`. `SorobanReputationCalls` takes the escrow and sends `tag2 = feedback_uri = "puls3:job:v1:<escrow>:<job id>"` and `feedback_hash = SHA-256(feedbackCommitment)`; `tag1` and `endpoint` stay empty |
| `puls3_server/lib/src/feedback/feedback_service.dart` | `prepare` passes `hire.jobId`. A hire without a job (never the case once `completed`) is `HireNotCompleted` |
| `puls3_server/lib/src/feedback/reputation_wiring.dart` | Calls and reader get `config.escrow` (`PULS3_STELLAR_ESCROW`) |

The app (Flutter) needs no change: the server builds the call, and the rating
screen (#211) inherits it.

## Read side (domain + server)

| File | Change |
|---|---|
| `puls3_domain/lib/src/feedback_provenance.dart` (new) | `PaidJobReference` (strict parser, versioned), `ReferencedJob`, `FeedbackProvenance` (trusted escrow + jobs read), `feedbackCommitment` |
| `puls3_domain/lib/src/feedback_record.dart` | `FeedbackRecord.tag2` and `jobReference`. Six new public exclusions: `noJobReference`, `otherEscrow`, `jobUnreadable`, `jobMismatch`, `jobNotCompleted`, `jobAlreadyRated`. `exclusionOf(record, provenance)`, `exclusionsOf(records, provenance)` (one rating per job, first wins, a revoked rating frees its job), `referencedJobIds`, `countedFeedback(records, provenance)` |
| `puls3_server/lib/src/ledger/soroban_reputation_registry.dart` | Decodes `tag2`; `readRecords` also returns the provenance: one `get_job` on the configured escrow per referenced job (only for records that pass the score rules). `feedbacksOf = countedFeedback(records, provenance)`. A job the escrow does not have is `jobUnreadable`; any other read failure throws |
| `scripts/verify_reputation.dart` | Prints the escrow, each record's job and state, and the new reasons |

## Rule, as implemented

A record counts only if, in this order: it is readable, not revoked, a whole
score 1..5; `tag2` parses as a reference; the reference names the configured
escrow; `get_job` returns the job; `job.client` is the record's client and
`job.agent_id` the rated agent; the job is `Completed`; and no earlier record
already counts for that job.

## Tests added or changed

| Side | File | What |
|---|---|---|
| Domain | `puls3_domain/test/feedback_provenance_test.dart` (new) | Reference text and strict parsing, bounds, commitment text and binding |
| Domain | `puls3_domain/test/feedback_record_test.dart` | Score rules kept; each job rule; every job state; one per job; revoke frees the job; excluded records take no job; `referencedJobIds`; nothing dropped without a public reason; direct-to-contract rating not counted |
| Server | `test/feedback/soroban_reputation_calls_test.dart` | Exact 9 arguments with a golden SHA-256 computed outside the code; job, score and client change the call; comment does not |
| Server | `test/feedback/feedback_service_test.dart` | `prepare` passes the hire's job id |
| Server | `test/feedback/reputation_wiring_test.dart` | Calls and reader use the configured escrow |
| Server | `test/unit/ledger/soroban_reputation_registry_test.dart` + `test/support/fake_reputation_chain.dart` | The fake chain answers `get_job`; direct rating excluded; `tag2` read verbatim; every job state; other client / other agent; one job once and read once; missing job; other escrow never read; a failing job read throws |
| Contract | `contracts/contracts/reputation-registry/src/test.rs` | `tag2` stored and read back verbatim; `NewFeedback` carries URI and hash unchanged; the contract still accepts a rating with no reference (drop-in) |

## Verification

| Check | Result |
|---|---|
| `cargo fmt --all`, `cargo clippy --all-targets -- -D warnings` | Pass, no warning (local) |
| `cargo test -p reputation-registry` | 13 passed (10 existing + 3 new) (local) |
| `dart analyze` / `dart test` (domain, server) | **Not run locally**: no Dart SDK on the machine. Left to CI on the pull request |
| Testnet | Not run. No deploy is needed (no contract change), but a server deploy changes served ratings |

## Behavior change to expect

Every rating on testnet today was written before this change, with an empty
`tag2`, so after the server is deployed they stop counting and each agent
shows the prior (4.00, `paidHireCount 0`) until a consumer rates a completed
hire through the server again. This is the decision recorded above.

## Not covered (unchanged)

- An agent owner who hires the agent from a second wallet and pays a real job
  (S11): provenance proves a paid job, not an independent buyer (#200).
- Server vs chain status when a third party calls `release` (S15).
- Job entries archived after about 60 days are `jobUnreadable` until restored
  (S16).
