import 'package:flutter/material.dart';

import '../../state/review_store.dart';
import '../../theme/puls3_theme.dart';

/// Stars for a 0–5 value, with half stars.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.value, this.size = 14});

  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              value >= i
                  ? Icons.star_rounded
                  : value >= i - 0.5
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded,
              size: size,
              color: Puls3Colors.accent,
            ),
        ],
      ),
    );
  }
}

/// "Ratings & reviews": average, distribution and the latest reviews, plus
/// a Rate button when the user may rate.
class ReviewsSection extends StatefulWidget {
  const ReviewsSection({
    super.key,
    required this.summary,
    required this.reviews,
    this.onRate,
  });

  final RatingSummary summary;
  final List<Review> reviews;

  /// Null when the user cannot rate (no paid hire, or already rated).
  final VoidCallback? onRate;

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  static const _preview = 3;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final shown = _all ? widget.reviews : widget.reviews.take(_preview);
    return Column(
      key: const ValueKey('reviews-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(Puls3Spacing.sm),
          decoration: BoxDecoration(
            color: Puls3Colors.surface,
            borderRadius: Puls3Radius.mdAll,
            border: Border.all(color: Puls3Colors.hairline),
          ),
          child: s.count == 0
              ? Row(
                  children: [
                    const Icon(
                      Icons.reviews_outlined,
                      color: Puls3Colors.muted,
                    ),
                    const SizedBox(width: Puls3Spacing.sm),
                    Expanded(
                      child: Text(
                        'No reviews yet. Clients can rate after a paid hire.',
                        style: Puls3Text.bodyMuted.copyWith(fontSize: 13),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Semantics(
                      label:
                          'Rated ${s.average.toStringAsFixed(1)} of 5 from '
                          '${s.count} reviews',
                      excludeSemantics: true,
                      child: Column(
                        children: [
                          Text(
                            s.average.toStringAsFixed(1),
                            style: Puls3Text.h3.copyWith(fontSize: 28),
                          ),
                          StarRow(value: s.average),
                          const SizedBox(height: 2),
                          Text(
                            '${s.count} ${s.count == 1 ? 'review' : 'reviews'}',
                            style: Puls3Text.bodyMuted.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Puls3Spacing.md),
                    Expanded(
                      child: Column(
                        children: [
                          for (var star = 5; star >= 1; star--)
                            _DistributionBar(
                              star: star,
                              count: s.byStars[star - 1],
                              total: s.count,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        if (widget.onRate != null) ...[
          const SizedBox(height: Puls3Spacing.sm),
          OutlinedButton.icon(
            onPressed: widget.onRate,
            icon: const Icon(Icons.star_outline_rounded, size: 18),
            label: const Text('Rate this agent'),
          ),
        ],
        for (final review in shown) _ReviewTile(review: review),
        if (widget.reviews.length > _preview)
          TextButton(
            onPressed: () => setState(() => _all = !_all),
            child: Text(
              _all ? 'Show less' : 'Show all ${widget.reviews.length} reviews',
            ),
          ),
      ],
    );
  }
}

class _DistributionBar extends StatelessWidget {
  const _DistributionBar({
    required this.star,
    required this.count,
    required this.total,
  });

  final int star;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            child: Text(
              '$star',
              style: Puls3Text.bodyMuted.copyWith(fontSize: 11),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: Puls3Radius.pillAll,
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : count / total,
                minHeight: 6,
                color: Puls3Colors.accent,
                backgroundColor: Puls3Colors.hairline,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 16,
            child: Text(
              '$count',
              textAlign: TextAlign.end,
              style: Puls3Text.bodyMuted.copyWith(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final days = DateTime.now().difference(review.date).inDays;
    final when = days == 0
        ? 'today'
        : days == 1
        ? 'yesterday'
        : '$days days ago';
    return Padding(
      padding: const EdgeInsets.only(top: Puls3Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: Puls3Colors.hairline,
                child: Text(
                  review.author.characters.first,
                  style: Puls3Text.caption.copyWith(fontSize: 11),
                ),
              ),
              const SizedBox(width: Puls3Spacing.xs),
              Flexible(
                child: Text(
                  review.mine ? '${review.author} (you)' : review.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Puls3Text.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (review.verifiedHire) ...[
                const SizedBox(width: 4),
                const Tooltip(
                  message: 'Verified hire',
                  child: Icon(
                    Icons.verified_rounded,
                    size: 14,
                    color: Puls3Colors.success,
                  ),
                ),
              ],
              const Spacer(),
              Text(when, style: Puls3Text.bodyMuted.copyWith(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 2),
          StarRow(value: review.rating.toDouble(), size: 12),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              review.comment,
              style: Puls3Text.body.copyWith(fontSize: 13, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sheet to rate an agent: 1–5 stars (required) and an optional comment.
Future<void> showRateSheet(
  BuildContext context, {
  required String agentName,
  required void Function(int rating, String comment) onSubmit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: _RateForm(agentName: agentName, onSubmit: onSubmit),
    ),
  );
}

class _RateForm extends StatefulWidget {
  const _RateForm({required this.agentName, required this.onSubmit});

  final String agentName;
  final void Function(int rating, String comment) onSubmit;

  @override
  State<_RateForm> createState() => _RateFormState();
}

class _RateFormState extends State<_RateForm> {
  final _comment = TextEditingController();
  int _rating = 0;
  bool _attempted = false;

  static const _labels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _submit() {
    final problems = ReviewStore.validate(
      rating: _rating,
      comment: _comment.text,
    );
    if (problems.isNotEmpty) {
      setState(() => _attempted = true);
      return;
    }
    widget.onSubmit(_rating, _comment.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final missingStars = _attempted && _rating == 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Puls3Spacing.md,
        0,
        Puls3Spacing.md,
        Puls3Spacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Rate ${widget.agentName}',
            style: Puls3Text.title.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 2),
          Text(
            'Your review is public and marked as a verified hire.',
            style: Puls3Text.bodyMuted.copyWith(fontSize: 13),
          ),
          const SizedBox(height: Puls3Spacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i star${i == 1 ? '' : 's'}',
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(
                    i <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 32,
                    color: missingStars
                        ? Puls3Colors.muted
                        : Puls3Colors.accent,
                  ),
                ),
            ],
          ),
          Text(
            missingStars ? 'Choose 1 to 5 stars' : _labels[_rating],
            textAlign: TextAlign.center,
            style: Puls3Text.body.copyWith(
              fontSize: 13,
              color: missingStars ? Puls3Colors.accent : Puls3Colors.muted,
            ),
          ),
          const SizedBox(height: Puls3Spacing.sm),
          TextField(
            key: const Key('review-comment'),
            controller: _comment,
            minLines: 2,
            maxLines: 4,
            maxLength: ReviewStore.commentMax,
            decoration: const InputDecoration(
              labelText: 'Comment (optional)',
              hintText: 'What went well? What could improve?',
            ),
          ),
          const SizedBox(height: Puls3Spacing.sm),
          FilledButton(onPressed: _submit, child: const Text('Submit review')),
        ],
      ),
    );
  }
}
