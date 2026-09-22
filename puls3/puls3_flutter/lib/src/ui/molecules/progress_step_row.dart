import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';

enum StepStatus { pending, active, done }

/// One line of a staged progress list.
class ProgressStepRow extends StatelessWidget {
  const ProgressStepRow({super.key, required this.label, required this.status});

  final String label;
  final StepStatus status;

  @override
  Widget build(BuildContext context) {
    final Widget leading = switch (status) {
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
      StepStatus.pending => const Icon(
        Icons.radio_button_unchecked_rounded,
        color: Puls3Colors.hairline,
        size: 22,
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Puls3Spacing.xs),
      child: Row(
        children: [
          leading,
          const SizedBox(width: Puls3Spacing.sm),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: Puls3Durations.fast,
              style: status == StepStatus.pending
                  ? Puls3Text.bodyMuted
                  : Puls3Text.body.copyWith(fontWeight: FontWeight.w600),
              child: Text(label),
            ),
          ),
        ],
      ),
    );
  }
}
