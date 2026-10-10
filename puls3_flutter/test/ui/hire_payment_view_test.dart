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
  String? escrowContractAddress,
  String? errorMessage,
  VoidCallback? onConfirm,
  VoidCallback? onBackToMarketplace,
  VoidCallback? onRetry,
}) {
  return MaterialApp(
    home: Scaffold(
      body: HirePaymentView(
        phase: phase,
        agentName: agentName,
        priceUsdcStroops: priceUsdcStroops,
        destinationAddress: destinationAddress,
        escrowContractAddress: escrowContractAddress,
        errorMessage: errorMessage,
        onConfirm: onConfirm ?? () {},
        onBackToMarketplace: onBackToMarketplace ?? () {},
        onRetry: onRetry,
      ),
    ),
  );
}

void main() {
  group('HirePaymentView', () {
    testWidgets(
      'review phase renders price, destination, and escrow contract',
      (tester) async {
        await tester.pumpWidget(buildView(phase: HirePhase.review));

        expect(find.text('Hire Ledger Scout'), findsOneWidget);
        expect(find.text('Escrow'), findsOneWidget);
        expect(find.text('Destination'), findsOneWidget);

        // Finds two AddressBadges: destination and escrow contract
        expect(find.byType(AddressBadge), findsNWidgets(2));
        expect(find.text('Confirm & sign'), findsOneWidget);
        expect(find.textContaining('Demo only'), findsOneWidget);
      },
    );

    testWidgets('escrow badge defaults to the resolved escrow address', (
      tester,
    ) async {
      await tester.pumpWidget(buildView(phase: HirePhase.review));

      final addresses = tester
          .widgetList<AddressBadge>(find.byType(AddressBadge))
          .map((badge) => badge.address);
      expect(addresses, contains(defaultEscrowContractAddress));
      expect(defaultEscrowContractAddress, testnetEscrowContractAddress);
    });

    testWidgets('signing phase shows signing progress indicator', (
      tester,
    ) async {
      await tester.pumpWidget(buildView(phase: HirePhase.signing));

      expect(find.text('Signing…'), findsOneWidget);
    });

    testWidgets('demo phase does not claim a payment or link to the explorer', (
      tester,
    ) async {
      await tester.pumpWidget(buildView(phase: HirePhase.confirmed));

      expect(find.text('Demo signature only'), findsOneWidget);
      expect(find.textContaining('No payment was sent'), findsOneWidget);
      expect(find.text('Payment confirmed'), findsNothing);
      expect(find.text('Tx hash'), findsNothing);
      expect(find.text('View on StellarExpert'), findsNothing);
    });

    testWidgets('error phase renders error message and invokes onRetry', (
      tester,
    ) async {
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
    testWidgets('review shows the escrow custody guarantee', (tester) async {
      await tester.pumpWidget(buildView(phase: HirePhase.review));
      expect(find.textContaining('Escrow protection'), findsOneWidget);
    });

    testWidgets('signing shows which wallet step is running', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HirePaymentView(
                phase: HirePhase.signing,
                agentName: 'Ledger Scout',
                priceUsdcStroops: 5000000,
                destinationAddress:
                    'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
                progressLabel: 'Sign the payment in your wallet (2 of 2).',
                onConfirm: () {},
                onBackToMarketplace: () {},
              ),
            ),
          ),
        ),
      );
      expect(
        find.text('Sign the payment in your wallet (2 of 2).'),
        findsOneWidget,
      );
    });

    testWidgets('a real payment links its transaction to StellarExpert', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HirePaymentView(
                phase: HirePhase.confirmed,
                isDemo: false,
                agentName: 'Ledger Scout',
                priceUsdcStroops: 5000000,
                destinationAddress:
                    'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
                hireId: 3,
                transactionHash:
                    'fa11ce0000000000000000000000000000000000000000000000000000000001',
                onOpenExplorer: () => opened++,
                onConfirm: () {},
                onBackToMarketplace: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Payment sent, confirming on Stellar…'), findsOneWidget);
      expect(find.text('Demo signature only'), findsNothing);
      expect(find.text('Tx hash'), findsOneWidget);
      await tester.tap(find.text('View on StellarExpert'));
      expect(opened, 1);
    });
    testWidgets('only a confirmed payment says the escrow holds it', (
      tester,
    ) async {
      Widget view({required bool confirmed}) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HirePaymentView(
              phase: HirePhase.confirmed,
              isDemo: false,
              agentName: 'Ledger Scout',
              priceUsdcStroops: 5000000,
              destinationAddress:
                  'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
              transactionHash: 'abc123',
              paymentConfirmed: confirmed,
              onOpenExplorer: () {},
              onConfirm: () {},
              onBackToMarketplace: () {},
            ),
          ),
        ),
      );

      await tester.pumpWidget(view(confirmed: false));
      expect(find.text('Payment sent, confirming on Stellar…'), findsOneWidget);
      expect(find.textContaining('held by the escrow'), findsNothing);
      // The transaction can be followed while it confirms.
      expect(find.text('View on StellarExpert'), findsOneWidget);

      await tester.pumpWidget(view(confirmed: true));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Payment held by the escrow'), findsOneWidget);
      expect(find.textContaining('confirming'), findsNothing);
    });
  });
}
