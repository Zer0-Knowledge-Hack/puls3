import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/content_width.dart';
import '../atoms/puls3_logo.dart';
import '../molecules/built_on_stellar.dart';

/// Footer with the logo, a demo disclaimer, the Brand link and the Stellar
/// lockup.
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
                  context.l10n.footerDemo,
                  style: Puls3Text.caption.copyWith(color: Puls3Colors.muted),
                ),
              ],
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Puls3Spacing.sm,
              children: [
                TextButton(
                  onPressed: () => context.go('/brand'),
                  style: TextButton.styleFrom(
                    foregroundColor: Puls3Colors.muted,
                    textStyle: Puls3Text.caption.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(context.l10n.footerBrand),
                ),
                const BuiltOnStellar(compact: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
