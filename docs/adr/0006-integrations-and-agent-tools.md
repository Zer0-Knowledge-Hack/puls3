# ADR-0006: Integrations and agent tools (x402 pay-per-call)

- **Status:** Proposed (awaiting the product owner and the owners of #20 and #35; see [Acceptance](#acceptance))
- **Date:** 2026-10-09
- **Issue:** #82
- **Research:** [Spike: integrations](../spikes/integrations.md)
- **Example:** [`integration-manifest.example.json`](../architecture/examples/integration-manifest.example.json) · [`agent-manifest.tools.example.json`](../architecture/examples/agent-manifest.tools.example.json)
- **Amends:** [ADR-0003](0003-payment-rail-and-custody.md) · [ADR-0004](0004-agent-manifest-and-deployment.md) · [ADR-0005](0005-align-agent-commerce-with-erc-8183-and-erc-8004.md) (see [What this supersedes or amends](#what-this-supersedes-or-amends))
- **Related:** [ADR-0001](0001-system-architecture.md) · [ADR-0002](0002-agent-registry-on-soroban.md) · [Spike: payments and wallets](../spikes/payments-and-wallets.md) (#7) · [#20](https://github.com/Zer0-Knowledge-Hack/puls3/issues/20) runtime · [#34](https://github.com/Zer0-Knowledge-Hack/puls3/issues/34) domain · [#35](https://github.com/Zer0-Knowledge-Hack/puls3/issues/35) Studio · [#37](https://github.com/Zer0-Knowledge-Hack/puls3/issues/37) UI

## Context

puls3 is a two-sided market: builders create agents and consumers hire them. Third-party API and SDK providers want in. The first concrete case is **TIA**, a USD/MXN remittance data API that AI agents pay per call with x402 on Stellar (`GET /v1/quote` $0.10, `GET /v1/route` $0.25, `POST /v1/alert` $0.10), with a real verified mainnet payment. Providers would earn per call, builders could build agents on real data, and puls3 would become a three-sided market (providers, builders, consumers).

That conflicts with current decisions, so #82 asked for this spike and ADR before any implementation:

- **ADR-0004:** MVP agents are prompt-only; the manifest reserves a `tools` field that validation rejects.
- **ADR-0003 and ADR-0005:** x402 is out of the MVP; hires are paid through the ERC-8183 escrow.
- **#7 spike:** the x402 SDKs are TypeScript and the Serverpod server is Dart.
- **ADR-0003:** agent wallets are server-custodied G-accounts on testnet, with smart accounts and spending limits required before mainnet.

The spike ([`integrations.md`](../spikes/integrations.md)) answers the eight questions in #82 with sources. This ADR records the decision, the alternatives, and the consequences for #20, #34, #35 and #37. It changes nothing in the escrow (ADR-0005).

**Scope split that resolves most conflicts:** the **hire rail stays ERC-8183 escrow** (ADR-0005) — a consumer pays an agent per job. **x402 is the provider rail** — an agent pays a third-party API per call. The two never share a contract or a budget. Everything below is about the second rail only.

## Decision

| # | Decision | Answers |
|---|---|---|
| [D1](#d1-reuse-openapi-with-a-thin-payment-overlay) | Reuse OpenAPI 3.1 plus a thin payment overlay; do not invent an API description format | Q1 |
| [D2](#d2-the-tools-field-holds-references-un-reserved) | `tools` holds references to integration operations; un-reserve the field | Q2 |
| [D3](#d3-the-runtime-exposes-a-closed-tool-set) | The runtime exposes a closed, manifest-pinned tool set through a new tool-calling loop | Q2 |
| [D4](#d4-x402-is-the-provider-rail-not-the-hire-rail) | x402 is the provider payment rail; the hire rail is unchanged | Q3 |
| [D5](#d5-payment-client-dart-native-target-sidecar-as-a-phase-1-fallback) | Dart-native x402 client is the target; a testnet-only TypeScript sidecar is the Phase-1 fallback; a facilitator settles | Q3 |
| [D6](#d6-fixed-price-with-a-cap-tool-costs-are-the-builders) | Fixed price with a per-hire cap; tool costs are the builder's; the escrow is untouched | Q4 |
| [D7](#d7-server-enforced-limits-now-contract-enforced-on-mainnet) | Server-enforced per-hire/per-day caps and a payTo allow-list now; smart-account policy on mainnet | Q5 |
| [D8](#d8-provider-identity-and-networks) | Provider identity via ERC-8004 registration files plus a curated listing; a testnet endpoint is required | Q6, Q7 |

### D1. Reuse OpenAPI with a thin payment overlay

**Decision.** An integration is described by the **provider's OpenAPI 3.1 document** (endpoints, parameters, request/response shapes) plus a small **puls3 overlay** that adds only what OpenAPI does not carry: per-operation **price**, the x402 **payment scheme/network/asset/payTo**, the tool name, and listing/safety metadata. puls3 does **not** invent a new API description format.

- **API description:** the OpenAPI document, referenced by URL (and optionally a content hash), stays the source of truth. TIA already publishes one (`docs/tia-openapi.yaml`).
- **The overlay** (`puls3.integration-manifest/v1`, [`example`](../architecture/examples/integration-manifest.example.json)) maps each paid `operationId` to a price and a payment. It is small, auditable, and redundant with the `402 PAYMENT-REQUIRED` header, so it can be verified at listing time.
- **Model-facing tool schema:** the tool definition the LLM sees (`name`, `description`, `inputSchema`) is **generated** from the OpenAPI operation — method and path become the fixed request, query parameters or request body become the JSON Schema `inputSchema`. It is not authored twice. This is the MCP tool shape; MCP is the transport for exposing tools to a model, not a description of a paid HTTP API.
- **Discovery/identity:** the **ERC-8004 registration file** `services` entry (with `x402Support: true`) points at the provider's endpoint and OpenAPI URL, so ERC-8004 tooling can find the provider. The **A2A Agent Card** describes puls3's own agents, not third-party paid APIs; its skill shape stays reused for the agent manifest but is not stretched to describe provider endpoints.

**Why not the alternatives:** OpenAPI alone cannot express price or the x402 scheme; MCP alone cannot express HTTP endpoints or price; the A2A Agent Card describes agents, not APIs; the ERC-8004 `services` field is a discovery pointer, not a description. Each covers one slice, and the overlay fills the single gap.

### D2. The `tools` field holds references, un-reserved

**Decision.** The reserved `tools` field (ADR-0004 decision 2) is **un-reserved**. It is an array of references to integration operations:

```json
"tools": [
  { "integration": "tia", "operation": "getRoute" },
  { "integration": "tia", "operation": "getQuote" }
]
```

- **References, not definitions.** The manifest holds an integration id and an operation id; the endpoint, price, payment and schema live in the integration manifest, outside the agent manifest. This keeps the agent manifest small, keeps provider configuration out of it, and keeps the salted hash meaningful (see [`agent-manifest.tools.example.json`](../architecture/examples/agent-manifest.tools.example.json)).
- **Un-reserve `v1`, do not bump the schema.** The reserved field was always intended to be filled in later. A manifest **without** `tools` hashes exactly as before, so existing deployments are unaffected; only new manifests that declare tools are new. Bumping to `puls3.agent-manifest/v2` would force a migration for no data change.
- **Validation additions (#34):** each reference must resolve to a listed integration and a non-experimental (unless explicitly allowed) paid operation; `tools` must be non-empty if present; `tools_budget.max_spend_per_hire` and `max_spend_per_day` are positive integers in stroops, with `max_spend_per_hire` recommended `≤ price`. Credentials stay out of the manifest, as before.
- **Pinning.** A hire records `manifestVersion` (ADR-0004 decision 4), so it runs the exact tool set it was paid for. A deployed version is immutable: adding or removing a tool creates a new version.

### D3. The runtime exposes a closed tool set

**Decision.** The runtime (#20) gains a **tool-calling loop**, and the model can only choose from the tool set pinned in the manifest.

Today the runtime is a single text-in/text-out call: `ModelRuntime.complete(RuntimeTask)` returns a `String`, with no loop ([`runtime_task.dart`](../../puls3_server/lib/src/runtime/runtime_task.dart)). Tool calling adds:

1. **Tool definitions to the model.** The provider adapters (`AnthropicRuntime`, `WorkersAiRuntime`) send the generated tool definitions alongside the system prompt.
2. **A bounded loop.** Call the model → if it asks for a tool, execute it → append the tool result as a message → call again. The loop is bounded by a step count and by the runtime timeout, which must now also cover the tool calls (see [D6](#d6-fixed-price-with-a-cap-tool-costs-are-the-builders) and the ADR-0005 D3 invariant).
3. **An executor behind a domain port.** A new `ProviderPaymentPort` (domain) with an adapter in `puls3_server` performs the x402 call: read the 402 terms, check the policy ([D7](#d7-server-enforced-limits-now-contract-enforced-on-mainnet)), sign, retry, and return the provider's JSON to the model. The escrow relay is not involved.
4. **Failure mapping.** A provider error, a refused payment or a cap hit becomes a **tool error** the model can react to; it never crashes the run. If the run still cannot produce a result, it fails exactly as today: `runtimeStatus = failed`, and the hire stays `funded` until the client rejects or the job expires (ADR-0005 D1).

**Closed set, fixed endpoints.** The model selects a **tool name** and supplies **arguments**; it never supplies a URL, an HTTP method, a `payTo`, an asset, or an amount. The server maps the tool name to a fixed method + path + base URL from the pinned integration manifest. This is the primary prompt-injection defence.

### D4. x402 is the provider rail, not the hire rail

**Decision.** The hire rail is **unchanged**: a consumer funds an ERC-8183 escrow job and the escrow pays the agent (ADR-0005). x402 is used **only** for agent→provider API calls, paid from the agent's wallet.

- This is the same split the peers use: ERC-8183 escrow for jobs, x402 for pay-per-call (spike §1, §5).
- It resolves the ADR-0003 conflict by scope: "no x402 in the MVP" becomes "no x402 for the **hire** rail," which stays true.
- The provider payment is a **SAC `transfer`** from the agent's custodied G-account to the provider's `payTo`, executed through the x402 facilitator (which assembles the transaction and pays the XLM fee). The agent needs USDC, not XLM.

### D5. Payment client: Dart-native target, sidecar as a Phase-1 fallback

**Decision.** The x402 client is **Dart-native** wherever possible, behind the `ProviderPaymentPort`; a **testnet-only, x402-only TypeScript sidecar** is allowed as the Phase-1 fallback if the Dart path cannot be proven in a 2-day experiment. A **facilitator** settles in both cases.

The x402 client has three parts:

| Part | Needs the agent key? | Today |
|---|---|---|
| (a) 402 negotiation and `PaymentPayload` encode/decode | No | Not implemented |
| (b) Sign a SAC `transfer` **authorization entry** with the agent's custodied key | **Yes** | Not implemented — the codec only relays node-provided `SOURCE_ACCOUNT` entries and has never built an `ADDRESS_V2` entry |
| (c) Call a facilitator's `/verify` and `/settle` | No | Not implemented |

- **(b) is the crux and the risk.** `stellar_dart` is proven for envelope decode/re-encode, the network transaction hash, and ed25519 verification (#96), but **not** for constructing and signing an `ADDRESS_V2` `SorobanAuthorizationEntry`. The server's `EnvelopeCodec` deliberately throws `UnsupportedAuthorization` for anything that is not `SOURCE_ACCOUNT` ([`envelope_codec.dart`](../../puls3_server/lib/src/ledger/envelope_codec.dart)). x402 is the opposite case: the facilitator is the transaction source, and the agent signs only the auth entry.
- **Go/no-go experiment (first 2 days of Phase 1).** Prove that `stellar_dart` (or the existing hand-written `XdrWriter`) can build and sign an `ADDRESS_V2` SAC `transfer` auth entry and round-trip it through an x402 `PaymentPayload` against the testnet facilitator. **Pass →** Dart-native, no sidecar, consistent with ADR-0001/ADR-0003. **Fail →** Phase 1 uses the sidecar.
- **Sidecar shape (only if the experiment fails).** `@x402/fetch` + `@x402/stellar` `ExactStellarScheme` behind the same `ProviderPaymentPort`, on the same host/private network, receiving the agent secret over a local channel and never logging it. Testnet only; a recorded security debt to remove before mainnet. This is the only thing that would re-introduce a sidecar that ADR-0003's amendment removed.
- **Facilitator.** Testnet: `https://x402.org/facilitator` (no API key, `stellar:testnet`). Mainnet: OZ Channels (`https://channels.openzeppelin.com/x402`, API key) or self-facilitation. The facilitator is orthogonal to signing — it verifies and settles; it is not an alternative to the client's signature.

**Time and risk:**

| Option | Time (Phase 1) | Risk | Verdict |
|---|---|---|---|
| Dart-native (`stellar_dart` + hand-written x402 payload) | 3–5 days incl. tests | Medium–high: auth-entry construction unproven; the x402 payload format is TypeScript-defined and may drift | **Target**, gated by the 2-day experiment |
| TypeScript sidecar (whole x402 call) | ~1 day | Low protocol risk; high key-handling risk; a second runtime, contradicts ADR-0001/ADR-0003 | **Phase-1 fallback**, testnet only |
| Dart signing + hosted facilitator | 2–3 days | Medium: still needs (b); removes the payload-format risk if the facilitator accepts a bare signed entry | Sub-option of the target if the experiment half-passes |
| "Just a facilitator" | — | — | **Not an option:** the facilitator still needs the client's signature |

### D6. Fixed price with a cap; tool costs are the builder's

**Decision.** The agent's manifest `price` stays **fixed** and already includes expected tool costs plus margin. Tool spend is bounded by a **per-hire cap** and a **per-day cap**; **tool costs are the builder's**, never the consumer's, and they never touch the escrow.

- **Consumer exposure is fixed.** The consumer funds exactly `price` into the escrow. The escrow amount is set at `create_job`/`fund` and paid on `complete`; nothing the agent does with tools can increase it. ERC-8183 has no partial refund on `complete`, so a pass-through ("price + actual tool costs") would require a non-standard max-funding-and-refund extension, contrary to ADR-0005 D1's conformance rule. **Rejected for the MVP.**
- **Builder exposure is capped.** `tools_budget.max_spend_per_hire` bounds what one run can pay providers; `max_spend_per_day` bounds a day across hires. When a cap is hit, the runtime stops calling tools and the agent must deliver with what it has, or the run fails. The builder eats the difference between tool spend and price — that is the builder's pricing decision, surfaced in the Studio with an estimate.
- **What happens to the escrow when a tool call fails or costs more than expected: nothing.** Tool payments are off-escrow. A failed tool call is either retried (bounded) or returned to the model as a tool error; a run that still produces no result sets `runtimeStatus = failed` and the hire stays `funded`. The refund path is unchanged (ADR-0005 D1): the client `reject`s, or the tracker `claim_refund`s after `expired_at`. **Tool spend already incurred is a builder loss, bounded by the cap.** No partial or stranded escrow state is possible from a tool call.
- **Tool float.** x402 pays **at call time**, before the escrow's `complete`, so the agent wallet must hold a USDC **tool float** funded by the builder (or from prior payouts). The Studio shows the required float. On testnet it is seeded. This is a new consequence for #18/#35.
- **Platform fee unchanged.** 0 bps (ADR-0005 D7). A future puls3 fee on provider payments would be a separate decision.

### D7. Server-enforced limits now, contract-enforced on mainnet

**Decision.** In Phase 1 the **server** enforces the spending limits and the allow-list; before mainnet they move to the **agent's smart account**. This is the concrete mechanism #82 asks for.

- **Phase 1 (testnet): server-enforced.** Before signing each provider payment, the tool executor's `ProviderPaymentPolicy` checks:
  1. `payTo` is in the integration's `allowedPayTo` for the network;
  2. `asset` is the configured USDC SAC and `network` is the server's network;
  3. the operation is declared in the **pinned** manifest version;
  4. `hireToolSpend + amount ≤ max_spend_per_hire`;
  5. `dayToolSpend + amount ≤ max_spend_per_day`.
  A failure is returned to the model as a tool error; no signature is produced. The counters are server-side and per agent.
- **Phase 2 (mainnet): contract-enforced.** Move agent wallets to **smart accounts (C-accounts) with a policy signer** that enforces per-payment and rolling-24h caps and a payee allow-list, so a compromised server cannot overspend. This is exactly what ADR-0003 decision 4 and the #7 spike require before mainnet (prior art: eunomia). Phase 1's server checks then become defence in depth, not the only gate.
- **Prompt injection.** The model cannot create endpoints, `payTo`s or amounts. Mitigations: a closed tool set ([D3](#d3-the-runtime-exposes-a-closed-tool-set)); arguments validated against the JSON Schema; tool results delimited and labelled as data, never instructions; the caps bound the blast radius; the provider list is curated and verified ([D8](#d8-provider-identity-and-networks)). No tool can return a secret or sign an arbitrary transaction.
- **Who sets the caps.** The builder sets `tools_budget` in the manifest; the server applies a hard ceiling from configuration. Caps are validated so that `max_spend_per_hire ≤ price` is recommended (and enforced if the product owner wants the consumer's economics to be guaranteed).

### D8. Provider identity and networks

**Decision.** A provider is described by an **ERC-8004 registration file** with a `services` entry (the API endpoint and OpenAPI URL) and `x402Support: true`, optionally backed by an on-chain Identity Registry entry (reusing ADR-0002's registry). Listing is **curated** in Phase 0/1: puls3 verifies the 402 handshake, the OpenAPI document, the `payTo`, the asset and the price before listing. On-chain identity is a signal, not proof.

- **Provider ≠ puls3 agent.** A provider can hold an ERC-8004 agent identity, but the Integrations directory reads registration files; it does not require a new registry. The drop-in caveat from ADR-0002/ADR-0005 D5 still applies (puls3 registrations are not indexed by Stellar 8004 tooling).
- **Networks.** The integration manifest declares per-network `baseUrl` and `payment`; the runtime **refuses** a `stellar:pubnet` operation on a testnet server and vice versa. A provider that is mainnet-only (as TIA's live API is) must offer a **testnet endpoint or a documented mock** to take part before mainnet. TIA publishes a testnet handshake host, so it can take part now.
- **Mainnet is Phase 2** and is blocked until the smart-account limits of [D7](#d7-server-enforced-limits-now-contract-enforced-on-mainnet) exist, per ADR-0003.

## Alternatives considered

1. **Keep agents prompt-only; no integrations (status quo).** Rejected: the demo agents that need real data (Ledger Scout, Market Pulse, Remit Pilot) stay fake, and puls3 misses the three-sided market the LATAM research (#80) targets.
2. **A new puls3 API-description format.** Rejected: builders and providers would rewrite their OpenAPI, and every existing tool (OpenAPI editors, validators, codegen) would be useless. Reuse OpenAPI and add one overlay.
3. **Inline full tool definitions in the agent manifest.** Rejected: the manifest would carry provider configuration, grow, and change the hash on every provider edit. References keep it stable.
4. **Pass-through pricing (consumer pays actual tool costs).** Rejected for the MVP: ERC-8183 fixes the budget and has no partial refund; it would need a non-standard extension and would expose the consumer to unbounded cost. Fixed price with a cap keeps the consumer's maximum equal to the escrow amount.
5. **A TypeScript sidecar as the plan (not a fallback).** Rejected as the target: it re-introduces a second runtime and moves a key across a boundary, against ADR-0001/ADR-0003. Kept only as the Phase-1 fallback if the Dart experiment fails.
6. **Pay providers directly from the escrow.** Rejected: the escrow is the consumer→agent rail (ADR-0005) and has no concept of third-party payees; mixing them would change the contract and its audit surface.
7. **Contract-enforced caps from day one.** Rejected for Phase 1: smart accounts and a policy contract are a Phase-2 prerequisite (ADR-0003); server enforcement on testnet is enough while no real money is at risk.
8. **No allow-list, rely on reputation.** Rejected: reputation does not stop a prompt-injected agent from paying an attacker's address; the allow-list is the hard boundary.

## What this supersedes or amends

ADR-0003, ADR-0004 and ADR-0005 are not edited in place; this ADR amends them as follows.

| Document | Part | Effect |
|---|---|---|
| [ADR-0004](0004-agent-manifest-and-deployment.md) | Decision 2 (MVP agents prompt-only; `tools` reserved and rejected) | **Amended:** `tools` is allowed and validated; manifests without `tools` hash unchanged |
| ADR-0004 | Decision 6 (test runs; puls3 pays the LLM cost) | **Amended:** a test run may call tools under the same caps; because a draft has no agent wallet, test runs use the provider's testnet/free handshake or a mock, and their tool cost is bounded by the existing daily quota. Owner and exact rule are an [open decision](#open-decisions) |
| ADR-0004 | Amendment (#34) decision 1 (builder brings the model account) | **Amended:** the builder also brings the **tool float** (funds the agent wallet for provider payments) |
| [ADR-0003](0003-payment-rail-and-custody.md) | Decision 1 and alternative 1 (x402 out of the MVP) | **Amended by scope:** x402 is in for **agent→provider** calls; the **hire rail** stays ERC-8183 (ADR-0005) |
| ADR-0003 | Decision 4 (smart accounts with spending limits before mainnet) | **Affirmed and extended:** a Phase-2 prerequisite; Phase-1 tool limits are server-enforced |
| ADR-0003 | Decision 5 amendment (no sidecar; the fallback is pure Dart) | **Amended:** a testnet-only, x402-only TypeScript sidecar is allowed as the Phase-1 fallback if the Dart auth-entry experiment fails; the target stays Dart-native |
| [ADR-0005](0005-align-agent-commerce-with-erc-8183-and-erc-8004.md) | D1 (escrow), D7 (fee 0), D10 (no hooks) | **Unchanged:** tool payments are off-escrow; the escrow holds only the hire price |
| ADR-0005 | D3 (timeout invariant) | **Affirmed and extended:** runtime timeout + approval window < `expired_at`, and the runtime timeout must now also cover the tool loop |
| [Spike: payments and wallets](../spikes/payments-and-wallets.md) (#7) | §1 (x402 out), §4 ("not needed for the MVP") | **Amended:** §4's conclusion no longer holds; the Dart x402 gap becomes the [D5](#d5-payment-client-dart-native-target-sidecar-as-a-phase-1-fallback) experiment |
| [Vision](../vision.md) | §6 In / Out | **Additive:** an Integrations directory and tool-using agents are a post-MVP extension (Phase 1+) |
| [LATAM market research](../research/latam-b2b-market.md) | "x402 and MPP Session are not part of the MVP" | **Amended for x402 only:** x402 becomes the provider rail (Phase 1+); MPP stays out |

## Consequences

### Impact by issue

| Issue | Impact |
|---|---|
| **#20** Agent runtime | New tool-calling loop; tool definitions sent to providers; a `ProviderPaymentPort` executor; policy checks; tool errors mapped without failing the run; the runtime timeout covers the tool loop |
| **#34** Domain | `AgentManifest` gains `tools` and `tools_budget` with validation; a new `IntegrationManifest` value object; the `ProviderPaymentPort`; integer/stroop rules as for `price` |
| **#35** Studio | Pick tools per agent; set caps; show an estimated tool cost and the required float; test runs under the same caps |
| **#37** UI | An Integrations directory (listing only in Phase 0); tool selection on the agent form; per-hire tool activity in the hire detail |
| **#15** Demo seed | Ledger Scout, Market Pulse and Remit Pilot can be rewritten on real provider data instead of being replaced |
| **#30** Configuration | Facilitator URL, USDC SAC per network, provider allow-list, cap ceilings, the sidecar flag |
| **#55** Escrow contract | **No interface change.** The D3 invariant must leave room for the tool loop |
| New | The Integrations directory and provider verification; the `ProviderPaymentPort` adapter; the sidecar (only if the experiment fails) |

- Builders can create agents on real third-party data, and providers earn per call without integrating with puls3.
- The consumer's cost is still bounded by the fixed escrow price; the builder carries the tool-cost risk, bounded by the caps.
- Mainnet is blocked until the smart-account limits exist, so the riskiest combination (a tool-using agent with a server-held key) stays on testnet.
- The Dart x402 gap is a real, time-boxed risk; the sidecar is a deliberate, temporary escape hatch.

## Phased plan

Estimates are developer-days for one developer; they include tests. "Fits before Oct 14" is judged against the Serverpod demo deadline without putting the MVP at risk.

| Phase | Scope | Estimate | Fits before Oct 14? |
|---|---|---|---|
| **Phase 0** | Integrations directory and the integration-manifest schema (docs + listing only, **no calls**); provider verification checklist | 2–3 | **Docs only.** The app listing waits until after the demo |
| **Phase 1** | Tool calling with x402 on **testnet**, per-hire cap: the 2-day Dart experiment; the tool loop; the `ProviderPaymentPort` executor (Dart or sidecar); policy checks; Studio fields; tests. Target: HackMeridian (Oct 25) | 10–15 | **No.** It touches the runtime, the domain and the Studio, and would put the demo at risk |
| **Phase 2** | **Mainnet**: smart-account spending limits and policy; a mainnet facilitator; provider ERC-8004 registration; audits | 15–25 | **No.** Post-HackMeridian |

**Recommendation:** ship **Phase 0 docs** before Oct 14 at most, and only if it does not compete for demo time. Start Phase 1 after the Serverpod demo, with the Dart experiment first so the sidecar decision is made early.

## Acceptance

Per #82, this ADR is Proposed until the **product owner** and the owners of **#20** and **#35** confirm in the PR that the decision is workable. The open questions below do not block that confirmation; they block implementation.

## Open decisions

1. **Cap defaults and ceilings.** The default `max_spend_per_hire` and `max_spend_per_day`, and the server hard ceiling. Recommended starting point: `max_spend_per_hire ≤ price`, `max_spend_per_day` a small multiple of the price.
2. **Test-run tool cost.** Who pays a tool call made from a test run, and whether test runs may call paid endpoints at all (recommended: testnet/free handshake or mock only).
3. **A puls3 fee on provider payments.** Not decided; the escrow fee (0 bps) does not apply off-escrow.
4. **Provider listing gate.** Whether Phase 1 requires an on-chain ERC-8004 registration or only the curated off-chain listing (recommended: curated listing in Phase 1, on-chain in Phase 2).
5. **The Dart experiment outcome.** Dart-native vs the testnet sidecar; decided by the 2-day experiment, recorded here when it lands.
