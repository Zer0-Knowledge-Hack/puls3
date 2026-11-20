@Tags(['integration'])
library;

import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_domain/puls3_domain.dart' as domain show Payment;
import 'package:puls3_server/src/chain/serverpod_chain_submission_store.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/generated/protocol.dart'
    show ChainSubmission, HireReceiptLineRecord, HireRecord;
import 'package:puls3_server/src/hire/escrow_relay_service.dart';
import 'package:puls3_server/src/hire/hire_lifecycle_store.dart';
import 'package:puls3_server/src/hire/hire_receipt_store.dart';
import 'package:puls3_server/src/hire/hire_relay_config.dart';
import 'package:puls3_server/src/hire/serverpod_escrow_preparation_store.dart';
import 'package:puls3_server/src/hire/serverpod_hire_receipt_store.dart';
import 'package:puls3_server/src/hire/serverpod_hire_repository.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:puls3_server/src/runtime/escrow_subcontract_port.dart';
import 'package:puls3_server/src/runtime/subcontract_port.dart';
import 'package:serverpod/serverpod.dart' show Session;
import 'package:test/test.dart';

import '../support/fake_chain_accounts.dart';
import '../support/fake_envelope_codec.dart';
import '../support/fake_submission_ledger.dart';
import '../unit/hire/hire_test_fakes.dart';
import 'test_tools/serverpod_test_tools.dart';

const _alice = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _agentA = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';
const _agentB = 'GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H';
const _jobDuration = 259200;
const _reserve = 2000000;
const _budget = 500000;
const _childRegistryId = 9;
final _at = DateTime.utc(2026, 10, 7, 12);
final _nowSeconds = _at.millisecondsSinceEpoch ~/ 1000;
const _env = {
  'PULS3_ESCROW_PREPARATION_VALIDITY_SECONDS': '300',
  'PULS3_STELLAR_INCLUSION_FEE_STROOPS': '100',
  'PULS3_PLATFORM_FEE_BPS': '0',
  'PULS3_HIRE_JOB_DURATION_SECONDS': '$_jobDuration',
};

/// [EscrowSubcontractPort] over the Serverpod stores of one [session], with
/// fake chain ports and custody.
final class _Stack {
  _Stack(Session session)
    : hires = ServerpodHireRepository(session),
      receipts = ServerpodHireReceiptStore(session, now: () => _at),
      submissions = ServerpodChainSubmissionStore(session, now: () => _at) {
    ledger.wallets[7] = StellarAddress.parse(_agentA);
    relay = EscrowRelayService(
      preparations: ServerpodEscrowPreparationStore(session, now: () => _at),
      submissions: submissions,
      hires: hires,
      accounts: accounts,
      codec: codec,
      sender: FakeSubmissionLedger(),
      agentWallets: ledger,
      agents: (id) async => null,
      stellar: StellarConfig.testnet,
      config: const HireRelayConfig(_env),
      now: () => _at,
    );
    port = EscrowSubcontractPort(
      hires: hires,
      receipts: receipts,
      submissions: submissions,
      jobs: ledger,
      relay: relay,
      config: const HireRelayConfig(_env),
      childAgent: (registryId) async => registryId == _childRegistryId
          ? ChildAgent(
              wallet: StellarAddress.parse(_agentB),
              manifestVersion: 3,
              priceStroops: _budget,
            )
          : null,
      approvalWindow: () async => 86400,
      sign: (prepared, signer) async {
        signers.add(signer);
        return FakeEnvelopeCodec.sign(prepared.envelopeXdr);
      },
      send: (envelope, hash) async {
        sent.add(envelope);
        return SendTransactionResult(
          status: SendTransactionStatus.pending,
          hash: hash,
        );
      },
      now: () => _at,
    );
  }

  final ServerpodHireRepository hires;
  final ServerpodHireReceiptStore receipts;
  final ServerpodChainSubmissionStore submissions;
  final accounts = FakeChainAccounts();
  final codec = FakeEnvelopeCodec();
  final ledger = FakeLedger();
  final signers = <StellarAddress>[];
  final sent = <String>[];
  late final EscrowRelayService relay;
  late final EscrowSubcontractPort port;

