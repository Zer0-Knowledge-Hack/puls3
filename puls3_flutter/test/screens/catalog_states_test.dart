import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_client/puls3_client.dart';
import 'package:puls3_flutter/src/data/server_agent_repository.dart';
import 'package:puls3_flutter/src/domain/agent.dart';
import 'package:puls3_flutter/src/theme/puls3_theme.dart';
import 'package:puls3_flutter/src/ui/atoms/primary_button.dart';
import 'package:puls3_flutter/src/ui/organisms/agent_detail_view.dart';

import '../helpers.dart';

/// A fake of the generated client's `agent` endpoint: every call waits for
/// the test to answer it, or uses the canned answer.
class FakeAgentEndpoint {
  List<AgentSummary> agents = [
    _summary('srv-1', 'Chain Atlas', ['on-chain-analytics', 'monitoring'], 7),
    _summary('srv-2', 'Vault Guard', ['security', 'smart-contracts'], 8),
  ];

  /// When set, `list` and `get` throw it.
  Object? failure;

  /// When true, calls wait in [pendingLists] / [pendingGets].
  bool hold = false;
  final pendingLists = <Completer<List<AgentSummary>>>[];
  final pendingGets = <Completer<AgentSummary?>>[];
  var gets = 0;

  Future<List<AgentSummary>> list() async {
    if (hold) {
      final call = Completer<List<AgentSummary>>();
      pendingLists.add(call);
      return call.future;
    }
    final failure = this.failure;
    if (failure != null) throw failure;
    return agents;
  }

  Future<AgentSummary?> get(String id) async {
    gets++;
    if (hold) {
      final call = Completer<AgentSummary?>();
      pendingGets.add(call);
      return call.future;
    }
    final failure = this.failure;
    if (failure != null) throw failure;
    for (final agent in agents) {
      if (agent.id == id) return agent;
    }
    return null;
  }

  ServerAgentRepository get repository =>
      ServerAgentRepository(list, byId: get);
}

AgentSummary _summary(
  String id,
  String name,
  List<String> skills,
  int registryId,
) => AgentSummary(
  id: id,
  registryId: registryId,
  name: name,
  description: '$name reads the chain.',
  skills: skills,
  priceUsdcStroops: 5000000,
  wallet: 'GCDSVE4MGRNDOWEP7HX7HGMECBFAZPDI2J5PDGWDLOLLLIUIXFFSQFXZ',
  model: 'Claude Sonnet',
);

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

const _viewports = {
  'phone 390': Size(390, 844),
  'desktop 1440': Size(1440, 1000),
};

