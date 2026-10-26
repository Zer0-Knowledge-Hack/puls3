import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:puls3_domain/puls3_domain.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;

import '../ledger/strkey.dart';
import '../ledger/xdr_invoke_encoder.dart';
import 'auth_entry.dart';

/// `ENVELOPE_TYPE_SOROBAN_AUTHORIZATION` (legacy ADDRESS credentials).
const _preimageAddress = 9;

/// `ENVELOPE_TYPE_SOROBAN_AUTHORIZATION_WITH_ADDRESS` (ADDRESS_V2).
const _preimageAddressV2 = 10;

const _credentialsAddress = 1;
const _credentialsAddressV2 = 2;
const _scvVec = 16;
const _scvMap = 17;
const _scvBytes = 13;
const _scvSymbol = 15;

/// Signs a simulated `SorobanAuthorizationEntry` with [key], the same way
/// Freighter's `signAuthEntry` does for ADDRESS and ADDRESS_V2.
///
/// The invocation, nonce, expiration and credential address are unchanged;
/// only the signature vector is written. Throws [FormatException] when [entryXdr]
/// is not an address credential of [key]'s account.
String signAddressAuthEntry({
  required String entryXdr,
  required stellar.StellarPrivateKey key,
  required String networkPassphrase,
}) {
  final view = readAuthEntry(entryXdr);
  final account = StellarAddress.parse(
    key.toPublicKey().toAddress().baseAddress,
  );
  if (view.isSourceAccount ||
      view.accountKey == null ||
      view.nonce == null ||
      view.expirationLedger == null ||
      !view.covers(account)) {
    throw const FormatException('not an address credential of this key');
  }
  if (view.credentialType != _credentialsAddress &&
      view.credentialType != _credentialsAddressV2) {
    throw const FormatException('unsupported authorization credential');
  }

  final networkId = Uint8List.fromList(
    sha256.convert(utf8.encode(networkPassphrase)).bytes,
  );
  final preimage = XdrWriter();
  if (view.credentialType == _credentialsAddressV2) {
    preimage
      ..uint32(_preimageAddressV2)
      ..opaque(networkId)
      ..int64(view.nonce!)
      ..uint32(view.expirationLedger!)
      ..uint32(0)
      ..uint32(0)
      ..opaque(view.accountKey!);
  } else {
    preimage
      ..uint32(_preimageAddress)
      ..opaque(networkId)
      ..int64(view.nonce!)
      ..uint32(view.expirationLedger!);
  }
  preimage.raw(view.invocation);
  final hash = sha256.convert(preimage.bytes).bytes;
  final signature = Uint8List.fromList(key.sign(hash).signature);

  final signed = XdrWriter()
    ..uint32(view.credentialType)
    ..uint32(0)
    ..uint32(0)
    ..opaque(view.accountKey!)
    ..int64(view.nonce!)
    ..uint32(view.expirationLedger!);
  _writeEd25519SignatureVec(signed, rawKey(account), signature);
  signed.raw(view.invocation);
  return base64Encode(signed.bytes);
}

void _writeEd25519SignatureVec(
  XdrWriter out,
  Uint8List publicKey,
  Uint8List signature,
) {
  out
    ..uint32(_scvVec)
    ..uint32(1)
    ..uint32(1)
    ..uint32(_scvMap)
    ..uint32(1)
    ..uint32(2)
    ..uint32(_scvSymbol)
    ..string('public_key')
    ..uint32(_scvBytes)
    ..uint32(publicKey.length)
    ..opaque(publicKey)
    ..uint32(_scvSymbol)
    ..string('signature')
    ..uint32(_scvBytes)
    ..uint32(signature.length)
    ..opaque(signature);
}
