import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/agent/catalog_reader.dart';
import 'package:puls3_server/src/agent/reputation_catalog_reader.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:test/test.dart';

import '../support/fake_feedback_ports.dart';
import '../support/relay_rig.dart';

AgentSummary _agent(String id, int registryId) => AgentSummary(
  id: id,
  registryId: registryId,
  name: 'Agent $registryId',
  description: 'A helpful test agent for verification.',
  skills: const ['coding'],
  priceUsdcStroops: 5000000,
  wallet: agentWallet,
);

final class _FakeCatalog implements CatalogReader {
  _FakeCatalog(this.agents);

  final List<AgentSummary> agents;
  Object? failure;

  @override
  Future<List<AgentSummary>> list() async {
    if (failure != null) throw failure!;
    return agents;
  }

  @override
  Future<AgentSummary?> get(String id) async {
    if (failure != null) throw failure!;
    return agents.where((a) => a.id == id).firstOrNull;
  }
}

Feedback _feedback(int agent, int score, int hire) => Feedback(
  hireId: HireId(hire),
  agentId: AgentId(agent),
  client: StellarAddress.parse(alice),
  score: score,
);

void main() {
  late FakeReputationRegistry registry;
  late _FakeCatalog inner;
  late DateTime now;
  late ReputationCatalogReader reader;

  setUp(() {
    registry = FakeReputationRegistry();
    inner = _FakeCatalog([_agent('agt-001', 7), _agent('agt-002', 8)]);
    now = DateTime.utc(2026, 10, 13, 12);
    reader = ReputationCatalogReader(
      inner: inner,
      cache: ReputationCache(registry: registry, now: () => now),
    );
  });

  group('values', () {
    test('equal a direct #11 call on the same feedback', () async {
      registry.given.addAll([
        _feedback(7, 5, 1),
        _feedback(7, 5, 2),
        _feedback(7, 3, 3),
        _feedback(8, 1, 4),
      ]);

      final agents = await reader.list();

      final first = agents.firstWhere((a) => a.registryId == 7);
      final second = agents.firstWhere((a) => a.registryId == 8);
      expect(first.rating, reputationOf(registry.given.take(3)));
      expect(first.paidHireCount, 3);
      expect(second.rating, reputationOf(registry.given.skip(3)));
      expect(second.paidHireCount, 1);
      expect(first.rating, isNot(second.rating));
    });

    test('get returns the same values as list', () async {
      registry.given.addAll([_feedback(7, 4, 1), _feedback(7, 2, 2)]);

      final listed = (await reader.list()).first;
      final got = (await reader.get('agt-001'))!;

      expect(got.rating, listed.rating);
      expect(got.rating, reputationOf(registry.given));
      expect(got.paidHireCount, 2);
    });

    test('the other fields are the inner reader fields', () async {
      final got = (await reader.get('agt-001'))!;

      expect(got.id, 'agt-001');
      expect(got.registryId, 7);
      expect(got.name, 'Agent 7');
      expect(got.wallet, agentWallet);
    });

    test('an agent without feedback gets the #11 empty-input value', () async {
      final agents = await reader.list();

      expect(agents, hasLength(2));
      for (final agent in agents) {
        expect(agent.rating, reputationOf(const []));
        expect(agent.rating, reputationPriorMean);
        expect(agent.paidHireCount, 0);
      }
    });

    test('an unknown id is null and reads no reputation', () async {
      expect(await reader.get('agt-404'), isNull);
      expect(registry.reads, 0);
    });

    test('the wire default of a summary is the empty-input value', () {
      expect(_agent('agt-009', 9).rating, reputationPriorMean);
      expect(_agent('agt-009', 9).paidHireCount, 0);
    });
  });

  group('cache', () {
    test('reads the registry once per agent within the TTL', () async {
      registry.given.add(_feedback(7, 5, 1));
      await reader.list();
      final reads = registry.reads;
      registry.given.add(_feedback(7, 1, 2));
      now = now.add(const Duration(seconds: 59));

      final again = await reader.list();

      expect(registry.reads, reads);
      expect(again.first.paidHireCount, 1);
    });

    test('refreshes once the TTL has passed', () async {
      registry.given.add(_feedback(7, 5, 1));
      await reader.list();
      registry.given.add(_feedback(7, 1, 2));
      now = now.add(const Duration(seconds: 61));

      final again = await reader.list();

      expect(again.first.paidHireCount, 2);
      expect(again.first.rating, reputationOf(registry.given));
    });
  });

  group('source failure', () {
    test('serves the last values, never made-up ones', () async {
      registry.given.addAll([_feedback(7, 5, 1), _feedback(7, 5, 2)]);
      final before = (await reader.list()).first;
      registry.failure = const LedgerUnavailable('down');
      now = now.add(const Duration(minutes: 5));

      final during = await reader.list();

      expect(during.first.rating, before.rating);
      expect(during.first.paidHireCount, 2);
      expect(registry.reads, greaterThan(2));
    });

    test('with nothing cached it is AgentCatalogUnavailable', () async {
      registry.failure = const LedgerUnavailable('down');

      await expectLater(reader.list(), throwsA(isA<AgentCatalogUnavailable>()));
      await expectLater(
        reader.get('agt-001'),
        throwsA(isA<AgentCatalogUnavailable>()),
      );
    });

    test('list keeps an agent whose reputation cannot be read, with the '
        'default values', () async {
      registry.given.addAll([_feedback(7, 5, 1), _feedback(8, 1, 2)]);
      registry.unreadable.add(AgentId(8));

      final agents = await reader.list();

      expect(agents.map((a) => a.registryId), [7, 8]);
      final readable = agents.first;
      final degraded = agents.last;
      expect(readable.rating, reputationOf(registry.given.take(1)));
      expect(readable.paidHireCount, 1);
      expect(degraded.rating, reputationPriorMean);
      expect(degraded.paidHireCount, 0);
      expect(degraded.name, 'Agent 8');
    });

    test('a degraded agent is read again, not cached', () async {
      registry.unreadable.add(AgentId(8));
      await reader.list();
      final reads = registry.reads;
      registry.unreadable.clear();
      registry.given.add(_feedback(8, 5, 2));

      final again = await reader.list();

      expect(registry.reads, greaterThan(reads));
      expect(again.last.paidHireCount, 1);
      expect(again.last.rating, reputationOf(registry.given));
    });

    test('get of an unreadable agent still throws, even when list degrades '
        'it', () async {
      registry.unreadable.add(AgentId(8));

      expect((await reader.list()).last.paidHireCount, 0);
      await expectLater(
        reader.get('agt-002'),
        throwsA(isA<AgentCatalogUnavailable>()),
      );
      expect((await reader.get('agt-001'))!.registryId, 7);
    });

    test(
      'when no agent can be read, list is AgentCatalogUnavailable',
      () async {
        registry.unreadable.addAll([AgentId(7), AgentId(8)]);

        await expectLater(
          reader.list(),
          throwsA(isA<AgentCatalogUnavailable>()),
        );
      },
    );

    test('an inner failure is passed through untouched', () async {
      final failure = AgentCatalogUnavailable(message: 'chain down');
      inner.failure = failure;

      await expectLater(reader.list(), throwsA(same(failure)));
      expect(registry.reads, 0);
    });
  });
}
