import 'package:flutter/material.dart';

import '../../domain/usdc.dart';
import '../../l10n/l10n.dart';
import '../../theme/puls3_theme.dart';

/// Displays a USDC amount. Takes integer stroops; formatting is display-only.
class PriceTag extends StatelessWidget {
  const PriceTag({
    super.key,
    required this.stroops,
    this.perTask = true,
    this.large = false,
  });

  final int stroops;

  /// Appends the localized "/ task" suffix.
  final bool perTask;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final amountStyle = large ? Puls3Text.dataLg : Puls3Text.data;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: formatUsdc(stroops),
            style: amountStyle.copyWith(
              color: Puls3Colors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: ' USDC', style: amountStyle),
          if (perTask)
            TextSpan(
              text: ' ${context.l10n.pricePerTask}',
              style: Puls3Text.caption.copyWith(color: Puls3Colors.muted),
            ),
        ],
      ),
    );
  }
}
