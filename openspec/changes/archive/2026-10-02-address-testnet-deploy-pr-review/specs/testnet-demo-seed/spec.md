# Delta Spec: testnet-demo-seed (new capability)

## Purpose

Seed demo agents on Stellar testnet only, with on-chain metadata aligned to the app catalog, validated before any network call, safe to re-run, and explicit about stale metadata.

## ADDED Requirements

### Requirement: Testnet-only network guard

The deploy and seed scripts MUST refuse to run against any network other than testnet. The refusal MUST happen before any network call and MUST exit non-zero with a message naming the rejected network.

#### Scenario: Non-testnet network rejected
- GIVEN the network is configured as mainnet (or any value other than testnet)
- WHEN a deploy or seed script is run
- THEN it exits non-zero, names the rejected network, and performs no network call

#### Scenario: Testnet accepted
- GIVEN the network is testnet
- WHEN a script is run
- THEN the guard passes and execution continues

### Requirement: Atomic, encoder-built testnet.json

`testnet.json` MUST be produced by a JSON encoder (never string concatenation) and written atomically (temp file then rename), so a failed run never leaves a partial or invalid file. The `soroban_sdk` field MUST hold the real SDK version value, not a regex artifact.

#### Scenario: Valid JSON output
- GIVEN a deploy completes
- WHEN `testnet.json` is parsed
- THEN it parses as valid JSON and values containing quotes or special characters are correctly escaped

#### Scenario: Interrupted write
- GIVEN the write fails midway
- WHEN the script exits
- THEN the previous `testnet.json` is unchanged and no partial file replaces it

#### Scenario: SDK version recorded
- GIVEN the contracts declare a `soroban_sdk` version
- WHEN `testnet.json` is written
- THEN `soroban_sdk` equals that declared version string

### Requirement: demo-agents.json schema

`demo-agents.json` MUST contain 6 to 8 agents. Each agent MUST have `id`, `name`, `description`, `model`, `priceUsdcStroops`, and `skills`.
- `priceUsdcStroops` MUST be a positive integer (stroops); the legacy `price` field MUST NOT be used.
- `skills` MUST be a JSON array of 1 to 5 unique kebab-case ids, stored on-chain as a JSON-array string.
- `name` MUST be 3 to 48 characters; `description` MUST be 10 to 280 characters.

#### Scenario: Valid seed file
- GIVEN a file with 6-8 agents satisfying every field rule
- WHEN validated
- THEN validation passes

#### Scenario: Invalid price
- GIVEN an agent with `priceUsdcStroops` of 0, negative, fractional, or non-numeric
- WHEN validated
- THEN validation fails naming the agent and `priceUsdcStroops`

#### Scenario: Invalid skills
- GIVEN an agent with 0 skills, more than 5, duplicates, or a non-kebab-case id
- WHEN validated
- THEN validation fails naming the agent and `skills`

#### Scenario: Length bounds
- GIVEN a name of 2 or 49 characters, or a description of 9 or 281 characters
- WHEN validated
- THEN validation fails naming the agent and the offending field

#### Scenario: Agent count bounds
- GIVEN a file with 5 or 9 agents
- WHEN validated
- THEN validation fails stating the allowed count of 6-8

### Requirement: Fail-fast pre-flight validation

The seed script MUST validate the entire seed file, including the metadata key count against `MAX_METADATA_KEYS`, before any network call. Any violation MUST exit non-zero, report the agent and field, and MUST NOT register or write anything.

#### Scenario: Malformed fixture
- GIVEN a seed file where the third agent has an invalid field
- WHEN the seed script runs
- THEN it exits non-zero naming that agent and field, and no network call is made, including for valid agents listed earlier

#### Scenario: Key count exceeds limit
- GIVEN the seed keys would exceed `MAX_METADATA_KEYS`
- WHEN pre-flight runs
- THEN it fails before any network call

### Requirement: Idempotent re-run

Re-running the seed script MUST NOT register duplicate agents. Agents whose URI is already registered MUST be skipped for registration. No secrets MUST be written to repository files or printed in output.

#### Scenario: Re-run with no changes
- GIVEN all seed agents are registered with matching metadata
- WHEN the script is run again
- THEN no registration occurs, the agent count is unchanged, and it exits zero

#### Scenario: Partial prior run
- GIVEN some agents are already registered
- WHEN the script is run
- THEN only the missing agents are registered

### Requirement: Stale-metadata detection

For each already-registered agent, the script MUST read `get_metadata` for every seed key and compare it with the seed. By default, on any mismatch it MUST print `stale: <uri> <key>`, skip that agent, continue checking the others, and exit non-zero with re-seed guidance.

#### Scenario: Stale agent reported by default
- GIVEN a registered agent still holds legacy metadata (`price`, comma-joined skills)
- WHEN the script is run without flags
- THEN it prints `stale: <uri> <key>` for each drifted key, does not modify the agent, and exits non-zero with guidance

#### Scenario: No drift
- GIVEN all keys match
- WHEN the script is run
- THEN no `stale:` line is printed and the exit status reflects success

### Requirement: Opt-in metadata sync

With `--sync-metadata`, the script MUST rewrite only drifted seed keys via `set_metadata`. If the caller is not the owner, it MUST fail clearly with a message that `set_metadata` is owner-only. The legacy `price` key MUST NOT be deleted (the contract has no removal) and MUST be documented as deprecated.

#### Scenario: Owner syncs
- GIVEN stale agents and the caller is the owner
- WHEN run with `--sync-metadata`
- THEN drifted keys are rewritten, a follow-up run reports no stale agents, and `price` remains untouched

#### Scenario: Non-owner syncs
- GIVEN the caller is not the owner
- WHEN run with `--sync-metadata`
- THEN it fails with a clear owner-only message and exits non-zero

### Requirement: Metadata schema documentation

`contracts/README.md` MUST document the metadata keys (`priceUsdcStroops`, `skills` as JSON-array string, `name`, `description`, `model`), the validation limits, the deprecated `price` key, and the `--sync-metadata` flag.

#### Scenario: Reader finds schema
- GIVEN a developer opens `contracts/README.md`
- WHEN they look for seed metadata rules
- THEN each key, its limits, the deprecated `price` key, and stale/sync behavior are described

## Key Learnings

1. Validation must run entirely before any network call, otherwise a bad fixture leaves a half-seeded testnet state that is append-only and cannot be undone.
2. The contract has no metadata removal, so the legacy `price` key can only be documented as deprecated rather than cleaned up.
3. Defaulting to report-and-skip for stale agents keeps re-runs safe, while owner-only repair stays behind an explicit flag.
