import 'dart:convert';

/// Server URL set at build time with `--dart-define=PULS3_API_URL=<url>` (or
/// `--dart-define-from-file`). Empty means "use `assets/config.json`".
///
/// The web build served by puls3_server gets its `config.json` from the
/// server itself, so it needs no override. Native and `flutter run` builds use
/// this to point at testnet without editing the bundled asset.
const String apiUrlOverride = String.fromEnvironment('PULS3_API_URL');

/// Returns the Serverpod API URL: [override] when it is not blank, otherwise
/// the `apiUrl` field of [configJson] (the bundled `assets/config.json`).
/// The wallet sign-in values the server publishes in `config.json` `auth`
/// (#136): its public signing key and home domain. The bundled config of a
/// static build (Cloudflare Pages) has no `auth`, so both may be null.
({String? serverSigningKey, String? homeDomain}) readAuthConfig(
  String configJson,
) {
  final config = jsonDecode(configJson);
  final auth = config is Map<String, dynamic> ? config['auth'] : null;
  String? text(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
  return auth is Map<String, dynamic>
      ? (
          serverSigningKey: text(auth['serverSigningKey']),
          homeDomain: text(auth['homeDomain']),
        )
      : (serverSigningKey: null, homeDomain: null);
}

String resolveApiUrl(String configJson, {String override = apiUrlOverride}) {
  final trimmed = override.trim();
  if (trimmed.isNotEmpty) return trimmed;
  final config = jsonDecode(configJson) as Map<String, dynamic>;
  final apiUrl = config['apiUrl'];
  if (apiUrl is String && apiUrl.isNotEmpty) return apiUrl;
  throw StateError(
    'No server URL: set apiUrl in assets/config.json or build with '
    '--dart-define=PULS3_API_URL=<url>.',
  );
}
