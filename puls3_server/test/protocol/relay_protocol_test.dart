import 'dart:convert';

import 'package:puls3_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart' show SerializationManager;
import 'package:test/test.dart';

/// Encodes with the protocol and decodes back, as the wire does.
T _roundTrip<T>(T value) {
  final protocol = Protocol();
  final encoded = SerializationManager.encode(value);
  return protocol.deserialize<T>(jsonDecode(encoded));
}

Hire _hire({String? status = 'open'}) => Hire(
      id: 7,
      agentId: 3,
      consumer: 'GCONSUMER',
      price: 10000000,
      manifestVersion: 1,
      status: status,
    );

PreparedTransaction _prepared() => PreparedTransaction(
      preparationId: 'prep-1',
      purpose: 'createJob',
      signer: 'GCONSUMER',
      networkPassphrase: 'Test SDF Network ; September 2015',
      unsignedTransactionXdr: 'AAAA',
      transaction: 'ab' * 32,
      expiresAt: DateTime.utc(2026, 10, 7, 12),
    );

void main() {
  group('Puls3ApiException', () {
    test('round-trips code, message and details', () {
      final original = Puls3ApiException(
        code: 'EnvelopeMismatch',
        message: 'The signed envelope differs.',
        details: {'field': 'arguments'},
      );
      final decoded = _roundTrip(original);
      expect(decoded.code, 'EnvelopeMismatch');
      expect(decoded.message, 'The signed envelope differs.');
      expect(decoded.details, {'field': 'arguments'});
    });

    test('keeps message and details optional', () {
      final decoded = _roundTrip(Puls3ApiException(code: 'WalletMismatch'));
      expect(decoded.code, 'WalletMismatch');
      expect(decoded.message, isNull);
      expect(decoded.details, isNull);
    });

    test('is an exception that names its code', () {
      expect(Puls3ApiException(code: 'InternalError'), isA<Exception>());
    });
  });

  group('PreparedTransaction', () {
    test('round-trips a createJob preparation', () {
      final decoded = _roundTrip(_prepared());
      expect(decoded.preparationId, 'prep-1');
      expect(decoded.purpose, 'createJob');
      expect(decoded.signer, 'GCONSUMER');
      expect(decoded.unsignedTransactionXdr, 'AAAA');
      expect(decoded.authorizationEntryXdr, isNull);
      expect(decoded.signatureExpirationLedger, isNull);
      expect(decoded.expiresAt, DateTime.utc(2026, 10, 7, 12));
    });

    test('round-trips a setAgentWallet authorization entry', () {
      final decoded = _roundTrip(PreparedTransaction(
        preparationId: 'prep-2',
        purpose: 'setAgentWallet',
        signer: 'GOWNER',
        networkPassphrase: 'Test SDF Network ; September 2015',
        authorizationEntryXdr: 'BBBB',
        signatureExpirationLedger: 123456,
        expiresAt: DateTime.utc(2026, 10, 7, 13),
      ));
      expect(decoded.authorizationEntryXdr, 'BBBB');
      expect(decoded.signatureExpirationLedger, 123456);
      expect(decoded.unsignedTransactionXdr, isNull);
      expect(decoded.transaction, isNull);
    });
  });

  group('CreateHireResult', () {
    test('round-trips a hire with a prepared create_job', () {
      final decoded = _roundTrip(
        CreateHireResult(hire: _hire(status: null), preparedCreateJob: _prepared()),
      );
      expect(decoded.hire.id, 7);
      expect(decoded.hire.status, isNull);
      expect(decoded.preparedCreateJob?.purpose, 'createJob');
    });

    test('allows a result without a preparation', () {
      final decoded = _roundTrip(CreateHireResult(hire: _hire()));
      expect(decoded.hire.status, 'open');
      expect(decoded.preparedCreateJob, isNull);
    });
  });

  group('HireDetail', () {
    AgentSummary agent() => AgentSummary(
          id: 'agt-001',
          registryId: 3,
          name: 'Ledger Scout',
          description: 'Reads the ledger.',
          skills: ['ledger'],
          priceUsdcStroops: 10000000,
        );

    test('round-trips a minimal detail', () {
      final decoded = _roundTrip(
        HireDetail(hire: _hire(), agent: agent(), input: 'hello'),
      );
      expect(decoded.hire.id, 7);
      expect(decoded.agent.registryId, 3);
      expect(decoded.input, 'hello');
      expect(decoded.result, isNull);
      expect(decoded.payment, isNull);
      expect(decoded.jobId, isNull);
      expect(decoded.escrowSubmission, isNull);
      expect(decoded.feedbackSubmission, isNull);
    });

    test('round-trips payment, job and the escrow submission', () {
      final decoded = _roundTrip(HireDetail(
        hire: _hire(status: 'funded'),
        agent: agent(),
        input: 'hello',
        result: 'done',
        payment: Payment(
          transaction: 'cd' * 32,
          hireId: 7,
          payer: 'GCONSUMER',
          payee: 'GAGENT',
          amount: 10000000,
        ),
        jobId: 42,
        expiresAt: DateTime.utc(2026, 10, 8),
        approvalDeadline: DateTime.utc(2026, 10, 9),
        rejectReason: 'late',
        escrowSubmission: ChainSubmission(
          purpose: 'fund',
          transaction: 'cd' * 32,
          state: 'submitted',
          updatedAt: DateTime.utc(2026, 10, 7),
        ),
        paymentExplorerUrl: 'https://stellar.expert/tx/x',
      ));
      expect(decoded.payment?.payee, 'GAGENT');
      expect(decoded.jobId, 42);
      expect(decoded.expiresAt, DateTime.utc(2026, 10, 8));
      expect(decoded.approvalDeadline, DateTime.utc(2026, 10, 9));
      expect(decoded.rejectReason, 'late');
      expect(decoded.escrowSubmission?.state, 'submitted');
      expect(decoded.paymentExplorerUrl, 'https://stellar.expert/tx/x');
    });
  });
}
