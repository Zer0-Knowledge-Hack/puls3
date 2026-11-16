import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:puls3_server/src/ledger/network_id.dart';
import 'package:puls3_server/src/ledger/stellar_envelope_codec.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;
import 'package:test/test.dart';

void main() {
  group('networkIdOf', () {
    test('the local standalone network is the SHA-256 of its passphrase', () {
      expect(
        networkIdOf(standaloneNetworkPassphrase),
        crypto.sha256.convert(utf8.encode(standaloneNetworkPassphrase)).bytes,
      );
    });

    test('the public, test and future networks keep the SDK ids', () {
      for (final network in stellar.StellarNetwork.values) {
        expect(networkIdOf(network.passphrase), network.passphraseHash);
      }
    });

    test('any other passphrase still throws', () {
      expect(
        () => networkIdOf('Public Global Stellar Network ; September 2016'),
        throwsA(anything),
      );
      expect(
        () => StellarEnvelopeCodec.forPassphrase('Standalone Network'),
        throwsA(anything),
      );
    });

    test('the envelope codec accepts the standalone passphrase', () {
      expect(
        () => StellarEnvelopeCodec.forPassphrase(standaloneNetworkPassphrase),
        returnsNormally,
      );
    });
  });
}
