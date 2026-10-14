# Design: Feedback and Reputation (issue #21)

## Technical Approach

Domain-first, chain behind ports (proposal Approach 2). The rules live in `puls3_domain`. The server reuses `EscrowRelayService` for `give_feedback`, with the contract call supplied by a server port, so the #14 ABI is never invented. Catalog reputation is computed on read by a `CatalogReader` decorator that calls the #11 function. **Gate 0 (apply):** rebase on `origin/main` and bind the read port to the real signature in `puls3_domain/lib/src/reputation.dart`. This design could not read that file: the branch lacks it and no git access was available.

## Architecture Decisions

| # | Topic | Options and tradeoffs | Decision |
|---|---|---|---|
| D1 | Domain rule shape | A domain `Hire` cannot be rebuilt in `completed` from `HireRow` (transitions only). A use case alone would leave the server duplicating the rules. | A pure `checkFeedbackAllowed(...)` over plain facts is the single rule source. `SubmitFeedback` (domain `Hire` plus ports) and `FeedbackService` (server `HireRow`) both call it. Order: completed, already rated, from consumer (`FeedbackDoesNotMatchHire`), not owner (new `OwnerCannotRate`). |
| D2 | Owner source | (a) identity registry `owner_of` (`contracts/contracts/identity-registry/src/lib.rs:367`, `AgentNotFound = 3`). (b) `AgentWallet.owner` exists only for Studio-deployed agents (seed agents have no row) and is custody data. | (a). This matches domain `Agent.owner` ("registered the agent on-chain"). New domain port `AgentOwnerReader`, implemented by `SorobanLedger.ownerOf`. A null owner fails closed (`ChainDataUnavailable`). |
| D3 | `give_feedback` call | Hard-coding args invents #14. | Server port `ReputationCalls.giveFeedback(client, agentId, feedback) → ContractCall(contract, function, args)`. Production `UnwiredReputationCalls` throws `HireConfigurationMissing`; tests use a fake. |
| D4 | Relay generalization | A separate feedback relay duplicates verify, claim and send. | `_draft` gets `StellarAddress? contract` (default `_stellar.escrow`). `_allows` adds `giveFeedback => completed`. A new `prepareFeedback(wallet, hireId, ContractCall)` handles the `giveFeedback` case in `_prepare`. Submit reuses `submitEscrowCall`. |
| D5 | `feedbackReference` storage | A new `hire` column needs a migration. Tracker confirmation needs the #14 event decoder. | Derived from data: the hash of the hire's `giveFeedback` `ChainSubmission` whose state is not `failed`. That record also gives "already rated". No migration. The tracker leaves `giveFeedback` `submitted` (default branch) until #14. |
| D6 | Catalog reputation | Storing it in `AgentRecord` needs a migration and indexer work. | `ReputationCatalogReader` decorates the `CatalogReader`. It has a process-wide cache with a 60 s TTL (same pattern as `_chainCatalog`). A port failure serves stale values, else throws `AgentCatalogUnavailable`. It never makes up values. |
| D7 | Production read source | Throwing would take the catalog down. | `UnwiredReputationRegistry` returns empty inputs, so the result is the #11 empty-input value, the same as today's `0.0`. |
| D8 | Wire fields | Required fields break the Flutter constructors in tests. | `rating: double, default=0.0` and `paidHireCount: int, default=0` are optional in the generated constructor. The Flutter mapper keeps compiling. |

## Data Flow

    prepareFeedback ─→ FeedbackService ─ owned HireRow, submissions(rated), AgentOwnerReader
                          │ checkFeedbackAllowed (domain)
                          └→ ReputationCalls ─→ relay.prepareFeedback ─→ _draft(contract)
    submitFeedback ──→ FeedbackService (re-check) ─→ relay.submitEscrowCall
                          └→ HireDetail.hire.feedbackReference = submission.transaction
    agent.list/get ──→ ReputationCatalogReader ─→ inner reader + ReputationRegistry (cached)
                          └→ #11 fn → copyWith(rating, paidHireCount)

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `puls3_domain/lib/src/feedback.dart` | Create | `checkFeedbackAllowed`, `SubmitFeedback`, `ReputationRegistry` |
| `puls3_domain/lib/src/ports.dart` | Modify | `AgentOwnerReader` |
| `puls3_domain/lib/src/errors.dart` | Modify | `OwnerCannotRate` |
| `puls3_domain/lib/puls3_domain.dart` | Modify | export |
| `puls3_server/lib/src/feedback/feedback_endpoint.dart` | Create | 3 methods, `HireEndpoint` seams |
| `puls3_server/lib/src/feedback/feedback_service.dart` | Create | eligibility, prepare, submit, error mapping |
| `puls3_server/lib/src/feedback/reputation_calls.dart` | Create | `ContractCall`, port, unwired impl |
| `puls3_server/lib/src/feedback/feedback_eligibility.spy.yaml` | Create | `hireId`, `eligible`, `reason: String?` |
| `puls3_server/lib/src/hire/escrow_relay_service.dart` | Modify | D4 |
| `puls3_server/lib/src/ledger/soroban_ledger.dart` | Modify | `ownerOf` (absent error 3) |
| `puls3_server/lib/src/agent/agent_summary.spy.yaml` | Modify | D8 |
| `puls3_server/lib/src/agent/reputation_catalog_reader.dart` | Create | D6 |
| `puls3_server/lib/src/agent/agent_catalog_wiring.dart` | Modify | wrap the reader |
| `docs/architecture/api.md` | Modify | `OwnerCannotRate` code, `reason` field, `rating`/`paidHireCount` no longer planned |
| `lib/src/generated/**`, `puls3_client/**` | Regenerate | `serverpod generate`; no migration (no table touched) |

## Interfaces / Contracts

```dart
void checkFeedbackAllowed({required HireStatus status, required bool rated,
    required bool byConsumer, required bool byOwner}); // throws DomainError
abstract interface class ReputationRegistry {
  Future<TransactionHash> giveFeedback(Feedback feedback);
  Future</* #11 input */> reputationInputs(AgentId agent); // bound at Gate 0
}
abstract interface class AgentOwnerReader { Future<StellarAddress?> ownerOf(AgentId agent); }
```

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Unit (domain) | 4 rules and their order; no registry call on violation; reference set and status still `completed` | `puls3_domain/test/feedback_test.dart`, recording fake registry |
| Unit (server) | eligibility reason, prepare purpose and contract, already rated, owner, submit reference | `relay_rig.dart` plus in-memory stores with a seeded `completed` `HireRow`, fake `ReputationCalls`/owners |
| Unit (catalog) | values equal a direct #11 call; empty input; TTL; stale on failure | fake inner reader and registry, injected clock |
| Contract | `ReputationRegistry` fake | one shared suite in `test/support/`, reused when #14 lands |

## Threat Matrix

N/A: no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.

## Migration / Rollout

No migration required. Rollback: revert the PR and regenerate. All changes are additive and touch no on-chain state.

## ADR-0001 Boundary

The domain gets only pure rules and ports, with no Serverpod or Stellar SDK. `ContractCall`/`ScArg` stay in the server. **Flag:** the reputation input type crosses into the port, which is acceptable because it is domain-owned (#11).

## Open Questions

- [ ] Gate 0: the exact #11 signature and the rating type (double?).
- [ ] `HireEndpoint.submitEscrowCall` also accepts a `giveFeedback` preparation. The prepare gate stays authoritative; a purpose guard is optional.
