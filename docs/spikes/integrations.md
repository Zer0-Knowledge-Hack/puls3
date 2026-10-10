# Spike: integrations — agents on third-party APIs and SDKs (x402 tools)

- **Issue:** #82 · **Time-box:** 2 days · **Date:** 2026-10-09
- **Decision record:** [ADR-0006](../adr/0006-integrations-and-agent-tools.md)
- **Examples:** [`integration-manifest.example.json`](../architecture/examples/integration-manifest.example.json) (TIA) · [`agent-manifest.tools.example.json`](../architecture/examples/agent-manifest.tools.example.json)
- **Related:** [ADR-0003](../adr/0003-payment-rail-and-custody.md) · [ADR-0004](../adr/0004-agent-manifest-and-deployment.md) · [ADR-0005](../adr/0005-align-agent-commerce-with-erc-8183-and-erc-8004.md) · [Spike: payments and wallets](payments-and-wallets.md) (#7) · [Spike: agent commerce standards](agent-commerce-standards.md) · #20 · #34 · #35 · #37

**Evidence labels.** **V** = verified in a primary source listed in [Sources](#sources), accessed 2026-10-09. **I** = inference by the authors; it must be confirmed before it drives an implementation.

## Question

puls3 is a two-sided market today: builders create agents and consumers hire them. Third-party API and SDK providers want in — the first concrete case is **TIA**, a USD/MXN remittance data API that agents pay per call with x402 on Stellar (V: `/v1/quote` $0.10, `/v1/route` $0.25, `/v1/alert` $0.10; a real mainnet payment was verified). The idea is an **Integrations** section: providers register APIs, builders pick them as tools in the Agent Studio, and agents use them at run time.

That conflicts with current decisions — ADR-0004 (prompt-only agents, `tools` reserved), ADR-0003/ADR-0005 (x402 out of the MVP), the #7 spike (x402 SDKs are TypeScript; the server is Dart), and ADR-0003 (custodied agent wallets need spending limits before mainnet). This spike answers the eight questions in #82 so ADR-0006 can decide.

## Summary

- **Format: reuse OpenAPI 3.1 plus a thin puls3 payment overlay.** OpenAPI describes the API; the overlay adds only price and the x402 payment terms. The model-facing tool schema is generated from the OpenAPI operation (MCP tool shape). Do not invent an API format.
- **Tools: the reserved `tools` field becomes a list of references** to `{integration, operation}`. A hire pins the manifest version, so it runs the tools it was paid for.
- **Runtime: a new tool-calling loop and a closed tool set.** The model picks tool names and arguments; it never picks a URL, a `payTo`, an asset or an amount.
- **Payment: x402 is the provider rail; the hire rail stays ERC-8183 escrow.** The x402 client is Dart-native as the target; a **testnet-only TypeScript sidecar** is the Phase-1 fallback if a 2-day Dart auth-entry experiment fails. A facilitator settles.
- **Economics: fixed price with a per-hire cap; tool costs are the builder's, never the consumer's.** Tool payments are off-escrow, so a failed or over-budget tool call never touches the escrow; the ADR-0005 refund path is unchanged.
- **Safety: server-enforced caps and a payTo allow-list now; smart-account policy on mainnet.** The closed tool set is the primary prompt-injection defence.
- **Providers: an ERC-8004 registration file plus a curated listing; a testnet endpoint is required** to take part before mainnet.

## 1. Integration manifest: can we reuse an existing format?

**Yes — reuse OpenAPI 3.1, and add one thin overlay.** No single existing format carries everything; the table shows the coverage.

| Candidate | What it covers | What it lacks for a paid provider |
|---|---|---|
| **[OpenAPI 3.1](https://spec.openapis.org/oas/v3.1.0)** (V) | Paths, methods, parameters, request/response schemas, auth | Price, the x402 scheme, network, asset, `payTo` |
| **MCP tool schema** (`inputSchema`, JSON Schema) (V) | One tool's inputs, for the model | HTTP endpoints, response shapes, price |
| **[A2A Agent Card](https://a2a-protocol.org/latest/specification/)** (V) | An agent's `skills`, input/output modes | Third-party APIs (it describes agents, not APIs) |
| **[ERC-8004](https://eips.ethereum.org/EIPS/eip-8004)** registration-file `services` + `x402Support` (V) | Discovery: an endpoint URL and whether it supports x402 | A full API description or price |

**Decision (ADR-0006 D1):** the provider's **OpenAPI 3.1** document is the API description, referenced by URL (and optionally a content hash). puls3 stores a small overlay, `puls3.integration-manifest/v1` ([example](../architecture/examples/integration-manifest.example.json)), that maps each paid `operationId` to a **tool name**, a **price**, and the **x402 payment terms**, plus listing and safety metadata. The **model-facing tool schema** is generated from the OpenAPI operation — method + path become the fixed request; query parameters or the request body become `inputSchema` — so it is not authored twice. The **ERC-8004 `services` field** is the discovery pointer. The **A2A Agent Card** stays for puls3's own agents.

The overlay is deliberately redundant with the `402 PAYMENT-REQUIRED` header, so a listing can be verified against the live provider before it is trusted (V: TIA's `GET /health` lists every paid route and its current price; an unpaid call returns the terms).

**TIA example, exactly as TIA publishes it** (V):

| Operation | Tool | Price | Base units (7 decimals) |
|---|---|---|---|
| `GET /v1/quote` | `tia_get_quote` | $0.10 | `1000000` |
| `GET /v1/route?amount=USD` | `tia_get_route` | $0.25 | `2500000` |
| `POST /v1/alert` | `tia_create_alert` | $0.10 | `1000000` |
| `GET /health` | — (free) | $0 | — |

## 2. Tools in the agent manifest, and how the runtime exposes them

**The reserved `tools` field becomes a list of references** (ADR-0006 D2):

```json
"tools": [
  { "integration": "tia", "operation": "getRoute" },
  { "integration": "tia", "operation": "getQuote" }
]
```

- **References, not definitions:** the endpoint, price, payment and schema live in the integration manifest, outside the agent manifest. This keeps the manifest small and the salted hash stable across provider edits.
- **Un-reserve `v1`:** a manifest without `tools` hashes exactly as before, so existing deployments are unaffected. A schema bump would force a migration for no data change.
- **Pinning:** a hire records `manifestVersion` (ADR-0004 decision 4), so it runs the exact tool set it was paid for. Adding or removing a tool creates a new immutable version.
- **New manifest fields:** `tools_budget.max_spend_per_hire` and `max_spend_per_day`, positive integers in stroops, with `max_spend_per_hire ≤ price` recommended ([example](../architecture/examples/agent-manifest.tools.example.json)).

**Runtime (#20).** Today the runtime is a single text-in/text-out call: `ModelRuntime.complete(RuntimeTask)` returns a `String` with no loop (V: [`runtime_task.dart`](../../puls3_server/lib/src/runtime/runtime_task.dart)). Tool calling adds (ADR-0006 D3):

1. **Tool definitions to the model** from the provider adapters (`AnthropicRuntime`, `WorkersAiRuntime`).
2. **A bounded loop:** call the model → execute a requested tool → append the tool result → call again, bounded by a step count and the runtime timeout (which must also cover the tool calls, per ADR-0005 D3).
3. **An executor behind a domain port** (`ProviderPaymentPort`): read the 402 terms, check the policy, sign, retry, return the provider JSON to the model. The escrow relay is not involved.
4. **Failure mapping:** a provider error, a refused payment or a cap hit becomes a **tool error** the model can react to; it never crashes the run. A run that still yields nothing fails as today (`runtimeStatus = failed`; the hire stays `funded` until reject or expiry).

**Closed set.** The model selects a **tool name** and supplies **arguments**; the server maps the name to a fixed method + path + base URL. The model never supplies a URL, method, `payTo`, asset or amount. This is the primary prompt-injection defence.

## 3. Paying providers: Dart, a TypeScript sidecar, or a facilitator?

The x402 client has three parts; only one needs the agent's key:

| Part | Needs the agent key? | State of the code |
|---|---|---|
| (a) 402 negotiation and `PaymentPayload` encode/decode | No | Not implemented |
| (b) Sign a SAC `transfer` **authorization entry** with the agent's custodied key | **Yes** | Not implemented: the `EnvelopeCodec` splices node-provided entries and only relays `SOURCE_ACCOUNT` credentials (V: [`envelope_codec.dart`](../../puls3_server/lib/src/ledger/envelope_codec.dart)) |
| (c) Call a facilitator's `/verify` and `/settle` | No | Not implemented |

On Stellar, x402 clients sign **auth entries, not full envelopes**; the facilitator assembles the transaction, pays the fee and submits (V: x402 on Stellar). So x402 is the mirror image of puls3's relay: the facilitator is the source, the agent signs only its entry.

| Option | Time (Phase 1) | Risk | Notes |
|---|---|---|---|
| **Dart-native** (`stellar_dart` + hand-written x402 payload) | 3–5 days | Medium–high: `stellar_dart` is proven for envelopes and ed25519 (#96) but **not** for `ADDRESS_V2` auth-entry construction; the x402 payload format is TypeScript-defined and may drift | Keeps chain work in Serverpod; consistent with ADR-0001/ADR-0003 |
| **TypeScript sidecar** (`@x402/fetch` + `@x402/stellar`) | ~1 day | Low protocol risk; high key-handling risk; a second runtime | Reuses the mature SDKs; the agent secret crosses a boundary |
| **Dart signing + hosted facilitator** | 2–3 days | Medium: still needs (b); removes the payload-format risk if the facilitator accepts a bare signed entry | Sub-option of the target |
| **"Just a facilitator"** | — | — | Not an option: the facilitator still needs the client's signature |

**Decision (ADR-0006 D5):** **Dart-native is the target**, gated by a **2-day go/no-go experiment** that proves `stellar_dart` (or the existing `XdrWriter`) can build and sign an `ADDRESS_V2` SAC `transfer` auth entry and round-trip it through an x402 `PaymentPayload`. If it passes, no sidecar. If it fails, Phase 1 uses the **testnet-only sidecar** behind the same `ProviderPaymentPort`, with the key handled narrowly and the sidecar recorded as a security debt to remove before mainnet.

**Facilitator (orthogonal to signing):** testnet uses `https://x402.org/facilitator` (no API key, `stellar:testnet`, fees sponsored); mainnet uses OZ Channels (API key) or self-facilitation (V). The facilitator pays the XLM fee, so the agent needs USDC, not XLM. The #7 spike's conclusion that "Dart cannot x402, and it is not needed for the MVP" is now superseded for the provider rail: it is needed, and the gap is the experiment above.

## 4. Economics: fixed price with a cap, and the escrow on failure

**Fixed price with a cap; tool costs are the builder's** (ADR-0006 D6).

- The manifest `price` is fixed and already includes expected tool costs plus margin. `tools_budget.max_spend_per_hire` and `max_spend_per_day` bound tool spend.
- **Consumer exposure is fixed.** The consumer funds exactly `price` into the escrow. ERC-8183 sets the budget at `create_job`/`fund` and pays it on `complete`; it has no partial refund. A pass-through ("price + actual tool costs") would need a non-standard max-funding-and-refund extension, contrary to ADR-0005 D1's conformance rule (V: [ERC-8183](https://eips.ethereum.org/EIPS/eip-8183)). **Rejected for the MVP.**
- **Builder exposure is capped.** When a cap is hit, the runtime stops calling tools; the agent delivers with what it has or the run fails. The builder eats the difference — a pricing decision, surfaced in the Studio.

**What happens to the escrow (ADR-0005) when a tool call fails or costs more than expected:**

| Event | Escrow effect | Hire outcome |
|---|---|---|
| Tool call fails (provider error, 402 refused) | **None** — tool payments are off-escrow | The runtime retries (bounded) or returns a tool error; the run may still `submit` a degraded result |
| Run cannot produce a result | **None** | `runtimeStatus = failed`; the hire stays `funded`; the client `reject`s (refund) or the tracker `claim_refund`s after `expired_at` (ADR-0005 D1) |
| Cap exceeded | **None** | The runtime stops calling tools; deliver partial or fail, as above |
| `complete` / `release` | Pays the agent the fixed `price` | Unchanged |

**No partial or stranded escrow state is possible from a tool call**, because the escrow only ever holds the hire price. Tool spend already incurred is a builder loss, bounded by the cap.

**Tool float (new consequence):** x402 pays at call time, before `complete`, so the agent wallet needs a USDC float funded by the builder (or from prior payouts). The Studio shows the required float; on testnet it is seeded. This touches #18 and #35.

**Platform fee:** unchanged, 0 bps (ADR-0005 D7). A fee on provider payments would be a separate decision.

## 5. Safety: spending limits, allow-list, prompt injection

**Server-enforced now, contract-enforced on mainnet** (ADR-0006 D7).

**Phase 1 (testnet) — server-enforced.** Before signing each provider payment, the tool executor's `ProviderPaymentPolicy` checks:

1. `payTo` is in the integration's `allowedPayTo` for the network;
2. `asset` is the configured USDC SAC and `network` is the server's network;
3. the operation is declared in the **pinned** manifest version;
4. `hireToolSpend + amount ≤ max_spend_per_hire`;
5. `dayToolSpend + amount ≤ max_spend_per_day`.

A failure is returned to the model as a tool error; no signature is produced.

**Phase 2 (mainnet) — contract-enforced.** Move agent wallets to **smart accounts (C-accounts) with a policy signer** enforcing per-payment and rolling-24h caps and a payee allow-list, so a compromised server cannot overspend. This is the ADR-0003 decision 4 / #7-spike prerequisite for mainnet (prior art: [eunomia](https://github.com/eunomia-finance/eunomia), V: per-payment and rolling 24h caps, payee allow-lists, expiring session keys). Phase-1 server checks then become defence in depth.

**Prompt injection.** The model cannot create endpoints, `payTo`s or amounts. Mitigations: the closed tool set (§2); arguments validated against the JSON Schema; tool results delimited and labelled as data, never instructions; the caps bound the blast radius; the provider list is curated and verified (§6). No tool can return a secret or sign an arbitrary transaction.

**Who enforces what:** the **escrow contract** enforces the hire budget (unchanged); the **server** enforces the tool budget in Phase 1; the **agent smart account** enforces it in Phase 2.

## 6. Provider identity and trust

**An ERC-8004 registration file plus a curated listing** (ADR-0006 D8). A provider publishes a registration file with a `services` entry (the API endpoint and OpenAPI URL) and `x402Support: true`, optionally backed by an on-chain Identity Registry entry (reusing ADR-0002's registry; a provider can hold an ERC-8004 agent identity). puls3 verifies the 402 handshake, the OpenAPI document, the `payTo`, the asset and the price before listing; **on-chain identity is a signal, not proof**. The drop-in caveat from ADR-0002/ADR-0005 D5 still applies: puls3 registrations are not indexed by Stellar 8004 tooling.

## 7. Networks

The MVP runs on **testnet**; TIA's live API is **mainnet only** (V). TIA also publishes a **testnet handshake host** (`https://remesa-tia-testnet.vercel.app`, `stellar:testnet`, same paths; the 402 header announces that host's network, asset and `payTo`), so TIA can take part now.

| Requirement | Rule |
|---|---|
| Per-network config | The integration manifest declares `baseUrl` and `payment` per network |
| Refusal | The runtime refuses a `stellar:pubnet` operation on a testnet server and vice versa |
| Provider onboarding | A provider must offer a **testnet endpoint or a documented mock** to take part before mainnet |
| Mainnet | **Phase 2**, blocked until the smart-account limits of §5 exist (ADR-0003) |

## 8. Prior art

At least two platforms let agents use paid third-party APIs; four are listed with links.

| Platform | How agents use paid third-party APIs | What we take |
|---|---|---|
| **BNB Agent Studio / BNBAgent SDK / APEX** ([site](https://www.bnbchain.org/en/blog/bnb-agent-studio-is-live-on-bnb-chain-ai-agents-from-one-prompt), [SDK](https://github.com/bnb-chain/bnbagent-sdk), [APEX](https://github.com/bnb-chain/apex-contracts)) (V) | Agents **pay their own LLM bills over x402**; the SDK registers an ERC-8183 task interface, an ERC-8004 identity and an agent wallet; the deploy pipeline (identity + wallet + runtime in one action) is the shape we follow | The three-sided shape: identity + wallet + runtime, with per-call payments |
| **Coinbase x402 Bazaar** ([docs](https://docs.cdp.coinbase.com/x402/bazaar)) (V) | A **discovery catalog** of x402-paid APIs that agents browse and pay per call; CDP agentic accounts add spending controls | Discovery by a paid-API catalog, and spending controls on the payer |
| **Virtuals ACP v2** ([whitepaper](https://whitepaper.virtuals.io/), [SDK](https://github.com/Virtual-Protocol/acp-node-v2)) (V) | Agents have **workers made of functions (tools)** and hire each other through ERC-8183 jobs; tools drive planning | Confirms tools as the agent's capability unit, on top of jobs |
| **MCP** ([spec](https://modelcontextprotocol.io/), [registry](https://github.com/mcp)) (V) | A standard way to expose **tools** (name, description, JSON Schema) to a model | Reuse the MCP tool schema for the model-facing definition, generated from OpenAPI |

## Phased plan

The plan and its effort estimates live in [ADR-0006 §Phased plan](../adr/0006-integrations-and-agent-tools.md#phased-plan): **Phase 0** (directory + schema, docs + listing only), **Phase 1** (tool calling with x402 on testnet, per-hire cap, target HackMeridian Oct 25), **Phase 2** (mainnet, smart-account limits, provider ERC-8004). Only Phase 0 docs can fit before the Serverpod demo (Oct 14) without putting the MVP at risk.

## Open questions

1. Cap defaults and the server hard ceiling (ADR-0006 open decision 1).
2. Test-run tool cost: who pays, and whether test runs may call paid endpoints at all.
3. Whether puls3 takes a fee on provider payments.
4. Whether the Phase-1 listing requires an on-chain ERC-8004 registration or only the curated off-chain listing.
5. The Dart auth-entry experiment outcome (Dart-native vs testnet sidecar).

## Sources

All accessed 2026-10-09 unless noted.

- TIA live site: https://tia-stellar.vercel.app · API: https://x402.holatia.app
- TIA repository (OpenAPI at `docs/tia-openapi.yaml`, agent guide at `docs/agents/README.md`): https://github.com/Edgadafi/remesa-liquidez
- TIA first paid mainnet call: https://stellar.expert/explorer/public/tx/b5fc310f086d3e4e170384fec0ccd1485c9b348559a12f61aa1ec9f2b5695e0d
- x402 on Stellar: https://developers.stellar.org/docs/build/agentic-payments/x402
- x402 facilitators: https://docs.x402.org/dev-tools/facilitators · OpenZeppelin Channels: https://channels.openzeppelin.com
- ERC-8004 Trustless Agents: https://eips.ethereum.org/EIPS/eip-8004
- ERC-8183 Agentic Commerce: https://eips.ethereum.org/EIPS/eip-8183
- OpenAPI 3.1: https://spec.openapis.org/oas/v3.1.0
- A2A Agent Card: https://a2a-protocol.org/latest/specification/
- MCP specification: https://modelcontextprotocol.io/ · MCP registry: https://github.com/mcp
- BNB Agent Studio: https://www.bnbchain.org/en/blog/bnb-agent-studio-is-live-on-bnb-chain-ai-agents-from-one-prompt
- BNBAgent SDK: https://github.com/bnb-chain/bnbagent-sdk · APEX contracts: https://github.com/bnb-chain/apex-contracts
- Coinbase x402 Bazaar: https://docs.cdp.coinbase.com/x402/bazaar
- Virtuals ACP v2: https://whitepaper.virtuals.io/ · https://github.com/Virtual-Protocol/acp-node-v2
- eunomia (agent treasury with spending caps): https://github.com/eunomia-finance/eunomia
- Stellar contract accounts / smart wallets: https://developers.stellar.org/docs/build/guides/contract-accounts
- Internal: [ADR-0003](../adr/0003-payment-rail-and-custody.md), [ADR-0004](../adr/0004-agent-manifest-and-deployment.md), [ADR-0005](../adr/0005-align-agent-commerce-with-erc-8183-and-erc-8004.md), [Spike: payments and wallets](payments-and-wallets.md) (#7), [Spike: agent commerce standards](agent-commerce-standards.md), [LATAM market research](../research/latam-b2b-market.md) (#80)
