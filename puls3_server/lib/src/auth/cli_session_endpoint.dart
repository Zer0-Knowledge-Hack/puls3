import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';

import '../generated/protocol.dart';
import 'cli_session_policy.dart';
import 'wallet_idp.dart';

/// CLI sessions for the signed-in wallet (#259, ADR-0007 option A′).
///
/// A program without the app (the `puls3` CLI, the MCP server) cannot sign a
/// SEP-10 challenge. The signed-in app asks this endpoint for a separate
/// session of the same wallet and shows its refresh token once; the program
/// seeds its session with it (`PULS3_REFRESH_TOKEN`).
///
/// Every call acts on the caller's own auth user only: no argument names a
/// wallet or a user. A CLI session is its own refresh token row (method
/// [cliSessionMethod]), so revoking it leaves the app's session working and
/// the reverse. It refreshes for at most [cliSessionLifetime] from its
/// creation (`JwtRefreshEndpoint` enforces it).
class CliSessionEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Jwt get _jwt => AuthServices.getTokenManager<JwtTokenManager>().jwt;

  /// Replaces the clock that decides which CLI sessions have ended, for
  /// tests. `null` restores the system clock.
  static DateTime Function()? debugNow;

  DateTime get _now => debugNow?.call() ?? DateTime.now().toUtc();

  /// Creates a CLI session for the caller. If the caller already has
  /// [maxCliSessions] live ones, the oldest is revoked first.
  ///
  /// Only the app's own wallet session may call it: a CLI session, or an
  /// access token whose session was revoked, gets `CliSessionNotAllowed`.
  /// Otherwise a CLI session could mint the next one before its 72 hours
  /// end, and never expire.
  ///
  /// The refresh token in the result is a bearer secret: show it once, do
  /// not store or log it.
  Future<CliSessionGrant> create(Session session) async {
    final user = _caller(session);
    await _requireWalletSession(session, user);
    final existing = await _cliTokens(session, user);
    // Room for the new one: keep the newest maxCliSessions - 1.
    final excess = existing.length - (maxCliSessions - 1);
    for (final old in existing.take(excess < 0 ? 0 : excess)) {
      await _jwt.revokeRefreshToken(session, refreshTokenId: old.id);
    }
    final success = await _jwt.createTokens(
      session,
      authUserId: user,
      method: cliSessionMethod,
    );
    final refreshToken = success.refreshToken;
    final id = refreshToken == null ? null : refreshTokenIdOf(refreshToken);
    final row = id == null ? null : await RefreshToken.db.findById(session, id);
    if (refreshToken == null || id == null || row == null) {
      throw StateError('The token manager issued no refresh token');
    }
    return CliSessionGrant(
      id: id.uuid,
      refreshToken: refreshToken,
      expiresAt: cliSessionExpiresAt(row.createdAt),
    );
  }

  /// The caller's live CLI sessions, oldest first. No secret is returned.
  /// A session past its lifetime is not listed (it is deleted).
  Future<List<CliSession>> list(Session session) async => [
    for (final token in await _cliTokens(session, _caller(session)))
      CliSession(
        id: token.id.uuid,
        createdAt: token.createdAt.toUtc(),
        lastUsedAt: token.lastUpdatedAt.toUtc(),
        expiresAt: cliSessionExpiresAt(token.createdAt),
      ),
  ];

  /// Revokes the caller's CLI session [id]. Returns false when the caller
  /// has no CLI session with that id, including the app's own session and
  /// another wallet's: neither can be revoked here.
  Future<bool> revoke(Session session, String id) async {
    final tokens = await _cliTokens(session, _caller(session));
    for (final token in tokens) {
      if (token.id.uuid == id) {
        return _jwt.revokeRefreshToken(session, refreshTokenId: token.id);
      }
    }
    return false;
  }

  /// The caller's live CLI refresh tokens, oldest first. Those past
  /// [cliSessionLifetime] are deleted on the way: they can no longer
  /// refresh, so they are neither listed nor counted toward
  /// [maxCliSessions].
  Future<List<JwtTokenInfo>> _cliTokens(Session session, UuidValue user) async {
    final tokens = await _jwt.listJwtTokens(
      session,
      authUserId: user,
      method: cliSessionMethod,
    );
    final now = _now;
    final live = <JwtTokenInfo>[];
    for (final token in tokens) {
      if (isCliSessionExpired(token.createdAt, now)) {
        await _jwt.revokeRefreshToken(session, refreshTokenId: token.id);
      } else {
        live.add(token);
      }
    }
    return live..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Throws `CliSessionNotAllowed` unless the calling access token belongs
  /// to a live wallet sign-in session (method [WalletIdp.methodName]) of
  /// [user].
  static Future<void> _requireWalletSession(
    Session session,
    UuidValue user,
  ) async {
    final authId = session.authenticated?.authId;
    UuidValue? id;
    try {
      id = authId == null ? null : UuidValue.withValidation(authId);
    } on FormatException {
      id = null;
    }
    final row = id == null ? null : await RefreshToken.db.findById(session, id);
    if (row == null ||
        row.method != WalletIdp.methodName ||
        row.authUserId != user) {
      throw Puls3ApiException(code: 'CliSessionNotAllowed');
    }
  }

  static UuidValue _caller(Session session) {
    final userIdentifier = session.authenticated?.userIdentifier;
    if (userIdentifier == null) {
      throw NotAuthorizedException(
        reason: AuthenticationFailureReason.unauthenticated,
      );
    }
    return UuidValue.withValidation(userIdentifier);
  }
}
