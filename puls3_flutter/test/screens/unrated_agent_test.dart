import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/data/agent_repository.dart';
import 'package:puls3_flutter/src/domain/agent.dart';
import 'package:puls3_flutter/src/ui/atoms/rating_badge.dart';
import 'package:puls3_flutter/src/ui/molecules/agent_card.dart';

import '../helpers.dart';

const unratedAgent = Agent(
  id: 'agt-900',
  name: 'Fresh Agent',
  description: 'Just registered on-chain.',
  skills: ['Monitoring'],
  priceUsdcStroops: 5000000,
  rating: 0.0,
  stellarAddress: 'GCDSVE4MGRNDOWEP7HX7HGMECBFAZPDI2J5PDGWDLOLLLIUIXFFSQFXZ',
  model: 'Unspecified',
);

const ratedAgent = Agent(
  id: 'agt-901',
  name: 'Veteran Agent',
  description: 'Well reviewed.',
  skills: ['Monitoring'],
  priceUsdcStroops: 5000000,
  rating: 5.0,
  stellarAddress: 'GCWJO7NSUK6NKZMVOAYSGFJCMKEG7OQPPAXW6UXZFZN43EMV3ZESMLX7',
  model: 'Claude Opus',
);

const sizes = {
  'phone': Size(390, 844),
  'desktop': Size(1440, 1000),
};

Future<void> pumpCard(WidgetTester tester, Size size, double rating) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AgentCard(
          name: 'Card Agent',
          topSkill: 'Monitoring',
          priceUsdcStroops: 5000000,
          rating: rating,
          description: 'Does things.',
          model: 'Unspecified',
        ),
      ),
    ),
  );
}

void main() {
  for (final MapEntry(key: label, value: size) in sizes.entries) {
    group('on $label', () {
      testWidgets('card with rating 0.0 shows no rating', (tester) async {
        await pumpCard(tester, size, 0.0);

        expect(tester.takeException(), isNull);
        expect(find.text('Card Agent'), findsOneWidget);
        expect(find.byType(RatingBadge), findsOneWidget);
        expect(find.text('0.0'), findsNothing);
        expect(find.byIcon(Icons.star_rounded), findsNothing);
      });

      testWidgets('card with rating 5.0 is unchanged', (tester) async {
        await pumpCard(tester, size, 5.0);

        expect(tester.takeException(), isNull);
        expect(find.text('5.0'), findsOneWidget);
        expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      });

      testWidgets('detail with rating 0.0 shows no rating', (tester) async {
        await pumpApp(
          tester,
          location: '/agent/agt-900',
          size: size,
          repository: const InMemoryAgentRepository([unratedAgent]),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Fresh Agent'), findsOneWidget);
        expect(find.text('Unspecified'), findsOneWidget);
        expect(find.text('0.0'), findsNothing);
        expect(find.byIcon(Icons.star_rounded), findsNothing);
      });

      testWidgets('detail with rating 5.0 is unchanged', (tester) async {
        await pumpApp(
          tester,
          location: '/agent/agt-901',
          size: size,
          repository: const InMemoryAgentRepository([ratedAgent]),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Veteran Agent'), findsOneWidget);
        expect(find.text('5.0'), findsOneWidget);
        expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      });
    });
  }
}
