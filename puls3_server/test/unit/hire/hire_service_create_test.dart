import 'dart:convert';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/agent/agent_catalog_service.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/hire_service.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:test/test.dart';

import 'hire_test_fakes.dart';

const _alice = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _provider = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';

void main() {
  group('HireService.createHire', () {
    late FakeHireRepository repo;
    late FakeLedger ledger;
    late AgentCatalogService catalog;
    final fixedNow = DateTime.utc(2026, 10, 5, 12, 0, 0);

    Uint8List encodeUtf8(String text) => Uint8List.fromList(utf8.encode(text));

    setUp(() {
      repo = FakeHireRepository();
      ledger = FakeLedger();
      catalog = AgentCatalogService(ledger);

      // Seed agent 7 in fake ledger
      ledger.wallets[7] = StellarAddress.parse(_provider);
      ledger.metadata[7] = {
        'id': encodeUtf8('agt-001'),
        'name': encodeUtf8('Test Agent'),
        'description': encodeUtf8('A helpful test agent for verification.'),
        'skills': encodeUtf8(jsonEncode(['coding', 'testing'])),
        'priceUsdcStroops': encodeUtf8('5000000'),
        'puls3.manifestVersion': encodeUtf8('1'),
      };
    });

    HireService createService({Map<String, String>? env}) {
      return HireService(
        repo: repo,
        registry: ledger,
        catalog: catalog,
        environment: env ?? {'PULS3_HIRE_JOB_DURATION_SECONDS': '86400'},
        now: () => fixedNow,
      );
    }

    test('returns the requested hire on happy path', () async {
      final service = createService();
      final view = await service.createHire(agentId: 7, consumer: _alice);

      expect(view.hireId, 1);
      expect(view.agentRegistryId, 7);
      expect(view.consumer, _alice);
      expect(view.priceStroops, 5000000);
      expect(view.status, HireStatus.requested.name);

      final persisted = await repo.findById(HireId(view.hireId));
      expect(persisted, isNotNull);
      expect(persisted!.status, HireStatus.requested);
      expect(persisted.agentId.value, 7);
      expect(persisted.consumer.value, _alice);
      expect(persisted.price.stroops, 5000000);
      expect(persisted.manifestVersion, 1);
    });

    test('expiredAt = now + duration', () async {
      final service = createService(
        env: {'PULS3_HIRE_JOB_DURATION_SECONDS': '3600'},
      );
      final view = await service.createHire(agentId: 7, consumer: _alice);

      final expectedNowSec = fixedNow.millisecondsSinceEpoch ~/ 1000;
      expect(repo.expiredAtByHire[view.hireId], expectedNowSec + 3600);
    });

    test('AgentUnavailable when the agent is unknown', () async {
      final service = createService();

      await expectLater(
        () => service.createHire(agentId: 99, consumer: _alice),
        throwsA(
          isA<AgentUnavailable>().having((e) => e.agentId, 'agentId', 99),
        ),
      );
      expect(repo.hires, isEmpty);
    });

    test('AgentUnavailable when the agent has no wallet', () async {
      ledger.wallets.remove(7);
      final service = createService();

      await expectLater(
        () => service.createHire(agentId: 7, consumer: _alice),
        throwsA(
          isA<AgentUnavailable>().having((e) => e.agentId, 'agentId', 7),
        ),
      );
      expect(repo.hires, isEmpty);
    });

    test('HireRequestInvalid when manifest version missing or invalid', () async {
      final service = createService();

      // Missing manifest version
      ledger.metadata[7]!.remove('puls3.manifestVersion');
      await expectLater(
        () => service.createHire(agentId: 7, consumer: _alice),
        throwsA(isA<HireRequestInvalid>()),
      );
      expect(repo.hires, isEmpty);

      // Non-integer manifest version
      ledger.metadata[7]!['puls3.manifestVersion'] = encodeUtf8('not-an-int');
      await expectLater(
        () => service.createHire(agentId: 7, consumer: _alice),
        throwsA(isA<HireRequestInvalid>()),
      );
      expect(repo.hires, isEmpty);

      // Manifest version < 1
      ledger.metadata[7]!['puls3.manifestVersion'] = encodeUtf8('0');
      await expectLater(
        () => service.createHire(agentId: 7, consumer: _alice),
        throwsA(isA<HireRequestInvalid>()),
      );
      expect(repo.hires, isEmpty);
    });

    test('HireRequestInvalid on invalid consumer address', () async {
      final service = createService();
      await expectLater(
        () => service.createHire(agentId: 7, consumer: 'not-an-address'),
        throwsA(isA<HireRequestInvalid>()),
      );
      expect(repo.hires, isEmpty);
    });

    test('HireConfigurationMissing when setting missing or invalid', () async {
      // Missing
      var service = createService(env: {});
      await expectLater(
        () => service.createHire(agentId: 7, consumer: _alice),
        throwsA(
          isA<HireConfigurationMissing>().having(
            (e) => e.setting,
            'setting',
            'PULS3_HIRE_JOB_DURATION_SECONDS',
          ),
        ),
      );
      expect(repo.hires, isEmpty);

      // Invalid (string not an int)
      service = createService(
        env: {'PULS3_HIRE_JOB_DURATION_SECONDS': 'invalid'},
      );
      await expectLater(
        () => service.createHire(agentId: 7, consumer: _alice),
        throwsA(
          isA<HireConfigurationMissing>().having(
            (e) => e.setting,
            'setting',
            'PULS3_HIRE_JOB_DURATION_SECONDS',
          ),
        ),
      );
      expect(repo.hires, isEmpty);

      // Invalid (<= 0)
      service = createService(env: {'PULS3_HIRE_JOB_DURATION_SECONDS': '0'});
      await expectLater(
        () => service.createHire(agentId: 7, consumer: _alice),
        throwsA(isA<HireConfigurationMissing>()),
      );
      expect(repo.hires, isEmpty);
    });

    test('HireLedgerUnavailable on wallet read failure', () async {
      // Wallet read failure
      ledger.walletError = const LedgerUnavailable('Stellar RPC timeout');
      var service = createService();
      await expectLater(
        () => service.createHire(agentId: 7, consumer: _alice),
        throwsA(isA<HireLedgerUnavailable>()),
      );
      expect(repo.hires, isEmpty);
    });
  });
}
