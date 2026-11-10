import 'package:puls3_client/puls3_client.dart';

/// The catalog calls the SDK makes. [Puls3Sdk.connect] backs it with the
/// generated Serverpod client; tests pass a fake.
abstract interface class CatalogApi {
  /// Every agent in the catalog. Raises [AgentCatalogUnavailable] on an
  /// outage, never an empty list.
  Future<List<AgentSummary>> list();

  /// One agent by its metadata id, or null for an unknown id.
  Future<AgentSummary?> get(String id);
}

/// [CatalogApi] over `AgentEndpoint` of the generated client.
final class ClientCatalogApi implements CatalogApi {
  ClientCatalogApi(this._client);

  final Client _client;

  @override
  Future<List<AgentSummary>> list() => _client.agent.list();

  @override
  Future<AgentSummary?> get(String id) => _client.agent.get(id);
}
