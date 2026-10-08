# ADR-0003: Payment rail and agent wallet custody

- **Status:** Proposed
- **Status note:** amended by [ADR-0005](0005-align-agent-commerce-with-erc-8183-and-erc-8004.md) (Accepted 2026-10-02). The decision text below is unchanged; each affected section carries a note.
- **Amended by:** [ADR-0005](0005-align-agent-commerce-with-erc-8183-and-erc-8004.md) · [What this supersedes or amends](0005-align-agent-commerce-with-erc-8183-and-erc-8004.md#what-this-supersedes-or-amends)
- **Date:** 2026-09-26
- **Issue:** #7
- **Research:** [Spike: payments and wallets](../spikes/payments-and-wallets.md)
- **Proof of concept:** [`spikes/payments-poc/`](../../spikes/payments-poc/)
- **Related:** [ADR-0001](0001-system-architecture.md) · [ADR-0002](0002-agent-registry-on-soroban.md) · [ADR-0004](0004-agent-manifest-and-deployment.md)

## Context

Consumers pay agents per task in USDC, and every agent has its own wallet ([vision](../vision.md)). Before building the register flow (#18) and the hire-and-pay endpoint (#19), we need to decide how money moves, how a payment is tied to a hire, who holds agent keys, and how the Serverpod server reads and writes to Stellar when `stellar_flutter_sdk` cannot run there.

## Decision

1. **Rail: direct USDC transfer through the SAC.** The consumer's wallet signs `transfer(from = consumer, to = M…, amount = price)` on the USDC Stellar Asset Contract. No x402, no MPP SDK, no escrow in the MVP.

   > **Superseded by [ADR-0005](0005-align-agent-commerce-with-erc-8183-and-erc-8004.md) D1, D2:** the consumer funds an ERC-8183 escrow job instead of a direct SAC transfer. See [What this supersedes or amends](0005-align-agent-commerce-with-erc-8183-and-erc-8004.md#what-this-supersedes-or-amends).

2. **The hire id travels as the muxed id.** `M…` is the agent wallet's address muxed with the hire id (a `u64`). The SAC's `transfer` event returns it as `to_muxed_id`.

   > **Amended by [ADR-0005](0005-align-agent-commerce-with-erc-8183-and-erc-8004.md) D1:** the escrow job id identifies the hire in contract calls and events; a muxed id may still tag the escrow's payout to the agent wallet (unverified).

3. **The server verifies before running the agent.** It calls RPC `getTransaction` with `xdrFormat: "json"` over plain HTTP and accepts the payment only if **all** of these hold:
   - `status` is `SUCCESS`;
   - a `transfer` event was emitted by the **configured USDC SAC contract id** (so a look-alike token cannot pass);
   - the event's `to` topic is the agent's wallet;
   - `amount` equals the price recorded for the hire (exact match);
   - `to_muxed_id` equals the hire id;
   - the transaction hash has **not been used** for any other hire, and the hire is not already paid.

   > **Superseded by [ADR-0005](0005-align-agent-commerce-with-erc-8183-and-erc-8004.md) D1:** the server reads the escrow job's state and events; the asset and amount are enforced by the contract.

4. **Agent wallets: server-custodied G-accounts, testnet only.** The server generates a keypair per agent, stores the secret encrypted, funds the account, and adds the USDC trustline. Earnings are swept to the builder. **Mainnet requires moving agent wallets to smart accounts with spending limits first.**
5. **Server-side chain access:** reads through Stellar RPC over plain HTTP; signing and submitting with the pure-Dart `stellar_dart`, only inside the `LedgerPort` adapter (ADR-0001). Fallback if `stellar_dart` fails: a small TypeScript sidecar.

   > **Unchanged by [ADR-0005](0005-align-agent-commerce-with-erc-8183-and-erc-8004.md).** **Amended 2026-10-07 (#96 spike):** `stellar_dart` 2.3.0 passed envelope decode and re-encode, network hash, and ed25519 verification (tests in `puls3_server/test/spike`). The fallback is no longer a TypeScript sidecar but pure Dart: `package:crypto` + ed25519 with hand-written XDR, behind the same `LedgerPort` adapter.

6. **Who signs:**

| Transaction | Signer |
|---|---|
| Consumer's payment | Consumer's wallet (app) |
| `register_full` | Builder's wallet (app) |
| Agent account creation and USDC trustline | Server, with the agent's key |
| `set_agent_wallet` | Transaction source = agent account (server signs the envelope); the builder signs only their authorization entry with Freighter's `signAuthEntry` |
| Sweep to the builder | Server |

> **Amended by [ADR-0005](0005-align-agent-commerce-with-erc-8183-and-erc-8004.md) D1, D4:** the consumer signs `create_job` and `fund` and, as evaluator, `complete` and `reject`; the server (agent's custodied key) signs `submit`; `claim_refund` is permissionless.

## Consequences

| Issue | Impact |
|---|---|
| **#18** Register agent flow | Creates the custodied agent account (keypair, funding, USDC trustline), then runs `register_full` (builder signs) and `set_agent_wallet` (server as source + builder's `signAuthEntry`). Must prove that two-party signing end to end |
| **#19** Hire and pay endpoint | Creates the hire with a `u64` id and a fixed price, returns the payment instruction (USDC SAC id, the agent's `M…` address, amount), then runs the six checks of decision 3 before marking the hire paid. Stores used transaction hashes to reject replays |
| **#33 / ADR-0004** | Resolves deploy steps 3 and 5 (agent wallet creation and its authorization) |
| **#25** Wallet connection | The app's wallet must sign a SAC `transfer` to a muxed address, and support `signAuthEntry` for the builder's step in #18 |
| **#30** Secrets | Adds the encryption key for custodied agent secrets, and the USDC SAC contract id per network |
| **#15, #30** Funding | Testnet USDC from Circle's faucet (manual) or the scripted test asset from the PoC |
| **#55** Escrow contract | Not needed for the MVP rail. Escrow stays out of scope, as in the vision |

> **Superseded by [ADR-0005](0005-align-agent-commerce-with-erc-8183-and-erc-8004.md) D1:** the **#55 Escrow contract** row above no longer holds — the escrow is in scope for the hire rail.

- Payments settle in one transaction and are verifiable from one HTTP call. No contract of ours holds user funds.
- The server is a custodian of agent earnings on testnet. A breach could drain agent balances, so balances stay small and are swept.
- Replay protection depends on the server's database (used hashes, paid hires), not on a contract.
- `stellar_dart` has low adoption. If it fails in #18, the sidecar fallback moves signing out of Serverpod. *(Amended 2026-10-07: the #96 spike passed, and the fallback is now pure Dart, so signing stays in Serverpod; see decision 5.)*

## Alternatives considered

1. **x402.** Standard per-request payments with a facilitator, but its SDKs are TypeScript, it needs a facilitator, and it is designed for machine clients calling HTTP APIs, not people in an app. Revisit for agent-to-agent API calls.
2. **MPP charge.** On-chain it is the same SAC transfer; the rest is an HTTP protocol with a TypeScript SDK we do not need yet.
3. **Escrow contract (#55).** Protects against agents that fail after payment, but adds a contract, refund logic, and disputes, all out of the MVP. Running the agent only after a confirmed payment keeps the MVP simple.

   > **Superseded by [ADR-0005](0005-align-agent-commerce-with-erc-8183-and-erc-8004.md) D1:** escrow moves into scope for the MVP hire rail.

4. **Memo instead of muxed id.** The muxed id is carried inside the SAC event, so one `getTransaction` call proves the hire; a memo is a transaction-level field outside the token event.
5. **Smart accounts for agent wallets now.** Safer, but needs a wallet contract and policies before the Serverpod deadline. Required before mainnet.
6. **Builder's own address as the payment address.** No custody at all, but agents would have no wallet of their own. Kept as the fallback if custody must be dropped.
