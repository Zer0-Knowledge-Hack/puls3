import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/ledger/envelope_codec.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart';
import 'package:test/test.dart';

import '../support/relay_rig.dart';

final _escrow = StellarConfig.testnet.escrow;
final _usdc = StellarConfig.testnet.usdcSac;
final _wallet = StellarAddress.parse(alice);
final _provider = StellarAddress.parse(agentWallet);

/// The XDR of a call, the form tests compare argument lists in.
String _call(String function, List<ScArg> args) => base64Encode(
  encodeInvokeHostFunction(contract: _escrow, function: function, args: args),
);

String _builtCall(RelayRig rig) {
  final spec = rig.codec.built.last.spec;
  return base64Encode(
    encodeInvokeHostFunction(
      contract: spec.contract,
      function: spec.function,
      args: spec.args,
    ),
  );
}

void main() {
  late RelayRig rig;

  setUp(() => rig = RelayRig());

  group('prepareFund', () {
    test(
      'returns an unsigned fund envelope bound to the session wallet',
      () async {
        final hire = await rig.hire(status: HireStatus.open);

        final prepared = await rig.service.prepareFund(_wallet, hire.id);

        final built = rig.codec.built.single;
        expect(prepared.purpose, 'fund');
        expect(prepared.signer, alice);
        expect(
          prepared.networkPassphrase,
          StellarConfig.testnet.networkPassphrase,
        );
        expect(prepared.preparationId, 'prep-1');
        expect(prepared.authorizationEntryXdr, isNull);
        expect(prepared.signatureExpirationLedger, isNull);
        expect(prepared.unsignedTransactionXdr, isNotEmpty);
        expect(
          prepared.transaction,
          PreparedEnvelope(
            envelopeXdr: '',
            body: Uint8List(0),
            hash: rig.codec.parse(prepared.unsignedTransactionXdr!).hash,
          ).hashHex,
        );
        expect(
          prepared.expiresAt,
          DateTime.fromMillisecondsSinceEpoch(
            rig.validUntilSeconds * 1000,
            isUtc: true,
          ),
        );
        expect(built.spec.source, _wallet);
        expect(built.spec.contract, _escrow);
        expect(built.spec.validUntil, rig.validUntilSeconds);
        expect(built.spec.inclusionFee, inclusionFee);
      },
    );

    test('fund carries Hire.price and the platform fee from config', () async {
      final hire = await rig.hire(status: HireStatus.open);

      await rig.service.prepareFund(_wallet, hire.id);

      expect(
        _builtCall(rig),
        _call('fund', [
          ScArg.address(_wallet),
          const ScArg.u64(3),
          const ScArg.i128(price),
          const ScArg.u32(platformFeeBps),
        ]),
      );
    });

    test('stores the preparation with the hash, sequence and window', () async {
      final hire = await rig.hire(status: HireStatus.open);

      final prepared = await rig.service.prepareFund(_wallet, hire.id);

      final stored = (await rig.preparations.findByPreparationId(
        prepared.preparationId,
      ))!;
      expect(stored.hireId, hire.id);
      expect(stored.purpose, SubmissionPurpose.fund);
      expect(stored.signer, alice);
      expect(stored.transactionHash, prepared.transaction);
      expect(stored.unsignedEnvelopeXdr, prepared.unsignedTransactionXdr);
      expect(stored.sequence, 101);
      expect(stored.validUntil, prepared.expiresAt);
      expect(stored.supersededAt, isNull);
      expect(stored.submittedAt, isNull);
    });

    test('reads the sequence, then simulates, then builds', () async {
      final hire = await rig.hire(status: HireStatus.open);
      rig.accounts.sequence = 4200;

      await rig.service.prepareFund(_wallet, hire.id);

      expect(rig.accounts.sequenceReads, [_wallet]);
      expect(rig.accounts.simulated.single.accountSequence, 4200);
      expect(rig.codec.built.single.spec.accountSequence, 4200);
      expect(rig.codec.built.single.sim, same(rig.accounts.simulation));
    });

    test(
      'without a USDC balance fails ChainUnavailable and persists nothing',
      () async {
        final hire = await rig.hire(status: HireStatus.open);
        rig.accounts.simulationFailure = Puls3ApiException(
          code: 'ChainUnavailable',
          details: {'reason': 'simulationFailed'},
        );

        await expectLater(
          rig.service.prepareFund(_wallet, hire.id),
          throwsA(
            api('ChainUnavailable', details: {'reason': 'simulationFailed'}),
          ),
        );
        expect(rig.preparations.all, isEmpty);
      },
    );

    test(
      'an unreadable account fails ChainUnavailable and persists nothing',
      () async {
        final hire = await rig.hire(status: HireStatus.open);
        rig.accounts.sequenceFailure = Puls3ApiException(
          code: 'ChainUnavailable',
          details: {'reason': 'simulationFailed'},
        );

        await expectLater(
          rig.service.prepareFund(_wallet, hire.id),
          throwsA(api('ChainUnavailable')),
        );
        expect(rig.preparations.all, isEmpty);
        expect(rig.accounts.simulated, isEmpty);
      },
    );

    test(
      'an authorization the relay cannot carry is an InternalError',
      () async {
        final hire = await rig.hire(status: HireStatus.open);
        rig.codec.buildFailure = const UnsupportedAuthorization();

        await expectLater(
          rig.service.prepareFund(_wallet, hire.id),
          throwsA(api('InternalError')),
        );
        expect(rig.preparations.all, isEmpty);
      },
    );

    test(
      'is PaymentAlreadySubmitted once an earlier fund reached the chain',
      () async {
        for (final code in [
          SubmissionOutcomeCode.jobMismatch,
          SubmissionOutcomeCode.jobEvidenceUnavailable,
        ]) {
          final hire = await rig.hire(status: HireStatus.open);
          await rig.record(hire.id, SubmissionPurpose.fund, failedWith: code);

          await expectLater(
            rig.service.prepareFund(_wallet, hire.id),
            throwsA(api('PaymentAlreadySubmitted')),
          );
          expect(
            rig.preparations.all.where((p) => p.hireId == hire.id),
            isEmpty,
          );
        }
      },
    );

    test('prepares again after a fund that never reached the chain', () async {
      for (final code in [
        SubmissionOutcomeCode.submissionRejected,
        SubmissionOutcomeCode.preparationExpired,
        SubmissionOutcomeCode.transactionFailed,
      ]) {
        final hire = await rig.hire(status: HireStatus.open);
        await rig.record(hire.id, SubmissionPurpose.fund, failedWith: code);

        final prepared = await rig.service.prepareFund(_wallet, hire.id);

        expect(prepared.purpose, 'fund');
      }
    });
  });

  group('prepareCreateJob', () {
    test(
      'builds create_job with the agent as provider and an empty description',
      () async {
        final hire = await rig.hire();

        final prepared = await rig.service.prepareCreateJob(_wallet, hire.id);

        final expiredAt =
            rig.clock.millisecondsSinceEpoch ~/ 1000 + jobDurationSeconds;
        expect(prepared.purpose, 'createJob');
        expect(
          _builtCall(rig),
          _call('create_job', [
            ScArg.address(_wallet),
            ScArg.address(_provider),
            ScArg.address(_wallet),
            ScArg.u64(expiredAt),
            const ScArg.string(''),
            const ScArg.voidValue(),
            const ScArg.u32(7),
            ScArg.address(_usdc),
            const ScArg.i128(price),
          ]),
        );
        final stored = (await rig.preparations.findByPreparationId(
          prepared.preparationId,
        ))!;
        expect(stored.jobExpiredAt, expiredAt);
      },
    );

    test('an agent without a wallet is AgentUnavailable', () async {
      final hire = await rig.hire();
      rig.ledger.wallets.clear();

      await expectLater(
        rig.service.prepareCreateJob(_wallet, hire.id),
        throwsA(isA<AgentUnavailable>().having((e) => e.agentId, 'id', 7)),
      );
      expect(rig.preparations.all, isEmpty);
    });
  });

  group('prepareComplete', () {
    test('builds complete with an empty reason for a submitted job', () async {
      final hire = await rig.hire(status: HireStatus.submitted);

      final prepared = await rig.service.prepareComplete(_wallet, hire.id);

      expect(prepared.purpose, 'complete');
      expect(
        _builtCall(rig),
        _call('complete', [
          ScArg.address(_wallet),
          const ScArg.u64(3),
          ScArg.bytes32(Uint8List(32)),
        ]),
      );
    });
  });

  group('prepareReject', () {
    Uint8List digest(String reason) =>
        Uint8List.fromList(sha256.convert(utf8.encode(reason)).bytes);

    test('builds reject with the hash of the reason', () async {
      final hire = await rig.hire(status: HireStatus.open);

      final prepared = await rig.service.prepareReject(
        _wallet,
        hire.id,
        'changed my mind',
      );

      expect(prepared.purpose, 'reject');
      expect(
        _builtCall(rig),
        _call('reject', [
          ScArg.address(_wallet),
          const ScArg.u64(3),
          ScArg.bytes32(digest('changed my mind')),
        ]),
      );
      final stored = (await rig.preparations.findByPreparationId(
        prepared.preparationId,
      ))!;
      expect(stored.rejectReason, 'changed my mind');
    });

    test('is allowed from open, funded and submitted', () async {
      for (final status in [
        HireStatus.open,
        HireStatus.funded,
        HireStatus.submitted,
      ]) {
        final hire = await rig.hire(status: status);

        final prepared = await rig.service.prepareReject(
          _wallet,
          hire.id,
          'no longer needed',
        );

        expect(prepared.purpose, 'reject', reason: status.name);
      }
    });

    test(
      'a missing or blank reason is InvalidRejectReason and persists nothing',
      () async {
        final hire = await rig.hire(status: HireStatus.open);

        for (final reason in ['', '   ', '\n\t']) {
          await expectLater(
            rig.service.prepareReject(_wallet, hire.id, reason),
            throwsA(api('InvalidRejectReason')),
          );
        }
        expect(rig.preparations.all, isEmpty);
        expect(rig.accounts.sequenceReads, isEmpty);
      },
    );

    test('supersedes an outstanding fund preparation', () async {
      final hire = await rig.hire(status: HireStatus.open);
      final fund = await rig.service.prepareFund(_wallet, hire.id);

      await rig.service.prepareReject(_wallet, hire.id, 'cancel');

      final old = (await rig.preparations.findByPreparationId(
        fund.preparationId,
      ))!;
      expect(old.supersededAt, isNotNull);
    });
  });

  group('state guards', () {
    final cases = <(String, HireStatus?)>[
      ('createJob', HireStatus.open),
      ('fund', null),
      ('fund', HireStatus.funded),
      ('complete', HireStatus.funded),
      ('reject', null),
    ];

    Future<void> prepare(String purpose, RelayRig rig, int hireId) =>
        switch (purpose) {
          'createJob' => rig.service.prepareCreateJob(rig.wallet, hireId),
          'fund' => rig.service.prepareFund(rig.wallet, hireId),
          'complete' => rig.service.prepareComplete(rig.wallet, hireId),
          _ => rig.service.prepareReject(rig.wallet, hireId, 'because'),
        };

    for (final (purpose, status) in cases) {
      test('$purpose is InvalidHireTransition for a hire with status '
          '${status?.name ?? 'none'}', () async {
        final hire = await rig.hire(status: status);

        await expectLater(
          prepare(purpose, rig, hire.id),
          throwsA(api('InvalidHireTransition')),
        );
        expect(rig.preparations.all, isEmpty);
      });
    }

    test('a hire without a status carries no details.status', () async {
      final none = await rig.hire();

      await expectLater(
        rig.service.prepareFund(rig.wallet, none.id),
        throwsA(
          isA<Puls3ApiException>()
              .having((e) => e.details!.containsKey('status'), 'has key', false)
              .having((e) => e.details!['status'], 'status', isNull)
              .having((e) => e.details!['purpose'], 'purpose', 'fund'),
        ),
      );
    });

    test('a hire with a status names it in details.status', () async {
      final hire = await rig.hire(status: HireStatus.open);

      await expectLater(
        rig.service.prepareComplete(rig.wallet, hire.id),
        throwsA(
          api(
            'InvalidHireTransition',
            details: {
              'status': 'open',
              'purpose': 'complete',
            },
          ),
        ),
      );
    });

    test(
      'every prepare is SubmissionInProgress while an escrow record is submitted',
      () async {
        final ready = <(String, HireStatus?)>[
          ('createJob', null),
          ('fund', HireStatus.open),
          ('complete', HireStatus.submitted),
          ('reject', HireStatus.open),
        ];
        for (final (purpose, status) in ready) {
          final hire = await rig.hire(status: status);
          await rig.record(hire.id, SubmissionPurpose.createJob);

          await expectLater(
            prepare(purpose, rig, hire.id),
            throwsA(api('SubmissionInProgress')),
            reason: purpose,
          );
        }
        expect(rig.preparations.all, isEmpty);
      },
    );

    test('a failed record does not block a new preparation', () async {
      final hire = await rig.hire();
      await rig.record(
        hire.id,
        SubmissionPurpose.createJob,
        failedWith: SubmissionOutcomeCode.submissionRejected,
      );

      final prepared = await rig.service.prepareCreateJob(_wallet, hire.id);

      expect(prepared.purpose, 'createJob');
    });
  });

  group('ownership', () {
    test('InvalidHireId for a non-positive id', () async {
      for (final id in [0, -4]) {
        await expectLater(
          rig.service.prepareFund(_wallet, id),
          throwsA(api('InvalidHireId')),
        );
      }
    });

    test('HireNotFound for an id that names no hire', () async {
      await rig.hire(status: HireStatus.open);

      await expectLater(
        rig.service.prepareFund(_wallet, 999),
        throwsA(api('HireNotFound')),
      );
    });

    test(
      'HireNotOwned for another wallet, and nothing is read or stored',
      () async {
        final hire = await rig.hire(
          status: HireStatus.open,
          consumer: stranger,
        );

        await expectLater(
          rig.service.prepareFund(_wallet, hire.id),
          throwsA(api('HireNotOwned')),
        );
        expect(rig.accounts.sequenceReads, isEmpty);
        expect(rig.preparations.all, isEmpty);
      },
    );
  });

  group('supersession', () {
    test(
      'a second preparation reuses the sequence and supersedes the first',
      () async {
        final hire = await rig.hire(status: HireStatus.open);

        final first = await rig.service.prepareFund(_wallet, hire.id);
        final second = await rig.service.prepareFund(_wallet, hire.id);

        final stored = rig.preparations.all;
        expect(stored, hasLength(2));
        expect(stored[0].preparationId, first.preparationId);
        expect(stored[0].supersededAt, isNotNull);
        expect(stored[1].preparationId, second.preparationId);
        expect(stored[1].supersededAt, isNull);
        expect(stored[1].sequence, stored[0].sequence);
        expect(rig.codec.built.map((b) => b.spec.accountSequence), [100, 100]);
      },
    );

    test('follows the ledger when the chain moved on', () async {
      final hire = await rig.hire(status: HireStatus.open);
      await rig.service.prepareFund(_wallet, hire.id);
      rig.accounts.sequence = 130;

      await rig.service.prepareFund(_wallet, hire.id);

      expect(rig.preparations.all.map((p) => p.sequence), [101, 131]);
    });
  });

  group('configuration without defaults', () {
    final keys = {
      'PULS3_ESCROW_PREPARATION_VALIDITY_SECONDS': HireStatus.open,
      'PULS3_STELLAR_INCLUSION_FEE_STROOPS': HireStatus.open,
      'PULS3_PLATFORM_FEE_BPS': HireStatus.open,
    };

    for (final MapEntry(key: key, value: status) in keys.entries) {
      test('$key missing, empty or invalid fails naming the key', () async {
        for (final bad in [null, '', 'abc', '-1', '1.5', '1001']) {
          final env = relayEnvironment();
          bad == null ? env.remove(key) : env[key] = bad;
          final bare = RelayRig(environment: env);
          final hire = await bare.hire(status: status);

          // 1001 is out of range for the fee only; it is a fine duration.
          if (key == 'PULS3_PLATFORM_FEE_BPS' || bad != '1001') {
            await expectLater(
              bare.service.prepareFund(bare.wallet, hire.id),
              throwsA(
                isA<HireConfigurationMissing>().having(
                  (e) => e.setting,
                  'setting',
                  key,
                ),
              ),
              reason: '$key=$bad',
            );
            expect(bare.preparations.all, isEmpty);
            expect(bare.accounts.sequenceReads, isEmpty);
          }
        }
      });
    }

    test('a platform fee of zero is valid', () async {
      final env = relayEnvironment()..['PULS3_PLATFORM_FEE_BPS'] = '0';
      final zero = RelayRig(environment: env);
      final hire = await zero.hire(status: HireStatus.open);

      await zero.service.prepareFund(zero.wallet, hire.id);

      expect(
        _builtCall(zero),
        _call('fund', [
          ScArg.address(_wallet),
          const ScArg.u64(3),
          const ScArg.i128(price),
          const ScArg.u32(0),
        ]),
      );
    });

    test(
      'a missing job duration fails prepareCreateJob and nothing else',
      () async {
        final env = relayEnvironment()
          ..remove('PULS3_HIRE_JOB_DURATION_SECONDS');
        final noDuration = RelayRig(environment: env);
        final fresh = await noDuration.hire();
        final open = await noDuration.hire(status: HireStatus.open);

        await expectLater(
          noDuration.service.prepareCreateJob(noDuration.wallet, fresh.id),
          throwsA(
            isA<HireConfigurationMissing>().having(
              (e) => e.setting,
              'setting',
              'PULS3_HIRE_JOB_DURATION_SECONDS',
            ),
          ),
        );
        expect(noDuration.preparations.all, isEmpty);
        expect(
          (await noDuration.service.prepareFund(
            noDuration.wallet,
            open.id,
          )).purpose,
          'fund',
        );
      },
    );
  });
}
