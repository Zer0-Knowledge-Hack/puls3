import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';

/// The `method` stored on a CLI session's refresh token. The app's own
/// session is `wallet` (`WalletIdp.methodName`), so the two are separate
/// rows: revoking one leaves the other (#259).
const cliSessionMethod = 'cli';

/// How long a CLI session can refresh, counted from when it was created.
///
/// Absolute: refreshing does not extend it, unlike the global refresh
/// lifetime of `serverpod_auth_core`, which is an idle timeout (ADR-0007).
const cliSessionLifetime = Duration(hours: 72);

/// How many CLI sessions one wallet keeps. Creating one more revokes the
/// oldest, so the table cannot grow without bound.
const maxCliSessions = 5;

/// When a CLI session created at [createdAt] stops refreshing.
DateTime cliSessionExpiresAt(DateTime createdAt) =>
    createdAt.toUtc().add(cliSessionLifetime);

/// Whether a CLI session created at [createdAt] is past its lifetime at
/// [now]. The boundary itself is expired.
bool isCliSessionExpired(DateTime createdAt, DateTime now) =>
    !now.toUtc().isBefore(cliSessionExpiresAt(createdAt));

/// The refresh token id inside [refreshToken], or null when it is not a
/// `serverpod_auth_core` refresh token (`sajrt:<id>:<fixed>:<rotating>`).
///
/// Only the id is read: the secrets are left to the core, which checks them.
UuidValue? refreshTokenIdOf(String refreshToken) {
  final parts = refreshToken.split(':');
  if (parts.length != 4 || parts.first != 'sajrt') return null;
  try {
    return UuidValue.fromByteList(base64Decode(parts[1]));
  } on FormatException {
    return null;
  } on ArgumentError {
    return null;
  }
}

/// Refuses a CLI refresh token past [cliSessionLifetime] at [now]: deletes it
/// and throws [RefreshTokenExpiredException], as the core does for an idle
/// one. Any other token, or one the core will refuse anyway (malformed,
/// unknown), is left to the core.
Future<void> refuseExpiredCliSession(
  Session session,
  String refreshToken, {
  required Jwt jwt,
  required DateTime now,
}) async {
  final id = refreshTokenIdOf(refreshToken);
  if (id == null) return;
  final row = await RefreshToken.db.findById(session, id);
  if (row == null || row.method != cliSessionMethod) return;
  if (!isCliSessionExpired(row.createdAt, now)) return;
  await jwt.revokeRefreshToken(session, refreshTokenId: id);
  throw RefreshTokenExpiredException();
}
