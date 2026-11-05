import 'package:flutter/material.dart';
import 'package:puls3_domain/puls3_domain.dart'
    show feedbackMaxScore, feedbackMinScore;

import '../../l10n/l10n.dart';
import '../../theme/puls3_theme.dart';

/// A row of stars from [feedbackMinScore] to [feedbackMaxScore] (S10).
/// [score] is null until one is picked. Read-only when [onChanged] is null,
/// as on S06 after the rating is sent.
class ScorePicker extends StatelessWidget {
  const ScorePicker({
    super.key,
    required this.score,
    this.onChanged,
    this.size = 32,
  });

  final int? score;
  final ValueChanged<int>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var value = feedbackMinScore; value <= feedbackMaxScore; value++)
          _Star(
            key: ValueKey('score-star-$value'),
            filled: value <= (score ?? 0),
            label: context.l10n.rateStars(value),
            size: size,
            onTap: onChanged == null ? null : () => onChanged(value),
          ),
      ],
    );
  }
}

class _Star extends StatelessWidget {
  const _Star({
    super.key,
    required this.filled,
    required this.label,
    required this.size,
    this.onTap,
  });

  final bool filled;
  final String label;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      filled ? Icons.star_rounded : Icons.star_outline_rounded,
      size: size,
      color: filled ? Puls3Colors.accent : Puls3Colors.muted,
    );
    if (onTap == null) return Semantics(label: label, child: icon);
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      icon: icon,
    );
  }
}
