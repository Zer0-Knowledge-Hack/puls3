import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// The network id of [passphrase]: the SHA-256 of its UTF-8 bytes, which is
/// what every transaction hash is signed over.
///
/// `stellar_dart` only knows the public, test and future networks. Deriving
/// the id lets the server also run against a local standalone network (#253),
/// and gives the same bytes as `StellarNetwork.passphraseHash` for the known
/// ones.
Uint8List networkIdOf(String passphrase) =>
    Uint8List.fromList(sha256.convert(utf8.encode(passphrase)).bytes);
