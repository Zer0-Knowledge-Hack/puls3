# Proposal: Escrow relay prepare and submit endpoints (#96)

## Intent

Implement Decision A of `docs/architecture/api.md`: the server prepares every client-signed escrow call, the wallet signs it unchanged, and `submitEscrowCall` verifies and relays it. Today no `HireEndpoint` exists, `createHire` returns `HireView`, and `onJobCreated` records nothing, so no hire can reach the chain. `api.md` is authoritative where `openspec/specs/hire-payment/spec.md` disagrees.

## Scope

### In Scope
- Spike first: `stellar_dart` decodes a recorded signed testnet envelope, computes the network transaction hash, and verifies the ed25519 signature. On failure, fall back to `crypto` plus an ed25519 package with hand-written XDR (no TypeScript sidecar).
- `HireEndpoint`: `createHire` (returns `CreateHireResult{hire, preparedCreateJob?}`, `requestId` unique per session wallet, `IdempotencyKeyReused`), `prepareCreateJob`, `prepareFund`, `prepareComplete`, `prepareReject`, `submitEscrowCall`.
- Persisted `escrow_preparation` table with supersession and time bounds.
- Envelope builder (sequence, fee, time bounds, Soroban data and auth from `simulateTransaction`), verification (`InvalidSignedEnvelope`, `EnvelopeMismatch` = body bytes differ, `InvalidTransactionSignature`), persist-then-send. Chain outcomes never throw from submit.
- `onJobCreated` records the job id; `status` stays null until `create_job` is confirmed.
- Injectable `SessionWallet` seam (`requireLogin`) with a fake; a test proves every hire method enforces it.
- `max_fee_bps = NetworkConfig.platformFeeBps`; preparation validity window and job `expired_at` read from `PULS3_*` env with no code default.

### Out of Scope
- Tracker effects for `complete`/`reject` (#97); a test pins that they stay `submitted`.
- Real wallet sessions (#25), `getHire`/`listHires` beyond what submit returns, server-signed calls, feedback.

## Capabilities

### New Capabilities
- `escrow-relay`: preparation, envelope verification, idempotent submission, and supersession for client-signed escrow calls.

### Modified Capabilities
- `hire-payment`: `createHire` contract (`CreateHireResult`, `requestId`, `input`, null status), `createJob` tracker effect, session-wallet enforcement, `complete`/`reject` settlement depends on #97.

## Approach

Hexagonal: domain rules in `hire/`, ports for preparation store, account sequence/latest ledger, and envelope codec; adapters wrap `stellar_dart` and Serverpod. Submit order: load preparation, check ownership, supersession and time bounds, verify envelope, `findByPreparation`, `insertSubmitted` (re-read on `ChainSubmissionConflict`), `sendTransaction`. Recorded testnet envelopes are golden vectors. Strict TDD.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `puls3_server/lib/src/hire/` | Modified | `createHire`, prepare/submit services, `onJobCreated` |
| `puls3_server/lib/src/chain/` | New/Modified | Envelope codec, preparation store, tracker wiring |
| `puls3_server/lib/src/ledger/` | Modified | Account sequence, latest ledger |
| `puls3_server/lib/src/endpoints/` | New | `HireEndpoint`, `SessionWallet` seam |
| `puls3_server/lib/src/protocol/`, migrations | New | `Puls3ApiException`, `PreparedTransaction`, `CreateHireResult`, `HireDetail`, `escrow_preparation` |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `stellar_dart` cannot sign-verify or hash | Med | Spike gates the work; defined fallback |
| Crypto bug without fixtures | Med | Recorded testnet golden vectors |
| Sequence races, out-of-relay broadcast | Med | Supersession reuses sequence; `claim_refund` residual (api.md) |
| Session ownership proven only against a fake | High | Seam test; replace at #25 |

## Review Workload

About 1,000 to 1,300 authored lines plus tests, above the 400-line budget. User chose single PR with `size:exception`; commits ordered spike, protocol/migration, codec, preparation, endpoints.

## Rollback Plan

Revert the PR; drop the `escrow_preparation` migration. No endpoint was public before, so no client depends on it.

## Dependencies

- #25 (sessions), #97 (`complete`/`reject` effects), testnet access for golden vectors.

## Success Criteria

- [ ] Spike passes or fallback is adopted and documented.
- [ ] Every `api.md` error code for the six methods has a test.
- [ ] A repeated submit never sends a second envelope.
- [ ] No default for validity window or `expired_at` exists in code.
