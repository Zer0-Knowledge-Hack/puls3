import 'dart:convert';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/agent/agent_index_repository.dart';
import 'package:puls3_server/src/agent/catalog_indexer.dart';
import 'package:puls3_server/src/agent/registry_event_reader.dart';
import 'package:puls3_server/src/agent/registry_reader.dart';
import 'package:puls3_server/src/chain/chain_log.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/ledger/registry_events.dart';
import 'package:test/test.dart';

const _wallet = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';
const _owner = 'GA' 'FUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';

/// Valid metadata for the seeded agent [n] (`agt-00n`).
Map<String, String> _metadata(int n) => {
  'id': 'agt-00$n',
  'name': 'Agent $n',
  'description': 'Does the job number $n well.',
  'skills': '["code-review","testing"]',
  'priceUsdcStroops': '${n * 1000000}',
  'model': 'claude-$n',
};

final class _FakeRegistry implements RegistryReader {
  _FakeRegistry(this.metadata, {int? total, this.wallets = const {}})
    : total = total ?? metadata.length;

  final Map<int, Map<String, String>> metadata;
  final Map<int, String> wallets;
  int total;
  LedgerException? failure;

  @override
  Future<int> totalAgents() async {
    if (failure != null) throw failure!;
    return total;
  }

  @override
  Future<Uint8List?> agentMetadata(AgentId id, String key) async {
    if (failure != null) throw failure!;
    final value = metadata[id.value]?[key];
    return value == null ? null : Uint8List.fromList(utf8.encode(value));
  }

  @override
  Future<StellarAddress?> agentWallet(AgentId id) async {
    final wallet = wallets[id.value];
    return wallet == null ? null : StellarAddress.parse(wallet);
  }
}

final class _FakeEvents implements RegistryEventReader {
  _FakeEvents({required this.latest, this.events = const []});

  int latest;
  List<RegistryEvent> events;
  LedgerException? latestFailure;
  LedgerException? eventsFailure;
  int? sinceCalled;

  @override
  Future<int> latestLedger() async {
    if (latestFailure != null) throw latestFailure!;
    return latest;
  }

  @override
  Future<List<RegistryEvent>> eventsSince(int startLedger) async {
    sinceCalled = startLedger;
    if (eventsFailure != null) throw eventsFailure!;
    return events;
  }
}

final class _InMemoryIndex implements AgentIndexRepository {
  final Map<int, AgentSummary> rows = {};
  int? checkpoint;

  @override
  Future<List<AgentSummary>> list() async {
    final newest = <String, AgentSummary>{};
    for (final agent in rows.values) {
      final current = newest[agent.id];
      if (current == null || agent.registryId > current.registryId) {
        newest[agent.id] = agent;
      }
    }
    return newest.values.toList()
      ..sort((a, b) => a.registryId.compareTo(b.registryId));
  }

  @override
  Future<AgentSummary?> findByAgentId(String agentId) async {
    AgentSummary? found;
    for (final agent in rows.values) {
      if (agent.id == agentId &&
          (found == null || agent.registryId > found.registryId)) {
        found = agent;
      }
    }
    return found;
  }

  @override
  Future<Set<int>> registryIds() async => rows.keys.toSet();

  @override
  Future<void> upsertAll(List<AgentSummary> agents) async {
    for (final agent in agents) {
      rows[agent.registryId] = agent;
    }
  }

  @override
  Future<int?> lastProcessedLedger() async => checkpoint;

  @override
  Future<void> setLastProcessedLedger(int ledger) async {
    checkpoint = ledger;
  }
}

RegisteredEvent _registered(int agentId) => RegisteredEvent(
  agentId: agentId,
  owner: StellarAddress.parse(_owner),
  uri: 'puls3://demo/agt-00$agentId',
);

