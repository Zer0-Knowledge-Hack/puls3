# Agent Manifest Specification

## Purpose

Defines, in the pure-Dart `puls3_domain` package, the one shared model of what an agent is: an editable draft, a validated immutable deployable manifest, the model policy, the validation problems, versioning, JSON and the canonical form. The Studio (#35, #37), the runtime (#20) and the deploy flow (#18) all use it. Field rules come from the spike `docs/spikes/agent-definition.md` (question 1) and ADR-0004.

> **Scope:** the domain holds no hash, no salt, no credential and no persistence. The salted SHA-256 hash, the builder credential reference (for any provider: builders always run on their own account, demo agents excepted) and the "the provider needs a stored credential" check belong to the server deploy flow (#18, #35). `puls3_domain` keeps zero runtime dependencies.

## ADDED Requirements

### Requirement: Draft shape and tolerance

`AgentManifestDraft` MUST have nullable fields named as in `docs/architecture/api.md` (`name`, `description`, `skills`, `model`, `systemPrompt`, `inputType`, `inputMaxChars`, `outputType`, `outputMaxChars`, `price`) and MUST NOT have a version. Building a draft (directly or through `fromJson`) MUST accept missing fields and texts below their minimum length. It MUST reject wrong types or shapes, values above a maximum, a non-positive `inputMaxChars` or `outputMaxChars` (malformed, not incomplete), a `tools` key, and unknown keys. Required fields and minimums MUST be enforced only by validate-for-deploy.

#### Scenario: S1 Empty draft is accepted

- GIVEN a draft with no fields set
- WHEN it is built
- THEN no error is raised

#### Scenario: S2 Below-minimum texts are accepted in a draft

- GIVEN a draft with `name` of 1 character, `description` of 3 characters and `systemPrompt` of 5 characters
- WHEN it is built
- THEN no error is raised

#### Scenario: S3 Above-maximum values are rejected in a draft

- GIVEN a draft whose `name` has 49 characters, or whose `systemPrompt` has 8,001, or whose `inputMaxChars` is 8,001, or whose `outputMaxChars` is 16,001
- WHEN it is built
- THEN it fails with `InvalidManifest` listing the matching problem for each such field

#### Scenario: S4 Wrong types are rejected in a draft

- GIVEN JSON where `name` is a number, `skills` is a string, or `price.amount` is a string or a non-integral number such as `1.5`
- WHEN `AgentManifestDraft.fromJson` is called
- THEN it fails with `InvalidManifest` listing a wrong-type problem for each such field
- AND an integral number written with a decimal point, such as `price.amount` `3000000.0`, is accepted as that integer

### Requirement: Validate for deploy

`AgentManifestDraft.validate(policy, version)` MUST return an immutable `AgentManifest`, or throw `InvalidManifest` listing every violated rule. It MUST enforce: every field present; `schema` equal to `puls3.agent-manifest/v1`; the field rules of the following requirements; and the model policy. The returned manifest MUST NOT be modifiable after creation, including its skill and tag lists.

#### Scenario: S5 Complete valid draft becomes a manifest

- GIVEN a draft with every field valid and an allowed model
- WHEN `validate(policy, ManifestVersion(1))` is called
- THEN it returns an `AgentManifest` with `schema` `puls3.agent-manifest/v1` and version 1

#### Scenario: S6 Missing fields fail validation

- GIVEN a draft with no fields set
- WHEN `validate` is called
- THEN it fails with `InvalidManifest` containing one missing-field problem per required field (name, description, skills, model, system prompt, input type and max chars, output type and max chars, price)

#### Scenario: S7 Manifest is immutable

- GIVEN a validated `AgentManifest`
- WHEN a caller tries to add to its skills list or a skill's tags
- THEN the operation throws and the manifest is unchanged

### Requirement: Text length rules

Lengths MUST be counted in Unicode runes (code points), not UTF-16 units. Text that is empty or only whitespace MUST count as empty. Stored values MUST NOT be trimmed. At deploy: `name` MUST be 3 to 48, `description` 10 to 280 and `system_prompt` 20 to 8,000 runes. Whitespace-only text MUST count as length 0 for the minimum check, while a text with content keeps its full length, including surrounding whitespace, for the maximum check.

#### Scenario: S8 Name and description boundaries

- GIVEN texts of exactly 3 and 48 runes for `name`, and 10 and 280 for `description`
- WHEN validated for deploy
- THEN they pass
- AND texts of 2 or 49 runes (`name`), 9 or 281 (`description`) fail with a length problem for that field

#### Scenario: S9 System prompt boundaries

- GIVEN a `system_prompt` of exactly 20 and exactly 8,000 runes
- WHEN validated for deploy
- THEN both pass
- AND 19 or 8,001 runes fail with a length problem

#### Scenario: S10 Runes, not UTF-16 units

- GIVEN a `name` of 3 emoji (each one rune, two UTF-16 units)
- WHEN validated for deploy
- THEN the name passes

#### Scenario: S11 Whitespace-only counts as empty and nothing is trimmed

- GIVEN a `name` of 10 spaces, and another `name` of `"  abc  "`
- WHEN both are validated for deploy
- THEN the first fails the name length problem
- AND the second passes and the manifest keeps the exact value `"  abc  "`

### Requirement: Skills

`skills` MUST contain 1 to 5 items. Each item MUST be a `Skill` as defined today (kebab-case `id`, `name` of 1 to 48), reused without changing `Skill`. Skill ids MUST be unique within the manifest. A skill that `Skill` rejects MUST surface as a manifest problem naming the skill and the cause, not as a thrown `InvalidSkill`.

#### Scenario: S12 Skill count boundaries

- GIVEN 1 skill, and separately 5 skills
- WHEN validated for deploy
- THEN both pass
- AND 0 skills or 6 skills fail with a skill count problem

#### Scenario: S13 Duplicate skill ids

- GIVEN two skills with the same `id`
- WHEN validated for deploy
- THEN validation fails with a duplicate skill id problem

#### Scenario: S14 Invalid skill

- GIVEN a skill whose `id` is `Not Kebab` and another whose name is empty
- WHEN validated for deploy
- THEN `InvalidManifest` lists each distinct skill problem kind once (the problem carries no skill index)

### Requirement: Model and model policy

`ModelId` MUST have exactly `provider` and `id`, and MUST NOT have any credential field. `provider` MUST be kebab-case of at most 32 characters. `id` MUST be non-blank, contain no whitespace and be at most 128 runes. `ModelPolicy` MUST reject construction when its paid providers include `workers-ai`. `ModelPolicy` MUST be injected into validation (never a domain constant) and hold the allowed `workers-ai` model ids and the enabled paid providers. `ModelPolicy.isPaid(provider)` MUST be true for any provider other than `workers-ai`. Validation MUST accept a `workers-ai` model only if its id is in the allowed list, a paid provider only if it is enabled, and MUST reject any other provider. The domain MUST NOT check credentials; that is a deploy-time server check.

#### Scenario: S15 Allowed workers-ai model

- GIVEN a policy allowing `workers-ai` id `@cf/meta/llama-3.3-70b-instruct-fp8-fast`
- WHEN a draft with that model is validated
- THEN no model problem is reported

#### Scenario: S16 workers-ai model outside the allowlist

- GIVEN a policy that does not list the model id
- WHEN a draft with provider `workers-ai` and that id is validated
- THEN validation fails with a model-not-allowed problem

#### Scenario: S17 Disabled or unknown paid provider

- GIVEN a policy enabling only `anthropic`
- WHEN drafts with provider `openai` and with provider `acme` are validated
- THEN each fails with a provider-not-enabled problem
- AND a draft with provider `anthropic` and a non-empty id passes the model check

#### Scenario: S18 isPaid

- GIVEN any policy
- WHEN `isPaid` is called with `workers-ai`, `anthropic` and `openai`
- THEN it returns false, true and true

#### Scenario: S41 ModelId shape

- GIVEN a provider that is kebab-case of 32 characters, and an id of 128 runes without whitespace
- WHEN a `ModelId` is created
- THEN it is accepted
- AND a provider of 33 characters or not kebab-case, or an id that is empty, blank, contains whitespace or has 129 runes, fails with `InvalidManifest` containing the model-malformed problem

#### Scenario: S42 workers-ai cannot be a paid provider

- GIVEN a `ModelPolicy` whose `paidProviders` contains `workers-ai`
- WHEN it is created
- THEN it throws `ArgumentError`

#### Scenario: S19 No credential field

- GIVEN manifest or draft JSON whose `model` object has an extra key such as `credential` or `api_key`
- WHEN `fromJson` is called
- THEN it fails with an unknown-key problem and the output of `toJson` never contains a credential

### Requirement: Input, output and price

At deploy: `input.type` MUST be `text` and `input.max_chars` MUST be an integer from 1 to 8,000. `output.type` MUST be `text` or `markdown` and `output.max_chars` MUST be an integer from 1 to 16,000. `price.asset` MUST be `USDC` and `price.amount` MUST be an integer of stroops (7 decimals) greater than zero. Numbers are integers by value: an integral number written with a decimal point (such as `3000000.0`) MUST be accepted as that integer, because Flutter web (dart2js) cannot tell `3.0` from `3` and validation MUST NOT depend on the platform. A non-integral number (such as `1.5`), NaN, infinity, or a value beyond ±(2^53−1) MUST be rejected. The price MUST use the existing `UsdcAmount`.

#### Scenario: S20 Input boundaries

- GIVEN `max_chars` of 1 and 8,000 with type `text`
- WHEN validated for deploy
- THEN both pass
- AND 0, 8,001 or type `markdown` fail with an input problem

#### Scenario: S21 Output boundaries

- GIVEN `max_chars` of 1 and 16,000 with type `text` or `markdown`
- WHEN validated for deploy
- THEN they pass
- AND 0, 16,001 or type `html` fail with an output problem

#### Scenario: S22 Price must be positive stroops

- GIVEN amount 1 and amount 3,000,000
- WHEN validated for deploy
- THEN both pass
- AND amount 0, a negative amount, or a non-integral JSON number such as `1.5` fail (zero and negative with a price problem, the non-integral number with a wrong-type problem)
- AND `3000000.0` passes, as the integer 3,000,000

#### Scenario: S23 Price asset

- GIVEN `price.asset` of `XLM`
- WHEN validated for deploy
- THEN validation fails with a price asset problem

#### Scenario: S43 Max chars below one

- GIVEN `inputMaxChars` or `outputMaxChars` of 0 or a negative number
- WHEN a draft is built or validated for deploy (draft and deploy modes both reject it)
- THEN it fails with the matching max-chars-too-low problem (restates S20 and S21)

### Requirement: Tools are reserved

A `tools` key MUST be rejected in every JSON input, draft or manifest, with its own problem that is distinct from the generic unknown-key problem. There MUST be no `tools` field on the Dart types.

#### Scenario: S24 tools rejected

- GIVEN JSON with `"tools": []`
- WHEN `AgentManifestDraft.fromJson` or `AgentManifest.fromJson` is called
- THEN it fails with `InvalidManifest` containing the tools-not-supported problem
- AND that problem is not the unknown-key problem

### Requirement: Error aggregation

`InvalidManifest` MUST carry a list of `ManifestProblem` values covering every violation found in one call, not only the first. The list MUST be in a deterministic order (field order of the manifest, then problem kind within skills) and MUST be non-empty. `InvalidManifest` MUST be a `DomainError` with a readable message.

#### Scenario: S25 All problems at once

- GIVEN a draft with a 2-rune name, a 5-rune description, 0 skills, a disallowed model, a zero price and `inputMaxChars` of 0 (a non-positive or above-maximum limit is already rejected when a draft is built, see S3 and S43, so this case is reached through `AgentManifest.fromJson`)
- WHEN `validate` is called
- THEN the thrown `InvalidManifest` lists all six problems in one list

#### Scenario: S26 Stable order

- GIVEN the same invalid input validated twice
- WHEN both `InvalidManifest` errors are compared
- THEN their problem lists are equal in content and order

### Requirement: Versioning

`ManifestVersion` MUST be an integer of at least 1; a lower value MUST be rejected. The first deploy MUST use version 1. Editing a deployed manifest of version n MUST yield a draft (without a version) whose next deploy is version n+1, with no skipped numbers. Drafts MUST NOT carry a version, and the version MUST be given only to `validate`.

#### Scenario: S27 Version lower bound

- GIVEN versions 0 and -1
- WHEN a `ManifestVersion` is created
- THEN it is rejected
- AND version 1 is accepted

#### Scenario: S28 First deploy is 1

- GIVEN a new draft that was never deployed
- WHEN the first deploy version is requested
- THEN it is `ManifestVersion(1)`

#### Scenario: S29 Edit of deployed n deploys n+1

- GIVEN a deployed `AgentManifest` of version 3
- WHEN it is turned back into a draft and the next version is requested
- THEN the draft has no version and the next version is `ManifestVersion(4)`
- AND the version 3 manifest is unchanged

### Requirement: JSON round-trip

`AgentManifest.toJson` MUST produce the snake_case document of the spike table: `schema`, `version`, `name`, `description`, `skills` (each `id`, `name`, `description`, `tags`), `model` (`provider`, `id`), `system_prompt`, `input` (`type`, `max_chars`), `output` (`type`, `max_chars`), `price` (`asset`, `amount`). `AgentManifest.fromJson` MUST validate with a policy and accept this document. `AgentManifestDraft.fromJson` and `toJson` MUST use the same keys without `schema` and `version`. Both `fromJson` methods MUST reject unknown keys at every level with an unknown-key problem (a single `unknownKey` problem per document; the problem does not carry the key name). `fromJson` of a manifest MUST reject a `schema` other than `puls3.agent-manifest/v1`.

#### Scenario: S30 Manifest round-trip

- GIVEN a valid `AgentManifest`
- WHEN `AgentManifest.fromJson(manifest.toJson(), policy)` is called
- THEN the result equals the original in every field

#### Scenario: S31 Draft round-trip

- GIVEN a partial draft
- WHEN `AgentManifestDraft.fromJson(draft.toJson())` is called
- THEN the result has the same fields set and the same fields missing

#### Scenario: S32 Unknown keys

- GIVEN JSON with an unknown key at the top level, inside `skills[0]`, `input` or `price`
- WHEN `fromJson` is called
- THEN it fails with `InvalidManifest` containing a single `unknownKey` problem for the document, however many unknown keys it holds

#### Scenario: S33 Wrong schema

- GIVEN manifest JSON with `schema` of `puls3.agent-manifest/v2`
- WHEN `AgentManifest.fromJson` is called
- THEN it fails with a schema problem

### Requirement: Canonical JSON

The manifest MUST expose a canonical form: UTF-8 bytes of the JSON with object keys sorted (by code unit, at every depth), no whitespace between tokens, array order preserved, and integers only: an integral number is written as an integer (`3.0` as `3`), while a non-integral number, NaN, infinity or a value beyond ±(2^53−1) MUST be rejected. The same manifest MUST always give identical bytes, independent of how it was built or the key order of the input JSON. The domain MUST NOT compute a hash or accept a salt; those belong to the server (#18).

#### Scenario: S34 Sorted keys, no whitespace

- GIVEN a valid manifest
- WHEN its canonical form is decoded as text
- THEN it contains no whitespace outside string values
- AND at every object level the keys appear in sorted order (`description` before `input`, `schema` before `skills`, `amount` before `asset`)

#### Scenario: S35 Deterministic

- GIVEN the same manifest JSON parsed from two documents with different key order and spacing
- WHEN both canonical forms are produced
- THEN the bytes are identical

#### Scenario: S36 Non-ASCII text

- GIVEN a `name` containing `é` and an emoji
- WHEN the canonical form is produced
- THEN the text is encoded as UTF-8 and decodes to the same string

#### Scenario: S37 Edit changes the bytes

- GIVEN two manifests that differ in one field (for example the model id)
- WHEN their canonical forms are produced
- THEN the bytes differ

### Requirement: Reference examples

The #33 example `docs/architecture/examples/agent-manifest.example.json` MUST use the new model shape (`provider`, `id`, no credential) and MUST parse and validate as deployable. A second example for a free `workers-ai` agent MUST exist next to it and also validate as deployable. Both MUST be accepted by `AgentManifest.fromJson` under a policy that allows their models, and MUST round-trip through `toJson` to an equal document.

#### Scenario: S38 Copy Forge example validates

- GIVEN the #33 example file and a policy enabling `anthropic`
- WHEN it is parsed with `AgentManifest.fromJson`
- THEN it returns a manifest of version 1 with no problems

#### Scenario: S39 Workers AI example validates

- GIVEN the free `workers-ai` example file and a policy allowing its model id
- WHEN it is parsed with `AgentManifest.fromJson`
- THEN it returns a manifest
- AND `policy.isPaid` is false for its provider

#### Scenario: S40 Examples fail without policy support

- GIVEN the same examples and a policy that does not allow their models
- WHEN they are parsed
- THEN each fails with `InvalidManifest` containing a model problem and no other problem
