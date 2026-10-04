import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/agent/agent_catalog_service.dart';
import 'package:puls3_server/src/agent/registry_reader.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:test/test.dart';

const _wallet = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';

/// Valid metadata for the seeded agent [n] (`agt-00n`).
Map<String, String> _metadata(
  int n, {
  Map<String, String?> overrides = const {},
}) {
  final metadata = <String, String?>{
    'id': 'agt-00$n',
    'name': 'Agent $n',
    'description': 'Does the job number $n well.',
    'skills': '["code-review","testing"]',
    'priceUsdcStroops': '${n * 1000000}',
    'model': 'claude-$n',
    ...overrides,
  };
  return {
    for (final entry in metadata.entries)
      if (entry.value != null) entry.key: entry.value!,
  };
}

/// A registry that answers from memory and counts and delays its reads.
final class _FakeRegistry implements RegistryReader {
  _FakeRegistry(this.metadata, {int? total, this.wallets = const {}})
    : total = total ?? metadata.length;

  /// Metadata by registry id; an id with no entry is an orphan.
  final Map<int, Map<String, String>> metadata;
  final Map<int, String> wallets;
  int total;

  int totalCalls = 0;
  int metadataCalls = 0;
  int inFlight = 0;
  int maxInFlight = 0;

  /// How long a metadata read of a registry id waits before answering.
  Duration Function(int id) delayFor = (_) => Duration.zero;

  /// Throws for any read when set.
  LedgerException? failure;

  /// Throws only when this agent's metadata is read.
  ({int id, LedgerException error})? failureForAgent;

  /// `totalAgents` waits for this to complete, when set.
  Completer<void>? totalGate;

  @override
  Future<int> totalAgents() async {
    totalCalls++;
    if (failure != null) throw failure!;
    await totalGate?.future;
    return total;
  }

  @override
  Future<Uint8List?> agentMetadata(AgentId id, String key) async {
    metadataCalls++;
    inFlight++;
    maxInFlight = max(maxInFlight, inFlight);
    try {
      await Future<void>.delayed(delayFor(id.value));
      if (failure != null) throw failure!;
      final scoped = failureForAgent;
      if (scoped != null && scoped.id == id.value) throw scoped.error;
      final value = metadata[id.value]?[key];
      return value == null ? null : Uint8List.fromList(utf8.encode(value));
    } finally {
      inFlight--;
    }
  }

  @override
  Future<StellarAddress?> agentWallet(AgentId id) async {
    final wallet = wallets[id.value];
    return wallet == null ? null : StellarAddress.parse(wallet);
  }
}

final class _Clock {
  DateTime now = DateTime.utc(2026, 10, 4, 12);
  DateTime call() => now;
  void advance(Duration by) => now = now.add(by);
}

final _throwsUnavailable = throwsA(isA<AgentCatalogUnavailable>());

