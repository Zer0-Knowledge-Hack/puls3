import 'dart:async';
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
/// Several programs can share one session file (the CLI and the MCP server
/// do): a lock on `<file>.lock` makes each refresh read the newest token,
/// so none of them presents a token another already rotated, which the
/// server would treat as reuse and revoke.
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
    final seeded = seed?.trim() ?? '';
    final state = await _locked(file, () async {
      final saved = await _read(file);
      if (seeded.isNotEmpty && seeded != saved?.seed) {
        final fresh = _Stored(seed: seeded, refreshToken: seeded);
        await _write(file, fresh);
        return fresh;
      }
      return saved;
    });
    if (state == null) return null;
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

  bool get _accessValid {
    final expiresAt = _state.accessTokenExpiresAt;
    return _state.accessToken != null &&
        expiresAt != null &&
        _now().add(_margin).isBefore(expiresAt);
  }

  Future<RefreshAuthKeyResult> _refreshOnce({required bool force}) async {
    if (!isUsable) return RefreshAuthKeyResult.failedUnauthorized;
    if (!force && _accessValid) return RefreshAuthKeyResult.skipped;
    // Another program (the CLI and the MCP server share the file) may have
    // rotated the token since this one read it. The file lock makes
    // read, refresh and write one step across processes, so no two of them
    // ever present the same refresh token.
    return _locked(_file, () async {
      final saved = await _read(_file);
      if (saved == null) {
        // Another program found the session refused and removed the file.
        _state = _Stored(seed: _state.seed, refreshToken: '');
        return RefreshAuthKeyResult.failedUnauthorized;
      }
      if (saved.refreshToken != _state.refreshToken) {
        // Rotated elsewhere: take the newer tokens. Its access token is
        // usually still valid, so no refresh is needed.
        _state = saved;
        if (_accessValid) return RefreshAuthKeyResult.success;
      } else if (!force && _accessValid) {
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
    });
  }

  /// Runs [body] holding an exclusive lock on `<file>.lock`, shared by every
  /// program that uses the same session file. The lock file holds no
  /// secret.
  static Future<T> _locked<T>(File file, Future<T> Function() body) async {
    // File locks are held per process, so two sessions in this process are
    // also queued per path in memory.
    final path = file.absolute.path;
    final previous = _inProcess[path];
    final done = Completer<void>();
    _inProcess[path] = done;
    try {
      if (previous != null) await previous.future;
      await file.parent.create(recursive: true);
      final lock = await File('$path.lock').open(mode: FileMode.append);
      try {
        await lock.lock(FileLock.blockingExclusive);
        return await body();
      } finally {
        await lock.close();
      }
    } finally {
      done.complete();
      if (identical(_inProcess[path], done)) _inProcess.remove(path);
    }
  }

  /// The last queued holder of each session file's lock in this process.
  static final _inProcess = <String, Completer<void>>{};

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
