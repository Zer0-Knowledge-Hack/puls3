import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/domain/stellar_explorer.dart';

void main() {
  group('resolveEscrowContractAddress', () {
    const custom = 'CCUSTOMESCROWCUSTOMESCROWCUSTOMESCROWCUSTOMESCROWCUSTOM';

    test('blank define falls back to the testnet escrow', () {
      // --dart-define-from-file=../.env defines PULS3_ESCROW_CONTRACT= as ''.
      expect(resolveEscrowContractAddress(''), testnetEscrowContractAddress);
    });

    test('whitespace-only define falls back to the testnet escrow', () {
      expect(resolveEscrowContractAddress('  	'), testnetEscrowContractAddress);
    });

    test('a set define wins, trimmed', () {
      expect(resolveEscrowContractAddress(' $custom '), custom);
    });

    test('the define is unset in tests', () {
      expect(escrowContractOverride, isEmpty);
    });
  });

  group('stellar_explorer', () {
    test('defaultEscrowContractAddress matches testnet deployment', () {
      expect(
        defaultEscrowContractAddress,
        'CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2',
      );
    });

    test('stellarExpertTxUrl builds testnet tx URL', () {
      const hash =
          '43cd3e8455cafdc08d62a644b8f9dd9174994644b2bdd3e57eaa6893aa5c2437';
      expect(
        stellarExpertTxUrl(hash),
        'https://stellar.expert/explorer/testnet/tx/$hash',
      );
    });

    test('stellarExpertContractUrl builds testnet contract URL', () {
      const contract =
          'CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2';
      expect(
        stellarExpertContractUrl(contract),
        'https://stellar.expert/explorer/testnet/contract/$contract',
      );
    });
  });
}
