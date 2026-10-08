```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:924157b16eeb8f7cde6d5dc5fe7da9f9b3f8bf2cd20f2b2cb784e98aaab360b7
verdict: pass_with_warnings
blockers: 0
critical_findings: 0
requirements: 14/14
scenarios: 56/56
test_command: cd puls3_server && dart test test/unit test/protocol test/spike test/ledger test/hire && dart test test/integration
test_exit_code: 0
test_output_hash: sha256:080f76d58dd5019bccb2e96c3efcf9fde40cc1227a9184060db1efa489afd1df
build_command: cd puls3_server && dart analyze --fatal-infos
build_exit_code: 0
build_output_hash: sha256:57bd4e1ef86bc6c242698f842b0bc366f8a166f87511a29801850dcab995a3b1
```

## Verification Report

**Change**: issue-96-escrow-relay (HEAD 45076bb, branch feat/19-hire-pay-endpoint)
**Version**: delta specs escrow-relay (10 requirements, 41 scenarios) and hire-payment (4 requirements, 15 scenarios)
**Mode**: Strict TDD

### Completeness
| Metric | Value |
|--------|-------|
| Tasks total | 23 (apply-progress says 20/20; tasks.md has 23 boxes) |
| Tasks complete | 23 |
| Tasks incomplete | 0 |

### Build & Tests Execution
**Build** (dart analyze --fatal-infos): passed, "No issues found!", exit 0.

**Tests, unit/protocol/spike/ledger/hire**: 529 passed, 0 failed, 0 skipped, exit 0 (hash sha256:080f76d5...afd1df).
**Tests, integration (real Postgres and Redis containers started)**: 68 passed, 0 failed, exit 0 (hash sha256:ebf7842d...47f2).
**Coverage**: not available (no coverage run requested; informational only).
**Hygiene**: git checkout pubspec.lock after the runs; git status --short is empty.

### TDD Compliance
| Check | Result | Details |
|-------|--------|---------|
| TDD evidence reported | WARNING | Formal TDD Cycle Evidence tables exist only for C6 and C7. C1-C5 have narrative RED/GREEN with commands and counts (compile-error RED, counts). |
| All tasks have tests | OK | 19/19 testable tasks have test files; 2.1-2.3 and 7.3 are docs (structural checks stated). |
| RED confirmed (tests exist) | OK | Every test file named in apply-progress exists. |
| GREEN confirmed | OK | All named files pass on execution (529 + 68). |
| Triangulation | OK | Per-field, per-reason and per-code cases throughout. |
| Safety net | OK | Reported counts per phase. |

One unreproduced flake was reported in C5 (envelope_codec_test "signature over another transaction does not verify"). The test is deterministic (recorded vector against a built hash). It passed in my full run.

### Test layer distribution
Unit (fakes and contract fakes): the bulk, in test/unit, test/hire, test/ledger, test/spike, test/protocol. Integration against Postgres: 68 tests in 8 files (store contracts, race, relay flow). E2E: none; the testnet end-to-end is an accepted follow-up.

### Assertion quality
No tautologies, ghost loops or smoke-only tests found in the reviewed files. Loops over calls.entries and cases are over non-empty constants. One note: the service-level submit tests use FakeEnvelopeCodec, so the glue between EscrowRelayService._verify and the real StellarEnvelopeCodec is not exercised together (see W1).

