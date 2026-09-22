import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';
import '../atoms/content_width.dart';
import '../atoms/puls3_logo.dart';
import '../molecules/wallet_chip.dart';

/// A navigation destination shown in the [TopBar].
class TopBarLink {
  const TopBarLink({
    required this.label,
    required this.path,
    required this.icon,
  });

  final String label;
  final IconData icon;
  final String path;
}

/// App bar for every non-landing screen (brand guide page 14): 56 px tall,
/// solid-3 lockup with C01-small at 28 px, text links, wallet action.
class TopBar extends StatelessWidget implements PreferredSizeWidget {
  const TopBar({
    super.key,
    required this.links,
    required this.currentPath,
    required this.onNavigate,
    required this.walletAddress,
    required this.isWalletConnecting,
    required this.onConnectWallet,
  });

  final List<TopBarLink> links;
  final String currentPath;
  final ValueChanged<String> onNavigate;
  final String? walletAddress;
  final bool isWalletConnecting;
  final VoidCallback onConnectWallet;

  static const double height = Puls3Spacing.topBarHeight;
  static const double logoMarkHeight = 28;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Puls3Colors.background,
        border: Border(bottom: BorderSide(color: Puls3Colors.hairline)),
      ),
      child: ContentWidth(
        alignment: Alignment.center,
        child: Row(
          children: [
            Puls3Logo(
              markHeight: logoMarkHeight,
              onTap: () => onNavigate('/'),
            ),
            SizedBox(width: compact ? Puls3Spacing.xs : Puls3Spacing.xl),
            for (final link in links)
              _NavLink(
                label: link.label,
                icon: link.icon,
                selected: currentPath.startsWith(link.path),
                compact: compact,
                onTap: () => onNavigate(link.path),
              ),
            const Spacer(),
            WalletChip(
              address: walletAddress,
              isConnecting: isWalletConnecting,
              onConnect: onConnectWallet,
              compact: compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({
    required this.label,
    required this.icon,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Puls3Colors.text : Puls3Colors.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: Puls3Radius.smAll,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? Puls3Spacing.xs : Puls3Spacing.sm,
          vertical: Puls3Spacing.xs,
        ),
        child: compact
            ? Tooltip(
                message: label,
                child: Icon(icon, size: 20, color: color),
              )
            : Text(
                label,
                style: Puls3Text.caption.copyWith(
                  fontSize: 14,
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
      ),
    );
  }
}
