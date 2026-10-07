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
