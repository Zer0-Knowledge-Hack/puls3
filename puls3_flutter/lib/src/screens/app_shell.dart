import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_scope.dart';
import '../theme/breakpoints.dart';
import '../theme/puls3_theme.dart';
import '../ui/organisms/top_bar.dart';

/// Container for every non-landing screen: wires the [TopBar] to the router
/// and the wallet. On phones the destinations move to a bottom navigation
/// bar, as in a native app, and the top bar keeps the logo and the wallet.
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
    final current = location.startsWith('/agent') ? '/market' : location;
    final compact = isCompactLayout(context);
    final selected = _links.indexWhere((l) => current.startsWith(l.path));
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(TopBar.height),
        child: ListenableBuilder(
          listenable: wallet,
          builder: (context, _) => TopBar(
            links: compact ? const [] : _links,
            currentPath: current,
            onNavigate: (path) => context.go(path),
            walletAddress: wallet.address,
            isWalletConnecting: wallet.isConnecting,
            onConnectWallet: wallet.connect,
          ),
        ),
      ),
      body: child,
      bottomNavigationBar: compact
          ? NavigationBar(
              height: 64,
              backgroundColor: Puls3Colors.surface,
              indicatorColor: Puls3Colors.accent.withValues(alpha: 0.18),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              selectedIndex: selected < 0 ? 0 : selected,
              onDestinationSelected: (i) => context.go(_links[i].path),
              destinations: [
                for (final link in _links)
                  NavigationDestination(
                    icon: Icon(link.icon),
                    selectedIcon: Icon(link.icon, color: Puls3Colors.accent),
                    label: link.label,
                  ),
              ],
            )
          : null,
    );
  }
}
