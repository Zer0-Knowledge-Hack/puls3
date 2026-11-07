import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puls3_domain/puls3_domain.dart' show feedbackCommentMaxLength;

import '../../l10n/l10n.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/primary_button.dart';
import '../atoms/section_label.dart';
import '../molecules/score_picker.dart';

/// S10 rate sheet (flow F7): a score from 1 to 5 and an optional comment.
/// Presentational: the container signs and sends the rating. It never calls
/// the client.
class RateSheetView extends StatelessWidget {
  const RateSheetView({
    super.key,
    required this.agentName,
    required this.score,
    required this.commentController,
    required this.onScore,
    required this.onSend,
    required this.onClose,
    this.sending = false,
    this.error,
    this.isDemo = false,
  });

  final String agentName;

  /// Null until a score is picked: **Send rating** stays disabled.
  final int? score;
  final TextEditingController commentController;
  final ValueChanged<int> onScore;
  final VoidCallback onSend;
  final VoidCallback onClose;

  /// The wallet is signing, or the rating is being relayed.
  final bool sending;

  /// Why the last attempt failed. The sheet stays open.
  final String? error;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final error = this.error;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: commentController,
      builder: (context, comment, _) {
        // The same text and unit the server checks: the container sends the
        // trimmed comment, and the domain counts its UTF-16 code units.
        final length = comment.text.trim().length;
        final tooLong = length > feedbackCommentMaxLength;
        final canSend = score != null && !tooLong && !sending;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.rateTitle(agentName), style: Puls3Text.h3),
                ),
                IconButton(
                  key: const ValueKey('rate-close'),
                  tooltip: l10n.rateClose,
                  onPressed: sending ? null : onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: Puls3Spacing.md),
            SectionLabel(l10n.rateScore),
            const SizedBox(height: Puls3Spacing.xs),
            ScorePicker(score: score, onChanged: sending ? null : onScore),
            const SizedBox(height: Puls3Spacing.md),
            TextField(
              key: const ValueKey('rate-comment'),
              controller: commentController,
              enabled: !sending,
              minLines: 2,
              maxLines: 5,
              maxLength: feedbackCommentMaxLength,
              // Over the limit stays editable and shows the inline error.
              maxLengthEnforcement: MaxLengthEnforcement.none,
              buildCounter:
                  (
                    context, {
                    required currentLength,
                    required isFocused,
                    required maxLength,
                  }) => Text(
                    '$length/$feedbackCommentMaxLength',
                    key: const ValueKey('rate-comment-counter'),
                    style: Puls3Text.bodyMuted,
                  ),
              decoration: InputDecoration(
                hintText: l10n.rateCommentHint,
                errorText: tooLong
                    ? l10n.rateCommentTooLong(feedbackCommentMaxLength)
                    : null,
              ),
            ),
            if (isDemo) ...[
              const SizedBox(height: Puls3Spacing.xs),
              Text(
                l10n.rateDemo,
                key: const ValueKey('rate-demo'),
                style: Puls3Text.bodyMuted,
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: Puls3Spacing.sm),
              Text(
                error,
                key: const ValueKey('rate-error'),
                style: Puls3Text.bodyMuted.copyWith(
                  color: Puls3Colors.accent,
                ),
              ),
            ],
            const SizedBox(height: Puls3Spacing.md),
            PrimaryButton(
              key: const ValueKey('rate-send'),
              label: sending ? l10n.rateSending : l10n.rateSend,
              icon: Icons.star_rounded,
              expand: true,
              isLoading: sending,
              onPressed: canSend ? onSend : null,
            ),
          ],
        );
      },
    );
  }
}
