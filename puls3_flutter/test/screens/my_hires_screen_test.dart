import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:puls3_flutter/l10n/generated/app_localizations.dart';
import 'package:puls3_flutter/src/data/agent_repository.dart';
import 'package:puls3_flutter/src/deploy/fake_deploy_gateway.dart';
import 'package:puls3_flutter/src/hire/fake_hire_gateway.dart';
import 'package:puls3_flutter/src/hire/hire_flow_store.dart';
import 'package:puls3_flutter/src/hire/hire_gateway.dart';
import 'package:puls3_flutter/src/l10n/locale_controller.dart';
import 'package:puls3_flutter/src/l10n/locale_store.dart';
import 'package:puls3_flutter/src/screens/my_hires_screen.dart';
import 'package:puls3_flutter/src/state/agent_catalog.dart';
import 'package:puls3_flutter/src/state/app_scope.dart';
import 'package:puls3_flutter/src/state/wallet_controller.dart';
import 'package:puls3_flutter/src/studio/fake_studio_gateway.dart';
import 'package:puls3_flutter/src/theme/puls3_theme.dart';
import 'package:puls3_flutter/src/wallet/wallet_port.dart';

import '../helpers.dart';
import 'hire_sheet_test.dart' show TestWallet;

const _consumer = 'GUSER123';

final _rows = [
  HireSummaryItem(
    hireId: 5,
    agentName: 'Support Relay',
    inputPreview: 'Answer ticket 42',
    priceUsdcStroops: 10000000,
    status: 'submitted',
    approvalDeadline: DateTime.utc(2030, 1, 2),
    needsAction: true,
  ),
  const HireSummaryItem(
    hireId: 4,
    agentName: 'Researcher',
    inputPreview: 'Summarise three papers',
    priceUsdcStroops: 20000000,
    status: 'funded',
  ),
  const HireSummaryItem(
    hireId: 3,
    agentName: 'Translator',
    inputPreview: 'Translate the email',
    priceUsdcStroops: 5000000,
    status: 'completed',
  ),
];

/// A demo gateway whose list is scripted.
class _ListGateway extends FakeHireGateway {
  _ListGateway(this.hires) : super(delay: Duration.zero);

  final List<HireSummaryItem> hires;

  @override
  Future<List<HireSummaryItem>> listMyHires(String consumer) async => hires;
}

Future<void> _pump(
  WidgetTester tester, {
  required HireGateway gateway,
  WalletPort? wallet,
}) async {
  Puls3Fonts.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/hires',
    routes: [
      GoRoute(
        path: '/hires',
        builder: (_, _) => const Scaffold(body: MyHiresScreen()),
      ),
      GoRoute(
        path: '/hires/:id',
        builder: (_, state) => Scaffold(
          body: Text(
            'detail ${state.pathParameters['id']}'
            '${state.uri.queryParameters['as'] == null ? '' : ' as ${state.uri.queryParameters['as']}'}',
          ),
        ),
      ),
      GoRoute(
        path: '/market',
        builder: (_, _) => const Scaffold(body: Text('market')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    AppScope(
      catalog: AgentCatalog(const InMemoryAgentRepository(testAgents)),
      wallet: WalletController(
        wallet ?? TestWallet(initialAddress: _consumer),
      ),
      deployGateway: FakeDeployGateway(),
      studioGateway: FakeStudioGateway(),
      hireGateway: gateway,
      hireFlowStore: MemoryHireFlowStore(),
      locale: LocaleController(
        store: MemoryLocaleStore(),
        initial: const Locale('en'),
      ),
      child: MaterialApp.router(
        theme: Puls3Theme.dark(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _openTab(WidgetTester tester, HireListTab tab) async {
  await tester.tap(find.byKey(ValueKey('my-hires-tab-${tab.name}')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('rows are split by tab, needs your action first', (
    tester,
  ) async {
    await _pump(tester, gateway: _ListGateway(_rows));

    expect(find.text('Needs your action (1)'), findsOneWidget);
    expect(find.text('In progress (1)'), findsOneWidget);
    expect(find.text('Finished (1)'), findsOneWidget);
    expect(find.text('Support Relay'), findsOneWidget);
    expect(find.text('Answer ticket 42'), findsOneWidget);
    expect(find.text('Ready for your review'), findsOneWidget);
    expect(find.textContaining('Approve by'), findsOneWidget);
    expect(find.text('Researcher'), findsNothing);

    await _openTab(tester, HireListTab.inProgress);
    expect(find.text('Researcher'), findsOneWidget);
    expect(find.text('Support Relay'), findsNothing);

    await _openTab(tester, HireListTab.finished);
    expect(find.text('Translator'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('tapping a row opens /hires/:id', (tester) async {
    await _pump(tester, gateway: _ListGateway(_rows));

    await tester.tap(find.byKey(const ValueKey('my-hires-row-5')));
    await tester.pumpAndSettle();

    expect(find.text('detail 5'), findsOneWidget);
  });

  testWidgets('a hire paid by an agent of the user says so and opens as it', (
    tester,
  ) async {
    await _pump(
      tester,
      gateway: _ListGateway(const [
        HireSummaryItem(
          hireId: 8,
          agentName: 'Translator',
          inputPreview: 'Translate the email',
          priceUsdcStroops: 5000000,
          status: 'funded',
          paidByAgentId: 11,
          paidByAgentName: 'Scout',
        ),
      ]),
    );

    expect(find.text('Paid by your agent Scout'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('my-hires-row-8')));
    await tester.pumpAndSettle();

    expect(find.text('detail 8 as 11'), findsOneWidget);
  });

  testWidgets('a hire the user paid names no agent', (tester) async {
    await _pump(tester, gateway: _ListGateway(_rows));

    expect(find.textContaining('Paid by your agent'), findsNothing);
  });

  testWidgets('an empty tab links to the Marketplace', (tester) async {
    await _pump(tester, gateway: _ListGateway(const []));

    expect(
      find.byKey(const ValueKey('my-hires-empty-inProgress')),
      findsOneWidget,
    );
    await tester.tap(find.text('Browse the Marketplace'));
    await tester.pumpAndSettle();

    expect(find.text('market'), findsOneWidget);
  });

  testWidgets('without a wallet it asks to connect one', (tester) async {
    await _pump(
      tester,
      gateway: _ListGateway(_rows),
      wallet: TestWallet(),
    );

    expect(find.byKey(const ValueKey('my-hires-connect')), findsOneWidget);
    expect(find.text('Connect your wallet'), findsOneWidget);
  });

  testWidgets('the demo gateway shows sample rows in every tab', (
    tester,
  ) async {
    await _pump(tester, gateway: FakeHireGateway(delay: Duration.zero));
    await tester.pumpAndSettle();

    expect(find.text('Needs your action (1)'), findsOneWidget);
    expect(find.text('In progress (1)'), findsOneWidget);
    expect(find.text('Finished (1)'), findsOneWidget);
  });

  group('navigation', () {
    testWidgets('desktop header links to My hires', (tester) async {
      await pumpApp(tester, location: '/market');

      await tester.tap(find.text('My hires').first);
      await advance(tester, const Duration(milliseconds: 400));

      expect(find.byKey(const ValueKey('my-hires-connect')), findsOneWidget);
    });

    testWidgets('the phone bottom bar has My hires', (tester) async {
      await pumpApp(tester, location: '/market', size: const Size(390, 844));

      final item = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('My hires'),
      );
      expect(item, findsOneWidget);
      await tester.tap(item);
      await advance(tester, const Duration(milliseconds: 400));

      expect(find.byKey(const ValueKey('my-hires-connect')), findsOneWidget);
    });
  });
}
