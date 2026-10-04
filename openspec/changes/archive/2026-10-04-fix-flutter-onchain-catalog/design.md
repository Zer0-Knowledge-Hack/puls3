# Design: Flutter On-chain Catalog

## Technical Approach

Keep `AgentRepository.fetchAgents()` as the only seam (proposal Approach A). Add a server-backed repository that maps `AgentSummary` to `Agent`, wrap it in a fallback repository with the asset catalog, and compose both in `main.dart`. `AgentCatalog`, router and screens stay unchanged; only `RatingBadge` changes.

## Architecture Decisions

| Topic | Options | Tradeoff | Decision |
|---|---|---|---|
| Timeout | `Client(connectionTimeout:)` vs `Future.timeout` | Verified in `serverpod_client-3.4.13`: `connectionTimeout` (default 20 s) is client-wide (also bounds `health.check()`); on IO it bounds connect and response headers only (`request.close().timeout`), not the body read; not testable without the real client | `Future.timeout` inside `ServerAgentRepository`, injectable `timeout`, default `Duration(seconds: 20)` (the client's own documented default, not a new value) |
| Source | Inject `Client` vs inject function | Faking a generated client is heavy | `typedef AgentSummarySource = Future<List<AgentSummary>> Function()` |
| Mapper home | Separate mapper file vs static on repository | Mirrors `AssetAgentRepository.parseAgents` | `static Agent? fromSummary(AgentSummary)` on `ServerAgentRepository` |
| Fallback catch | `on Exception` vs `catch (e, st)` | Spec requires any error; catching `Error` may hide mapper bugs | Catch everything, log with `debugPrint`, return fallback |
| Logging | Silent vs `debugPrint` vs callback | `avoid_print` lint is active; `debugPrint` is allowed and throttled; no UI source indicator in scope | `debugPrint('Agent catalog: primary failed, using fallback: $e')` |
| Skill names | Inline in mapper vs pure domain function | Domain is pure Dart, unit-testable | `lib/src/domain/skill_display_name.dart` |
| Unrated badge | Conditional in screens vs badge self-hides | Proposal limits screen changes; the detail `Wrap` keeps one `Puls3Spacing.sm` gap before the model text when the badge is empty (cosmetic) | Badge returns `const SizedBox.shrink()` when `rating <= 0`; no screen edits |

## Data Flow

    main.dart
      FallbackAgentRepository
        ├─ primary:  ServerAgentRepository(() => client.agent.list())
        │             source().timeout(t) -> fromSummary -> drop null -> List<Agent>
        └─ fallback: AssetAgentRepository()  (on any thrown error, incl. TimeoutException)
      -> Puls3App(repository) -> AgentCatalog.load() -> screens

Errors: `ServerAgentRepository` propagates (no swallowing); `FallbackAgentRepository` swallows primary errors only; fallback errors reach `AgentCatalog._error` as today.

## File Changes

| File | Action | Description |
|---|---|---|
| `puls3_flutter/lib/src/domain/skill_display_name.dart` | Create | Const 17-id table + generic fallback |
| `puls3_flutter/lib/src/data/server_agent_repository.dart` | Create | Source typedef, timeout, mapper |
| `puls3_flutter/lib/src/data/fallback_agent_repository.dart` | Create | Primary/fallback composition |
| `puls3_flutter/lib/src/ui/atoms/rating_badge.dart` | Modify | Hide when `rating <= 0` |
| `puls3_flutter/lib/main.dart` | Modify | Compose repositories |
| `puls3_flutter/test/helpers.dart` | Modify | `pumpApp` gains optional `AgentRepository repository` (default `InMemoryAgentRepository(testAgents)`) |
| `puls3_flutter/test/{domain,data,ui,screens}/...` | Create/Modify | Tests below |

## Interfaces / Contracts

```dart
// domain/skill_display_name.dart (no Flutter import)
String skillDisplayName(String id); // table hit, else id.replaceAll('-', ' ') with first char uppercased; '' -> ''

// data/server_agent_repository.dart
typedef AgentSummarySource = Future<List<AgentSummary>> Function();
class ServerAgentRepository implements AgentRepository {
  ServerAgentRepository(this._source, {this.timeout = defaultTimeout});
  static const defaultTimeout = Duration(seconds: 20);
  final Duration timeout;
  Future<List<Agent>> fetchAgents(); // (await _source().timeout(timeout)) mapped, nulls dropped, unmodifiable
  static Agent? fromSummary(AgentSummary s);
}

// data/fallback_agent_repository.dart
class FallbackAgentRepository implements AgentRepository {
  const FallbackAgentRepository(this.primary, this.fallback);
}
```

Mapper rules: `wallet == null || wallet.isEmpty` -> `null` (dropped, no trimming, no placeholder); `id/name/description/priceUsdcStroops` copied; `skills` = `List.unmodifiable(s.skills.map(skillDisplayName))`; `model` null or empty -> `'Unspecified'`; `stellarAddress` = wallet; `rating` = `0.0`. `registryId` unused.

`main.dart`:

```dart
repository: FallbackAgentRepository(
  ServerAgentRepository(() => client.agent.list()),
  AssetAgentRepository(),
),
```

`Future.timeout` does not cancel the underlying HTTP request; the late result is discarded.

## Testing Strategy (strict TDD, RED first per unit)

| Layer | What | Approach |
|---|---|---|
| Unit | `skillDisplayName`: 17 ids, `yield-farming`, `quant`, `''` | `test/domain/skill_display_name_test.dart` |
| Unit | Server repo: single call + order, error propagates, null/empty wallet dropped, all-dropped -> `[]`, model default, full mapping | `test/data/server_agent_repository_test.dart`, fake source counting calls, `AgentSummary(...)` from `puls3_client` |
| Unit | Timeout: never-completing `Completer` with `timeout: Duration(milliseconds: 10)` -> `TimeoutException`; fast source unaffected | plain `test` (real timers; `testWidgets` fake time would not fire) |
| Unit | Fallback: success not falling back, empty not falling back, throw / `AgentCatalogUnavailable` / `TimeoutException` -> fallback | counting fakes |
| Widget | `RatingBadge` 0.0 / -1.0 render no `Text`/`Icon`; 4.5 -> `4.5`; 5.0 -> `5.0` | `test/ui/rating_badge_test.dart` |
| Widget | Card and detail with rating 0.0: no exception, no rating text; phone and desktop sizes | `AgentCard` pumped directly; detail via `pumpApp(repository: ...)` |
| Widget | App: server source -> market shows `On-chain analytics`; throwing primary -> `testAgents` shown; empty primary -> empty market | `pumpApp` with composed repositories |

Local run (Flutter 3.38.2 / Dart 3.10; CI uses 3.41.4; SDK constraints `^3.8.0` / `^3.32.0` are satisfied):

    cd puls3_flutter
    flutter pub get
    flutter analyze --fatal-infos
    flutter test
    cd ..; git restore pubspec.lock   # workspace lock at root must not change

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.

## Migration / Rollout

No migration required. Rollback: restore `AssetAgentRepository()` in `main.dart`.

## Open Questions

- [ ] Is 20 s (Serverpod default) acceptable for the market, or should a shorter bound be chosen by the team? Non-blocking; the value is a constructor parameter.
- [ ] Accept the `Puls3Spacing.sm` leading gap in the detail `Wrap` for unrated agents, or allow a one-line conditional in `agent_detail_screen.dart`? Non-blocking.
