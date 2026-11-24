import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/hire/hire_gateway.dart';
import 'package:puls3_flutter/src/theme/puls3_theme.dart';
import 'package:puls3_flutter/src/ui/organisms/hire_detail_view.dart';
import 'package:puls3_flutter/src/ui/organisms/hire_receipt_view.dart';

import '../helpers.dart';

const _wallet = 'GPROVIDERWALLETAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA99';
const _createHash =
    'c0ffee0000000000000000000000000000000000000000000000000000000001';
const _settleHash =
    '5e771e0000000000000000000000000000000000000000000000000000000001';

HireReceiptEntry _line({
  int id = 1,
  String state = 'completed',
  bool relatedParty = false,
  int budget = 20000000,
  int? fee,
  int? payout,
  String? createTransaction,
  String? createExplorerUrl,
  String? settleTransaction,
  String? settleExplorerUrl,
  String justification = 'Best rated translator under budget',
}) => HireReceiptEntry(
  id: id,
  providerAgentId: 19,
  providerWallet: _wallet,
  budgetUsdcStroops: budget,
  feeUsdcStroops: fee,
  payoutUsdcStroops: payout,
  state: state,
  createTransaction: createTransaction,
  createExplorerUrl: createExplorerUrl,
  settleTransaction: settleTransaction,
  settleExplorerUrl: settleExplorerUrl,
  relatedParty: relatedParty,
  justification: justification,
  createdAt: DateTime.utc(2026, 11, 24),
);

Future<List<String>> _pump(
  WidgetTester tester, {
  int reserve = 30000000,
  List<HireReceiptEntry> lines = const [],
}) async {
  Puls3Fonts.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final opened = <String>[];
  await tester.pumpWidget(
    localizedTestApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: HireReceiptView(
            reserveUsdcStroops: reserve,
            lines: lines,
            onOpenUrl: opened.add,
          ),
        ),
      ),
    ),
  );
  return opened;
}

HireProgress _hire({
  int reserve = 0,
  List<HireReceiptEntry> receipt = const [],
}) => HireProgress(
  hireId: 3,
  agentName: 'Support Relay',
  priceUsdcStroops: 10000000,
  input: 'Answer ticket 42',
  status: 'funded',
  runtimeStatus: 'running',
  subcontractReserveUsdcStroops: reserve,
  receipt: receipt,
);

Future<void> _pumpDetail(WidgetTester tester, HireProgress hire) async {
  Puls3Fonts.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    localizedTestApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: HireDetailView(hire: hire, onBackToMarketplace: () {}),
        ),
      ),
    ),
  );
}

