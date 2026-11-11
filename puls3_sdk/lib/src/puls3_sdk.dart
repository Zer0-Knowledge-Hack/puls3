import 'package:puls3_client/puls3_client.dart';

import 'catalog.dart';
import 'session_calls.dart';

/// The puls3 API for Dart programs: the CLI, the MCP server and developers.
///
/// It reads and prepares; it never signs or submits a transaction. Server
/// errors reach the caller unchanged: `Puls3ApiException` codes, and
/// `AgentCatalogUnavailable` for a catalog outage (`docs/architecture/api.md`,
/// "Agent catalog").
///
/// The catalog needs no session. Hire and Studio calls act for a wallet, so
/// they need its session: without one they throw [SessionRequired] and send
/// nothing. A program gets a session from the app (A′ in
/// `docs/adr/0007-developer-sdk.md`, #259).
final class Puls3Sdk {
  Puls3Sdk._(this._catalog, this._hire, this._studio, this._close);

  /// An SDK for tests and other transports. Without [hire] or [studio], those
  /// calls throw [SessionRequired], as with no session.
  Puls3Sdk.withApi({
    required CatalogApi catalog,
    HireApi? hire,
    StudioApi? studio,
  }) : this._(catalog, hire, studio, () {});

  /// Connects to the puls3 server at [apiUrl], for example
  /// `https://puls3-hub-on-stellar.api.serverpod.space/`.
  ///
  /// [session] authenticates the hire and Studio calls as the wallet that
  /// owns it. Without it only the catalog works.
  ///
  /// Throws [ArgumentError] unless [apiUrl] is an absolute `http` or `https`
  /// URL.
  factory Puls3Sdk.connect(Uri apiUrl, {ClientAuthKeyProvider? session}) {
    final client = Client(normalizeApiUrl(apiUrl));
    if (session == null) {
      return Puls3Sdk._(ClientCatalogApi(client), null, null, client.close);
    }
    client.authKeyProvider = session;
    return Puls3Sdk._(
      ClientCatalogApi(client),
      ClientHireApi(client),
      ClientStudioApi(client),
      client.close,
    );
  }

  final CatalogApi _catalog;
  final HireApi? _hire;
  final StudioApi? _studio;
  final void Function() _close;

  /// Whether the hire and Studio calls have a session to use.
  bool get hasSession => _hire != null && _studio != null;

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

  /// Hire [hireId] of [consumer], the session wallet's address
  /// (`HireEndpoint.getHire`).
  ///
  /// Throws [ArgumentError] for an id below 1 or a blank [consumer], and
  /// [SessionRequired] without a session, without calling the server.
  Future<HireDetail> getHire(int hireId, String consumer) {
    _requireHireId(hireId);
    if (consumer.trim().isEmpty) {
      throw ArgumentError.value(consumer, 'consumer', 'must not be blank');
    }
    return _hireApi('getHire').get(hireId, consumer.trim());
  }

  /// The unsigned `complete` of hire [hireId], for the session wallet to
  /// sign (`HireEndpoint.prepareComplete`). The SDK does not sign or submit
  /// it.
  ///
  /// Throws [ArgumentError] for an id below 1, and [SessionRequired] without
  /// a session, without calling the server.
  Future<PreparedTransaction> prepareComplete(int hireId) {
    _requireHireId(hireId);
    return _hireApi('prepareComplete').prepareComplete(hireId);
  }

  /// The unsigned `reject` of hire [hireId] with [reason], for the session
  /// wallet to sign (`HireEndpoint.prepareReject`). The SDK does not sign or
  /// submit it.
  ///
  /// Throws [ArgumentError] for an id below 1 or a blank [reason], and
  /// [SessionRequired] without a session, without calling the server.
  Future<PreparedTransaction> prepareReject(int hireId, String reason) {
    _requireHireId(hireId);
    if (reason.trim().isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'must not be blank');
    }
    return _hireApi('prepareReject').prepareReject(hireId, reason);
  }

  /// Runs the session wallet's saved draft [draftId] once on [input], with
  /// the builder's own provider credential (`StudioEndpoint.testRun`). No hire
  /// and no payment.
  ///
  /// Throws [ArgumentError] for an id below 1 or a blank [input], and
  /// [SessionRequired] without a session, without calling the server.
  Future<TestRunResult> testRun(int draftId, String input) {
    if (draftId < 1) {
      throw ArgumentError.value(draftId, 'draftId', 'must be 1 or more');
    }
    if (input.trim().isEmpty) {
      throw ArgumentError.value(input, 'input', 'must not be blank');
    }
    final studio = _studio;
    if (studio == null) throw const SessionRequired('testRun');
    return studio.testRun(draftId, input);
  }

  /// Closes the connection. The SDK is unusable afterwards.
  void close() => _close();

  HireApi _hireApi(String operation) =>
      _hire ?? (throw SessionRequired(operation));

  static void _requireHireId(int hireId) {
    if (hireId < 1) {
      throw ArgumentError.value(hireId, 'hireId', 'must be 1 or more');
    }
  }
}

/// [apiUrl] as the generated client expects it: absolute, `http` or `https`,
/// with a path ending in `/`, and no query or fragment (the client appends
/// endpoint paths to it).
String normalizeApiUrl(Uri apiUrl) {
  if (!apiUrl.isAbsolute ||
      (apiUrl.scheme != 'http' && apiUrl.scheme != 'https') ||
      apiUrl.host.isEmpty ||
      apiUrl.hasQuery ||
      apiUrl.hasFragment) {
    throw ArgumentError.value(
      apiUrl.toString(),
      'apiUrl',
      'must be an absolute http or https URL with no query or fragment',
    );
  }
  final path = apiUrl.path.endsWith('/') ? apiUrl.path : '${apiUrl.path}/';
  return apiUrl.replace(path: path).toString();
}

/// [stroops] (7 decimals) as a USDC amount, with integer arithmetic only
/// (contract rule 1): at least 2 decimals, trailing zeros past them dropped.
/// `5000000` is `0.50`, `12345678` is `1.2345678`.
String formatUsdc(int stroops) {
  final sign = stroops < 0 ? '-' : '';
  final value = stroops.abs();
  final whole = value ~/ 10000000;
  var fraction = (value % 10000000).toString().padLeft(7, '0');
  while (fraction.length > 2 && fraction.endsWith('0')) {
    fraction = fraction.substring(0, fraction.length - 1);
  }
  return '$sign$whole.$fraction';
}
