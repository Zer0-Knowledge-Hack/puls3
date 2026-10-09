import 'package:serverpod/serverpod.dart';

const _variableName = 'PULS3_ALLOWED_ORIGINS';

const _developmentRunMode = 'development';

const _loopbackHosts = {'localhost', '127.0.0.1', '::1'};

/// The browser origins allowed to call the API server.
///
/// In the `development` run mode, loopback origins (`localhost`, `127.0.0.1`
/// and `[::1]` on any port) are allowed, so the app runs against a local
/// server. In every other run mode (production, staging, test) only the
/// origins listed in `PULS3_ALLOWED_ORIGINS` are allowed.
final class AllowedOrigins {
  AllowedOrigins._(this.configured, {required this.allowsLoopback});

  /// Reads `PULS3_ALLOWED_ORIGINS` from [env] (normally
  /// `Platform.environment`): a comma-separated list of origins such as
  /// `https://puls3-4lw.pages.dev`. Empty entries are skipped and a trailing
  /// slash is ignored. An entry that is not a bare `http(s)://host[:port]`
  /// origin throws an [ArgumentError]. [runMode] is the Serverpod run mode.
  factory AllowedOrigins.fromEnvironment(
    Map<String, String> env, {
    required String runMode,
  }) {
    final raw = env[_variableName] ?? '';
    final configured = <String>[];
    for (final entry in raw.split(',')) {
      final value = entry.trim();
      if (value.isEmpty) continue;
      final origin = _normalize(value);
      if (origin == null) {
        throw ArgumentError.value(
          value,
          _variableName,
          'must be a comma-separated list of http(s)://host[:port] origins',
        );
      }
      if (!configured.contains(origin)) configured.add(origin);
    }
    return AllowedOrigins._(
      List.unmodifiable(configured),
      allowsLoopback: runMode == _developmentRunMode,
    );
  }

  /// The normalized origins read from `PULS3_ALLOWED_ORIGINS`.
  final List<String> configured;

  /// Whether any loopback origin is allowed (development run mode only).
  final bool allowsLoopback;

  /// Whether a request whose `Origin` header is [origin] may call the server.
  bool allows(String origin) {
    final normalized = _normalize(origin);
    if (normalized == null) return false;
    if (configured.contains(normalized)) return true;
    return allowsLoopback &&
        _loopbackHosts.contains(Uri.parse(normalized).host);
  }

  /// Returns `scheme://host[:port]` in lower case without a default port, or
  /// `null` when [value] is not a bare http(s) origin.
  static String? _normalize(String value) {
    final Uri uri;
    try {
      uri = Uri.parse(value);
    } on FormatException {
      return null;
    }
    final isHttp = uri.scheme == 'http' || uri.scheme == 'https';
    final isBare =
        (uri.path.isEmpty || uri.path == '/') &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        uri.userInfo.isEmpty;
    if (!isHttp || uri.host.isEmpty || !isBare) return null;
    return uri.origin;
  }
}

/// Builds the [originGate] that `server.dart` installs on the API server,
/// from `PULS3_ALLOWED_ORIGINS` in [env] and the Serverpod [runMode], and
/// reports the policy through [log]. An invalid list throws an
/// [ArgumentError], so a misconfigured server does not start.
Middleware originGateFromEnvironment(
  Map<String, String> env, {
  required String runMode,
  required void Function(String message) log,
}) {
  final allowed = AllowedOrigins.fromEnvironment(env, runMode: runMode);
  final loopback = allowed.allowsLoopback
      ? 'loopback allowed'
      : 'loopback not allowed';
  log(
    'Allowed browser origins: ${allowed.configured} '
    '($loopback, run mode $runMode)',
  );
  return originGate(allowed);
}

/// Middleware that lets only [allowed] browser origins call the API server.
///
/// A request without an `Origin` header (curl, server-to-server, platform
/// health probes) passes through. A request from an allowed origin passes
/// through, and its response echoes that origin in
/// `Access-Control-Allow-Origin` with `Vary: Origin`. A request from any other
/// origin, or with several `Origin` headers, gets `403` and never reaches an
/// endpoint, which also stops "simple" cross-origin POSTs that CORS alone would
/// let run.
///
/// Preflight (`OPTIONS`) requests are passed on untouched: in Serverpod 4.0.4
/// the core header middleware answers them before any added middleware runs.
Middleware originGate(AllowedOrigins allowed) {
  return (next) => (req) async {
    if (req.method == Method.options) return next(req);

    final values = req.headers[Headers.originHeader];
    if (values == null || values.isEmpty) return next(req);

    // Browsers send exactly one origin; anything else is not a browser call
    // this server should answer.
    final origin = values.length == 1 ? values.single : null;
    if (origin == null || !allowed.allows(origin)) {
      return Response.forbidden(body: Body.fromString('Origin not allowed'));
    }

    final result = await next(req);
    if (result is! Response) return result;
    return result.copyWith(
      headers: result.headers.transform((mh) {
        mh['access-control-allow-origin'] = [origin];
        final vary = mh['vary'] ?? const <String>[];
        final variesOnOrigin = vary
            .expand((value) => value.split(','))
            .any((field) => field.trim().toLowerCase() == 'origin');
        if (!variesOnOrigin) mh['vary'] = [...vary, 'Origin'];
      }),
    );
  };
}