void main() {
  late _Clock clock;

  setUp(() => clock = _Clock());

  AgentCatalogService serviceOver(_FakeRegistry registry) =>
      AgentCatalogService(registry, now: clock.call);

  group('list', () {
    test('maps valid metadata and the optional wallet and model', () async {
      final registry = _FakeRegistry(
        {
          0: _metadata(1),
          1: _metadata(2, overrides: {'model': null}),
        },
        wallets: {0: _wallet},
      );

      final agents = await serviceOver(registry).list();

      expect(agents, hasLength(2));
      expect(agents[0].id, 'agt-001');
      expect(agents[0].registryId, 0);
      expect(agents[0].name, 'Agent 1');
      expect(agents[0].description, 'Does the job number 1 well.');
      expect(agents[0].skills, ['code-review', 'testing']);
      expect(agents[0].priceUsdcStroops, 1000000);
      expect(agents[0].wallet, _wallet);
      expect(agents[0].model, 'claude-1');
      expect(agents[1].wallet, isNull);
      expect(agents[1].model, isNull);
    });

    test('skips orphans 0-6 and returns the agents 7-14', () async {
      final registry = _FakeRegistry({
        for (var id = 0; id < 7; id++) id: {'name': 'Orphan $id'},
        for (var id = 7; id < 15; id++) id: _metadata(id - 6),
      });

      final agents = await serviceOver(registry).list();

      expect(agents.map((a) => a.registryId), [7, 8, 9, 10, 11, 12, 13, 14]);
      expect(agents.first.id, 'agt-001');
      expect(agents.last.id, 'agt-008');
    });

    test('an empty registry gives an empty list without an error', () async {
      final registry = _FakeRegistry({}, total: 0);

      expect(await serviceOver(registry).list(), isEmpty);
      expect(registry.totalCalls, 1);
      expect(registry.metadataCalls, 0);
    });

    test('skips an agent with invalid metadata, keeps the others', () async {
      final registry = _FakeRegistry({
        0: _metadata(1),
        1: _metadata(2, overrides: {'skills': 'not json'}),
        2: _metadata(3, overrides: {'priceUsdcStroops': '9007199254740992'}),
        3: _metadata(4, overrides: {'name': null}),
        4: _metadata(5),
      });

      final agents = await serviceOver(registry).list();

      expect(agents.map((a) => a.id), ['agt-001', 'agt-005']);
    });

    test('an invalid model becomes null and the agent stays', () async {
      final registry = _FakeRegistry({
        0: _metadata(1, overrides: {'model': ''}),
      });

      final agents = await serviceOver(registry).list();

      expect(agents.single.id, 'agt-001');
      expect(agents.single.model, isNull);
    });

    test('keeps the highest registry id when a metadata id repeats', () async {
      final registry = _FakeRegistry({
        0: _metadata(1, overrides: {'name': 'First registration'}),
        1: _metadata(2),
        2: _metadata(1, overrides: {'name': 'Second registration'}),
      });

      final agents = await serviceOver(registry).list();

      expect(agents.map((a) => a.id), ['agt-002', 'agt-001']);
      expect(agents.map((a) => a.registryId), [1, 2]);
      expect(agents.last.name, 'Second registration');
    });

    test('orders by registry id even when reads finish out of order', () async {
      final registry = _FakeRegistry({
        for (var id = 0; id < 6; id++) id: _metadata(id + 1),
      })..delayFor = (id) => Duration(milliseconds: (6 - id) * 5);

      final agents = await serviceOver(registry).list();

      expect(agents.map((a) => a.registryId), [0, 1, 2, 3, 4, 5]);
    });

    test('reads at most 4 agents at once and processes all of them', () async {
      final registry = _FakeRegistry({
        for (var id = 0; id < 15; id++) id: _metadata(id + 1),
      })..delayFor = (_) => const Duration(milliseconds: 5);

      final agents = await serviceOver(registry).list();

      expect(agents, hasLength(15));
      expect(registry.maxInFlight, 4);
    });
  });

  group('cache', () {
    test('a second call inside the TTL does not read the chain', () async {
      final registry = _FakeRegistry({0: _metadata(1)});
      final service = serviceOver(registry);

      final first = await service.list();
      final reads = registry.metadataCalls;
      clock.advance(const Duration(seconds: 59));
      final second = await service.list();

      expect(second, same(first));
      expect(registry.totalCalls, 1);
      expect(registry.metadataCalls, reads);
    });

    test('a call after the TTL rebuilds the list from the chain', () async {
      final registry = _FakeRegistry({0: _metadata(1)});
      final service = serviceOver(registry);
      await service.list();

      registry.metadata[1] = _metadata(2);
      registry.total = 2;
      clock.advance(const Duration(seconds: 60));
      final agents = await service.list();

      expect(registry.totalCalls, 2);
      expect(agents.map((a) => a.id), ['agt-001', 'agt-002']);
    });

    test('an outage after the TTL returns the stale list', () async {
      final registry = _FakeRegistry({0: _metadata(1)});
      final service = serviceOver(registry);
      final fresh = await service.list();

      registry.failure = const LedgerUnavailable('down');
      clock.advance(const Duration(minutes: 5));
      final stale = await service.list();

      expect(registry.totalCalls, 2);
      expect(stale.single.id, fresh.single.id);
    });

    test('a failed refresh is retried by the next call', () async {
      final registry = _FakeRegistry({0: _metadata(1)});
      final service = serviceOver(registry);
      await service.list();
      clock.advance(const Duration(minutes: 5));

      registry.failure = const LedgerUnavailable('down');
      await service.list();
      registry.failure = null;
      registry.metadata[1] = _metadata(2);
      registry.total = 2;
      final recovered = await service.list();

      expect(registry.totalCalls, 3);
      expect(recovered.map((a) => a.id), ['agt-001', 'agt-002']);
    });

    test('concurrent calls share one refresh', () async {
      final registry = _FakeRegistry({0: _metadata(1)})
        ..totalGate = Completer<void>();
      final service = serviceOver(registry);

      final calls = [service.list(), service.list(), service.list()];
      await Future<void>.delayed(Duration.zero);
      registry.totalGate!.complete();
      final results = await Future.wait(calls);

      expect(registry.totalCalls, 1);
      expect(results[1], same(results[0]));
      expect(results[2], same(results[0]));
    });
  });

  group('outage', () {
    test('without a cache list throws and never returns empty', () {
      final registry = _FakeRegistry({0: _metadata(1)})
        ..failure = const LedgerUnavailable('down');

      expect(serviceOver(registry).list(), _throwsUnavailable);
    });

    test('without a cache get throws instead of returning null', () {
      final registry = _FakeRegistry({0: _metadata(1)})
        ..failure = const LedgerUnavailable('down');

      expect(serviceOver(registry).get('agt-001'), _throwsUnavailable);
    });

    test('a failure reading one agent aborts the refresh', () {
      final registry = _FakeRegistry({0: _metadata(1), 1: _metadata(2)})
        ..failureForAgent = (id: 1, error: const LedgerUnavailable('down'));

      expect(serviceOver(registry).list(), _throwsUnavailable);
    });

    test('a contract error aborts the refresh, the stale list stays', () async {
      final registry = _FakeRegistry({0: _metadata(1), 1: _metadata(2)});
      final service = serviceOver(registry);
      await service.list();

      registry.failureForAgent = (
        id: 1,
        error: const LedgerContractError(3, 'unexpected'),
      );
      clock.advance(const Duration(minutes: 5));
      final stale = await service.list();

      expect(stale.map((a) => a.id), ['agt-001', 'agt-002']);
    });
  });

  group('get', () {
    test('returns the agent with that metadata id', () async {
      final registry = _FakeRegistry({0: _metadata(1), 1: _metadata(2)});

      final agent = await serviceOver(registry).get('agt-002');

      expect(agent?.registryId, 1);
      expect(agent?.name, 'Agent 2');
    });

    test('returns null for an unknown id', () async {
      final registry = _FakeRegistry({0: _metadata(1)});

      expect(await serviceOver(registry).get('agt-999'), isNull);
    });

    test('reads the cached list instead of the chain', () async {
      final registry = _FakeRegistry({0: _metadata(1)});
      final service = serviceOver(registry);
      await service.list();

      await service.get('agt-001');

      expect(registry.totalCalls, 1);
    });
  });
}
