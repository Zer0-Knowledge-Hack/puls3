import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/data/agent_repository.dart';
import 'package:puls3_flutter/src/domain/agent.dart';
import 'package:puls3_flutter/src/deploy/fake_deploy_gateway.dart';
import 'package:puls3_flutter/src/screens/hire_sheet.dart';
import 'package:puls3_flutter/src/state/agent_catalog.dart';
import 'package:puls3_flutter/src/state/app_scope.dart';
import 'package:puls3_flutter/src/state/wallet_controller.dart';
import 'package:puls3_flutter/src/wallet/wallet_port.dart';

class TestWallet implements WalletPort {
  TestWallet({this.initialAddress, this.shouldFail = false});

  final String? initialAddress;
  bool shouldFail;
  String? _address;

  @override
  String? get address => _address ?? initialAddress;

  @override
  Future<String> connect() async {
    return _address = 'GTESTUSERWALLET1234567890';
  }

  @override
  Future<String> signTransaction(String unsignedXdr) async {
    if (shouldFail) {
      throw Exception('Signature rejected by user');
    }
    return '43cd3e8455cafdc08d62a644b8f9dd9174994644b2bdd3e57eaa6893aa5c2437';
  }
}

Widget buildTestSheet({
  required Agent agent,
  required WalletPort walletPort,
}) {
  final catalog = AgentCatalog(InMemoryAgentRepository([agent]));
  final walletController = WalletController(walletPort);

  return MaterialApp(
    home: AppScope(
      catalog: catalog,
      wallet: walletController,
      deployGateway: FakeDeployGateway(),
      child: Scaffold(
        body: HireSheet(agent: agent),
      ),
    ),
  );
}

void main() {
  final testAgent = Agent(
    id: 'agt-001',
    name: 'Ledger Scout',
    description: 'Autonomous ledger analytics agent.',
    skills: ['On-chain analytics'],
    priceUsdcStroops: 5000000,
    stellarAddress:
        'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
    model: 'gpt-4o',
    rating: 0.0,
  );

  group('HireSheet', () {
    testWidgets('successful signing shows the demo result, not a payment',
        (tester) async {
      final wallet = TestWallet(initialAddress: 'GUSER123');

      await tester.pumpWidget(
        buildTestSheet(agent: testAgent, walletPort: wallet),
      );

      expect(find.text('Hire Ledger Scout'), findsOneWidget);
      expect(find.text('Confirm & sign'), findsOneWidget);

      await tester.tap(find.text('Confirm & sign'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Demo signature only'), findsOneWidget);
      expect(find.text('Payment confirmed'), findsNothing);
      expect(find.text('View on StellarExpert'), findsNothing);
    });

    testWidgets('failing wallet transitions to error and allows retry',
        (tester) async {
      final wallet =
          TestWallet(initialAddress: 'GUSER123', shouldFail: true);

      await tester.pumpWidget(
        buildTestSheet(agent: testAgent, walletPort: wallet),
      );

      await tester.tap(find.text('Confirm & sign'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Payment failed'), findsOneWidget);
      expect(find.text('Signature rejected by user'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      // Now fix wallet and retry
      wallet.shouldFail = false;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Demo signature only'), findsOneWidget);
    });
  });
}
