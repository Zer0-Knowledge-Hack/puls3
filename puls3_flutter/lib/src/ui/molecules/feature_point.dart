import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';

/// A stat in Doto with a short headline and explanation.
class FeaturePoint extends StatelessWidget {
  const FeaturePoint({
    super.key,
    required this.stat,
    required this.title,
    required this.body,
  });

  /// Short figure shown in the Doto accent face, e.g. "~5s".
  final String stat;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Puls3Spacing.lg),
      decoration: BoxDecoration(
        color: Puls3Colors.surface,
        borderRadius: Puls3Radius.lgAll,
        border: Border.all(color: Puls3Colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stat, style: Puls3Text.accentLg),
          const SizedBox(height: Puls3Spacing.lg),
          Text(title, style: Puls3Text.h3.copyWith(fontSize: 20)),
          const SizedBox(height: Puls3Spacing.xs),
          Text(body, style: Puls3Text.bodyMuted),
        ],
      ),
    );
  }
}
