import 'dart:convert';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/agent/agent_catalog_service.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/hire_lifecycle_store.dart';
import 'package:puls3_server/src/hire/hire_relay_config.dart';
import 'package:puls3_server/src/hire/hire_service.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart';
import 'package:serverpod/serverpod.dart' show Transaction;
import 'package:test/test.dart';

import '../../support/in_memory_hire_lifecycle_store.dart';
import '../../support/relay_rig.dart';

/// A store whose first insert loses a race: another call stored the hire
/// for the same request just before.
final class _RacingHires extends InMemoryHireLifecycleStore {
  _RacingHires(this.winner);

  final NewHire winner;
  var raced = false;

  @override
  Future<HireRow> insertHire(NewHire hire, {Transaction? transaction}) async {
    if (!raced) {
      raced = true;
      await super.insertHire(winner);
      throw const HireRequestConflict();
    }
    return super.insertHire(hire, transaction: transaction);
  }
}

void main() {
  group('HireService.createHire', () {
    late RelayRig rig;
    late Map<String, String> env;

    Uint8List utf8Bytes(String text) => Uint8List.fromList(utf8.encode(text));

    HireService serviceOn(RelayRig on, Map<String, String> environment) =>
        HireService(
          hires: on.hires,
          preparations: on.preparations,
          relay: on.service,
          registry: on.ledger,
          catalog: AgentCatalogService(on.ledger),
          config: HireRelayConfig(environment),
          now: () => on.clock,
        );

    void seedAgent(RelayRig on) {
      on.ledger.metadata[7] = {
        'id': utf8Bytes('agt-001'),
        'name': utf8Bytes('Test Agent'),
        'description': utf8Bytes('A helpful test agent for verification.'),
        'skills': utf8Bytes(jsonEncode(['coding', 'testing'])),
        'priceUsdcStroops': utf8Bytes('5000000'),
        'puls3.manifestVersion': utf8Bytes('1'),
      };
    }

    Future<CreateHireResult> create(
      HireService service, {
      int agentId = 7,
      String consumer = alice,
      String input = 'summarise this',
      String requestId = 'request-1',
    }) => service.createHire(
      agentId: agentId,
      consumer: consumer,
      input: input,
      requestId: requestId,
    );

    late HireService service;

    setUp(() {
      rig = RelayRig();
      env = relayEnvironment();
      seedAgent(rig);
      service = serviceOn(rig, env);
    });

    group('a new request', () {
      test(
        'stores a hire with no status and prepares its create_job',
        () async {
          final result = await create(service);

          final stored = rig.hires.all.single;
          expect(stored.id, result.hire.id);
          expect(stored.consumer, alice);
          expect(stored.agentId, 7);
          expect(stored.price, price);
          expect(stored.manifestVersion, 1);
          expect(stored.input, 'summarise this');
          expect(stored.requestId, 'request-1');
          expect(stored.jobId, isNull);
          expect(result.hire.status, isNull);
          expect(result.hire.agentId, 7);
          expect(result.hire.consumer, alice);
          expect(result.hire.price, price);

          final prepared = result.preparedCreateJob!;
          expect(prepared.purpose, 'createJob');
          expect(prepared.signer, alice);
          final row = (await rig.preparations.findByPreparationId(
            prepared.preparationId,
          ))!;
          expect(row.hireId, result.hire.id);
          expect(row.purpose, SubmissionPurpose.createJob);
          expect(row.transactionHash, prepared.transaction);
        },
      );

      test('expired_at is now plus the configured duration', () async {
        final result = await create(service);

        final expiredAt =
            rig.clock.millisecondsSinceEpoch ~/ 1000 + jobDurationSeconds;
        expect(rig.hires.all.single.expiredAt, expiredAt);
        final row = (await rig.preparations.findByPreparationId(
          result.preparedCreateJob!.preparationId,
        ))!;
        expect(row.jobExpiredAt, expiredAt);
      });

      test(
        'create_job names the agent wallet, consumer, USDC and price',
        () async {
          await create(service);

          final spec = rig.codec.built.single.spec;
          final expiredAt =
              rig.clock.millisecondsSinceEpoch ~/ 1000 + jobDurationSeconds;
          String call(List<ScArg> args) => base64Encode(
            encodeInvokeHostFunction(
              contract: StellarConfig.testnet.escrow,
              function: 'create_job',
              args: args,
            ),
          );
          expect(
            call(spec.args),
            call([
              ScArg.address(rig.wallet),
              ScArg.address(StellarAddress.parse(agentWallet)),
              ScArg.address(rig.wallet),
              ScArg.u64(expiredAt),
              const ScArg.string(''),
              const ScArg.voidValue(),
              const ScArg.u32(7),
              ScArg.address(StellarConfig.testnet.usdcSac),
              const ScArg.i128(price),
            ]),
          );
        },
      );

      test(
        'the first preparation failing persists no hire, and a retry creates it',
        () async {
          rig.accounts.simulationFailure = Puls3ApiException(
            code: 'ChainUnavailable',
            details: {'reason': 'simulationFailed'},
          );

          await expectLater(
            create(service),
            throwsA(
              isA<Puls3ApiException>().having(
                (e) => e.code,
                'code',
                'ChainUnavailable',
              ),
            ),
          );
          expect(rig.hires.all, isEmpty);
          expect(rig.preparations.all, isEmpty);

          rig.accounts.simulationFailure = null;
          final retried = await create(service);

          expect(rig.hires.all.single.id, retried.hire.id);
          expect(retried.preparedCreateJob, isNotNull);
        },
      );
    });

    group('retries with the same requestId', () {
      test('return the existing hire with its current preparation', () async {
        final first = await create(service);

        final again = await create(service);

        expect(again.hire.id, first.hire.id);
        expect(rig.hires.all, hasLength(1));
        expect(
          again.preparedCreateJob!.preparationId,
          first.preparedCreateJob!.preparationId,
        );
        expect(rig.preparations.all, hasLength(1));
      });

      test('prepare a fresh one when the previous expired unused', () async {
        final first = await create(service);
        rig.clock = first.preparedCreateJob!.expiresAt.add(
          const Duration(seconds: 1),
        );

        final again = await create(service);

        expect(again.hire.id, first.hire.id);
        expect(
          again.preparedCreateJob!.preparationId,
          isNot(first.preparedCreateJob!.preparationId),
        );
        final old = (await rig.preparations.findByPreparationId(
          first.preparedCreateJob!.preparationId,
        ))!;
        expect(old.supersededAt, isNotNull);
      });

      test(
        'return no preparation once the create_job is submitted or confirmed',
        () async {
          final first = await create(service);
          final record = await rig.record(
            first.hire.id,
            SubmissionPurpose.createJob,
          );

          final submitted = await create(service);
          await rig.submissions.markConfirmed(record.id);
          final confirmed = await create(service);

          expect(submitted.hire.id, first.hire.id);
          expect(submitted.preparedCreateJob, isNull);
          expect(confirmed.preparedCreateJob, isNull);
        },
      );

      test('prepare again when the submitted create_job failed', () async {
        final first = await create(service);
        // A submit claims the preparation before it stores its record.
        await rig.preparations.claim(first.preparedCreateJob!.preparationId);
        await rig.record(
          first.hire.id,
          SubmissionPurpose.createJob,
          failedWith: SubmissionOutcomeCode.submissionRejected,
        );

        final again = await create(service);

        expect(again.preparedCreateJob, isNotNull);
        expect(
          again.preparedCreateJob!.preparationId,
          isNot(first.preparedCreateJob!.preparationId),
        );
      });

      test(
        'with another agent or input fail IdempotencyKeyReused and change nothing',
        () async {
          await create(service);

          for (final (agentId, input) in [
            (8, 'summarise this'),
            (7, 'something else'),
          ]) {
            await expectLater(
              create(service, agentId: agentId, input: input),
              throwsA(
                isA<Puls3ApiException>().having(
                  (e) => e.code,
                  'code',
                  'IdempotencyKeyReused',
                ),
              ),
            );
          }
          expect(rig.hires.all, hasLength(1));
          expect(rig.preparations.all, hasLength(1));
        },
      );

      test(
        'a lost insert race returns the winner instead of failing',
        () async {
          final racing = _RacingHires(
            const NewHire(
              consumer: alice,
              agentId: 7,
              price: price,
              manifestVersion: 1,
              expiredAt: 1,
              requestId: 'request-1',
              input: 'summarise this',
            ),
          );
          final raced = RelayRig(hires: racing);
          seedAgent(raced);

          final result = await create(serviceOn(raced, env));

          expect(racing.all, hasLength(1));
          expect(result.hire.id, racing.all.single.id);
          expect(result.preparedCreateJob, isNotNull);
        },
      );
    });

    test('requestId is scoped per wallet', () async {
      final alices = await create(service);
      final strangers = await create(service, consumer: stranger);

      expect(alices.hire.id, isNot(strangers.hire.id));
      expect(strangers.hire.consumer, stranger);
      expect(rig.hires.all, hasLength(2));
    });

    test('a blank requestId is HireRequestInvalid', () async {
      await expectLater(
        create(service, requestId: ' '),
        throwsA(isA<HireRequestInvalid>()),
      );
      expect(rig.hires.all, isEmpty);
    });

    test(
      'AgentUnavailable when the agent is unknown or has no wallet',
      () async {
        await expectLater(
          create(service, agentId: 99),
          throwsA(isA<AgentUnavailable>().having((e) => e.agentId, 'id', 99)),
        );
        rig.ledger.wallets.remove(7);
        await expectLater(
          // A new service: the catalog of the first one is cached.
          create(serviceOn(rig, env)),
          throwsA(isA<AgentUnavailable>().having((e) => e.agentId, 'id', 7)),
        );
        expect(rig.hires.all, isEmpty);
      },
    );

    test(
      'HireRequestInvalid when the manifest version is missing or invalid',
      () async {
        final metadata = rig.ledger.metadata[7]!;
        for (final version in [null, 'not-an-int', '0']) {
          version == null
              ? metadata.remove('puls3.manifestVersion')
              : metadata['puls3.manifestVersion'] = utf8Bytes(version);

          await expectLater(
            create(service),
            throwsA(isA<HireRequestInvalid>()),
          );
        }
        expect(rig.hires.all, isEmpty);
      },
    );

    test('HireRequestInvalid on an invalid consumer address', () async {
      await expectLater(
        create(service, consumer: 'not-an-address'),
        throwsA(isA<HireRequestInvalid>()),
      );
      expect(rig.hires.all, isEmpty);
    });

    test('a missing setting fails naming it and persists nothing', () async {
      for (final key in [
        HireRelayConfig.jobDurationKey,
        HireRelayConfig.preparationValidityKey,
        HireRelayConfig.inclusionFeeKey,
      ]) {
        final broken = {...env}..remove(key);
        final bare = RelayRig(environment: broken);
        seedAgent(bare);

        await expectLater(
          create(serviceOn(bare, broken)),
          throwsA(
            isA<HireConfigurationMissing>().having(
              (e) => e.setting,
              'setting',
              key,
            ),
          ),
          reason: key,
        );
        expect(bare.hires.all, isEmpty, reason: key);
        expect(bare.preparations.all, isEmpty, reason: key);
      }
    });

    test('HireLedgerUnavailable when the wallet read fails', () async {
      rig.ledger.walletError = const LedgerUnavailable('Stellar RPC timeout');

      await expectLater(
        create(service),
        throwsA(isA<HireLedgerUnavailable>()),
      );
      expect(rig.hires.all, isEmpty);
    });
  });
}
