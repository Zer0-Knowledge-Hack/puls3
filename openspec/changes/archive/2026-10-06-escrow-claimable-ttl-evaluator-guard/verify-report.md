```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:215d17162eed87d090a2de7e9468e22d514a854e5ce29262e6275bb5def96643
verdict: pass
blockers: 0
critical_findings: 0
requirements: 5/5
scenarios: 27/27
test_command: cargo test -p escrow
test_exit_code: 0
test_output_hash: sha256:b1c20ff25974c3ced53848846a009b469a28667c38936475a1e2e0c8cd4d548f
build_command: stellar contract build
build_exit_code: 0
build_output_hash: sha256:ffbd21677fee59d27a4e28a8d9736604cade470fe5b4bca59377779a4db675e9
```

## Verification Report

Change: escrow-claimable-ttl-evaluator-guard (issue #95). Mode: Strict TDD (hybrid store). HEAD d73602d on fix/95-escrow-claimable-ttl-evaluator-guard.

### Completeness
All tasks in tasks.md are checked (Phases 1-4, 17 of 17). No pending tasks.

### Runtime evidence
| Command | Exit | Result |
|---|---|---|
| cargo fmt --all -- --check | 0 | clean |
| cargo clippy --all-targets -- -D warnings | 0 | clean |
| cargo test -p escrow | 0 | 136 passed, 0 failed |
| stellar contract build | 0 | escrow.wasm exports 30 functions, including extend_claimable_ttl |

CRLF-only churn in 10+ existing snapshots (Windows autocrlf) was discarded with git checkout -- contracts; ignoring EOL there is no content diff. Tree is clean after discard.

### Spec compliance matrix (all tests passed at runtime)
| Requirement / Scenario | Covering test | Status |
|---|---|---|
| R1 evaluator equals provider | evaluator_cannot_be_the_provider (error, job_count 0, no events) | COMPLIANT |
| R1 evaluator equals client accepted | evaluator_equal_to_client_is_accepted | COMPLIANT |
| R1 third-party evaluator accepted | third_party_evaluator_is_stored (existing) | COMPLIANT |
| R1 client and evaluator both provider -> ClientIsProvider | client_cannot_be_the_provider (existing; caller=provider=evaluator) | COMPLIANT |
| R1 client equals provider | client_cannot_be_the_provider | COMPLIANT |
| R1 other scenarios (unchanged) | existing create_job tests | COMPLIANT |
| R11 extend_claimable_ttl keeps payout alive | extend_claimable_ttl_restores_a_decayed_entry | COMPLIANT |
| R11 TTL bumped / extend_ttl keeps long job | existing tests | COMPLIANT |
| R12 EvaluatorIsProvider code 117 | evaluator_is_provider_has_code_117 + evaluator_cannot_be_the_provider | COMPLIANT |
| R13 allow-list includes extend_claimable_ttl, nothing else new | contract_exports_exactly_the_specified_functions | COMPLIANT |
| R13 no dispute surface | same allow-list test | COMPLIANT |
| R15 decayed claimable restored and withdrawable | extend_claimable_ttl_restores_a_decayed_entry (TTL < threshold, then == TTL_BUMP, withdraw BUDGET) | COMPLIANT |
| R15 balance/tokens unchanged, no event | same test (escrow/provider/caller balances, job_events empty) | COMPLIANT |
| R15 unknown claimable only bumps instance | extend_claimable_ttl_for_an_unknown_entry_only_bumps_the_instance | COMPLIANT |
| R15 permissionless | restores_a_decayed_entry (mock_auths(&[])) | COMPLIANT |

### Design coherence
Guard sits after ClientIsProvider and before verify_provider; new fn directly after extend_ttl with four-space indent, has-guard, no auth, no event, returns (); extend_ttl, pay_or_defer, withdraw, claimable unchanged; error appended as 117. All match design.

### Docs
contracts/README.md mentions extend_claimable_ttl and EvaluatorIsProvider (117) with redeploy (#84) note. docs/verification/onchain.md documents extend_claimable_ttl. docs/architecture/api.md updated (no longer says "once #95 lands").

### Strict TDD
Task list records RED then GREEN per task; tests are behavioral, assert exact values; snapshots committed as new files only. Code 117 is not used on any local branch.

### Issues
CRITICAL: none.
WARNING: none.
SUGGESTION: (1) Follow-up for Serverpod/Flutter mapping of code 117 (#77) and the redeploy (#84), both out of scope. (2) Spec says the base spec is the openspec/specs path; proposal notes it lived in an unarchived change, so confirm the delta merges cleanly at archive time.

Verdict: PASS
