@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/agent/agent_catalog_service.dart';
import 'package:puls3_server/src/chain/escrow_effects.dart';
import 'package:puls3_server/src/chain/serverpod_chain_submission_store.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/escrow_preparation_store.dart';
import 'package:puls3_server/src/hire/escrow_relay_service.dart';
import 'package:puls3_server/src/hire/hire_escrow_effects.dart';
import 'package:puls3_server/src/hire/hire_relay_config.dart';
import 'package:puls3_server/src/hire/hire_service.dart';
import 'package:puls3_server/src/hire/serverpod_escrow_preparation_store.dart';
import 'package:puls3_server/src/hire/serverpod_hire_repository.dart';
import 'package:puls3_server/src/ledger/escrow_events.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:serverpod/serverpod.dart' show Session;
import 'package:test/test.dart';

import '../support/fake_chain_accounts.dart';
import '../support/fake_envelope_codec.dart';
import '../support/fake_submission_ledger.dart';
import '../unit/hire/hire_test_fakes.dart';
import 'test_tools/serverpod_test_tools.dart';

const _alice = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _agentWallet = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';
final _at = DateTime.utc(2026, 10, 7, 12);
const _env = {
  'PULS3_ESCROW_PREPARATION_VALIDITY_SECONDS': '300',
  'PULS3_STELLAR_INCLUSION_FEE_STROOPS': '100',
  'PULS3_PLATFORM_FEE_BPS': '0',
  'PULS3_HIRE_JOB_DURATION_SECONDS': '86400',
};

/// The hire services over the Serverpod stores of one [session], with fake
/// chain ports.
final class _Stack {
  _Stack(Session session, {String Function()? newPreparationId})
    : hires = ServerpodHireRepository(session),
      preparations = ServerpodEscrowPreparationStore(session, now: () => _at),
      submissions = ServerpodChainSubmissionStore(session, now: () => _at) {
    ledger
      ..wallets[7] = StellarAddress.parse(_agentWallet)
      ..metadata[7] = {
        'id': utf8.encode('agt-001'),
        'name': utf8.encode('Test Agent'),
        'description': utf8.encode('A helpful test agent for verification.'),
        'skills': utf8.encode(jsonEncode(['coding'])),
        'priceUsdcStroops': utf8.encode('5000000'),
        'puls3.manifestVersion': utf8.encode('1'),
      }.map((k, v) => MapEntry(k, Uint8List.fromList(v)));
    relay = EscrowRelayService(
      preparations: preparations,
      submissions: submissions,
      hires: hires,
      accounts: accounts,
      codec: codec,
      sender: sender,
      agentWallets: ledger,
      agents: (id) async => AgentSummary(
        id: 'agt-001',
        registryId: 7,
        name: 'Test Agent',
        description: 'A helpful test agent for verification.',
        skills: ['coding'],
        priceUsdcStroops: 5000000,
        wallet: _agentWallet,
      ),
      stellar: StellarConfig.testnet,
      config: const HireRelayConfig(_env),
      now: () => _at,
      newPreparationId: newPreparationId,
    );
    service = HireService(
      hires: hires,
      preparations: preparations,
      relay: relay,
      registry: ledger,
      catalog: AgentCatalogService(ledger),
      config: const HireRelayConfig(_env),
      now: () => _at,
    );
  }

  final ServerpodHireRepository hires;
  final ServerpodEscrowPreparationStore preparations;
  final ServerpodChainSubmissionStore submissions;
  final accounts = FakeChainAccounts();
  final codec = FakeEnvelopeCodec();
  final sender = FakeSubmissionLedger();
  final ledger = FakeLedger();
  late final EscrowRelayService relay;
  late final HireService service;

  Future<CreateHireResult> create({String requestId = 'it-request-1'}) =>
      service.createHire(
        agentId: 7,
        consumer: _alice,
        input: 'summarise this',
        requestId: requestId,
      );
}

