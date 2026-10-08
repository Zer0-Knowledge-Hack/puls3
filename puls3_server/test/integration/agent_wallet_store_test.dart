import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/agent/secret_cipher.dart';
import 'package:puls3_server/src/agent/serverpod_agent_wallet_store.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

const _owner = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _address = 'GDWVBEPVODIA7D3A2II7LBR7FLD4TZDFOVWWVAXUAYPV4F4J5ZIIKWNF';

void main() {
  group('ServerpodAgentWalletStore integration', () {
    withServerpod('agent wallet persistence', (sessionBuilder, _) {
      test('saves the encrypted secret and finds it by address', () async {
        final session = sessionBuilder.build();
        final store = ServerpodAgentWalletStore(session);

        final saved = await store.save(
          owner: StellarAddress.parse(_owner),
          address: StellarAddress.parse(_address),
          secret: const EncryptedSecret(
            ciphertext: 'Y2lwaGVy',
            nonce: 'bm9uY2U=',
            mac: 'bWFj',
            keyVersion: 2,
          ),
          createdAt: DateTime.utc(2026, 10, 8),
        );

        expect(saved.id, greaterThan(0));
        expect(saved.agentId, isNull);

        final found = await store.findByAddress(
          StellarAddress.parse(_address),
        );
        expect(found, isNotNull);
        expect(found!.owner.value, _owner);
        expect(found.secret.ciphertext, 'Y2lwaGVy');
        expect(found.secret.nonce, 'bm9uY2U=');
        expect(found.secret.mac, 'bWFj');
        expect(found.secret.keyVersion, 2);
      });

      test('an unknown address has no wallet', () async {
        final session = sessionBuilder.build();
        final store = ServerpodAgentWalletStore(session);

        expect(
          await store.findByAddress(StellarAddress.parse(_owner)),
          isNull,
        );
      });
    });
  }, tags: 'integration');
}
