import 'package:puls3_client/puls3_client.dart';

import '../domain/agent.dart';
import '../domain/skill_display_name.dart';
import 'agent_repository.dart';

/// Fetches the catalog summaries, typically `() => client.agent.list()`.
typedef AgentSummarySource = Future<List<AgentSummary>> Function();

/// Lists the agents served by the server catalog.
///
/// Errors from the source, including the timeout, propagate to the caller;
/// pair it with a fallback repository to stay usable offline.
class ServerAgentRepository implements AgentRepository {
  ServerAgentRepository(this._source, {this.timeout = defaultTimeout});

  /// Mirrors the Serverpod client's own default connection timeout.
  static const defaultTimeout = Duration(seconds: 20);

  final AgentSummarySource _source;

  /// Upper bound for the server call. It does not cancel the HTTP request,
  /// it only stops waiting for it.
  final Duration timeout;

  @override
  Future<List<Agent>> fetchAgents() async {
    final summaries = await _source().timeout(timeout);
    return List<Agent>.unmodifiable(
      summaries.map(fromSummary).whereType<Agent>(),
    );
  }

  /// Maps a summary to an [Agent], or returns null when it has no wallet.
  ///
  /// An agent without a wallet cannot be paid, so it is dropped instead of
  /// listed with a placeholder address.
  static Agent? fromSummary(AgentSummary s) {
    final wallet = s.wallet;
    if (wallet == null || wallet.isEmpty) return null;
    final model = s.model;
    return Agent(
      id: s.id,
      name: s.name,
      description: s.description,
      skills: List<String>.unmodifiable(s.skills.map(skillDisplayName)),
      priceUsdcStroops: s.priceUsdcStroops,
      // The catalog carries no reviews yet; 0.0 makes the badge hide itself.
      rating: 0.0,
      stellarAddress: wallet,
      model: model == null || model.isEmpty ? 'Unspecified' : model,
    );
  }
}
