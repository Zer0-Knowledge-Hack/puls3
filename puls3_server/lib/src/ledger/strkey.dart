import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';

const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

/// The 32 raw bytes of [address]: the ed25519 public key of a `G…` account or
/// the hash of a `C…` contract.
///
/// [StellarAddress.parse] already verified the length, alphabet, version byte
/// and checksum, so this only unpacks the base32 payload: version (1 byte),
/// key (32 bytes), checksum (2 bytes).
Uint8List rawKey(StellarAddress address) {
  final bytes = <int>[];
  var buffer = 0;
  var bits = 0;
  for (final char in address.value.split('')) {
    buffer = (buffer << 5) | _alphabet.indexOf(char);
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      bytes.add((buffer >> bits) & 0xff);
      buffer &= (1 << bits) - 1;
    }
  }
  return Uint8List.fromList(bytes.sublist(1, 33));
}