### Spec compliance matrix (escrow-relay)
| Requirement / scenario | Covering test | Result |
|---|---|---|
| Spike gate: Spike passes | test/spike/envelope_spike_test.dart (decode/re-encode, hash, verify, for create_job and fund) | COMPLIANT |
| Spike gate: Spike fails | Conditional on a failure that did not occur; fallback documented in api.md | COMPLIANT (not applicable) |
| Spike gate: Golden vectors | test/ledger/envelope_codec_test.dart parse/verify groups on recorded vectors | COMPLIANT |
| Prepare: Prepare fund | escrow_relay_service_test.dart prepareFund (unsigned, bound to wallet), "fund carries Hire.price and the platform fee", "stores the preparation with the hash, sequence and window" | COMPLIANT |
| Prepare: Chain unavailable | prepareFund "without a USDC balance fails ChainUnavailable and persists nothing", "an unreadable account ..." | COMPLIANT |
| Prepare: complete and reject | prepareComplete, prepareReject groups, "a missing or blank reason is InvalidRejectReason" | COMPLIANT |
| Window config: Missing preparation window | service test "configuration without defaults" (3 keys x 6 bad values); hire_service_create_test "a missing setting fails naming it and persists nothing" | COMPLIANT |
| Window config: Missing job duration | service test "a missing job duration fails prepareCreateJob and nothing else" | COMPLIANT |
| Window config: No default in code | Behavioral only (missing and invalid fail); no test inspects sources for literals | PARTIAL (W2) |
| Ownership: Not logged in | hire_endpoint_test.dart "without a session no service work happens" x6, "createHire stores nothing" | COMPLIANT |
| Ownership: Every method enforces the seam | hire_endpoint_test.dart "every method resolves the session wallet exactly once, first" x6 | COMPLIANT |
| Ownership: Hire not owned | service ownership tests; escrow_relay_submit_test "InvalidHireId, HireNotFound and HireNotOwned come first"; endpoint HireNotOwned x5 | COMPLIANT |
| Ownership: Wallet parameter differs | hire_endpoint_test "a consumer other than the session wallet is WalletMismatch" (no hire stored) | COMPLIANT |
| Ownership: Unknown or foreign preparation | submit tests: unknown id, other hire, other signer = PreparationNotFound | COMPLIANT |
| Ownership: Invalid or unknown hire | service and submit ownership tests | COMPLIANT |
| Expiry: Time bounds passed | submit "after the time bounds it is PreparationExpired(timeBounds)", boundary tests, "a repeated submit after validUntil expires" | COMPLIANT |
| Expiry: Superseded | submit "a superseded preparation is PreparationExpired(superseded)", "losing the claim to a newer preparation ..." | COMPLIANT |
| Expiry: Supersession reuses the sequence | service "a second preparation reuses the sequence and supersedes the first" | COMPLIANT |
| Verification: Malformed envelopes | codec parse/malformed (empty, not base64, truncated x2, trailing, fee-bump); submit "empty, non-base64 and truncated ..." | COMPLIANT |
| Verification: contract, function, arguments, source, time bounds | envelope_codec_test firstDifference "names the contract/function/arguments/source/time bounds" (real bytes), plus group-order tests; service maps to details.field in "a different body is EnvelopeMismatch naming the field" | COMPLIANT |
| Verification: outside the named groups (other) | codec "other" group: fee, sequence, Soroban data, memo, undecodable body; submit "no match found by the codec still names a field: other" | COMPLIANT |
| Verification: Unsigned / Signed by another key / Does not verify | codec verify tests (missing, wrong hint, tampered hint, two signatures, corrupted, other passphrase, other transaction); service "an unsigned, foreign or corrupt signature is InvalidTransactionSignature" | COMPLIANT |
| Verification: precedes persistence | submit group "verification precedes persistence" (expectUntouched), "first failure wins" | COMPLIANT |
| Persist then send: Accepted by RPC | submit "the record exists, submitted, before sendTransaction is called", "an accepted send returns the submitted record" | COMPLIANT |
| Persist then send: Definitive rejection | submit "an ERROR answer fails the record SubmissionRejected without throwing", "a request the node refuses ..." | COMPLIANT |
| Persist then send: RPC unreachable | submit "an unreachable node leaves it submitted and sends once", "TRY_AGAIN_LATER ..." | COMPLIANT |
| Persist then send: Invalid hire transition | submit "a hire state that no longer allows the purpose is InvalidHireTransition" | COMPLIANT |
| One submission: Repeated submit returns existing | submit "a repeated submit returns the existing record and does not send" | COMPLIANT |
| One submission: Repeated submit still verified | submit "a repeated submit is verified again" | COMPLIANT |
| One submission: Concurrent submits | submit "the loser of a concurrent submit re-reads the winner without sending"; Postgres escrow_preparation_store_test race, identical-submit and hash-conflict tests | COMPLIANT |
| In flight: Submission in flight | service "every prepare is SubmissionInProgress while an escrow record is submitted" | COMPLIANT |
| In flight: Fund already reached the chain | service "is PaymentAlreadySubmitted once an earlier fund reached the chain" | COMPLIANT |
| In flight: Re-prepare after a final failure | service "a failed record does not block a new preparation", "prepares again after a fund that never reached the chain"; submit "after a rejection the hire can prepare again" | COMPLIANT |
| In flight: Wrong hire state | service "state guards" (5 cases) | COMPLIANT |
| Settlement: Complete stays submitted | submit "a relayed complete stays submitted ...", "a relayed reject stays submitted even when the chain confirms it" | COMPLIANT |

