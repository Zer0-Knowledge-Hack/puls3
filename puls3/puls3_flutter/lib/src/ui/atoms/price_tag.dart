import 'package:flutter/material.dart';

import '../../domain/usdc.dart';
import '../../theme/puls3_theme.dart';

/// Displays a USDC amount. Takes integer stroops; formatting is display-only.
class PriceTag extends StatelessWidget {
  const PriceTag({
    super.key,
    required this.stroops,
    this.suffix = '/ task',
    this.large = false,
  });

  final int stroops;
  final String? suffix;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final amountStyle = large ? Puls3Text.monoLg : Puls3Text.mono;
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
          if (suffix != null)
            TextSpan(
              text: ' $suffix',
              style: Puls3Text.label.copyWith(color: Puls3Colors.textMuted),
            ),
        ],
      ),
    );
  }
}
