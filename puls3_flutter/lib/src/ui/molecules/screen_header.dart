import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';

/// Below this width the app uses its phone layout: bottom navigation,
/// compact headers and sticky primary actions.
const double compactLayoutMaxWidth = 640;

/// Whether the screen gets the phone layout.
bool isCompactLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width < compactLayoutMaxWidth;

/// Title and one-line subtitle of a screen. On phones the title is 22 px and
/// the subtitle 14 px, like an app header; on wider screens the brand sizes
/// apply.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;

  /// Optional accent on the title row, e.g. a live count.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final compact = isCompactLayout(context);
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final titleStyle = compact
        ? Puls3Text.h3.copyWith(fontSize: 20, fontWeight: FontWeight.w600)
        : wide
        ? Puls3Text.h1
        : Puls3Text.h2Compact;
    final subtitleStyle = compact
        ? Puls3Text.bodyMuted.copyWith(fontSize: 14, height: 1.45)
        : Puls3Text.lead;
    final trailing = this.trailing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title, style: titleStyle),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: Puls3Spacing.sm),
              trailing,
            ],
          ],
        ),
        SizedBox(height: compact ? 2 : Puls3Spacing.xs),
        Text(subtitle, style: subtitleStyle),
      ],
    );
  }
}
