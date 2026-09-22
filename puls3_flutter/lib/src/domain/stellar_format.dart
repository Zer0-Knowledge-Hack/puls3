import 'dart:math';

const _base32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
const _hex = '0123456789abcdef';

/// Shortens a Stellar strkey for display: `GABC…WXYZ`.
String shortenAddress(String address, {int head = 4, int tail = 4}) {
  if (address.length <= head + tail + 1) return address;
  return '${address.substring(0, head)}…${address.substring(address.length - tail)}';
}

/// Generates fake, plausible-looking Stellar identifiers for the demo.
/// None of these values exist on any network.
class FakeLedgerIds {
  FakeLedgerIds([Random? random]) : _random = random ?? Random();

  final Random _random;

  /// A 56-character strkey with the given version prefix (G for accounts,
  /// C for Soroban contracts).
  String strkey(String prefix) {
    final buffer = StringBuffer(prefix)..write('ABCD'[_random.nextInt(4)]);
    for (var i = 0; i < 54; i++) {
      buffer.write(_base32[_random.nextInt(_base32.length)]);
    }
    return buffer.toString();
  }

  String accountAddress() => strkey('G');

  String contractId() => strkey('C');

  /// A 64-character lowercase hex transaction hash.
  String txHash() =>
      List.generate(64, (_) => _hex[_random.nextInt(_hex.length)]).join();
}
