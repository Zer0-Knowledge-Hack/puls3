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
  GetHireCall? getHire,
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
  getHire: getHire ?? (_, _) async => _detail('confirmed'),
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
        getHire: (_, _) async => _detail('confirmed'),
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

  group('ServerHireGateway.getHire (S06)', () {
    HireDetail funded({
      String? status = 'funded',
      String? runtimeStatus = 'running',
      String? result,
      String? paymentTransaction = 'fa11ce',
      ChainSubmission? submission,
    }) => HireDetail(
      hire: _hire(3).copyWith(
        status: status,
        runtimeStatus: runtimeStatus,
        paymentTransaction: paymentTransaction,
      ),
      agent: AgentSummary(
        id: 'agt-007',
        registryId: 13,
        name: 'Support Relay',
        description: 'Answers support tickets',
        skills: ['support'],
        priceUsdcStroops: 45000000,
      ),
      input: 'Answer this ticket',
      result: result,
      escrowSubmission: submission,
    );

    ChainSubmission submission(String purpose, String hash) => ChainSubmission(
      purpose: purpose,
      transaction: hash,
      state: 'confirmed',
      explorerUrl: 'https://stellar.expert/explorer/testnet/tx/$hash',
      updatedAt: DateTime(2030),
    );

    test('reads the hire of the consumer and maps the detail', () async {
      final calls = <(int, String)>[];
      final gateway = _gateway(
        getHire: (id, consumer) async {
          calls.add((id, consumer));
          return funded(
            result: 'Ticket answered',
            submission: submission('fund', 'fa11ce'),
          );
        },
      );

      final hire = await gateway.getHire(3, _consumer);

      expect(calls, [(3, _consumer)]);
      expect(hire.hireId, 3);
      expect(hire.agentName, 'Support Relay');
      expect(hire.priceUsdcStroops, 45000000);
      expect(hire.input, 'Answer this ticket');
      expect(hire.result, 'Ticket answered');
      expect(hire.stage, HireStage.delivered);
      expect(hire.paymentTransaction, 'fa11ce');
      expect(
        hire.paymentExplorerUrl,
        'https://stellar.expert/explorer/testnet/tx/fa11ce',
      );
    });

    test('takes the payment from the fund submission until the hire has '
        'one', () async {
      final hire = await _gateway(
        getHire: (_, _) async => funded(
          status: null,
          paymentTransaction: null,
          submission: submission('fund', 'beef'),
        ),
      ).getHire(3, _consumer);
      expect(hire.paymentTransaction, 'beef');
      expect(hire.paymentExplorerUrl, contains('/tx/beef'));
      expect(hire.stage, HireStage.awaitingPayment);
    });

    test('never links another submission as the payment', () async {
      final hire = await _gateway(
        getHire: (_, _) async => funded(
          paymentTransaction: null,
          submission: submission('createJob', 'c0ffee'),
        ),
      ).getHire(3, _consumer);
      expect(hire.paymentTransaction, isNull);
      expect(hire.paymentExplorerUrl, isNull);

      final paid = await _gateway(
        getHire: (_, _) async =>
            funded(submission: submission('submit', '5eed')),
      ).getHire(3, _consumer);
      expect(paid.paymentTransaction, 'fa11ce');
      expect(paid.paymentExplorerUrl, isNull);
    });

    test('an unknown or foreign hire is HireNotFound', () async {
      for (final code in ['HireNotFound', 'HireNotOwned', 'InvalidHireId']) {
        await expectLater(
          _gateway(
            getHire: (_, _) async => throw Puls3ApiException(code: code),
          ).getHire(3, _consumer),
          throwsA(isA<HireNotFound>()),
          reason: code,
        );
      }
    });

    test('no session is HireNotSignedIn; an unreachable chain is '
        'retryable', () async {
      await expectLater(
        _gateway(
          getHire: (_, _) async =>
              throw Puls3ApiException(code: 'NotAuthenticated'),
        ).getHire(3, _consumer),
        throwsA(isA<HireNotSignedIn>()),
      );
      await expectLater(
        _gateway(
          getHire: (_, _) async =>
              throw Puls3ApiException(code: 'ChainDataUnavailable'),
        ).getHire(3, _consumer),
        throwsA(isA<HireBackendUnavailable>()),
      );
    });
  });

  group('HireProgress.stage', () {
    HireProgress progress({
      String? status,
      String? runtimeStatus,
      String? result,
      String? rejectedFrom,
    }) => HireProgress(
      hireId: 3,
      agentName: 'Support Relay',
      priceUsdcStroops: 1,
      input: 'x',
      status: status,
      runtimeStatus: runtimeStatus,
      result: result,
      rejectedFrom: rejectedFrom,
    );

    test('follows the escrow status and, while funded, the run', () {
      expect(progress().stage, HireStage.awaitingPayment);
      expect(progress(status: 'open').stage, HireStage.awaitingPayment);
      expect(progress(status: 'funded').stage, HireStage.queued);
      expect(
        progress(status: 'funded', runtimeStatus: 'queued').stage,
        HireStage.queued,
      );
      expect(
        progress(status: 'funded', runtimeStatus: 'running').stage,
        HireStage.running,
      );
      // A succeeded run reads `running` until its submit lands.
      expect(
        progress(
          status: 'funded',
          runtimeStatus: 'running',
          result: 'ok',
        ).stage,
        HireStage.delivered,
      );
      expect(
        progress(status: 'funded', runtimeStatus: 'failed').stage,
        HireStage.runFailed,
      );
      expect(progress(status: 'submitted').stage, HireStage.submitted);
      expect(progress(status: 'completed').stage, HireStage.completed);
      expect(progress(status: 'rejected').stage, HireStage.rejected);
      expect(progress(status: 'expired').stage, HireStage.expired);
    });

    test('polling stops only where nothing moves without the client', () {
      expect(
        HireStage.values.where((s) => s.isFinal),
        [
          HireStage.runFailed,
          HireStage.completed,
          HireStage.rejected,
          HireStage.expired,
        ],
      );
    });

    test('a reject from open is a cancel', () {
      expect(
        progress(status: 'rejected', rejectedFrom: 'open').isCancelled,
        isTrue,
      );
      expect(
        progress(status: 'rejected', rejectedFrom: 'funded').isCancelled,
        isFalse,
      );
    });
  });
}
