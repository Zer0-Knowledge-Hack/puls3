import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import '../state/app_scope.dart';
import '../theme/breakpoints.dart';
import '../theme/puls3_theme.dart';
import '../ui/molecules/language_menu.dart';
import '../ui/organisms/top_bar.dart';
import 'wallet_sheet.dart';

/// Shared chrome for landing, Marketplace and Studio: [TopBar] plus, on
/// phones, a bottom [NavigationBar]. Logo, Marketplace, Studio, language
/// and wallet stay in the same slots on every route.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static String _destination(String location) {
    if (location == '/') return '/';
    if (location.startsWith('/studio')) return '/studio';
    if (location.startsWith('/market') ||
        location.startsWith('/agent') ||
        location.startsWith('/hires')) {
      return '/market';
    }
    return location;
  }

  static int _selectedIndex(List<TopBarLink> links, String current) {
    if (current == '/') {
      final home = links.indexWhere((l) => l.path == '/');
      return home < 0 ? 0 : home;
    }
    final i = links.indexWhere(
      (l) => l.path != '/' && current.startsWith(l.path),
    );
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final productLinks = [
      TopBarLink(
        label: l10n.navMarketplace,
        path: '/market',
        icon: Icons.storefront_outlined,
      ),
      TopBarLink(
        label: l10n.navStudio,
        path: '/studio',
        icon: Icons.auto_awesome_outlined,
      ),
    ];
    final compactLinks = [
      TopBarLink(
        label: l10n.navHome,
        path: '/',
        icon: Icons.home_outlined,
      ),
      ...productLinks,
    ];
    final wallet = AppScope.of(context).wallet;
    final locale = AppScope.of(context).locale;
    final current = _destination(location);
    final compact = isCompactLayout(context);
    final barLinks = compact ? compactLinks : productLinks;
    final selected = _selectedIndex(barLinks, current);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(TopBar.height),
        child: ListenableBuilder(
          listenable: Listenable.merge([wallet, locale]),
          builder: (context, _) => TopBar(
            links: compact ? const [] : productLinks,
            currentPath: current,
            onNavigate: (path) => context.go(path),
            walletAddress: wallet.address,
            isWalletConnecting: wallet.isConnecting,
            onConnectWallet: () => showWalletSheet(context),
            beforeWallet: LanguageMenu(
              locale: locale.locale,
              onSelected: locale.setLocale,
              compact: true,
              iconOnly: compact,
            ),
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
              selectedIndex: selected,
              onDestinationSelected: (i) => context.go(barLinks[i].path),
              destinations: [
                for (final link in barLinks)
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
