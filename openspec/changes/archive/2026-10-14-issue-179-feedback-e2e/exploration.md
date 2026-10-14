# Exploration: issue #179 — feedback end to end on testnet through the server

Engram: `sdd/issue-179-feedback-e2e/explore` (obs 528).

## Current state

- `chain/chain_submission_tracker.dart` marks `release` and `claim_refund` as `confirmed` on a successful transaction (~line 262) but runs no hire effect.
  - `setAgentWallet` and `submit` are in `_untrackedPurposes` and stay `submitted`.
  - Nothing writes `EscrowCallFailed` (only reference outside `submission_values.dart`: `serverpod_chain_submission_store.dart:194-200`, behavior unverified).
  - `EffectFailed` only accepts `jobMismatch` and `jobEvidenceUnavailable`.
- `chain/escrow_server_submit.dart`: `RelayEscrowCallSender` handles `release` and `claim_refund` only, signed with `escrowRelaySigningKey`. `maxEscrowCallAttempts = 3` only stops building a 4th envelope; it never fails the record. `EscrowServerCall` has no `submit`; there is no agent-custodied-key sender (`runtime/hire_runner.dart:83`).
- Hire status is not persisted past `funded`: `serverpod_hire_repository._row` derives null/open/funded from `jobId` and the payment row. Nothing assigns `HireStatus.completed`, so `FeedbackService._requireRateable` can only pass with fakes. `EscrowEffects` has `onJobCreated`, `onFunded`, `onFeedbackGiven`, no release/refund hook. `api.md:460` lists this as an open prerequisite (#97).
- `ReputationCatalogReader.list` uses `Future.wait`; `ReputationCache.of` throws `AgentCatalogUnavailable` when the registry fails with nothing cached, so one unreadable agent fails the whole catalog.
- `ledger/soroban_reputation_registry.dart:117` builds `Feedback(hireId: HireId(index))` from the registry `feedback_index`. `Feedback.hireId` is required and used by `SubmitFeedback.matchesHire` (`feedback.dart:72`).
- D5: ADR-0005 D5 says readers filter by clients with completed jobs; `api.md:266` says the catalog does not filter yet.
- Docs: `api.md:143` says `release` makes the hire `completed`; ADR-0005 D6 removed `rated`. Flutter shows 0.0 in `atoms/rating_badge.dart`, `molecules/agent_card.dart`, `domain/agent.dart`.
- Tooling: `tool/feedback_walkthrough.dart` (untracked, fakes), `tool/reputation_read_testnet.dart`.

## Approaches (item 1: hire becomes `completed`)

| Approach | Pros | Cons | Effort |
|---|---|---|---|
| A. Derive status from confirmed submissions (release → completed, claim_refund → expired) in `_row` / `HireLifecycleStore` | No migration, idempotent, same precedent as derived `feedbackReference` | Extra query per status read; no `submitted`/`rejected` | Low-Med |
| B. Persist a status column + `onReleased`/`onRefunded` effects | Explicit state, prepares #97 | Migration + serverpod generate, likely >400 lines | High |
| C. Read job state from chain after `release` | Authoritative | Extra RPC, no persistence gain | Med |

Item 4a: catch per-agent failure in `ReputationCatalogReader.list`; the agent keeps the #11 empty-input values.
Item 4b: nullable `Feedback.hireId` (smaller, touches `feedback_test`, `reputation_test`, fakes) or a separate `RegistryFeedback` read model (cleaner, larger).

## Recommendation

Take A plus `EscrowCallFailed` written by the sender (3rd failed record of that purpose for the hire). Agent `submit` signing goes to its own PR or the other contributor. Split: PR1 tracker + derivation + `EscrowCallFailed`; PR2 cache isolation + `hireId` decoupling; PR3 F7 script + docs + D5 outcome.

## Code vs ops

Code: items 1, 3, 4, 5 (if filtered), 6. Ops: item 2 (deploy, relay key, testnet runs). Flutter 0.0 preview is frontend; flag only.

## Size

~450-700 changed lines vs the 400 budget.

## Risks

- Single in-flight gate in `RelayEscrowCallSender`: one stuck `submitted` release/claim blocks every hire.
- `hireId` change ripples into domain tests.
- D5 filter adds reads per agent against the 60 s `ReputationCache`.
- Overlap check (orchestrator, 2026-10-14): no open PR touches the tracker, sender, reputation reader or hire repository files. #97 is closed; its handoff says the remaining effects are taken by @XxHugheadxX, but no PR exists yet.
- Strict TDD applies; tracker tests at `test/unit/chain/chain_submission_tracker_test.dart` ~484-650.

## Open product decisions

1. D5 filter: (a) implement now, (b) keep unfiltered and amend ADR/api.md, (c) filter via on-chain job history. Lean: (b).
2. Wording: ADR D6 (`completed` + `feedbackReference`) over "Rated" in #21.
3. Flutter 0.0 preview: out of scope for this user (frontend).
4. Ownership of item 1 / agent `submit` (see overlap risk).
