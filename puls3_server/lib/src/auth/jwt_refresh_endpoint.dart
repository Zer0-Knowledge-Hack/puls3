import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';

import 'cli_session_policy.dart';

/// By extending [RefreshJwtTokensEndpoint], the JWT token refresh endpoint
/// is made available on the server and enables automatic token refresh on the client.
///
/// A CLI session (#259) refreshes for at most [cliSessionLifetime] from its
/// creation: past it, its refresh token is deleted and the refresh fails
/// with [RefreshTokenExpiredException], however recently it was used. The
/// app's sessions keep the core's rules.
class JwtRefreshEndpoint extends RefreshJwtTokensEndpoint {
  /// Replaces the clock of the CLI lifetime check, for tests. `null` restores
  /// the system clock.
  static DateTime Function()? debugNow;

  /// Creates a new token pair for [refreshToken] and rotates it: the old one
  /// stops working.
  ///
  /// Fails with [RefreshTokenMalformedException], [RefreshTokenNotFoundException]
  /// (unknown or revoked), [RefreshTokenExpiredException] (idle for the core's
  /// refresh lifetime, or a CLI session past [cliSessionLifetime]) or
  /// [RefreshTokenInvalidSecretException] (a reused token: the session is
  /// revoked).
  ///
  /// This endpoint is unauthenticated, meaning the client won't include any
  /// authentication information with the call.
  @override
  @unauthenticatedClientCall
  Future<AuthSuccess> refreshAccessToken(
    Session session, {
    String? refreshToken,
  }) async {
    // A CLI program sends the token in the body; only the app's web build
    // uses the refresh cookie, and it never holds a CLI session.
    if (refreshToken != null) {
      await refuseExpiredCliSession(
        session,
        refreshToken,
        jwt: jwt,
        now: debugNow?.call() ?? DateTime.now().toUtc(),
      );
    }
    return super.refreshAccessToken(session, refreshToken: refreshToken);
  }
}
