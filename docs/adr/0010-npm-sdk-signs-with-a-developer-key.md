# ADR-0010: The npm SDK creates agents and signs with a developer key

- **Status:** Accepted (2026-11-25). Implemented in #415 (merged `2fe943e`, reviewed and approved by moises-cisneros) and published to npm as `@puls3_org/sdk` 0.1.0 (the `@puls3` scope belongs to another npm organization).
- **Date:** 2026-11-17
- **Issue:** #314 (SOW week 3, SDK npm package)
- **Amends:** [ADR-0007](0007-developer-sdk.md) D1 ("never signs or submits", "a TypeScript SDK is out of this milestone"). The rest of ADR-0007 is unchanged.
- **Implemented by:** #302 (the npm package)
- **Related:** [ADR-0003](0003-payment-rail-and-custody.md) (custody) · [ADR-0005](0005-align-agent-commerce-with-erc-8183-and-erc-8004.md) D1, D4 (who signs each escrow call) · [API contract](../architecture/api.md) · #259 (CLI session) · #312 (agent-to-agent hire)

## Context

SOW week 3 promises an npm SDK that **creates agents with their own on-chain identity and wallet** and **executes autonomous payments on testnet from code**. ADR-0007 D1 says the opposite on two points: the SDK never signs or submits a transaction, and a TypeScript SDK is out of the milestone. With D1 as written, a program can read the catalog, prepare envelopes and start an agent-to-agent hire, but it cannot deploy an agent or pay for a hire without a person signing in Freighter.

What the server already offers, checked on `main` (`64a6793`):

- Every wallet-signed step is a pair: a `prepare…` call returns a `PreparedTransaction` (unsigned envelope or authorization entry, `signer`, `networkPassphrase`, `expiresAt`) and a `submit…` call takes the signed XDR back. The server relays it (ADR-0003, Decision A). Nothing new is needed on the server for a program to sign.
- Login is SEP-10: `WalletAuthEndpoint.createChallenge(wallet)` and `verifyChallenge(challengeId, wallet, signedChallengeXdr)`, both callable without a session. A program that holds a key can log itself in, so it needs neither the app nor a CLI session.
- Agent wallets are created and custodied by the server at deploy (`prepareDeploy` creates the agent wallet). The agent's own transactions, `submit` on a hire and every transaction of an agent-to-agent hire (`StudioEndpoint.hireAgentAs`, #312), are signed by the server with that custodied key.

So the change is in the SDK only: let it sign the envelopes the server already prepares, with a key the developer supplies, and say exactly which ones.

## Decision

### D1. The npm SDK is the primary SDK

The TypeScript package from #302 (name and npm scope still open there) is the SDK the SOW refers to. `puls3_sdk` (Dart) stays as the library of the CLI and the MCP server and keeps ADR-0007 D1: it does not sign. Bringing signing to Dart later is its own decision.

### D2. It signs with a key the developer supplies, and that key never leaves the process

- The SDK takes a **signer**, not a secret string, in its public API:

  ```ts
  interface Puls3Signer {
    publicKey(): string; // G… address
    signTransaction(xdr: string, networkPassphrase: string): Promise<string>;
    signAuthEntry(entryXdr: string, validUntilLedger: number, networkPassphrase: string): Promise<string>;
  }
  ```

  The package ships one implementation, `keypairSigner(secret)`, for a secret the developer reads from the environment (`PULS3_SECRET_KEY`) or from a file. A developer can plug in their own (a KMS, a hardware key) without the SDK seeing the secret.
- The secret, or anything derived from it other than the public key and signatures, is **never** sent to the server or any other host, never logged, and never put into an error message or a thrown object.
- The docs tell developers to use a **dedicated testnet key** for the SDK, not the wallet they use in the app.

### D3. It signs only what it can check, and checks before signing

A signing SDK that signs whatever the server prepares would turn a server bug or a compromised server into a drained developer wallet. So the SDK never signs blind. Before it signs a `PreparedTransaction` or an authorization entry, it decodes the XDR and refuses (`SigningRefused`, with the rule that failed) unless all of these hold:

