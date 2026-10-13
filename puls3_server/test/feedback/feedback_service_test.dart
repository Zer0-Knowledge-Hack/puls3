import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/feedback/feedback_service.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:test/test.dart';

import '../support/fake_envelope_codec.dart';
import '../support/fake_feedback_ports.dart';
import '../support/relay_rig.dart';

final _wallet = StellarAddress.parse(alice);
final _owner = StellarAddress.parse(agentWallet);

void main() {
  late RelayRig rig;
  late FakeAgentOwners owners;
  late FakeReputationCalls calls;
  late FeedbackService service;

  setUp(() {
    rig = RelayRig();
    // The rig's hires are for agent 7, owned by a wallet that is not alice.
    owners = FakeAgentOwners({7: _owner});
    calls = FakeReputationCalls();
    service = FeedbackService(
      hires: rig.hires,
      submissions: rig.submissions,
      preparations: rig.preparations,
      owners: owners,
      calls: calls,
      relay: rig.service,
    );
  });

  group('eligibility', () {
    test('a funded hire is not eligible: not completed', () async {
      final hire = await rig.hire(status: HireStatus.funded);

      final result = await service.eligibility(_wallet, hire.id);

      expect(result.hireId, hire.id);
      expect(result.eligible, isFalse);
      expect(result.reason, 'HireNotCompleted');
    });

    test('a completed, unrated hire of a non-owner is eligible', () async {
      final hire = await rig.hire(status: HireStatus.completed);

      final result = await service.eligibility(_wallet, hire.id);

      expect(result.eligible, isTrue);
      expect(result.reason, isNull);
    });

    test('a hire with a live giveFeedback is already rated', () async {
      final hire = await rig.hire(status: HireStatus.completed);
      await rig.record(hire.id, SubmissionPurpose.giveFeedback);

      final result = await service.eligibility(_wallet, hire.id);

      expect(result.eligible, isFalse);
      expect(result.reason, 'HireAlreadyRated');
    });

    test('a failed giveFeedback does not count as rated', () async {
      final hire = await rig.hire(status: HireStatus.completed);
      await rig.record(
        hire.id,
        SubmissionPurpose.giveFeedback,
        failedWith: SubmissionOutcomeCode.transactionFailed,
      );

      final result = await service.eligibility(_wallet, hire.id);

      expect(result.eligible, isTrue);
    });

    test('the agent owner is not eligible', () async {
      final hire = await rig.hire(status: HireStatus.completed);
      owners.owners[7] = _wallet;

      final result = await service.eligibility(_wallet, hire.id);

      expect(result.eligible, isFalse);
      expect(result.reason, 'FeedbackFromAgentOwner');
    });

    test('hire rules are reported before the owner is read', () async {
      final hire = await rig.hire(status: HireStatus.funded);
      owners.failure = const LedgerUnavailable('down');

      final result = await service.eligibility(_wallet, hire.id);

      expect(result.reason, 'HireNotCompleted');
      expect(owners.reads, 0);
    });

    test('hire lookup errors are thrown, not reported', () async {
      await expectLater(
        service.eligibility(_wallet, 0),
        throwsA(api('InvalidHireId')),
      );
      await expectLater(
        service.eligibility(_wallet, 99),
        throwsA(api('HireNotFound')),
      );
      final hire = await rig.hire(status: HireStatus.completed);
      await expectLater(
        service.eligibility(rig.other, hire.id),
        throwsA(api('HireNotOwned')),
      );
    });

    test('an unknown owner is ChainDataUnavailable', () async {
      final hire = await rig.hire(status: HireStatus.completed);
      owners.owners.clear();

      await expectLater(
        service.eligibility(_wallet, hire.id),
        throwsA(api('ChainDataUnavailable')),
      );
    });
  });

  group('prepare', () {
    test('builds a giveFeedback draft on the registry contract', () async {
      final hire = await rig.hire(status: HireStatus.completed);

      final prepared = await service.prepare(_wallet, hire.id, 4, 'Great');

      expect(prepared.purpose, 'giveFeedback');
      expect(calls.built.single.feedback.score, 4);
      expect(calls.built.single.feedback.comment, 'Great');
      expect(calls.built.single.client, _wallet);
      expect(rig.codec.built.single.spec.contract, fakeReputationRegistry);
    });

    test('a hire that is not completed is HireNotCompleted', () async {
      final hire = await rig.hire(status: HireStatus.submitted);

      await expectLater(
        service.prepare(_wallet, hire.id, 4, ''),
        throwsA(api('HireNotCompleted', details: {'status': 'submitted'})),
      );
      expect(rig.codec.built, isEmpty);
    });

    test(
      'an already rated hire is HireAlreadyRated and builds no draft',
      () async {
        final hire = await rig.hire(status: HireStatus.completed);
        await rig.record(hire.id, SubmissionPurpose.giveFeedback);

        await expectLater(
          service.prepare(_wallet, hire.id, 4, ''),
          throwsA(api('HireAlreadyRated')),
        );
        expect(calls.built, isEmpty);
        expect(rig.codec.built, isEmpty);
      },
    );

    test('the agent owner is rejected with no draft', () async {
      final hire = await rig.hire(status: HireStatus.completed);
      owners.owners[7] = _wallet;

      await expectLater(
        service.prepare(_wallet, hire.id, 4, ''),
        throwsA(api('FeedbackFromAgentOwner')),
      );
      expect(calls.built, isEmpty);
      expect(rig.codec.built, isEmpty);
    });

    test('a null owner fails closed as ChainDataUnavailable', () async {
      final hire = await rig.hire(status: HireStatus.completed);
      owners.owners.clear();

      await expectLater(
        service.prepare(_wallet, hire.id, 4, ''),
        throwsA(api('ChainDataUnavailable')),
      );
      expect(rig.codec.built, isEmpty);
    });

    test(
      'a chain failure while reading the owner is ChainDataUnavailable',
      () async {
        final hire = await rig.hire(status: HireStatus.completed);
        owners.failure = const LedgerUnavailable('down');

        await expectLater(
          service.prepare(_wallet, hire.id, 4, ''),
          throwsA(api('ChainDataUnavailable')),
        );
      },
    );

    test('an invalid score or comment is InvalidFeedback', () async {
      final hire = await rig.hire(status: HireStatus.completed);

      await expectLater(
        service.prepare(_wallet, hire.id, 6, ''),
        throwsA(api('InvalidFeedback', details: {'reason': 'scoreOutOfRange'})),
      );
      await expectLater(
        service.prepare(_wallet, hire.id, 3, 'x' * 501),
        throwsA(api('InvalidFeedback', details: {'reason': 'commentTooLong'})),
      );
      expect(rig.codec.built, isEmpty);
    });

    test('another wallet cannot prepare it', () async {
      final hire = await rig.hire(status: HireStatus.completed);

      await expectLater(
        service.prepare(rig.other, hire.id, 4, ''),
        throwsA(api('HireNotOwned')),
      );
    });
  });

  group('submit', () {
    test('relays the signed call and sets the feedback reference', () async {
      final hire = await rig.hire(status: HireStatus.completed);
      final prepared = await service.prepare(_wallet, hire.id, 5, 'Great');

      final detail = await service.submit(
        _wallet,
        hire.id,
        prepared.preparationId,
        FakeEnvelopeCodec.sign(prepared.unsignedTransactionXdr!, tag: 'ok'),
      );

      final submission = detail.feedbackSubmission!;
      expect(submission.purpose, 'giveFeedback');
      expect(submission.state, 'submitted');
      expect(detail.hire.feedbackReference, submission.transaction);
      expect(detail.hire.status, 'completed');
      expect(detail.escrowSubmission, isNull);
      expect(rig.sender.resent, hasLength(1));
    });

    test('a replay of the same preparation returns the same record', () async {
      final hire = await rig.hire(status: HireStatus.completed);
      final prepared = await service.prepare(_wallet, hire.id, 5, '');
      final xdr = FakeEnvelopeCodec.sign(
        prepared.unsignedTransactionXdr!,
        tag: 'ok',
      );

      final first = await service.submit(
        _wallet,
        hire.id,
        prepared.preparationId,
        xdr,
      );
      final second = await service.submit(
        _wallet,
        hire.id,
        prepared.preparationId,
        xdr,
      );

      expect(second.feedbackSubmission!.id, first.feedbackSubmission!.id);
      expect(rig.sender.resent, hasLength(1));
    });

    test(
      'a hire rated meanwhile is HireAlreadyRated and nothing is sent',
      () async {
        final hire = await rig.hire(status: HireStatus.completed);
        final prepared = await service.prepare(_wallet, hire.id, 5, '');
        await rig.record(hire.id, SubmissionPurpose.giveFeedback);

        await expectLater(
          service.submit(
            _wallet,
            hire.id,
            prepared.preparationId,
            FakeEnvelopeCodec.sign(prepared.unsignedTransactionXdr!, tag: 'ok'),
          ),
          throwsA(api('HireAlreadyRated')),
        );
        expect(rig.sender.resent, isEmpty);
      },
    );

    test('the owner is re-checked at submit', () async {
      final hire = await rig.hire(status: HireStatus.completed);
      final prepared = await service.prepare(_wallet, hire.id, 5, '');
      owners.owners[7] = _wallet;

      await expectLater(
        service.submit(
          _wallet,
          hire.id,
          prepared.preparationId,
          FakeEnvelopeCodec.sign(prepared.unsignedTransactionXdr!, tag: 'ok'),
        ),
        throwsA(api('FeedbackFromAgentOwner')),
      );
      expect(rig.sender.resent, isEmpty);
    });

    test('a preparation of another purpose is not accepted', () async {
      final hire = await rig.hire(status: HireStatus.submitted);
      final prepared = await rig.service.prepareComplete(_wallet, hire.id);
      rig.hires.statusOverride[hire.id] = HireStatus.completed;

      await expectLater(
        service.submit(
          _wallet,
          hire.id,
          prepared.preparationId,
          FakeEnvelopeCodec.sign(prepared.unsignedTransactionXdr!, tag: 'ok'),
        ),
        throwsA(api('PreparationNotFound')),
      );
      expect(rig.sender.resent, isEmpty);
    });
  });
}
