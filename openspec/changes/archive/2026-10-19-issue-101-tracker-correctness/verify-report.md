```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:23d521b937c0fc4b35903003e8a930b59f1f5f03a12c45cb8bbefe1423e4ddba
verdict: pass_with_warnings
blockers: 0
critical_findings: 0
requirements: 11/11
scenarios: 40/40
test_command: "dart test test/unit test/hire test/feedback test/studio test/ledger test/agent test/protocol test/spike (puls3_server): +1032 all passed"
test_exit_code: 0
test_output_hash: sha256:b63943e80ed6f348a5a7574c4a8263b2fef5bd146d3b2497ee49dd04665830ea
build_command: "dart analyze --fatal-infos lib test bin (puls3_server): No issues found"
build_exit_code: 0
build_output_hash: sha256:31af940f584daa34ed28f726484bed764a7c56c7905a14ad4e5c0f3d6c860faf
```

## Verification Report (re-verification after remediation)

**Change**: 101-tracker-correctness | **Mode**: Strict TDD | **Store**: hybrid
**Verdict**: PASS WITH WARNINGS (0 CRITICAL, 2 WARNING, 1 SUGGESTION). Exit codes are 1 only because of the baseline: 21 DB-connection failures (no PostgreSQL) and 24 avoid_print infos in an untracked tool file, both identical on origin/main.

### Completeness
Tasks 20/20 plus remediation R1-R6. Specs: 11 requirements (7+2+2), 40 scenarios (26+7+7), matching the heading counts.

### Runtime evidence (re-run by the verifier)
- `dart analyze --fatal-infos`: 24 infos, 0 outside tool/feedback_walkthrough.dart; `analyze lib test bin` is clean (exit 0).
- `dart test` (full): +1032 -21, confirmed. The 21 failures are the DB setUpAll connection refusals in test/integration (no PostgreSQL), identical to baseline. Envelope evidence uses the DB-free dirs (unit, hire, feedback, studio, ledger, agent, protocol, spike): +1032 passed, exit 0.
- Root pubspec.lock reverted with `git checkout -- pubspec.lock`; no lock diff.
- Not runnable: chain_submission_tracker_restart_test and hire_relay_flow_test (need PostgreSQL), edited blind.

### Previous findings
- C1 RESOLVED: test 'a restart resets the counter...' (tracker test L769) builds a second ChainSubmissionTracker over the same store and ledger after two empty passes, asserts waiting 1 / failed 0 and still submitted, then needs two more passes to fail JobEvidenceUnavailable. Mutation proof is sound by reading: with a static or shared _missingEvents the restarted tracker would count 3 on its first pass and fail, breaking the first assertions. Matrix is now 40/40 COMPLIANT.
- W2 RESOLVED: test 'an event that shows up on the second pass confirms and clears the counter' (L755).
- W3 RESOLVED: test 'an effect that throws after the event shows up resets the counter' (L799), plus pass() reset logic.
- W1 RESOLVED (documented): sentence in api.md and the tracker doc comment about expired/missing job with covered retention.
- W4 RESOLVED: R1-R6 RED/GREEN table in Engram apply-progress #572 (R2 is a characterization test, R1 RED by mutation; acceptable).
- S1/S2 RESOLVED: specs say "per submission record" and "any escrow record"; api.md states the in-memory/restart behavior (L132).

### Review of the new pass() logic
- Count increments only in _missingEvidence; the pass() snapshot `before` and the rule `settled || count == before => remove` give: miss (before n, after n+1) keeps; settle (including the 3rd miss failing) clears; event seen with effect throw or LedgerException/other exception leaves the count unchanged so it is cleared (consecutive semantics as intended, covered by the effect-throw test).
- Dropping non-listed ids only when batch.length < limit is correct: a short batch is every submitted record, so ids absent are settled or gone. When the batch is full, entries of records beyond the limit are kept, never wrongly dropped; a record rotated out by _recordCheck and back counts its earlier misses, which is conservative (not unfair).
- No bug found.

### Spec compliance matrix
All 40 scenarios COMPLIANT with passing runtime tests, as in the previous report plus: "Event on second pass" now direct (L755), "Restart resets the counter" now covered (L769). The only scenarios without direct runtime proof against a real database are the store-backed ones covered in-memory through the shared store contract.

### TDD Compliance
Per-task RED/GREEN table exists for the remediation (R1-R6); earlier units have per-unit pass counts only (U1 972 ... U6 1029). Triangulation good. Assertion quality: no tautologies, no ghost loops; the new tests assert real state and counts.

### Design coherence
D1-D8 unchanged and coherent; the counter is keyed by submission id (equivalent to per hash).

### Hygiene
32 modified owned files plus the untracked change dir. Untracked docs/audits, puls3_server/config/passwords.yaml.bak-before-sep10 and tool/feedback_walkthrough.dart untouched. pubspec.lock clean. Raw diff 1514/252 (tests about 70%).

### Issues
CRITICAL: none.
WARNING
- W1 Full `dart test` exits 1 (21 DB-connection failures) and full `dart analyze` exits 1 (24 avoid_print infos in untracked tool/feedback_walkthrough.dart); both are baseline and not caused by this change. The envelope uses the DB-free test dirs and `analyze lib test bin`, both exit 0.
- W2 Integration tests chain_submission_tracker_restart_test and hire_relay_flow_test were edited blind; run once with PostgreSQL before merge.
SUGGESTION
- S1 Earlier units (U1-U5) lack per-task RED/GREEN rows; only the remediation has them.

## Key Learnings
1. The in-memory evidence counter must be cleared whenever a pass does not add a miss, or consecutive counting is lost.
2. Pruning counter entries is safe only when the listed batch is smaller than the limit.
3. A restart test is a real proof when a second tracker instance shares the store and ledger.
4. Running dart test here rewrites the root pubspec.lock, which must be reverted afterwards.
