import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/data/agent_repository.dart';
import 'package:puls3_flutter/src/domain/agent.dart';

import '../helpers.dart';

const _studioAgent = Agent(
  id: 'studio-7',
  registryId: 32,
  name: 'Studio Scout',
  description: 'An agent deployed from the Studio.',
  skills: ['stellar'],
  priceUsdcStroops: 5000000,
  rating: 0,
  stellarAddress: 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
  model: 'test-model',
);

/// `/agent/:id` with a purely numeric id that is no catalog id resolves it
/// as the on-chain registry id.
void main() {
  testWidgets('/agent/<registryId> shows the agent', (tester) async {
    await pumpApp(
      tester,
      location: '/agent/32',
      repository: const InMemoryAgentRepository([...testAgents, _studioAgent]),
    );
    await advance(tester, const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('detail-not-found')), findsNothing);
    expect(find.text('Studio Scout'), findsWidgets);
  });

  testWidgets('/agent/<catalogId> still shows the agent', (tester) async {
    await pumpApp(
      tester,
      location: '/agent/studio-7',
      repository: const InMemoryAgentRepository([...testAgents, _studioAgent]),
    );
    await advance(tester, const Duration(milliseconds: 400));

    expect(find.text('Studio Scout'), findsWidgets);
  });

  testWidgets('an unknown registry id is still not found', (tester) async {
    await pumpApp(
      tester,
      location: '/agent/99',
      repository: const InMemoryAgentRepository([...testAgents, _studioAgent]),
    );
    await advance(tester, const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('detail-not-found')), findsOneWidget);
  });
}
