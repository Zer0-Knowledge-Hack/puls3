import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';

/// A headline figure with a short explanation, e.g. "~5s settlement".
class FeaturePoint extends StatelessWidget {
  const FeaturePoint({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Puls3Spacing.lg),
      decoration: BoxDecoration(
        color: Puls3Colors.surface.withValues(alpha: 0.85),
        borderRadius: Puls3Radius.lgAll,
        border: Border.all(color: Puls3Colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Puls3Colors.accent, size: 22),
          const SizedBox(height: Puls3Spacing.md),
          Text(title, style: Puls3Text.displayMd.copyWith(fontSize: 30)),
          const SizedBox(height: Puls3Spacing.xs),
          Text(body, style: Puls3Text.bodyMuted),
        ],
      ),
    );
  }
}
