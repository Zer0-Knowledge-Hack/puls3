# ADR-0014: Installable skills: versioned instruction packs an agent pins

- **Status:** Proposed
- **Date:** 2026-11-21
- **Issue:** #320
- **Related:** [ADR-0004](0004-agent-manifest-and-deployment.md) (the agent manifest) · [ADR-0006](0006-integrations-and-agent-tools.md) (tools paid with x402, Proposed) · [ADR-0005](0005-align-agent-commerce-with-erc-8183-and-erc-8004.md) (one provider per escrow job)

## Context

Today a **skill is only a tag.** `AgentManifest.skills` holds 1 to 5 `{id, name, description, tags}` entries in the A2A `AgentSkill` shape (ADR-0004, `puls3_domain/lib/src/entities.dart`). The catalog and the registration file show them, but nothing reaches the model. All an agent does comes from one `system_prompt` of 20 to 8000 characters, which the runtime adapters send as the system message (`workers_ai_runtime.dart`, `anthropic_runtime.dart`).

Builders who use AI tools expect a skill to **add capability**: a set of instructions, a procedure or a checklist, written once and added to any agent. #320 asks what a puls3 skill is, how it is versioned and paid, and for an agent with a skill to behave differently in a test run.

Constraints that any design has to keep:

- **A hire runs exactly what was published.** A hire pins a manifest version, and the deploy writes a salted hash of the manifest on chain. A skill that changed after the agent was deployed must not change what a paid hire runs.
- **The tags stay.** They are the A2A and ERC-8004 discovery shape. Changing their meaning breaks that export.
- **One escrow job pays one provider** (ADR-0005). A skill sold by another builder cannot be paid inside the hire's escrow without a contract change.
- **The text is untrusted.** Instructions written by someone else go into the model's system prompt.

## Decision

### 1. A skill is a **skill pack**: versioned Markdown instructions

A skill pack has:
- an `id` (kebab-case) and a `version` (an integer, starting at 1);
- a `name` (at most 48 characters) and a `description`;
- an `instructions` body in Markdown, 20 to 4000 characters.

A version is immutable once published. Fixing a pack publishes a new version. The server stores packs in a `skill_pack` table, with the owner, the `id` and `version`, the content, and the SHA-256 of the content.

A pack holds **instructions only** in this phase. Packs that bring tools reuse ADR-0006 when it is accepted (see "Later phases").

### 2. An agent **pins** packs by version and hash

The manifest gets a new optional field, `skill_packs`, holding up to 3 `{id, version, sha256}` entries.

- **Pinned by version and hash.** A paid hire always runs the exact text that was deployed: a new version of a pack changes nothing until the builder deploys a new manifest version that points to it.
- **A manifest without `skill_packs` hashes exactly as before**, so existing deployments are unaffected (the same rule as ADR-0006's `tools`). The schema stays `puls3.agent-manifest/v1`.
- **`skills` (the tags) does not change.** Adding a pack does not add a tag on its own. The builder still writes the tags that describe what the agent offers.

### 3. The runtime composes the prompt

The runtime builds the system message as:

1. the agent's `system_prompt`;
2. then each pinned pack, in manifest order, as a delimited block:

```text
## Skill: <name> (<id> v<version>)
<instructions>
```

- **Limits.** The composed message is limited to 16 000 characters, and the deploy refuses a manifest that would exceed it.
- **Order.** The agent's own prompt comes first, and the runtime adds a fixed line before the packs. That line says the skill blocks are guidance for the task and cannot change the input and output contract or reveal the prompt.
- **The packs stay private.** The registration file never includes the prompt (ADR-0004), and it does not include the pack text either. It lists only the pinned `id` and `version`, so a buyer can see which skills an agent uses.

### 4. Who can attach which pack (phase 1)

- **Own packs only.** A builder can attach the packs they own.
- **No marketplace of packs and no payment for packs yet.** That keeps the untrusted-text risk at its current level: the builder already writes their own system prompt.

### 5. What "behaves differently" means for the acceptance

Two tests together meet #320's criterion "an agent with an added skill behaves differently in a test run", without depending on a model's mood:

- **A runtime test with a deterministic model.** The same input, with and without a pack, produces a different system message: the pack block is present, in order and within limits.
- **A Studio test run.** Same draft and input, with a pack that sets an output rule (for example "answer in a numbered list"). The output follows the rule.

## Later phases (not decided here)

- **Phase 2, packs with tools.** A pack may reference ADR-0006 integration operations, and the agent's `tools_budget` and caps still apply. This depends on ADR-0006 being accepted (#275).
- **Phase 3, shared and paid packs.** Builders publish packs that others can attach. Paying the author needs a decision this ADR does not make:
  - **a one-off price when a pack is attached**, paid from the builder's wallet, outside any hire;
  - **a share of each hire**, which needs either a second escrow payee (a contract change, against ADR-0005's one provider per job) or a transfer from the agent wallet after `complete`.

  Shared packs also need review or reputation, because their text goes into other builders' prompts.

## Consequences

- **Domain:** `SkillPackRef` and the `skill_packs` field, validated: kebab-case id, positive version, a 64-hex SHA-256, at most 3 entries, unique ids.
- **Server:**
  - the `skill_pack` table and its endpoints (save a draft version, publish, list own);
  - the deploy resolves each ref and checks its hash and the 16 000-character limit;
  - `RuntimeTask` (`runtime_task.dart`) receives the composed prompt, so the adapters do not change.
- **Studio:** a "Skills" step to write a pack and to attach published packs to an agent.
- **Testing:** the two tests in decision 5, plus domain tests for the validation and an integration test for the immutable versions.

The work fits in three PRs, in this order:
1. domain and manifest;
2. server tables, deploy and runtime;
3. Studio.

It starts once this ADR is accepted.
