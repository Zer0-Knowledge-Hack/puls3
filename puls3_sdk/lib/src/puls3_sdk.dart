import 'package:puls3_client/puls3_client.dart';

import 'catalog.dart';

/// The puls3 API for Dart programs: the CLI, the MCP server and developers.
///
/// It reads and prepares; it never signs or submits a transaction. Server
/// errors reach the caller unchanged: `Puls3ApiException` codes, and
/// `AgentCatalogUnavailable` for a catalog outage (`docs/architecture/api.md`,
/// "Agent catalog").
///
/// This first part covers the catalog, which needs no session. Hire and
/// Studio calls need a wallet session; how a program without the app gets one
/// is the open decision in `docs/adr/0007-developer-sdk.md`.
final class Puls3Sdk {
  Puls3Sdk._(this._catalog, this._close);

  /// An SDK for tests and other transports.
  Puls3Sdk.withApi({required CatalogApi catalog}) : this._(catalog, () {});

  /// Connects to the puls3 server at [apiUrl], for example
  /// `https://puls3-hub-on-stellar.api.serverpod.space/`.
  ///
  /// Throws [ArgumentError] unless [apiUrl] is an absolute `http` or `https`
  /// URL.
  factory Puls3Sdk.connect(Uri apiUrl) {
    final client = Client(normalizeApiUrl(apiUrl));
    return Puls3Sdk._(ClientCatalogApi(client), client.close);
  }

  final CatalogApi _catalog;
  final void Function() _close;

  /// Every agent in the catalog (`AgentEndpoint.list`).
  Future<List<AgentSummary>> listAgents() => _catalog.list();

  /// One agent by its metadata id, for example `agt-001`
  /// (`AgentEndpoint.get`). Returns null for an unknown id.
  ///
  /// Throws [ArgumentError] for a blank [id] without calling the server.
  Future<AgentSummary?> getAgent(String id) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be blank');
    }
    return _catalog.get(id);
  }

  /// Closes the connection. The SDK is unusable afterwards.
  void close() => _close();
}

/// [apiUrl] as the generated client expects it: absolute, `http` or `https`,
/// and ending in `/`.
String normalizeApiUrl(Uri apiUrl) {
  if (!apiUrl.isAbsolute ||
      (apiUrl.scheme != 'http' && apiUrl.scheme != 'https') ||
      apiUrl.host.isEmpty) {
    throw ArgumentError.value(
      apiUrl.toString(),
      'apiUrl',
      'must be an absolute http or https URL',
    );
  }
  final text = apiUrl.toString();
  return text.endsWith('/') ? text : '$text/';
}
