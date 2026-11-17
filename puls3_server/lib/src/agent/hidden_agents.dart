/// The environment variable that lists the registry ids puls3 hides.
const hiddenAgentIdsKey = 'PULS3_HIDDEN_AGENT_IDS';

/// The agents maintainers chose not to show (moderation, phase 1).
///
/// The identity registry has no delete and anyone can register, so the
/// indexer lists every agent on chain. This list lets puls3 stop showing and
/// selling one without touching the chain: the catalog drops it, a new hire
/// is refused and its registration file is not served. Jobs already funded
/// are not affected; they settle or refund as usual.
final class HiddenAgents {
  const HiddenAgents._(this.ids);

  /// Hides nothing: the behavior while the variable is unset.
  static const none = HiddenAgents._({});

  /// Reads [hiddenAgentIdsKey] from [environment]: comma-separated
  /// non-negative registry ids, whitespace tolerated, empty entries ignored.
  /// Unset or blank hides nothing.
  ///
  /// A malformed entry is an [ArgumentError] naming the variable and that
  /// entry only, so a typo fails loudly instead of silently showing an agent
  /// that was meant to be hidden.
  factory HiddenAgents.fromEnvironment(Map<String, String> environment) {
    final raw = environment[hiddenAgentIdsKey];
    if (raw == null || raw.trim().isEmpty) return none;
    final ids = <int>{};
    for (final entry in raw.split(',')) {
      final token = entry.trim();
      if (token.isEmpty) continue;
      // Digits only: int.tryParse would also accept "+3" and "-0".
      final id = RegExp(r'^\d+$').hasMatch(token) ? int.tryParse(token) : null;
      if (id == null) {
        throw ArgumentError.value(
          token,
          hiddenAgentIdsKey,
          'must be comma-separated non-negative registry ids',
        );
      }
      ids.add(id);
    }
    return HiddenAgents._(Set.unmodifiable(ids));
  }

  /// The hidden registry ids.
  final Set<int> ids;

  /// Whether the agent with [registryId] is hidden. An agent with no
  /// registry id is never hidden.
  bool contains(int? registryId) =>
      registryId != null && ids.contains(registryId);
}
