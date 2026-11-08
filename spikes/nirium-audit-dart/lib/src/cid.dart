import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// The largest file that IPFS stores as one block with the default chunker
/// (256 KiB). Above it the file is split and its CID is a tree of chunks.
const maxSingleBlockFile = 262144;

/// The CIDv0 (`Qm…`) that IPFS gives [file] when it adds it with the
/// default settings (dag-pb, UnixFS, no raw leaves), as the Nirium node does.
///
/// The block is `PBNode{Data: UnixFS{Type: File, Data: file, filesize}}`,
/// and the CID is the base58btc sha2-256 multihash of that block. Throws
/// [ArgumentError] for a file above [maxSingleBlockFile], whose CID this
/// function cannot compute.
String cidV0ForFile(List<int> file) {
  if (file.length > maxSingleBlockFile) {
    throw ArgumentError.value(
      file.length,
      'file',
      'is above $maxSingleBlockFile bytes; only single-block files',
    );
  }
  final unixfs = BytesBuilder()..add([0x08, 0x02]); // Type: File
  if (file.isNotEmpty) {
    // Data; protobuf omits an empty bytes field.
    unixfs
      ..addByte(0x12)
      ..add(_varint(file.length))
      ..add(file);
  }
  unixfs
    ..addByte(0x18) // filesize
    ..add(_varint(file.length));
  final unixfsBytes = unixfs.toBytes();
  final node = BytesBuilder()
    ..addByte(0x0a) // PBNode.Data
    ..add(_varint(unixfsBytes.length))
    ..add(unixfsBytes);
  final digest = sha256.convert(node.toBytes()).bytes;
  return _base58([0x12, 0x20, ...digest]);
}

List<int> _varint(int value) {
  final out = <int>[];
  var n = value;
  while (n >= 0x80) {
    out.add((n & 0x7f) | 0x80);
    n >>= 7;
  }
  out.add(n);
  return out;
}

const _alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

String _base58(List<int> bytes) {
  var n = BigInt.zero;
  for (final b in bytes) {
    n = (n << 8) | BigInt.from(b);
  }
  final out = StringBuffer();
  final base = BigInt.from(58);
  final digits = <String>[];
  while (n > BigInt.zero) {
    digits.add(_alphabet[(n % base).toInt()]);
    n ~/= base;
  }
  for (final b in bytes) {
    if (b != 0) break;
    out.write('1');
  }
  out.writeAll(digits.reversed);
  return '$out';
}
