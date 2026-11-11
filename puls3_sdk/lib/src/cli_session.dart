import 'dart:convert';
import 'dart:io';

import 'package:puls3_client/puls3_client.dart';

import 'puls3_sdk.dart' show normalizeApiUrl;

/// The environment variable a program seeds its CLI session with: the
/// refresh token the app shows once ("Copy session for CLI", #259).
const refreshTokenVariable = 'PULS3_REFRESH_TOKEN';

/// The environment variable that moves the session file.
const sessionFileVariable = 'PULS3_SESSION_FILE';

/// What one refresh returns: a new access token and the rotated refresh
/// token.
typedef RefreshedTokens = ({
  String accessToken,
  DateTime? accessTokenExpiresAt,
  String refreshToken,
});

/// Exchanges a refresh token for [RefreshedTokens]
/// (`JwtRefreshEndpoint.refreshAccessToken`).
///
/// A refused token (expired, revoked, reused) is a [SerializableException];
/// an unreachable server is a [ServerpodClientException] or an
/// [IOException].
typedef RefreshCall = Future<RefreshedTokens> Function(String refreshToken);

/// The session file of a program: `$PULS3_SESSION_FILE`, else
/// `%APPDATA%\puls3\session.json` on Windows, else
/// `$XDG_CONFIG_HOME/puls3/session.json`, else
/// `$HOME/.config/puls3/session.json`. Null when none of them is set.
String? defaultSessionFile(Map<String, String> environment) {
  String? set(String name) {
    final value = environment[name]?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  final explicit = set(sessionFileVariable);
  if (explicit != null) return explicit;
  final sep = Platform.pathSeparator;
  if (Platform.isWindows) {
    final appData = set('APPDATA');
    return appData == null ? null : '$appData${sep}puls3${sep}session.json';
  }
  final config = set('XDG_CONFIG_HOME');
  if (config != null) return '$config${sep}puls3${sep}session.json';
  final home = set('HOME');
  return home == null ? null : '$home$sep.config${sep}puls3${sep}session.json';
}

/// A wallet session for a program without the app (#259, ADR-0007 A′).
///
/// The app creates a separate CLI session for its wallet and shows the
/// refresh token once. The program seeds this session with it, through
/// [refreshTokenVariable] and never an argument (`docs/infra/secrets.md`).
/// Every refresh rotates the token, so the current one is kept in a file
/// only the user can read (mode 0600) and survives restarts. The session
/// stops refreshing 72 hours after the app created it; then copy a new one.
///
/// Pass it as the client's `authKeyProvider` (the SDK's `session`). It
/// never signs or submits a transaction, and no token appears in a
/// `toString`, an error or a log.
final class CliSession implements RefresherClientAuthKeyProvider {
  CliSession._(this._file, this._refresh, this._now, this._state);

  /// Opens the session for the server at [apiUrl]: the session file of
  /// [environment] (see [defaultSessionFile]) seeded from
  /// [refreshTokenVariable].
  ///
  /// Returns null when there is neither a seed nor a saved session.
  static Future<CliSession?> open(
    Uri apiUrl, {
    required Map<String, String> environment,
  }) async {
    final path = defaultSessionFile(environment);
    if (path == null) return null;
    final client = Client(normalizeApiUrl(apiUrl));
    return load(
      File(path),
      seed: environment[refreshTokenVariable],
      refresh: (token) async {
        final success = await client.jwtRefresh.refreshAccessToken(
          refreshToken: token,
        );
        final rotated = success.refreshToken;
        if (rotated == null) {
          throw StateError('The server returned no refresh token');
        }
        return (
          accessToken: success.token,
          accessTokenExpiresAt: success.tokenExpiresAt,
          refreshToken: rotated,
        );
      },
    );
  }

  /// The session saved in [file], or a new one from [seed].
  ///
  /// A [seed] that differs from the one the file was last seeded with
  /// replaces the saved session: that is how a program takes a newly copied
  /// session. Returns null when there is neither.
  static Future<CliSession?> load(
    File file, {
    String? seed,
    required RefreshCall refresh,
    DateTime Function()? now,
  }) async {
    final clock = now ?? () => DateTime.now().toUtc();
    final saved = await _read(file);
    final seeded = seed?.trim() ?? '';
    final _Stored state;
    if (seeded.isNotEmpty && seeded != saved?.seed) {
      state = _Stored(seed: seeded, refreshToken: seeded);
      await _write(file, state);
    } else if (saved != null) {
      state = saved;
    } else {
      return null;
    }
    return CliSession._(file, refresh, clock, state);
  }

  final File _file;
  final RefreshCall _refresh;
  final DateTime Function() _now;
  _Stored _state;

  /// An access token this close to its expiry is refreshed first.
  static const _margin = Duration(seconds: 30);

  /// Whether the session can still refresh. False once the server refused
  /// it: the file is removed and a new session must be copied from the app.
  bool get isUsable => _state.refreshToken.isNotEmpty;

  /// The refresh in flight. Two at once would present the same refresh
  /// token twice, and the server revokes a session whose token is reused.
  Future<RefreshAuthKeyResult>? _pending;

  /// The access token, refreshed first when there is none yet or it is about
  /// to expire.
  @override
  Future<String?> get authHeaderValue async {
    await refreshAuthKey();
    final token = _state.accessToken;
    return token == null ? null : wrapAsBearerAuthHeaderValue(token);
  }

  /// Refreshes the access token, one refresh at a time. Without [force], a
  /// token that is still valid is kept ([RefreshAuthKeyResult.skipped]).
  @override
  Future<RefreshAuthKeyResult> refreshAuthKey({bool force = false}) {
    final pending = _pending;
    if (pending != null) return pending;
    final next = _refreshOnce(force: force);
    _pending = next;
    return next.whenComplete(() => _pending = null);
  }

  Future<RefreshAuthKeyResult> _refreshOnce({required bool force}) async {
    if (!isUsable) return RefreshAuthKeyResult.failedUnauthorized;
    final expiresAt = _state.accessTokenExpiresAt;
    if (!force &&
        _state.accessToken != null &&
        expiresAt != null &&
        _now().add(_margin).isBefore(expiresAt)) {
      return RefreshAuthKeyResult.skipped;
    }
    final RefreshedTokens tokens;
    try {
      tokens = await _refresh(_state.refreshToken);
    } on SerializableException {
      // Expired, revoked, reused or unknown: this session is over.
      _state = _Stored(seed: _state.seed, refreshToken: '');
      if (await _file.exists()) await _file.delete();
      return RefreshAuthKeyResult.failedUnauthorized;
    } on ServerpodClientException {
      return RefreshAuthKeyResult.failedOther;
    } on IOException {
      return RefreshAuthKeyResult.failedOther;
    }
    _state = _Stored(
      seed: _state.seed,
      refreshToken: tokens.refreshToken,
      accessToken: tokens.accessToken,
      accessTokenExpiresAt: tokens.accessTokenExpiresAt?.toUtc(),
    );
    await _write(_file, _state);
    return RefreshAuthKeyResult.success;
  }

  @override
  String toString() => 'CliSession(${_file.path})';

  static Future<_Stored?> _read(File file) async {
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, Object?>) return null;
      final refreshToken = json['refreshToken'];
      final seed = json['seed'];
      if (refreshToken is! String || refreshToken.isEmpty || seed is! String) {
        return null;
      }
      final accessToken = json['accessToken'];
      final expiresAt = json['accessTokenExpiresAt'];
      return _Stored(
        seed: seed,
        refreshToken: refreshToken,
        accessToken: accessToken is String ? accessToken : null,
        accessTokenExpiresAt: expiresAt is String
            ? DateTime.tryParse(expiresAt)?.toUtc()
            : null,
      );
    } on FormatException {
      return null;
    }
  }

  /// Writes [state] to [file] with mode 0600: to a temporary file in the
  /// same directory made user-only before any secret is written, then
  /// renamed over [file].
  static Future<void> _write(File file, _Stored state) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString('');
    await _userOnly(temp.path);
    await temp.writeAsString(jsonEncode(state.toJson()), flush: true);
    await temp.rename(file.path);
  }

  /// `chmod 600`. Windows has no POSIX modes: the file is in the user's
  /// profile, which only that user can read.
  static Future<void> _userOnly(String path) async {
    if (Platform.isWindows) return;
    final result = await Process.run('chmod', ['600', path]);
    if (result.exitCode != 0) {
      throw FileSystemException('Could not make the session file private', path);
    }
  }
}

/// What the session file holds. [seed] is the token it was seeded with, so a
/// newly copied one is recognised.
final class _Stored {
  _Stored({
    required this.seed,
    required this.refreshToken,
    this.accessToken,
    this.accessTokenExpiresAt,
  });

  final String seed;
  final String refreshToken;
  final String? accessToken;
  final DateTime? accessTokenExpiresAt;

  Map<String, Object?> toJson() => {
    'seed': seed,
    'refreshToken': refreshToken,
    'accessToken': accessToken,
    'accessTokenExpiresAt': accessTokenExpiresAt?.toIso8601String(),
  };
}
