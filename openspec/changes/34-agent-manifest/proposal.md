# Proposal: AgentManifest domain model and validation (issue #34)

## Intent

- The Studio (#35, #37), runtime (#20) and deploy flow (#18) all need one shared definition of an agent manifest. Today `Agent`, `agent_metadata.dart` and the Flutter `agent_draft.dart` each define their own rules.
- Product decision: every agent uses exactly one LLM. The builder picks it once, when building the agent. It is either free (Cloudflare Workers AI, provider `workers-ai`) or paid, using the builder's own key (BYOK, e.g. `anthropic`, `openai`). Hirers choose nothing. Changing the model counts as editing the agent and creates a new manifest version.

## Scope

### In Scope
- New `puls3_domain/lib/src/manifest.dart`, exported from the barrel:
  - `ModelId {provider, id}`. Provider and model shape behavior, so they are part of the hashed manifest. The builder's key (BYOK) is NOT part of the manifest: a reference to it lives in the deploy record (#18, #35), next to the salt and the agent wallet. This way the builder can rotate the key without a new version. The rule "a paid provider needs a stored credential" is checked at deploy time, not in the domain. This follows bnbagent-sdk's "no plaintext secrets in config" invariant.
  - An injected `ModelPolicy` holds the allowed Workers AI ids and the enabled paid providers. It is config, not code.
  - `ManifestVersion` (>= 1; first deploy is 1, each later deploy is n+1, no skips).
  - `AgentManifestDraft` with nullable fields named as in `api.md:277`. It has no version.
  - `validate(policy, version)` returns an immutable `AgentManifest` or throws `InvalidManifest`.
  - `fromJson`/`toJson`, which reject unknown keys and give `tools` its own problem.
  - Canonical JSON: UTF-8, sorted keys, no whitespace, no floats.
- Draft tolerance:
  - Accepted in a draft: missing fields and texts below their minimum length.
  - Rejected in a draft: wrong types or shapes, values above a maximum, `tools`, and unknown keys.
  - Required fields and minimums are enforced only by validate-for-deploy.
- Lengths are counted in runes. Whitespace-only text counts as empty. Stored values are never trimmed. `Skill` is reused unchanged.
- `errors.dart`: a `ManifestProblem` enum and `InvalidManifest(List<ManifestProblem>)` that collects every problem, not just the first.
- Docs:
  - Amend ADR-0004 with the model/provider decision. Also record a deliberate change from ADR-0004 line 32: the salted hash moves to the server (#18).
  - `docs/domain/model.md`: glossary, diagram, invariants I23+.
  - The example JSON switches to the new model shape and gains a free `workers-ai` example.
  - `api.md:277`: remove `version` from the draft.

### Out of Scope
- Persistence (#35), UI (#37), runtime adapters (#20), credential custody (server), hash and salt (#18), deriving `Agent` from a manifest (follow-up).

## Capabilities

### New Capabilities
- `agent-manifest`: draft and deployable manifest, the model policy, validation problems, versioning, JSON and canonical form.

### Modified Capabilities
None.

## Approach

This follows exploration approach A: additive types in a new file, so there is no conflict with PR #120 (`entities.dart`). Validation collects every problem into one list. `ModelPolicy` is passed in as a parameter, so `puls3_domain` keeps zero runtime dependencies. This stays within ADR-0001: no `package:crypto`, no Serverpod/Flutter/Stellar SDK.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `puls3_domain/lib/src/manifest.dart` | New | Types, validation, JSON, canonical form |
| `puls3_domain/lib/src/errors.dart` | Modified | `ManifestProblem`, `InvalidManifest` |
| `puls3_domain/lib/puls3_domain.dart` | Modified | Export |
| `puls3_domain/test/manifest_test.dart` | New | Grouped by invariant (I23+) |
| `docs/adr/0004-...md`, `docs/domain/model.md`, `docs/architecture/api.md`, `docs/architecture/examples/` | Modified/New | Docs |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Over the 400-line budget (estimated ~800 lines including tests) | High | Chained PRs, see the delivery note below |
| `api.md` lists `version` on the draft, which contradicts the "drafts have no version" decision | Med | Fix in the docs task. `DraftVersionConflict` stays a storage concern |
| Rules duplicated across `Agent`, the manifest and the server | Med | Follow-up to derive `Agent` from the manifest |
| A deploy accepts a paid-provider manifest with no stored credential | Med | Deploy check in #35/#18 (documented in the ADR-0004 amendment); the domain exposes `ModelPolicy.isPaid(provider)` for it |

## Rollback Plan

Revert the commits. The change is additive, has no consumers yet, and needs no data migration.

## Delivery note

The estimate is over budget and no delivery strategy has been chosen yet. A possible 3-PR chain:
1. Value objects, draft/validate and errors, with tests.
2. JSON and canonical form, plus example-parsing tests.
3. Docs and the ADR amendment.

## Success Criteria (issue #34)

- [ ] The #33 example, updated to the new model shape, parses and validates as deployable, and so does the `workers-ai` example.
- [ ] Every spike-table rule is enforced, all problems are reported together, and `tools` and unknown keys are rejected.
- [ ] Model policy: a `workers-ai` model outside the allowlist fails, a disabled paid provider fails, and the manifest JSON has no credential field (unknown key).
- [ ] Canonical JSON is deterministic and has sorted keys.
- [ ] `dart analyze --fatal-infos` and `dart test` pass in `puls3_domain`, which has zero runtime dependencies.
- [ ] ADR-0004 amendment, `model.md` and `api.md` are updated.

## Proposal question round

All decisions were approved before this phase. Resolved after it: the BYOK credential reference stays outside the hashed manifest (deploy record), and the design follows bnb-chain/bnbagent-sdk where possible, adapted to Stellar and keeping ERC-8004 / ERC-8183.
