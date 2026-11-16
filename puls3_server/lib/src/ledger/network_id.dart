import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:stellar_dart/stellar_dart.dart' as stellar;

/// The passphrase of `stellar/quickstart --local`, the standalone network of
/// the local sandbox (#253). Stellar's SDK knows only the public, test and
/// future networks, so this one is added here.
const standaloneNetworkPassphrase = 'Standalone Network ; February 2017';

/// The network id of [passphrase]: the SHA-256 that prefixes every transaction
/// signature payload.
///
/// The public, test and future networks come from `stellar_dart`. The local
/// standalone network is the only other one accepted. Any other passphrase
/// throws, so a mistyped mainnet passphrase never signs for another network.
List<int> networkIdOf(String passphrase) {
  if (passphrase == standaloneNetworkPassphrase) {
    return crypto.sha256.convert(utf8.encode(passphrase)).bytes;
  }
  return stellar.StellarNetwork.fromPassphrase(passphrase).passphraseHash;
}
