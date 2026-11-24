import 'package:puls3_server/src/runtime/team_run_quota.dart';
import 'package:test/test.dart';

void main() {
  test('allows the daily team runs per agent and refuses the next one', () {
    final quota = MemoryTeamRunQuota();
    final now = DateTime.utc(2026, 11, 19, 12);

    for (var i = 0; i < teamDailyHireRunsPerAgent; i++) {
      expect(quota.reserve(agentId: 7, now: now), isTrue, reason: 'run $i');
    }

    expect(quota.reserve(agentId: 7, now: now), isFalse);
    expect(quota.reserve(agentId: 8, now: now), isTrue);
    expect(
      quota.reserve(agentId: 7, now: now.add(const Duration(days: 1))),
      isTrue,
    );
  });

  test('counts the UTC day, not the local one', () {
    final quota = MemoryTeamRunQuota();
    final lateLocal = DateTime.utc(2026, 11, 19, 23, 59);

    for (var i = 0; i < teamDailyHireRunsPerAgent; i++) {
      quota.reserve(agentId: 7, now: lateLocal);
    }
    expect(quota.reserve(agentId: 7, now: lateLocal), isFalse);
    expect(
      quota.reserve(agentId: 7, now: DateTime.utc(2026, 11, 20, 0, 1)),
      isTrue,
    );
  });
}
