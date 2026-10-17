import 'dart:typed_data';

/// Reads big-endian XDR. Strings and opaque data are padded to 4 bytes.
final class XdrReader {
  XdrReader(this.bytes);

  final Uint8List bytes;
  int at = 0;

  int get remaining => bytes.length - at;

  void need(int length) {
    if (length < 0 || at + length > bytes.length) {
      throw const FormatException('truncated xdr');
    }
  }

  int uint32() {
    need(4);
    final value = ByteData.sublistView(bytes).getUint32(at);
    at += 4;
    return value;
  }

  int int64() {
    need(8);
    final value = ByteData.sublistView(bytes).getInt64(at);
    at += 8;
    return value;
  }

  Uint8List opaque(int length) {
    need(length);
    final value = Uint8List.sublistView(bytes, at, at + length);
    at += length;
    _pad(length);
    return Uint8List.fromList(value);
  }

  Uint8List takeRest() {
    final rest = Uint8List.sublistView(bytes, at);
    at = bytes.length;
    return Uint8List.fromList(rest);
  }

  void _pad(int length) {
    final padding = (4 - length % 4) % 4;
    need(padding);
    at += padding;
  }
}

/// Skips one `SCVal`. Throws [FormatException] on a truncated or unknown value.
void skipScVal(XdrReader reader) {
  switch (reader.uint32()) {
    case 0: // SCV_BOOL
    case 3: // SCV_U32
    case 4: // SCV_I32
      reader.need(4);
      reader.at += 4;
    case 1: // SCV_VOID
      return;
    case 5: // SCV_U64
    case 6: // SCV_I64
    case 7: // SCV_TIMEPOINT
    case 8: // SCV_DURATION
      reader.need(8);
      reader.at += 8;
    case 9: // SCV_U128
    case 10: // SCV_I128
      reader.need(16);
      reader.at += 16;
    case 11: // SCV_U256
    case 12: // SCV_I256
      reader.need(32);
      reader.at += 32;
    case 13: // SCV_BYTES
    case 14: // SCV_STRING
    case 15: // SCV_SYMBOL
      reader.opaque(reader.uint32());
    case 16: // SCV_VEC
      _skipOptional(reader, () {
        final length = reader.uint32();
        for (var i = 0; i < length; i++) {
          skipScVal(reader);
        }
      });
    case 17: // SCV_MAP
      _skipOptional(reader, () {
        final length = reader.uint32();
        for (var i = 0; i < length; i++) {
          skipScVal(reader);
          skipScVal(reader);
        }
      });
    case 18: // SCV_ADDRESS
      _skipAddress(reader);
    default:
      throw const FormatException('unknown scval');
  }
}

void _skipOptional(XdrReader reader, void Function() read) {
  final present = reader.uint32();
  if (present == 0) return;
  if (present != 1) throw const FormatException('bad optional');
  read();
}

void _skipAddress(XdrReader reader) {
  switch (reader.uint32()) {
    case 0: // account
      if (reader.uint32() != 0) {
        throw const FormatException('unknown public key type');
      }
      reader.opaque(32);
    case 1: // contract
      reader.opaque(32);
    default:
      throw const FormatException('unknown address');
  }
}
