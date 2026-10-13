# Flutter–Serverpod API contract

- **Issue:** #8 · **Status:** Draft contract · **Sources:** [MVP flows](../blueprints/flows.md), [domain model](../domain/model.md), [hire lifecycle](../domain/hire-lifecycle.md), [ADR-0001](../adr/0001-system-architecture.md), [ADR-0002](../adr/0002-agent-registry-on-soroban.md), [ADR-0003](../adr/0003-payment-rail-and-custody.md), [ADR-0004](../adr/0004-agent-manifest-and-deployment.md), [ADR-0005](../adr/0005-align-agent-commerce-with-erc-8183-and-erc-8004.md) (#71), Flutter–Stellar wallet spike (#68, `docs/spikes/flutter-stellar-wallet.md`, section "Recommended changes for #8 and ADR-0003")

> **Aligned with ADR-0005 (2026-10-02).** A hire is an ERC-8183 escrow job. Changed: contract rule 3, the scalar mapping, the hire rows of the endpoint table, the lifecycle error rule, asynchronous outcome codes, server-signed escrow calls (new), [hire escrow states](#hire-escrow-states) (was "Hire payment states"), [funding verification](#funding-verification) (was "Payment verification mapping"), feedback (the `authorize_feedback` flow is removed, D5), response shapes, the polling contract, F5–F7 traceability, and the open questions. Decisions A and B and the relay rules are unchanged. Expiry, runtime-timeout and approval-window values are deferred (ADR-0005 D3) and come from server configuration. Aligned with the escrow on main (#78, #94): no `setBudget`, approval window and `release`, `is_expired`, `fund` parameters. Catalog aligned with the AgentEndpoint implementation (#88, #98).

This is the boundary between the Flutter app and Serverpod for the MVP. The app connects wallets and asks the user to sign what the server prepared. The server owns persistence, transaction preparation, relay submission, chain reads, escrow job verification, deploy orchestration, and agent execution. Endpoint implementations remain in issues #17–#21 and #35.

## Contract rules

1. IDs and USDC amounts cross the wire as `int`; USDC values are always stroops, never `double`.
2. Stellar addresses and transaction hashes cross as validated `String` values. XDR crosses as base64 `String`.
3. The server never signs on behalf of a user. It signs only with keys it custodies (agent accounts, ADR-0003 as amended by ADR-0005) and submits permissionless calls such as `claim_refund` and `release`.
4. **Server relay (Decision A).** Every user-signed transaction or authorization entry is prepared by the server, signed unchanged by the wallet, and returned to a Serverpod `submit…` method. The app never builds or submits a Stellar transaction itself.
5. **Idempotency.** A retry uses the same resource id (`draftId`, `hireId`), the same `requestId` for `createHire`, and, for submissions, the same `preparationId` and signed XDR. Mutating methods return the current resource for a repeated input instead of applying it twice.
6. **Chain outcomes are data, not errors.** Chain work in progress and its final result are reported through response fields (`ChainSubmission.state` and `errorCode`, `DeploySession.state` and `failureCode`). Exceptions are reserved for requests the server rejects before taking ownership of chain work.
7. Every endpoint failure in the table is transported as a serializable `Puls3ApiException`. Its stable `code` drives client behavior; its optional `message` and `details` contain only safe, user-displayable data. Native Serverpod session rejection happens before endpoint execution and is handled by Flutter as HTTP `401` or `403`, without assuming a serialized exception body.
8. **Read methods have no side effects.** `get…` and `list…` methods never start chain work.
9. Draft `.spy.yaml` models live in [`models/`](models/). They mirror domain field names; adapters reconstruct and validate domain value objects.
10. MVP identity is wallet-first: a verified wallet challenge establishes the Serverpod session. There is no email/password UI.
11. **Progress transport (Decision B).** MVP clients poll the read methods named below. A later streaming transport is additive and emits the same shapes.

### Domain-to-wire scalar mapping

| Domain type | Wire type | Validation owner |
|---|---|---|
| `AgentId`, `HireId`, `UsdcAmount` | `int` | Domain adapter; amount means USDC stroops |
| `StellarAddress`, `TransactionHash` | `String` | Domain adapter |
| `HireStatus` | `String` | One of `open`, `funded`, `submitted`, `completed`, `rejected`, `expired` (ADR-0005 D6, #73) |
| `RuntimeStatus` | `String` | One of `queued`, `running`, `failed`; runtime progress, not a hire state |

## Endpoint contract

`Auth` means a wallet-bound Serverpod user session. For every `Auth: Yes` method, Flutter maps native HTTP `401` to an unauthenticated or expired-session outcome and HTTP `403` to a forbidden outcome. When a method accepts a wallet address (`builder`, `consumer`, or `client`), it returns `WalletMismatch` unless that address equals the wallet bound to the session. Resource ownership checks use that same bound wallet even when no address parameter is present.

| Endpoint class | Method | Parameters | Returns | Auth | Possible errors |
|---|---|---|---|---|---|
| `WalletAuthEndpoint` (`walletAuth`) | `createChallenge` | `wallet: String` | `WalletChallenge` | No | `InvalidStellarAddress`, `ChallengeRateLimited`, `AuthenticationUnavailable` |
| `WalletAuthEndpoint` (`walletAuth`) | `verifyChallenge` | `challengeId: String`, `wallet: String`, `signedChallengeXdr: String` | `AuthSuccess` | No | `InvalidStellarAddress`, `ChallengeNotFound`, `ChallengeExpired`, `ChallengeConsumed`, `InvalidWalletSignature`, `AuthenticationUnavailable` |
| `ConfigEndpoint` | `getNetworkConfig` | — | `NetworkConfig` | No | `ConfigurationUnavailable` |
| `AgentEndpoint` | `list` | — | `List<AgentSummary>` | No | `AgentCatalogUnavailable` (typed exception, see [Agent catalog](#agent-catalog)) |
| `AgentEndpoint` | `get` | `id: String` (metadata id, for example `agt-001`) | `AgentSummary?` (`null` for an unknown id) | No | `AgentCatalogUnavailable` (typed exception) |
| `StudioEndpoint` | `saveDraft` | `draft: AgentManifestDraft` | `StudioDraft` | Yes | `InvalidManifest`, `DraftNotOwned`, `DraftVersionConflict` |
| `StudioEndpoint` | `testRun` | `draftId: int`, `input: String` | `TestRunResult` | Yes | `DraftNotFound`, `DraftNotOwned`, `InvalidManifest`, `InputTooLong`, `TestQuotaExceeded`, `RuntimeUnavailable`, `AgentExecutionFailed` |
| `StudioEndpoint` | `prepareDeploy` | `draftId: int`, `builder: String` | `DeploySession` | Yes | `DraftNotFound`, `DraftNotOwned`, `InvalidStellarAddress`, `WalletMismatch`, `InvalidManifest`, `AgentWalletCreationFailed`, `SubmissionInProgress`, `ChainUnavailable` |
| `StudioEndpoint` | `submitRegistration` | `draftId: int`, `preparationId: String`, `signedTransactionXdr: String` | `DeploySession` | Yes | `DraftNotFound`, `DraftNotOwned`, `PreparationNotFound`, `PreparationExpired`, `InvalidSignedEnvelope`, `EnvelopeMismatch`, `InvalidTransactionSignature` |
| `StudioEndpoint` | `getDeploySession` | `draftId: int` | `DeploySession` | Yes | `DraftNotFound`, `DraftNotOwned` |
| `StudioEndpoint` | `prepareWalletAuthorization` | `draftId: int` | `DeploySession` | Yes | `DraftNotFound`, `DraftNotOwned`, `RegistrationNotConfirmed`, `AgentWalletUnavailable`, `SubmissionInProgress`, `ChainUnavailable` |
| `StudioEndpoint` | `submitWalletAuthorization` | `draftId: int`, `preparationId: String`, `signedAuthorizationEntryXdr: String` | `DeploySession` | Yes | `DraftNotFound`, `DraftNotOwned`, `RegistrationNotConfirmed`, `PreparationNotFound`, `PreparationExpired`, `InvalidAuthorizationEntry`, `AuthorizationExpired` |
| `HireEndpoint` | `createHire` | `agentId: int`, `consumer: String`, `input: String`, `requestId: String` | `CreateHireResult` | Yes | `InvalidAgentId`, `InvalidStellarAddress`, `WalletMismatch`, `AgentNotFound`, `AgentInactive`, `InputTooLong`, `InvalidHire`, `IdempotencyKeyReused`, `PersistenceUnavailable`, `ChainUnavailable` |
| `HireEndpoint` | `prepareCreateJob` | `hireId: int` | `PreparedTransaction` | Yes | `InvalidHireId`, `HireNotFound`, `HireNotOwned`, `InvalidHireTransition`, `SubmissionInProgress`, `ChainUnavailable` |
| `HireEndpoint` | `prepareFund` | `hireId: int` | `PreparedTransaction` | Yes | `InvalidHireId`, `HireNotFound`, `HireNotOwned`, `InvalidHireTransition`, `SubmissionInProgress`, `PaymentAlreadySubmitted`, `ChainUnavailable` |
| `HireEndpoint` | `prepareComplete` | `hireId: int` | `PreparedTransaction` | Yes | `InvalidHireId`, `HireNotFound`, `HireNotOwned`, `InvalidHireTransition`, `SubmissionInProgress`, `ChainUnavailable` |
| `HireEndpoint` | `prepareReject` | `hireId: int`, `reason: String` | `PreparedTransaction` | Yes | `InvalidHireId`, `HireNotFound`, `HireNotOwned`, `InvalidHireTransition`, `InvalidRejectReason`, `SubmissionInProgress`, `ChainUnavailable` |
| `HireEndpoint` | `submitEscrowCall` | `hireId: int`, `preparationId: String`, `signedTransactionXdr: String` | `HireDetail` | Yes | `InvalidHireId`, `HireNotFound`, `HireNotOwned`, `InvalidHireTransition`, `PreparationNotFound`, `PreparationExpired`, `InvalidSignedEnvelope`, `EnvelopeMismatch`, `InvalidTransactionSignature`, `ChainDataUnavailable` |
| `HireEndpoint` | `getHire` | `hireId: int`, `consumer: String` | `HireDetail` | Yes | `InvalidHireId`, `InvalidStellarAddress`, `WalletMismatch`, `HireNotFound`, `HireNotOwned`, `ChainDataUnavailable` |
| `HireEndpoint` | `listHires` | `consumer: String` | `List<HireSummary>` | Yes | `InvalidStellarAddress`, `WalletMismatch`, `PersistenceUnavailable` |
| `FeedbackEndpoint` | `getFeedbackEligibility` | `hireId: int`, `client: String` | `FeedbackEligibility` | Yes | `InvalidHireId`, `InvalidStellarAddress`, `WalletMismatch`, `HireNotFound`, `HireNotOwned`, `HireNotCompleted`, `HireAlreadyRated` |
| `FeedbackEndpoint` | `prepareFeedback` | `hireId: int`, `score: int`, `comment: String` | `PreparedTransaction` | Yes | `InvalidHireId`, `HireNotFound`, `HireNotOwned`, `HireNotCompleted`, `HireAlreadyRated`, `InvalidFeedback`, `SubmissionInProgress`, `ChainUnavailable` |
| `FeedbackEndpoint` | `submitFeedback` | `hireId: int`, `preparationId: String`, `signedTransactionXdr: String` | `HireDetail` | Yes | `InvalidHireId`, `HireNotFound`, `HireNotOwned`, `HireNotCompleted`, `HireAlreadyRated`, `PreparationNotFound`, `PreparationExpired`, `InvalidSignedEnvelope`, `EnvelopeMismatch`, `InvalidTransactionSignature` |

`submitEscrowCall` accepts any client-signed escrow preparation (`createJob`, `fund`, `complete`, `reject`); the preparation's `purpose` selects the domain effect. `prepareReject` hashes `reason` (short display-safe text) into the ERC-8183 `reason` (`bytes32`) and stores the text with the hire.

**Catalog reads (#17).** `listAgents` and `getAgent` are served from the Postgres `agent_record` index, which the server syncs from the identity registry (bootstrap from registry state, then registry events after a stored per-network cursor). While the index is empty the server falls back to reading the registry directly, so `AgentCatalogUnavailable` no longer fires for a chain outage once the index has rows. `listAgents` returns the whole index; Flutter filters by name and skill client-side (F2-3, F2-4). Pagination and server-side search are deferred to a follow-up issue.

**Lifecycle error rule.** Hire methods report a wrong hire state with one code per family, so clients can branch on it:

- Escrow methods raise `InvalidHireTransition` with `details.status` set to the current status when the hire is not in the state the call needs: `prepareCreateJob` needs a hire with no status yet (`details.status` is `null`: only a pending preparation exists, see [hire escrow states](#hire-escrow-states)) or `createJob` `failed`; `prepareFund` needs `open`; `prepareComplete` needs `submitted`; `prepareReject` needs `open` (a cancel before paying), `funded`, or `submitted` before `approvalDeadline`.
- Feedback methods raise `HireNotCompleted` when the hire is not `completed`, and `HireAlreadyRated` when the hire already has a `feedbackReference`. `HireAlreadyRated` is the only "already rated" code, synchronous or asynchronous.

### Agent catalog

`AgentEndpoint` (#88) is registered as `agent`, so Flutter calls `client.agent.list()` and `client.agent.get(id)`. Both are public (no `requireLogin`) and read the Identity Registry through a cache with a 60-second TTL.

- **Two identifiers.** [`AgentSummary`](models/agent_summary.spy.yaml) carries `id: String`, the metadata id (for example `agt-001`), and `registryId: int`, the on-chain Identity Registry agent id (`u32`, the domain `AgentId`). `get` takes the metadata `id`. `HireEndpoint.createHire(agentId, …)`, `Hire.agentId`, and the escrow use the on-chain id, so the app passes `AgentSummary.registryId` as `agentId`. When orphaned registrations repeat a metadata id, the catalog serves only the newest one (highest `registryId`).
- **Ordering and skipping.** `list` returns every agent with valid metadata, ordered by `registryId`. An agent whose required metadata (`id`, `name`, `description`, `skills`, `priceUsdcStroops`) is missing or invalid is skipped, not reported as an error.
- **Outage.** Reads are served from the `agent_record` index, so a chain outage does not affect them while the index has rows. Only when the index is empty and the chain cannot be read do `list` and `get` raise [`AgentCatalogUnavailable`](models/agent_catalog_unavailable.spy.yaml) (`message: String`). An outage is never reported as an empty list or `null`.
- **Typed exception, not `Puls3ApiException`.** The catalog is the one exception to contract rule 7: it raises the typed Serverpod exception `AgentCatalogUnavailable`, not a `Puls3ApiException` code. An unknown metadata id is `null`, not `AgentNotFound`. The catalog codes `CatalogUnavailable`, `InvalidAgentId`, `AgentNotFound`, and `ChainDataUnavailable` are not raised by the catalog; `InvalidAgentId` and `AgentNotFound` remain in use by `createHire`.
- **Field names.** `AgentSummary` uses `priceUsdcStroops` (USDC stroops, at most 2^53 − 1) for the domain `price`, and `skills` holds kebab-case skill ids only (1 to 5, in stored order).

**Planned fields (not served in the MVP).** The earlier draft's `AgentSummary { agent: Agent, … }` and `AgentDetail` are not implemented. These fields stay planned:

| Field | Earlier shape | Target issue |
|---|---|---|
| `rating`, `paidHireCount` | `AgentSummary`, `AgentDetail` | #21 (reputation in catalog) |
| `active` | `AgentSummary`, `AgentDetail` | #18 (register flow activates the agent) |
| `owner` | [`Agent`](models/agent.spy.yaml) | #17 (catalog with on-chain indexing) |
| Structured skills (`name`, `description`, `tags`) | [`Skill`](models/skill.spy.yaml) | #35 (manifest from Agent Studio) |
| `registrationUri`, `explorerUrl`, `chainDataFresh` | `AgentDetail` | #17 |
| Hire input limit (`inputMaxChars`) | Read by F5-1 from the agent detail | #35 |

### Asynchronous outcome codes

Once a `submit…` call has accepted a submission, every later outcome is data: `ChainSubmission.state = failed` with `errorCode` set, read through the polling method of the resource. The `submit…` call itself never throws for chain outcomes. Every value comes from the same code catalog as `Puls3ApiException.code`.

| Submission `purpose` | Read through | Possible `errorCode` values |
|---|---|---|
| `registerFull` | `StudioEndpoint.getDeploySession` (`DeploySession.registration`) | `TransactionFailed`, `RegistrationUriConflict`, `SubmissionRejected`, `PreparationExpired` |
| `setAgentWallet` | `StudioEndpoint.getDeploySession` (`DeploySession.walletAuthorization`) | `TransactionFailed`, `SubmissionRejected`, `AuthorizationExpired` |
| `createJob`, `complete`, `reject` | `HireEndpoint.getHire` (`HireDetail.escrowSubmission`) | `TransactionFailed`, `SubmissionRejected`, `PreparationExpired` |
| `fund` | `HireEndpoint.getHire` (`HireDetail.escrowSubmission`) | `TransactionFailed`, `JobMismatch`, `JobEvidenceUnavailable`, `SubmissionRejected`, `PreparationExpired` |
| `submit`, `release`, `claimRefund` (server-signed) | `HireEndpoint.getHire` (`HireDetail.escrowSubmission`) | `EscrowCallFailed` |
| `giveFeedback` | `HireEndpoint.getHire` (`HireDetail.feedbackSubmission`) | `TransactionFailed`, `HireAlreadyRated`, `SubmissionRejected`, `PreparationExpired` |

A superseded preparation is rejected synchronously by the `submit…` call as `PreparationExpired` (`details.reason: superseded`). It never becomes an asynchronous outcome, because a new preparation cannot be issued while a submission is `submitted`.

Agent runtime failures after funding are not submission outcomes: they set `Hire.runtimeStatus = failed` and `Hire.failureReason`, and the hire stays `funded` until the client rejects it or the job expires (see [hire escrow states](#hire-escrow-states)). Deploy-step failures that are not chain outcomes, such as publication, are reported in `DeploySession.failureCode` (see [Deploy session](#deploy-session)).

### Server relay submission

This applies to F4-6 (`register_full`), F4-7 (`set_agent_wallet`), F5-4 (escrow `create_job` and `fund`), the evaluator's `complete` and `reject`, and F7-4 (`give_feedback`).

1. **Prepare.** A `prepare…` method (or `createHire` for the first `create_job`) builds the unsigned envelope or authorization entry, simulates it, and returns a `PreparedTransaction` bound to the session wallet (`signer`), the network passphrase, and an expiry. When the chain cannot be read or the simulation fails (for example `prepareFund` when the wallet has no USDC balance), the call raises `ChainUnavailable` with `details.reason = simulationFailed`.
   - For transaction envelopes the session wallet is the transaction source, so its envelope signature is the only user signature needed. `transaction` is the envelope hash, fixed at preparation.
   - For `setAgentWallet` the server also fixes, at preparation, the whole `set_agent_wallet` envelope around the entry: agent account as source, sequence number, fee, and time bounds that end no later than `signatureExpirationLedger`. Only the builder's entry signature is missing, so the final hash is determined by the prepared envelope plus that signature.
2. **Sign (client).** The wallet adapter signs the prepared XDR unchanged. The app sends the signed XDR, with the `preparationId`, to the matching `submit…` method.
3. **Verify.** The server rejects the submission synchronously unless it is exactly what it prepared:
   - `PreparationNotFound`: unknown `preparationId`, or it belongs to another resource or wallet.
   - `PreparationExpired`: the preparation can no longer be used (`details.reason`: `timeBounds` when the envelope time bounds have passed, or `superseded` when a newer preparation replaced it). This applies to every purpose, including `setAgentWallet`.
   - `InvalidSignedEnvelope`: the XDR is empty, not base64, truncated, has trailing bytes, or is a fee-bump envelope.
   - `EnvelopeMismatch`: the transaction body differs in any byte from the prepared body. `details.field` names the first differing group: `contract`, `function`, `arguments`, `source`, `timeBounds`, or `other` (fee, sequence number, Soroban data, memo, or envelope type).
   - `InvalidTransactionSignature`: no signature from the session wallet, or a signature that does not verify over the transaction hash for the configured network (`details.reason`: `missing`, `wrongSigner`, or `doesNotVerify`).
   - For authorization entries, `InvalidAuthorizationEntry` replaces the three envelope checks, and `AuthorizationExpired` covers ledger expiry (see F4-7 below).
4. **Persist, then submit.** Only after verification, the server stores the final signed envelope and its hash as a `ChainSubmission` with `state = submitted`, and then calls RPC `sendTransaction`. For `setAgentWallet` the final envelope is the prepared envelope with the verified entry inserted and the server's agent-account signature added.
   - A definitive RPC rejection (for example a bad sequence number or insufficient fee) sets the record to `failed` with `errorCode = SubmissionRejected` and a safe reason logged server-side. The `submit…` call returns the resource with that record; it does not throw. The client may then re-prepare.
   - If RPC cannot be reached or times out, the record stays `submitted` and the call returns the resource with it. The tracker resends. The client does not re-prepare: `prepare…` methods raise `SubmissionInProgress` until the record is final.
5. **Track durably.** A server-side tracker polls RPC `getTransaction` for every `submitted` record, resending the same persisted envelope when needed, until the transaction is final or its time bounds pass (`failed` with `PreparationExpired`, or `AuthorizationExpired` for `setAgentWallet`). It then applies the domain effect (record `agentId`, record the job id, `Hire.fund`, `Hire.complete`, `Hire.reject`, record the feedback reference) and sets `confirmed`, or sets `failed` with an outcome code.
6. **Idempotency.**
   - Each preparation has at most one `ChainSubmission`. A `submit…` call for a preparation that already has one re-runs the verification of step 3 and then returns the resource with the existing record. It never builds, signs, or sends a new envelope, for any purpose.
   - The persisted envelope is the only one the tracker ever sends, so a record has exactly one hash.
   - While a resource has a `submitted` record, `prepare…` methods raise `SubmissionInProgress`. A hire has at most one escrow submission in flight, client- or server-signed.
   - A new preparation for the same resource supersedes the previous one and reuses the signer's current sequence number, so at most one of them can be included on chain.
   - `HireEndpoint.prepareFund` raises `PaymentAlreadySubmitted` when an earlier `fund` for the hire reached `SUCCESS` on chain, even if verification then failed. A new funding is never prepared once funds may have moved.

Server-side envelope handling through `stellar_dart` is proven: the #96 spike passed with stellar_dart 2.3.0 (decode and byte-identical re-encode, network transaction hash, and ed25519 signature verification; tests in `puls3_server/test/spike`). The fallback, if it is ever needed, is pure Dart: `package:crypto` + ed25519 with hand-written XDR behind the same `LedgerPort` adapter. This is not a contract change.

### Server-signed escrow calls

The server submits three escrow calls itself, tracked like relay submissions on `HireDetail.escrowSubmission`:

| Purpose | Signer | Trigger |
|---|---|---|
| `submit` | Agent account (provider), custodied key | When the runtime delivers; carries the hash of the result |
| `release` | Relay account (permissionless) | When a `submitted` job passes `approval_deadline` without an evaluation; the hire becomes `completed` |
| `claimRefund` | Relay account (permissionless) | When a `funded` job passes `expired_at` (runtime-failure fallback, ADR-0005 D1) |

A failed attempt is retried automatically with a bounded number of attempts; the exposed record is the current attempt. When the attempts are exhausted, the record is `failed` with `errorCode = EscrowCallFailed`. These calls are never triggered by a read.

**Approval invariant (ADR-0005 D4).** The escrow guarantees that a `submitted` job is auto-approved before it can expire, so `claim_refund` only refunds jobs the agent never submitted. `submit` sets the job's `approval_deadline` (submission time plus the approval window) and fails unless it ends before `expired_at`. Once it passes, `reject` is refused and anyone can call `release` to pay the provider; `claim_refund` never applies to `Submitted`. `HireDetail.approvalDeadline` exposes the deadline for the countdown; the window length is deferred (D3).

### Deploy session

`DeploySession.state` is one of:

| State | Meaning | Client action |
|---|---|---|
| `awaitingRegistrationSignature` | `preparation` holds the `register_full` envelope | Sign it and call `submitRegistration` |
| `registrationSubmitted` | `registration` is `submitted` | Poll `getDeploySession` |
| `awaitingWalletAuthorization` | Registration confirmed (or resumed at F4-5); `agentId` is set | Call `prepareWalletAuthorization`, sign `preparation.authorizationEntryXdr`, call `submitWalletAuthorization` |
| `walletAuthorizationSubmitted` | `walletAuthorization` is `submitted` | Poll `getDeploySession` |
| `publishing` | `set_agent_wallet` confirmed; the server publishes the registration file and activates the agent | Poll `getDeploySession` |
| `active` | Deploy finished; `result` is set | Stop; open the agent |
| `failed` | A step failed; `failureCode` and `retryFromStep` are set | Stop; offer **Retry** as below |

`failed` is not terminal: the builder can retry. `failureCode` holds the `errorCode` of the failed `ChainSubmission`, or `PublicationFailed` when publication failed after `set_agent_wallet` was confirmed. A confirmed chain submission is never marked failed because of a later step.

| `retryFromStep` | Set after | Retry call |
|---|---|---|
| `5` | `RegistrationUriConflict` | `prepareDeploy`: re-checks `agent_id_by_uri`, then resumes or rotates the URI |
| `6` | `register_full` failed (`TransactionFailed`, `SubmissionRejected`, `PreparationExpired`) | `prepareDeploy`: prepares a new `register_full` envelope |
| `7` | `set_agent_wallet` failed (`TransactionFailed`, `SubmissionRejected`, `AuthorizationExpired`) | `prepareWalletAuthorization`; the agent stays registered |
| `8` | `PublicationFailed` | `prepareDeploy`: re-runs publication and activation; no signature needed |

`prepareDeploy` is the single idempotent resume entry: for any draft it returns the current session and, when the session is `failed` at step 5, 6, or 8, performs that retry. Agent wallet creation (F4-4) is synchronous inside `prepareDeploy`; its failure raises `AgentWalletCreationFailed` and the same call is retried.

### Hire escrow states

**Two client signatures.** `create_job` and `fund` are separate ERC-8183 calls, and a Soroban transaction carries one contract invocation, so the consumer signs twice: `create_job`, then `fund`, with no server step between them. `create_job` already carries the token (USDC SAC) and the budget (`Hire.price`). A combined call would be a non-standard addition (ADR-0005 D1 conformance rule), and two calls keep the on-chain `Open` state that a pre-payment cancel rejects from (D6). The server sets `expired_at` from configuration when it prepares `create_job` (value deferred, D3).

Progress is read from `hire.status`, `hire.runtimeStatus`, and `HireDetail.escrowSubmission` (the hire's latest escrow submission, any purpose):

| `hire.status` | `escrowSubmission` | Meaning | Available calls |
|---|---|---|---|
| none (`null`) | none, or `createJob` `failed` | No job on chain yet: only a pending preparation | `prepareCreateJob`, `submitEscrowCall`. Cancel = abandon the preparation; no transaction |
| none (`null`) | `createJob` `submitted` | Job being created | Poll `getHire` |
| `open` | `createJob` `confirmed`, or `fund` `failed` with `SubmissionRejected`, `PreparationExpired` or `TransactionFailed` | Job created and priced; unfunded | `prepareFund`, `prepareReject` (cancel), `submitEscrowCall` |
| `open` | `fund` `submitted` | Funding in flight | Poll `getHire`. `prepare…` methods raise `SubmissionInProgress` |
| `open` | `fund` `failed` with `JobMismatch` or `JobEvidenceUnavailable` | The transaction succeeded but the job does not match this hire; funds stay in the escrow | None. `prepareFund` raises `PaymentAlreadySubmitted`. Refund through `claim_refund` after `expired_at` |
| `funded` | `fund` `confirmed` | Funds held by the escrow; the agent works (`runtimeStatus` `queued` or `running`). A finished run reads `running` with `result` set until its `submit` lands | Poll `getHire` |
| `funded` | — | `runtimeStatus` is `failed` | `prepareReject` (one-step reject and refund). Fallback: the tracker calls `claim_refund` after `expired_at` |
| `submitted` | `submit` `confirmed` | Delivered; awaiting the client's evaluation; `result` and `approvalDeadline` are set | Before `approvalDeadline`: `prepareComplete`, `prepareReject`. After it: `prepareComplete` until the tracker's `release` lands; poll `getHire` |
| `expired` (derived) | — | Unfunded job past `expired_at`: on chain it stays `Open`, but `fund` reverts and there is nothing to refund | None. No transaction |
| `completed`, `rejected`, `expired` | final | Terminal. `rejected` carries `rejectedFrom`; the app labels a reject from `open` as "Cancelled" | Feedback, when `completed` |

**Rejection.** `prepareReject` is the client's ERC-8183 `reject` as evaluator, signed and relayed like any client call. From `open` it is the pre-payment cancel; from `funded` it refunds a failed run; from `submitted`, only before `approvalDeadline`, it refunds delivered work, and only these rejects count toward client-side reputation (D8). A reject is final: there are no disputes in the MVP (D8). Preparing a reject supersedes any outstanding `createJob` or `fund` preparation.

**Before and after the open window** (product owner, 2026-10-02):

- **No job, no state.** A hire has a status only once `create_job` is confirmed; until then `status` is `null` and the record is a pending preparation. Cancelling it means abandoning the preparation: no on-chain `reject`, no new state.
- **Unfunded expiry is derived.** An `open` hire past `expired_at` is reported as `expired` with no transaction: ERC-8183 `fund` reverts after expiry and `claim_refund` applies only to `Funded`, so the job stays `Open` on chain with no funds held. This is the one derived exception to the 1:1 mirror (ADR-0005 D6). The escrow's `is_expired(job_id)` view reports the same result, and the server uses it.

**Residual risk.** A signed `fund` envelope that the user broadcasts outside the relay before its time bounds pass can still land after a supersession or reject. The funds are then held by the escrow and return through `claim_refund` after `expired_at`; only funds sent outside the escrow fall under open question P1.

### Wallet session lifecycle

1. `client.walletAuth.createChallenge` returns a one-use SEP-10 challenge bound to the wallet and the configured network. `expiresAt` is 900 seconds (15 minutes) after issuance.
2. The wallet signs that challenge transaction. `verifyChallenge(challengeId, wallet, signedChallengeXdr)` checks the signed envelope, consumes the challenge atomically, and returns Serverpod `AuthSuccess` access and refresh credentials bound to that wallet. The web client learns the expected signer and domains from `config.json` `auth`: `serverSigningKey` (the public `G…` address), `homeDomain`, `webAuthDomain` and `networkPassphrase`. That payload never carries the `S…` secret.
3. Protected endpoints load the wallet from the session. They never trust a caller-supplied wallet address without comparing it to the session wallet. Relay submissions must be signed by that same wallet.
4. The standard Serverpod JWT refresh path renews an expired access token. If the refresh token is expired, revoked, or invalid, Flutter discards the session and repeats the wallet challenge before resuming the pending action.

No password, email, or wallet secret is stored or transmitted by this flow.

### Client-only wallet outcomes

The wallet adapter rejects some requests **before the wallet prompt**, with no endpoint call (spike #68). They are `WalletFailure` variants in Flutter, not `Puls3ApiException` codes.

| Wallet outcome | Meaning | Client action |
|---|---|---|
| `WalletUnavailable` | No supported wallet extension | Show the install link (F1-2) |
| `WalletRejected` | The user declined the prompt | Stay on the step; the prepared XDR can be signed again until it expires |
| `WrongNetwork` | The wallet is not on the configured network | Ask the user to switch (F1-4) |
| `WalletAccountChanged` | The active wallet account differs from the session | Reconnect (F1) |
| `PayloadAccountMismatch` | The prepared transaction or entry is not for the connected account | Reconnect, then re-prepare |
| `InvalidEnvelope`, `ModifiedEnvelope` | Malformed prepared XDR, or the wallet returned a changed envelope | Re-prepare |
| `UnsupportedAuthCredentials` | The entry uses `ADDRESS_WITH_DELEGATES` | Re-prepare; the server never prepares this arm |

### Typed error transport

[`puls3_api_exception.spy.yaml`](models/puls3_api_exception.spy.yaml) declares the Serverpod serializable exception used by every endpoint above, and lists the full code catalog below.

- `code` is required, stable, and machine-readable. It is one of the values in the catalog.
- `message` is optional safe display text. Clients must branch on `code`, never parse `message`.
- `details` is an optional map of safe structured values, such as `field`, `reason`, `status`, `retryAfterSeconds`, or `expectedNetwork`. It must never contain secrets, raw provider errors, stack traces, signed payloads, or private prompts.

Unexpected failures are logged server-side and cross the boundary only as `InternalError` with no sensitive details.

| Group | Codes |
|---|---|
| Session and shared | `WalletMismatch`, `InternalError` |
| Authentication | `InvalidStellarAddress`, `ChallengeRateLimited`, `ChallengeNotFound`, `ChallengeExpired`, `ChallengeConsumed`, `InvalidWalletSignature`, `AuthenticationUnavailable` |
| Configuration and catalog | `ConfigurationUnavailable`, `CatalogUnavailable`, `InvalidAgentId`, `AgentNotFound`, `ChainDataUnavailable` |
| Studio and deploy | `InvalidManifest`, `DraftNotFound`, `DraftNotOwned`, `DraftVersionConflict`, `InputTooLong`, `TestQuotaExceeded`, `RuntimeUnavailable`, `AgentExecutionFailed`, `AgentWalletCreationFailed`, `AgentWalletUnavailable`, `RegistrationNotConfirmed`, `RegistrationUriConflict`, `InvalidAuthorizationEntry`, `AuthorizationExpired`, `PublicationFailed` |
| Relay and chain | `PreparationNotFound`, `PreparationExpired`, `InvalidSignedEnvelope`, `EnvelopeMismatch`, `InvalidTransactionSignature`, `SubmissionRejected`, `SubmissionInProgress`, `TransactionFailed`, `ChainUnavailable` |
| Hire and escrow | `InvalidHireId`, `HireNotFound`, `HireNotOwned`, `AgentInactive`, `InvalidHire`, `InvalidHireTransition`, `IdempotencyKeyReused`, `PersistenceUnavailable`, `PaymentAlreadySubmitted`, `InvalidRejectReason`, `JobMismatch`, `JobEvidenceUnavailable`, `EscrowCallFailed` |
| Feedback | `HireNotCompleted`, `HireAlreadyRated`, `InvalidFeedback` |

`AgentEndpoint` does not use these error codes yet: it raises the typed `AgentCatalogUnavailable` and returns `null` for an unknown id, so `CatalogUnavailable` and `ChainDataUnavailable` are currently unused (see [Agent catalog](#agent-catalog)).

### Funding verification

The escrow contract enforces an allow-listed token and the amount (`fund`'s `expected_budget`), so the tracker no longer checks a SAC transfer to the agent's muxed address. After a `fund` transaction is final it reads the job from the configured escrow contract:

| Evidence | Check | Outcome code on failure |
|---|---|---|
| `getTransaction` status | `SUCCESS` | `TransactionFailed` |
| Job state and funding event | Readable for the hire's job id | `JobEvidenceUnavailable` |
| Job fields | State `Funded`; client and evaluator = `Hire.consumer` (the escrow rejects evaluator = provider with `EvaluatorIsProvider`); provider = agent wallet; token = USDC SAC; budget = `Hire.price`; `expired_at` as prepared; job id bound to no other hire | `JobMismatch` (`details.field`) |

`JobEvidenceUnavailable` is terminal, not the transient `ChainUnavailable`. Only after every check passes does the server build the domain `Payment` (the `fund` transaction, `payer` = consumer, `payee` = agent wallet, `amount` = budget) and call `Hire.fund`. The platform fee (ADR-0005 D7) is snapshotted at `fund` (capped by the contract at `MAX_FEE_BPS` = 1000) and charged by the contract only on settlement (`complete` or `release`), never on a refund; its value is exposed as `NetworkConfig.platformFeeBps` and is `0` in the MVP.

### Feedback

ADR-0005 D5 removes the server's `authorize_feedback` step: the Reputation Registry is a Stellar 8004 drop-in (#14), and the paid-hire rule is proven by a completed escrow job, not by the registry.

- **Eligibility.** The client of a `completed` hire, with no `feedbackReference` yet. `getFeedbackEligibility` reads this from the hire without side effects.
- **Outcome.** When `give_feedback` is confirmed, the tracker stores its reference in `Hire.feedbackReference`. The hire status does not change.
- **Reputation reads.** Readers count feedback only from clients with completed jobs (D5). Client-side reputation, from rejects made from `submitted` (D8), is derived from job history and is not exposed by this contract.
- The `give_feedback` arguments follow the #14 drop-in interface, not yet fixed.

### Response shapes not copied from the domain

The core `Agent`, `Skill`, `Hire`, `Payment`, and `Feedback` drafts mirror domain entities; `Agent` and `Skill` are planned and not served in the MVP (see [Agent catalog](#agent-catalog)). [`AgentSummary`](models/agent_summary.spy.yaml) and [`AgentCatalogUnavailable`](models/agent_catalog_unavailable.spy.yaml) copy the models of #88 exactly. `PreparedTransaction` and `ChainSubmission` have draft models because every relay flow shares them. Other endpoint-specific projections add only transport and orchestration data:

| Type | Required fields |
|---|---|
| `WalletChallenge` | `challengeId`, `wallet`, `payload` (the challenge transaction XDR), `networkPassphrase`, `expiresAt` (900 seconds after issuance) |
| `NetworkConfig` | `network`, `rpcUrl`, `networkPassphrase`, `usdcContractId`, `escrowContractId`, `platformFeeBps`, `identityRegistryContractId`, `reputationRegistryContractId`, `explorerBaseUrl` |
| [`AgentSummary`](models/agent_summary.spy.yaml) | `id: String`, `registryId: int`, `name: String`, `description: String`, `skills: List<String>`, `priceUsdcStroops: int`, `wallet: String?`, `model: String?` |
| `AgentManifestDraft` | ADR-0004 fields without `version` (a draft has none; the deployed `AgentManifest` gets it): `name`, `description`, `skills`, `model: ModelId`, `systemPrompt`, `inputType`, `inputMaxChars`, `outputType`, `outputMaxChars`, `price`. `DraftVersionConflict` is a storage concern (`StudioDraft.revision`), not a manifest field |

**Manifest wire mapping.** Dart fields are flat camelCase; the JSON (the hash input) is nested snake_case: `systemPrompt` ↔ `system_prompt`, `inputType` and `inputMaxChars` ↔ `input.type` and `input.max_chars`, `outputType` and `outputMaxChars` ↔ `output.type` and `output.max_chars`, `price` (`UsdcAmount`) ↔ `price: {asset: "USDC", amount: stroops}`, `model` ↔ `model: {provider, id}`. A deployed manifest adds `schema` and `version`. `fromJson` reports every mismatch as an `InvalidManifest` problem and never throws a type error. See [domain model](../domain/model.md).
| `StudioDraft` | `draftId`, `manifest`, `revision`, `deployState` |
| `TestRunResult` | `output`, `remainingDailyRuns` |
| [`PreparedTransaction`](models/prepared_transaction.spy.yaml) | `preparationId`, `purpose`, `signer`, `networkPassphrase`, `unsignedTransactionXdr?`, `authorizationEntryXdr?`, `transaction?`, `signatureExpirationLedger?`, `expiresAt` |
| [`ChainSubmission`](models/chain_submission.spy.yaml) | `preparationId?`, `purpose`, `transaction`, `state` (`submitted`, `confirmed`, `failed`), `errorCode?`, `explorerUrl?`, `updatedAt` |
| `DeploySession` | `draftId`, `state`, `preparation: PreparedTransaction?`, `registration: ChainSubmission?`, `walletAuthorization: ChainSubmission?`, `agentId?`, `failureCode?`, `retryFromStep?`, `result: DeployResult?` |
| `DeployResult` | `agent: Agent`, `registrationUri`, `explorerUrl` |
| `CreateHireResult` | `hire: Hire`, `preparedCreateJob: PreparedTransaction?` |
| `HireSummary` | `hire: Hire`, `agentName` |
| `HireDetail` | `hire: Hire`, `agent: AgentSummary` (the catalog entry whose `registryId` is `hire.agentId`), `input`, `result?`, `payment?`, `jobId?`, `expiresAt?` (the job's `expired_at`), `approvalDeadline?` (the job's `approval_deadline`, set once the job is submitted), `rejectReason?`, `escrowSubmission: ChainSubmission?`, `feedbackSubmission: ChainSubmission?`, `paymentExplorerUrl?` |
| `FeedbackEligibility` | `hireId`, `eligible: bool` |

**`getHire` as served today (#20).** `hire.runtimeStatus` and `hire.failureReason` are set only while `hire.status` is `funded`; later states come from the escrow. `result` is the agent run's output, returned as soon as the run succeeds, so it can be set while the hire is still `funded`, before `submit` (#97) lands. `payment`, `paymentExplorerUrl`, `approvalDeadline`, `rejectReason` and `feedbackSubmission` are not set yet; the `fund` transaction is `hire.paymentTransaction`, and its link is `escrowSubmission.explorerUrl` while that submission's purpose is `fund`.

`PreparedTransaction.purpose` is one of `registerFull`, `setAgentWallet`, `createJob`, `fund`, `complete`, `reject`, `giveFeedback`. `ChainSubmission.purpose` is one of those or `submit`, `release`, `claimRefund` (server-signed, never prepared for a wallet, so `preparationId` is null).

**`createHire` idempotency.** `requestId` is a client-generated UUID, created once per **Confirm and pay** action and reused on every retry of it. The server keeps it unique per session wallet for the life of the hire:

- The same `requestId` with the same `agentId` and `input` returns the existing hire. Its `preparedCreateJob` is the current unexpired preparation, or a fresh one when the previous one expired unused. It is null once a `create_job` is `submitted` or confirmed.
- The same `requestId` with a different `agentId` or `input` raises `IdempotencyKeyReused`.
- No hire is persisted when the first preparation fails, so a retry after `ChainUnavailable` creates it then.

These projections are implementation drafts. Before `serverpod generate`, the owning endpoint issue must add the remaining `.spy.yaml` files without renaming any domain fields.

### Polling contract

Any exception raised by a polled method stops polling; the client handles its code.

| What is tracked | Poll | Keep polling while | Stop when |
|---|---|---|---|
| Deploy (F4-6 to F4-8) | `StudioEndpoint.getDeploySession(draftId)` | `state` is `registrationSubmitted`, `walletAuthorizationSubmitted`, or `publishing` | `state` is `awaitingRegistrationSignature` or `awaitingWalletAuthorization` (user action needed), `active`, or `failed` |
| Escrow call (F5-4 to F5-6, evaluation, refund) | `HireEndpoint.getHire(hireId, consumer)` | `escrowSubmission.state` is `submitted` | `escrowSubmission.state` is `confirmed` with no server call pending, or `failed` |
| Hire progress (F6-3) | `HireEndpoint.getHire(hireId, consumer)` | `hire.status` is `funded` and `runtimeStatus` is `queued` or `running` | `hire.status` is `submitted`, `completed`, `rejected`, or `expired`; or `runtimeStatus` is `failed` (offer reject and refund) |
| Feedback confirmation (F7-5) | `HireEndpoint.getHire(hireId, consumer)` | `feedbackSubmission.state` is `submitted` | `feedbackSubmission.state` is `confirmed` or `failed` |

Clients poll every 2 seconds while a screen shows the tracked state, back off to 10 seconds after 30 seconds, and stop when the screen closes. Server-side tracking never depends on a client polling.

## Flow traceability

Every numbered row in [the merged MVP flows](../blueprints/flows.md) appears once below. “Client-only” means no puls3 endpoint call; direct wallet interaction is named explicitly. Wallet pre-prompt rejections in any signing step are client-only outcomes (see [Client-only wallet outcomes](#client-only-wallet-outcomes)). The flows doc is being updated to ADR-0005 in #76; F5–F7 below already follow ADR-0005.

### F1 — Connect wallet

| Step | API mapping |
|---|---|
| F1-1 | Client-only: open the wallet picker. |
| F1-2 | Client detects the selected wallet extension and requests connection (`WalletUnavailable` is client-only). After an installed wallet returns its address, call `client.walletAuth.createChallenge(wallet)`. |
| F1-3 | After connection approval, the wallet signs the challenge transaction and `verifyChallenge(challengeId, wallet, signedChallengeXdr)` establishes the wallet-bound Serverpod session; rejection (`WalletRejected`) cancels connection and no private key reaches Serverpod. |
| F1-4 | `ConfigEndpoint.getNetworkConfig`; Flutter compares the wallet network. `WrongNetwork` is a client-only outcome: ask for a switch. |
| F1-5 | Client shows the authenticated wallet address and resumes the pending action. If the session cannot refresh, repeat F1-2/F1-3 before resuming. |

### F2 — Discover agents

| Step | API mapping |
|---|---|
| F2-1 | Client-only: navigate to `/market`. |
| F2-2 | `AgentEndpoint.list`. `AgentCatalogUnavailable` shows the catalog error state. |
| F2-3 | Client-only: filter the returned catalog by name and description. |
| F2-4 | Client-only: filter the returned catalog by skill ids and render the empty state. |
| F2-5 | Client-only: navigate to F3 with the selected agent's metadata `id`. |

### F3 — View agent detail

| Step | API mapping |
|---|---|
| F3-1 | `AgentEndpoint.get(id)`; `null` shows the not-found state. |
| F3-2 | `AgentEndpoint.get`; reads come from the index (no chain while it has rows), and `AgentCatalogUnavailable` is raised only when the index is empty and the chain cannot be read. The cached-data warning needs `chainDataFresh`, deferred (not served yet). |
| F3-3 | Client-only: open the agent's explorer link. Planned: `explorerUrl` is not served yet (#17). |
| F3-4 | Client-only: open F5 with `registryId` as the hire's `agentId`. Planned: `active` is not served yet (#18), so Hire is not hidden by the catalog. |

### F4 — Create and register an agent

| Step | API mapping |
|---|---|
| F4-1 | Client validation mirrors ADR-0004; `StudioEndpoint.saveDraft` performs authoritative validation. |
| F4-2 | `StudioEndpoint.testRun(draftId, input)`. |
| F4-3 | Client-only navigation; if needed, run F1 before continuing. |
| F4-4 | `StudioEndpoint.prepareDeploy(draftId, builder)` stores the immutable version and hash and creates the agent wallet. `AgentWalletCreationFailed`: retry the same call. |
| F4-5 | `StudioEndpoint.prepareDeploy` idempotently checks `agent_id_by_uri`: it resumes an owned registration (`awaitingWalletAuthorization`), or rotates a conflicting URI and prepares `register_full` for the new one. |
| F4-6 | `prepareDeploy` returns `awaitingRegistrationSignature` with the unsigned `register_full` envelope (builder as source) in `preparation`. The wallet signs it; `StudioEndpoint.submitRegistration(draftId, preparationId, signedTransactionXdr)` verifies and submits it. Poll `StudioEndpoint.getDeploySession`; the server records `agentId` from the `Registered` event. A failed registration sets `failed` with `retryFromStep` 5 (`RegistrationUriConflict`) or 6. |
| F4-7 | `StudioEndpoint.prepareWalletAuthorization(draftId)` returns `preparation.authorizationEntryXdr`: a simulated `ADDRESS_V2` `SorobanAuthorizationEntry` for the builder's wallet, with a server-set non-zero `signatureExpirationLedger` (spike #68, #8 recommendation 1). The server also fixes the surrounding `set_agent_wallet` envelope at this point. The wallet signs the entry with `signAuthEntry`. `StudioEndpoint.submitWalletAuthorization` re-verifies it, inserts it into the prepared envelope, signs that envelope with the custodied agent key, persists it and its hash, and submits. Poll `getDeploySession`. `AuthorizationExpired` (synchronous or asynchronous) means call `prepareWalletAuthorization` again; the agent stays registered (`retryFromStep` 7). |
| F4-8 | After `set_agent_wallet` is confirmed, the state is `publishing`: the server publishes the registration file and activates the agent. `getDeploySession` returns `active` with `result: DeployResult`, and the client opens the agent or explorer URL. `PublicationFailed` sets `failed` with `retryFromStep` 8; retry with `prepareDeploy`. |

`InvalidAuthorizationEntry` covers the spike's #8 recommendation 2: malformed XDR; a credential type other than the prepared `ADDRESS_V2`; an address other than the session wallet; a network, contract, function, arguments, nonce, or `signatureExpirationLedger` that differs from the prepared entry; or a signature that does not verify over the `ENVELOPE_TYPE_SOROBAN_AUTHORIZATION_WITH_ADDRESS` preimage. Expiry is the separate `AuthorizationExpired`, raised when the current ledger is past `signatureExpirationLedger`, so Flutter re-prepares instead of failing. A superseded entry preparation raises `PreparationExpired` (`details.reason: superseded`).

### F5 — Hire and pay

| Step | API mapping |
|---|---|
| F5-1 | Client-only input validation. Planned: the input limit is not served by `AgentSummary` yet (#35); `createHire` validates authoritatively (`InputTooLong`). |
| F5-2 | Client-only wallet balance and trustline check, before any signature: the app reads the consumer's Circle testnet USDC (`USDC:GBBD…LFLA5`, the asset of `PULS3_STELLAR_USDC_SAC`) from Horizon; run F1 if disconnected. No account, no trustline or less than `Hire.price` stops the flow with the balance shown. A failed read does not block: `prepareFund`'s simulation (`ChainUnavailable`, `simulationFailed`) stays the authoritative check. |
| F5-3 | `HireEndpoint.createHire(agentId, consumer, input, requestId)`, with `agentId` = `AgentSummary.registryId`, creates the hire record (`status: null` until `create_job` is confirmed, then `open`) and returns `preparedCreateJob`: the unsigned `create_job` envelope with the consumer as source, the agent wallet as provider, the consumer as evaluator, a server-set `expired_at`, the USDC SAC as token, and `Hire.price` as budget. **Retry** reuses the same `requestId`. |
| F5-4 | Two signatures. The wallet signs `preparedCreateJob`; `submitEscrowCall` relays it. Once `create_job` is confirmed, `prepareFund(hireId)` returns the `fund` envelope, with `expected_budget` = `Hire.price` and `max_fee_bps` = `NetworkConfig.platformFeeBps`; the wallet signs it and `submitEscrowCall` relays it. `WalletRejected` is client-only: the hire stays `open`. After `PreparationExpired` or `SubmissionRejected`, call the same `prepare…` method and sign again. |
| F5-5 | Poll `HireEndpoint.getHire`; `escrowSubmission` (`fund`, `submitted`) shows **Verifying payment…**. `JobMismatch` or `JobEvidenceUnavailable` shows "Payment does not match this hire" with the transaction link; the funds stay in the escrow and return after `expired_at`. |
| F5-6 | `hire.status: funded`; `paymentExplorerUrl` links the `fund` transaction. The server starts the agent run (`runtimeStatus: queued`). |

### F6 — Track a hire and see its result

| Step | API mapping |
|---|---|
| F6-1 | Client-only: navigate to `/hires/:id`. |
| F6-2 | `HireEndpoint.getHire(hireId, consumer)`. |
| F6-3 | Poll `HireEndpoint.getHire` (Decision B) under the hire-progress stop rule; `runtimeStatus` shows progress. On delivery the server signs `submit` with the agent key and the hire becomes `submitted`. If `runtimeStatus` is `failed`, offer **Reject and refund** (`prepareReject` from `funded`); otherwise the tracker calls `claim_refund` after `expired_at`. |
| F6-4 | `HireEndpoint.getHire`; result scrolling and copy are client-only. The client approves with `prepareComplete` or rejects with `prepareReject(hireId, reason)`, each signed and relayed through `submitEscrowCall`. Reject is available only before `approvalDeadline`; after it the tracker calls `release`. |
| F6-5 | `HireEndpoint.listHires(consumer)`; run F1 first when disconnected. |

### F7 — Rate an agent

| Step | API mapping |
|---|---|
| F7-1 | Client-only: show Rate only for a `completed` hire with no `feedbackReference`. |
| F7-2 | `FeedbackEndpoint.getFeedbackEligibility(hireId, client)` checks the paying wallet and the hire state without side effects. |
| F7-3 | Client validation mirrors the domain; `FeedbackEndpoint.prepareFeedback(hireId, score, comment)` validates authoritatively (`InvalidFeedback`) and returns the unsigned `give_feedback` envelope with the client as source. |
| F7-4 | The wallet signs the prepared envelope; `FeedbackEndpoint.submitFeedback(hireId, preparationId, signedTransactionXdr)` verifies, persists, and submits it. `WalletRejected` is client-only: stay on S10. |
| F7-5 | Poll `HireEndpoint.getHire` until `feedbackSubmission` is final. `HireAlreadyRated` shows "You already rated this hire" and returns to S06. |
| F7-6 | `feedbackSubmission.state: confirmed` and `hire.feedbackReference` is set; refresh with `AgentEndpoint.get(id)`. Planned: the rating is not served yet (#21). |

## Ownership and non-goals

- **Flutter:** wallet discovery, user signatures over server-prepared XDR, pre-prompt wallet checks, navigation, polling, optimistic display, and client-side validation.
- **Serverpod:** authorization, domain reconstruction, persistence, transaction preparation, relay verification and submission, durable chain tracking, idempotency, escrow job verification, server-signed escrow calls, background runtime work, and projections.
- **Domain:** invariants and lifecycle transitions; endpoint code must not assign hire status directly. Hire states follow ADR-0005 D6 (#73).
- **Soroban:** the escrow contract (#55, ADR-0005) and the Identity and Reputation Registries (ADR-0002 as amended by ADR-0005 D5).

This document does **not** implement endpoints, finalize database tables, fix a Soroban interface, or change the domain. It depends on the escrow interface (#55), the domain change (#73), and the ADR-0002/ADR-0003 amendment notes (#75).

## Decisions

Both decisions were made by the product owner on 2026-09-30. They resolve the two product questions of the earlier draft. ADR-0005 later changed the payment calls they name, not the decisions.

### A. Server relay submits user-signed transactions

**Decision.** For F4-6 (`register_full`), F4-7 (`set_agent_wallet`), F5-4 (SAC payment; since ADR-0005, the escrow `create_job` and `fund`, plus `complete` and `reject`), and F7-4 (`give_feedback`), the server prepares the unsigned envelope or authorization entry. The client only signs it with the wallet and sends the signed XDR to a Serverpod `submit…` method. The server verifies that the submission is exactly what it prepared, persists the transaction hash before submitting, submits, and tracks the result durably. Confirmation and verification stay server-side.

**Rationale.**
- The server-prepared, wallet-signed-unchanged path is the one the spike verified live. Client-side building is unverified.
- One component owns sequence numbers, fees, simulation, submission, and retries, so a lost client or closed tab cannot leave a transaction untracked.
- Persisting the hash before submission gives crash-safe idempotency and replay protection in the server database, which ADR-0003 already relies on.
- `set_agent_wallet` already needed the server as submitter (agent account as source, ADR-0003), so every signing flow now works the same way.

**Consequences.**
- New methods: `StudioEndpoint.submitRegistration`, `StudioEndpoint.getDeploySession`, `StudioEndpoint.submitWalletAuthorization`, `FeedbackEndpoint.getFeedbackEligibility`, `FeedbackEndpoint.submitFeedback`, and the hire escrow methods. ADR-0005 replaced the first draft's `preparePayment`, `submitPayment` and `cancelHire` with `prepareCreateJob`, `prepareFund`, `prepareComplete`, `prepareReject` and `submitEscrowCall`, and removed `retryFeedbackAuthorization`.
- Replaced methods: `confirmRegistration`, `completeDeploy`, and `confirmPayment` (their verification now runs in the server tracker). `prepareFeedback` now takes the score and comment and returns a `PreparedTransaction`.
- New codes: `PreparationNotFound`, `PreparationExpired`, `InvalidSignedEnvelope`, `EnvelopeMismatch`, `InvalidTransactionSignature`, `SubmissionRejected`, `SubmissionInProgress`, `PaymentAlreadySubmitted`, `AuthorizationExpired`.
- Removed codes, because the client no longer supplies transaction hashes or builds transactions, and pending is data: `InvalidTransactionHash`, `TransactionNotFound`, `TransactionPending`, `RegistrationMismatch`, `FeedbackAuthorizationPending`, `FeedbackDoesNotMatchHire`. ADR-0005 also removed the SAC verification codes and the feedback authorization codes.
- New shared models: `PreparedTransaction` and `ChainSubmission`.
- Not a contract change: the #96 spike proved `stellar_dart` 2.3.0 for envelope decode, hash, and signature verification (tests in `puls3_server/test/spike`). The pure-Dart fallback (`package:crypto` + ed25519 with hand-written XDR) stays behind the same `LedgerPort` adapter.

### B. Progress transport: polling for the MVP, Serverpod streaming later

**Decision.** The MVP uses polling for hire progress (F6) and for every pending state created by the relay (deploy steps, escrow calls, feedback confirmation). A Serverpod streaming transport is planned after the MVP.

**Rationale.**
- No MVP flow needs realtime delivery. Agent runs and chain confirmations take seconds, and the flows already show "Verifying…" states.
- Polling uses plain request/response endpoints, which are simpler to build, test, and debug on Flutter Web.
- Relay confirmation is already a server-side tracker writing durable state, so a read method exposes it directly.

**Consequences.**
- The polling methods, keep-polling conditions, and stop conditions are in the [polling contract](#polling-contract).
- **Compatibility rule for streaming:** streaming must be additive. A future method such as `watchHire(hireId)` or `watchDeploySession(draftId)` must emit the same response shapes (`HireDetail`, `DeploySession`, `FeedbackEligibility`), the same status, `ChainSubmission.state`, and `DeploySession.state` values, and the same `Puls3ApiException` codes as the polling methods. Polling methods stay available as the fallback and are never removed or narrowed by the streaming change.

### Remaining open questions

**Product questions.** Until they are answered, the contract applies the minimal safe behavior described.

| # | Question | Contract behavior until decided | Recommended default |
|---|---|---|---|
| P1 | What happens to funds sent outside the escrow (for example a direct transfer to an agent wallet)? Escrowed funds always return through `reject` or `claim_refund` (ADR-0005 D1). | No in-app refund or override; the app shows the transaction link. | Manual operator review off-app for the MVP |
| P2 | When does an unpaid hire stop being payable? | It is the job's `expired_at`, set by the server at `create_job` from configuration; `fund` fails after it. The value is deferred (ADR-0005 D3). | Decided with D3 |

**Unverified technical dependencies** for the owning issues:

| Item | Owner | Why it matters here |
|---|---|---|
| Escrow interface: function signatures, job id type, events, a job read method, how auto-approval and the D4 invariant are enforced | #55 | Preparation, funding verification, and `approvalDeadline` depend on it |
| RPC providers other than SDF Testnet returning contract events and state | #30 | Funding verification reads the job and its event |
| Server-side submission with `stellar_dart` | #18, #19 | Relay implementation path; spike passed (stellar_dart 2.3.0, `puls3_server/test/spike`); the pure-Dart fallback is `package:crypto` + ed25519 with hand-written XDR behind the same adapter. |
| A Freighter-signed SEP-10 challenge recorded as a vector | #136 | The server verifies the signed transaction (`signedChallengeXdr`), not `signMessage`. A manual Freighter check is still required. |
| `give_feedback` arguments in the Stellar 8004 drop-in | #14 | `prepareFeedback` builds that call |
