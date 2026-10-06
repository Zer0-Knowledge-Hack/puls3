# Tasks: Address Testnet Deploy PR Review (item 3)

## Review Workload Forecast

| Field | Value |
| ------- | ------- |
| Estimated changed lines | ~250 (range 200-300) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR (branch chore/deploy-testnet) |
| Delivery strategy | auto-chain |
| Chain strategy | pending (not needed) |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Seed rename, validation, tests, stale detection, docs | PR 1 | `bash scripts/tests/seed-preflight.test.sh` | `bash scripts/seed-demo-agents.sh --check` (offline) | Revert the single commit |

## Phase 1: Seed file and validation (test-first)

- [x] 1.1 RED: create `scripts/tests/seed-preflight.test.sh` (plain bash, offline, `SEED_FILE` fixtures): valid seed passes; malformed fixtures fail (bad skills, price, name/desc length, agent count, legacy price key, MAX_METADATA_KEYS).
- [x] 1.2 RED: in the same test, assert the STELLAR_NETWORK guard rejects non-testnet for both scripts.
- [x] 1.3 Rename the seed data file to the demo-agents schema (priceUsdcStroops string, skills kebab array 1-5) under `scripts/`; 6-8 agents.
- [x] 1.4 GREEN: add `validate_seed` (python and node branches via `JSON_RT`) and `SEED_FILE` override in `scripts/seed-demo-agents.sh`.
- [x] 1.5 GREEN: add `--check` (offline, no identity or stellar CLI) and static MAX_METADATA_KEYS check (distinct + 2 <= 100).
- [x] 1.6 Confirm `soroban_sdk` "28" matches `contracts/Cargo.toml:8`; no edit.

## Phase 2: Stale detection and sync

- [x] 2.1 RED: extend `scripts/tests/seed-preflight.test.sh` with stubbed `get_metadata` drift cases: stale exits 3; `--sync-metadata` exits 0; non-owner exits 1.
- [x] 2.2 GREEN: per-key drift check in `scripts/seed-demo-agents.sh` comparing `get_metadata` output with seed UTF-8 hex; log to `STALE_LOG` temp file (subshell-safe).
- [x] 2.3 GREEN: default mode reports stale, skips, exits 3; never writes the legacy price key.
- [x] 2.4 GREEN: implement opt-in `--sync-metadata` (owner-only repair) and idempotent rerun.
- [ ] 2.5 (PENDING, manual by maintainer; no testnet mutation allowed during apply) Manual: verify the atomic `testnet.json` writer (item 2) with a real run; no automated test (a PATH shim would overwrite the file).

## Phase 3: Documentation

- [x] 3.1 Update `README.md` (deploy/seed section): `--check`, `--sync-metadata`, exit codes 0/1/3, `SEED_FILE`, seed schema, legacy price key deprecated (no delete), skill id vs Flutter display-name note.

## Phase 4: Final verification

- [x] 4.1 Run `bash scripts/tests/seed-preflight.test.sh`; all pass.
- [x] 4.2 (shellcheck not installed; `bash -n` syntax check passed instead) Run `shellcheck scripts/seed-demo-agents.sh scripts/tests/seed-preflight.test.sh` if available; fix warnings.
- [x] 4.3 Run `bash scripts/seed-demo-agents.sh --check`; exit 0.

## Commit Plan

One conventional commit: `fix(scripts): validate demo seed and detect stale agent metadata`

No Co-Authored-By or AI attribution. No pushes, no changes to main.
