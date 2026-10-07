# Proposal: Address Testnet Deploy PR Review (#58)

## Intent

PR #58 has CHANGES_REQUESTED. Items 1 (testnet-only guard) and 2 (encoder-built JSON, atomic write) already exist at `d6d884a`. Item 3 is still open: the seed metadata (`price`, comma-joined `skills`) does not match the app catalog (`priceUsdcStroops`, `skills[]`). This change closes item 3 and adds proof for items 1-2. Issue #15 needs 6-8 agents, idempotent re-runs, and no secrets.

## Scope

### In Scope
- Keep and verify the guards for items 1-2. Add one cheap script regression test only if it is cheap.
- `demo-agents.json`: rename `price` to `priceUsdcStroops` (positive integer stroops). Store `skills` as a JSON-array string. Keep `id`, `name`, `description` and `model`.
- Pre-flight validation in `seed-demo-agents.sh`, run before any network call:
  - skills: 1-5 unique kebab-case ids
  - `priceUsdcStroops`: positive integer
  - name: 3-48 chars
  - description: 10-280 chars
  - agent count: 6-8
- Stale-metadata handling for agents already registered on testnet (see Approach).
- Document the metadata schema in `contracts/README.md`.
- Verify `soroban_sdk` in `testnet.json`. The record shows `"28"`, which may come from a regex quirk.

### Out of Scope
- Rewriting the deploy or seed scripts.
- Contract changes, including deleting metadata keys.
- Adding `rating` or `stellarAddress` to the on-chain metadata.
- Shell CI jobs and shellcheck.
- Any push or any change to `main`.

## Capabilities

### New Capabilities
- `testnet-demo-seed`: testnet-only seeding, the metadata schema aligned with the catalog, pre-flight validation, an idempotent re-run, and stale-metadata reporting.

### Modified Capabilities
None.

## Approach

- Validation reuses the JSON runtime the script already selects (python or node). Any violation exits non-zero and names the agent and field.
- Existing URIs: the script reads `get_metadata` for each seed key and compares it with the seed.
  - Default: on a mismatch, print `stale: <uri> <key>`, skip the agent, and exit non-zero with re-seed guidance.
  - Opt-in `--sync-metadata`: the owner rewrites the drifted keys with `set_metadata`, which is owner-only. A non-owner gets a clear failure.
  - The legacy `price` key cannot be deleted (the contract has no removal). It stays as a documented deprecated key.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `contracts/deployments/demo-agents.json` | Modified | Schema rename and skills array |
| `scripts/seed-demo-agents.sh` | Modified | Validation, stale detection, sync flag |
| `scripts/deploy-testnet.sh` | Verified/Modified | `soroban_sdk` capture fix, if needed |
| `contracts/deployments/testnet.json` | Possibly modified | `soroban_sdk` value |
| `contracts/README.md` | Modified | Metadata schema docs |
| domain/server/client/app | None | The catalog is only read for reference |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Live testnet agents (`CD5QZOKG...FIJJ`) keep the old metadata | High | Report stale agents by default; repair with opt-in `--sync-metadata` |
| An orphan `price` key confuses consumers | Med | Document it as deprecated |
| The added key reaches `MAX_METADATA_KEYS` | Low | Check the key count during pre-flight |
| A shell test is hard to run on Windows | Med | Skip the test if it is not cheap, and verify manually |

## Rollback Plan

Revert the change commits on `chore/deploy-testnet` with `git revert`. Seeded on-chain data is append-only, and the old keys remain readable. Nothing reaches `main`.

## Dependencies

- `stellar` CLI and testnet access for the manual verification run.

## Success Criteria

- [ ] The seed file passes validation. A malformed fixture fails clearly.
- [ ] A re-run on testnet registers no duplicates and reports stale agents.
- [ ] `--sync-metadata` aligns the live agents with the catalog keys.
- [ ] The README documents the schema. The `soroban_sdk` value is correct.
- [ ] The estimated diff is about 200-300 changed lines, within the 400-line budget.
