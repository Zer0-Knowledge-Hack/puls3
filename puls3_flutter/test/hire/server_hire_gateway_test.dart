import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_client/puls3_client.dart';
import 'package:puls3_flutter/src/hire/hire_gateway.dart';
import 'package:puls3_flutter/src/hire/server_hire_gateway.dart';

const _consumer = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';

Hire _hire(int id) => Hire(
  id: id,
  agentId: 9,
  consumer: _consumer,
  price: 45000000,
  manifestVersion: 1,
);

PreparedTransaction _prepared(
  String purpose, {
  String? xdr = 'AAAA-unsigned',
}) => PreparedTransaction(
  preparationId: 'prep-$purpose',
  purpose: purpose,
  signer: _consumer,
  networkPassphrase: 'Test SDF Network ; September 2015',
  unsignedTransactionXdr: xdr,
  expiresAt: DateTime(2030),
);

HireDetail _detail(String state, {String? errorCode}) => HireDetail(
  hire: _hire(3),
  agent: AgentSummary(
    id: 'agt-003',
    registryId: 9,
    name: 'Soroban Auditor',
    description: 'Reviews contracts',
    skills: ['security'],
    priceUsdcStroops: 45000000,
  ),
  input: 'Audit this',
  escrowSubmission: ChainSubmission(
    preparationId: 'prep-fund',
    purpose: 'fund',
    transaction: 'abc123',
    state: state,
    errorCode: errorCode,
    explorerUrl: 'https://stellar.expert/explorer/testnet/tx/abc123',
    updatedAt: DateTime(2030),
  ),
);

ServerHireGateway _gateway({
  CreateHireCall? createHire,
  PrepareEscrowCall? prepareCreateJob,
  PrepareEscrowCall? prepareFund,
  SubmitEscrowCall? submit,
  Duration confirmationTimeout = const Duration(seconds: 1),
}) => ServerHireGateway(
  createHire:
      createHire ??
      (_, _, _, _) async => CreateHireResult(
        hire: _hire(3),
        preparedCreateJob: _prepared('createJob'),
      ),
  prepareCreateJob: prepareCreateJob ?? (_) async => _prepared('createJob'),
  prepareFund: prepareFund ?? (_) async => _prepared('fund'),
  submitEscrowCall: submit ?? (_, _, _) async => _detail('submitted'),
  pollInterval: const Duration(milliseconds: 5),
  confirmationTimeout: confirmationTimeout,
);

