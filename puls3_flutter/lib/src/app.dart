import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/agent_repository.dart';
import 'domain/stellar_format.dart';
import 'screens/agent_detail_screen.dart';
import 'screens/app_shell.dart';
import 'screens/landing_screen.dart';
import 'screens/market_screen.dart';
import 'screens/studio_screen.dart';
import 'state/agent_catalog.dart';
import 'state/app_scope.dart';
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
    this.initialLocation = '/',
  });

  final AgentRepository repository;
  final WalletPort wallet;
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

  @override
  void dispose() {
    _router.dispose();
    _catalog.dispose();
    _wallet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      catalog: _catalog,
      wallet: _wallet,
      ids: _ids,
      child: MaterialApp.router(
        title: 'puls3: the agent hub on Stellar',
        debugShowCheckedModeBanner: false,
        theme: Puls3Theme.dark(),
        routerConfig: _router,
      ),
    );
  }
}
