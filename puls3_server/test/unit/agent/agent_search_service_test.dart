import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/agent/agent_owners.dart';
import 'package:puls3_server/src/agent/agent_search_service.dart';
import 'package:puls3_server/src/agent/catalog_reader.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/hire_lifecycle_store.dart';
import 'package:test/test.dart';

import '../../support/in_memory_hire_lifecycle_store.dart';

const _ownerA = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _ownerB = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';

AgentSummary _agent(
  int registryId, {
  List<String> skills = const ['translation'],
  int price = 1000000,
  String? wallet,
  bool hireable = true,
  double rating = 4.0,
  int paidHireCount = 0,
}) => AgentSummary(
  id: 'agt-$registryId',
  registryId: registryId,
  name: 'Agent $registryId',
  description: 'Translates documents.',
  skills: skills,
  priceUsdcStroops: price,
  wallet: wallet ?? 'wallet-$registryId',
  rating: rating,
  paidHireCount: paidHireCount,
  hireable: hireable,
);

final class _FakeCatalog implements CatalogReader {
  _FakeCatalog(this.agents);

  final List<AgentSummary> agents;

  @override
  Future<List<AgentSummary>> list() async => agents;

  @override
  Future<AgentSummary?> get(String id) async => null;
}

final class _FakeOwnerReader implements AgentOwnerReader {
  _FakeOwnerReader(this.owners, {this.failing = const {}});

  final Map<int, String> owners;
  final Set<int> failing;

  @override
  Future<StellarAddress?> ownerOf(AgentId agent) async {
    if (failing.contains(agent.value)) throw Exception('rpc down');
    final owner = owners[agent.value];
    return owner == null ? null : StellarAddress.parse(owner);
  }
}

NewHire _hire(int agentId, {int? parent, bool allowRelatedParty = true}) =>
    NewHire(
      consumer: 'consumer',
      agentId: agentId,
      price: 1000000,
      manifestVersion: 1,
      expiredAt: 0,
      requestId: 'req-$agentId-$parent',
      input: 'task',
      subcontractReserve: 5000000,
      allowRelatedParty: allowRelatedParty,
      parentHireId: parent,
    );

