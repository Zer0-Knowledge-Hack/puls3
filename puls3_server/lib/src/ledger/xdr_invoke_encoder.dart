import 'dart:convert';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';

import 'strkey.dart';

/// One argument of a contract call. Only the types the adapter sends exist.
sealed class ScArg {
  const ScArg._();

  /// An `SCV_U32` argument.
  const factory ScArg.u32(int value) = _U32;

  /// An `SCV_U64` argument.
  const factory ScArg.u64(int value) = _U64;

  void _write(_XdrWriter out);
}

final class _U32 extends ScArg {
  const _U32(this.value) : super._();

  final int value;

  @override
  void _write(_XdrWriter out) => out
    ..uint32(_scvU32)
    ..uint32(value);
}

final class _U64 extends ScArg {
  const _U64(this.value) : super._();

  final int value;

  @override
  void _write(_XdrWriter out) => out
    ..uint32(_scvU64)
    ..int64(value);
}

// XDR discriminants, from Stellar-transaction.x and Stellar-contract.x.
const _envelopeTypeTx = 2;
const _keyTypeEd25519 = 0;
const _preconditionNone = 0;
const _memoNone = 0;
const _invokeHostFunction = 24;
const _hostFunctionInvokeContract = 0;
const _scAddressContract = 1;
const _scvU32 = 3;
const _scvU64 = 5;

/// An unsigned `TransactionEnvelope` (base64 XDR) that invokes [function] on
/// [contract].
///
/// It carries no signature and no authorization entries, so it can only be
/// simulated. It is sent to `simulateTransaction`, never submitted.
String encodeInvokeEnvelope({
  required StellarAddress source,
  required int fee,
  required int sequence,
  required StellarAddress contract,
  required String function,
  required List<ScArg> args,
}) {
  final out = _XdrWriter()
    ..uint32(_envelopeTypeTx)
    ..uint32(_keyTypeEd25519)
    ..opaque(rawKey(source))
    ..uint32(fee)
    ..int64(sequence)
    ..uint32(_preconditionNone)
    ..uint32(_memoNone)
    ..uint32(1) // one operation
    ..uint32(0) // no operation source account
    ..uint32(_invokeHostFunction)
    ..uint32(_hostFunctionInvokeContract)
    ..uint32(_scAddressContract)
    ..opaque(rawKey(contract))
    ..string(function)
    ..uint32(args.length);
  for (final arg in args) {
    arg._write(out);
  }
  out
    ..uint32(0) // no authorization entries
    ..uint32(0) // transaction extension v0
    ..uint32(0); // no signatures
  return base64Encode(out.bytes);
}

/// Big-endian XDR primitives. Strings and opaque data pad to 4 bytes.
final class _XdrWriter {
  final _builder = BytesBuilder();

  Uint8List get bytes => _builder.toBytes();

  void uint32(int value) {
    final data = ByteData(4)..setUint32(0, value);
    _builder.add(data.buffer.asUint8List());
  }

  void int64(int value) {
    final data = ByteData(8)..setInt64(0, value);
    _builder.add(data.buffer.asUint8List());
  }

  /// Fixed-length opaque data, such as a 32-byte key: no length prefix.
  void opaque(Uint8List value) {
    _builder.add(value);
    _pad(value.length);
  }

  /// A variable-length string: length prefix, bytes, zero padding.
  void string(String value) {
    final encoded = utf8.encode(value);
    uint32(encoded.length);
    _builder.add(encoded);
    _pad(encoded.length);
  }

  void _pad(int length) {
    final padding = (4 - length % 4) % 4;
    if (padding > 0) _builder.add(Uint8List(padding));
  }
}
