import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/l10n/generated/app_localizations.dart';
import 'package:puls3_flutter/src/data/agent_repository.dart';
import 'package:puls3_flutter/src/deploy/fake_deploy_gateway.dart';
import 'package:puls3_flutter/src/hire/fake_hire_gateway.dart';
import 'package:puls3_flutter/src/hire/hire_flow_store.dart';
import 'package:puls3_flutter/src/hire/hire_gateway.dart';
import 'package:puls3_flutter/src/l10n/locale_controller.dart';
import 'package:puls3_flutter/src/l10n/locale_store.dart';
import 'package:puls3_flutter/src/screens/agent_hire_tracker.dart';
import 'package:puls3_flutter/src/state/agent_catalog.dart';
import 'package:puls3_flutter/src/state/app_scope.dart';
import 'package:puls3_flutter/src/state/wallet_controller.dart';
import 'package:puls3_flutter/src/studio/fake_studio_gateway.dart';
import 'package:puls3_flutter/src/studio/studio_gateway.dart';
import 'package:puls3_flutter/src/theme/puls3_theme.dart';

import '../helpers.dart';
import 'hire_sheet_test.dart' show TestWallet;

const _owner = 'GOWNER';
const _createHash =
    'c0ffee0000000000000000000000000000000000000000000000000000000001';

/// Answers `getAgentHire` with one final progress.
class _AgentHireGateway extends FakeStudioGateway {
  _AgentHireGateway(this.progress) : super(delay: Duration.zero);

  final AgentHireProgress progress;

  @override
  Future<AgentHireProgress> getAgentHire({
    required int hiringAgentId,
    required int hireId,
    required String owner,
  }) async => progress;
}

Future<List<Uri>> _pump(WidgetTester tester, AgentHireProgress progress) async {
  Puls3Fonts.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final opened = <Uri>[];
  await tester.pumpWidget(
    AppScope(
      catalog: AgentCatalog(const InMemoryAgentRepository(testAgents)),
      wallet: WalletController(TestWallet(initialAddress: _owner)),
      deployGateway: FakeDeployGateway(),
      studioGateway: _AgentHireGateway(progress),
      hireGateway: FakeHireGateway(delay: Duration.zero),
      hireFlowStore: MemoryHireFlowStore(),
      locale: LocaleController(
        store: MemoryLocaleStore(),
        initial: const Locale('en'),
      ),
      child: MaterialApp(
        theme: Puls3Theme.dark(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AgentHireTracker(
              hiringAgentId: 9,
              hireId: 8,
              owner: _owner,
              openUrl: (url) async => opened.add(url),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pump(const Duration(milliseconds: 10));
  return opened;
}

void main() {
  testWidgets('a plain agent hire shows no subcontract receipt (#334)', (
    tester,
  ) async {
    await _pump(
      tester,
      const AgentHireProgress(
        hireId: 8,
        status: 'completed',
        result: 'Done',
        fundTransaction: 'fa11ce',
      ),
    );
    expect(find.byKey(const Key('collab-progress')), findsOneWidget);
    expect(find.byKey(const ValueKey('hire-receipt')), findsNothing);
  });

  testWidgets('an agent hire with a reserve shows its receipt rows, discloses '
      'a related party to the builder and opens a line on StellarExpert '
      '(#334)', (tester) async {
    final semantics = tester.ensureSemantics();
    final opened = await _pump(
      tester,
      AgentHireProgress(
        hireId: 8,
        status: 'completed',
        result: 'Done',
        subcontractReserveUsdcStroops: 30000000,
        receipt: [
          HireReceiptEntry(
            id: 1,
            providerAgentId: 19,
            providerWallet: 'GPROVIDER',
            budgetUsdcStroops: 20000000,
            state: 'funded',
            createTransaction: _createHash,
            relatedParty: true,
            justification: 'Best rated translator',
            createdAt: DateTime.utc(2026, 11, 24),
          ),
        ],
      ),
    );

    expect(find.byKey(const ValueKey('hire-receipt-line-1')), findsOneWidget);
    expect(find.text('Agent #19'), findsOneWidget);
    expect(find.text('Best rated translator'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('same builder as your agent')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('hire-receipt-opened-1')));
    await tester.pump();
    expect(opened.single.toString(), endsWith('/tx/$_createHash'));
    semantics.dispose();
  });
}
