import 'package:flutter/foundation.dart';

import '../domain/agent.dart';
import 'agent_repository.dart';

/// Serves the [primary] catalog and uses [fallback] when the primary fails.
///
/// Any thrown error triggers the fallback, including timeouts. A primary that
/// succeeds with an empty list is a valid answer and is returned as is.
class FallbackAgentRepository implements AgentRepository {
  const FallbackAgentRepository(this.primary, this.fallback);

  final AgentRepository primary;
  final AgentRepository fallback;

  @override
  Future<List<Agent>> fetchAgents() async {
    try {
      return await primary.fetchAgents();
    } catch (e) {
      debugPrint('Agent catalog: primary failed, using fallback: $e');
      return fallback.fetchAgents();
    }
  }
}
