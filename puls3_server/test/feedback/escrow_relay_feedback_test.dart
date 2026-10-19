import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/feedback/reputation_calls.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart';
import 'package:test/test.dart';

import '../support/fake_envelope_codec.dart';
import '../support/relay_rig.dart';

final _wallet = StellarAddress.parse(alice);

/// A registry the escrow is not: the call must go there, not to the escrow.
final _registry = StellarAddress.parse(
  'CD5QZOKGRBV35C5SDT6PG7S72XGG4BHQAC2L56YLNBJDUL4LDMTXFIJJ',
);

final _call = ContractCall(
  contract: _registry,
  function: 'give_feedback',
  args: [ScArg.address(_wallet), const ScArg.u32(7), const ScArg.u32(4)],
);

void main() {
  late RelayRig rig;

  setUp(() => rig = RelayRig());

  group('prepareFeedback', () {
    test('builds the given call on the given contract', () async {
      final hire = await rig.hire(status: HireStatus.completed);

      final prepared = await rig.service.prepareFeedback(
        _wallet,
        hire.id,
        _call,
      );

      final spec = rig.codec.built.single.spec;
      expect(prepared.purpose, 'giveFeedback');
      expect(prepared.signer, alice);
      expect(spec.contract, _registry);
      expect(spec.function, 'give_feedback');
      expect(spec.args, hasLength(3));
      expect(spec.source, _wallet);
    });

    test('stores the preparation with the giveFeedback purpose', () async {
      final hire = await rig.hire(status: HireStatus.completed);

      final prepared = await rig.service.prepareFeedback(
        _wallet,
        hire.id,
        _call,
      );

      final stored = (await rig.preparations.findByPreparationId(
        prepared.preparationId,
      ))!;
      expect(stored.purpose, SubmissionPurpose.giveFeedback);
      expect(stored.hireId, hire.id);
    });

    test('only a completed hire is allowed', () async {
      for (final status in [
        HireStatus.open,
        HireStatus.funded,
        HireStatus.submitted,
        HireStatus.rejected,
        HireStatus.expired,
      ]) {
        final hire = await rig.hire(status: status);

        await expectLater(
          rig.service.prepareFeedback(_wallet, hire.id, _call),
          throwsA(api('InvalidHireTransition')),
          reason: status.name,
        );
      }
      expect(rig.codec.built, isEmpty);
    });

    test('an in-progress giveFeedback blocks a second preparation', () async {
      final hire = await rig.hire(status: HireStatus.completed);
      await rig.record(hire.id, SubmissionPurpose.giveFeedback);

      await expectLater(
        rig.service.prepareFeedback(_wallet, hire.id, _call),
        throwsA(api('SubmissionInProgress')),
      );
    });

    test(
      'a record failed with OutcomeUnknown blocks the feedback too',
      () async {
        final hire = await rig.hire(status: HireStatus.completed);
        await rig.record(
          hire.id,
          SubmissionPurpose.complete,
          failedWith: SubmissionOutcomeCode.outcomeUnknown,
        );

        await expectLater(
          rig.service.prepareFeedback(_wallet, hire.id, _call),
          throwsA(api('OutcomeUnknown')),
        );
        expect(rig.codec.built, isEmpty);
      },
    );

    test('another wallet cannot prepare it', () async {
      final hire = await rig.hire(status: HireStatus.completed);

      await expectLater(
        rig.service.prepareFeedback(rig.other, hire.id, _call),
        throwsA(api('HireNotOwned')),
      );
    });
  });

  group('submitEscrowCall of a giveFeedback preparation', () {
    test('relays the signed envelope and records it submitted', () async {
      final hire = await rig.hire(status: HireStatus.completed);
      final prepared = await rig.service.prepareFeedback(
        _wallet,
        hire.id,
        _call,
      );

      final detail = await rig.service.submitEscrowCall(
        _wallet,
        hire.id,
        prepared.preparationId,
        FakeEnvelopeCodec.sign(prepared.unsignedTransactionXdr!, tag: 'ok'),
      );

      expect(detail.escrowSubmission!.purpose, 'giveFeedback');
      expect(detail.escrowSubmission!.state, 'submitted');
      expect(rig.sender.resent, hasLength(1));
    });
  });
}
