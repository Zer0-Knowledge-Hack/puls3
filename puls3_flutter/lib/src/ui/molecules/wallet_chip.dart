import 'package:flutter/material.dart';

import '../../domain/stellar_format.dart';
import '../../theme/puls3_theme.dart';

/// "Connect wallet" chip that shows the shortened address once connected.
class WalletChip extends StatelessWidget {
  const WalletChip({
    super.key,
    required this.address,
    required this.isConnecting,
    required this.onConnect,
    this.compact = false,
  });

  final String? address;
  final bool isConnecting;
  final VoidCallback onConnect;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final connected = address != null;
    final label = connected
        ? shortenAddress(address!)
        : isConnecting
        ? 'Connecting…'
        : (compact ? 'Connect' : 'Connect wallet');

    return Material(
      color: connected ? Puls3Colors.surface : Puls3Colors.accent,
      shape: RoundedRectangleBorder(
        borderRadius: Puls3Radius.pillAll,
        side: BorderSide(
          color: connected ? Puls3Colors.hairline : Puls3Colors.accent,
        ),
      ),
      child: InkWell(
        borderRadius: Puls3Radius.pillAll,
        onTap: connected || isConnecting ? null : onConnect,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Puls3Spacing.md,
            vertical: Puls3Spacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (connected)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Puls3Colors.success,
                    shape: BoxShape.circle,
                  ),
                )
              else
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 16,
                  color: Puls3Colors.onAccent,
                ),
              const SizedBox(width: Puls3Spacing.xs),
              Text(
                label,
                style: connected
                    ? Puls3Text.data
                    : Puls3Text.caption.copyWith(color: Puls3Colors.onAccent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
