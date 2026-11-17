import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/data/agent_repository.dart';
import 'package:puls3_flutter/src/domain/agent.dart';
import 'package:puls3_flutter/src/studio/fake_studio_gateway.dart';
import 'package:puls3_flutter/src/studio/studio_gateway.dart';
import 'package:puls3_flutter/src/wallet/mock_wallet.dart';

import '../helpers.dart';
import '../studio/studio_fixtures.dart';

const _agents = [
  Agent(
    id: '7',
    name: 'Brief Bot',
    description: 'Summarizes long text.',
    skills: ['Summaries'],
    priceUsdcStroops: 10000000,
    rating: 4,
    stellarAddress: 'GCJOMHOLKJJUMFCBC56ZIZTINBAFARFQIWNM4MA4GJ6RJZQI4KH3RIB3',
    model: 'Llama',
    registryId: 7,
  ),
];

void main() {
  // Editing an agent is only its own configuration: hiring another agent
  // with it belongs to the hire flow ("Who pays?").
  testWidgets('editing a live agent offers no hire of another agent', (
    tester,
  ) async {
    final wallet = MockWallet()..switchAccount();
    final draft = savedDraft(
      1,
      state: DraftDeployState.live,
      liveVersion: 1,
      agentId: '7',
    );
    await pumpApp(
      tester,
      location: '/studio?draft=${draft.draftId}',
      wallet: wallet,
      studioGateway: FakeStudioGateway(
        delay: const Duration(milliseconds: 50),
        seed: [(wallet.address!, draft)],
      ),
      repository: const InMemoryAgentRepository(_agents),
    );
    await advance(tester, const Duration(milliseconds: 200));

    expect(find.text('Brief Bot'), findsWidgets);
    expect(find.byKey(const Key('studio-collaborate')), findsNothing);
    expect(find.text('Collaborate: hire another agent'), findsNothing);
    expect(find.byKey(const Key('collab-agent')), findsNothing);
  });
}
