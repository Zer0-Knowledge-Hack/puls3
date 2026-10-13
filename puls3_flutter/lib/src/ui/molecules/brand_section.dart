import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';

/// A /brand section: the title with an optional [action] on the right, a
/// hairline, an optional intro, then the content.
class BrandSection extends StatelessWidget {
  const BrandSection({
    super.key,
    required this.title,
    this.action,
    this.intro,
    required this.child,
  });

  final String title;
  final Widget? action;
  final String? intro;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Text(title, style: Puls3Text.h2Compact)),
            if (action != null) ...[
              const SizedBox(width: Puls3Spacing.md),
              action!,
            ],
          ],
        ),
        const SizedBox(height: Puls3Spacing.md),
        const Divider(height: 1, thickness: 1, color: Puls3Colors.hairline),
        if (intro != null) ...[
          const SizedBox(height: Puls3Spacing.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Text(intro!, style: Puls3Text.bodyMuted),
          ),
        ],
        const SizedBox(height: Puls3Spacing.lg),
        child,
      ],
    );
  }
}

/// Lays children out in 1 to [maxColumns] equal columns by width: three on
/// desktop, two on tablets, one on phones with the defaults.
class BrandGrid extends StatelessWidget {
  const BrandGrid({
    super.key,
    required this.children,
    this.minTileWidth = 300,
    this.maxColumns = 3,
  });

  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = Puls3Spacing.md;
        final columns = ((constraints.maxWidth + gap) / (minTileWidth + gap))
            .floor()
            .clamp(1, maxColumns);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
