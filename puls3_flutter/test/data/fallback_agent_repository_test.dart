import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_client/puls3_client.dart';
import 'package:puls3_flutter/src/data/agent_repository.dart';
import 'package:puls3_flutter/src/data/fallback_agent_repository.dart';
import 'package:puls3_flutter/src/domain/agent.dart';

Agent agent(String id) => Agent(
  id: id,
  name: 'Agent $id',
  description: 'Does things.',
  skills: const ['Monitoring'],
  priceUsdcStroops: 5000000,
  rating: 0,
  stellarAddress: 'GABC',
  model: 'Unspecified',
);

/// Counts calls and either returns [agents] or throws [error].
class CountingRepository implements AgentRepository {
  CountingRepository({this.agents = const [], this.error});

  final List<Agent> agents;
  final Object? error;
  int calls = 0;

  @override
  Future<List<Agent>> fetchAgents() async {
    calls++;
    final failure = error;
    if (failure != null) throw failure;
    return agents;
  }
}

void main() {
  group('FallbackAgentRepository', () {
    test('returns the primary result and skips the fallback', () async {
      final primary = CountingRepository(agents: [agent('p1'), agent('p2')]);
      final fallback = CountingRepository(
        agents: [agent('f1'), agent('f2'), agent('f3')],
      );

      final result = await FallbackAgentRepository(
        primary,
        fallback,
      ).fetchAgents();

      expect(result.map((a) => a.id), ['p1', 'p2']);
      expect(primary.calls, 1);
      expect(fallback.calls, 0);
    });

    test('an empty primary result is returned without fallback', () async {
      final primary = CountingRepository();
      final fallback = CountingRepository(agents: [agent('f1')]);

      final result = await FallbackAgentRepository(
        primary,
        fallback,
      ).fetchAgents();

      expect(result, isEmpty);
      expect(primary.calls, 1);
      expect(fallback.calls, 0);
    });

    test('a thrown error falls back', () async {
      final fallback = CountingRepository(agents: [agent('f1')]);

      final result = await FallbackAgentRepository(
        CountingRepository(error: StateError('boom')),
        fallback,
      ).fetchAgents();

      expect(result.map((a) => a.id), ['f1']);
      expect(fallback.calls, 1);
    });

    test('AgentCatalogUnavailable falls back', () async {
      final fallback = CountingRepository(agents: [agent('f1')]);

      final result = await FallbackAgentRepository(
        CountingRepository(
          error: AgentCatalogUnavailable(message: 'rpc down'),
        ),
        fallback,
      ).fetchAgents();

      expect(result.map((a) => a.id), ['f1']);
      expect(fallback.calls, 1);
    });

    test('TimeoutException falls back', () async {
      final fallback = CountingRepository(agents: [agent('f1')]);

      final result = await FallbackAgentRepository(
        CountingRepository(error: TimeoutException('slow')),
        fallback,
      ).fetchAgents();

      expect(result.map((a) => a.id), ['f1']);
      expect(fallback.calls, 1);
    });

    test('a fallback error is not swallowed', () async {
      final error = StateError('asset missing');

      await expectLater(
        FallbackAgentRepository(
          CountingRepository(error: StateError('boom')),
          CountingRepository(error: error),
        ).fetchAgents(),
        throwsA(same(error)),
      );
    });
  });
}
