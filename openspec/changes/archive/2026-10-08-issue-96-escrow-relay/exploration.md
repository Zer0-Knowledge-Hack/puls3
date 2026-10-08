# Exploration: issue #96 escrow relay prepare and submit endpoints

Source of truth for the contract: `docs/architecture/api.md` (PR #77). `openspec/specs/hire-payment/spec.md` is stale where it disagrees (for example `createHire` returning `HireView`).

## Current state

Built (server-internal, no public endpoint):
- `HireService.createHire({agentId, consumer})` persists a `HireRecord` with `expiredAt`; no `requestId`/`input`, returns `HireView`.
- `HireRepository` port: `create`, `findById`, `preparedExpiry`, `recordPayment`; `hire_payment` has unique indexes on `hire_id`, `transaction_hash`, `job_id` (mapped to `HirePaymentConflict`).
- `verifyFunding` (pure) and `HireEscrowEffects.onFunded`; `onJobCreated` is a no-op marked "belongs to #96", so no job id is recorded before `fund`.
- `ChainSubmission` table, `ChainSubmissionStore` (unique `preparationId`/`transaction`, `insertSubmitted` throws `ChainSubmissionConflict`, `findByPreparation`) and `ChainSubmissionTracker` (handles `createJob` and `fund` only; `complete`/`reject` stay `submitted`).
- `SorobanRpcClient`: `simulateTransaction`, `getTransaction`, `sendTransaction`. `SorobanLedger`: registry reads, `get_job`, `agentWallet`.
- `xdr_invoke_encoder.dart`: simulation-only (no time bounds, Soroban data, auth entries or signatures; args `u32`, `u64`, `string`).

Not built:
- `HireEndpoint`; `Puls3ApiException`, `PreparedTransaction`, `CreateHireResult`, `HireDetail` exist only as docs `.spy.yaml` drafts.
- Preparation persistence, account sequence / latest ledger lookups.
- ed25519 verification, SHA-256 transaction hash, signed-envelope XDR parsing. `stellar_dart` is unproven in the server (spike #68, rec. 6).
- Wallet sessions (#25) and any `requireLogin`.

## Decisions taken from the contract
- `createHire` returns `CreateHireResult{hire, preparedCreateJob?}`; `status` is null until `create_job` is confirmed; `requestId` is unique per session wallet; a different `agentId`/`input` raises `IdempotencyKeyReused`; no hire is persisted if the first preparation fails.
- `max_fee_bps` = `NetworkConfig.platformFeeBps` (0 in the MVP).
- `EnvelopeMismatch` means the transaction body differs in any byte from the prepared body.

## Approaches considered
- Preparation state: persisted `escrow_preparation` table (chosen) vs stateless HMAC token vs columns on `hire`.
- Envelope comparison: body-bytes equality, decoding only to name `details.field` (chosen).
- Idempotency: load preparation, check ownership, supersession and time bounds, verify envelope, `findByPreparation`, `insertSubmitted` (re-read on `ChainSubmissionConflict`), then `sendTransaction`; chain outcomes never throw.
- Auth: injectable `SessionWallet` seam enforced in every method until #25.

## Risks
- Security-critical crypto without fixtures: record testnet envelopes as golden vectors.
- Simulation data, resource fee and auth entries must come from `simulateTransaction`.
- Sequence races between preparations; a signed envelope broadcast outside the relay.
- `complete`/`reject` submissions never settle until #97 handles them.
- "Only the session wallet" can only be proven against a fake until #25.
- Size: about 1,000 to 1,300 hand-written lines plus tests.