### Spec compliance matrix (hire-payment)
| Requirement / scenario | Covering test | Result |
|---|---|---|
| Create: Hire created with prepared create_job | hire_service_create_test "stores a hire with no status and prepares its create_job", "expired_at is now plus the configured duration", "create_job names the agent wallet, consumer, USDC and price" | COMPLIANT |
| Create: Retry with the same requestId | "retries ... return the existing hire with its current preparation", "prepare a fresh one when the previous expired unused" | COMPLIANT |
| Create: Retry after create_job submitted | "return no preparation once the create_job is submitted or confirmed", "prepare again when the submitted create_job failed" | COMPLIANT |
| Create: requestId reused with different content | "with another agent or input fail IdempotencyKeyReused and change nothing"; endpoint test | COMPLIANT |
| Create: requestId scoped per wallet | "requestId is scoped per wallet"; integration "two createHire calls with one request id ..." | COMPLIANT |
| Create: Unknown or inactive agent | "AgentUnavailable when the agent is unknown or has no wallet"; endpoint InvalidAgentId and AgentNotFound. AgentInactive is not distinguishable | PARTIAL (accepted follow-up) |
| Create: Input too long or invalid hire | InvalidHire tested (blank requestId, bad manifest, bad consumer); InputTooLong not enforced | PARTIAL (accepted follow-up) |
| Create: First preparation fails | "the first preparation failing persists no hire, and a retry creates it"; integration "a failed first preparation stores no hire" | COMPLIANT |
| Create: Ledger unavailable on create | "HireLedgerUnavailable when the wallet read fails"; endpoint "a chain that cannot be read is ChainUnavailable" | COMPLIANT |
| create_job confirmed | hire_escrow_effects_test onJobCreated "binds the job id, opens the hire and takes the prepared expiry"; integration "create_job, submit and onJobCreated open the hire" | COMPLIANT |
| Applied twice | "applied twice it succeeds and the job id is stored once" | COMPLIANT |
| Job id already bound | "a job id another hire holds is a mismatch and the hire keeps no status" | COMPLIANT |
| Funding before confirmation | service state guards "fund is InvalidHireTransition for a hire with status none" | COMPLIANT |
| Seam enforced on every method | endpoint "every method resolves the session wallet exactly once, first" | COMPLIANT |
| Status unchanged after complete or reject relay | submit "complete and reject settle with issue 97" | COMPLIANT |

**Compliance summary**: 56/56 scenarios have a passing covering test. 53 are fully compliant; 3 are PARTIAL and counted complete only because two are follow-ups accepted by the orchestrator (InputTooLong, AgentInactive) and one (No default in code) is proven behaviorally but not by source inspection (W2). 0 UNTESTED, 0 FAILING.

