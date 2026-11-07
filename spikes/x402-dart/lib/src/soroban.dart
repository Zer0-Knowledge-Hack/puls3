import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;

import 'signer.dart';
import 'xdr.dart';

// XDR discriminants, from Stellar-transaction.x and Stellar-contract.x.
const _envelopeTypeTx = 2;
const _envelopeTypeSorobanAuthorization = 9;
const _envelopeTypeSorobanAuthorizationWithAddress = 10;
const _opInvokeHostFunction = 24;
const _hostFunctionInvokeContract = 0;
const _authorizedFunctionContractFn = 0;
const _credentialsAddress = 1;
const _credentialsAddressV2 = 2;
const _scAddressAccount = 0;
const _scAddressContract = 1;
const _publicKeyEd25519 = 0;
const _precondTime = 1;
const _memoNone = 0;
const _scvVoid = 1;
const _scvI128 = 10;
const _scvBytes = 13;
const _scvSymbol = 15;
const _scvVec = 16;
const _scvMap = 17;
const _scvAddress = 18;

/// The impossible account `GAAA…WHF` (an all-zero key). The payer is not the
/// transaction source, so simulation returns an address credential for it
/// instead of a source-account one; the facilitator replaces the source.
final Uint8List nullAccount = Uint8List(32);

/// The 32 raw bytes of a `G…` or `C…` address.
Uint8List rawKey(String address) {
  final decoded = stellar.StellarAddress.fromBase32Addr(address);
  if (decoded is stellar.StellarMuxedAddress) {
    throw FormatException('muxed addresses are not supported: $address');
  }
  return Uint8List.fromList(decoded.keyBytes());
}

Uint8List networkId(String passphrase) =>
    Uint8List.fromList(sha256.convert(utf8.encode(passphrase)).bytes);

/// A SAC `transfer(from, to, amount)` call.
final class SacTransfer {
  SacTransfer({
    required this.asset,
    required this.from,
    required this.to,
    required this.amount,
  });

  final String asset;
  final String from;
  final String to;
  final BigInt amount;

  /// `InvokeContractArgs`, shared by the host function and the auth entry.
  Uint8List invokeContractArgs() {
    final out = XdrWriter();
    _scAddress(out, asset);
    out
      ..string('transfer')
      ..uint32(3);
    out.uint32(_scvAddress);
    _scAddress(out, from);
    out.uint32(_scvAddress);
    _scAddress(out, to);
    _i128(out, amount);
    return out.toBytes();
  }

  /// The `SorobanAuthorizedInvocation` the payer must authorize: this call
  /// and no sub-invocations.
  Uint8List expectedInvocation() {
    final out = XdrWriter()
      ..uint32(_authorizedFunctionContractFn)
      ..raw(invokeContractArgs())
      ..uint32(0);
    return out.toBytes();
  }

  /// An unsigned `TransactionEnvelope` with one `InvokeHostFunction`.
  ///
  /// [auth] are `SorobanAuthorizationEntry` XDR blobs; [sorobanData] is the
  /// `SorobanTransactionData` from simulation, or null before it.
  Uint8List envelope({
    required int fee,
    required int maxTime,
    List<Uint8List> auth = const [],
    Uint8List? sorobanData,
  }) {
    final out = XdrWriter()
      ..uint32(_envelopeTypeTx)
      // sourceAccount: MuxedAccount, KEY_TYPE_ED25519
      ..uint32(_publicKeyEd25519)
      ..fixed(nullAccount)
      ..uint32(fee)
      ..int64(1)
      ..uint32(_precondTime)
      ..uint64(BigInt.zero)
      ..uint64(BigInt.from(maxTime))
      ..uint32(_memoNone)
      ..uint32(1)
      // Operation: no source account, INVOKE_HOST_FUNCTION.
      ..uint32(0)
      ..uint32(_opInvokeHostFunction)
      ..uint32(_hostFunctionInvokeContract)
      ..raw(invokeContractArgs())
      ..uint32(auth.length);
    for (final entry in auth) {
      out.raw(entry);
    }
    if (sorobanData == null) {
      out.uint32(0);
    } else {
      out
        ..uint32(1)
        ..raw(sorobanData);
    }
    out.uint32(0); // no signatures
    return out.toBytes();
  }
}

/// Thrown when simulation asks for an authorization the client did not
/// expect. Nothing was signed.
final class UnexpectedAuthorization implements Exception {
  UnexpectedAuthorization(this.message);

  final String message;

  @override
  String toString() => 'UnexpectedAuthorization: $message';
}

