```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:ae3628b48f2b7b5f4d393c7eb248d86cf83b2339ca78c4539d3e43dbbf3f04ff
verdict: fail
blockers: 2
critical_findings: 2
requirements: 14/14
scenarios: 35/37
test_command: dart test test/unit
test_exit_code: 0
test_output_hash: sha256:1fa630ed67fe7d14aac4b612f277b35e917bbe43484a0798573b5822ae47ced4
build_command: dart analyze --fatal-infos
build_exit_code: 0
build_output_hash: sha256:cecbcfa60342b19b6195d18f586ac63e7396dd2d014a9c0aac34681b01fe1ee9
```

## Verification Report

**Change**: fix-server-agent-catalog-endpoint
**Version**: N/A
**Mode**: Strict TDD (hybrid store)

### Completeness
| Metric | Value |
|--------|-------|
| Tasks total | 22 (0.1, 1.1-1.4, 2.1-2.4, 3.1-3.6, 4.1-4.3, 5.1-5.3) |
| Tasks complete | 22 |
| Tasks incomplete | 0 |

### Build & Tests Execution
**Build** (`dart analyze --fatal-infos`): Passed, "No issues found!" (exit 0)

**Tests** (`dart test test/unit`): 150 passed / 0 failed / 0 skipped (exit 0)

**Generation**: `serverpod generate` (serverpod_cli 3.4.13) re-run; `git diff --exit-code -- puls3_server puls3_client` exit 0 (clean, no CRLF noise either). Root `pubspec.lock` restored with `git checkout pubspec.lock` after every dart command.

**Coverage**: not measured; informational only.

**Live fixture check (read-only, no signing or broadcast)**: replayed the recorded `get_metadata(7,"name")` envelope via `simulateTransaction` on soroban-testnet: it returns the bytes of "Ledger Scout" (4c65646765722053636f7574), identical to `simulate_get_metadata_present.json`. `stellar contract invoke --send=no -- total_agents` returns 15, identical to `simulate_total_agents.json`. The void fixture (agent 0, key `id`) was not replayed.

