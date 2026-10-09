import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';
import '../atoms/primary_button.dart';

/// A centered message for a list or screen with nothing to show, with an
/// optional action. Purely presentational.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Puls3Spacing.xxl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: Puls3Colors.muted),
              const SizedBox(height: Puls3Spacing.sm),
              Text(title, style: Puls3Text.title, textAlign: TextAlign.center),
              const SizedBox(height: Puls3Spacing.xxs),
              Text(
                message,
                style: Puls3Text.bodyMuted,
                textAlign: TextAlign.center,
              ),
              if (label != null && onAction != null) ...[
                const SizedBox(height: Puls3Spacing.md),
                PrimaryButton(
                  label: label,
                  variant: PrimaryButtonVariant.outline,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
