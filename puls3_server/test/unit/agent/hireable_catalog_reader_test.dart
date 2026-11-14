import 'package:puls3_server/src/agent/catalog_reader.dart';
import 'package:puls3_server/src/agent/hireable_catalog_reader.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:test/test.dart';

const _custodiedWallet =
    'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';
const _otherWallet =
    'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';

AgentSummary _agent(String id, int registryId, {String? wallet}) =>
    AgentSummary(
      id: id,
      registryId: registryId,
      name: 'Agent $registryId',
      description: 'A helpful test agent for verification.',
      skills: const ['coding'],
      priceUsdcStroops: 5000000,
      wallet: wallet,
    );

final class _FakeCatalog implements CatalogReader {
  _FakeCatalog(this.agents);

  final List<AgentSummary> agents;

  @override
  Future<List<AgentSummary>> list() async => agents;

  @override
  Future<AgentSummary?> get(String id) async {
    for (final agent in agents) {
      if (agent.id == id) return agent;
    }
    return null;
  }
}

void main() {
  late List<Set<String>> asked;

  Future<Set<String>> custody(Set<String> addresses) async {
    asked.add(addresses);
    return addresses.where((address) => address == _custodiedWallet).toSet();
  }

  setUp(() => asked = []);

  test('list marks only custodied agent wallets hireable', () async {
    final reader = HireableCatalogReader(
      inner: _FakeCatalog([
        _agent('agt-001', 7, wallet: _custodiedWallet),
        _agent('agt-002', 8, wallet: _otherWallet),
        _agent('agt-003', 9),
      ]),
      custody: custody,
    );

    final agents = await reader.list();

    expect(
      {for (final agent in agents) agent.id: agent.hireable},
      {'agt-001': true, 'agt-002': false, 'agt-003': false},
    );
  });

  test('list asks the custody rule once, for every wallet', () async {
    final reader = HireableCatalogReader(
      inner: _FakeCatalog([
        _agent('agt-001', 7, wallet: _custodiedWallet),
        _agent('agt-002', 8, wallet: _otherWallet),
      ]),
      custody: custody,
    );

    await reader.list();

    expect(asked, [
      {_custodiedWallet, _otherWallet},
    ]);
  });

  test('get marks the agent with the same rule', () async {
    final reader = HireableCatalogReader(
      inner: _FakeCatalog([
        _agent('agt-001', 7, wallet: _custodiedWallet),
        _agent('agt-002', 8, wallet: _otherWallet),
      ]),
      custody: custody,
    );

    expect((await reader.get('agt-001'))!.hireable, isTrue);
    expect((await reader.get('agt-002'))!.hireable, isFalse);
    expect(asked, [
      {_custodiedWallet},
      {_otherWallet},
    ]);
  });

  test('get of an unknown id does not ask about custody', () async {
    final reader = HireableCatalogReader(
      inner: _FakeCatalog([_agent('agt-001', 7, wallet: _custodiedWallet)]),
      custody: custody,
    );

    expect(await reader.get('nope'), isNull);
    expect(asked, isEmpty);
  });

  test('an agent without a wallet never becomes hireable', () async {
    final reader = HireableCatalogReader(
      inner: _FakeCatalog([_agent('agt-001', 7)]),
      custody: custody,
    );

    final agent = await reader.get('agt-001');

    expect(agent!.hireable, isFalse);
    expect(asked, isEmpty);
  });
}
