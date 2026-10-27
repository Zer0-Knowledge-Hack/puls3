import 'dart:convert';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/ledger/strkey.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart';
import 'package:puls3_server/src/studio/auth_entry.dart';
import 'package:puls3_server/src/studio/auth_entry_signer.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;
import 'package:test/test.dart';

const _passphrase = 'Test SDF Network ; September 2015';

void main() {
  final key = stellar.StellarPrivateKey.fromBytes(
    List<int>.generate(32, (i) => i + 1),
  );
  final account = StellarAddress.parse(
    key.toPublicKey().toAddress().baseAddress,
  );

  test('signs an ADDRESS_V2 entry without changing the invocation', () {
    final unsigned = _entry(account, credentialType: 2);
    final signed = signAddressAuthEntry(
      entryXdr: unsigned,
      key: key,
      networkPassphrase: _passphrase,
    );

    expect(signed, isNot(unsigned));
    final prepared = readAuthEntry(unsigned);
    final view = readAuthEntry(signed);
    expect(view.covers(account), isTrue);
    expect(sameAuthorization(prepared, view), isTrue);
  });

  test('signs a legacy ADDRESS entry', () {
    final unsigned = _entry(account, credentialType: 1);
    final signed = signAddressAuthEntry(
      entryXdr: unsigned,
      key: key,
      networkPassphrase: _passphrase,
    );
    expect(
      sameAuthorization(readAuthEntry(unsigned), readAuthEntry(signed)),
      isTrue,
    );
  });

  test('rejects a source-account entry', () {
    expect(
      () => signAddressAuthEntry(
        entryXdr: base64Encode((XdrWriter()..uint32(0)).bytes),
        key: key,
        networkPassphrase: _passphrase,
      ),
      throwsFormatException,
    );
  });
}

String _entry(StellarAddress account, {required int credentialType}) {
  final out = XdrWriter()
    ..uint32(credentialType)
    ..uint32(0)
    ..uint32(0)
    ..opaque(rawKey(account))
    ..int64(9)
    ..uint32(100)
    ..uint32(1)
    ..uint32(0x10);
  return base64Encode(out.bytes);
}
