import 'dart:convert';

import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/chain/chain_log.dart';
import 'package:puls3_server/src/chain/chain_submission_store.dart';
import 'package:puls3_server/src/chain/chain_submission_tracker.dart';
import 'package:puls3_server/src/chain/submission_ledger.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/escrow_preparation_store.dart';
import 'package:puls3_server/src/hire/hire_lifecycle_store.dart';
import 'package:puls3_server/src/ledger/envelope_codec.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:serverpod/serverpod.dart' show Transaction;
import 'package:test/test.dart';

import '../support/fake_envelope_codec.dart';
import '../support/fake_escrow_effects.dart';
import '../support/fake_submission_ledger.dart';
import '../support/relay_rig.dart';

final _wallet = StellarAddress.parse(alice);

/// Runs [beforeSend] when the service sends, then delegates.
final class _ObservingLedger implements SubmissionLedger {
  _ObservingLedger(this._inner, this._beforeSend);

  final SubmissionLedger _inner;
  final Future<void> Function() _beforeSend;

  @override
  Future<TransactionLookup> lookup(String hash) => _inner.lookup(hash);

  @override
  Future<SendTransactionResult> resend(String envelopeXdr) async {
    await _beforeSend();
    return _inner.resend(envelopeXdr);
  }
}

/// A store whose first insert loses a race: it stores the winner (for the
/// preparation index) and throws [ChainSubmissionConflict].
final class _RacingStore implements ChainSubmissionStore {
  _RacingStore(this._inner, {this.index = ChainSubmissionIndex.preparationId});

  final ChainSubmissionStore _inner;
  final ChainSubmissionIndex index;
  var conflicts = 0;
  StoredSubmission? winner;

  @override
  Future<StoredSubmission> insertSubmitted({
    required SubmissionPurpose purpose,
    required String transactionHash,
    required String signedEnvelopeXdr,
    required DateTime validUntil,
    String? preparationId,
    int? hireId,
    String? explorerUrl,
    Transaction? transaction,
  }) async {
    conflicts++;
    if (index == ChainSubmissionIndex.preparationId) {
      winner = await _inner.insertSubmitted(
        purpose: purpose,
        transactionHash: transactionHash,
        signedEnvelopeXdr: signedEnvelopeXdr,
        validUntil: validUntil,
        preparationId: preparationId,
        hireId: hireId,
      );
    }
    throw ChainSubmissionConflict(index);
  }

  @override
  Future<StoredSubmission?> findByPreparation(String preparationId) =>
      _inner.findByPreparation(preparationId);

  @override
  Future<List<StoredSubmission>> listByHire(int hireId) =>
      _inner.listByHire(hireId);

  @override
  Future<List<StoredSubmission>> listSubmitted({int limit = 100}) =>
      _inner.listSubmitted(limit: limit);

  @override
  Future<bool> markConfirmed(int id) => _inner.markConfirmed(id);

  @override
  Future<bool> markFailed(int id, String code) => _inner.markFailed(id, code);

  @override
  Future<bool> recordSend(int id, DateTime at) => _inner.recordSend(id, at);

  @override
  Future<bool> recordCheck(int id, DateTime at) => _inner.recordCheck(id, at);
}

/// A funded-ready hire, a fund preparation, and its signed envelope.
typedef _Prepared = ({HireRow hire, PreparedTransaction prepared});