  /// A funded parent hire of agent A (registry id 7) whose chain job holds
  /// the reserve.
  Future<HireRow> parent() async {
    final row = await hires.insertHire(
      NewHire(
        consumer: _alice,
        agentId: 7,
        price: 5000000,
        manifestVersion: 1,
        expiredAt: _nowSeconds + _jobDuration,
        requestId: 'parent-${DateTime.now().microsecondsSinceEpoch}',
        input: 'summarise this',
        subcontractReserve: _reserve,
      ),
    );
    final jobId = 900000000 + row.id;
    await hires.bindJob(row.id, jobId, expiredAt: _nowSeconds + _jobDuration);
    final open = (await hires.findById(HireId(row.id)))!;
    await hires.recordPayment(
      open,
      domain.Payment(
        transaction: TransactionHash.parse(
          row.id.toRadixString(16).padLeft(64, 'e'),
        ),
        hireId: open.id,
        payer: StellarAddress.parse(_alice),
        payee: StellarAddress.parse(_agentA),
        amount: UsdcAmount.stroops(5000000),
      ),
      jobId,
    );
    ledger.jobs[jobId] = EscrowJob(
      client: StellarAddress.parse(_alice),
      provider: StellarAddress.parse(_agentA),
      evaluator: StellarAddress.parse(_alice),
      agentId: AgentId(7),
      token: StellarConfig.testnet.usdcSac,
      budget: BigInt.from(5000000),
      feeBps: 0,
      expiredAt: _nowSeconds + _jobDuration,
      description: '',
      state: EscrowJobState.funded,
      submittedAt: 0,
      approvalDeadline: 0,
      deliverable: null,
      reserve: BigInt.from(_reserve),
      reserveFunded: BigInt.from(_reserve),
    );
    final funded = (await hires.findHire(row.id))!;
    expect(funded.status, HireStatus.funded);
    return funded;
  }
}

ChildRequest _request(int parentHireId, String callId) => ChildRequest(
  parentHireId: parentHireId,
  agentRegistryId: _childRegistryId,
  agentId: 'agt-009',
  priceStroops: _budget,
  task: 'Research the topic',
  justification: 'Best rated research agent',
  isRelatedParty: false,
  relatedPartyJustification: RelatedPartyJustification.independent,
  ranking: const [],
  toolCallId: callId,
);

void main() {
  // Real PostgreSQL transactions, not the test tools' savepoints: a write
  // that escaped the transaction would stay behind.
  withServerpod(
    'Given EscrowSubcontractPort on PostgreSQL',
    (
      sessionBuilder,
      _,
    ) {
      late Session session;
      late _Stack stack;

      setUp(() {
        session = sessionBuilder.build();
        stack = _Stack(session);
      });

      Future<List<HireRecord>> children(int parentHireId) => HireRecord.db.find(
        session,
        where: (t) => t.parentHireId.equals(parentHireId),
      );

      test('opening a child stores its hire, receipt line and submitted '
          'create_child_job together', () async {
        final parent = await stack.parent();

        final childId = await stack.port.requestChild(
          _request(parent.id, 'call-1'),
        );

        final child = (await children(parent.id)).single;
        expect(child.id, childId);
        expect(child.requestId, 'child:${parent.id}:call-1');
        expect(child.consumer, _agentA);
        final line = (await HireReceiptLineRecord.db.find(
          session,
          where: (t) => t.parentHireId.equals(parent.id),
        )).single;
        expect(line.childHireId, childId);
        expect(line.state, ReceiptLineState.pending);
        final submission = (await ChainSubmission.db.find(
          session,
          where: (t) => t.hireId.equals(childId),
        )).single;
        expect(submission.purpose, SubmissionPurpose.createChildJob.wireName);
        expect(line.createTransaction, submission.transaction);
        expect(stack.sent, [submission.signedEnvelopeXdr]);

        // A retry of the call reads the database and sends nothing.
        expect(
          await stack.port.requestChild(_request(parent.id, 'call-1')),
          childId,
        );
        expect(stack.sent, hasLength(1));
      });

      test(
        'a conflict inside the transaction rolls back the child hire and its '
        'receipt line, so a retry of the call opens it',
        () async {
          final parent = await stack.parent();
          await stack.port.requestChild(_request(parent.id, 'call-1'));

          // The same sequence and arguments draft the same envelope: the
          // submission insert conflicts after the hire and the line.
          await expectLater(
            stack.port.requestChild(_request(parent.id, 'call-2')),
            throwsA(
              isA<SubcontractRefused>().having(
                (e) => e.code,
                'code',
                'chain_busy',
              ),
            ),
          );

          expect(
            (await children(parent.id)).map((c) => c.requestId),
            ['child:${parent.id}:call-1'],
            reason: 'the call-2 child hire rolled back',
          );
          expect(
            await HireReceiptLineRecord.db.count(
              session,
              where: (t) => t.parentHireId.equals(parent.id),
            ),
            1,
            reason: 'the call-2 receipt line rolled back',
          );
          expect(stack.sent, hasLength(1));

          stack.accounts.sequence += 1;
          final second = await stack.port.requestChild(
            _request(parent.id, 'call-2'),
          );

          final child = (await stack.hires.findHire(second))!;
          expect(child.requestId, 'child:${parent.id}:call-2');
          expect(stack.signers, hasLength(3));
          expect(stack.sent, hasLength(2));
        },
      );
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}
