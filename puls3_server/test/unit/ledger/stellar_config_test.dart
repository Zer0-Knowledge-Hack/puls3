import 'dart:convert';
import 'dart:io';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/ledger/classic_asset.dart';
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
        'PULS3_STELLAR_REPUTATION_REGISTRY':
            StellarConfig.testnet.identityRegistry.value,
      });

      expect(config.rpcUrl, Uri.parse('https://rpc.example.test'));
      expect(config.networkPassphrase, 'Other Network ; 2030');
      expect(config.usdcSac, StellarConfig.testnet.escrow);
      expect(config.identityRegistry, StellarConfig.testnet.usdcSac);
      expect(config.escrow, StellarConfig.testnet.identityRegistry);
      expect(config.simulationSource, StellarAddress.parse(_bob));
      expect(
        config.reputationRegistry,
        StellarConfig.testnet.identityRegistry,
      );
    });

    test('the Reputation Registry defaults to the deployed testnet one', () {
      final deployed = StellarConfig.testnet.reputationRegistry;

      expect(deployed, isNotNull);
      expect(
        StellarConfig.fromEnvironment(const {}).reputationRegistry,
        deployed,
      );
      expect(
        StellarConfig.fromEnvironment(const {
          'PULS3_STELLAR_REPUTATION_REGISTRY': '',
        }).reputationRegistry,
        deployed,
      );
    });

    test('an invalid Reputation Registry address throws', () {
      expect(
        () => StellarConfig.fromEnvironment(const {
          'PULS3_STELLAR_REPUTATION_REGISTRY': 'not-an-address',
        }),
        throwsA(isA<InvalidStellarAddress>()),
      );
    });

    test('the Reputation Registry takes part in equality', () {
      final configured = StellarConfig.fromEnvironment({
        'PULS3_STELLAR_REPUTATION_REGISTRY': StellarConfig.testnet.escrow.value,
      });

      expect(configured, isNot(StellarConfig.testnet));
    });

    group('usdc asset', () {
      const name = 'PULS3_STELLAR_USDC_ASSET';

      test('unset keeps the Circle testnet USDC', () {
        final asset = StellarConfig.fromEnvironment(const {}).usdcAsset;

        expect(asset.code, 'USDC');
        expect(
          asset.issuer,
          'GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5',
        );
      });

      test('CODE:ISSUER overrides it', () {
        final config = StellarConfig.fromEnvironment(const {
          name: 'EURC:$_alice',
        });

        expect(config.usdcAsset, ClassicAsset.parse('EURC:$_alice'));
        expect(config, isNot(StellarConfig.testnet));
      });

      for (final bad in ['USDC', 'USDC:nope', 'TOO-LONG-CODE1:$_alice']) {
        test('"$bad" throws', () {
          expect(
            () => StellarConfig.fromEnvironment({name: bad}),
            throwsA(anything),
          );
        });
      }
    });

    group('rpc timeout', () {
      const name = 'PULS3_STELLAR_RPC_TIMEOUT_SECONDS';

      test('unset or empty keeps the 8 s default', () {
        expect(
          StellarConfig.fromEnvironment(const {}).rpcTimeout,
          const Duration(seconds: 8),
        );
        expect(
          StellarConfig.fromEnvironment(const {name: ''}).rpcTimeout,
          const Duration(seconds: 8),
        );
        expect(StellarConfig.testnet.rpcTimeout, const Duration(seconds: 8));
      });

      test('a positive whole number of seconds is used', () {
        final config = StellarConfig.fromEnvironment(const {name: '20'});

        expect(config.rpcTimeout, const Duration(seconds: 20));
        expect(config, isNot(StellarConfig.testnet));
        expect(config.hashCode, isNot(StellarConfig.testnet.hashCode));
      });

      for (final bad in ['abc', '1.5', '0', '-3', ' ']) {
        test('"$bad" throws an ArgumentError naming the variable', () {
          expect(
            () => StellarConfig.fromEnvironment({name: bad}),
            throwsA(
              isA<ArgumentError>().having((e) => e.name, 'name', name),
            ),
          );
        });
      }
    });

    group('previous escrows (#273)', () {
      final old = StellarConfig.testnet.identityRegistry.value;
      final older = StellarConfig.testnet.usdcSac.value;

      test('none by default', () {
        expect(
          StellarConfig.fromEnvironment(const {}).previousEscrows,
          isEmpty,
        );
        expect(
          StellarConfig.fromEnvironment(const {
            'PULS3_STELLAR_PREVIOUS_ESCROWS': '',
          }).previousEscrows,
          isEmpty,
        );
      });

      test('a comma-separated list of contracts, in order', () {
        final config = StellarConfig.fromEnvironment({
          'PULS3_STELLAR_PREVIOUS_ESCROWS': '$old, $older ,',
        });

        expect(config.previousEscrows, [
          StellarAddress.parse(old),
          StellarAddress.parse(older),
        ]);
      });

      test('trusted escrows are the configured one and the previous ones', () {
        final config = StellarConfig.fromEnvironment({
          'PULS3_STELLAR_PREVIOUS_ESCROWS': old,
        });

        expect(config.trustedEscrows, {
          StellarConfig.testnet.escrow,
          StellarAddress.parse(old),
        });
      });

      test('the configured escrow listed again is trusted once', () {
        final config = StellarConfig.fromEnvironment({
          'PULS3_STELLAR_PREVIOUS_ESCROWS':
              '${StellarConfig.testnet.escrow.value},$old',
        });

        expect(config.trustedEscrows, hasLength(2));
      });

      test('an invalid address throws', () {
        expect(
          () => StellarConfig.fromEnvironment(const {
            'PULS3_STELLAR_PREVIOUS_ESCROWS': 'not-an-address',
          }),
          throwsA(isA<InvalidStellarAddress>()),
        );
      });

      test('a list changes the configuration', () {
        expect(
          StellarConfig.fromEnvironment({
            'PULS3_STELLAR_PREVIOUS_ESCROWS': old,
          }),
          isNot(StellarConfig.testnet),
        );
      });
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

    test('the Reputation Registry id follows the deployment record', () {
      final deployment =
          jsonDecode(
                File(
                  '../contracts/deployments/testnet.json',
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      // The slot is `null` until #14 is deployed; then it holds
      // `{"contract_id": ...}` like the other registries.
      final slot = deployment['reputation_registry'];
      final expected = slot == null
          ? null
          : (slot as Map<String, Object?>)['contract_id'];

      expect(StellarConfig.testnet.reputationRegistry?.value, expected);
    });
  });
}
