import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';
import '../atoms/content_width.dart';
import '../atoms/wordmark.dart';
import '../molecules/built_on_stellar.dart';

/// Footer with the wordmark, a demo disclaimer and the Stellar lockup.
class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Puls3Colors.border)),
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
                const Wordmark(size: 22),
                const SizedBox(width: Puls3Spacing.sm),
                Text(
                  'Demo build. Mock data, no real funds.',
                  style: Puls3Text.label.copyWith(color: Puls3Colors.textMuted),
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
