import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';

enum StepStatus { pending, active, done, failed }

/// One line of a staged progress list: a status marker, a label and, when
/// given, the step's [icon] and a one-line [description].
class ProgressStepRow extends StatelessWidget {
  const ProgressStepRow({
    super.key,
    required this.label,
    required this.status,
    this.icon,
    this.description,
  });

  final String label;
  final StepStatus status;

  /// What the step is about (wallet, chain…), shown next to the label.
  final IconData? icon;

  /// Shown under the label while the step is active or failed.
  final String? description;

  @override
  Widget build(BuildContext context) {
    final Widget marker = switch (status) {
      StepStatus.done => const Icon(
        Icons.check_circle_rounded,
        color: Puls3Colors.success,
        size: 22,
      ),
      StepStatus.active => const SizedBox.square(
        dimension: 22,
        child: Padding(
          padding: EdgeInsets.all(2),
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Puls3Colors.accent,
          ),
        ),
      ),
      StepStatus.failed => const Icon(
        Icons.error_rounded,
        color: Puls3Colors.accent,
        size: 22,
      ),
      StepStatus.pending => const Icon(
        Icons.radio_button_unchecked_rounded,
        color: Puls3Colors.hairline,
        size: 22,
      ),
    };
    final emphasized = status != StepStatus.pending;
    final description = this.description;
    final showDescription =
        description != null &&
        (status == StepStatus.active || status == StepStatus.failed);
    final stateLabel = switch (status) {
      StepStatus.done => 'completed',
      StepStatus.active => 'in progress',
      StepStatus.failed => 'failed',
      StepStatus.pending => 'pending',
    };

    return Semantics(
      label: '$label, $stateLabel',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Puls3Spacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            marker,
            const SizedBox(width: Puls3Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: AnimatedDefaultTextStyle(
                          duration: Puls3Durations.fast,
                          style: emphasized
                              ? Puls3Text.body.copyWith(
                                  fontSize: 14,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                )
                              : Puls3Text.bodyMuted.copyWith(
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                          child: Text(label),
                        ),
                      ),
                      if (icon != null) ...[
                        const SizedBox(width: Puls3Spacing.xs),
                        Icon(
                          icon,
                          size: 16,
                          color: emphasized
                              ? Puls3Colors.lavender
                              : Puls3Colors.hairline,
                        ),
                      ],
                    ],
                  ),
                  if (showDescription)
                    Text(
                      description,
                      style: Puls3Text.bodyMuted.copyWith(
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
