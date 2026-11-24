@Tags(['integration'])
library;

import 'dart:io';

import 'package:puls3_sdk/puls3_sdk.dart' as sdk;
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';
// The test server is built without `run`, so it has no auth handler; this is
// Serverpod's own hook for setting one in tests.
// ignore: implementation_imports
import 'package:serverpod/src/server/server.dart' show ServerInternalMethods;
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:test/test.dart';

import 'sdk_contract/sdk_world.dart';
import 'test_tools/serverpod_test_tools.dart';

const _otherWallet = 'GBY33NK3HMKQUKHL7YSCJ2W5JMJ62MEVKEJTRUWNQXBQIFLUVZY6TJ4R';

/// `puls3_sdk` against this server over HTTP (#375).
///
/// Every call goes through the generated client, a CLI session minted by
/// the real wallet sign-in and its refresh, and the real endpoints on the
/// test database. Only the chain is faked (see [SdkWorld]). A fake of the
/// server cannot catch a call the server reads differently, such as the
/// trimmed idempotency key found in #369; these tests compare what the SDK
/// sends with what the server stores.
void main() {
  withServerpod(
    'Given puls3_sdk over HTTP (#375)',
    rollbackDatabase: RollbackDatabase.disabled,
    (sessionBuilder, _) {
      late SdkWorld world;
      late sdk.Puls3Sdk signedIn;

      setUpAll(() async {
        // `run` (lib/server.dart) does this through
        // `initializeAuthServices`; the test server needs it to accept bearer
        // tokens over HTTP.
        AuthServices.set(tokenManagerBuilders: [JwtConfigFromPasswords()]);
        Serverpod.instance.server.setAuthenticationHandlerForTesting(
          AuthServices.instance.authenticationHandler,
        );
        world = await SdkWorld.start(sessionBuilder);
        // One sign-in for the group: the challenge endpoint is rate limited.
        signedIn = await world.signedInSdk();
      });

      tearDownAll(() => world.close());

      Matcher apiError(String code, {Map<String, String>? details}) => throwsA(
        isA<sdk.Puls3ApiException>()
            .having((e) => e.code, 'code', code)
            .having((e) => e.details, 'details', details),
      );

      /// A hire of the signed-in wallet with its `create_job` confirmed.
      Future<HireRecord> openHire(String requestId) async {
        final created = await world.createHire(requestId: requestId);
        return HireRecord.db.updateRow(
          world.db,
          (await HireRecord.db.findById(world.db, created.hire.id))!.copyWith(
            jobId: 9000 + created.hire.id,
          ),
        );
      }

      /// [openHire], funded, with the agent's `submit` confirmed.
      Future<HireRecord> submittedHire(String requestId) async {
        final hire = await openHire(requestId);
        await HirePaymentRecord.db.insertRow(
          world.db,
          HirePaymentRecord(
            hireId: hire.id!,
            transactionHash: 'fund-${hire.id}',
            jobId: hire.jobId!,
            payer: world.wallet,
            payee: 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
            amount: agentPrice,
          ),
        );
        await ChainSubmission.db.insertRow(
          world.db,
          ChainSubmission(
            purpose: 'submit',
            transaction: 'submit-${hire.id}',
            state: 'confirmed',
            updatedAt: DateTime.now().toUtc(),
            hireId: hire.id,
          ),
        );
        return hire;
      }

      Future<EscrowPreparation> currentPreparation(int hireId) async =>
          (await EscrowPreparation.db.findFirstRow(
            world.db,
            where: (t) => t.hireId.equals(hireId) & t.supersededAt.equals(null),
            orderByList: (t) => [t.id.desc()],
          ))!;

      Future<int> submissionsOf(int hireId) => ChainSubmission.db.count(
        world.db,
        where: (t) => t.hireId.equals(hireId),
      );

      group('the catalog, with no session', () {
        test('lists the agents the server lists', () async {
          final client = sdk.Puls3Sdk.connect(world.apiUrl);
          addTearDown(client.close);

          final agent = (await client.listAgents()).single;

          expect(agent.id, 'agt-001');
          expect(agent.registryId, agentRegistryId);
          expect(agent.priceUsdcStroops, agentPrice);
          expect(agent.skills, ['coding']);
        });

        test('gets one agent by id, and null for an unknown one', () async {
          final client = sdk.Puls3Sdk.connect(world.apiUrl);
          addTearDown(client.close);

          expect((await client.getAgent('agt-001'))!.name, 'Test Agent');
          expect(await client.getAgent('agt-999'), isNull);
        });
      });

      group('a CLI session', () {
        test('is saved to the session file on its first call', () async {
          expect(File(world.sessionFile).existsSync(), isTrue);
        });
      });

      group('createHire', () {
        test(
          'stores the hire the SDK started and returns it unsigned',
          () async {
            final result = await signedIn.createHire(
              agentRegistryId,
              world.wallet,
              'summarise this',
              'contract-create',
            );

            final row = (await HireRecord.db.findById(
              world.db,
              result.hire.id,
            ))!;
            expect(row.consumer, world.wallet);
            expect(row.agentId, agentRegistryId);
            expect(row.price, agentPrice);
            expect(result.hire.id, row.id);
            expect(result.hire.agentId, row.agentId);
            expect(result.hire.consumer, row.consumer);
            expect(result.hire.price, row.price);
            expect(result.hire.status, isNull, reason: 'no job yet');
            expect(await submissionsOf(row.id!), 0, reason: 'nothing sent');
          },
        );

        test('the envelope it returns carries no signatures', () async {
          final result = await signedIn.createHire(
            agentRegistryId,
            world.wallet,
            'summarise this',
            'contract-unsigned',
          );

          final prepared = result.preparedCreateJob!;
          expect(prepared.purpose, 'createJob');
          expect(prepared.signer, world.wallet);
          expect(prepared.unsignedTransactionXdr, isNotEmpty);
          expect(
            world.codec.parse(prepared.unsignedTransactionXdr!).signatures,
            isEmpty,
          );
          final stored = await currentPreparation(result.hire.id);
          expect(prepared.unsignedTransactionXdr, stored.unsignedEnvelopeXdr);
        });

        test('a repeated requestId returns the same hire', () async {
          final first = await signedIn.createHire(
            agentRegistryId,
            world.wallet,
            'summarise this',
            'contract-repeat',
          );
          final hiresBefore = await HireRecord.db.count(
            world.db,
            where: (t) => t.consumer.equals(world.wallet),
          );
          final again = await signedIn.createHire(
            agentRegistryId,
            world.wallet,
            'summarise this',
            'contract-repeat',
          );

          expect(again.hire.id, first.hire.id);
          expect(
            await HireRecord.db.count(
              world.db,
              where: (t) => t.consumer.equals(world.wallet),
            ),
            hiresBefore,
            reason: 'the retry created no second hire',
          );
        });

        test('the requestId is sent exactly as given, never trimmed', () async {
          // The server uses the key raw (#369): padded and plain are two
          // keys, so two hires.
          final plain = await signedIn.createHire(
            agentRegistryId,
            world.wallet,
            'summarise this',
            'contract-raw',
          );
          final padded = await signedIn.createHire(
            agentRegistryId,
            world.wallet,
            'summarise this',
            '  contract-raw  ',
          );

          expect(padded.hire.id, isNot(plain.hire.id));
          final server = await world.createHire(
            requestId: '  contract-raw  ',
          );
          expect(server.hire.id, padded.hire.id);
        });

        test('a wallet that is not the session is WalletMismatch', () async {
          await expectLater(
            signedIn.createHire(
              agentRegistryId,
              _otherWallet,
              'summarise this',
              'contract-mismatch',
            ),
            apiError('WalletMismatch'),
          );
        });
      });

      group('getHire', () {
        test('returns the hire the server stored', () async {
          final created = await world.createHire(requestId: 'contract-get');
          final row = (await HireRecord.db.findById(
            world.db,
            created.hire.id,
          ))!;

          final detail = await signedIn.getHire(row.id!, world.wallet);

          expect(detail.hire.id, row.id);
          expect(detail.hire.consumer, row.consumer);
          expect(detail.hire.agentId, row.agentId);
          expect(detail.hire.price, row.price);
          expect(detail.hire.manifestVersion, row.manifestVersion);
          expect(detail.hire.status, isNull, reason: 'no job yet');
        });

        test(
          'the SDK trims the consumer, and the server accepts it',
          () async {
            final created = await world.createHire(requestId: 'contract-pad');

            final detail = await signedIn.getHire(
              created.hire.id,
              '  ${world.wallet}  ',
            );

            expect(detail.hire.id, created.hire.id);
          },
        );

        test('reaches the server for a hire that does not exist', () async {
          await expectLater(
            signedIn.getHire(999999, world.wallet),
            apiError('HireNotFound'),
          );
        });

        test("another wallet's hire is HireNotOwned", () async {
          final foreign = await HireRecord.db.insertRow(
            world.db,
            HireRecord(
              consumer: _otherWallet,
              agentId: agentRegistryId,
              price: agentPrice,
              manifestVersion: 1,
              expiredAt: 1795000000,
            ),
          );

          await expectLater(
            signedIn.getHire(foreign.id!, world.wallet),
            apiError('HireNotOwned'),
          );
        });

        test('asking as another consumer is WalletMismatch', () async {
          final created = await world.createHire(requestId: 'contract-other');

          await expectLater(
            signedIn.getHire(created.hire.id, _otherWallet),
            apiError('WalletMismatch'),
          );
        });
      });

      group('prepareReject', () {
        test(
          'stores the unsigned reject it returns, with the trimmed reason',
          () async {
            final hire = await openHire('contract-reject');

            final prepared = await signedIn.prepareReject(
              hire.id!,
              '  not needed any more  ',
            );

            final stored = await currentPreparation(hire.id!);
            expect(prepared.purpose, 'reject');
            expect(prepared.signer, world.wallet);
            expect(prepared.preparationId, stored.preparationId);
            expect(stored.rejectReason, 'not needed any more');
            // The SDK hands back the envelope the server stored, unsigned:
            // it never signs, re-encodes or replaces it.
            expect(prepared.unsignedTransactionXdr, stored.unsignedEnvelopeXdr);
            expect(prepared.transaction, stored.transactionHash);
            expect(await submissionsOf(hire.id!), 0, reason: 'nothing sent');
          },
        );

        test('a hire with no job cannot be rejected', () async {
          final created = await world.createHire(
            requestId: 'contract-reject-nojob',
          );

          await expectLater(
            signedIn.prepareReject(created.hire.id, 'no'),
            // Details reach the client since #390.
            apiError('InvalidHireTransition', details: {'purpose': 'reject'}),
          );
        });
      });

      group('prepareComplete', () {
        test('stores the unsigned complete of a submitted hire', () async {
          final hire = await submittedHire('contract-complete');
          final before = await submissionsOf(hire.id!);

          final prepared = await signedIn.prepareComplete(hire.id!);

          final stored = await currentPreparation(hire.id!);
          expect(prepared.purpose, 'complete');
          expect(prepared.signer, world.wallet);
          expect(prepared.preparationId, stored.preparationId);
          expect(prepared.unsignedTransactionXdr, stored.unsignedEnvelopeXdr);
          expect(stored.rejectReason, isNull);
          expect(await submissionsOf(hire.id!), before, reason: 'nothing sent');
        });

        test('an open hire cannot be completed', () async {
          final hire = await openHire('contract-complete-open');

          await expectLater(
            signedIn.prepareComplete(hire.id!),
            apiError(
              'InvalidHireTransition',
              details: {'status': 'open', 'purpose': 'complete'},
            ),
          );
        });
      });

      group('testRun', () {
        test('runs the stored draft on the input exactly as given', () async {
          final draftId = await world.saveDraft();
          world.studioTasks.clear();

          final result = await signedIn.testRun(draftId, '  A long note.  ');

          final task = world.studioTasks.single;
          expect(
            task.input,
            '  A long note.  ',
            reason: 'input is not trimmed',
          );
          expect(
            task.systemPrompt,
            'Summarize the text in five short bullet points.',
          );
          expect(result.output, 'echo:   A long note.  ');
          expect(result.remainingDailyRuns, greaterThanOrEqualTo(0));
        });

        test('an unknown draft is DraftNotFound', () async {
          await expectLater(
            signedIn.testRun(999999, 'hello'),
            apiError('DraftNotFound'),
          );
        });
      });
    },
  );
}
