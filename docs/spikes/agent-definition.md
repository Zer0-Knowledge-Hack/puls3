# Spike: agent definition and deployment for Agent Studio

- **Issue:** #33 · **Time-box:** 2 days · **Date:** 2026-09-26
- **Decision record:** [ADR-0004](../adr/0004-agent-manifest-and-deployment.md)
- **Example:** [`agent-manifest.example.json`](../architecture/examples/agent-manifest.example.json)

## Question

The backlog covers an agent's on-chain identity (#6, #13) and its registration (#18), but not **what an agent is** (its behavior) or **how it is deployed** so the runtime (#20) can run it. This spike answers the seven questions in #33.

Since #33 was written, [Stellar 8004](https://github.com/trionlabs/stellar-8004) turned out to already offer ERC-8004 registries on Soroban (see [ADR-0002](../adr/0002-agent-registry-on-soroban.md)). puls3 still has to create its own supply of agents, so the Studio stays central.

## Summary

- An agent is a **manifest**: a small JSON document the builder writes in the Studio. The MVP manifest is **prompt-only**: no tools.
- The manifest is **private and off-chain** (in the Serverpod database). What goes public is a **registration file** without the prompt, served over HTTPS, whose URL is the agent's `agent_uri` on-chain. The chain also stores a **salted hash** of the full manifest, so anyone can later check that the agent ran the version it committed to, without the prompt ever being published.
- Deployed versions are **immutable**. Editing creates a new version; a hire always runs the version it was paid for.
- Deploy = validate → store the version → create the agent wallet → register on-chain → confirm → activate. **Who signs the agent-wallet step is pending ADR-0003 (#7).**

## 1. Agent manifest: which fields define an agent?

The builder writes these fields. Names follow the app's existing `AgentDraft` (`puls3_flutter/lib/src/domain/agent_draft.dart`); skills follow the A2A `AgentSkill` shape so they can be exported as an A2A Agent Card later.

| Field | Type | Rules (enforced by the domain, #34) |
|---|---|---|
| `schema` | string | Always `puls3.agent-manifest/v1` |
| `version` | integer | Starts at 1, +1 on every deployed change |
| `name` | string | 3–48 chars |
| `description` | string | 10–280 chars. Public |
| `skills` | array of `{ id, name, description, tags }` | 1–5 items; `id` is kebab-case, unique in the manifest |
| `model` | `{ provider, id }` | Must be in the server's model allowlist (config, not code) |
| `system_prompt` | string | 20–8,000 chars. **Private** |
| `input` | `{ type, max_chars }` | MVP: `type` is `text`; `max_chars` ≤ 8,000 |
| `output` | `{ type, max_chars }` | MVP: `type` is `text` or `markdown`; `max_chars` ≤ 16,000 |
| `price` | `{ asset, amount }` | `asset` is `USDC`; `amount` is an **integer in stroops** (7 decimals), > 0. Never a float |

Fields the builder does **not** write are kept outside the manifest, in the deployment record: `agent_id` and `agent_wallet` (known after registration), `salt`, timestamps, and status.

**Why this set:** it is exactly what the Studio form already asks for (name, description, model, system prompt, skills, price), plus the input/output contract that the runtime (#20) and the hire flow (#19) need to reject oversized requests before anyone pays. Temperature and similar knobs are left out on purpose: they are model-specific, and several current models no longer accept them.

## 2. Tools: can agents call tools in the MVP?

**No. MVP agents are prompt-only:** they receive text and return text.

- **Security:** an agent that can call HTTP or sign Stellar operations needs sandboxing, egress rules, and spending limits on its wallet. The custody model (#7) is not decided yet, and a tool-calling agent with a server-held key is the riskiest combination.
- **Time:** tool calling adds a loop, timeouts, and error handling to the runtime (#20) before the Serverpod deadline.
- **Demo impact:** some demo agents in `puls3_flutter/assets/mock/demo_agents.json` describe tool-dependent work: *Ledger Scout* and *Market Pulse* read live chain data, *Remit Pilot* compares anchor routes. For the MVP they either take the data as input text (the user pastes it) or are replaced in the seed set (#15). *Copy Forge*, *Invoice Clerk*, *Soroban Auditor*, *Support Relay* and *Data Weaver* work as prompt-only agents.

Tools are the first post-MVP extension: a `tools` field is reserved in the schema and rejected by validation until then.

## 3. Where does the manifest live?

**Hybrid, with the prompt kept private.**

| Where | What | Why |
|---|---|---|
| **Serverpod database** (private) | The full manifest of every version, including `system_prompt`, plus its `salt` | Builders may not want their prompts public, and the runtime needs them |
| **Public registration file** (HTTPS, served by our server) | ERC-8004 registration file: `type`, `name`, `description`, `services` (the puls3 endpoint), `x402Support`, `active`, plus a `puls3` block with `skills`, `price`, `model` and `manifestVersion`. **No prompt** | Discovery by any ERC-8004 / Stellar 8004 client ([EIP-8004 registration file](https://eips.ethereum.org/EIPS/eip-8004)) |
| **On-chain** (Identity Registry, #13) | `agent_uri` = URL of the registration file. Metadata `puls3.manifestHash` = SHA-256 of the canonical manifest with its salt (32 bytes). Metadata `puls3.manifestVersion` = the version | A tamper-evident commitment: the builder can prove later which exact prompt ran, without revealing it now |

**Prompt privacy decision:** the system prompt is **never published** — not on-chain, not in the registration file, not in API responses to anyone but its owner. The hash is **salted** (32 random bytes kept in the database) so a short or guessable prompt cannot be confirmed by brute force from the public hash.

**Canonical form** for the hash: UTF-8 JSON with keys sorted and no whitespace. The manifest contains only strings, integers, arrays and objects (no floats), so this is unambiguous. Hash input: `salt || canonical_json`. SHA-256 is available both in Soroban (`env.crypto().sha256`, [docs](https://docs.rs/soroban-sdk/latest/soroban_sdk/crypto/struct.Crypto.html)) and in pure Dart ([`package:crypto`](https://pub.dev/packages/crypto)).

This needs **no change to the Identity Registry interface**: `set_metadata` and `register_full` already take arbitrary keys (≤ 64 chars) and byte values (ADR-0002).

## 4. Versioning: editing a deployed agent with hires in flight

- A deployed version is **immutable**. Editing opens a new draft; nothing changes until it is deployed.
- Deploying version *n+1* writes the new `puls3.manifestHash` and `puls3.manifestVersion` on-chain (builder signs, as for any metadata change) and switches **new** hires to it.
- Every hire records the `manifestVersion` and `manifestHash` it was created with. **A hire always runs the version it was paid for**, including its price and prompt.
- The server keeps old versions while any hire references them. Hires are short tasks in the MVP, so this is a small set.
- Pausing an agent sets `active: false` in the registration file and stops new hires; in-flight hires still finish.

## 5. Deployment: the exact steps, and who signs

| # | Step | Who acts / signs | Status |
|---|---|---|---|
| 1 | Validate the manifest (#34) | Server (domain rules) | Decided |
| 2 | Store it as version *n*, generate the salt, compute `manifestHash` | Server | Decided |
| 3 | Create the agent wallet | **Pending ADR-0003 (#7)**: server-held key vs. smart account | ⏳ |
| 4 | Register on-chain: `register_full(caller = builder, agent_uri, [puls3.manifestHash, puls3.manifestVersion])` | **Builder's wallet** signs (ADR-0001 §4) | Decided |
| 5 | Point payments at the agent wallet: `set_agent_wallet(builder, agent_id, agent_wallet)` | Builder **and** the agent wallet authorize (ADR-0002). **How the agent wallet's authorization is produced is pending ADR-0003** | ⏳ |
| 6 | Confirm steps 4–5 with RPC `getTransaction`, read `agent_id` from the `Registered` event | Server (read only) | Decided |
| 7 | Publish the registration file, mark the version active in the runtime | Server | Decided |

If step 4 or 5 fails, the version stays in `pending` and the Studio shows the error; retrying repeats from the failed step. Steps 4 and 5 can go in one transaction only if ADR-0003 lets the server attach the agent wallet's auth entry to the builder's transaction; otherwise they are two.

**This question is deliberately left open** until #7 decides custody. Everything else in this spike is independent of that decision.

## 6. Test run (playground)

- The Studio sends the **draft** manifest and a test input to a test-run endpoint (#35). The draft must pass validation (step 1) first.
- It uses the **same runtime path** as a paid hire (#20), but with no payment, no on-chain write, and nothing stored beyond a usage counter.
- **puls3 pays** the LLM cost of test runs from its own provider key, never from the agent's wallet: the agent has no wallet until it is deployed.
- **Limits** (initial values, tuned after the demo): 20 test runs per builder per day, the manifest's `input.max_chars`, and a per-run timeout. Over the limit, the endpoint returns a typed error and the Studio shows when the quota resets.

## 7. Prior art

| Project | How it defines an agent | What we take |
|---|---|---|
| [BNB Agent Studio](https://www.bnbchain.org/en/blog/bnb-agent-studio-is-live-on-bnb-chain-ai-agents-from-one-prompt) (BNB Chain, July 2026) | The builder describes the agent in one prompt from a coding tool; the Studio scaffolds code, deploys it to a managed runtime (AWS Bedrock AgentCore), registers an ERC-8004 identity, binds a wallet, and registers an ERC-8183 task interface. Agents pay their own LLM bills over x402 | The deploy pipeline shape (identity + wallet + runtime in one action). We differ: puls3 agents are declarative manifests, not generated code, so they are reviewable and versionable |
| [ERC-8004 registration file](https://eips.ethereum.org/EIPS/eip-8004) | Public JSON behind `agentURI`: `name`, `description`, `image`, `services` (endpoints such as A2A or web), `x402Support`, `active`, `registrations`, `supportedTrust`. The URI may be `ipfs://`, `https://` or `data:` | Our public registration file follows it, so Stellar 8004 tooling can read puls3 agents |
| [A2A Agent Card](https://a2a-protocol.org/latest/specification/) (spec 1.0.0) | `name`, `description`, `url`, `version`, `capabilities`, `skills` (each with `id`, `name`, `description`, `tags`, `examples`), input and output modes | The skill shape, and input/output declared up front |
| [GAME by Virtuals](https://docs.game.virtuals.io/game-overview) ([architecture](https://whitepaper.virtuals.io/about-virtuals/agentic-framework-game/architecture-of-agents)) | An agent has a goal and a description (personality) that drive a high-level planner, plus workers made of functions (tools) | Confirms goal/description as the core of an agent. Its tool-driven planning is what we leave for after the MVP |

## Open questions

1. **Agent wallet authorization at deploy** (question 5, steps 3 and 5): decided by ADR-0003 (#7).
2. **Model allowlist for the MVP:** the Studio lists five models today; which ones the runtime (#20) supports first is a #20 decision.
3. **Registration file hosting:** served by the Serverpod web server (simplest) vs. pinned to IPFS (survives our server going down). The MVP uses our server; the on-chain hash keeps it verifiable either way.
4. **Who can read the prompt later:** only the owner in the MVP. Whether a builder can opt in to publishing it (e.g. for audited agents) is a product decision for after the MVP.
