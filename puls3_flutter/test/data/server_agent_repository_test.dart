import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_client/puls3_client.dart';
import 'package:puls3_flutter/src/data/server_agent_repository.dart';

AgentSummary summary({
  String id = 'a1',
  String name = 'Atlas',
  String? wallet = 'GABC',
  String? model = 'gpt-x',
  List<String> skills = const ['on-chain-analytics', 'monitoring'],
}) => AgentSummary(
  id: id,
  registryId: 1,
  name: name,
  description: 'Reads chains',
  skills: skills,
  priceUsdcStroops: 5000000,
  wallet: wallet,
  model: model,
);

void main() {
  group('ServerAgentRepository', () {
    test('invokes the source once and keeps source order', () async {
      var calls = 0;
      final repository = ServerAgentRepository(() async {
        calls++;
        return [summary(id: 'a1'), summary(id: 'a2', name: 'Borealis')];
      });

      final agents = await repository.fetchAgents();

      expect(calls, 1);
      expect(agents.map((a) => a.id), ['a1', 'a2']);
      expect(agents.map((a) => a.name), ['Atlas', 'Borealis']);
    });

    test('propagates a source error unchanged', () async {
      final error = StateError('boom');
      final repository = ServerAgentRepository(() async => throw error);

      await expectLater(repository.fetchAgents(), throwsA(same(error)));
    });

    test('maps a full summary', () async {
      final repository = ServerAgentRepository(
        () async => [summary()],
      );

      final agent = (await repository.fetchAgents()).single;

      expect(agent.id, 'a1');
      expect(agent.name, 'Atlas');
      expect(agent.description, 'Reads chains');
      expect(agent.priceUsdcStroops, 5000000);
      expect(agent.skills, ['On-chain analytics', 'Monitoring']);
      expect(agent.model, 'gpt-x');
      expect(agent.stellarAddress, 'GABC');
      expect(agent.rating, 0.0);
    });

    test('returned lists are unmodifiable', () async {
      final repository = ServerAgentRepository(
        () async => [summary()],
      );

      final agents = await repository.fetchAgents();

      expect(() => agents.add(agents.first), throwsUnsupportedError);
      expect(() => agents.first.skills.add('x'), throwsUnsupportedError);
    });

    test('drops summaries with a null wallet', () async {
      final repository = ServerAgentRepository(
        () async => [summary(id: 'a1'), summary(id: 'a2', wallet: null)],
      );

      final agents = await repository.fetchAgents();

      expect(agents.map((a) => a.id), ['a1']);
    });

    test('drops summaries with an empty wallet', () async {
      final repository = ServerAgentRepository(
        () async => [summary(id: 'a1', wallet: ''), summary(id: 'a2')],
      );

      final agents = await repository.fetchAgents();

      expect(agents.map((a) => a.id), ['a2']);
    });

    test('returns an empty list when every agent lacks a wallet', () async {
      final repository = ServerAgentRepository(
        () async => [summary(wallet: null), summary(id: 'a2', wallet: '')],
      );

      expect(await repository.fetchAgents(), isEmpty);
    });

    test('null model defaults to Unspecified', () async {
      final repository = ServerAgentRepository(
        () async => [summary(model: null)],
      );

      expect((await repository.fetchAgents()).single.model, 'Unspecified');
    });

    test('empty model defaults to Unspecified', () async {
      final repository = ServerAgentRepository(
        () async => [summary(model: '')],
      );

      expect((await repository.fetchAgents()).single.model, 'Unspecified');
    });
  });

  // Plain `test`: these need real timers, which testWidgets' fake time
  // would never fire.
  group('ServerAgentRepository timeout', () {
    test('a never-completing source throws TimeoutException', () async {
      final never = Completer<List<AgentSummary>>();
      final repository = ServerAgentRepository(
        () => never.future,
        timeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        repository.fetchAgents(),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('a fast source is unaffected by the timeout', () async {
      final repository = ServerAgentRepository(
        () async => [summary()],
        timeout: const Duration(seconds: 5),
      );

      expect((await repository.fetchAgents()).single.id, 'a1');
    });

    test('default timeout is finite', () {
      expect(ServerAgentRepository.defaultTimeout, const Duration(seconds: 20));
    });
  });

  group('ServerAgentRepository.fetchAgent', () {
    test('uses the detail call (agent.get) when given', () async {
      final asked = <String>[];
      final repository = ServerAgentRepository(
        () async => fail('list must not be called'),
        byId: (id) async {
          asked.add(id);
          return summary(id: id);
        },
      );
      final agent = await repository.fetchAgent('a7');
      expect(asked, ['a7']);
      expect(agent!.id, 'a7');
      expect(agent.registryId, 1);
    });

    test('an unknown id is null, not an error', () async {
      final repository = ServerAgentRepository(
        () async => [],
        byId: (_) async => null,
      );
      expect(await repository.fetchAgent('nope'), isNull);
    });

    test('a server error propagates, so the screen can offer Retry', () async {
      final error = StateError('down');
      final repository = ServerAgentRepository(
        () async => [],
        byId: (_) async => throw error,
      );
      await expectLater(repository.fetchAgent('a1'), throwsA(same(error)));
    });

    test('without a detail call it searches the list', () async {
      final repository = ServerAgentRepository(
        () async => [summary(id: 'a1'), summary(id: 'a2', name: 'Borealis')],
      );
      expect((await repository.fetchAgent('a2'))!.name, 'Borealis');
      expect(await repository.fetchAgent('a3'), isNull);
    });
  });
}