void main() {
  const log = ignoreChainLog;

  CatalogIndexer indexer(
    _FakeRegistry registry,
    _FakeEvents events,
    _InMemoryIndex index,
  ) => CatalogIndexer(
    registry: registry,
    events: events,
    repository: index,
    log: log,
  );

  test('the first pass bootstraps every agent from state', () async {
    final registry = _FakeRegistry({
      0: _metadata(1),
      1: _metadata(2),
    }, wallets: {0: _wallet});
    final events = _FakeEvents(latest: 500);
    final index = _InMemoryIndex();

    final summary = await indexer(registry, events, index).pass();

    expect(summary.hydrated, 2);
    expect(summary.events, 0);
    expect(index.checkpoint, 500);
    expect(index.rows, hasLength(2));
    expect(index.rows[0]!.id, 'agt-001');
    expect(index.rows[0]!.wallet, _wallet);
    expect(events.sinceCalled, isNull);
  });

  test('a later pass reads only events after the cursor', () async {
    final registry = _FakeRegistry({0: _metadata(1), 1: _metadata(2)});
    final events = _FakeEvents(
      latest: 600,
      events: [_registered(1)],
    );
    final index = _InMemoryIndex()
      ..rows[0] = AgentSummary(
        id: 'agt-001',
        registryId: 0,
        name: 'Agent 1',
        description: 'Does the job number 1 well.',
        skills: const ['code-review'],
        priceUsdcStroops: 1000000,
      )
      ..checkpoint = 500;

    final summary = await indexer(registry, events, index).pass();

    expect(events.sinceCalled, 501);
    expect(summary.events, 1);
    expect(summary.hydrated, 1);
    expect(index.checkpoint, 600);
    expect(index.rows, hasLength(2));
  });

  test('missing agents are recovered even without an event', () async {
    final registry = _FakeRegistry({0: _metadata(1), 1: _metadata(2)});
    final events = _FakeEvents(latest: 600);
    final index = _InMemoryIndex()
      ..rows[0] = AgentSummary(
        id: 'agt-001',
        registryId: 0,
        name: 'Agent 1',
        description: 'Does the job number 1 well.',
        skills: const ['code-review'],
        priceUsdcStroops: 1000000,
      )
      ..checkpoint = 500;

    final summary = await indexer(registry, events, index).pass();

    expect(summary.hydrated, 1);
    expect(index.rows, hasLength(2));
    expect(index.rows[1]!.id, 'agt-002');
  });

  test('running twice does not duplicate rows', () async {
    final registry = _FakeRegistry({0: _metadata(1), 1: _metadata(2)});
    final events = _FakeEvents(latest: 500);
    final index = _InMemoryIndex();
    final subject = indexer(registry, events, index);

    await subject.pass();
    final second = await subject.pass();

    expect(index.rows, hasLength(2));
    expect(second.hydrated, 0, reason: 'nothing changed and nothing is missing');
    expect(index.checkpoint, 500);
  });

  test('skips an agent whose metadata is invalid', () async {
    final registry = _FakeRegistry({
      0: _metadata(1),
      1: _metadata(2)..['skills'] = 'not json',
    });
    final index = _InMemoryIndex();

    final summary = await indexer(
      registry,
      _FakeEvents(latest: 500),
      index,
    ).pass();

    expect(summary.hydrated, 1);
    expect(summary.skipped, 1);
    expect(index.rows.keys, [0]);
  });

  test('a chain outage aborts the pass and leaves the index untouched', () {
    final registry = _FakeRegistry({0: _metadata(1)});
    final index = _InMemoryIndex();
    final events = _FakeEvents(latest: 500)
      ..latestFailure = const LedgerUnavailable('down');

    expect(
      indexer(registry, events, index).pass(),
      throwsA(isA<LedgerUnavailable>()),
    );
    expect(index.rows, isEmpty);
    expect(index.checkpoint, isNull);
  });

  test('a retention gap advances the cursor and recovers from state', () async {
    final registry = _FakeRegistry({0: _metadata(1), 1: _metadata(2)});
    final index = _InMemoryIndex()..checkpoint = 1;
    final events = _FakeEvents(latest: 900)
      ..eventsFailure = const RpcRequestRejected(-32602, 'bad', 'out of range');

    final summary = await indexer(registry, events, index).pass();

    expect(summary.hydrated, 2);
    expect(index.checkpoint, 900);
  });
}
