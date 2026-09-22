import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';
import '../atoms/content_width.dart';
import '../atoms/wordmark.dart';
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

/// App bar for every non-landing screen.
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

  static const double height = 68;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Puls3Colors.background,
        border: Border(bottom: BorderSide(color: Puls3Colors.border)),
      ),
      child: ContentWidth(
        alignment: Alignment.center,
        child: Row(
          children: [
            Wordmark(size: compact ? 24 : 28, onTap: () => onNavigate('/')),
            SizedBox(width: compact ? Puls3Spacing.sm : Puls3Spacing.xl),
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
    return InkWell(
      onTap: onTap,
      borderRadius: Puls3Radius.smAll,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? Puls3Spacing.xs : Puls3Spacing.sm,
          vertical: Puls3Spacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (compact)
              Tooltip(
                message: label,
                child: Icon(
                  icon,
                  size: 20,
                  color: selected ? Puls3Colors.text : Puls3Colors.textMuted,
                ),
              )
            else
              Text(
                label,
                style: Puls3Text.label.copyWith(
                  color: selected ? Puls3Colors.text : Puls3Colors.textMuted,
                ),
              ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: Puls3Durations.fast,
              height: 2,
              width: selected ? 18 : 0,
              color: Puls3Colors.accent,
            ),
          ],
        ),
      ),
    );
  }
}
