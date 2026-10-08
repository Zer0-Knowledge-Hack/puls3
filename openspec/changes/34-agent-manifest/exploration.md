# Exploration: AgentManifest domain model and validation (#34)

## Sources

- ADR-0004 (`docs/adr/0004-agent-manifest-and-deployment.md`) delegates field rules to the spike: "Field rules are in the spike, question 1" (line 15).
- Spike: `docs/spikes/agent-definition.md` (field table lines 26-35, versioning lines 69-73, hash and deploy lines 61-63 and 87).
- Example manifest from #33: `docs/architecture/examples/agent-manifest.example.json` (Copy Forge, version 1, 3 skills, `anthropic`/`claude-sonnet-5`, markdown output `max_chars` 8000, price 3000000 stroops). It satisfies every rule below.

## Normative rules

ADR-0004:

1. Manifest schema `puls3.agent-manifest/v1` with `version, name, description, skills, model, system_prompt, input, output, price`; prices are integer USDC stroops (line 15).
2. MVP agents are prompt-only; a `tools` field is reserved and must be rejected (line 16; spike lines 24, 49).
3. Deployed versions are immutable; an edit creates a new version; each hire records and runs the version it paid for (line 21).
4. #34 owns the manifest type, validation rules, canonical JSON form and salted hash, in pure Dart (line 32).
5. Hash = SHA-256 of `salt || canonical_json` (32 bytes, 32-byte random salt); metadata keys `puls3.manifestHash`, `puls3.manifestVersion`; value limit 4,096 bytes (lines 20, 29).
6. The system prompt is only returned to the owner (line 33). Adapter rule, not a domain rule.
7. The runtime enforces `input.max_chars` / `output.max_chars`; test runs require a draft that passes validation (lines 23, 31; spike line 91).

Spike field table (lines 26-35):

8. `schema` is always `puls3.agent-manifest/v1`.
9. `version`: integer, starts at 1, +1 on every deployed change.
10. `name`: 3-48 chars.
11. `description`: 10-280 chars, public.
12. `skills`: 1-5 items of `{id, name, description, tags}`; `id` kebab-case and unique within the manifest.
13. `model`: `{provider, id}`, in the server allowlist ("config, not code").
14. `system_prompt`: 20-8,000 chars, private.
15. `input`: `{type, max_chars}`, type `text`, `max_chars` <= 8,000.
16. `output`: `{type, max_chars}`, type `text` or `markdown`, `max_chars` <= 16,000.
17. `price`: `{asset, amount}`, asset `USDC`, integer stroops > 0, never a float.
18. Outside the manifest (deployment record): `agent_id`, `agent_wallet`, `salt`, timestamps, status.

Versioning and deploy (spike lines 61-73, 87):

19. Editing a deployed agent opens a new draft; nothing changes until it is deployed.
20. Deploying n+1 affects only new hires; hires record `manifestVersion` and `manifestHash`.
21. Canonical form: UTF-8 JSON, sorted keys, no whitespace, no floats.
22. Deploy validates, then stores the version and hash; failures after that leave the version `pending`.

## Current `puls3_domain`

Zero runtime dependencies (`pubspec.yaml` lines 10-13). Reusable pieces:

- `Skill` (`entities.dart:7-29`): kebab-case `id`, `name` 1-48, `description`, `tags`.
- `Agent` (`entities.dart:34-96`): enforces name 3-48, description 10-280, 1-5 unique skills, price > 0 (lines 54-71), duplicating manifest rules.
- `UsdcAmount` (`values.dart:7-35`): `stroops` accepts 0..2^53-1, so "price > 0" must be explicit.
- `Hire.manifestVersion` (`entities.dart:152`): plain `int` >= 1.
- Errors (`errors.dart:5-12, 64-100`): `sealed class DomainError`, one `XProblem` enum plus `final class InvalidX(problem)` per rule group.
- Tests (`test/entities_test.dart`): `group('I6 Skill', ...)` by invariant number, typed `problem<E, P>` matcher.
- `docs/domain/model.md`: glossary lines 11-13, Mermaid diagram lines 25-82, invariants I1-I22 lines 99-122.

## Overlaps

- `puls3_server/lib/src/agent/agent_metadata.dart` agrees on name, description, skills and price limits, but counts runes (line 76) and does no model allowlist check (line 65).
- `puls3_flutter/lib/src/domain/agent_draft.dart:2-18` is a flat draft without input/output schema or version; moving it to the domain type belongs to #37.
- Open PR #120 adds `AgentDetails` to `entities.dart` for shared draft/published rules; #34 should own that concept and live in a new file to avoid conflicts.
- No `openspec/specs` capability covers manifests; this change introduces `agent-manifest`.
- `docs/architecture/api.md:43-49, 277, 349` already names `AgentManifestDraft` (fields `version, name, description, skills, model, systemPrompt, inputType, inputMaxChars, outputType, outputMaxChars, price`) and `InvalidManifest`; "client validation mirrors ADR-0004; saveDraft is authoritative".

## Open product questions

1. Model allowlist source (injected set vs domain constant) and MVP model ids.
2. Draft shape (nullable-field `AgentManifestDraft` vs status on one class).
3. Which fields may be missing in a draft; whether present-but-invalid values are rejected in drafts.
4. Error reporting: all problems at once vs fail-fast.
5. Version assignment (domain vs server), drafts carrying a version, edits with no change.
6. Deployed as a separate type vs a state; whether `pending` is modeled in the domain.
7. Hash and canonical JSON in scope (needs `package:crypto`, breaking zero-dependency) or deferred.
8. Salt generated by the domain (injected randomness) or received.
9. `fromJson` in the domain; handling of unknown keys.
10. Length counting (runes vs UTF-16), trimming, whitespace-only text.
11. Skill description/tag limits; alignment with existing `Skill`.
12. Whether `Agent` should be derived from a manifest.

## Approaches

**A (recommended).** New `manifest.dart` with value objects, `AgentManifestDraft` (nullable fields), `AgentManifest` (deployable), `InvalidManifest` with a problem list; JSON and canonical form included; hash deferred. Additive, no conflict with #120. About 330-400 authored lines.

**B.** Extend `Agent` with a draft state in `entities.dart`. Fewer files, but mixes on-chain fields into drafts and conflicts with #120.

## Risks

- Rule duplication across `Agent`, the manifest and server constants.
- Review budget is near 400 lines; adding the hash and `package:crypto` grows it.
- Rune vs UTF-16 mismatch with the server.
- ADR-0004 is still `Proposed` (line 3).
