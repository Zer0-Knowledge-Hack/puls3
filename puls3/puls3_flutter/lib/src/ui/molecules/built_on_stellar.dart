import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';

/// "Built on Stellar" lockup, text only for now.
class BuiltOnStellar extends StatelessWidget {
  const BuiltOnStellar({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    // TODO: replace with official Stellar logo SVG from brand kit
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? Puls3Spacing.sm : Puls3Spacing.md,
        vertical: compact ? 6 : Puls3Spacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: Puls3Radius.pillAll,
        border: Border.all(color: Puls3Colors.border),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Built on ',
              style: Puls3Text.label.copyWith(color: Puls3Colors.textMuted),
            ),
            TextSpan(
              text: 'Stellar',
              style: Puls3Text.label.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
