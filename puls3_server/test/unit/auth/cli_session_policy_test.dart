import 'dart:convert';
import 'dart:typed_data';

import 'package:puls3_server/src/auth/cli_session_policy.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

void main() {
  group('isCliSessionExpired', () {
    final created = DateTime.utc(2026, 11, 11, 12);

    test('refreshes until 72 hours after creation', () {
      expect(isCliSessionExpired(created, created), isFalse);
      expect(
        isCliSessionExpired(
          created,
          created.add(const Duration(hours: 71, minutes: 59, seconds: 59)),
        ),
        isFalse,
      );
    });

    test('the 72-hour mark itself is expired, and everything after', () {
      expect(
        isCliSessionExpired(created, created.add(cliSessionLifetime)),
        isTrue,
      );
      expect(
        isCliSessionExpired(created, created.add(const Duration(days: 30))),
        isTrue,
      );
    });

    test('compares instants, whatever the time zone', () {
      final local = created.toLocal();
      expect(
        isCliSessionExpired(local, created.add(cliSessionLifetime)),
        isTrue,
      );
      expect(cliSessionExpiresAt(local), created.add(cliSessionLifetime));
    });
  });

  group('refreshTokenIdOf', () {
    final id = UuidValue.withValidation('0f5b3a1e-6c2d-4f7a-9b8e-1d2c3b4a5f60');
    final idPart = base64Encode(id.toBytes());
    final secret = base64Encode(Uint8List(8));

    test('reads the id of a core refresh token', () {
      expect(refreshTokenIdOf('sajrt:$idPart:$secret:$secret'), id);
    });

    test('anything else is null, never a throw', () {
      for (final token in [
        '',
        'sajrt',
        'sajrt:$idPart:$secret',
        'other:$idPart:$secret:$secret',
        'sajrt:not base64!:$secret:$secret',
        'sajrt:${base64Encode([1, 2, 3])}:$secret:$secret',
      ]) {
        expect(refreshTokenIdOf(token), isNull, reason: token);
      }
    });
  });
}