void main() {
  late RelayRig rig;

  setUp(() => rig = RelayRig());

  Future<_Prepared> prepareFund() async {
    final hire = await rig.hire(status: HireStatus.open);
    return (
      hire: hire,
      prepared: await rig.service.prepareFund(_wallet, hire.id),
    );
  }

  String signed(PreparedTransaction p, {String tag = 'ok'}) =>
      FakeEnvelopeCodec.sign(p.unsignedTransactionXdr!, tag: tag);

  Future<HireDetail> submit(_Prepared p, String xdr, {StellarAddress? as}) =>
      rig.service.submitEscrowCall(
        as ?? _wallet,
        p.hire.id,
        p.prepared.preparationId,
        xdr,
      );

  /// Nothing was claimed, stored or sent.
  Future<void> expectUntouched(_Prepared p) async {
    expect(await rig.submissions.listByHire(p.hire.id), isEmpty);
    expect(rig.sender.resent, isEmpty);
    final stored = await rig.preparations.findByPreparationId(
      p.prepared.preparationId,
    );
    expect(stored!.submittedAt, isNull);
  }

  group('ownership', () {
    test('InvalidHireId, HireNotFound and HireNotOwned come first', () async {
      final p = await prepareFund();

      await expectLater(
        rig.service.submitEscrowCall(_wallet, 0, 'prep-1', signed(p.prepared)),
        throwsA(api('InvalidHireId')),
      );
      await expectLater(
        rig.service.submitEscrowCall(_wallet, 99, 'prep-1', signed(p.prepared)),
        throwsA(api('HireNotFound')),
      );
      await expectLater(
        submit(p, signed(p.prepared), as: rig.other),
        throwsA(api('HireNotOwned')),
      );
      await expectUntouched(p);
    });

    test('an unknown preparation id is PreparationNotFound', () async {
      final p = await prepareFund();

      await expectLater(
        rig.service.submitEscrowCall(
          _wallet,
          p.hire.id,
          'nope',
          signed(p.prepared),
        ),
        throwsA(api('PreparationNotFound')),
      );
      await expectUntouched(p);
    });

    test('a preparation of another hire is PreparationNotFound', () async {
      final p = await prepareFund();
      final other = await rig.hire(status: HireStatus.open);

      await expectLater(
        rig.service.submitEscrowCall(
          _wallet,
          other.id,
          p.prepared.preparationId,
          signed(p.prepared),
        ),
        throwsA(api('PreparationNotFound')),
      );
      await expectUntouched(p);
    });

    test('a preparation of another signer is PreparationNotFound', () async {
      final p = await prepareFund();
      final foreign = await rig.preparations.insert(
        NewPreparation(
          preparationId: 'foreign',
          hireId: p.hire.id,
          purpose: SubmissionPurpose.fund,
          signer: stranger,
          unsignedEnvelopeXdr: p.prepared.unsignedTransactionXdr!,
          transactionHash: p.prepared.transaction!,
          sequence: 101,
          validUntil: p.prepared.expiresAt,
        ),
      );

      await expectLater(
        rig.service.submitEscrowCall(
          _wallet,
          p.hire.id,
          foreign.preparationId,
          signed(p.prepared),
        ),
        throwsA(api('PreparationNotFound')),
      );
    });
  });

  group('expiry', () {
    test(
      'after the time bounds it is PreparationExpired(timeBounds)',
      () async {
        final p = await prepareFund();
        rig.clock = p.prepared.expiresAt.add(const Duration(seconds: 1));

        await expectLater(
          submit(p, signed(p.prepared)),
          throwsA(api('PreparationExpired', details: {'reason': 'timeBounds'})),
        );
        await expectUntouched(p);
      },
    );

    test('at the end of the window it is already expired', () async {
      final p = await prepareFund();
      rig.clock = p.prepared.expiresAt;

      await expectLater(
        submit(p, signed(p.prepared)),
        throwsA(api('PreparationExpired', details: {'reason': 'timeBounds'})),
      );
    });

    test('one second before the end it is still accepted', () async {
      final p = await prepareFund();
      rig.clock = p.prepared.expiresAt.subtract(const Duration(seconds: 1));

      final detail = await submit(p, signed(p.prepared));

      expect(detail.escrowSubmission!.state, 'submitted');
    });

    test(
      'a superseded preparation is PreparationExpired(superseded)',
      () async {
        final p = await prepareFund();
        await rig.service.prepareFund(_wallet, p.hire.id);

        await expectLater(
          submit(p, signed(p.prepared)),
          throwsA(api('PreparationExpired', details: {'reason': 'superseded'})),
        );
        await expectUntouched(p);
      },
    );

    test(
      'a repeated submit after validUntil expires even with a record',
      () async {
        final p = await prepareFund();
        final xdr = signed(p.prepared);
        await submit(p, xdr);
        rig.clock = p.prepared.expiresAt.add(const Duration(minutes: 1));

        await expectLater(
          submit(p, xdr),
          throwsA(api('PreparationExpired', details: {'reason': 'timeBounds'})),
        );
        expect(await rig.submissions.listByHire(p.hire.id), hasLength(1));
      },
    );
  });

  group('verification precedes persistence', () {
    test(
      'empty, non-base64 and truncated envelopes are InvalidSignedEnvelope',
      () async {
        final p = await prepareFund();
        final cases = {
          '': 'empty',
          '***': 'notBase64',
          base64Encode([1, 2, 3]): 'truncated',
        };

        for (final MapEntry(key: xdr, value: reason) in cases.entries) {
          await expectLater(
            submit(p, xdr),
            throwsA(api('InvalidSignedEnvelope', details: {'reason': reason})),
          );
        }
        await expectUntouched(p);
      },
    );

    test('a different body is EnvelopeMismatch naming the field', () async {
      final p = await prepareFund();
      final tampered = FakeEnvelopeCodec.sign(
        p.prepared.unsignedTransactionXdr!,
        body: utf8.encode('another call'),
      );

      for (final field in [EnvelopeField.contract, EnvelopeField.timeBounds]) {
        rig.codec.differenceField = field;
        await expectLater(
          submit(p, tampered),
          throwsA(api('EnvelopeMismatch', details: {'field': field})),
        );
      }
      await expectUntouched(p);
    });

    test('no match found by the codec still names a field: other', () async {
      final p = await prepareFund();
      rig.codec.differenceField = EnvelopeField.other;

      await expectLater(
        submit(
          p,
          FakeEnvelopeCodec.sign(
            p.prepared.unsignedTransactionXdr!,
            body: utf8.encode('x'),
          ),
        ),
        throwsA(api('EnvelopeMismatch', details: {'field': 'other'})),
      );
    });

    test(
      'an unsigned, foreign or corrupt signature is InvalidTransactionSignature',
      () async {
        final p = await prepareFund();
        final cases = {
          '': 'missing',
          'wrong': 'wrongSigner',
          'bad': 'doesNotVerify',
        };

        for (final MapEntry(key: tag, value: reason) in cases.entries) {
          await expectLater(
            submit(p, signed(p.prepared, tag: tag)),
            throwsA(
              api('InvalidTransactionSignature', details: {'reason': reason}),
            ),
          );
        }
        await expectUntouched(p);
      },
    );

    test(
      'the first failure wins: malformed, then body, then signature',
      () async {
        final p = await prepareFund();
        rig.codec.differenceField = EnvelopeField.function;

        await expectLater(
          submit(
            p,
            FakeEnvelopeCodec.sign(
              p.prepared.unsignedTransactionXdr!,
              tag: 'bad',
              body: utf8.encode('x'),
            ),
          ),
          throwsA(api('EnvelopeMismatch')),
        );
      },
    );

    test(
      'a hire state that no longer allows the purpose is InvalidHireTransition',
      () async {
        final p = await prepareFund();
        rig.hires.statusOverride[p.hire.id] = HireStatus.funded;

        await expectLater(
          submit(p, signed(p.prepared)),
          throwsA(api('InvalidHireTransition')),
        );
        await expectUntouched(p);
      },
    );

    test(
      'losing the claim to a newer preparation is PreparationExpired(superseded)',
      () async {
        final p = await prepareFund();
        rig.codec.onVerify = () => rig.preparations.supersedeCurrent(p.hire.id);

        await expectLater(
          submit(p, signed(p.prepared)),
          throwsA(api('PreparationExpired', details: {'reason': 'superseded'})),
        );
        expect(await rig.submissions.listByHire(p.hire.id), isEmpty);
        expect(rig.sender.resent, isEmpty);
      },
    );
  });

  group('persist, then send', () {
    test(
      'the record exists, submitted, before sendTransaction is called',
      () async {
        final p = await prepareFund();
        final xdr = signed(p.prepared);
        late List<StoredSubmission> atSend;
        final observed = _ObservingLedger(
          rig.sender,
          () async => atSend = await rig.submissions.listByHire(p.hire.id),
        );
        final service = rig.build(sender: observed);

        await service.submitEscrowCall(
          _wallet,
          p.hire.id,
          p.prepared.preparationId,
          xdr,
        );

        expect(atSend, hasLength(1));
        expect(atSend.single.state, SubmissionState.submitted);
        expect(atSend.single.signedEnvelopeXdr, xdr);
        expect(atSend.single.transactionHash, hasLength(64));
      },
    );

    test(
      'an accepted send returns the submitted record and counts the send',
      () async {
        final p = await prepareFund();
        final xdr = signed(p.prepared);

        final detail = await submit(p, xdr);

        final record = detail.escrowSubmission!;
        expect(record.purpose, 'fund');
        expect(record.state, 'submitted');
        expect(record.preparationId, p.prepared.preparationId);
        expect(record.transaction, hasLength(64));
        expect(rig.sender.resent, [xdr]);
        final stored = (await rig.submissions.listByHire(p.hire.id)).single;
        expect(stored.sendAttempts, 1);
        expect(stored.hireId, p.hire.id);
        expect(detail.hire.id, p.hire.id);
        expect(detail.agent.registryId, 7);
        expect(detail.input, 'summarise this');
      },
    );

    test('the claim is recorded on the preparation', () async {
      final p = await prepareFund();

      await submit(p, signed(p.prepared));

      final stored = await rig.preparations.findByPreparationId(
        p.prepared.preparationId,
      );
      expect(stored!.submittedAt, isNotNull);
    });

    test('a DUPLICATE answer counts as sent', () async {
      final p = await prepareFund();
      final xdr = signed(p.prepared);
      rig.sender.sends[xdr] = SendTransactionResult(
        status: SendTransactionStatus.duplicate,
        hash: 'f' * 64,
      );

      final detail = await submit(p, xdr);

      expect(detail.escrowSubmission!.state, 'submitted');
      expect(
        (await rig.submissions.listByHire(p.hire.id)).single.sendAttempts,
        1,
      );
    });

    test('TRY_AGAIN_LATER leaves it submitted for the tracker', () async {
      final p = await prepareFund();
      final xdr = signed(p.prepared);
      rig.sender.sends[xdr] = SendTransactionResult(
        status: SendTransactionStatus.tryAgainLater,
        hash: 'f' * 64,
      );

      final detail = await submit(p, xdr);

      expect(detail.escrowSubmission!.state, 'submitted');
      expect(
        (await rig.submissions.listByHire(p.hire.id)).single.sendAttempts,
        0,
      );
    });

    test(
      'an ERROR answer fails the record SubmissionRejected without throwing',
      () async {
        final p = await prepareFund();
        final xdr = signed(p.prepared);
        rig.sender.sends[xdr] = SendTransactionResult(
          status: SendTransactionStatus.error,
          hash: 'f' * 64,
          errorResultXdr: 'AAAA',
        );

        final detail = await submit(p, xdr);

        expect(detail.escrowSubmission!.state, 'failed');
        expect(detail.escrowSubmission!.errorCode, 'SubmissionRejected');
      },
    );

    test(
      'a request the node refuses fails the record SubmissionRejected',
      () async {
        final p = await prepareFund();
        final xdr = signed(p.prepared);
        rig.sender.sends[xdr] = const RpcRequestRejected(-32602, 'bad', 'bad');

        final detail = await submit(p, xdr);

        expect(detail.escrowSubmission!.state, 'failed');
        expect(detail.escrowSubmission!.errorCode, 'SubmissionRejected');
      },
    );

    test('an unreachable node leaves it submitted and sends once', () async {
      final p = await prepareFund();
      final xdr = signed(p.prepared);
      rig.sender.sends[xdr] = const LedgerUnavailable('timeout');

      final detail = await submit(p, xdr);

      expect(detail.escrowSubmission!.state, 'submitted');
      expect(rig.sender.resent, [xdr]);
      expect(
        (await rig.submissions.listByHire(p.hire.id)).single.sendAttempts,
        0,
      );
    });

    test('after a rejection the hire can prepare again', () async {
      final p = await prepareFund();
      final xdr = signed(p.prepared);
      rig.sender.sends[xdr] = const RpcRequestRejected(-32602, 'bad', 'bad');
      await submit(p, xdr);

      final next = await rig.service.prepareFund(_wallet, p.hire.id);

      expect(next.preparationId, isNot(p.prepared.preparationId));
    });
  });

  group('at most one submission per preparation', () {
    test(
      'a repeated submit returns the existing record and does not send',
      () async {
        final p = await prepareFund();
        final xdr = signed(p.prepared);
        final first = await submit(p, xdr);

        final again = await submit(p, xdr);

        expect(again.escrowSubmission!.id, first.escrowSubmission!.id);
        expect(
          again.escrowSubmission!.transaction,
          first.escrowSubmission!.transaction,
        );
        expect(rig.sender.resent, hasLength(1));
        expect(await rig.submissions.listByHire(p.hire.id), hasLength(1));
      },
    );

    test('a repeated submit is verified again', () async {
      final p = await prepareFund();
      await submit(p, signed(p.prepared));
      rig.codec.differenceField = EnvelopeField.arguments;

      await expectLater(
        submit(
          p,
          FakeEnvelopeCodec.sign(
            p.prepared.unsignedTransactionXdr!,
            body: utf8.encode('tampered'),
          ),
        ),
        throwsA(api('EnvelopeMismatch')),
      );
      final record = (await rig.submissions.listByHire(p.hire.id)).single;
      expect(record.state, SubmissionState.submitted);
      expect(rig.sender.resent, hasLength(1));
    });

    test(
      'a repeated create_job submit still returns its record once the job opened',
      () async {
        final hire = await rig.hire();
        final prepared = await rig.service.prepareCreateJob(_wallet, hire.id);
        final xdr = FakeEnvelopeCodec.sign(prepared.unsignedTransactionXdr!);
        await rig.service.submitEscrowCall(
          _wallet,
          hire.id,
          prepared.preparationId,
          xdr,
        );
        await rig.hires.bindJob(hire.id, 3, expiredAt: 1800000000);

        final again = await rig.service.submitEscrowCall(
          _wallet,
          hire.id,
          prepared.preparationId,
          xdr,
        );

        expect(again.escrowSubmission!.purpose, 'createJob');
        expect(rig.sender.resent, hasLength(1));
      },
    );

    test(
      'the loser of a concurrent submit re-reads the winner without sending',
      () async {
        final p = await prepareFund();
        final xdr = signed(p.prepared);
        final racing = _RacingStore(rig.submissions);
        final service = rig.build(submissions: racing);

        final detail = await service.submitEscrowCall(
          _wallet,
          p.hire.id,
          p.prepared.preparationId,
          xdr,
        );

        expect(racing.conflicts, 1);
        expect(detail.escrowSubmission!.id, racing.winner!.id);
        expect(rig.sender.resent, isEmpty);
      },
    );

    test(
      'a hash collision with another preparation is an InternalError',
      () async {
        final p = await prepareFund();
        final xdr = signed(p.prepared);
        final racing = _RacingStore(
          rig.submissions,
          index: ChainSubmissionIndex.transaction,
        );
        final service = rig.build(submissions: racing);

        await expectLater(
          service.submitEscrowCall(
            _wallet,
            p.hire.id,
            p.prepared.preparationId,
            xdr,
          ),
          throwsA(api('InternalError')),
        );
        expect(rig.sender.resent, isEmpty);
      },
    );
  });

  group('complete and reject settle with #97', () {
    test(
      'a relayed complete stays submitted and leaves the hire alone',
      () async {
        final hire = await rig.hire(status: HireStatus.submitted);
        final prepared = await rig.service.prepareComplete(_wallet, hire.id);

        final detail = await rig.service.submitEscrowCall(
          _wallet,
          hire.id,
          prepared.preparationId,
          FakeEnvelopeCodec.sign(prepared.unsignedTransactionXdr!),
        );

        expect(detail.escrowSubmission!.purpose, 'complete');
        expect(detail.escrowSubmission!.state, 'submitted');
        expect(
          (await rig.hires.findHire(hire.id))!.status,
          HireStatus.submitted,
        );
      },
    );

    test(
      'a relayed reject stays submitted even when the chain confirms it',
      () async {
        final hire = await rig.hire(status: HireStatus.open);
        final prepared = await rig.service.prepareReject(
          _wallet,
          hire.id,
          'no',
        );
        final detail = await rig.service.submitEscrowCall(
          _wallet,
          hire.id,
          prepared.preparationId,
          FakeEnvelopeCodec.sign(prepared.unsignedTransactionXdr!),
        );
        final record = detail.escrowSubmission!;
        final chain = FakeSubmissionLedger();
        chain.lookups[record.transaction] = const TransactionLookup(
          status: TransactionStatus.success,
        );
        final effects = FakeEscrowEffects();
        final tracker = ChainSubmissionTracker(
          ledger: chain,
          effects: effects,
          log: ignoreChainLog,
          now: () => rig.clock,
        );

        final summary = await tracker.pass(rig.submissions);

        expect(record.purpose, 'reject');
        expect(chain.lookedUp, [record.transaction]);
        expect(summary.untracked, 1);
        expect(summary.confirmed, 0);
        expect(
          (await rig.submissions.listByHire(hire.id)).single.state,
          SubmissionState.submitted,
        );
        expect(effects.created, isEmpty);
        expect(effects.funded, isEmpty);
        expect((await rig.hires.findHire(hire.id))!.status, HireStatus.open);
      },
    );
  });
}