void main() {
  late InMemoryHireLifecycleStore hires;
  late List<Set<int>> ownerQueries;

  AgentOwnersLookup ownersFrom(Map<int, Set<String>?> table) => (ids) async {
    ownerQueries.add(ids);
    return {
      for (final id in ids)
        if (table.containsKey(id)) id: table[id],
    };
  };

  AgentSearchService service(
    List<AgentSummary> agents, {
    Map<int, Set<String>?>? owners,
  }) => AgentSearchService(
    catalog: _FakeCatalog(agents),
    hires: hires,
    owners: ownersFrom(
      owners ??
          {
            1: {_ownerA},
            for (var id = 2; id < 20; id++) id: {_ownerB},
          },
    ),
  );

  List<int> ids(List<AgentCandidate> candidates) => [
    for (final c in candidates) c.registryId,
  ];

  setUp(() {
    hires = InMemoryHireLifecycleStore();
    ownerQueries = [];
  });

  test(
    'excludes the hiring agent and every ancestor by id and wallet',
    () async {
      final root = await hires.insertHire(_hire(3));
      final middle = await hires.insertHire(_hire(2, parent: root.id));
      final child = await hires.insertHire(_hire(1, parent: middle.id));

      final result =
          await service([
            _agent(1),
            _agent(2),
            _agent(3, wallet: 'wallet-root'),
            _agent(4, wallet: 'wallet-root'),
            _agent(5),
          ]).search(
            hireId: child.id,
            remainingReserveStroops: 5000000,
            query: 'translation',
          );

      expect(ids(result), [5]);
    },
  );

  test('filters out unhireable agents and agents above the reserve', () async {
    final hire = await hires.insertHire(_hire(1));

    final result =
        await service([
          _agent(2, hireable: false),
          _agent(3, price: 2000001),
          _agent(4, price: 2000000),
        ]).search(
          hireId: hire.id,
          remainingReserveStroops: 2000000,
          query: '',
        );

    expect(ids(result), [4]);
  });

  test('reads owners only for the hiring agent and eligible agents', () async {
    final hire = await hires.insertHire(_hire(1));

    await service([
      _agent(1),
      _agent(2),
      _agent(3, hireable: false),
    ]).search(hireId: hire.id, remainingReserveStroops: 5000000, query: '');

    expect(ownerQueries, [
      {1, 2},
    ]);
  });

  test(
    'flags related parties and drops them when any hire opted out',
    () async {
      final owners = {
        1: {_ownerA},
        2: {_ownerA},
        3: {_ownerB},
      };
      final allowing = await hires.insertHire(_hire(1));
      final kept =
          await service([
            _agent(2),
            _agent(3),
          ], owners: owners).search(
            hireId: allowing.id,
            remainingReserveStroops: 5000000,
            query: '',
          );
      expect(ids(kept), [2, 3]);
      expect(kept.first.isRelatedParty, isTrue);
      expect(kept.last.isRelatedParty, isFalse);

      final root = await hires.insertHire(_hire(9, allowRelatedParty: false));
      final child = await hires.insertHire(_hire(1, parent: root.id));
      final filtered =
          await service([
            _agent(2),
            _agent(3),
          ], owners: owners).search(
            hireId: child.id,
            remainingReserveStroops: 5000000,
            query: '',
          );
      expect(ids(filtered), [3]);
    },
  );

  test('an unknown owner is a related party and an opt-out drops it', () async {
    final hire = await hires.insertHire(_hire(1, allowRelatedParty: false));
    final result = await service(
      [
        _agent(2),
        _agent(3),
      ],
      owners: {
        1: {_ownerA},
        2: null,
        3: {_ownerB},
      },
    ).search(hireId: hire.id, remainingReserveStroops: 5000000, query: '');

    expect(ids(result), [3]);
  });

  test('ranks with the catalog rating, hires and skills, limited', () async {
    final hire = await hires.insertHire(_hire(1));
    final result =
        await service([
          for (var id = 2; id < 15; id++) _agent(id, rating: 3.0 + id / 10),
          _agent(15, skills: ['poetry'], rating: 5, paidHireCount: 99),
        ]).search(
          hireId: hire.id,
          remainingReserveStroops: 5000000,
          query: 'documents',
          skills: const ['translation'],
        );

    expect(result, hasLength(defaultAgentSearchLimit));
    expect(result.first.registryId, 14);
    expect(ids(result), isNot(contains(15)));
    expect(result.first.paidHireCount, 0);
    expect(result.first.rating, closeTo(4.4, 1e-9));
  });

  test('a missing hire or a broken chain cannot be searched', () async {
    final orphan = await hires.insertHire(_hire(1, parent: 999));
    final search = service([_agent(2)]);

    await expectLater(
      search.search(hireId: 404, remainingReserveStroops: 1, query: ''),
      throwsA(isA<AgentSearchContextMissing>()),
    );
    await expectLater(
      search.search(hireId: orphan.id, remainingReserveStroops: 1, query: ''),
      throwsA(isA<AgentSearchContextMissing>()),
    );
  });

  group('owner lookups', () {
    test(
      'registry owners: absent stays absent, a failure is unknown',
      () async {
        final lookup = registryOwnersLookup(
          _FakeOwnerReader({1: _ownerA}, failing: {3}),
        );
        expect(await lookup({1, 2, 3}), {
          1: {_ownerA},
          3: null,
        });
      },
    );

    test('combined owners union sources and keep unknown sticky', () async {
      Future<Map<int, Set<String>?>> first(Set<int> ids) async => {
        1: {'x'},
        2: {'y'},
      };
      Future<Map<int, Set<String>?>> second(Set<int> ids) async => {
        1: {'z'},
        2: null,
        3: {'w'},
      };

      final owners = await combinedOwnersLookup([first, second])({1, 2, 3});

      expect(owners, {
        1: {'x', 'z'},
        2: null,
        3: {'w'},
      });
    });

    test('a failing source makes every asked agent unknown', () async {
      Future<Map<int, Set<String>?>> broken(Set<int> ids) async =>
          throw Exception('db down');

      expect(await combinedOwnersLookup([broken])({1, 2}), {
        1: null,
        2: null,
      });
    });
  });
}
