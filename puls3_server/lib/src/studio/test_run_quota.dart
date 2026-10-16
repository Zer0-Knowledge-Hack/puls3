import 'studio_test_errors.dart';

/// Free test runs per builder per UTC day (ADR-0004 decision 6, spike #33).
const studioDailyTestRuns = 20;

/// Counts test runs. A reservation is spent even when the model then fails,
/// because the builder's provider may already have been called.
abstract interface class TestRunQuota {
  /// Reserves one run for [owner] on the UTC day of [now] and returns how
  /// many remain afterwards. Throws [StudioTestQuotaExceeded] when the day
  /// is already full.
  Future<int> reserve({required String owner, required DateTime now});
}

/// In-memory [TestRunQuota]. One server process shares one instance.
final class MemoryTestRunQuota implements TestRunQuota {
  final Map<String, int> _used = {};

  @override
  Future<int> reserve({required String owner, required DateTime now}) async {
    final utc = now.toUtc();
    final key = '$owner|${utc.year}-${utc.month}-${utc.day}';
    final used = _used[key] ?? 0;
    if (used >= studioDailyTestRuns) {
      throw StudioTestQuotaExceeded(
        DateTime.utc(utc.year, utc.month, utc.day + 1),
      );
    }
    _used[key] = used + 1;
    return studioDailyTestRuns - used - 1;
  }
}