void main() {
  withServerpod('Given createHire on PostgreSQL', (sessionBuilder, _) {
    late Session session;
    late _Stack stack;

    setUp(() {
      session = sessionBuilder.build();
      stack = _Stack(session);
    });

    test(
      'stores the hire and its preparation, and a retry returns both',
      () async {
        final first = await stack.create();

        final again = await stack.create();

        expect(again.hire.id, first.hire.id);
        expect(
          again.preparedCreateJob!.preparationId,
          first.preparedCreateJob!.preparationId,
        );
        final record = (await HireRecord.db.findById(session, first.hire.id))!;
        expect(record.requestId, 'it-request-1');
        expect(record.input, 'summarise this');
        expect(record.jobId, isNull);
        expect(
          await EscrowPreparation.db.count(
            session,
            where: (t) => t.hireId.equals(first.hire.id),
          ),
          1,
        );
      },
    );

    test('a failing preparation insert rolls the hire back', () async {
      // The same preparation id twice: the second insert violates the unique
      // index, after the hire of the second request was inserted.
      final dup = _Stack(session, newPreparationId: () => 'it-same-id');
      await dup.create(requestId: 'it-request-a');

      await expectLater(
        dup.create(requestId: 'it-request-b'),
        throwsA(isA<EscrowPreparationConflict>()),
      );

      expect(
        await HireRecord.db.count(
          session,
          where: (t) => t.requestId.equals('it-request-b'),
        ),
        0,
      );
      expect(
        await HireRecord.db.count(
          session,
          where: (t) => t.requestId.equals('it-request-a'),
        ),
        1,
      );
    });

    test('a failed first preparation stores no hire', () async {
      stack.accounts.simulationFailure = Puls3ApiException(
        code: 'ChainUnavailable',
      );

      await expectLater(stack.create(), throwsA(isA<Puls3ApiException>()));

      expect(
        await HireRecord.db.count(
          session,
          where: (t) => t.requestId.equals('it-request-1'),
        ),
        0,
      );
    });

    test('create_job, submit and onJobCreated open the hire', () async {
      final created = await stack.create();
      final prepared = created.preparedCreateJob!;
      final wallet = StellarAddress.parse(_alice);
      final xdr = FakeEnvelopeCodec.sign(prepared.unsignedTransactionXdr!);

      final detail = await stack.relay.submitEscrowCall(
        wallet,
        created.hire.id,
        prepared.preparationId,
        xdr,
      );
      expect(detail.escrowSubmission!.state, 'submitted');
      final stored = (await stack.submissions.findByPreparation(
        prepared.preparationId,
      ))!;
      final effects = HireEscrowEffects(
        repositories: <T>(action) => action(stack.hires),
        lifecycle: <T>(action) => action(stack.hires, stack.preparations),
        ledger: stack.ledger,
        jobs: stack.ledger,
        usdc: StellarConfig.testnet.usdcSac,
      );
      final event = JobCreatedEvent(
        jobId: 4242,
        client: wallet,
        provider: StellarAddress.parse(_agentWallet),
        evaluator: wallet,
        agentId: AgentId(7),
        token: StellarConfig.testnet.usdcSac,
        budget: BigInt.from(5000000),
        expiredAt: 1,
      );

      final first = await effects.onJobCreated(stored, event);
      final second = await effects.onJobCreated(stored, event);

      expect(first, isA<EffectOk>());
      expect(second, isA<EffectOk>());
      final hire = (await stack.hires.findHire(created.hire.id))!;
      expect(hire.jobId, 4242);
      expect(hire.status, HireStatus.open);
      final preparation = (await stack.preparations.findByPreparationId(
        prepared.preparationId,
      ))!;
      expect(hire.expiredAt, preparation.jobExpiredAt);
      expect(preparation.submittedAt, isNotNull);

      final other = await stack.create(requestId: 'it-request-2');
      final otherPrepared = other.preparedCreateJob!;
      final otherStored = await stack.submissions.insertSubmitted(
        purpose: SubmissionPurpose.createJob,
        transactionHash: 'c' * 64,
        signedEnvelopeXdr: 'AAAA',
        validUntil: _at,
        preparationId: otherPrepared.preparationId,
        hireId: other.hire.id,
      );
      final clash = await effects.onJobCreated(otherStored, event);
      expect(clash, isA<EffectFailed>());
      expect((await stack.hires.findHire(other.hire.id))!.jobId, isNull);
    });
  });

  // Two calls racing on one request need committed, concurrent transactions.
  withServerpod(
    'Given two createHire calls with one request id',
    (sessionBuilder, _) {
      const requestId = 'it-race-request';

      tearDown(() async {
        final session = sessionBuilder.build();
        final rows = await HireRecord.db.find(
          session,
          where: (t) => t.requestId.equals(requestId),
        );
        for (final row in rows) {
          await EscrowPreparation.db.deleteWhere(
            session,
            where: (t) => t.hireId.equals(row.id!),
          );
        }
        await HireRecord.db.deleteWhere(
          session,
          where: (t) => t.requestId.equals(requestId),
        );
      });

      test('store one hire and one preparation and answer both', () async {
        final a = _Stack(sessionBuilder.build());
        final b = _Stack(sessionBuilder.build());

        final results = await Future.wait([
          a.create(requestId: requestId),
          b.create(requestId: requestId),
        ]);

        expect(results[0].hire.id, results[1].hire.id);
        expect(
          results[0].preparedCreateJob!.preparationId,
          results[1].preparedCreateJob!.preparationId,
        );
        final session = sessionBuilder.build();
        expect(
          await HireRecord.db.count(
            session,
            where: (t) => t.requestId.equals(requestId),
          ),
          1,
        );
        expect(
          await EscrowPreparation.db.count(
            session,
            where: (t) => t.hireId.equals(results[0].hire.id),
          ),
          1,
        );
      });
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}
