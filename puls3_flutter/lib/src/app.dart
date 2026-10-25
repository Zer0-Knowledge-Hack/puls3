import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/agent_repository.dart';
import 'deploy/deploy_gateway.dart';
import 'deploy/fake_deploy_gateway.dart';
import 'hire/create_hire_flow_store.dart';
import 'hire/fake_hire_gateway.dart';
import 'hire/hire_flow_store.dart';
import 'hire/hire_gateway.dart';
import 'l10n/create_locale_store.dart';
import 'l10n/l10n.dart';
import 'l10n/locale_controller.dart';
import 'l10n/locale_store.dart';
import 'screens/agent_detail_screen.dart';
import 'screens/app_shell.dart';
import 'screens/brand_screen.dart';
import 'screens/hire_detail_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/market_screen.dart';
import 'screens/my_agents_screen.dart';
import 'screens/studio_screen.dart';
import 'state/agent_catalog.dart';
import 'state/app_scope.dart';
import 'state/wallet_controller.dart';
import 'studio/fake_studio_gateway.dart';
import 'studio/studio_gateway.dart';
import 'theme/breakpoints.dart';
import 'theme/puls3_theme.dart';
import 'wallet/wallet_port.dart';

/// Builds the app router. Exposed for tests via [initialLocation].
GoRouter buildRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LandingScreen()),
      GoRoute(path: '/brand', builder: (context, state) => const BrandScreen()),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/studio',
            builder: (context, state) {
              final query = state.uri.queryParameters;
              return StudioScreen(
                // A new key per draft, so opening another one resets the form.
                key: ValueKey(state.uri.query),
                draftId: int.tryParse(query['draft'] ?? ''),
                newVersion: query['edit'] == '1',
              );
            },
          ),
          GoRoute(
            path: '/studio/agents',
            builder: (context, state) => const MyAgentsScreen(),
          ),
          GoRoute(
            path: '/market',
            builder: (context, state) => const MarketScreen(),
          ),
          GoRoute(
            path: '/agent/:id',
            builder: (context, state) =>
                AgentDetailScreen(agentId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/hires/:id',
            builder: (context, state) =>
                HireDetailScreen(hireId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
}

/// Root widget: composes the dependencies and the router.
class Puls3App extends StatefulWidget {
  const Puls3App({
    super.key,
    required this.repository,
    required this.wallet,
    this.demoRepository,
    this.deployGateway,
    this.studioGateway,
    this.hireGateway,
    this.hireFlowStore,
    this.localeStore,
    this.locale,
    this.healthCheck,
    this.initialLocation = '/',
  });

  /// The catalog: the server catalog in the app.
  final AgentRepository repository;
  final WalletPort wallet;

  /// Shown, labelled as a demo, when [repository] fails. Null shows the
  /// error state instead.
  final AgentRepository? demoRepository;

  /// The deploy backend. Until the register/deploy endpoint (#18) exists
  /// it defaults to [FakeDeployGateway], which the flow labels as a demo.
  final DeployGateway? deployGateway;

  /// Drafts, test runs and My agents. Until `StudioEndpoint` (#35) exists
  /// it defaults to [FakeStudioGateway], which the Studio labels as a demo.
  final StudioGateway? studioGateway;

  /// The hire backend (#91). It defaults to [FakeHireGateway], which the
  /// flow labels as a demo, until the server accepts wallet sessions (#136).
  final HireGateway? hireGateway;

  /// Where unfinished hires are kept: the browser's storage by default.
  final HireFlowStore? hireFlowStore;

  /// Where the language tag is kept: the browser's storage by default.
  final LocaleStore? localeStore;

  /// Forces a locale in tests. Production resolves from the store, then
  /// the device, then English.
  final Locale? locale;
  final Future<String>? healthCheck;
  final String initialLocation;

  @override
  State<Puls3App> createState() => _Puls3AppState();
}

class _Puls3AppState extends State<Puls3App> {
  late final AgentCatalog _catalog = AgentCatalog(
    widget.repository,
    fallback: widget.demoRepository,
  )..load();
  late final WalletController _wallet = WalletController(widget.wallet);
  late final GoRouter _router = buildRouter(
    initialLocation: widget.initialLocation,
  );
  late final DeployGateway _deployGateway =
      widget.deployGateway ?? FakeDeployGateway();
  late final StudioGateway _studioGateway =
      widget.studioGateway ?? FakeStudioGateway();
  late final HireGateway _hireGateway = widget.hireGateway ?? FakeHireGateway();
  late final HireFlowStore _hireFlowStore =
      widget.hireFlowStore ?? createHireFlowStore();
  late final LocaleController _locale = LocaleController(
    store: widget.localeStore ?? createLocaleStore(),
    deviceLocale: WidgetsBinding.instance.platformDispatcher.locale,
    initial: widget.locale,
  );

  @override
  void initState() {
    super.initState();
    // The banner reports a failed health check, but routes that hide it
    // (/brand) leave the future unwatched; mark the error as handled so it
    // is not reported as uncaught. The banner still receives it.
    widget.healthCheck?.ignore();
  }

  @override
  void dispose() {
    _router.dispose();
    _catalog.dispose();
    _wallet.dispose();
    _locale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Phones get the compact type scale; set before the theme is built.
    Puls3Text.compact =
        MediaQuery.sizeOf(context).width < Puls3Breakpoints.compact;
    return ListenableBuilder(
      listenable: _locale,
      builder: (context, _) => AppScope(
        catalog: _catalog,
        wallet: _wallet,
        deployGateway: _deployGateway,
        studioGateway: _studioGateway,
        hireGateway: _hireGateway,
        hireFlowStore: _hireFlowStore,
        locale: _locale,
        child: MaterialApp.router(
          onGenerateTitle: (context) => context.l10n.appTitle,
          debugShowCheckedModeBanner: false,
          theme: Puls3Theme.dark(),
          locale: _locale.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: _router,
          builder: (context, child) => Column(
            children: [
              if (widget.healthCheck != null)
                // The public brand page does not depend on the backend.
                ListenableBuilder(
                  listenable: _router.routeInformationProvider,
                  builder: (context, _) =>
                      _hidesBackendStatus(
                        _router.routeInformationProvider.value.uri.path,
                      )
                      ? const SizedBox.shrink()
                      : _BackendStatus(healthCheck: widget.healthCheck!),
                ),
              Expanded(child: child ?? const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Routes that hide the backend status banner.
bool _hidesBackendStatus(String path) => path == '/brand';

class _BackendStatus extends StatelessWidget {
  const _BackendStatus({required this.healthCheck});

  final Future<String> healthCheck;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: healthCheck,
      builder: (context, snapshot) {
        final l10n = context.l10n;
        final label = switch (snapshot.connectionState) {
          ConnectionState.waiting => l10n.backendConnecting,
          _ when snapshot.hasError => l10n.backendUnavailable,
          _ => l10n.backendVersion(snapshot.data ?? ''),
        };
        return Semantics(
          liveRegion: true,
          child: ColoredBox(
            color: Puls3Colors.surface,
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Puls3Spacing.md,
                  vertical: Puls3Spacing.xs,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Puls3Text.caption.copyWith(color: Puls3Colors.muted),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
