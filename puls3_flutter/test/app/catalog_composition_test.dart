import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_client/puls3_client.dart';
import 'package:puls3_flutter/src/data/agent_repository.dart';
import 'package:puls3_flutter/src/data/fallback_agent_repository.dart';
import 'package:puls3_flutter/src/data/server_agent_repository.dart';

import '../helpers.dart';

/// Mirrors the composition in `main.dart`, with a fake source and an
/// in-memory stand-in for the asset catalog.
FallbackAgentRepository compose(AgentSummarySource source) =>
    FallbackAgentRepository(
      ServerAgentRepository(source),
      const InMemoryAgentRepository(testAgents),
    );

void main() {
  testWidgets('the market lists server agents with readable skills', (
    tester,
  ) async {
    await pumpApp(
      tester,
      location: '/market',
      repository: compose(
        () async => [
          AgentSummary(
            id: 'srv-1',
            registryId: 1,
            name: 'Chain Atlas',
            description: 'Reads chains',
            skills: ['on-chain-analytics'],
            priceUsdcStroops: 5000000,
            wallet: 'GABC',
          ),
        ],
      ),
    );

    expect(find.text('Chain Atlas'), findsOneWidget);
    expect(find.text('On-chain analytics'), findsWidgets);
    expect(find.text('Ledger Scout'), findsNothing);
  });

  testWidgets('a failing server shows the fallback catalog', (tester) async {
    await pumpApp(
      tester,
      location: '/market',
      repository: compose(() async => throw StateError('server down')),
    );

    expect(find.text('Ledger Scout'), findsOneWidget);
    expect(find.text('Soroban Auditor'), findsOneWidget);
  });

  testWidgets('an empty server catalog shows an empty market', (tester) async {
    await pumpApp(
      tester,
      location: '/market',
      repository: compose(() async => []),
    );

    expect(find.text('No agents match your filters.'), findsOneWidget);
    expect(find.text('Ledger Scout'), findsNothing);
  });
}
