import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/ledger/strkey.dart';
import 'package:test/test.dart';

String _hex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('rawKey', () {
    // The G key is the one stellar-cli wrote into the recorded envelope. The
    // C key is the contract hash the RPC reported for the same contract.
    test('decodes an account address to its 32 key bytes', () {
      final bytes = rawKey(
        StellarAddress.parse(
          'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
        ),
      );

      expect(bytes.length, 32);
      expect(
        _hex(bytes),
        '0b4c57a6dc82a43c051d40acd4d86a71bc098ed287e75e74d2b024119366e4c4',
      );
    });

    test('decodes a contract address to its 32 hash bytes', () {
      final bytes = rawKey(
        StellarAddress.parse(
          'CD5QZOKGRBV35C5SDT6PG7S72XGG4BHQAC2L56YLNBJDUL4LDMTXFIJJ',
        ),
      );

      expect(bytes.length, 32);
      expect(
        _hex(bytes),
        'fb0cb946886bbe8bb21cfcf37e5fd5cc6e04f000b4befb0b68523a2f8b1b2772',
      );
    });

    test('a different account decodes to different bytes', () {
      final bytes = rawKey(
        StellarAddress.parse(
          'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
        ),
      );

      expect(
        _hex(bytes),
        '02a6dfa7b5e989d8be7450ac3b4d3cc0f4fbee4179e9bdfa4119535ae60c2e83',
      );
    });
  });
}
