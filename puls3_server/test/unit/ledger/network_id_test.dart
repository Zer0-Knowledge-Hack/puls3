// The network id is what every transaction hash is signed over (#255). It is
// derived from the passphrase so the server also runs on a local standalone
// network, which stellar_dart does not know.
import 'dart:convert';
import 'dart:io';

import 'package:puls3_server/src/ledger/network_id.dart';
import 'package:puls3_server/src/ledger/stellar_envelope_codec.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;
import 'package:test/test.dart';

const _standalone = 'Standalone Network ; February 2017';

void main() {
  group('networkIdOf', () {
    test('equals the id stellar_dart has for every network it knows', () {
      for (final network in stellar.StellarNetwork.values) {
        expect(networkIdOf(network.passphrase), network.passphraseHash);
      }
    });

    test(
      'gives a 32-byte id for the standalone network, apart from the rest',
      () {
        final id = networkIdOf(_standalone);

        expect(id, hasLength(32));
        for (final network in stellar.StellarNetwork.values) {
          expect(id, isNot(network.passphraseHash));
        }
      },
    );
  });

  group('StellarEnvelopeCodec.forPassphrase', () {
    final signed =
        (jsonDecode(
                  File(
                    'test/fixtures/escrow_relay/get_transaction_create_job_3_xdr.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>)['envelopeXdr']!
            as String;

    test('hashes like the stellar_dart network for a known passphrase', () {
      final byPassphrase = StellarEnvelopeCodec.forPassphrase(
        stellar.StellarNetwork.testnet.passphrase,
      );
      final byNetwork = StellarEnvelopeCodec(stellar.StellarNetwork.testnet);

      expect(byPassphrase.parse(signed).hash, byNetwork.parse(signed).hash);
    });

    test('accepts the standalone passphrase and hashes on its own network', () {
      final standalone = StellarEnvelopeCodec.forPassphrase(_standalone);
      final testnet = StellarEnvelopeCodec.forPassphrase(
        stellar.StellarNetwork.testnet.passphrase,
      );

      expect(standalone.parse(signed).hash, isNot(testnet.parse(signed).hash));
    });
  });
}