1. **Network.** `networkPassphrase` equals the one the SDK was configured with, and that is testnet (`Test SDF Network ; September 2015`). Public network signing is refused until a later decision.
2. **Signer.** `prepared.signer`, the envelope's source account and every authorization entry's address are the signer's public key.
3. **Purpose and call.** The envelope has exactly one `InvokeHostFunction` operation. Its contract is the one **pinned in the SDK** for that purpose (escrow for `createJob`, `fund`, `complete`, `reject`; Identity Registry for `registerFull`; Reputation Registry for `giveFeedback`), and its function name matches `purpose`. The contract ids come from the SDK's network config, never from the server's answer. An authorization entry is not an envelope and is covered by rule 8.
4. **Arguments.** The invocation's arguments must be the ones the caller asked for, not merely the ones the server returned:
   - `caller` is the signer's public key, on every function that takes one.
   - `create_job`: `provider` is the wallet the SDK reads for the requested `agentId` (from the registry, not copied from the prepared envelope); `evaluator` is the signer; `hook` is `None`; `token` is the pinned USDC SAC; `agent_id` is the requested id; and `budget` is the price the caller accepted (the agent's price, at most `maxPrice` when the caller set one).
   - `fund`: `job_id` is the job id this flow's `create_job` produced, and `expected_budget` is the price the caller accepted.
   - `complete` and `reject`: `job_id` is that same job id, and the reason is the caller's, hashed as the server specifies.
   - `give_feedback`: `caller` is the signer and `agent_id` is the agent the hire was for, not another.
   - `register_full`: `caller` is the signer, and the URI and metadata are the draft's.
   - `set_agent_wallet`: `caller` is the signer, `agent_id` is the agent being deployed, and `new_wallet` is the agent wallet the deploy flow returned.
5. **Money.** Only `fund` may move USDC. Its `expected_budget` is the price the caller accepted, at most `maxPrice` when the caller set one, and `create_job` pinned the token to the USDC SAC. No other signed purpose may invoke a token contract.
6. **Bounds.** The fee is under the SDK's cap, the envelope has time bounds, and `maxTime` is no more than a short configured horizon ahead (for example 15 minutes), not merely present. `expiresAt` has not passed.
7. **Login.** A SEP-10 challenge is signed only if it is a valid challenge: its source account is the pinned server account (the `walletAuthSigningKey` public key), its sequence number is 0, it has exactly the two `manage_data` operations SEP-10 requires — the first for the signer's address with `<home domain> auth`, the second `web_auth_domain` with the configured value on the server account — and it is signed by that pinned server key. These are the checks SEP-10 asks of a wallet.
8. **Authorization entries.** `signAuthEntry` is a separate path and gets its own checks. The SDK signs an entry only when its address is the signer's public key, its root invocation is the pinned Identity Registry's `set_agent_wallet(caller, agent_id, new_wallet)` with the signer as `caller`, the deployed `agent_id` and the agent wallet the deploy flow returned as `new_wallet`, it has no sub-invocations, and `signatureExpirationLedger` matches the `validUntilLedger` given to the signer and is within a small configured number of ledgers ahead of the current ledger (for example 120 ledgers, about 10 minutes) and not already past. Every other authorization entry is refused.

The pinned addresses and the server signing key ship in the package for testnet and can be overridden in config for a local server. Overriding them is the developer's decision, made in their code, not the server's.

### D4. What is signed by whom

| Transaction | Signed by | Where |
|---|---|---|
| SEP-10 login challenge | Developer key | SDK |
| `register_full` (deploy, F4-6) | Developer key, as builder | SDK |
| `set_agent_wallet` authorization entry (deploy, F4-7) | Developer key, as builder | SDK |
| `create_job`, `fund`, `complete`, `reject` (a hire the developer pays) | Developer key, as client and evaluator | SDK |
| `give_feedback` | Developer key, as client | SDK |
| `submit` (the agent delivers) | Agent's custodied key | Server, unchanged |
| Every transaction of an agent-to-agent hire (#312) | Hiring agent's custodied key | Server, unchanged |

Custody does not change. The SDK never receives an agent's key. The "autonomous payment" of the SOW is the agent-to-agent hire: the program calls `hireAgentAs`, and the hiring agent's custodied wallet pays, with no person and no developer key signing it.

### D5. Sessions

- With a signer, the SDK logs in by itself (D3.7) and keeps the access and refresh tokens in memory. It may persist them in a user-only file (mode 0600), as the Dart CLI session does, so that several processes share one login.
- Without a signer, the SDK takes a CLI session (#259, `PULS3_REFRESH_TOKEN`) and can do everything that does not sign: catalog, reading hires and drafts, test runs, `prepare…` calls and `hireAgentAs`.
- A call that needs a signature and has no signer fails locally with `SignerRequired` before any network call.

### D6. The week 3 surface

Every call maps to an endpoint that exists today. The SDK adds the signing between `prepare…` and `submit…` and the polling, and nothing else. Error codes are the server's `Puls3ApiException` codes, passed through unchanged (ADR-0007 D3), plus the three local ones of this ADR: `SignerRequired`, `SigningRefused`, `Timeout`.

| SDK call | Endpoints, in order | Signer |
|---|---|---|
| `login()` | `walletAuth.createChallenge` → sign → `walletAuth.verifyChallenge`; later `jwtRefresh.refreshAccessToken` | Required (or a CLI session instead) |
| `listAgents()`, `getAgent(id)` | `agent.list`, `agent.get` | No session |
| `createDraft(manifest)`, `updateDraft(id, manifest, revision)` | `studio.saveDraft` | Session |
| `getDraft(id)`, `listDrafts()` | `studio.getDraft`, `studio.listDrafts` | Session |
| `setProviderCredential(…)` | `studio.saveProviderCredential` | Session |
| `testRun(draftId, input)` | `studio.testRun` | Session |
| `deploy(draftId)` → `{ agentId, agentWallet }` | `studio.prepareDeploy(draftId, builder)` → sign `register_full` → `studio.submitRegistration` → poll `studio.getDeploySession` until `awaitingWalletAuthorization` → `studio.prepareWalletAuthorization` → sign the entry → `studio.submitWalletAuthorization` → poll until `active` or `failed` | Required |
| `hire(agentId, input, { maxPrice })` → `hireId` | `hire.createHire` (returns `preparedCreateJob`) → sign → `hire.submitEscrowCall` → `hire.prepareFund` → sign → `hire.submitEscrowCall` | Required |
| `waitForResult(hireId)` | poll `hire.getHire` | Session |
| `approve(hireId)`, `reject(hireId, reason)` | `hire.prepareComplete` / `hire.prepareReject` → sign → `hire.submitEscrowCall` | Required |
| `rate(hireId, score, comment)` | `feedback.getFeedbackEligibility` → `feedback.prepareFeedback` → sign → `feedback.submitFeedback` | Required |
| `listMyHires()` | `hire.listMyHires` | Session |
| `hireAgentAs(hiringAgentId, agentId, input, budget)` | `studio.hireAgentAs` | Session (no signature: custodied) |
| `getAgentHire(hiringAgentId, hireId)` | `studio.getAgentHire` | Session |

`deploy` and `hire` resume rather than restart: `prepareDeploy` is idempotent (F4-4, F4-5) and `createHire` takes a `requestId` the SDK generates once per call and reuses on retry.

## Options considered

| Option | Why not |
|---|---|
| Keep ADR-0007 D1: no signing, return envelopes | Meets neither SOW promise from code. Every deploy and every paid hire still needs a person in Freighter. |
| Server signs with a key the developer uploads | Puts developer funds in server custody, which ADR-0003 limits to agent wallets. A server breach would reach every developer wallet. |
| Sign whatever the server prepares, without D3 | Simplest, but a compromised or buggy server could ask the SDK to sign any transfer from the developer's account. |
| Compile the Dart SDK to JavaScript | Rejected in #302: large output, no TypeScript types, poor stack traces. |

## Consequences

- #302 changes. Deliverable 3 there says "it never signs or submits a transaction (ADR-0007)". It now signs within D2 to D4, and its surface is D6, which is larger than `puls3_sdk`'s. "Same API as `puls3_sdk`" still holds for the calls both have, with the same names and error codes.
- The SDK must pin contract ids per network, so a contract redeploy needs a release of the package. The release notes list the pinned ids.
- D3 is security-critical code and needs its own tests: one refused case per rule, against envelopes built in the test, not only the happy path against the local server.
- A developer key with testnet USDC is a funded secret on a developer's machine. D2 keeps it out of the server and the logs; how the developer stores it is up to them, and the quickstart says so.
- No server change and no contract change.

## Open decisions

1. Package name and npm scope, and who owns the npm organization (#302).
2. Whether the SDK may sign on the public network, and with which extra limits. Out of week 3, which is testnet only.
