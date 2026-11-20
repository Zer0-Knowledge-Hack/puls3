import 'dart:convert';

import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/hire/escrow_relay_service.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart';
import 'package:test/test.dart';

import '../support/relay_rig.dart';

/// The escrow binding of ADR-0011 D2: `create_child_job`.

final _escrow = StellarConfig.testnet.escrow;
final _agentA = StellarAddress.parse(agentWallet);
final _agentB = StellarAddress.parse(stranger);

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

  group('draftCreateChildJob (D2)', () {
    Future<PreparationDraft> draft({int reserve = 0}) =>
        rig.service.draftCreateChildJob(
          parentProvider: _agentA,
          parentJobId: 3,
          provider: _agentB,
          evaluator: _agentA,
          expiredAt: 1790000000,
          agentId: 9,
          budget: 500000,
          reserve: reserve,
        );

    test('builds create_child_job signed by the parent provider', () async {
      final built = await draft();

      expect(built.purpose, SubmissionPurpose.createChildJob);
      expect(built.signer, _agentA);
      expect(built.jobExpiredAt, 1790000000);
      expect(rig.codec.built.single.spec.source, _agentA);
      expect(
        _builtCall(rig),
        _call('create_child_job', [
          ScArg.address(_agentA),
          const ScArg.u64(3),
          ScArg.address(_agentB),
          ScArg.address(_agentA),
          const ScArg.u64(1790000000),
          const ScArg.string(''),
          const ScArg.u32(9),
          const ScArg.i128(500000),
          const ScArg.i128(0),
        ]),
      );
      expect(rig.preparations.all, isEmpty, reason: 'nothing is stored');
    });

    test('a subcontract contract error is typed', () async {
      rig.accounts.simulationFailure = const LedgerContractError(
        124,
        'create_child_job failed with #124',
      );

      await expectLater(
        draft(),
        throwsA(
          isA<SubcontractRejected>().having(
            (e) => e.error,
            'error',
            EscrowSubcontractError.reserveExceeded,
          ),
        ),
      );
    });

    test('another contract error stays a LedgerContractError', () async {
      rig.accounts.simulationFailure = const LedgerContractError(
        5,
        'create_child_job failed with #5',
      );

      await expectLater(draft(), throwsA(isA<LedgerContractError>()));
    });
  });
}
