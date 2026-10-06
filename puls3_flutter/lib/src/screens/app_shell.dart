import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_scope.dart';
import '../theme/puls3_theme.dart';
import '../ui/molecules/screen_header.dart';
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
      label: 'Marketplace',
      path: '/market',
      icon: Icons.storefront_outlined,
    ),
    TopBarLink(
      label: 'Studio',
      path: '/studio',
      icon: Icons.auto_awesome_outlined,
    ),
    TopBarLink(
      label: 'Activity',
      path: '/activity',
      icon: Icons.notifications_none_rounded,
    ),
    TopBarLink(
      label: 'Profile',
      path: '/profile',
      icon: Icons.person_outline_rounded,
    ),
  ];

  static const _selectedIcons = {
    '/market': Icons.storefront_rounded,
    '/studio': Icons.auto_awesome,
    '/activity': Icons.notifications_rounded,
    '/profile': Icons.person_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final wallet = scope.wallet;
    final notifications = scope.notifications;
    final current = location.startsWith('/agent') ? '/market' : location;
    final compact = isCompactLayout(context);
    final selected = _links.indexWhere((l) => current.startsWith(l.path));
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(TopBar.height),
        child: ListenableBuilder(
          listenable: Listenable.merge([wallet, notifications]),
          builder: (context, _) => TopBar(
            links: compact ? const [] : _links,
            currentPath: current,
            onNavigate: (path) => context.go(path),
            walletAddress: wallet.address,
            isWalletConnecting: wallet.isConnecting,
            onConnectWallet: wallet.connect,
            badges: {'/activity': notifications.unreadCount},
          ),
        ),
      ),
      body: child,
      bottomNavigationBar: compact
          ? ListenableBuilder(
              listenable: notifications,
              builder: (context, _) => NavigationBar(
                height: 64,
                backgroundColor: Puls3Colors.surface,
                indicatorColor: Puls3Colors.accent.withValues(alpha: 0.18),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                selectedIndex: selected < 0 ? 0 : selected,
                onDestinationSelected: (i) => context.go(_links[i].path),
                destinations: [
                  for (final link in _links)
                    NavigationDestination(
                      icon: _withBadge(
                        Icon(link.icon),
                        link.path == '/activity'
                            ? notifications.unreadCount
                            : 0,
                      ),
                      selectedIcon: _withBadge(
                        Icon(
                          _selectedIcons[link.path],
                          color: Puls3Colors.accent,
                        ),
                        link.path == '/activity'
                            ? notifications.unreadCount
                            : 0,
                      ),
                      label: link.label,
                    ),
                ],
              ),
            )
          : null,
    );
  }

  static Widget _withBadge(Widget icon, int count) => count == 0
      ? icon
      : Badge(
          label: Text('$count'),
          backgroundColor: Puls3Colors.accent,
          textColor: Puls3Colors.onAccent,
          child: icon,
        );
}
