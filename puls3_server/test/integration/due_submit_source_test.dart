import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/agent/secret_cipher.dart';
import 'package:puls3_server/src/agent/serverpod_agent_wallet_store.dart';
import 'package:puls3_server/src/chain/escrow_deadline.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/generated/protocol.dart' show ChainSubmission;
import 'package:puls3_server/src/hire/serverpod_hire_repository.dart';
import 'package:puls3_server/src/runtime/serverpod_due_submit_source.dart';
import 'package:puls3_server/src/runtime/serverpod_hire_run_store.dart';
import 'package:serverpod/serverpod.dart' show Session;
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

const _alice = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';

/// Custodied by the server.
const _custodied = 'GDWVBEPVODIA7D3A2II7LBR7FLD4TZDFOVWWVAXUAYPV4F4J5ZIIKWNF';

/// A seed agent payee with no custodied wallet (escrow admin).
const _uncustodied = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';

void main() {
  withServerpod('ServerpodDueSubmitSource', (sessionBuilder, _) {
    var serial = 0;

    Future<void> custody(Session session) =>
        ServerpodAgentWalletStore(session).save(
          owner: StellarAddress.parse(_alice),
          address: StellarAddress.parse(_custodied),
          idempotencyKey: 'due-submit-wallet',
          secret: const EncryptedSecret(
            ciphertext: 'Y2lwaGVy',
            nonce: 'bm9uY2U=',
            mac: 'bWFj',
            keyVersion: 1,
          ),
          createdAt: DateTime.utc(2026, 10, 26),
        );

    /// A funded hire paid to [payee], bound to a job, whose run succeeded.
    Future<int> succeeded(Session session, {String payee = _custodied}) async {
      serial++;
      final repo = ServerpodHireRepository(session);
      final hire = await repo.create(
        agentId: AgentId(7),
        consumer: StellarAddress.parse(_alice),
        price: UsdcAmount.stroops(5000000),
        manifestVersion: 1,
        expiredAt: 1700000000,
      );
      await repo.bindJob(hire.id.value, 500 + serial, expiredAt: 1700000000);
      await repo.recordPayment(
        hire,
        Payment(
          transaction: TransactionHash.parse(
            serial.toRadixString(16).padLeft(64, '0'),
          ),
          hireId: hire.id,
          payer: StellarAddress.parse(_alice),
          payee: StellarAddress.parse(payee),
          amount: UsdcAmount.stroops(5000000),
        ),
        500 + serial,
      );
      final runs = ServerpodHireRunStore(session);
      final at = DateTime.utc(2026, 10, 26);
      await runs.markRunning(hire.id.value, at);
      await runs.markSucceeded(hire.id.value, 'output $serial', at);
      return hire.id.value;
    }

    Future<void> relay(
      Session session,
      int hireId,
      SubmissionPurpose purpose,
      SubmissionState state,
    ) async {
      serial++;
      await ChainSubmission.db.insertRow(
        session,
        ChainSubmission(
          purpose: purpose.wireName,
          transaction: 'e${serial.toRadixString(16).padLeft(63, '0')}',
          state: state.wireName,
          updatedAt: DateTime.utc(2026, 10, 26),
          hireId: hireId,
          sendAttempts: 0,
        ),
      );
    }

    test('returns a funded custodied hire with its job and output', () async {
      final session = sessionBuilder.build();
      await custody(session);
      final hireId = await succeeded(session);

      final due = await ServerpodDueSubmitSource(session).list();

      expect(due, hasLength(1));
      expect(due.single.hireId, hireId);
      expect(due.single.jobId, 500 + 1);
      expect(due.single.provider.value, _custodied);
      expect(due.single.result, startsWith('output '));
    });

    test(
      'settled and stuck runs ahead of a fresh one do not starve it',
      () async {
        final session = sessionBuilder.build();
        await custody(session);
        // 40 runs older than the fresh one, more than the 30-row window of
        // list(limit: 10): settled, out of attempts, or not custodied.
        for (var i = 0; i < 10; i++) {
          final submitted = await succeeded(session);
          await relay(
            session,
            submitted,
            SubmissionPurpose.submit,
            SubmissionState.confirmed,
          );
          final completed = await succeeded(session);
          await relay(
            session,
            completed,
            SubmissionPurpose.submit,
            SubmissionState.confirmed,
          );
          await relay(
            session,
            completed,
            SubmissionPurpose.complete,
            SubmissionState.confirmed,
          );
          final exhausted = await succeeded(session);
          for (var n = 0; n < maxEscrowCallAttempts; n++) {
            await relay(
              session,
              exhausted,
              SubmissionPurpose.submit,
              SubmissionState.failed,
            );
          }
          await succeeded(session, payee: _uncustodied);
        }
        final fresh = await succeeded(session);

        final due = await ServerpodDueSubmitSource(session).list();

        expect(due.map((d) => d.hireId), [fresh]);
      },
    );

    test(
      'a hire with fewer failed submits than the limit is still due',
      () async {
        final session = sessionBuilder.build();
        await custody(session);
        final hireId = await succeeded(session);
        for (var n = 0; n < maxEscrowCallAttempts - 1; n++) {
          await relay(
            session,
            hireId,
            SubmissionPurpose.submit,
            SubmissionState.failed,
          );
        }

        final due = await ServerpodDueSubmitSource(session).list();

        expect(due.map((d) => d.hireId), [hireId]);
      },
    );

    test('stops at limit, oldest run first', () async {
      final session = sessionBuilder.build();
      await custody(session);
      final ids = [for (var i = 0; i < 5; i++) await succeeded(session)];

      final due = await ServerpodDueSubmitSource(session).list(limit: 2);

      expect(due.map((d) => d.hireId), ids.take(2));
    });
  });
}
