# ADR-0004: Agent manifest and deployment

- **Status:** Proposed
- **Date:** 2026-09-26
- **Issue:** #33
- **Research:** [Spike: agent definition and deployment](../spikes/agent-definition.md)
- **Related:** [ADR-0001](0001-system-architecture.md) (who signs what) · [ADR-0002](0002-agent-registry-on-soroban.md) (Identity Registry) · ADR-0003 (#7, payment rail and custody — pending)

## Context

puls3 must create its own supply of agents, so the Agent Studio needs a precise definition of what an agent is and what "Deploy" does. Without it, the domain (#34), the endpoints (#35), the runtime (#20), the registration flow (#18) and the Studio UI (#37) would each invent their own shape. Builders may also not want their prompts to be public.

## Decision

1. **An agent is a manifest** (`puls3.agent-manifest/v1`): `version`, `name`, `description`, `skills`, `model`, `system_prompt`, `input`, `output`, `price`. Field rules are in the [spike, question 1](../spikes/agent-definition.md#1-agent-manifest-which-fields-define-an-agent); an example is in [`agent-manifest.example.json`](../architecture/examples/agent-manifest.example.json). Prices are integers in USDC stroops.
2. **MVP agents are prompt-only.** No tools. A `tools` field is reserved and rejected by validation.
3. **Hybrid storage, private prompt:**
   - the full manifest (with `system_prompt`) and its salt live only in the Serverpod database;
   - a public ERC-8004 registration file, **without the prompt**, is served over HTTPS and its URL is the agent's `agent_uri`;
   - on-chain metadata holds `puls3.manifestHash` (SHA-256 of `salt || canonical_json`, 32 bytes) and `puls3.manifestVersion`.
4. **Deployed versions are immutable.** Editing creates a new version; each hire records and runs the version it was paid for.
5. **Deploy steps:** validate → store version and hash → create agent wallet → `register_full` (builder signs) → `set_agent_wallet` (builder and agent wallet authorize) → confirm via RPC → publish the registration file and activate. Steps 3 and 5 follow [ADR-0003](0003-payment-rail-and-custody.md): the server creates a custodied agent account, and `set_agent_wallet` uses the agent account as transaction source plus the builder's `signAuthEntry`.
6. **Test runs** use the same runtime path with no payment and no on-chain writes; puls3 pays the LLM cost; 20 runs per builder per day to start.

## Consequences

| Issue | Impact |
|---|---|
| **#13** Identity Registry | **No interface change.** Uses `register_full` and `set_metadata` with the keys `puls3.manifestHash` and `puls3.manifestVersion`, both within ADR-0002's limits (key ≤ 64 chars, value ≤ 4,096 bytes) |
| **#18** Register agent flow | Implements deploy steps 3–7, with the signing described in ADR-0003 |
| **#20** Agent runtime | Loads the manifest by `(agent_id, manifestVersion)`, runs prompt-only tasks, enforces `input.max_chars` and `output.max_chars`, and exposes the test-run path without payment |
| **#34** AgentManifest domain model | Implements the manifest type, the validation rules (spike, question 1), the canonical JSON form, and the salted hash, in pure Dart |
| **#35** Agent Studio endpoints | Drafts CRUD, test run (with the daily quota and typed "quota exceeded" error), deploy, and new version. Never returns `system_prompt` to anyone but the owner |
| **#37** Agent Studio UI | Form fields map 1:1 to the manifest. Shows the version and deploy status per step, and warns that edits create a new version |
| **#15** Demo seed | Seeded agents must be prompt-only. *Ledger Scout*, *Market Pulse* and *Remit Pilot* need tools as described today: rewrite them to take data as input, or replace them |

- A builder can prove later which exact prompt an agent ran (reveal manifest + salt, recompute the hash), without publishing it now.
- The public registration file makes puls3 agents readable by ERC-8004 / Stellar 8004 tooling, as ADR-0002 intends.
- Our server is a single point of availability for registration files in the MVP; the on-chain hash keeps them verifiable if they move to IPFS later.

## Alternatives considered

1. **Whole manifest on-chain.** Maximally transparent, but publishes every prompt, costs rent on every byte (Soroban TTL), and makes edits expensive. Rejected: prompt privacy is a requirement.
2. **Fully off-chain, nothing on-chain.** Simplest, but nobody could verify that the agent they paid ran the version it advertised. Rejected: the on-chain commitment is cheap (two metadata entries).
3. **Unsalted hash.** Simpler, but short or templated prompts could be confirmed by brute force from the public hash. Rejected: a 32-byte salt costs nothing.
4. **Agents as generated code (BNB Agent Studio's model).** More powerful, but code is harder to review, version, and sandbox than a declarative manifest, and it would need a code runtime before the Serverpod deadline. Rejected for the MVP.
5. **Tools in the MVP.** Enables the chain-reading demo agents, but needs sandboxing and wallet spending limits before custody (#7) is decided. Deferred.
