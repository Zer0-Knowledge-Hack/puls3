import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/data/agent_repository.dart';
import 'package:puls3_flutter/src/domain/agent.dart';
import 'package:puls3_flutter/src/studio/fake_studio_gateway.dart';
import 'package:puls3_flutter/src/studio/studio_gateway.dart';
import 'package:puls3_flutter/src/wallet/mock_wallet.dart';

import '../helpers.dart';
import '../studio/studio_fixtures.dart';

const _selfWallet = 'GCJOMHOLKJJUMFCBC56ZIZTINBAFARFQIWNM4MA4GJ6RJZQI4KH3RIB3';

const _agents = [
  Agent(
    id: '7',
    name: 'Brief Bot',
    description: 'Summarizes long text.',
    skills: ['Summaries'],
    priceUsdcStroops: 10000000,
    rating: 4,
    stellarAddress: _selfWallet,
    model: 'Llama',
    registryId: 7,
  ),
  Agent(
    id: '42',
    name: 'Translator',
    description: 'Translates text.',
    skills: ['Research'],
    priceUsdcStroops: 20000000,
    rating: 4,
    stellarAddress: 'GCDSVE4MGRNDOWEP7HX7HGMECBFAZPDI2J5PDGWDLOLLLIUIXFFSQFXZ',
    model: 'Llama',
    registryId: 42,
  ),
];

Finder _key(String key) => find.byKey(Key(key));

void main() {
  late MockWallet wallet;
  late FakeStudioGateway studio;

  Future<void> open(WidgetTester tester, StudioDraft draft) async {
    wallet = MockWallet()..switchAccount();
    studio = FakeStudioGateway(
      delay: const Duration(milliseconds: 50),
      seed: [(wallet.address!, draft)],
    );
    await pumpApp(
      tester,
      location: '/studio?draft=${draft.draftId}',
      wallet: wallet,
      studioGateway: studio,
      repository: const InMemoryAgentRepository(_agents),
    );
    await advance(tester, const Duration(milliseconds: 200));
  }

  Future<void> fillHire(WidgetTester tester) async {
    await tester.ensureVisible(_key('collab-agent'));
    await tester.tap(_key('collab-agent'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Translator').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(_key('collab-instructions'), 'Translate: hola');
    await tester.pump();
  }

  Future<void> tapHire(WidgetTester tester) async {
    await tester.ensureVisible(_key('collab-hire'));
    await tester.tap(_key('collab-hire'));
    await tester.pump();
  }

  testWidgets('a draft that is not live has no Collaborate section', (
    tester,
  ) async {
    await open(tester, savedDraft(1));
    expect(find.text('Brief Bot'), findsWidgets);
    expect(_key('studio-collaborate'), findsNothing);
  });

  testWidgets('a live agent hires another agent and follows the payment', (
    tester,
  ) async {
    await open(
      tester,
      savedDraft(1, state: DraftDeployState.live, liveVersion: 1, agentId: '7'),
    );
    expect(_key('studio-collaborate'), findsOneWidget);
    expect(find.text('Collaborate: hire another agent'), findsOneWidget);
    expect(find.text(_selfWallet), findsOneWidget);
    expect(
      find.text(
        'This agent pays from its own wallet. Fund it with testnet USDC first.',
      ),
      findsOneWidget,
    );

    await fillHire(tester);
    // The budget starts at the hired agent's price.
    expect(find.widgetWithText(TextField, '2.00'), findsOneWidget);
    await tapHire(tester);
    await advance(tester, const Duration(seconds: 8));

    expect(studio.agentHires, [
      (
        hiringAgentId: 7,
        agentId: 42,
        input: 'Translate: hola',
        budget: 20000000,
      ),
    ]);
    expect(_key('collab-progress'), findsOneWidget);
    expect(find.text('Hire #1'), findsOneWidget);
    expect(find.text('Payment released to the hired agent'), findsOneWidget);
    // fund, submit and complete each link to their transaction.
    expect(find.text('View transaction'), findsNWidgets(3));
    expect(_key('collab-result'), findsOneWidget);
    expect(_key('collab-hire-again'), findsOneWidget);
  });

  testWidgets('a budget below the price shows a clear message', (
    tester,
  ) async {
    await open(
      tester,
      savedDraft(1, state: DraftDeployState.live, liveVersion: 1, agentId: '7'),
    );
    studio.nextHireError = const StudioAgentHireRefused(
      AgentHireRefusal.budgetExceeded,
    );
    await fillHire(tester);
    await tapHire(tester);
    await advance(tester, const Duration(milliseconds: 300));

    expect(
      find.text(
        'The budget is lower than this agent\'s price. Raise it and try again.',
      ),
      findsOneWidget,
    );
    expect(_key('collab-progress'), findsNothing);
  });
}
