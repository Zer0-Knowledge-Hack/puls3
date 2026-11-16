# 08 · Test coverage

## Commands run (2026-11-07, Windows, on the local checkout)

```bash
cd contracts
cargo test -p reputation-registry -p escrow
#   escrow               136 passed; 0 failed
#   reputation-registry   20 passed; 0 failed
```

`cargo test` rewrote existing snapshot files with CRLF line endings only. They
were restored with `git checkout -- contracts`, so the working tree has no
change from the run.

**Dart tests were not run:** no Dart or Flutter SDK is installed on this
machine (`dart` is not on `PATH`, and no `dart.exe` was found). Their state is
taken from CI: the latest `CI` run on `main` (`dd2a83d`, run 42282204498)
passed, with the `server` job successful and the `domain` job skipped (no
domain change in that commit). The domain and server test lists below come
from reading the files, not from a local run.

## What is tested today

### Contract: `reputation-registry/src/test.rs` (20 tests)

| Behavior | Test |
|---|---|
| A feedback is stored and emits one event | `give_feedback_stores_and_emits_one_event` |
| Unregistered agent rejected (cross-contract) | `feedback_for_unregistered_agent_is_rejected_cross_contract` |
| Owner cannot rate own agent | `owner_cannot_rate_own_agent` |
| Decimals and range checks | `value_decimals_and_range_are_checked`, and the #199 tests |
| Revoke single use, submitter only | `revoke_is_single_use_and_persists_the_flag`, `only_the_submitter_can_revoke_their_feedback` |
| Summary excludes revoked | `summary_averages_excludes_revoked_and_requires_clients` |
| Responses | `append_response_is_open_but_needs_feedback_and_a_uri` |
| Auth required | `submitter_auth_is_required_without_mock_all_auths` |

Nothing about hires, jobs, `feedback_uri`, `feedback_hash` content or tags as
references. That is expected: the contract has no such behavior.

### Contract: `escrow/src/test.rs` (136 tests)

Lifecycle, guards, refunds, settlement, `get_job`. The facts the new reader
rule depends on (`Completed` only from `Submitted`, `client` recorded at
`create_job`, `provider` bound to the agent wallet) are covered by the escrow
suite, not by a test that links escrow and reputation.

### Domain: `puls3_domain/test/feedback_test.dart`

Covers `checkHireRateable` (completed only, already rated, mismatch, order),
self-rating, and `SubmitFeedback` (consumer only, same hire, unbound
`hireId == null` rejected, owner rejected, second feedback rejected, unknown
owner fails closed).

### Domain: `puls3_domain/test/feedback_record_test.dart`

The four exclusion reasons and "nothing is dropped without a public reason".

### Server: `puls3_server/test/feedback/`

`feedback_service_test.dart` (eligibility, prepare, submit, replay, owner
re-check), `soroban_reputation_calls_test.dart` (the nine arguments: empty
strings, zero hash), `feedback_endpoint_test.dart`,
`escrow_relay_feedback_test.dart`, `reputation_wiring_test.dart`,
`fake_reputation_registry_contract_test.dart`; and
`test/unit/ledger/soroban_reputation_registry_test.dart` for the reader.

## Requirement vs coverage

| Requirement | Tested today? | Where |
|---|---|---|
| Only the hire's client can rate (app path) | Yes | `feedback_service_test.dart` ("another wallet cannot prepare it"), `feedback_test.dart` |
| Payment confirmed | Indirectly (status `completed` from settlement) | `feedback_service_test.dart` ("a funded hire is not eligible") |
| Job completed before rating | Yes (app path) | Same |
| One rating per hire | Yes (app path) | "a hire with a live giveFeedback is already rated", "a second feedback is rejected" |
| Hire reference linked to the on-chain feedback | **No** | `soroban_reputation_calls_test.dart` asserts the opposite (empty URI, zero hash) |
| Hash verifiable | **No** | — |
| Reference not reusable | **No** | — |
| On-chain data consistent with the hire | **No** | — |
| A direct-to-contract rating does not count | **No** | `feedback_record_test.dart` asserts it **does** count if well formed |

## Missing tests (for the implementation phase)

Domain (`puls3_domain`):

1. A record with a valid reference to a `Completed` job of the same client and
   agent counts.
2. No reference → excluded (new reason, e.g. `noPaidHire`).
3. Reference to a job in `Open`, `Funded`, `Submitted`, `Rejected`, `Expired`
   → excluded.
4. Job of another client → excluded. Job of another agent → excluded.
5. Reference to a non-canonical escrow → excluded.
6. Two live records with the same job → only the first by index counts; a
   revoked first record does not consume the job (or does, per decision).
7. Job unreadable → its own exclusion reason, not "paid".
8. Malformed reference string → excluded, never a crash.
9. Every exclusion is public (extends the #202 property test).

Server:

10. `prepare` puts the hire's `jobId` reference into `tag2`, `feedback_uri`
    and the hash input; a hire without `jobId` cannot be prepared.
11. The canonical document and hash are deterministic (golden vector).
12. The reader decodes `tag2` and passes it to the domain rule; `get_job` is
    read from the pinned escrow; `feedbacksOf` equals the domain result.
13. `verify_reputation.dart` reports the new exclusion and still matches.

Contract:

14. `give_feedback` stores `tag2` verbatim and `read_feedback` returns it
    (long reference string, unicode-free format).
15. `NewFeedback` carries `feedback_uri` and `feedback_hash` unchanged.
16. Escrow: a cross-contract test that a job reaches `Completed` only via
    `Funded → Submitted`, and `get_job` returns `client` and `agent_id` the
    reader relies on (most of it exists; one end-to-end test helps).
