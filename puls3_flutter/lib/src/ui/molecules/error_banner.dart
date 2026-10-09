import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';

/// A recoverable error with a Retry action (docs/blueprints/flows.md: "error
/// banner with Retry"). Purely presentational.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.retrying = false,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  /// Shows progress instead of the action while a retry runs.
  final bool retrying;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          Puls3Spacing.md,
          Puls3Spacing.sm,
          Puls3Spacing.xs,
          Puls3Spacing.sm,
        ),
        decoration: BoxDecoration(
          color: Puls3Colors.surface,
          borderRadius: Puls3Radius.mdAll,
          border: Border.all(color: Puls3Colors.accent),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 20,
              color: Puls3Colors.accent,
            ),
            const SizedBox(width: Puls3Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Puls3Text.body),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: Puls3Text.bodyMuted.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Puls3Spacing.xs),
            if (retrying)
              const Padding(
                padding: EdgeInsets.all(Puls3Spacing.sm),
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: TextButton.styleFrom(
                  foregroundColor: Puls3Colors.accent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
