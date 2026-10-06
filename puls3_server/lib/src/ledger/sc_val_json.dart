import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';

import 'ledger_errors.dart';

/// Readers for ScVal values in the JSON form the Soroban RPC returns when the
/// request sets `xdrFormat: "json"`, for example `{"u32": 7}` or `"void"`.
///
/// Every reader throws [LedgerUnavailable] when the value has another shape,
/// so a response the adapter does not understand never becomes a type error.

/// Whether [value] is the `void` ScVal.
bool isVoid(Object? value) => value == 'void';

/// [read] applied to [value], or `null` when [value] is `void`.
T? readOptional<T>(Object? value, T Function(Object?) read) =>
    isVoid(value) ? null : read(value);

bool readBool(Object? value) {
  final inner = _inner(value, 'bool');
  if (inner is! bool) throw _mismatch('bool', value);
  return inner;
}

int readU32(Object? value) {
  final number = _integer(value, 'u32');
  if (number < BigInt.zero || number > BigInt.from(4294967295)) {
    throw _mismatch('u32', value);
  }
  return number.toInt();
}

/// A `u64` as a Dart [int]. Values above `2^63 - 1` do not fit and throw.
int readU64(Object? value) {
  final number = _integer(value, 'u64');
  if (number < BigInt.zero || !number.isValidInt) {
    throw _mismatch('u64', value);
  }
  return number.toInt();
}

BigInt readI128(Object? value) => _integer(value, 'i128');

String readString(Object? value) => _text(value, 'string');

String readSymbol(Object? value) => _text(value, 'symbol');

StellarAddress readAddress(Object? value) {
  final text = _text(value, 'address');
  try {
    return StellarAddress.parse(text);
  } on InvalidStellarAddress {
    throw _mismatch('address', value);
  }
}

/// Hex-encoded `bytes`.
Uint8List readBytes(Object? value) {
  final text = _text(value, 'bytes');
  if (text.length.isOdd || !_hex.hasMatch(text)) {
    throw _mismatch('bytes', value);
  }
  final bytes = Uint8List(text.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(text.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

/// A `map` keyed by symbol. The values stay in their raw JSON form so the
/// caller reads each one with the reader of its own type.
Map<String, Object?> readMap(Object? value) {
  final entries = _inner(value, 'map');
  if (entries is! List) throw _mismatch('map', value);
  final result = <String, Object?>{};
  for (final entry in entries) {
    if (entry is! Map || !entry.containsKey('val')) {
      throw _mismatch('map', value);
    }
    result[readSymbol(entry['key'])] = entry['val'];
  }
  return result;
}

final _hex = RegExp(r'^[0-9a-fA-F]*$');

Object? _inner(Object? value, String type) {
  if (value is! Map || value.length != 1 || !value.containsKey(type)) {
    throw _mismatch(type, value);
  }
  return value[type];
}

String _text(Object? value, String type) {
  final inner = _inner(value, type);
  if (inner is! String) throw _mismatch(type, value);
  return inner;
}

/// An integer sent as a JSON number or as a numeric string.
BigInt _integer(Object? value, String type) {
  final inner = _inner(value, type);
  final number = switch (inner) {
    int() => BigInt.from(inner),
    String() => BigInt.tryParse(inner),
    _ => null,
  };
  if (number == null) throw _mismatch(type, value);
  return number;
}

LedgerUnavailable _mismatch(String expected, Object? value) =>
    LedgerUnavailable('Expected a $expected ScVal, got ${_describe(value)}');

String _describe(Object? value) {
  final text = '$value';
  return text.length <= 80 ? text : '${text.substring(0, 80)}...';
}
