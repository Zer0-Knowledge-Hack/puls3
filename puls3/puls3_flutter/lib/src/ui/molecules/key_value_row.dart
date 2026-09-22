import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';

/// A label on the left and a value on the right, optionally in mono type.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.mono = false,
    this.valueWidget,
  });

  final String label;
  final String value;
  final bool mono;

  /// Overrides [value] rendering when provided.
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Puls3Spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: Puls3Text.bodyMuted),
          const SizedBox(width: Puls3Spacing.md),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child:
                  valueWidget ??
                  SelectableText(
                    value,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    style: mono
                        ? Puls3Text.mono
                        : Puls3Text.body.copyWith(fontWeight: FontWeight.w600),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
