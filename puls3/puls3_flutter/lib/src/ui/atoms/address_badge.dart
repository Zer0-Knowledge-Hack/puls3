import 'package:flutter/material.dart';

import '../../domain/stellar_format.dart';
import '../../theme/puls3_theme.dart';

/// A shortened Stellar address (`GABC…WXYZ`) in mono type.
class AddressBadge extends StatelessWidget {
  const AddressBadge({
    super.key,
    required this.address,
    this.onTap,
    this.icon = Icons.account_balance_wallet_outlined,
  });

  final String address;
  final VoidCallback? onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: address,
      child: Material(
        color: Puls3Colors.background,
        shape: const RoundedRectangleBorder(
          borderRadius: Puls3Radius.pillAll,
          side: BorderSide(color: Puls3Colors.hairline),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: Puls3Radius.pillAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Puls3Spacing.sm,
              vertical: 6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: Puls3Colors.lavender),
                const SizedBox(width: Puls3Spacing.xs),
                Text(shortenAddress(address), style: Puls3Text.data),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