/// An address-credential `SorobanAuthorizationEntry` returned by simulation.
final class AuthEntry {
  AuthEntry._({
    required this.credentialType,
    required this.address,
    required this.addressXdr,
    required this.nonceXdr,
    required this.expirationLedger,
    required this.invocation,
  });

  /// `1` for `ADDRESS`, `2` for `ADDRESS_V2` (CAP-71).
  final int credentialType;

  /// The 32-byte account key that must sign.
  final Uint8List address;

  /// The `ScAddress` XDR, which the V2 payload binds.
  final Uint8List addressXdr;
  final Uint8List nonceXdr;
  final int expirationLedger;

  /// The `SorobanAuthorizedInvocation` XDR, unchanged by signing.
  final Uint8List invocation;

  /// Parses an unsigned entry. Throws [UnexpectedAuthorization] for source
  /// account or contract credentials, delegates, or an existing signature.
  factory AuthEntry.parse(Uint8List entry) {
    try {
      final reader = XdrReader(entry);
      final type = reader.uint32();
      if (type != _credentialsAddress && type != _credentialsAddressV2) {
        throw UnexpectedAuthorization('credential type $type');
      }
      final addressStart = reader.at;
      if (reader.uint32() != _scAddressAccount ||
          reader.uint32() != _publicKeyEd25519) {
        throw UnexpectedAuthorization('the signer is not an account');
      }
      final address = reader.fixed(32);
      final addressXdr = reader.since(addressStart);
      final nonce = reader.fixed(8);
      final expiration = reader.uint32();
      if (reader.uint32() != _scvVoid) {
        throw UnexpectedAuthorization('the entry is already signed');
      }
      return AuthEntry._(
        credentialType: type,
        address: address,
        addressXdr: addressXdr,
        nonceXdr: nonce,
        expirationLedger: expiration,
        invocation: reader.rest(),
      );
    } on FormatException catch (e) {
      throw UnexpectedAuthorization('malformed entry: ${e.message}');
    }
  }

  /// The `HashIdPreimage` whose SHA-256 the account signs.
  Uint8List preimage(Uint8List networkId, int expirationLedger) {
    final out = XdrWriter()
      ..uint32(
        credentialType == _credentialsAddressV2
            ? _envelopeTypeSorobanAuthorizationWithAddress
            : _envelopeTypeSorobanAuthorization,
      )
      ..fixed(networkId)
      ..raw(nonceXdr)
      ..uint32(expirationLedger);
    if (credentialType == _credentialsAddressV2) out.raw(addressXdr);
    out.raw(invocation);
    return out.toBytes();
  }

  /// This entry signed by [signer], valid through [expirationLedger].
  Uint8List sign(AuthSigner signer, Uint8List networkId, int expirationLedger) {
    if (expirationLedger <= 0) {
      throw ArgumentError.value(expirationLedger, 'expirationLedger');
    }
    final payload = Uint8List.fromList(
      sha256.convert(preimage(networkId, expirationLedger)).bytes,
    );
    final signature = signer.sign(payload);
    final out = XdrWriter()
      ..uint32(credentialType)
      ..raw(addressXdr)
      ..raw(nonceXdr)
      ..uint32(expirationLedger)
      // Vec<AccountEd25519Signature>: [{public_key, signature}], keys sorted.
      ..uint32(_scvVec)
      ..uint32(1)
      ..uint32(1)
      ..uint32(_scvMap)
      ..uint32(1)
      ..uint32(2)
      ..uint32(_scvSymbol)
      ..string('public_key')
      ..uint32(_scvBytes)
      ..opaque(signer.publicKey)
      ..uint32(_scvSymbol)
      ..string('signature')
      ..uint32(_scvBytes)
      ..opaque(signature)
      ..raw(invocation);
    return out.toBytes();
  }
}

void _scAddress(XdrWriter out, String address) {
  final key = rawKey(address);
  if (address.startsWith('G')) {
    out
      ..uint32(_scAddressAccount)
      ..uint32(_publicKeyEd25519)
      ..fixed(key);
  } else if (address.startsWith('C')) {
    out
      ..uint32(_scAddressContract)
      ..fixed(key);
  } else {
    throw FormatException('not an account or contract address: $address');
  }
}

void _i128(XdrWriter out, BigInt value) {
  if (value.isNegative || value.bitLength > 127) {
    throw ArgumentError.value(value, 'value', 'not a positive i128');
  }
  final mask = (BigInt.one << 64) - BigInt.one;
  out
    ..uint32(_scvI128)
    ..int64Big(value >> 64)
    ..uint64(value & mask);
}

bool sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
