import 'dart:typed_data';

/// Minimal Stellar strkey and ScVal decoding for the values Horizon returns
/// as base64 XDR in `invoke_host_function` parameters.
///
/// Only the types a `complete` call carries: `Address`, `Sym` and `U64`.

const _accountVersion = 6 << 3; // G...
const _contractVersion = 2 << 3; // C...
const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

/// [payload] (32 bytes) as a `G…` account or `C…` contract strkey.
String encodeStrkey(List<int> payload, {required bool contract}) {
  if (payload.length != 32) {
    throw FormatException(
      'a strkey payload is 32 bytes, got ${payload.length}',
    );
  }
  final data = <int>[contract ? _contractVersion : _accountVersion, ...payload];
  final crc = _crc16Xmodem(data);
  data
    ..add(crc & 0xff)
    ..add(crc >> 8);
  return _base32(data);
}

int _crc16Xmodem(List<int> bytes) {
  var crc = 0;
  for (final byte in bytes) {
    crc ^= byte << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
      crc &= 0xffff;
    }
  }
  return crc;
}

String _base32(List<int> bytes) {
  final out = StringBuffer();
  var buffer = 0;
  var bits = 0;
  for (final byte in bytes) {
    buffer = (buffer << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      out.write(_alphabet[(buffer >> (bits - 5)) & 31]);
      bits -= 5;
      buffer &= (1 << bits) - 1;
    }
  }
  if (bits > 0) out.write(_alphabet[(buffer << (5 - bits)) & 31]);
  return '$out';
}

/// A decoded ScVal: a [String] for `Sym` and `Address`, a [BigInt] for
/// `U64`, and null for any other type.
Object? decodeScVal(Uint8List xdr) {
  final data = ByteData.sublistView(xdr);
  if (xdr.length < 4) throw const FormatException('ScVal shorter than 4 bytes');
  switch (data.getUint32(0)) {
    case 5: // SCV_U64
      _need(xdr, 12);
      return (BigInt.from(data.getUint32(4)) << 32) |
          BigInt.from(data.getUint32(8));
    case 15: // SCV_SYMBOL
      _need(xdr, 8);
      final length = data.getUint32(4);
      _need(xdr, 8 + length);
      return String.fromCharCodes(xdr.sublist(8, 8 + length));
    case 18: // SCV_ADDRESS
      _need(xdr, 8);
      switch (data.getUint32(4)) {
        case 0: // SC_ADDRESS_TYPE_ACCOUNT, PUBLIC_KEY_TYPE_ED25519
          _need(xdr, 44);
          return encodeStrkey(xdr.sublist(12, 44), contract: false);
        case 1: // SC_ADDRESS_TYPE_CONTRACT
          _need(xdr, 40);
          return encodeStrkey(xdr.sublist(8, 40), contract: true);
      }
      return null;
  }
  return null;
}

void _need(Uint8List xdr, int length) {
  if (xdr.length < length) {
    throw FormatException('ScVal needs $length bytes, got ${xdr.length}');
  }
}