### Issue 96 acceptance criteria
| # | Criterion | Evidence | Result |
|---|---|---|---|
| 1 | Create and fund on testnet using only prepare and submit | Unit and Postgres flow tests; hire_relay_flow_test "create_job, submit and onJobCreated open the hire"; no testnet end-to-end run | NOT RUN (accepted; blocked on session work in issue 25 and a testnet run) |
| 2 | Envelope differing in any field rejected, one test per group | envelope_codec_test firstDifference tests for contract, function, arguments, source, time bounds, other | COMPLIANT |
| 3 | Caller cannot prepare or submit for a hire of another wallet | service ownership test (HireNotOwned, nothing read or stored); endpoint HireNotOwned x5 including submitEscrowCall and "ownership follows the session wallet, not the caller input" | COMPLIANT |
| 4 | submit never throws for chain outcomes | submit tests: ERROR answer, node-refused request, unreachable node, TRY_AGAIN_LATER (see W3 for a gap after the send) | COMPLIANT with W3 |
| 5 | At most one ChainSubmission per preparation, repeat returns the record | submit "a repeated submit returns the existing record", concurrent test, Postgres race tests | COMPLIANT |

### Correctness and drift (static plus runtime)
| Item | Status | Notes |
|---|---|---|
| Check order | OK | _ownedHire (InvalidHireId, HireNotFound, HireNotOwned), preparation lookup (NotFound for id, hire or signer), superseded, time bounds, parse, body bytes, signature, findByPreparation, hire state, then claim plus insertSubmitted. Matches spec and api.md. A repeated submit is verified and expiry-checked first (P4). |
| Error codes and details | OK with notes | InvalidSignedEnvelope details.reason, EnvelopeMismatch details.field, InvalidTransactionSignature details.reason and PreparationExpired details.reason match api.md. InvalidHireTransition details.status is the string none for a null status where api.md says null (S1). |
| Idempotency | OK | requestId lookup before prepare; IdempotencyKeyReused; per-wallet; currentCreateJob returns null once a createJob is submitted or confirmed. |
| createHire status-null semantics | OK | Hire stored with null status, opened only by onJobCreated; prepareFund rejects null status. |
| Persist-then-send | OK | A test proves the record exists when sendTransaction runs; claim and insert in one transaction. |
| Never-throw on chain outcomes | Mostly | See W3. |
| Session enforcement first and once | OK | The endpoint calls requireLogin first in all six methods; services are built after login; tests assert the event order. |
| Single-signature rule | OK | verify: 0 signatures = missing; more than 1, or a hint that is not the signer key = wrongSigner; failed ed25519 = doesNotVerify. |
| Body-bytes equality and hash | OK | Byte equality on the decoded-and-re-encoded tx; trailing-byte guard by length comparison; hash from the configured passphrase. |
| SOURCE_ACCOUNT-only auth | OK | build rejects any auth entry whose credential type is not 0; two codec tests. |
| Ownership before verification | OK | Hire ownership and preparation signer checks precede _verify; no XDR parsing happens for a foreign hire. |
| No sidecar | OK | No TypeScript sidecar; stellar_dart adapter. |

### Design coherence
| Decision | Followed? | Notes |
|---|---|---|
| D1 preparation table | Yes | escrow_preparation plus migration 20261008012344930. |
| D2/D3 conditional UPDATEs, one transaction | Yes | Proven on Postgres (12 concurrent rounds, one winner). |
| D4 envelope build | Yes | PRECOND_TIME, seq+1, fee = inclusion + minResourceFee, spliced simulation data. |
| D5/D6/D7 mismatch, malformed, hash and signature | Yes | |
| D8 stellar_dart gated by spike | Yes | |
| D9 SessionWallet fail-closed | Yes | |
| D10/D11 lifecycle store, prepare-first createHire | Yes | |
| D12 onJobCreated | Yes | Idempotent; mismatch on a job id held elsewhere. |
| D13 send outcomes | Yes | |
| D14 config without defaults | Yes (name differs) | Raises HireConfigurationMissing rather than ConfigurationUnavailable (documented deviation; matches the typed configuration error in the spec). |
| UnsupportedAuthorization mapped in the service | Documented deviation | Mapped to InternalError in the service. |

### Issues Found

**CRITICAL**: None.

