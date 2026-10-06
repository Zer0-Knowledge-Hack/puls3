# Design: Address Testnet Deploy PR Review (#58)

## Technical Approach

Extend `scripts/seed-demo-agents.sh` in place, without a rewrite. Add three things: a pre-flight validator built on the existing `JSON_RT` python/node switch, a per-key drift check for URIs that are already registered, and an opt-in `--sync-metadata` repair path. Rename the metadata in `demo-agents.json`, document the schema in `contracts/README.md`, and add one plain-bash regression script. `deploy-testnet.sh` is verified and left unchanged.

## Architecture Decisions

| Topic | Options | Tradeoff | Decision |
|---|---|---|---|
| Validator runtime | python/node inline (as today) vs. a new `.py`/`.js` file vs. jq | A new file adds a dependency or a second code path. jq is not guaranteed on Git Bash. | One `validate_seed` function with python and node branches, the same pattern as `seed_metadata`. |
| Skills encoding | comma string vs. JSON-array string of display names vs. JSON-array string of kebab ids | Display names match the Flutter mock. Kebab ids match the domain `Skill.id` regex `^[a-z0-9]+(-[a-z0-9]+)*$`, as the proposal and spec require. | A compact JSON-array string of kebab ids, slugged from the catalog names (`"On-chain analytics"` becomes `on-chain-analytics`). Example: `["on-chain-analytics","monitoring","summaries"]`. |
| Price encoding | number vs. decimal string | Metadata values are UTF-8 bytes in any case. | `priceUsdcStroops` is a base-10 integer string matching `^[1-9][0-9]*$` and `<= 9007199254740991` (`UsdcAmount.maxStroops`). |
| Legacy `price` key | overwrite with empty vs. leave in place | `set_metadata` rejects an empty value, and the contract has no delete. | Never write or read it. Document it as deprecated. The validator rejects `price` in the seed. |
| Stale default | warn and exit 0 vs. skip and exit non-zero | A silent exit 0 hides catalog drift. | Print `stale: <uri> <key>`, keep processing the other agents, then **exit 3** with guidance to re-run with `--sync-metadata`. Exit 1 stays reserved for errors. |
| Sync authority | sync every agent vs. owner-only | `set_metadata` is owner-only on chain. | Before writing, check `owner_of` against `CALLER`. A non-owner prints `error: not owner of <uri> (agent N)` and the script exits 1. |
| Stale state across loop | variable vs. temp file | The `| while` loop runs in a subshell, so a variable does not survive it. | Append to `STALE_LOG` (from `mktemp`, removed by the existing trap) and test `[ -s ]` after the loop. |
| Regression test | bats vs. plain bash vs. manual only | bats is not installed. Plain bash runs on Windows Git Bash and Linux. | `scripts/tests/seed-preflight.test.sh` runs offline cases only (see Testing). |
| soroban_sdk `"28"` | regex fix vs. read Cargo.lock | `contracts/Cargo.toml:8` is `soroban-sdk = "28"`. | No change: the regex is correct and records the declared requirement. The README notes that this field holds the requirement, not the resolved version. |
| MAX_METADATA_KEYS | runtime query vs. static pre-flight | 6 seed keys, plus `agentWallet`, plus legacy `price`, is 8. The limit is 100. | Pre-flight asserts `distinct_keys + 2 <= 100`, the constant mirrored from `lib.rs:17`. |

## Data Flow

    args ─→ parse (--sync-metadata | --check | identity)
         ─→ testnet guard ─→ files ─→ JSON_RT ─→ validate_seed ──fail─→ exit 1
                                                     │ ok
                                         --check? ───┴─→ exit 0 (offline)
         ─→ identity/stellar/record checks ─→ for each URI:
              agent_id_by_uri ── none ─→ register_full
                     │ id
                     └─→ per seed key: get_metadata(id,key) == hex(value)?
                           drift: --sync? owner_of==CALLER → set_metadata
                                         else → error, exit 1
                                  no sync → STALE_LOG
         ─→ STALE_LOG non-empty ─→ exit 3, else exit 0

The comparison normalizes the CLI output: strip quotes and whitespace, lowercase it, and treat `null` or empty as drift. On the seed side, the hex is produced by the existing UTF-8 encoding.

## File Changes

| File | Action | Description |
|---|---|---|
| `contracts/deployments/demo-agents.json` | Modify | `price` becomes `priceUsdcStroops`. `skills` becomes a JSON-array string of kebab ids. (~16 lines) |
| `scripts/seed-demo-agents.sh` | Modify | Argument parsing, `validate_seed`, `seed_kv_hex` (prints one `key<TAB>hex` line per key), drift and sync loop, exit 3, and a `SEED_FILE` env override. (~140 lines) |
| `scripts/tests/seed-preflight.test.sh` | Create | Offline regression cases. (~60 lines) |
| `contracts/README.md` | Modify | Metadata schema table, the deprecated `price` key, flags, exit codes, and the meaning of `soroban_sdk`. (~35 lines) |
| `scripts/deploy-testnet.sh`, `testnet.json` | Verified | No change. |

Estimate: about 250 changed lines.

## Interfaces / Contracts

```
seed-demo-agents.sh [--check] [--sync-metadata] [<identity>]
  exit 0 ok | 1 error/invalid/not-owner | 3 stale (no --sync-metadata)
  validation output: "invalid: <uri> <field>: <reason>" (all violations collected, then exit 1)
  --check: validate only, no identity and no stellar CLI needed
```

The validator rules match the spec:

- 6-8 agents, with unique, non-empty URIs.
- Each of `id`, `name`, `description`, `skills`, `priceUsdcStroops` and `model` appears exactly once.
- `price` is rejected.
- `name` is 3-48 code points and `description` is 10-280.
- `skills` holds 1-5 unique kebab-case ids.
- Each key is at most 64 bytes, and each value is 1-4096 UTF-8 bytes.

## Testing Strategy

| Layer | What | Approach |
|---|---|---|
| Script (offline) | The real seed passes `--check` with exit 0 | Bash test runner |
| Script (offline) | Malformed fixtures fail with exit 1 and name the field: price set to `0`, skills not kebab-case, 6 skills, a short name, 5 agents, legacy `price` present | The fixtures are written with `mktemp` and passed via `SEED_FILE` |
| Script (offline) | Item 1 guard: with `STELLAR_NETWORK=futurenet`, both scripts exit 1 before any `stellar` call | Bash test runner |
| Manual (testnet) | Item 2 atomic writer; a re-run without duplicates; stale report and exit 3; `--sync-metadata` repair; a non-owner failure | Run against `CD5QZOKG...FIJJ` and record the output in the PR |

The item 2 writer has no offline test. A PATH shim would overwrite the real `testnet.json`.

## Threat Matrix

| Boundary | Applicability | Design response |
|---|---|---|
| Documentation-like paths | N/A: no file classification | none |
| Git repository selection | N/A: no git calls | none |
| Commit state | N/A | none |
| Push state | N/A | none |
| PR commands | N/A | none |

Subprocess note:

- Seed values reach `stellar` only as hex or as quoted argv items. Nothing goes through `eval`.
- Python and node read file paths through `sys.argv` and `process.argv`, never through interpolated source.

## Migration / Rollout

The live agents keep their old keys. Run the script once with `--sync-metadata` as owner `GBY33...TJ4R` to write `priceUsdcStroops` and to overwrite `skills`. The legacy `price` key stays orphaned. Roll back with `git revert`.

## Open Questions

- [ ] Non-blocking: the Flutter mock lists skill display names, while the seed stores kebab ids. A later app change has to map ids to names.
