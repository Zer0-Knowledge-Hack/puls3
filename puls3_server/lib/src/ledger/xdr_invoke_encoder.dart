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

  /// An `SCV_STRING` argument, sent as UTF-8.
  const factory ScArg.string(String value) = _String;

  /// An `SCV_ADDRESS` argument: an account (`G...`) or a contract (`C...`).
  const factory ScArg.address(StellarAddress value) = _Address;

  /// An `SCV_I128` argument. [value] is a Dart `int`, so it spans 64 bits;
  /// the upper half is its sign extension.
  const factory ScArg.i128(int value) = _I128;

  /// An `SCV_VOID` argument, for example an absent `Option`.
  const factory ScArg.voidValue() = _Void;

  void _write(XdrWriter out);
}

final class _U32 extends ScArg {
  const _U32(this.value) : super._();

  final int value;

  @override
  void _write(XdrWriter out) => out
    ..uint32(_scvU32)
    ..uint32(value);
}

final class _U64 extends ScArg {
  const _U64(this.value) : super._();

  final int value;

  @override
  void _write(XdrWriter out) => out
    ..uint32(_scvU64)
    ..int64(value);
}

final class _String extends ScArg {
  const _String(this.value) : super._();

  final String value;

  @override
  void _write(XdrWriter out) => out
    ..uint32(_scvString)
    ..string(value);
}

final class _Address extends ScArg {
  const _Address(this.value) : super._();

  final StellarAddress value;

  @override
  void _write(XdrWriter out) {
    out.uint32(_scvAddress);
    if (value.kind == StellarAddressKind.contract) {
      out.uint32(_scAddressContract);
    } else {
      out
        ..uint32(_scAddressAccount)
        ..uint32(_keyTypeEd25519);
    }
    out.opaque(rawKey(value));
  }
}

final class _I128 extends ScArg {
  const _I128(this.value) : super._();

  final int value;

  @override
  void _write(XdrWriter out) => out
    ..uint32(_scvI128)
    ..int64(value < 0 ? -1 : 0)
    ..uint64(value);
}

final class _Void extends ScArg {
  const _Void() : super._();

  @override
  void _write(XdrWriter out) => out.uint32(_scvVoid);
}

// XDR discriminants, from Stellar-transaction.x and Stellar-contract.x.
const _envelopeTypeTx = 2;
const _keyTypeEd25519 = 0;
const _preconditionNone = 0;
const _memoNone = 0;
const _invokeHostFunction = 24;
const _hostFunctionInvokeContract = 0;
const _scAddressAccount = 0;
const _scAddressContract = 1;
const _scvVoid = 1;
const _scvU32 = 3;
const _scvU64 = 5;
const _scvI128 = 10;
const _scvString = 14;
const _scvAddress = 18;

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
  final out = XdrWriter()
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
    ..raw(
      encodeInvokeHostFunction(
        contract: contract,
        function: function,
        args: args,
      ),
    )
    ..uint32(0) // no authorization entries
    ..uint32(0) // transaction extension v0
    ..uint32(0); // no signatures
  return base64Encode(out.bytes);
}

/// The XDR `HostFunction` that invokes [function] on [contract]: the
/// invoke-contract discriminant, the contract address, the function name and
/// the arguments.
Uint8List encodeInvokeHostFunction({
  required StellarAddress contract,
  required String function,
  required List<ScArg> args,
}) {
  final out = XdrWriter()
    ..uint32(_hostFunctionInvokeContract)
    ..uint32(_scAddressContract)
    ..opaque(rawKey(contract))
    ..string(function)
    ..uint32(args.length);
  for (final arg in args) {
    arg._write(out);
  }
  return out.bytes;
}

/// Big-endian XDR primitives. Strings and opaque data pad to 4 bytes.
final class XdrWriter {
  final _builder = BytesBuilder();

  Uint8List get bytes => _builder.toBytes();

  /// Bytes that are already XDR, written as they are.
  void raw(List<int> value) => _builder.add(value);

  void uint32(int value) {
    final data = ByteData(4)..setUint32(0, value);
    _builder.add(data.buffer.asUint8List());
  }

  void int64(int value) {
    final data = ByteData(8)..setInt64(0, value);
    _builder.add(data.buffer.asUint8List());
  }

  /// The low 64 bits of [value] as an unsigned integer (two's complement for
  /// a negative [value]).
  void uint64(int value) {
    final data = ByteData(8)..setUint64(0, value);
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
