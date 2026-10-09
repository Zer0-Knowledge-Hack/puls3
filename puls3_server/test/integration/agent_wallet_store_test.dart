import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/agent/agent_wallet_store.dart';
import 'package:puls3_server/src/agent/secret_cipher.dart';
import 'package:puls3_server/src/agent/serverpod_agent_wallet_store.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

const _owner = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _walletA = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';
const _walletB = 'GDWVBEPVODIA7D3A2II7LBR7FLD4TZDFOVWWVAXUAYPV4F4J5ZIIKWNF';

const _secret = EncryptedSecret(
  ciphertext: 'Y2lwaGVy',
  nonce: 'bm9uY2U=',
  mac: 'bWFj',
  keyVersion: 2,
);

void main() {
  group('ServerpodAgentWalletStore integration', () {
    withServerpod('agent wallet persistence', (sessionBuilder, _) {
      test('saves the encrypted secret and finds it by key and address',
          () async {
        final session = sessionBuilder.build();
        final store = ServerpodAgentWalletStore(session);

        final saved = await store.save(
          owner: StellarAddress.parse(_owner),
          address: StellarAddress.parse(_walletA),
          idempotencyKey: 'it-wallet-1',
          secret: _secret,
          createdAt: DateTime.utc(2026, 10, 9),
        );

        expect(saved.id, greaterThan(0));
        expect(saved.idempotencyKey, 'it-wallet-1');
        expect(saved.agentId, isNull);

        final byKey = await store.findByIdempotencyKey('it-wallet-1');
        expect(byKey, isNotNull);
        expect(byKey!.address, StellarAddress.parse(_walletA));
        expect(byKey.secret.ciphertext, 'Y2lwaGVy');
        expect(byKey.secret.keyVersion, 2);

        final byAddress = await store.findByAddress(
          StellarAddress.parse(_walletA),
        );
        expect(byAddress!.idempotencyKey, 'it-wallet-1');
      });

      test('a duplicate idempotency key is a conflict', () async {
        final session = sessionBuilder.build();
        final store = ServerpodAgentWalletStore(session);

        await store.save(
          owner: StellarAddress.parse(_owner),
          address: StellarAddress.parse(_walletB),
          idempotencyKey: 'it-wallet-2',
          secret: _secret,
          createdAt: DateTime.utc(2026, 10, 9),
        );

        await expectLater(
          store.save(
            owner: StellarAddress.parse(_owner),
            address: StellarAddress.parse(_owner),
            idempotencyKey: 'it-wallet-2',
            secret: _secret,
            createdAt: DateTime.utc(2026, 10, 9),
          ),
          throwsA(isA<AgentWalletConflict>()),
        );
      });

      test('an unknown key and address have no wallet', () async {
        final session = sessionBuilder.build();
        final store = ServerpodAgentWalletStore(session);

        expect(await store.findByIdempotencyKey('nope'), isNull);
        expect(
          await store.findByAddress(StellarAddress.parse(_owner)),
          isNull,
        );
      });
    });
  }, tags: 'integration');
}
