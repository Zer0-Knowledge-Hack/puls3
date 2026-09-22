import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_scope.dart';
import '../ui/organisms/top_bar.dart';

/// Container for every non-landing screen: wires the [TopBar] to the router
/// and the wallet.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _links = [
    TopBarLink(
      label: 'Studio',
      path: '/studio',
      icon: Icons.auto_awesome_outlined,
    ),
    TopBarLink(
      label: 'Marketplace',
      path: '/market',
      icon: Icons.storefront_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final wallet = AppScope.of(context).wallet;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(TopBar.height),
        child: ListenableBuilder(
          listenable: wallet,
          builder: (context, _) => TopBar(
            links: _links,
            currentPath: location.startsWith('/agent') ? '/market' : location,
            onNavigate: (path) => context.go(path),
            walletAddress: wallet.address,
            isWalletConnecting: wallet.isConnecting,
            onConnectWallet: wallet.connect,
          ),
        ),
      ),
      body: child,
    );
  }
}
