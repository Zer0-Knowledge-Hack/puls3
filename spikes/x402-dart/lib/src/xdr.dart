import 'dart:convert';
import 'dart:typed_data';

/// Writes big-endian XDR. Strings and opaque data are padded to 4 bytes.
final class XdrWriter {
  final BytesBuilder _out = BytesBuilder(copy: false);

  void uint32(int value) {
    final data = ByteData(4)..setUint32(0, value);
    _out.add(data.buffer.asUint8List());
  }

  void int64(int value) {
    final data = ByteData(8)..setInt64(0, value);
    _out.add(data.buffer.asUint8List());
  }

  void uint64(BigInt value) {
    if (value.isNegative || value.bitLength > 64) {
      throw ArgumentError.value(value, 'value', 'not a uint64');
    }
    final data = ByteData(8)
      ..setUint32(0, (value >> 32).toUnsigned(32).toInt())
      ..setUint32(4, value.toUnsigned(32).toInt());
    _out.add(data.buffer.asUint8List());
  }

  void int64Big(BigInt value) {
    if (value.bitLength > 63) {
      throw ArgumentError.value(value, 'value', 'not an int64');
    }
    uint64(value.toUnsigned(64));
  }

  /// Fixed-length opaque data, padded to 4 bytes.
  void fixed(List<int> bytes) {
    _out.add(bytes);
    _pad(bytes.length);
  }

  /// Variable-length opaque data: a length, then the padded bytes.
  void opaque(List<int> bytes) {
    uint32(bytes.length);
    fixed(bytes);
  }

  void string(String value) => opaque(utf8.encode(value));

  /// Bytes that are already XDR, written as they are.
  void raw(List<int> bytes) => _out.add(bytes);

  void _pad(int length) {
    final pad = (4 - length % 4) % 4;
    if (pad > 0) _out.add(Uint8List(pad));
  }

  Uint8List toBytes() => _out.toBytes();
}

/// Reads big-endian XDR.
final class XdrReader {
  XdrReader(this.bytes);

  final Uint8List bytes;
  int at = 0;

  void _need(int length) {
    if (length < 0 || at + length > bytes.length) {
      throw const FormatException('truncated xdr');
    }
  }

  int uint32() {
    _need(4);
    final value = ByteData.sublistView(bytes).getUint32(at);
    at += 4;
    return value;
  }

  /// [length] bytes, plus the padding that follows them.
  Uint8List fixed(int length) {
    _need(length);
    final value = Uint8List.fromList(bytes.sublist(at, at + length));
    at += length;
    final pad = (4 - length % 4) % 4;
    _need(pad);
    at += pad;
    return value;
  }

  /// The bytes from [start] to the current position.
  Uint8List since(int start) => Uint8List.fromList(bytes.sublist(start, at));

  Uint8List rest() {
    final value = Uint8List.fromList(bytes.sublist(at));
    at = bytes.length;
    return value;
  }
}
