# Spike: agent payment rail and wallet custody on Stellar

- **Issue:** #7 · **Time-box:** 2 days · **Date:** 2026-09-26
- **Decision record:** [ADR-0003](../adr/0003-payment-rail-and-custody.md)
- **Proof of concept:** [`spikes/payments-poc/`](../../spikes/payments-poc/) — one real testnet payment, verified over plain HTTP

## Summary

- **Rail:** the consumer pays with a **direct USDC transfer through the Stellar Asset Contract (SAC)** to the agent's **muxed address**, whose muxed id is the **hire id**. The payment is tied to the hire on-chain, with no memo and no escrow contract.
- **Verification:** the server reads the transaction with RPC `getTransaction` (`xdrFormat: "json"`) over plain HTTP and checks status, emitting SAC, recipient, exact amount, and hire id. The PoC does this with `curl`.
- **Agent wallets:** for the MVP on testnet, each agent gets a **server-custodied G-account**. Before mainnet, move to smart accounts (C-accounts) with spending limits.
- **Server-side Stellar access:** reads over plain HTTP; signing with the pure-Dart library [`stellar_dart`](https://pub.dev/packages/stellar_dart), inside Serverpod.

## 1. Payment rail: x402, direct SAC transfer, or escrow?

| Option | How it works | Fit for "hire an agent" |
|---|---|---|
| **Direct SAC transfer (chosen)** | The consumer's wallet signs `transfer(from, to, amount)` on the USDC SAC. `to` is a muxed address (`M…`) whose id is the hire id; the SAC's `transfer` event carries it as `to_muxed_id` ([SAC docs](https://developers.stellar.org/docs/tokens/stellar-asset-contract)) | A person hires an agent from our app and pays once per task. One signature, one transaction, settles in seconds, and the event proves who was paid, how much, and for which hire |
| [x402](https://developers.stellar.org/docs/build/agentic-payments/x402) | An HTTP 402 flow: the client signs a Soroban transaction as a payment payload, and a facilitator verifies and settles it ([quickstart](https://developers.stellar.org/docs/build/agentic-payments/x402/quickstart-guide)) | Built for machine clients calling a paid HTTP API. Our consumer is a person in an app. Its SDKs are TypeScript (question 4). A good fit later, for agents paying other agents' APIs |
| [MPP](https://developers.stellar.org/docs/build/agentic-payments/mpp) charge | Each request triggers a SAC `transfer` settled on-chain; the SDK is `@stellar/mpp` (TypeScript) | On-chain it is the same SAC transfer we chose. What MPP adds is an HTTP protocol and a TypeScript SDK we do not need for the MVP |
| Escrow contract (#55) | Funds are locked in a contract and released on completion or refunded on timeout | Adds a contract to write, audit, and deploy. Refunds, disputes and escrow are **out of the MVP** in the [vision](../vision.md). Hires are short tasks, so we run the agent only after the payment is confirmed instead of locking funds |

**Why a muxed address and not a memo:** the muxed id travels inside the SAC event, so the hire id is part of the payment itself, readable from one `getTransaction` call. It works for any SEP-41 wallet that can sign a SAC transfer, and needs no extra operation.

## 2. Agent wallets: server-custodied G-accounts or smart accounts (C-accounts)?

| | Server-custodied G-account (chosen for the MVP) | Smart account / C-account | Builder's own address |
|---|---|---|---|
| What it is | The server generates a keypair per agent and stores the secret encrypted | A contract account whose `__check_auth` enforces signers and policies such as spending limits ([contract accounts](https://developers.stellar.org/docs/build/guides/contract-accounts)) | The agent's payment address is the builder's wallet (ADR-0002's default after `register`) |
| Receives USDC | Needs a USDC trustline (the server adds it when it creates the wallet) | No trustline: the SAC keeps the balance in contract storage ([SAC docs](https://developers.stellar.org/docs/tokens/stellar-asset-contract)) | Needs the builder's trustline |
| Risk | A server breach can drain every agent balance. Mitigated by keeping balances small and sweeping earnings to the builder | Policies bound what a compromised signer can spend (prior art: [eunomia](https://github.com/eunomia-finance/eunomia)) | None for us: we hold no keys |
| Complexity | Low: plain accounts, signed with `stellar_dart` | High: deploy and maintain a wallet contract and its policies | Lowest |
| Agent can pay (later) | Yes | Yes, within its policy | No: the agent has no wallet of its own |

**Decision:** server-custodied G-accounts **on testnet only**, because they keep the vision's "every agent has its own wallet" and allow agent-to-agent payments later with little work. **Mainnet is blocked until agent wallets move to smart accounts with spending limits.** The builder's own address stays a valid fallback if custody has to be dropped: it needs no code beyond ADR-0002's default.

## 3. Agent-to-agent payments: does the rail support them without changes?

**Yes.** An agent pays another agent with the same SAC `transfer`, from its custodied account (signed by the server) to the payee agent's muxed address, and the same verification applies. Nothing in the rail changes. Agent-to-agent hiring is still **out of the MVP** (no UI or orchestration), as the vision states.

## 4. Dart compatibility: can our Serverpod server take part in x402?

- The x402 packages used on Stellar are TypeScript: `@x402/fetch`, `@x402/core`, `@x402/stellar`, and `@x402/express` for the resource server ([quickstart](https://developers.stellar.org/docs/build/agentic-payments/x402/quickstart-guide)). There is no Dart SDK.
- The payer signs a full Soroban transaction as the payment payload, and a facilitator verifies and settles it over HTTP. A Dart server could call a facilitator over HTTP, but it would have to build and check x402 payloads itself; the Stellar quickstart does not document the facilitator's endpoints.
- **What is missing for Dart:** x402 payload encoding and decoding, and the facilitator client. **Not needed for the MVP**, because the chosen rail is a direct transfer. It becomes relevant if puls3 agents are exposed as paid HTTP APIs to external agents.

## 5. Testnet: how do we fund demo accounts?

- **Circle's faucet** sends testnet USDC on Stellar: [faucet.circle.com](https://faucet.circle.com), 20 USDC every 2 hours per address. Testnet USDC issuer: `GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5` ([x402 quickstart](https://developers.stellar.org/docs/build/agentic-payments/x402/quickstart-guide)). A G-account needs a USDC trustline first.
- The faucet is a web page, so it cannot be scripted. For automated tests and seeding (#15, #30), the PoC issues a **throwaway test asset** (`PUSDC`) and deploys its SAC. The rail is identical; only the asset changes, through configuration.
- XLM for fees and account reserves comes from Friendbot (`stellar keys generate --fund`).

## 6. Server-side Stellar access

`stellar_flutter_sdk` depends on Flutter and cannot run in the Serverpod server ([ADR-0001](../adr/0001-system-architecture.md)).

**Reads and verification: Stellar RPC over plain HTTP. Proven.** The PoC verifies a payment with one `curl` call to `getTransaction` with `xdrFormat: "json"` ([method docs](https://developers.stellar.org/docs/data/apis/rpc/api-reference/methods/getTransaction)). The JSON response includes `status` and `events.contractEventsJson`, where the SAC's `transfer` event shows the emitting `contract_id`, the `from`/`to` addresses and asset in its topics, and `amount` and `to_muxed_id` in its data. A Dart server needs only `package:http` and JSON decoding. RPC keeps about 7 days of transactions by default, so the server verifies right after the payment, not days later.

**Signing and submitting: the pure-Dart library `stellar_dart`, inside Serverpod.**

| Option | Assessment |
|---|---|
| **(b) `stellar_dart` (chosen)** | Pure Dart (only depends on `blockchain_utils`), MIT, updated in July 2026. Its [`transfer.dart` example](https://github.com/mrtnetwork/stellar_dart/blob/main/example/lib/examples/transfer.dart) invokes a SAC `transfer`, simulates it, and signs it: the exact operations we need. **Risk:** low adoption (3 stars, ~77 downloads a month). Keeps all chain work inside Serverpod, which the "Use of the Serverpod stack" criterion rewards |
| (a) Sign only on the client | Users already sign their own transactions in the app. But agent wallets are server-held, so the server must sign something |
| (c) Sidecar service (TypeScript SDK) | Mature SDKs, but a second runtime and deployment, and chain work moves out of Serverpod. **Kept as the fallback** if `stellar_dart` fails in #18 |

**Who signs which transaction:**

| Transaction | Signed by |
|---|---|
| Consumer pays for a hire (SAC `transfer`) | Consumer's wallet, in the app |
| `register_full` (agent identity) | Builder's wallet, in the app |
| Create the agent account and its USDC trustline | Server (`stellar_dart`), with the agent's key |
| `set_agent_wallet` (needs builder **and** agent wallet auth) | Transaction source = the agent account, so the server's envelope signature covers the agent's authorization. The builder signs only their **authorization entry** with Freighter's `signAuthEntry` ([docs](https://developers.stellar.org/docs/build/guides/freighter/sign-auth-entries)) |
| Sweep earnings from the agent to the builder | Server, at the builder's request |
| Verify a payment | Nobody (read only) |

## Open questions

1. **Prove the `set_agent_wallet` two-party signing end to end** (server as source + Freighter `signAuthEntry`) in #18. Documented, not yet run.
2. **`getEvents` with `xdrFormat: "json"`** for catalog indexing (#17): `getTransaction` is proven; `getEvents` still needs checking.
3. **Key storage for custodied agent keys:** encryption key location and rotation belong to #30.
4. **Sweep policy:** automatic after each hire, or on demand. A product call for #18/#19.
5. **Smart-account migration** before mainnet: which wallet contract, and which policies.
