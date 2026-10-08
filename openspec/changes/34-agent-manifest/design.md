# Design: AgentManifest domain model and validation (#34)

## Technical Approach

Exploration approach A. The change adds types to a new `puls3_domain/lib/src/manifest.dart` and puts its errors in `errors.dart`. It does not touch `entities.dart` (open PR #120). The layering follows bnbagent-sdk:

- **Protocol**: ERC-8004 identity and ERC-8183 jobs (contracts, `Agent`, `Hire`).
- **Product**: the declarative manifest, which holds no secrets.
- **Serving**: the server deploy record, which holds the BYOK credential ref, salt and hash (#18, #35).

The domain stays pure Dart and uses only `dart:convert` (ADR-0001).

## Architecture Decisions

| # | Decision | Choice | Rejected | Rationale |
|---|---|---|---|---|
| D1 | Draft vs deployable | `AgentManifestDraft` (nullable, no version) → `validate(policy, version)` → immutable `AgentManifest` | One class with a status | Each type states what is guaranteed. Matches `api.md:277` minus `version` |
| D2 | One check pass | A private `_check(fields, {forDeploy, policy})` walks the fields in a fixed order and collects problems into an ordered, deduplicated list | Fail-fast factories (the `Agent` style) | All problems are reported together, the order is deterministic, and draft and deploy share one code path |
| D3 | Draft tolerance | `forDeploy:false` skips only *missing* and *below-minimum*. Wrong type or value, above-maximum, duplicates, `tools`, unknown keys and `version` are always rejected | Lenient drafts | Proposal rule; a draft can still be stored as long as it has the right shape |
| D4 | Model | `ModelId{provider,id}` sits in the manifest. The `ModelPolicy` is injected. There is no credential field | A credential ref in the manifest | Rotating the key needs no new version. Follows the bnbagent rule "no secrets in config". `isPaid(provider)` is used by the deploy-time credential check (#18/#35) |
| D5 | Policy semantics | `workers-ai` passes only if the id is in `workersAiModels`. A paid provider passes if it is in `paidProviders`, with any id (BYOK) | An allowlist for paid model ids | The builder owns the paid model choice. The config is still "not code" |
| D6 | Versioning | `ManifestVersion` (>=1, `first`, `next()`). `AgentManifest.toDraft()`. The caller passes `latest?.next() ?? ManifestVersion.first` | The domain assigns versions | Only storage knows the latest version. "No skips" stays a server invariant |
| D7 | Dart vs wire names | Dart fields are flat camelCase, as in `api.md`. The JSON is nested snake_case, as in the example file | A flat wire format | The wire matches the spike and the example (hash input). Dart matches the Serverpod models. See the mapping below |
| D8 | Parsing | `fromJson(Object? json)` never throws a type error. Every mismatch becomes a problem, and parse problems are merged with the D2 problems | `as` casts / `FormatException` | All problems are reported together, including those from bad JSON |
| D9 | Canonical | `jsonEncode(_sortKeysDeep(toJson()))`. Keys are sorted by `String.compareTo`. Any `double` throws `StateError` | A hand-written writer; `package:crypto` | `jsonEncode` already emits no whitespace and keeps insertion order. All keys are ASCII, so UTF-16 order equals code point order (JCS-compatible for this subset). Hashing moves to #18 |
| D10 | Text rules | Length counts `runes`. `trim().isEmpty` counts as missing. Stored text is never trimmed | UTF-16 `length` | Matches `agent_metadata.dart` (server) |
| D11 | Skills | Reuse `Skill` unchanged. JSON items map `InvalidSkill` to manifest problems. Skill items must be complete in drafts too | A new `ManifestSkill` | No change to `entities.dart`. Incomplete rows stay in UI state |
| D12 | Error family | `ManifestVersion` and `ModelId` also throw `InvalidManifest([problem])` | A separate error type for each | Callers handle one type for manifest input |
| D13 | Fixtures | Tests read `../docs/architecture/examples/*.json`. The CI path filter adds `docs/architecture/examples/*` → domain | Copies under `test/fixtures` | One source of truth. Editing the docs re-runs the domain tests |

## Interfaces / Contracts

```dart
final class ModelId { factory ModelId({required String provider, required String id}); } // provider kebab ≤32, id non-blank, no whitespace, ≤128 runes
final class ModelPolicy {
  ModelPolicy({required Set<String> workersAiModels, required Set<String> paidProviders}); // ArgumentError if paid contains 'workers-ai'
  static const freeProvider = 'workers-ai';
  bool allows(ModelId m); bool isPaid(String provider); // provider != freeProvider
}
final class ManifestVersion implements Comparable<ManifestVersion> {
  factory ManifestVersion(int value); static final first; ManifestVersion next(); final int value;
}
enum InputType { text }  enum OutputType { text, markdown }
final class AgentManifestDraft {
  factory AgentManifestDraft({String? name, String? description, List<Skill>? skills, ModelId? model,
    String? systemPrompt, InputType? inputType, int? inputMaxChars, OutputType? outputType,
    int? outputMaxChars, UsdcAmount? price}); // throws InvalidManifest (draft mode)
  factory AgentManifestDraft.fromJson(Object? json);
  List<ManifestProblem> problemsForDeploy(ModelPolicy policy); // test-run gate (spike §6)
  AgentManifest validate(ModelPolicy policy, ManifestVersion version); // throws InvalidManifest
  Map<String, Object?> toJson(); // nulls omitted, no version
}
final class AgentManifest { // same fields, non-null, plus version; value equality on canonical form
  factory AgentManifest.fromJson(Object? json, ModelPolicy policy); // needs version
  AgentManifestDraft toDraft(); Map<String, Object?> toJson(); String toCanonicalJson();
}
```

**Mapping**: `systemPrompt`↔`system_prompt`; `inputType/inputMaxChars`↔`input{type,max_chars}`; `outputType/outputMaxChars`↔`output{...}`; `price`↔`price{asset:"USDC",amount}`; `model`↔`model{provider,id}`. `schema` is optional on input and must equal `puls3.agent-manifest/v1`; it is always emitted.

## Problems (`ManifestProblem` → rule)

| Problem | Rule | Mode |
|---|---|---|
| `notAnObject`, `unknownKey` (any level, e.g. `credential`) | ADR-0004 §1 | always |
| `toolsNotSupported` | spike §2 | always |
| `versionInDraft` | drafts have no version | always |
| `schemaUnsupported` | spike row `schema` | always |
| `versionInvalid` | `version` ≥1 | always |
| `{name,description,systemPrompt}Malformed` / `TooLong` | 48 / 280 / 8,000 | always |
| `{name,description,systemPrompt}Missing` / `TooShort` | 3 / 10 / 20 | deploy |
| `skillsMalformed`, `skillsTooMany` (>5), `skillIdNotKebabCase`, `skillNameLength`, `skillIdDuplicate` | spike row `skills`, I6 | always |
| `skillsMissing` (null or empty) | 1–5 | deploy |
| `modelMalformed` | `{provider,id}` | always |
| `modelMissing`, `modelProviderNotEnabled`, `modelNotAllowed` | allowlist (config) | deploy |
| `inputMalformed`, `inputTypeUnsupported`, `inputMaxCharsTooHigh` (>8,000) | spike row `input` | always |
| `inputMissing`, `inputMaxCharsTooLow` (<1, new) | — | deploy |
| `output*` (same set; `text|markdown`, >16,000) | spike row `output` | as input |
| `priceMalformed` (float, negative, >2⁵³−1), `priceAssetUnsupported` | spike row `price`, I2 | always |
| `priceMissing`, `priceNotPositive` | > 0 | deploy |

## Data Flow

    Studio JSON ─→ AgentManifestDraft.fromJson ─(draft problems)─→ InvalidManifest
                          │ ok: saveDraft (#35)
    deploy: latest?.next() ?? first ─→ draft.validate(policy, v) ─→ AgentManifest
                          │ toCanonicalJson ─→ server: sha256(salt‖utf8) (#18)
    edit:   AgentManifest.toDraft() ─→ ... ─→ validate(policy, n+1)

## File Changes

| File | Action |
|---|---|
| `puls3_domain/lib/src/manifest.dart` | Create |
| `puls3_domain/lib/src/errors.dart` | Modify: `ManifestProblem`, `InvalidManifest(List)` |
| `puls3_domain/lib/puls3_domain.dart` | Modify: export |
| `puls3_domain/test/manifest_test.dart` | Create |
| `docs/architecture/examples/agent-manifest.example.json` | Keep: it already uses `{provider,id}` and `version`. It is used as a fixture for `AgentManifest.fromJson` |
| `docs/architecture/examples/agent-manifest.workers-ai.example.json` | Create: `@cf/meta/llama-3.3-70b-instruct-fp8-fast` (illustrative, set by config) |
| `.github/workflows/ci.yml` | Modify: `docs/architecture/examples/*` → domain=true |
| `docs/adr/0004-*.md`, `docs/domain/model.md`, `docs/architecture/api.md` | Modify |

The docs changes:

- **ADR-0004 amendment**:
  - The model is one `{provider,id}` per agent, either free `workers-ai` or BYOK paid.
  - `ModelPolicy` is injected.
  - The credential ref lives in the deploy record. The deploy checks `isPaid` → a stored credential exists.
  - Changing the model creates a new version.
  - The hash and salt move from #34 to #18 (line 32).
  - Drafts have no version.
- **model.md**: glossary entries for Manifest, Draft, ModelId, ModelPolicy and ManifestVersion; a diagram node; invariants I23–I32.
- **api.md:277**: drop `version` from the draft and note the wire mapping.

## Testing Strategy (strict TDD, `dart test` in puls3_domain)

The test file has one group per invariant. A new matcher `problems(List<ManifestProblem>)` uses `contains` in single-rule tests and `equals` in the all-at-once test.

| Group | Covers |
|---|---|
| I23 ModelId / I24 ModelPolicy | shape; allowlist hit/miss; disabled paid; `isPaid` |
| I25 ManifestVersion | <1 rejected; `first`; `next` |
| I26 Draft tolerance | empty draft ok; below-min ok; above-max, `tools`, unknown, `version` rejected |
| I27 Text | runes (emoji), whitespace-only = missing, no trimming |
| I28–I31 Field rules | name/desc/prompt, skills, input/output, price (float, 0, asset) |
| I32 Deploy | all problems together, fixed order; both example files validate |
| Canonical | sorted keys, no whitespace, deterministic, round trip `fromJson(toJson)`, no doubles |

## Threat Matrix

N/A: there is no routing, shell, subprocess, VCS/PR automation or process boundary. The security-relevant rule (no credential or tools in the manifest) is covered by `unknownKey`/`toolsNotSupported` tests.

## PR Slices (authored lines incl. tests)

1. Errors, ModelId, ModelPolicy, ManifestVersion: ~200.
2. Draft, AgentManifest, `_check`, validate: ~400 (Medium risk).
3. JSON, canonical form, workers-ai example, CI filter, fixture tests: ~380.
4. Docs (ADR amendment, model.md, api.md): ~120.

Total ~1,100, which is above the proposal's ~800 estimate.

## Migration / Rollout

The change is additive and has no consumers. No migration is required.

## Open Questions

- [ ] Rune vs UTF-16: `Skill` name (I6) still counts `length` (left unchanged because of #120).
- [ ] Skill description and tag limits are still undefined (exploration Q11).
- [ ] `ModelId` caps (32/128) and `max_chars ≥ 1` are new rules. They need confirmation in the spec.
- [ ] Problems carry no path (for example, which skill). The current UI does not need it.
