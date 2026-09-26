import 'errors.dart';

enum StellarAddressKind { account, contract }

/// A Stellar account (`G…`) or contract (`C…`) address in strkey form.
///
/// Parsing checks the length, the base32 alphabet, the version byte and the
/// CRC16-XModem checksum, so a mistyped address is rejected before it is used.
final class StellarAddress {
  const StellarAddress._(this.value, this.kind);

  factory StellarAddress.parse(String input) {
    if (input.length != _length) {
      throw const InvalidStellarAddress(StellarAddressProblem.wrongLength);
    }
    if (!_base32Only.hasMatch(input)) {
      throw const InvalidStellarAddress(
        StellarAddressProblem.invalidCharacters,
      );
    }
    final kind = switch (input[0]) {
      'G' => StellarAddressKind.account,
      'C' => StellarAddressKind.contract,
      _ => throw const InvalidStellarAddress(StellarAddressProblem.wrongPrefix),
    };
    final bytes = _decodeBase32(input);
    final expectedVersion = switch (kind) {
      StellarAddressKind.account => _accountVersion,
      StellarAddressKind.contract => _contractVersion,
    };
    if (bytes[0] != expectedVersion) {
      throw const InvalidStellarAddress(StellarAddressProblem.wrongPrefix);
    }
    final stored = bytes[33] | (bytes[34] << 8);
    if (_crc16Xmodem(bytes.sublist(0, 33)) != stored) {
      throw const InvalidStellarAddress(StellarAddressProblem.badChecksum);
    }
    return StellarAddress._(input, kind);
  }

  final String value;
  final StellarAddressKind kind;

  @override
  bool operator ==(Object other) =>
      other is StellarAddress && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

const _length = 56;
const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
final _base32Only = RegExp(r'^[A-Z2-7]+$');

// Version bytes from the strkey spec: 6 << 3 for accounts, 2 << 3 for contracts.
const _accountVersion = 6 << 3;
const _contractVersion = 2 << 3;

/// Decodes unpadded base32. 56 characters are exactly 35 bytes:
/// version (1) + key (32) + checksum (2).
List<int> _decodeBase32(String input) {
  final out = <int>[];
  var buffer = 0;
  var bits = 0;
  for (final char in input.split('')) {
    buffer = (buffer << 5) | _alphabet.indexOf(char);
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      out.add((buffer >> bits) & 0xff);
    }
  }
  return out;
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
