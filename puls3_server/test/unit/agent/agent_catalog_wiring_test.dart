import 'package:puls3_server/src/agent/agent_catalog_wiring.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

/// The wiring never touches the session while building, so a stand-in is
/// enough.
final class _UnusedSession implements Session {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('The wiring must not use the session');
}

void main() {
  tearDown(resetChainCatalog);

  test('the on-chain fallback is built once per process', () {
    resetChainCatalog();
    final session = _UnusedSession();

    buildAgentCatalogReader(session);
    buildAgentCatalogReader(session);

    expect(chainCatalogBuilds, 1);
  });

  test('an injected environment builds an isolated fallback', () {
    resetChainCatalog();
    final session = _UnusedSession();
    const environment = {'PULS3_STELLAR_RPC_URL': 'https://rpc.example.test'};

    buildAgentCatalogReader(session, environment: environment);
    buildAgentCatalogReader(session, environment: environment);

    expect(chainCatalogBuilds, 0, reason: 'the process singleton is untouched');
  });
}
