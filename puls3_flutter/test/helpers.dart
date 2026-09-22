import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/app.dart';
import 'package:puls3_flutter/src/data/agent_repository.dart';
import 'package:puls3_flutter/src/domain/agent.dart';
import 'package:puls3_flutter/src/theme/puls3_theme.dart';
import 'package:puls3_flutter/src/wallet/mock_wallet.dart';

const testAgents = [
  Agent(
    id: 'agt-001',
    name: 'Ledger Scout',
    description: 'Monitors Stellar accounts.',
    skills: ['On-chain analytics', 'Monitoring'],
    priceUsdcStroops: 5000000,
    rating: 4.9,
    stellarAddress: 'GCDSVE4MGRNDOWEP7HX7HGMECBFAZPDI2J5PDGWDLOLLLIUIXFFSQFXZ',
    model: 'Claude Sonnet',
  ),
  Agent(
    id: 'agt-003',
    name: 'Soroban Auditor',
    description: 'Reviews Soroban smart contracts.',
    skills: ['Smart contracts', 'Security'],
    priceUsdcStroops: 45000000,
    rating: 4.7,
    stellarAddress: 'GCWJO7NSUK6NKZMVOAYSGFJCMKEG7OQPPAXW6UXZFZN43EMV3ZESMLX7',
    model: 'Claude Opus',
  ),
];

/// Pumps the full app at [location] on a desktop-sized surface.
Future<void> pumpApp(
  WidgetTester tester, {
  String location = '/',
  Size size = const Size(1440, 1000),
}) async {
  Puls3Fonts.useGoogleFonts = false;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    Puls3App(
      repository: const InMemoryAgentRepository(testAgents),
      wallet: MockWallet(),
      initialLocation: location,
    ),
  );
  // Let the catalog load. The pulse animation repeats forever, so
  // pumpAndSettle is not an option.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Advances fake time by [duration] in small frames.
Future<void> advance(WidgetTester tester, Duration duration) async {
  const step = Duration(milliseconds: 100);
  var elapsed = Duration.zero;
  while (elapsed < duration) {
    await tester.pump(step);
    elapsed += step;
  }
}
