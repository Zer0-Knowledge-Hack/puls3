import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:puls3_flutter/l10n/generated/app_localizations.dart';
import 'package:puls3_flutter/src/data/agent_repository.dart';
import 'package:puls3_flutter/src/deploy/deploy_flow_controller.dart';
import 'package:puls3_flutter/src/deploy/deploy_gateway.dart';
import 'package:puls3_flutter/src/domain/agent_draft.dart';
import 'package:puls3_flutter/src/hire/fake_hire_gateway.dart';
import 'package:puls3_flutter/src/hire/hire_flow_store.dart';
import 'package:puls3_flutter/src/l10n/locale_controller.dart';
import 'package:puls3_flutter/src/l10n/locale_store.dart';
import 'package:puls3_flutter/src/screens/deploy_sheet.dart';
import 'package:puls3_flutter/src/state/agent_catalog.dart';
import 'package:puls3_flutter/src/state/app_scope.dart';
import 'package:puls3_flutter/src/state/wallet_controller.dart';
import 'package:puls3_flutter/src/studio/fake_studio_gateway.dart';
import 'package:puls3_flutter/src/theme/puls3_theme.dart';
import 'package:puls3_flutter/src/wallet/mock_wallet.dart';

import '../helpers.dart';

class _InstantDeployGateway implements DeployGateway {
  _InstantDeployGateway({this.isDemo = false, this.agentId = 42});

  @override
  final bool isDemo;
  final int agentId;

  @override
  Future<PreparedDeploy> prepare(
    AgentDraft draft, {
    required String builder,
  }) async {
    return const PreparedDeploy(
      preparationId: 'prep-1',
      unsignedTransaction: 'AAAA-unsigned',
    );
  }

  @override
  Future<Registration> submitRegistration(
    PreparedDeploy prepared,
    String signedTransaction,
  ) async {
    return Registration(
      agentId: agentId,
      transactionHash:
          'aa11bb22cc33dd44ee55ff6600112233445566778899aabbccddeeff00112233',
    );
  }

  @override
  Future<String> activate(Registration registration) async {
    return 'GCDSVE4MGRNDOWEP7HX7HGMECBFAZPDI2J5PDGWDLOLLLIUIXFFSQFXZ';
  }

  @override
  Future<String?> walletAuthorization(Registration registration) async => null;

  @override
  Future<void> submitWalletAuthorization(
    Registration registration,
    String signedAuthorizationEntry,
  ) async {}
}

void main() {
  testWidgets(
    'live deploy with draftId publishes to catalog with studio-<draftId> and onViewAgent navigates to it',
    (tester) async {
      Puls3Fonts.useGoogleFonts = false;
      final wallet = MockWallet(
        connectDelay: Duration.zero,
        signDelay: Duration.zero,
      )..switchAccount();
      final catalog = AgentCatalog(const InMemoryAgentRepository([]));
      final walletController = WalletController(wallet);
      addTearDown(walletController.dispose);

      DeployResult? recordedResult;

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => showDeploySheet(
                  context,
                  const AgentDraft(
                    name: 'Studio Deployed Bot',
                    description: 'Deployed live from studio test.',
                    model: 'Claude Sonnet',
                    systemPrompt: 'You test deploy.',
                    skills: ['Testing'],
                    priceUsdcStroops: 5000000,
                    draftId: 7,
                  ),
                  onLive: (result) => recordedResult = result,
                ),
                child: const Text('Open deploy sheet'),
              ),
            ),
          ),
          GoRoute(
            path: '/agent/:id',
            builder: (_, state) => Scaffold(
              body: Text('agent route: ${state.pathParameters['id']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        AppScope(
          catalog: catalog,
          wallet: walletController,
          deployGateway: _InstantDeployGateway(isDemo: false, agentId: 42),
          studioGateway: FakeStudioGateway(),
          hireGateway: FakeHireGateway(),
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

      await tester.tap(find.text('Open deploy sheet'));
      await advance(tester, const Duration(milliseconds: 500));

      // Wait for DeployFlow to run through preparation, registration, and activation.
      await advance(tester, const Duration(seconds: 3));

      expect(find.byType(DeploySheet), findsOneWidget);
      expect(find.text('Agent deployed'), findsOneWidget);
      expect(recordedResult, isNotNull);
      expect(recordedResult!.agentId, 42);

      // Verify catalog.publish carries catalogId 'studio-7'
      final published = catalog.byId('studio-7');
      expect(published, isNotNull);
      expect(published!.id, 'studio-7');
      expect(published.name, 'Studio Deployed Bot');

      // Tap 'Open agent' to trigger onViewAgent
      await tester.tap(find.text('Open agent'));
      await advance(tester, const Duration(milliseconds: 500));

      // Verify sheet closed and navigated to /agent/studio-7
      expect(find.byType(DeploySheet), findsNothing);
      expect(find.text('agent route: studio-7'), findsOneWidget);
    },
  );

  testWidgets(
    'live deploy without draftId publishes with numeric agentId and onViewAgent navigates to /agent/<id>',
    (tester) async {
      Puls3Fonts.useGoogleFonts = false;
      final wallet = MockWallet(
        connectDelay: Duration.zero,
        signDelay: Duration.zero,
      )..switchAccount();
      final catalog = AgentCatalog(const InMemoryAgentRepository([]));
      final walletController = WalletController(wallet);
      addTearDown(walletController.dispose);

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => showDeploySheet(
                  context,
                  const AgentDraft(
                    name: 'Standalone Bot',
                    description: 'No draft id.',
                    model: 'Claude Sonnet',
                    systemPrompt: 'You test standalone.',
                    skills: ['Testing'],
                    priceUsdcStroops: 5000000,
                  ),
                ),
                child: const Text('Open deploy sheet'),
              ),
            ),
          ),
          GoRoute(
            path: '/agent/:id',
            builder: (_, state) => Scaffold(
              body: Text('agent route: ${state.pathParameters['id']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        AppScope(
          catalog: catalog,
          wallet: walletController,
          deployGateway: _InstantDeployGateway(isDemo: false, agentId: 99),
          studioGateway: FakeStudioGateway(),
          hireGateway: FakeHireGateway(),
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

      await tester.tap(find.text('Open deploy sheet'));
      await advance(tester, const Duration(seconds: 3));

      expect(find.text('Agent deployed'), findsOneWidget);

      final published = catalog.byId('99');
      expect(published, isNotNull);
      expect(published!.id, '99');

      await tester.tap(find.text('Open agent'));
      await advance(tester, const Duration(milliseconds: 500));

      expect(find.byType(DeploySheet), findsNothing);
      expect(find.text('agent route: 99'), findsOneWidget);
    },
  );
}
