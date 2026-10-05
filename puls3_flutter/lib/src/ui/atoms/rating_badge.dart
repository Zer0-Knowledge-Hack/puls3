import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';

/// Star icon with a one-decimal rating.
///
/// Renders nothing for a rating of 0 or less: the agent has no reviews yet,
/// and showing `0.0` would read as a bad score.
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 16, color: Puls3Colors.accent),
        const SizedBox(width: 2),
        Text(rating.toStringAsFixed(1), style: Puls3Text.caption),
      ],
    );
  }
}
