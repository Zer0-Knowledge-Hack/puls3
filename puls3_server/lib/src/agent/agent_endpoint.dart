import 'package:meta/meta.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'agent_catalog_wiring.dart';
import 'catalog_reader.dart';

/// Serves the agent catalog from the Postgres index, with an on-chain
/// fallback while the index is empty.
///
/// The endpoint depends only on [CatalogReader]; every chain detail lives in
/// [buildAgentCatalogReader] and the services behind it. When the chain is
/// unreachable and nothing is indexed, `list` and `get` may throw
/// [AgentCatalogUnavailable] through the fallback instead of answering with
/// an empty catalog.
class AgentEndpoint extends Endpoint {
  /// Builds the default reader from a [Session]. Replaceable for tests.
  @visibleForTesting
  static CatalogReader Function(Session session) defaultServiceBuilder =
      buildAgentCatalogReader;

  static CatalogReader? _service;

  /// Replaces the reader, for tests. `null` restores the default builder.
  @visibleForTesting
  static set service(CatalogReader? service) => _service = service;

  CatalogReader _reader(Session session) =>
      _service ?? defaultServiceBuilder(session);

  /// Every agent in the catalog, ordered by registry id.
  Future<List<AgentSummary>> list(Session session) => _reader(session).list();

  /// The agent with metadata id [id], or `null` when there is none.
  Future<AgentSummary?> get(Session session, String id) =>
      _reader(session).get(id);
}