void main() {
  group('ServerHireGateway', () {
    test(
      'createHire passes the request through and returns the create_job',
      () async {
        final calls = <List<Object>>[];
        final gateway = _gateway(
          createHire: (agentId, consumer, input, requestId) async {
            calls.add([agentId, consumer, input, requestId]);
            return CreateHireResult(
              hire: _hire(3),
              preparedCreateJob: _prepared('createJob'),
            );
          },
        );
        final start = await gateway.createHire(
          agentId: 9,
          consumer: _consumer,
          input: 'Audit this',
          requestId: 'req-1',
        );
        expect(calls.single, [9, _consumer, 'Audit this', 'req-1']);
        expect(start.hireId, 3);
        expect(start.createJob!.purpose, 'createJob');
        expect(start.createJob!.unsignedTransaction, 'AAAA-unsigned');
        expect(gateway.isDemo, isFalse);
      },
    );

    test('no wallet session yet is a clear "not signed in" error', () async {
      final gateway = _gateway(
        createHire: (_, _, _, _) async =>
            throw Puls3ApiException(code: 'AuthenticationUnavailable'),
      );
      await expectLater(
        gateway.createHire(
          agentId: 9,
          consumer: _consumer,
          input: 'x',
          requestId: 'r',
        ),
        throwsA(isA<HireNotSignedIn>()),
      );
    });

    test('prepareFund waits while the create_job confirms', () async {
      var calls = 0;
      final gateway = _gateway(
        prepareFund: (_) async {
          calls++;
          if (calls == 1) {
            throw Puls3ApiException(code: 'SubmissionInProgress');
          }
          if (calls == 2) {
            throw Puls3ApiException(code: 'InvalidHireTransition');
          }
          return _prepared('fund');
        },
      );
      final fund = await gateway.prepareFund(3);
      expect(calls, 3);
      expect(fund.purpose, 'fund');
    });

    test('prepareFund gives up after its limit', () async {
      final gateway = _gateway(
        prepareFund: (_) async =>
            throw Puls3ApiException(code: 'SubmissionInProgress'),
        confirmationTimeout: const Duration(milliseconds: 30),
      );
      await expectLater(
        gateway.prepareFund(3),
        throwsA(isA<HireBackendUnavailable>()),
      );
    });

    test('a hire in another state is refused, not polled', () async {
      final gateway = _gateway(
        prepareFund: (_) async => throw Puls3ApiException(
          code: 'InvalidHireTransition',
          details: {'status': 'funded'},
        ),
      );
      await expectLater(
        gateway.prepareFund(3),
        throwsA(isA<HirePaymentAlreadySubmitted>()),
      );
    });

    test('a failed fund simulation does not claim missing funds', () async {
      final gateway = _gateway(
        prepareFund: (_) async => throw Puls3ApiException(
          code: 'ChainUnavailable',
          details: {'reason': 'simulationFailed'},
        ),
      );
      await expectLater(
        gateway.prepareFund(3),
        throwsA(
          isA<HirePaymentNotPrepared>().having(
            (e) => e.message,
            'message',
            allOf(contains('USDC and XLM'), contains('could not be prepared')),
          ),
        ),
      );
    });

    test('an earlier payment is never prepared again', () async {
      final gateway = _gateway(
        prepareFund: (_) async =>
            throw Puls3ApiException(code: 'PaymentAlreadySubmitted'),
      );
      await expectLater(
        gateway.prepareFund(3),
        throwsA(isA<HirePaymentAlreadySubmitted>()),
      );
    });

    test('submit relays the signed envelope unchanged', () async {
      final sent = <List<Object>>[];
      final gateway = _gateway(
        submit: (hireId, preparationId, signed) async {
          sent.add([hireId, preparationId, signed]);
          return _detail('submitted');
        },
      );
      final submission = await gateway.submit(
        3,
        const EscrowPreparation(
          preparationId: 'prep-fund',
          purpose: 'fund',
          unsignedTransaction: 'AAAA-unsigned',
        ),
        'AAAA-signed',
      );
      expect(sent.single, [3, 'prep-fund', 'AAAA-signed']);
      expect(submission.transactionHash, 'abc123');
      expect(submission.explorerUrl, contains('/tx/abc123'));
    });

    test('an expired preparation and a failed submission are typed', () async {
      const prep = EscrowPreparation(
        preparationId: 'p',
        purpose: 'fund',
        unsignedTransaction: 'x',
      );
      await expectLater(
        _gateway(
          submit: (_, _, _) async =>
              throw Puls3ApiException(code: 'PreparationExpired'),
        ).submit(3, prep, 's'),
        throwsA(isA<HirePreparationExpired>()),
      );
      await expectLater(
        _gateway(
          submit: (_, _, _) async =>
              _detail('failed', errorCode: 'TransactionFailed'),
        ).submit(3, prep, 's'),
        throwsA(isA<HireSubmissionFailed>()),
      );
    });

    test('a payment that does not match the hire never claims that no '
        'funds moved', () async {
      const prep = EscrowPreparation(
        preparationId: 'p',
        purpose: 'fund',
        unsignedTransaction: 'x',
      );
      await expectLater(
        _gateway(
          submit: (_, _, _) async =>
              _detail('failed', errorCode: 'JobMismatch'),
        ).submit(3, prep, 's'),
        throwsA(
          isA<HireRejected>().having(
            (e) => e.message,
            'message',
            allOf(contains('stay in the escrow'), isNot(contains('No funds'))),
          ),
        ),
      );
    });

    test('final submission failures ask for a new preparation', () async {
      const prep = EscrowPreparation(
        preparationId: 'p',
        purpose: 'fund',
        unsignedTransaction: 'x',
      );
      for (final code in ['SubmissionRejected', 'TransactionFailed']) {
        await expectLater(
          _gateway(
            submit: (_, _, _) async => _detail('failed', errorCode: code),
          ).submit(3, prep, 's'),
          throwsA(isA<HireSubmissionFailed>()),
          reason: code,
        );
      }
      await expectLater(
        _gateway(
          submit: (_, _, _) async =>
              throw Puls3ApiException(code: 'PreparationNotFound'),
        ).submit(3, prep, 's'),
        throwsA(isA<HireSubmissionFailed>()),
      );
    });

    test(
      'a resumed hire that is already funded is never prepared again',
      () async {
        for (final status in ['funded', 'submitted', 'completed']) {
          await expectLater(
            _gateway(
              prepareFund: (_) async => throw Puls3ApiException(
                code: 'InvalidHireTransition',
                details: {'status': status},
              ),
            ).prepareFund(3),
            throwsA(isA<HirePaymentAlreadySubmitted>()),
            reason: status,
          );
        }
        await expectLater(
          _gateway(
            prepareFund: (_) async => throw Puls3ApiException(
              code: 'InvalidHireTransition',
              details: {'status': 'expired'},
            ),
          ).prepareFund(3),
          throwsA(isA<HireClosed>()),
        );
      },
    );

    test('a server that does not answer is a retryable error', () async {
      final gateway = ServerHireGateway(
        createHire: (_, _, _, _) => Completer<CreateHireResult>().future,
        prepareCreateJob: (_) async => _prepared('createJob'),
        prepareFund: (_) async => _prepared('fund'),
        submitEscrowCall: (_, _, _) async => _detail('submitted'),
        callTimeout: const Duration(milliseconds: 20),
      );
      await expectLater(
        gateway.createHire(
          agentId: 9,
          consumer: _consumer,
          input: 'x',
          requestId: 'r',
        ),
        throwsA(isA<HireBackendUnavailable>()),
      );
    });
  });
}
