import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
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
        border: Border.all(color: Puls3Colors.hairline),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${context.l10n.footerBuiltOn} ',
              style: Puls3Text.caption.copyWith(color: Puls3Colors.text),
            ),
            TextSpan(
              text: 'Stellar',
              style: Puls3Text.caption.copyWith(
                color: Puls3Colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
