import 'package:flutter/foundation.dart';

/// One client review of an agent.
@immutable
class Review {
  const Review({
    required this.agentId,
    required this.author,
    required this.rating,
    required this.comment,
    required this.date,
    this.verifiedHire = true,
    this.mine = false,
  });

  final String agentId;
  final String author;

  /// 1 to 5 stars.
  final int rating;
  final String comment;
  final DateTime date;

  /// Left by a client who paid for a hire (ADR-0005: only paying clients
  /// can rate).
  final bool verifiedHire;

  /// Written from this device.
  final bool mine;
}

/// Average, count and how many reviews gave each star value.
@immutable
class RatingSummary {
  const RatingSummary({
    required this.average,
    required this.count,
    required this.byStars,
  });

  final double average;
  final int count;

  /// Index 0 is 1 star, index 4 is 5 stars.
  final List<int> byStars;
}

/// Why a review cannot be saved.
enum ReviewProblem { noStars, commentTooLong, notHired, alreadyRated }

/// In-memory reviews, seeded for the demo agents. Rating is open only to a
/// client who hired the agent, once per agent. A server store and the
/// on-chain Reputation Registry (#14) replace it later.
class ReviewStore extends ChangeNotifier {
  ReviewStore({List<Review>? seed, DateTime Function()? now})
    : _now = now ?? DateTime.now,
      _reviews = seed ?? _demoSeed((now ?? DateTime.now)());

  static const commentMax = 280;

  final DateTime Function() _now;
  final List<Review> _reviews;
  final Set<String> _hired = {};

  /// Newest first.
  List<Review> forAgent(String agentId) {
    final list = _reviews.where((r) => r.agentId == agentId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  RatingSummary summaryFor(String agentId) {
    final list = forAgent(agentId);
    final byStars = List.filled(5, 0);
    for (final r in list) {
      byStars[r.rating - 1]++;
    }
    final avg = list.isEmpty
        ? 0.0
        : list.map((r) => r.rating).reduce((a, b) => a + b) / list.length;
    return RatingSummary(average: avg, count: list.length, byStars: byStars);
  }

  /// Records a paid hire, which unlocks rating that agent.
  void markHired(String agentId) {
    _hired.add(agentId);
    notifyListeners();
  }

  bool hasRated(String agentId) =>
      _reviews.any((r) => r.agentId == agentId && r.mine);

  bool canRate(String agentId) =>
      _hired.contains(agentId) && !hasRated(agentId);

  static Set<ReviewProblem> validate({
    required int rating,
    required String comment,
  }) => {
    if (rating < 1 || rating > 5) ReviewProblem.noStars,
    if (comment.trim().length > commentMax) ReviewProblem.commentTooLong,
  };

  /// Saves my review of [agentId]. Throws [StateError] when rating is not
  /// allowed and [ArgumentError] when [validate] reports a problem.
  void add({
    required String agentId,
    required String author,
    required int rating,
    required String comment,
  }) {
    if (!_hired.contains(agentId)) throw StateError('notHired');
    if (hasRated(agentId)) throw StateError('alreadyRated');
    final problems = validate(rating: rating, comment: comment);
    if (problems.isNotEmpty) throw ArgumentError(problems);
    _reviews.add(
      Review(
        agentId: agentId,
        author: author,
        rating: rating,
        comment: comment.trim(),
        date: _now(),
        mine: true,
      ),
    );
    notifyListeners();
  }

  static List<Review> _demoSeed(DateTime now) {
    Review r(String id, String who, int stars, String text, int daysAgo) =>
        Review(
          agentId: id,
          author: who,
          rating: stars,
          comment: text,
          date: now.subtract(Duration(days: daysAgo)),
        );
    return [
      r('agt-001', 'María G.', 5, 'Clear daily summaries of my wallets.', 2),
      r('agt-001', 'Tom K.', 5, 'Caught a trustline change I missed.', 6),
      r('agt-001', 'Lucía P.', 4, 'Useful. Would like CSV export.', 12),
      r('agt-002', 'Diego R.', 5, 'Saved me fees on a payout to Mexico.', 3),
      r('agt-002', 'Ana S.', 4, 'Good routes, a bit slow on weekends.', 9),
      r(
        'agt-003',
        'Kenji O.',
        5,
        'Clear, fast audit with actionable fixes.',
        1,
      ),
      r('agt-003', 'Sara M.', 4, 'Found two real issues in my contract.', 8),
      r('agt-003', 'Leo V.', 3, 'Solid, but missed a TTL edge case.', 20),
    ];
  }
}
