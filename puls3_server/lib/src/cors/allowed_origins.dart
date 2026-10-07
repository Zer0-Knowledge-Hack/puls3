import 'package:serverpod/serverpod.dart';

const _variableName = 'PULS3_ALLOWED_ORIGINS';

const _loopbackHosts = {'localhost', '127.0.0.1', '::1'};

/// The browser origins allowed to call the API server.
///
/// Loopback origins (`localhost`, `127.0.0.1` and `[::1]` on any port) are
/// always allowed, so the app runs against the server during development.
/// Any other origin must be listed in `PULS3_ALLOWED_ORIGINS`.
final class AllowedOrigins {
  AllowedOrigins._(this.configured);

  /// Reads `PULS3_ALLOWED_ORIGINS` from [env] (normally
  /// `Platform.environment`): a comma-separated list of origins such as
  /// `https://puls3-4lw.pages.dev`. Empty entries are skipped and a trailing
  /// slash is ignored. An entry that is not a bare `http(s)://host[:port]`
  /// origin throws an [ArgumentError].
  factory AllowedOrigins.fromEnvironment(Map<String, String> env) {
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
    return AllowedOrigins._(List.unmodifiable(configured));
  }

  /// The normalized origins read from `PULS3_ALLOWED_ORIGINS`.
  final List<String> configured;

  /// Whether a request whose `Origin` header is [origin] may call the server.
  bool allows(String origin) {
    final normalized = _normalize(origin);
    if (normalized == null) return false;
    return _loopbackHosts.contains(Uri.parse(normalized).host) ||
        configured.contains(normalized);
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

/// Middleware that lets only [allowed] browser origins call the API server.
///
/// A request without an `Origin` header (curl, server-to-server, platform
/// health probes) passes through. A request from an allowed origin passes
/// through, and its response echoes that origin in
/// `Access-Control-Allow-Origin` with `Vary: Origin`. A request from any other
/// origin gets `403` and never reaches an endpoint, which also stops "simple"
/// cross-origin POSTs that CORS alone would let run.
///
/// Preflight (`OPTIONS`) requests are passed on untouched: in Serverpod 3.4.13
/// the core header middleware answers them before any added middleware runs.
Middleware originGate(AllowedOrigins allowed) {
  return (next) => (req) async {
    if (req.method == Method.options) return next(req);

    final values = req.headers[Headers.originHeader];
    final origin = values == null || values.isEmpty ? null : values.first;
    if (origin == null) return next(req);

    if (!allowed.allows(origin)) {
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
