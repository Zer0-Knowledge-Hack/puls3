```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:1783f69c82eb49298695f854d17542926b4ec9b5516e0bbf6cc2783e1bca17a8
verdict: pass_with_warnings
blockers: 0
critical_findings: 0
requirements: 13/13
scenarios: 28/28
test_command: bash scripts/tests/escrow-deploy.test.sh && bash scripts/tests/seed-preflight.test.sh
test_exit_code: 0
test_output_hash: sha256:495882416e2ee221c89ca0d0bfd775f8145dab893ae26299284053e56d30ed13
build_command: bash -n scripts/deploy-escrow-testnet.sh scripts/seed-demo-agents.sh
build_exit_code: 0
build_output_hash: sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

## Verification Report

**Change**: fix-readme-onchain-evidence
**Mode**: Strict TDD (hybrid store)
**Verdict**: PASS WITH WARNINGS (0 CRITICAL, 3 WARNING, 3 SUGGESTION)

### Completeness
All 18 task checkboxes (1.1-1.3, 2.1-2.10, 3.1-3.2, 4.1-4.4) are checked and match code state.

### Test execution
| Suite | Result |
|---|---|
| `bash scripts/tests/escrow-deploy.test.sh` | 143 passed, 0 failed, exit 0 |
| `bash scripts/tests/seed-preflight.test.sh` | 52 passed, 0 failed, exit 0 |
| `bash -n` on both scripts | exit 0 (shellcheck not installed; skipped) |

Test layer: shell unit tests with a PATH-stubbed `stellar` (offline). No coverage tool available (skipped, not a failure).

### TDD compliance (apply-progress #405)
- apply-progress reports batch summaries, not the per-task "TDD Cycle Evidence" table. WARNING: table not found in strict form; RED test files exist (both suites) and are green now.
- Test files exist and pass: 2/2. Triangulation is adequate (133 expect_* calls in escrow-deploy; success and failure variants per behavior).
- Assertion quality: no tautologies, no ghost loops, no assertion without a production call found. No issues.

### Spec compliance (testnet-escrow-deployment)
| Req | Evidence | Status |
|---|---|---|
| D1 deploy script | Tests: missing identity, non-testnet, missing registry/wasm exit non-zero before any tx; constants fixed in script; no secret in output test. Live getters (simulate, `--send=no`): fee_bps 0, approval_window 86400, max_expiry 2592000, treasury null | COMPLIANT |
| D2 record | testnet.json `escrow` slot matches chain; `reputation_registry` null; identity_registry untouched; merge and in-place update tests pass | COMPLIANT |
| D3 allow-list | `is_token_allowed(USDC SAC)` returns true live; only USDC allowed in script; skip-if-true test | COMPLIANT |
| D4 seed binds wallets | ensure_wallet tests (bound: no call; missing/different: bind; failure names step); live `get_agent_wallet(14)` returns owner, `agent_uri(14)` = agt-008, total_agents 15 | COMPLIANT |
| D5 test job | Job 3 live `state`: 3 (Completed); four distinct hashes, all `successful: true` on Horizon; failure-mid-flow and missing-hash tests pass | COMPLIANT |
| D6 TTL | Mentioned in contracts/README.md and docs/verification/onchain.md; "about 60 days" matches TTL_BUMP 1,036,800 ledgers | COMPLIANT |

### Spec compliance (onchain-evidence-docs)
| Req | Evidence | Status |
|---|---|---|
| E1 evidence table | All 19 56-char IDs / 64-hex values in testnet.json appear in README in full (3 hash-only values are wasm hash / deliverable and reason hashes, present in README); no truncated IDs; reputation registry stated not deployed | COMPLIANT |
| E2 both rails | 4 escrow hashes + Completed, direct payment hash, all linked; all Horizon-confirmed successful | COMPLIANT |
| E3 agents | README lists agt-001..008 = demo-agents.json (8); 7 orphans disclosed | COMPLIANT |
| E4 parameters | Only documented values appear | COMPLIANT |
| E5 guide | CLI + explorer steps, expected results, reset caveat, TTL, read-only; no secrets | COMPLIANT |
| E6 contracts docs | Layout, escrow, deploy script, TTL present; all referenced paths exist (crate paths are workspace-relative, matching the main-branch convention) | COMPLIANT |
| E7 language | English; unverified items labeled | COMPLIANT |

Evidence-only checks: manual (docs); runtime evidence is live read-only simulation plus Horizon GETs. No broadcast performed.

### Secrets and banned words
- `git diff main..HEAD`: no secret key material (only the literal test stub value `SSECRETKEYMATERIAL` in the leak-check test).
- openspec artifacts of this change: zero matches for jury, judges, feedback.

### Issues
**CRITICAL**: none.

**WARNING**
1. README.md line 54 (mermaid `result + feedback`) still contains the word "feedback"; apply-progress said it was changed. It is pre-existing (blame: earlier commit) and outside openspec, so the stated rule is not violated.
2. Spec headings use `### D1.` / `### E1.` rather than `### Requirement:`; native status counts 0 requirements, so envelope totals (13 req, 28 scenarios) may show a mismatch in status.
3. apply-progress lacks the strict per-task TDD Cycle Evidence table.

**SUGGESTION**
1. Agent registration, orphan job and agent 0/6 hashes in the README are not in testnet.json (they come from script output); all were confirmed on Horizon, but recording them in testnet.json would make traceability machine-checkable.
2. contracts/AGENTS.md writes `contracts/escrow/` while the crate lives at `contracts/contracts/escrow/` (workspace-relative, matches existing convention); consider clarifying.
3. README says the registry "owner and original deployer" is GBY33... while agents were registered by GAFUY...; add one sentence clarifying the ownership split.
