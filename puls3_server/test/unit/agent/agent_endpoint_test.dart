import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/agent/agent_catalog_service.dart';
import 'package:puls3_server/src/agent/agent_endpoint.dart';
import 'package:puls3_server/src/agent/registry_reader.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

/// The endpoint never touches the session, so a bare stand-in is enough.
final class _UnusedSession implements Session {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('The agent endpoint must not use the session');
}

final class _FakeRegistry implements RegistryReader {
  _FakeRegistry({this.unavailable = false});

  final bool unavailable;

  static const _agent = {
    'id': 'agt-001',
    'name': 'Ledger Scout',
    'description': 'Reads the ledger and reports what changed.',
    'skills': '["ledger-analysis"]',
    'priceUsdcStroops': '5000000',
  };

  @override
  Future<int> totalAgents() async {
    if (unavailable) throw const LedgerUnavailable('down');
    return 1;
  }

  @override
  Future<Uint8List?> agentMetadata(AgentId id, String key) async {
    final value = _agent[key];
    return value == null ? null : Uint8List.fromList(utf8.encode(value));
  }

  @override
  Future<StellarAddress?> agentWallet(AgentId id) async => null;
}

void main() {
  final session = _UnusedSession();
  final endpoint = AgentEndpoint();

  tearDown(() {
    AgentEndpoint.service = null;
    AgentEndpoint.defaultServiceBuilder = null;
  });

  test('list serves the injected service', () async {
    AgentEndpoint.service = AgentCatalogService(_FakeRegistry());

    final agents = await endpoint.list(session);

    expect(agents.map((a) => a.id), ['agt-001']);
    expect(agents.single.name, 'Ledger Scout');
  });

  test('get returns a known agent and null for an unknown id', () async {
    AgentEndpoint.service = AgentCatalogService(_FakeRegistry());

    expect((await endpoint.get(session, 'agt-001'))?.priceUsdcStroops, 5000000);
    expect(await endpoint.get(session, 'agt-999'), isNull);
  });

  test('list and get throw AgentCatalogUnavailable during an outage', () {
    AgentEndpoint.service = AgentCatalogService(
      _FakeRegistry(unavailable: true),
    );

    expect(
      endpoint.list(session),
      throwsA(isA<AgentCatalogUnavailable>()),
    );
    expect(
      endpoint.get(session, 'agt-001'),
      throwsA(isA<AgentCatalogUnavailable>()),
    );
  });

  test(
    'default service is built once on first use from the environment',
    () async {
      final urls = <Uri>[];
      var built = 0;
      AgentEndpoint.service = null;
      AgentEndpoint.defaultServiceBuilder = () {
        built++;
        return AgentEndpoint.buildDefaultService(
          environment: {'PULS3_STELLAR_RPC_URL': 'https://rpc.example.test'},
          httpClient: MockClient((http.Request request) async {
            urls.add(request.url);
            return http.Response('down', 503);
          }),
        );
      };

      expect(built, 0, reason: 'nothing is built before the first call');

      await expectLater(
        endpoint.list(session),
        throwsA(isA<AgentCatalogUnavailable>()),
      );
      await expectLater(
        endpoint.list(session),
        throwsA(isA<AgentCatalogUnavailable>()),
      );

      expect(built, 1, reason: 'the default service is reused');
      expect(urls, isNotEmpty);
      expect(urls.first.host, 'rpc.example.test');
    },
  );

  test('AgentSummary exposes exactly the catalog fields and no rating', () {
    final json = AgentSummary(
      id: 'agt-001',
      registryId: 1,
      name: 'n',
      description: 'd',
      skills: ['s'],
      priceUsdcStroops: 1,
      wallet: 'w',
      model: 'm',
    ).toJson();

    expect(
      json.keys.toSet()..remove('__className__'),
      {
        'id',
        'registryId',
        'name',
        'description',
        'skills',
        'priceUsdcStroops',
        'wallet',
        'model',
      },
    );
    expect(
      json.keys.where((k) => k.contains(RegExp('rating|reputation'))),
      isEmpty,
    );
  });
}
