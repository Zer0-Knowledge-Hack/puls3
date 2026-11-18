/// Free-model (`workers-ai`) hire runs per agent per UTC day on the platform
/// account (#318). A paid-provider run uses the builder's own key and is not
/// counted.
const teamDailyHireRunsPerAgent = 10;

/// Counts the hires that run on the platform's Workers AI account.
///
/// The platform pays for free-model inference, so one agent must not be able
/// to spend an unbounded amount through a loop of paid hires.
abstract interface class TeamRunQuota {
  /// Reserves one run for [agentId] on the UTC day of [now]. Returns false
  /// when the agent's day is full.
  bool reserve({required int agentId, required DateTime now});
}

/// In-memory [TeamRunQuota]. One server process shares one instance; a
/// restart clears it, like the Studio test-run quotas.
final class MemoryTeamRunQuota implements TeamRunQuota {
  final Map<String, int> _used = {};

  @override
  bool reserve({required int agentId, required DateTime now}) {
    final utc = now.toUtc();
    final key = '$agentId|${utc.year}-${utc.month}-${utc.day}';
    final used = _used[key] ?? 0;
    if (used >= teamDailyHireRunsPerAgent) return false;
    _used[key] = used + 1;
    return true;
  }
}