void main() {
  group('S02 marketplace states (fake client)', () {
    testWidgets('loading shows card skeletons, then the agents', (
      tester,
    ) async {
      final server = FakeAgentEndpoint()..hold = true;
      await pumpApp(tester, location: '/market', repository: server.repository);

      expect(_key('market-loading'), findsOneWidget);
      expect(find.text('Chain Atlas'), findsNothing);

      server.pendingLists.single.complete(server.agents);
      await _settle(tester);
      expect(_key('market-loading'), findsNothing);
      expect(find.text('Chain Atlas'), findsOneWidget);
      expect(find.text('2 AGENTS LIVE'), findsOneWidget);
    });

    testWidgets('error offers a Retry that works', (tester) async {
      final server = FakeAgentEndpoint()..failure = StateError('down');
      await pumpApp(tester, location: '/market', repository: server.repository);

      expect(_key('market-error'), findsOneWidget);
      expect(find.text('Could not load the agents'), findsOneWidget);
      expect(find.text('Chain Atlas'), findsNothing);

      server.failure = null;
      await tester.tap(find.text('Retry'));
      await _settle(tester);
      expect(_key('market-error'), findsNothing);
      expect(find.text('Chain Atlas'), findsOneWidget);
    });

    testWidgets('empty catalog says so and points to the Studio', (
      tester,
    ) async {
      final server = FakeAgentEndpoint()..agents = [];
      await pumpApp(tester, location: '/market', repository: server.repository);

      expect(_key('market-empty'), findsOneWidget);
      await tester.tap(find.text('Create an agent'));
      await _settle(tester);
      expect(find.text('Agent Studio'), findsWidgets);
    });

    testWidgets('skills filter to agents with every selected skill', (
      tester,
    ) async {
      final server = FakeAgentEndpoint();
      await pumpApp(tester, location: '/market', repository: server.repository);

      await tester.tap(find.widgetWithText(InkWell, 'Monitoring').first);
      await tester.pump();
      expect(find.text('Chain Atlas'), findsOneWidget);
      expect(find.text('Vault Guard'), findsNothing);

      // Monitoring AND Security: no agent has both.
      await tester.tap(find.widgetWithText(InkWell, 'Security').first);
      await tester.pump();
      expect(_key('market-no-match'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pump();
      expect(find.text('Chain Atlas'), findsOneWidget);
      expect(find.text('Vault Guard'), findsOneWidget);
    });

    testWidgets('a search with no match can be cleared', (tester) async {
      final server = FakeAgentEndpoint();
      await pumpApp(tester, location: '/market', repository: server.repository);

      await tester.enterText(find.byType(TextField), 'nothing like this');
      await tester.pump();
      expect(_key('market-no-match'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      expect(find.text('Vault Guard'), findsOneWidget);
    });

    for (final MapEntry(key: name, value: size) in _viewports.entries) {
      testWidgets('$name: every state lays out', (tester) async {
        final server = FakeAgentEndpoint()..hold = true;
        await pumpApp(
          tester,
          location: '/market',
          size: size,
          repository: server.repository,
        );
        expect(_key('market-loading'), findsOneWidget);
        expect(tester.takeException(), isNull);

        server.pendingLists.single.completeError(StateError('down'));
        await _settle(tester);
        expect(_key('market-error'), findsOneWidget);
        expect(tester.takeException(), isNull);

        server.hold = false;
        await tester.tap(find.text('Retry'));
        await _settle(tester);
        expect(find.text('Vault Guard'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('S03 agent detail states (fake client)', () {
    testWidgets('loading shows a skeleton, then the agent from agent.get', (
      tester,
    ) async {
      final server = FakeAgentEndpoint()..hold = true;
      await pumpApp(
        tester,
        location: '/agent/srv-1',
        repository: server.repository,
      );

      expect(_key('detail-loading'), findsOneWidget);
      server.pendingLists.single.complete(server.agents);
      server.pendingGets.single.complete(server.agents.first);
      await _settle(tester);

      expect(find.text('Chain Atlas'), findsOneWidget);
      expect(find.text('#7'), findsOneWidget);
      expect(find.text('View on explorer'), findsOneWidget);
      final hire = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'Hire'),
      );
      expect(hire.onPressed, isNotNull);
    });

    testWidgets('an unknown id is not found, with a way back', (tester) async {
      final server = FakeAgentEndpoint();
      await pumpApp(
        tester,
        location: '/agent/nope',
        repository: server.repository,
      );

      expect(_key('detail-not-found'), findsOneWidget);
      expect(find.text('Agent not found'), findsOneWidget);
      await tester.tap(find.text('Back to Marketplace'));
      await _settle(tester);
      expect(find.text('Chain Atlas'), findsOneWidget);
    });

    testWidgets('error with nothing cached offers a Retry that works', (
      tester,
    ) async {
      final server = FakeAgentEndpoint()..failure = StateError('down');
      await pumpApp(
        tester,
        location: '/agent/srv-1',
        repository: server.repository,
      );

      expect(_key('detail-error'), findsOneWidget);
      expect(find.text('Could not load this agent'), findsOneWidget);

      server.failure = null;
      await tester.tap(find.text('Retry'));
      await _settle(tester);
      expect(_key('detail-error'), findsNothing);
      expect(find.text('Chain Atlas'), findsOneWidget);
    });

    testWidgets('server unreachable: cached data with a warning, Hire '
        'disabled until it loads', (tester) async {
      final server = FakeAgentEndpoint();
      // The catalog loads, then the detail call fails.
      await pumpApp(tester, location: '/market', repository: server.repository);
      server.failure = StateError('down');
      await tester.tap(find.text('Chain Atlas'));
      // Let the page transition finish.
      await advance(tester, const Duration(milliseconds: 600));

      expect(_key('detail-stale'), findsOneWidget);
      expect(find.text('Showing the last known data'), findsOneWidget);
      expect(find.text('Chain Atlas'), findsOneWidget);
      var hire = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'Hire'),
      );
      expect(hire.onPressed, isNull);
      expect(find.text('Hire is disabled until the agent loads.'), findsOne);

      server.failure = null;
      await tester.tap(find.text('Retry'));
      await _settle(tester);
      expect(_key('detail-stale'), findsNothing);
      hire = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'Hire'),
      );
      expect(hire.onPressed, isNotNull);
    });

    for (final MapEntry(key: name, value: size) in _viewports.entries) {
      testWidgets('$name: every state lays out', (tester) async {
        final server = FakeAgentEndpoint()..hold = true;
        await pumpApp(
          tester,
          location: '/agent/srv-1',
          size: size,
          repository: server.repository,
        );
        expect(_key('detail-loading'), findsOneWidget);
        expect(tester.takeException(), isNull);

        server.pendingLists.single.completeError(StateError('down'));
        server.pendingGets.single.completeError(StateError('down'));
        await _settle(tester);
        expect(_key('detail-error'), findsOneWidget);
        expect(tester.takeException(), isNull);

        server.hold = false;
        await tester.tap(find.text('Retry'));
        await _settle(tester);
        expect(find.text('Chain Atlas'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('AgentDetailView (presentational)', () {
    testWidgets('View on explorer calls back; a demo agent says it is not '
        'on chain', (tester) async {
      Puls3Fonts.useGoogleFonts = false;
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: Puls3Theme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AgentDetailView(
                agent: testAgents.first,
                onBack: () {},
                onHire: null,
                hireNote: 'Hire is disabled until the agent loads.',
                onOpenExplorer: () => opened++,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Demo agent, not on chain'), findsOneWidget);
      await tester.tap(find.text('View on explorer'));
      expect(opened, 1);
    });
  });

  test('Agent keeps the registry id from the server summary', () {
    final agent = ServerAgentRepository.fromSummary(
      _summary('srv-9', 'Nine', ['payments'], 9),
    );
    expect(agent, isA<Agent>());
    expect(agent!.registryId, 9);
  });
}
