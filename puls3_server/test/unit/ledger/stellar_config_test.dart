import 'dart:convert';
import 'dart:io';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:test/test.dart';

const _alice = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _bob = 'GCHX6NRPMSB4CIZM3ZLHPOC2VD6DJVAN6IY3NE5QSAMOWJ7N4TAWK6HN';

void main() {
  group('StellarConfig.fromEnvironment', () {
    test('an empty environment equals the testnet defaults', () {
      expect(StellarConfig.fromEnvironment(const {}), StellarConfig.testnet);
    });

    test('a set variable overrides its field and the rest stay default', () {
      final config = StellarConfig.fromEnvironment(const {
        'PULS3_STELLAR_RPC_URL': 'https://rpc.example.test/path',
      });

      expect(config.rpcUrl, Uri.parse('https://rpc.example.test/path'));
      expect(
        config.networkPassphrase,
        StellarConfig.testnet.networkPassphrase,
      );
      expect(config.usdcSac, StellarConfig.testnet.usdcSac);
      expect(config.identityRegistry, StellarConfig.testnet.identityRegistry);
      expect(config.escrow, StellarConfig.testnet.escrow);
      expect(config.simulationSource, StellarConfig.testnet.simulationSource);
      expect(config, isNot(StellarConfig.testnet));
    });

    test('every variable maps to its own field', () {
      final config = StellarConfig.fromEnvironment({
        'PULS3_STELLAR_RPC_URL': 'https://rpc.example.test',
        'PULS3_STELLAR_NETWORK_PASSPHRASE': 'Other Network ; 2030',
        'PULS3_STELLAR_USDC_SAC': StellarConfig.testnet.escrow.value,
        'PULS3_STELLAR_IDENTITY_REGISTRY': StellarConfig.testnet.usdcSac.value,
        'PULS3_STELLAR_ESCROW': StellarConfig.testnet.identityRegistry.value,
        'PULS3_STELLAR_SIMULATION_SOURCE': _bob,
      });

      expect(config.rpcUrl, Uri.parse('https://rpc.example.test'));
      expect(config.networkPassphrase, 'Other Network ; 2030');
      expect(config.usdcSac, StellarConfig.testnet.escrow);
      expect(config.identityRegistry, StellarConfig.testnet.usdcSac);
      expect(config.escrow, StellarConfig.testnet.identityRegistry);
      expect(config.simulationSource, StellarAddress.parse(_bob));
    });

    test('an invalid address throws', () {
      expect(
        () => StellarConfig.fromEnvironment(const {
          'PULS3_STELLAR_ESCROW': 'not-an-address',
        }),
        throwsA(isA<InvalidStellarAddress>()),
      );
      expect(
        () => StellarConfig.fromEnvironment(const {
          'PULS3_STELLAR_SIMULATION_SOURCE': '${_alice}X',
        }),
        throwsA(isA<InvalidStellarAddress>()),
      );
    });
  });

  group('StellarConfig.testnet', () {
    test('mirrors the public values documented in ADR-0001', () {
      expect(
        StellarConfig.testnet.rpcUrl,
        Uri.parse('https://soroban-testnet.stellar.org'),
      );
      expect(
        StellarConfig.testnet.networkPassphrase,
        'Test SDF Network ; September 2015',
      );
    });

    test('contract ids equal contracts/deployments/testnet.json', () {
      final deployment =
          jsonDecode(
                File(
                  '../contracts/deployments/testnet.json',
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      final registry = deployment['identity_registry']! as Map<String, Object?>;
      final escrow = deployment['escrow']! as Map<String, Object?>;
      final tokens = escrow['allowed_tokens']! as List<Object?>;
      final usdc = tokens.single! as Map<String, Object?>;

      expect(
        StellarConfig.testnet.identityRegistry.value,
        registry['contract_id'],
      );
      expect(StellarConfig.testnet.escrow.value, escrow['contract_id']);
      expect(StellarConfig.testnet.usdcSac.value, usdc['sac_id']);
      expect(
        StellarConfig.testnet.simulationSource.value,
        (escrow['constructor']! as Map<String, Object?>)['admin'],
      );
    });
  });
}
