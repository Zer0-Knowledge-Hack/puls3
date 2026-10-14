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
/// The wallet sign-in values pinned at build time (#136), for builds whose
/// `config.json` has no `auth` (Cloudflare Pages). Empty means "use
/// `assets/config.json`". All three are public: the server key is a `G…`
/// account address, never a secret.
const Map<String, String> authConfigOverrides = {
  'serverSigningKey': String.fromEnvironment('PULS3_AUTH_SERVER_SIGNING_KEY'),
  'homeDomain': String.fromEnvironment('PULS3_AUTH_HOME_DOMAIN'),
  'webAuthDomain': String.fromEnvironment('PULS3_AUTH_WEB_AUTH_DOMAIN'),
};

/// The wallet sign-in values the server publishes in `config.json` `auth`
/// (#136): its public signing key, its home domain and its
/// `web_auth_domain`. A non-blank entry of [overrides] wins over the file.
/// The bundled config of a static build (Cloudflare Pages) has no `auth`, so
/// each one is null unless the build pins it.
({String? serverSigningKey, String? homeDomain, String? webAuthDomain})
readAuthConfig(
  String configJson, {
  Map<String, String> overrides = authConfigOverrides,
}) {
  final config = jsonDecode(configJson);
  final auth = config is Map<String, dynamic> ? config['auth'] : null;
  final block = auth is Map<String, dynamic> ? auth : const {};
  String? read(String field) {
    final override = overrides[field]?.trim() ?? '';
    if (override.isNotEmpty) return override;
    final value = block[field];
    return value is String && value.isNotEmpty ? value : null;
  }

  return (
    serverSigningKey: read('serverSigningKey'),
    homeDomain: read('homeDomain'),
    webAuthDomain: read('webAuthDomain'),
  );
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