void main() {
  group('HireDetailView receipt section (#334)', () {
    testWidgets('a plain hire with no reserve and no lines shows no section', (
      tester,
    ) async {
      await _pumpDetail(tester, _hire());
      expect(find.byType(HireReceiptView), findsNothing);
      expect(find.text('SUBCONTRACTS'), findsNothing);
    });

    testWidgets('a hire with a reserve shows the section', (tester) async {
      await _pumpDetail(tester, _hire(reserve: 30000000));
      expect(find.byType(HireReceiptView), findsOneWidget);
    });

    testWidgets('a hire with lines and no reserve still shows them', (
      tester,
    ) async {
      await _pumpDetail(tester, _hire(receipt: [_line()]));
      expect(find.byKey(const ValueKey('hire-receipt-line-1')), findsOneWidget);
    });
  });

  group('HireReceiptView', () {
    testWidgets('a reserve with no lines says there are no subcontracts yet', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('No subcontracts yet.'), findsOneWidget);
      expect(find.text('3.00 USDC'), findsOneWidget);
      expect(
        find.text('The unspent reserve is refunded to you when the hire ends.'),
        findsOneWidget,
      );
    });

    testWidgets('one row per line with the provider, budget and the agent '
        'justification', (tester) async {
      await _pump(
        tester,
        lines: [
          _line(id: 1),
          _line(id: 2, justification: 'Cheapest independent reviewer'),
        ],
      );
      expect(find.text('No subcontracts yet.'), findsNothing);
      expect(find.byKey(const ValueKey('hire-receipt-line-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('hire-receipt-line-2')), findsOneWidget);
      expect(find.text('Agent #19'), findsNWidgets(2));
      expect(find.text('GPRO…AA99'), findsNWidgets(2));
      expect(find.text('2.00 USDC'), findsNWidgets(2));
      expect(find.text('Best rated translator under budget'), findsOneWidget);
      expect(find.text('Cheapest independent reviewer'), findsOneWidget);
    });

    testWidgets('every state has a readable label; an unknown one is raw', (
      tester,
    ) async {
      const labels = {
        'pending': 'Opening on chain',
        'not_opened': 'Not opened',
        'unverified': 'Being verified',
        'open': 'Open',
        'funded': 'In progress',
        'submitted': 'Delivered',
        'completed': 'Completed',
        'rejected': 'Rejected',
        'expired': 'Expired',
        'mystery': 'mystery',
      };
      final states = labels.keys.toList();
      await _pump(
        tester,
        lines: [
          for (var i = 0; i < states.length; i++)
            _line(id: i + 1, state: states[i]),
        ],
      );
      for (var i = 0; i < states.length; i++) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('hire-receipt-state-${i + 1}')),
            matching: find.text(labels[states[i]]!),
          ),
          findsOneWidget,
          reason: states[i],
        );
      }
    });

    testWidgets('the related-party badge shows only on a related-party line', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        lines: [
          _line(id: 1, relatedParty: true),
          _line(id: 2),
        ],
      );
      expect(
        find.byKey(const ValueKey('hire-receipt-related-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('hire-receipt-related-2')),
        findsNothing,
      );
      expect(find.text('Related party'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('same builder')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('fee and payout show only when they are known', (tester) async {
      await _pump(
        tester,
        lines: [
          _line(id: 1, fee: 1000000, payout: 19000000),
          _line(id: 2, state: 'funded'),
        ],
      );
      expect(find.byKey(const ValueKey('hire-receipt-fee-1')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('hire-receipt-payout-1')),
        findsOneWidget,
      );
      expect(find.text('0.10 USDC'), findsOneWidget);
      expect(find.text('1.90 USDC'), findsOneWidget);
      expect(find.byKey(const ValueKey('hire-receipt-fee-2')), findsNothing);
      expect(find.byKey(const ValueKey('hire-receipt-payout-2')), findsNothing);
    });

    testWidgets('explorer links show only with a hash and prefer the server '
        'link', (tester) async {
      final opened = await _pump(
        tester,
        lines: [
          _line(
            id: 1,
            createTransaction: _createHash,
            createExplorerUrl: 'https://example.test/tx/create',
            settleTransaction: _settleHash,
          ),
          _line(id: 2, state: 'pending'),
        ],
      );
      expect(find.byKey(const ValueKey('hire-receipt-opened-2')), findsNothing);
      expect(
        find.byKey(const ValueKey('hire-receipt-settled-2')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('hire-receipt-opened-1')));
      await tester.tap(find.byKey(const ValueKey('hire-receipt-settled-1')));
      expect(opened, [
        'https://example.test/tx/create',
        'https://stellar.expert/explorer/testnet/tx/$_settleHash',
      ]);
      expect(find.text('Opened on chain'), findsOneWidget);
      expect(find.text('Settled on chain'), findsOneWidget);
    });

    testWidgets('spent sums the payout and fee of completed lines only', (
      tester,
    ) async {
      await _pump(
        tester,
        lines: [
          _line(id: 1, fee: 1000000, payout: 19000000),
          _line(id: 2, state: 'completed', fee: 500000, payout: 4500000),
          _line(id: 3, state: 'funded', fee: 7000000, payout: 7000000),
          _line(id: 4, state: 'rejected', fee: 0, payout: 0),
        ],
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('hire-receipt-spent')),
          matching: find.text('2.50 USDC'),
        ),
        findsOneWidget,
      );
    });
  });
}
