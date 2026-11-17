import 'dart:convert';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';

import '../ledger/strkey.dart';
import '../ledger/xdr_reader.dart';

/// The parts of a `SorobanAuthorizationEntry` the deploy relay compares.
///
/// Source-account entries have no address. Address entries carry the
/// account, the nonce and the expiration, and the bytes of the invocation
/// that follow the signature.
final class AuthEntryView {
  const AuthEntryView({
    required this.credentialType,
    required this.accountKey,
    required this.nonce,
    required this.expirationLedger,
    required this.invocation,
  });

  /// `0` is `SOURCE_ACCOUNT`. Anything else is an address credential.
  final int credentialType;

  /// The 32-byte account id when the credential is an account address.
  final Uint8List? accountKey;
  final int? nonce;
  final int? expirationLedger;

  /// The authorized invocation, unchanged by signing.
  final Uint8List invocation;

  bool get isSourceAccount => credentialType == 0;

  /// True when this entry authorizes [account].
  bool covers(StellarAddress account) {
    final key = accountKey;
    if (key == null) return false;
    final expected = rawKey(account);
    if (key.length != expected.length) return false;
    for (var i = 0; i < key.length; i++) {
      if (key[i] != expected[i]) return false;
    }
    return true;
  }
}

/// Reads [entryXdr]. Throws [FormatException] when it is not an entry.
AuthEntryView readAuthEntry(String entryXdr) {
  final reader = XdrReader(base64Decode(entryXdr));
  final type = reader.uint32();
  if (type == 0) {
    return AuthEntryView(
      credentialType: type,
      accountKey: null,
      nonce: null,
      expirationLedger: null,
      invocation: reader.takeRest(),
    );
  }
  final accountKey = _accountKey(reader);
  final nonce = reader.int64();
  final expiration = reader.uint32();
  skipScVal(reader);
  return AuthEntryView(
    credentialType: type,
    accountKey: accountKey,
    nonce: nonce,
    expirationLedger: expiration,
    invocation: reader.takeRest(),
  );
}

/// [entryXdr] with its signature expiration ledger set to [ledger] and every
/// other byte unchanged.
///
/// Simulation in recording mode returns address entries with an expiration
/// of 0; the signer must set one before signing. Throws [FormatException]
/// for a source-account entry, a malformed entry or a [ledger] outside u32.
String withExpirationLedger(String entryXdr, int ledger) {
  if (ledger < 0 || ledger > 0xFFFFFFFF) {
    throw FormatException('expiration ledger $ledger is not a uint32');
  }
  final bytes = base64Decode(entryXdr);
  final reader = XdrReader(bytes);
  if (reader.uint32() == 0) {
    throw const FormatException('a source-account entry has no expiration');
  }
  _accountKey(reader);
  reader.int64();
  // The expiration is the next four bytes, big-endian like all XDR.
  final offset = reader.at;
  reader.need(4);
  final copy = Uint8List.fromList(bytes);
  ByteData.sublistView(copy).setUint32(offset, ledger);
  // Validate that the rewritten entry still reads as a whole entry.
  readAuthEntry(base64Encode(copy));
  return base64Encode(copy);
}

/// The index of the first address credential in [auth], or null.
int? addressAuthIndex(List<String> auth) {
  for (var i = 0; i < auth.length; i++) {
    try {
      if (!readAuthEntry(auth[i]).isSourceAccount) return i;
    } on FormatException {
      return null;
    }
  }
  return null;
}

/// True when [signed] is [prepared] with a different signature and the same
/// address, nonce, expiration and invocation.
bool sameAuthorization(AuthEntryView prepared, AuthEntryView signed) {
  if (prepared.isSourceAccount || signed.isSourceAccount) return false;
  if (prepared.credentialType != signed.credentialType) return false;
  if (!_same(prepared.accountKey, signed.accountKey)) return false;
  if (prepared.nonce != signed.nonce) return false;
  if (prepared.expirationLedger != signed.expirationLedger) return false;
  return _same(prepared.invocation, signed.invocation);
}

Uint8List? _accountKey(XdrReader reader) {
  switch (reader.uint32()) {
    case 0:
      if (reader.uint32() != 0) {
        throw const FormatException('unknown public key type');
      }
      return reader.opaque(32);
    case 1:
      reader.opaque(32);
      return null;
    default:
      throw const FormatException('unknown address');
  }
}

bool _same(Uint8List? a, Uint8List? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
