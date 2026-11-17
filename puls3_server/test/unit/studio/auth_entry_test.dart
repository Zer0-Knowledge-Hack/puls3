import 'dart:convert';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/ledger/strkey.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart';
import 'package:puls3_server/src/studio/auth_entry.dart';
import 'package:test/test.dart';

const _account = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';

void main() {
  final account = StellarAddress.parse(_account);

  group('withExpirationLedger', () {
    test('sets the expiration of an account address entry', () {
      final entry = _accountEntry(account, expiration: 0);

      final rewritten = withExpirationLedger(entry, 123456);

      final view = readAuthEntry(rewritten);
      expect(view.expirationLedger, 123456);
      expect(view.covers(account), isTrue);
      expect(view.nonce, 9);
      expect(_withoutExpiration(rewritten, 52), _withoutExpiration(entry, 52));
    });

    test('sets the expiration of a contract address entry', () {
      final entry = _contractEntry(expiration: 0);

      final rewritten = withExpirationLedger(entry, 0xFFFFFFFF);

      final view = readAuthEntry(rewritten);
      expect(view.expirationLedger, 0xFFFFFFFF);
      expect(view.nonce, 9);
      expect(_withoutExpiration(rewritten, 48), _withoutExpiration(entry, 48));
    });

    test('keeps a prepared entry comparable to its signed form', () {
      final prepared = withExpirationLedger(
        _accountEntry(account, expiration: 0),
        500,
      );
      final signed = withExpirationLedger(
        _accountEntry(account, expiration: 0, signature: 3),
        500,
      );

      expect(
        sameAuthorization(readAuthEntry(prepared), readAuthEntry(signed)),
        isTrue,
      );
    });

    test('rejects a source-account entry', () {
      final entry = base64Encode((XdrWriter()..uint32(0)).bytes);

      expect(() => withExpirationLedger(entry, 10), throwsFormatException);
    });

    test('rejects a ledger outside uint32', () {
      final entry = _accountEntry(account, expiration: 0);

      expect(() => withExpirationLedger(entry, -1), throwsFormatException);
      expect(
        () => withExpirationLedger(entry, 0x100000000),
        throwsFormatException,
      );
    });
  });
}

/// The entry bytes with the four expiration bytes at [offset] removed.
List<int> _withoutExpiration(String entryXdr, int offset) {
  final bytes = base64Decode(entryXdr);
  return [...bytes.sublist(0, offset), ...bytes.sublist(offset + 4)];
}

// Layout: type(4) + address type(4) + key type(4) + key(32) + nonce(8) puts
// the expiration at byte 52 for accounts; contract addresses have no key
// type word, so theirs is at byte 48.
String _accountEntry(
  StellarAddress account, {
  required int expiration,
  int signature = 1,
}) {
  final out = XdrWriter()
    ..uint32(1)
    ..uint32(0)
    ..uint32(0)
    ..opaque(rawKey(account))
    ..int64(9)
    ..uint32(expiration);
  if (signature == 1) {
    out.uint32(1);
  } else {
    out
      ..uint32(signature)
      ..uint32(1);
  }
  out.uint32(0x10);
  return base64Encode(out.bytes);
}

String _contractEntry({required int expiration}) {
  final out = XdrWriter()
    ..uint32(1)
    ..uint32(1)
    ..opaque(Uint8List.fromList(List<int>.generate(32, (i) => i + 7)))
    ..int64(9)
    ..uint32(expiration)
    ..uint32(1)
    ..uint32(0x10);
  return base64Encode(out.bytes);
}
