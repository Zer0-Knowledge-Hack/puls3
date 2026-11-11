# 10 · Final report

## Requirement matrix

| Requirement | Status | Evidence | Observation |
|---|---|---|---|
| Hire reference in feedback | PENDIENTE | `reputation_calls.dart:79-89` sends `tag2 = ""`, `feedback_uri = ""`, zero hash | The `jobId` is available (`HireRow.jobId`) but not sent |
| Verifiable evidence of payment | PARCIAL | Escrow `Completed` proves funded + settled (`escrow/src/lib.rs:516, 557, 849`) | The proof exists on chain, but no rating points to it |
| Job completed before rating | PARCIAL | App path: `HireNotCompleted` (`feedback_service.dart:147-149`). Contract: no check | Bypassable by a direct contract call |
| One rating per hire | PARCIAL | App path: `HireAlreadyRated` (`_isRated`, `:196-201`). Contract: index increments freely (`:238-239`) | Bypassable by a direct call; readers count every record |
| Verifiable link on chain | PENDIENTE | `FeedbackData` has no hire field (`reputation-registry/src/lib.rs:35`) | — |
| Independence from the backend | PENDIENTE | The only link is the server's `chain_submission` row (`feedback_service.dart:25-28`) | #202 made the formula verifiable, not the provenance |
| Stellar 8004 compatibility | CUMPLIDO (today) | ABI identical to the subset in ADR-0002; #199 deviation recorded | The recommended design keeps it (convention, no ABI change) |
| Domain tests | PARCIAL | `feedback_test.dart`, `feedback_record_test.dart` cover app-path rules and the four exclusions | No test for a paid-job reference (not run locally: no Dart SDK; CI on `main` passed) |
| Contract tests | PARCIAL | 20 reputation + 136 escrow tests pass (run locally) | No test of tags/URI/hash as a reference, none linking escrow and reputation |
| ADR-0002 documentation | PENDIENTE | ADR-0002 and ADR-0005 D5 describe the reader rule as a follow-up | An "Amended by #201" note is needed with the implementation |

## Answers

1. **What #201 really asks.** That a rating made through the app carries an
   on-chain reference to its paid job that anyone can verify without trusting
   the server, while keeping the app rules (one rating per hire, only after
   completion), with no Stellar 8004 ABI break and with tests on the domain and
   the contracts.
2. **Already implemented.** The paid-job proof itself (escrow `Completed`), the
   app-path rules in the domain and the server, the self-rating check in the
   contract, auth on every write, and a public, recomputable rating formula
   (#202).
3. **Missing.** The reference in the written feedback, a reader rule that uses
   it (paid, completed, same client and agent, one per job, pinned escrow),
   tests for both, and the ADR-0002 note.
4. **Current flow.** Consumer signs `create_job` and `fund`; the agent signs
   `submit`; the consumer signs `complete` (or anyone calls `release`); the
   server derives `completed`, checks eligibility, prepares `give_feedback`
   without any reference, the consumer signs it and the server relays it; the
   reader later counts every well-formed record ([03](03-feedback-flow.md)).
5. **Why the contract cannot prove it today.** The registry has no notion of a
   hire and no link to the escrow; it stores only value, decimals, revoked and
   two tags; puls3 writes no reference in any field; `feedback_uri` and
   `feedback_hash` are not stored at all ([04](04-contract-analysis.md)).
6. **How to fix it without trusting the backend.** Write a canonical job
   reference in the rating and let readers check it against the escrow's
   public state (`get_job`: `Completed`, same client, same agent, pinned
   escrow, first record per job). Anyone can rerun the check with public RPC
   reads ([09](09-technical-proposal.md)).
7. **Can `feedback_uri` and `feedback_hash` be used?** Yes, and they should be,
   as the ERC-8004 pointer and commitment. Alone they are not enough: they are
   only emitted, public RPC keeps events about 7 days, and neither proves
   payment. The durable, readable copy should go in `tag2`, and the proof is
   always the escrow state.
8. **Can the Stellar 8004 ABI be kept?** Yes. The recommended design changes no
   signature, type, event or error. It is a write convention plus a puls3
   reader rule, which ADR-0005 D5 already chose. Only a contract-enforced gate
   (alternative C) would break or deviate.
9. **What would change.** `puls3_domain` (`feedback_record.dart`: reference
   parsing, new exclusions, one per job, an escrow job reader port; a shared
   canonical hash encoder), `puls3_server` (`reputation_calls.dart`,
   `feedback_service.dart` prepare, `soroban_reputation_registry.dart` reader,
   wiring of the escrow id), `scripts/verify_reputation.dart`, ADR-0002. No
   contract change is required; the app needs none for the write side.
10. **Tests to add.** Listed in [08](08-test-coverage.md) (1–16): every
    exclusion reason, uniqueness per job, mismatched client/agent/escrow,
    unreadable job, malformed reference, deterministic hash, the prepared call's
    fields, the reader decoding `tag2`, the verifier, and contract tests that
    `tag2` round-trips and the event carries URI and hash.
11. **Risks.** Existing unreferenced ratings (served ratings change), read
    cost of one `get_job` per record, escrow redeploys, archived job entries,
    hash canonicalization drift, and self-dealing through a real paid job,
    which provenance does not solve (#200) ([09](09-technical-proposal.md) §8).

## Recommendation

Alternative B: no contract change, no ABI change. The server writes a
versioned job reference in `tag2` and `feedback_uri` and a canonical
`feedback_hash`; the domain gains a public rule that counts a rating only if
the pinned escrow says its job is `Completed` for the same client and agent,
once per job. It completes ADR-0005 D5 instead of reversing it, and the #202
verifier makes the result checkable by anyone.

## Next steps, in order

1. Product decision: what happens to existing ratings without a reference
   (strict exclusion vs dated "unverified" transition).
2. Fix the reference grammar and the canonical hash encoding (versioned), in
   an ADR-0002 amendment draft.
3. Domain: reference parser, escrow job reader port, new exclusions, one per
   job, tests 1–9.
4. Server: fill `tag2`/`feedback_uri`/`feedback_hash` in `prepare`; reader
   decodes `tag2` and reads jobs from the pinned escrow with a cache; tests
   10–12.
5. Contract tests 14–16 (no contract change).
6. Extend `verify_reputation.dart`; testnet evidence: one rating with a
   reference that the verifier accepts, one direct-to-contract rating that it
   excludes.
7. Separately: track self-dealing through a paid job with #200, the server vs
   chain status divergence (`release` by a third party), and job TTL upkeep.