### TDD Compliance
| Check | Result | Details |
|-------|--------|---------|
| TDD evidence reported | PARTIAL | apply-progress (engram #421) reports evidence in prose (units, 150 passed) but has no per-task TDD Cycle Evidence table |
| All tasks have tests | OK | every behavioral unit (1, 3, 4) has test files |
| RED confirmed (tests exist) | OK | encoder, ledger, agent_metadata, agent_catalog_service and agent_endpoint tests exist |
| GREEN confirmed | OK | 150/150 pass now |
| Triangulation | OK | price bounds (2^53-1, 2^53, 0, -5, abc), name 3/48, description 10/280, TTL hit/expiry/stale |
| Safety net | OK | existing ledger tests (agentExists, agentUri, wallet, findPayment, escrowJob) still pass |

### Test Layer Distribution
Unit only: 150 tests (package:test). No integration test (withServerpod); the design marks it optional and CI-only.

### Assertion Quality
Scanned agent and ledger tests: no tautologies, no ghost loops, no smoke-only tests, hand-written fakes (not mock-heavy). The concurrency test asserts maxInFlight == 4 and 15 agents processed. **Assertion quality**: 0 CRITICAL, 0 WARNING.

### Spec Compliance Matrix

agent-catalog-endpoint (10 requirements, 25 scenarios):

| Requirement | Scenario | Test | Result |
|---|---|---|---|
| AgentSummary model | Required fields populated | service_test > list > maps valid metadata and the optional wallet and model | COMPLIANT |
| AgentSummary model | No rating | no test; static grep of spy yaml and generated class finds no rating or reputation | UNTESTED (static only) |
| Endpoint list and get | List seeded agents | service_test > skips orphans 0-6 and returns the agents 7-14; endpoint_test > list | COMPLIANT |
| Endpoint list and get | Get existing | endpoint_test > get returns a known agent | COMPLIANT |
| Endpoint list and get | Get unknown | endpoint_test > get null for unknown id; service_test > get > null | COMPLIANT |
| Enumeration and orphans | Orphans skipped | service_test > skips orphans 0-6 | COMPLIANT |
| Enumeration and orphans | Invalid metadata skipped | service_test > skips an agent with invalid metadata, keeps the others | COMPLIANT |
| Enumeration and orphans | Empty registry | service_test > an empty registry gives an empty list | COMPLIANT |
| Skills parsing | Valid skills | metadata_test > parseSkills keeps the order | COMPLIANT |
| Skills parsing | Non-array skills | metadata_test > rejects an object, invalid JSON and a non-string element | COMPLIANT |
| Price parsing | Valid price | metadata_test > parses a valid price | COMPLIANT |
| Price parsing | Upper bound accepted | metadata_test > accepts 2^53 - 1 and rejects 2^53 | COMPLIANT |
| Price parsing | Above bound rejected | same test | COMPLIANT |
| Price parsing | Zero, negative or non-numeric | metadata_test > rejects zero, negative, non-numeric and fractional values | COMPLIANT |
| Cache and stale fallback | Cache hit | service_test > cache > a second call inside the TTL does not read the chain | COMPLIANT |
| Cache and stale fallback | Expired cache refreshes | service_test > cache > a call after the TTL rebuilds the list | COMPLIANT |
| Cache and stale fallback | Stale fallback | service_test > cache > an outage after the TTL returns the stale list | COMPLIANT |
| AgentCatalogUnavailable | Outage without cache | service_test > outage > without a cache list throws and never returns empty | COMPLIANT |
| AgentCatalogUnavailable | Get during outage | service_test > outage > get throws instead of null; endpoint_test > list and get throw | COMPLIANT |
| Bounded concurrency | Concurrency cap | service_test > reads at most 4 agents at once and processes all of them | COMPLIANT |
| Lazy default wiring | Default built on first use | none (private lazy getter needs environment; not exercised) | UNTESTED |
| Lazy default wiring | Override used in tests | endpoint_test > list serves the injected service | COMPLIANT |
| Lazy default wiring | Offline unit tests | whole unit suite runs offline with a fake RegistryReader | COMPLIANT |
| Generated client committed | No generated diff | serverpod generate 3.4.13 then git diff --exit-code: exit 0 | COMPLIANT |
| Generated client committed | Client exposes the endpoint | puls3_client protocol/client.dart, agent_summary.dart, agent_catalog_unavailable.dart committed; generate diff clean | COMPLIANT |

registry-metadata-reads (4 requirements, 12 scenarios):

| Requirement | Scenario | Test | Result |
|---|---|---|---|
| totalAgents | Count returned | soroban_ledger_test > totalAgents > returns the recorded count and sends the right call | COMPLIANT |
| totalAgents | Empty registry | totalAgents > returns 0 for an empty registry | COMPLIANT |
| totalAgents | Malformed result | totalAgents > a value that is not an integer is unavailable | COMPLIANT |
| agentMetadata | Metadata present | agentMetadata > returns the recorded bytes (Ledger Scout) | COMPLIANT (bytes per design; spec says string) |
| agentMetadata | Metadata missing | agentMetadata > a void result is null | COMPLIANT |
| agentMetadata | Key sent as string | agentMetadata > returns the recorded bytes and sends the key as a string | COMPLIANT |
| ScArg.string | Discriminant and length | encoder_test > writes discriminant 14, the byte length and no padding | COMPLIANT |
| ScArg.string | Padding | encoder_test > pads a 2-byte string with 2 zero bytes | COMPLIANT |
| ScArg.string | Empty string | encoder_test > writes only discriminant and length for an empty string | COMPLIANT |
| ScArg.string | Multi-byte characters | encoder_test > counts UTF-8 bytes, not characters, and pads to 4 | COMPLIANT |
| Simulation-only | RPC failure | ledger_test > totalAgents and agentMetadata > HTTP 503 is unavailable | COMPLIANT |
| Simulation-only | Offline test | MockClient with recorded fixtures, no network | COMPLIANT |

**Compliance summary**: 35/37 scenarios compliant, 2 untested, 0 failing. Requirements 14, scenarios 37.

### Correctness (Static Evidence)
| Requirement | Status | Notes |
|---|---|---|
| Read-only | OK | simulation paths only; no sendTransaction or signing in the diff |
| No secrets | OK | diff vs origin/fix/server-soroban-rpc-adapter holds only public contract ids and the public simulation source address; keyword hits are generated auth-module field names |
| Artifact hygiene | OK | change folder is free of the banned review-process words requested by the caller |
| Endpoint | OK | thin delegation, visibleForTesting setter, 8 s timeout |

### Coherence (Design)
| Decision | Followed? | Notes |
|---|---|---|
| Port in agent/registry_reader.dart; SorobanLedger implements both | Yes | |
| Service returns generated models | Yes | |
| Static lazy default and visibleForTesting setter | Yes | |
| Any LedgerException aborts the refresh; only invalid metadata skips | Yes | tested |
| Duplicate id keeps highest registryId | Yes | tested |
| meta ^1.17.0 | Yes | |
| 3-method RegistryReader (no agentUri) | Yes | spec text lists agentUri; design wins |
| Four workers on a shared iterator, single in-flight refresh | Yes | tested |

### Issues Found
**CRITICAL**:
1. UNTESTED scenario "Default built on first use" (Lazy default wiring): no test builds the default service from the environment; the lazy getter in AgentEndpoint is never exercised.
2. UNTESTED scenario "No rating" (AgentSummary model): only a static grep supports it; no test inspects the generated AgentSummary fields (for example via toJson keys).

**WARNING**:
1. Spec drift: the spec lists agentUri on RegistryReader and a string-valued agentMetadata; design and code use 3 methods and Uint8List (Option of Bytes). Align the specs at archive (design wins).
2. apply-progress reports TDD evidence in prose, without the per-task TDD Cycle Evidence table.

**SUGGESTION**:
1. Add the optional withServerpod integration test (CI only), as the design allows.
2. Record in the spec sync that the void fixture is agent 0 key `id`, because live agents 0-6 have a name but no id.

### Verdict
FAIL
Runtime is green (150/150, analyze clean, generate clean) but two scenarios lack a covering test; the skill rules make that CRITICAL UNTESTED. Both are small test additions.
