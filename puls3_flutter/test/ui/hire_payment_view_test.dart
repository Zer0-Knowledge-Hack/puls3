import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/domain/stellar_explorer.dart';
import 'package:puls3_flutter/src/ui/atoms/address_badge.dart';
import 'package:puls3_flutter/src/ui/organisms/hire_payment_view.dart';

Widget buildView({
  required HirePhase phase,
  String agentName = 'Ledger Scout',
  int priceUsdcStroops = 5000000,
  String destinationAddress =
      'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
  String escrowContractAddress = defaultEscrowContractAddress,
  String? txHash,
  String? errorMessage,
  VoidCallback? onConfirm,
  VoidCallback? onBackToMarketplace,
  VoidCallback? onRetry,
  ValueChanged<String>? onOpenExplorer,
}) {
  return MaterialApp(
    home: Scaffold(
      body: HirePaymentView(
        phase: phase,
        agentName: agentName,
        priceUsdcStroops: priceUsdcStroops,
        destinationAddress: destinationAddress,
        escrowContractAddress: escrowContractAddress,
        txHash: txHash,
        errorMessage: errorMessage,
        onConfirm: onConfirm ?? () {},
        onBackToMarketplace: onBackToMarketplace ?? () {},
        onRetry: onRetry,
        onOpenExplorer: onOpenExplorer,
      ),
    ),
  );
}

void main() {
  group('HirePaymentView', () {
    testWidgets('review phase renders price, destination, and escrow contract',
        (tester) async {
      await tester.pumpWidget(buildView(phase: HirePhase.review));

      expect(find.text('Hire Ledger Scout'), findsOneWidget);
      expect(find.text('Escrow'), findsOneWidget);
      expect(find.text('Destination'), findsOneWidget);

      // Finds two AddressBadges: destination and escrow contract
      expect(find.byType(AddressBadge), findsNWidgets(2));
      expect(find.text('Confirm & sign'), findsOneWidget);
      expect(
        find.textContaining('Soroban Escrow contract'),
        findsOneWidget,
      );
    });

    testWidgets('signing phase shows signing progress indicator',
        (tester) async {
      await tester.pumpWidget(buildView(phase: HirePhase.signing));

      expect(find.text('Signing…'), findsOneWidget);
    });

    testWidgets('confirmed phase renders tx hash and triggers onOpenExplorer',
        (tester) async {
      const txHash =
          '43cd3e8455cafdc08d62a644b8f9dd9174994644b2bdd3e57eaa6893aa5c2437';
      String? launchedUrl;

      await tester.pumpWidget(
        buildView(
          phase: HirePhase.confirmed,
          txHash: txHash,
          onOpenExplorer: (url) => launchedUrl = url,
        ),
      );

      expect(find.text('Payment confirmed'), findsOneWidget);
      expect(find.text('Tx hash'), findsOneWidget);

      // Verify the explorer button is present and triggers the URL
      final explorerBtn = find.text('View on StellarExpert');
      expect(explorerBtn, findsOneWidget);

      await tester.tap(explorerBtn);
      await tester.pump();

      expect(launchedUrl, stellarExpertTxUrl(txHash));
    });

    testWidgets('error phase renders error message and invokes onRetry',
        (tester) async {
      var retried = false;

      await tester.pumpWidget(
        buildView(
          phase: HirePhase.error,
          errorMessage: 'User rejected signature',
          onRetry: () => retried = true,
        ),
      );

      expect(find.text('Payment failed'), findsOneWidget);
      expect(find.text('User rejected signature'), findsOneWidget);

      final retryBtn = find.text('Try again');
      expect(retryBtn, findsOneWidget);

      await tester.tap(retryBtn);
      await tester.pump();

      expect(retried, isTrue);
    });
  });
}
