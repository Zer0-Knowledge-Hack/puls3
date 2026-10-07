import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/agent_repository.dart';
import 'deploy/deploy_gateway.dart';
import 'deploy/fake_deploy_gateway.dart';
import 'domain/stellar_format.dart';
import 'screens/activity_screen.dart';
import 'screens/agent_detail_screen.dart';
import 'screens/app_shell.dart';
import 'screens/landing_screen.dart';
import 'screens/market_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/studio_screen.dart';
import 'state/agent_catalog.dart';
import 'state/app_scope.dart';
import 'state/notification_center.dart';
import 'state/profile_controller.dart';
import 'state/review_store.dart';
import 'state/wallet_controller.dart';
import 'theme/puls3_theme.dart';
import 'wallet/wallet_port.dart';

/// Builds the app router. Exposed for tests via [initialLocation].
GoRouter buildRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LandingScreen()),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/studio',
            builder: (context, state) => const StudioScreen(),
          ),
          GoRoute(
            path: '/market',
            builder: (context, state) => const MarketScreen(),
          ),
          GoRoute(
            path: '/activity',
            builder: (context, state) => const ActivityScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/agent/:id',
            builder: (context, state) =>
                AgentDetailScreen(agentId: state.pathParameters['id']!),
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
    this.deployGateway,
    this.healthCheck,
    this.initialLocation = '/',
  });

  final AgentRepository repository;
  final WalletPort wallet;

  /// The deploy backend; defaults to the demo [FakeDeployGateway] until the
  /// register/deploy endpoint (#18) exists.
  final DeployGateway? deployGateway;
  final Future<String>? healthCheck;
  final String initialLocation;

  @override
  State<Puls3App> createState() => _Puls3AppState();
}

class _Puls3AppState extends State<Puls3App> {
  late final AgentCatalog _catalog = AgentCatalog(widget.repository)..load();
  late final WalletController _wallet = WalletController(widget.wallet);
  late final GoRouter _router = buildRouter(
    initialLocation: widget.initialLocation,
  );
  final FakeLedgerIds _ids = FakeLedgerIds();
  late final DeployGateway _deployGateway =
      widget.deployGateway ?? FakeDeployGateway(ids: _ids);
  final NotificationCenter _notifications = NotificationCenter();
  final ProfileController _profile = ProfileController();
  final ReviewStore _reviews = ReviewStore();

  @override
  void dispose() {
    _router.dispose();
    _catalog.dispose();
    _wallet.dispose();
    _notifications.dispose();
    _profile.dispose();
    _reviews.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Phones get the compact type scale; set before the theme is built.
    Puls3Text.compact = MediaQuery.sizeOf(context).width < 640;
    return AppScope(
      catalog: _catalog,
      wallet: _wallet,
      ids: _ids,
      deployGateway: _deployGateway,
      notifications: _notifications,
      profile: _profile,
      reviews: _reviews,
      child: MaterialApp.router(
        title: 'puls3: the agent hub on Stellar',
        debugShowCheckedModeBanner: false,
        theme: Puls3Theme.dark(),
        routerConfig: _router,
        builder: (context, child) => Column(
          children: [
            if (widget.healthCheck != null)
              _BackendStatus(healthCheck: widget.healthCheck!),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

class _BackendStatus extends StatelessWidget {
  const _BackendStatus({required this.healthCheck});

  final Future<String> healthCheck;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: healthCheck,
      builder: (context, snapshot) {
        final label = switch (snapshot.connectionState) {
          ConnectionState.waiting => 'Connecting to backend…',
          _ when snapshot.hasError => 'Backend unavailable',
          _ => 'Backend v${snapshot.data}',
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