**WARNING**
- W1. No test composes EscrowRelayService with the real StellarEnvelopeCodec. Submit tests use FakeEnvelopeCodec (tag-based signatures), and codec tests verify recorded on-chain signatures. A freshly built envelope signed by a real key and then submitted through the service is never exercised, so the glue (parse of the prepared XDR for the body, verify of the signed envelope against its hash) is proven only by composition of parts. Recommend one test that builds, signs with an ed25519 key, and submits through the real codec, or the testnet end-to-end before merge.
- W2. Scenario "No default in code" (to be inspected by a test) has no source-inspection test. Behavioral tests (missing, empty, non-integer and out-of-range values fail naming the key) show no fallback works, but not that no literal exists.
- W3. submitEscrowCall can throw ChainDataUnavailable from _detail (agent catalog read) after the record is persisted and the envelope sent. The chain outcome is safe (a retry returns the record), but the caller sees an error for a relay that happened, ChainDataUnavailable is not in the api.md catalog row for submitEscrowCall, and no test covers this path. Consider returning the detail without catalog data, or documenting the code.
- W4. TDD Cycle Evidence tables exist only for C6 and C7; C1-C5 are narrative. The evidence is verifiable (files exist, tests pass) so this is not a protocol failure, but the tables are incomplete. Apply-progress also states 20/20 while tasks.md has 23 checked boxes.
- W5. HireEndpoint._prepare does not map AgentUnavailable (raised by prepareCreateJob when the agent has no wallet) to a catalog code, so it can reach the client as a raw Serverpod exception. createHire maps it to AgentNotFound; prepareCreateJob does not.

**SUGGESTION**
- S1. InvalidHireTransition details.status is none for a null status; api.md says null. Align one of them. The extra details.purpose is harmless.
- S2. InvalidSignedEnvelope adds details.reason that api.md does not list. Document it.
- S3. parse re-encodes the transaction for the body comparison and the hash, but the stored and sent string is the raw XDR from the client. A non-canonical encoding (for example non-zero padding) would be signed and checked over the canonical form and then rejected by the network; no security impact, only a late failure. A byte-for-byte round-trip comparison of the whole envelope in parse would close it.
- S4. The C5 flake report for "signature over another transaction does not verify" was not reproduced; keep an eye on it in CI.

**Known and accepted follow-ups (not failures)**: InputTooLong not enforced (no documented limit); AgentInactive indistinguishable from AgentNotFound; PersistenceUnavailable unmapped; getHire and listHires not implemented (so HireDetail from submit has null payment, result and explorer fields); onFunded does not compare the payment job id with hire.jobId; complete/reject settlement depends on issue 97; SessionWallet fail-closed until issue 25; testnet end-to-end not run (acceptance criterion 1).

### Verdict
PASS WITH WARNINGS

0 CRITICAL, 5 WARNING, 4 SUGGESTION. All 529 unit-level and 68 integration tests pass, analysis is clean, every spec scenario has a passing covering test except three partials (one new, two accepted), and the verification path is sound on body-bytes equality, single signature, hash and signature checks, SOURCE_ACCOUNT-only auth and ownership-before-verification. Archive is not blocked; W1 and W3 are worth addressing before merge.

### Remediation of verify warnings

Resolved in apply batch 8 (strict TDD, tests written first):
- W1 resolved: `test/hire/escrow_relay_real_codec_test.dart` ("a createJob signed with a real key is relayed as signed", "a fund signed with a real key is relayed as signed", "a tampered envelope is EnvelopeMismatch and nothing is stored", "a signature by another key is InvalidTransactionSignature").
- W3 resolved: `escrow_relay_submit_test.dart`, group "agent catalog outage" ("an outage before anything happened stores and sends nothing, and the retry relays once", "the catalog is read once, before the claim, ... a retry returns the same record"). The agent is read before the claim because `HireDetail.agent` is required; `ChainDataUnavailable` before any side effect is not in api.md's `submitEscrowCall` row (propose adding it).
- W5 resolved: `hire_endpoint_test.dart` "prepareCreateJob for an agent without a wallet is AgentNotFound".
- S1 resolved: `escrow_relay_service_test.dart` "a hire without a status carries no details.status" and "a hire with a status names it in details.status" (`status` omitted rather than the string none).
- W4 task-count inconsistency corrected in apply-progress (23/23).

Still open: W2, W4 (TDD tables for C1-C5), S2, S3, S4.
