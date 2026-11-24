import 'dart:convert';

import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/hire/escrow_relay_service.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart';
import 'package:test/test.dart';

import '../support/relay_rig.dart';

/// The escrow bindings of ADR-0011: `fund_with_reserve` and
/// `create_child_job`.

final _escrow = StellarConfig.testnet.escrow;
final _wallet = StellarAddress.parse(alice);
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

  group('prepareFund with a subcontract reserve (D1)', () {
    test('a hire with a reserve calls fund_with_reserve once', () async {
      final hire = await rig.hire(
        status: HireStatus.open,
        subcontractReserve: 2000000,
      );

      final prepared = await rig.service.prepareFund(_wallet, hire.id);

      expect(prepared.purpose, 'fund', reason: 'funding stays one purpose');
      expect(
        _builtCall(rig),
        _call('fund_with_reserve', [
          ScArg.address(_wallet),
          const ScArg.u64(3),
          const ScArg.i128(price),
          const ScArg.i128(2000000),
          const ScArg.u32(platformFeeBps),
        ]),
      );
      expect(
        rig.preparations.all.single.purpose,
        SubmissionPurpose.fund,
      );
    });

    test('a hire without a reserve still calls fund unchanged', () async {
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
  });

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
