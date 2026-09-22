import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';
import '../atoms/content_width.dart';
import '../atoms/puls3_logo.dart';
import '../molecules/built_on_stellar.dart';

/// Footer with the logo, a demo disclaimer and the Stellar lockup.
class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Puls3Colors.hairline)),
      ),
      padding: const EdgeInsets.symmetric(vertical: Puls3Spacing.lg),
      child: ContentWidth(
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Puls3Spacing.md,
          runSpacing: Puls3Spacing.sm,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Puls3Logo(markHeight: 24),
                const SizedBox(width: Puls3Spacing.sm),
                Text(
                  'Demo build. Mock data, no real funds.',
                  style: Puls3Text.caption.copyWith(color: Puls3Colors.muted),
                ),
              ],
            ),
            const BuiltOnStellar(compact: true),
          ],
        ),
      ),
    );
  }
}
