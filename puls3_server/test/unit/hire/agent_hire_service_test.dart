import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/agent_hire_service.dart';
import 'package:test/test.dart';

const _hiring = 'GCJOMHOLKJJUMFCBC56ZIZTINBAFARFQIWNM4MA4GJ6RJZQI4KH3RIB3';
const _other = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';
const _provider = 'GDJUWQHLXXSKF6AFLMWFZT37WRRIL4VRGW5P7SB3QPW2F4MWPNYCPHEU';

AgentSummary _agent({int price = 500000}) => AgentSummary(
  id: 'a2a-b',
  registryId: 42,
  name: 'Agent B',
  description: 'Summarises text for other agents.',
  skills: const ['summarize'],
  priceUsdcStroops: price,
  wallet: _provider,
);

PreparedTransaction _prepared(String purpose, {String signer = _hiring}) =>
    PreparedTransaction(
      preparationId: 'prep-$purpose',
      purpose: purpose,
      signer: signer,
      networkPassphrase: 'Test SDF Network ; September 2015',
      unsignedTransactionXdr: 'unsigned-$purpose',
      transaction: 'hash-$purpose',
      expiresAt: DateTime.utc(2030),
    );

/// Records every call, in order, and answers like the escrow relay.
final class _FakeEscrow implements AgentHireEscrow {
  _FakeEscrow({this.hirePrice = 500000, this.signer = _hiring});

  final int hirePrice;
  final String signer;
  final calls = <String>[];
  final signed = <String, String>{};

  @override
  Future<CreateHireResult> createHire({
    required int agentId,
    required String consumer,
    required String input,
    required String requestId,
  }) async {
    calls.add('createHire $agentId $consumer');
    return CreateHireResult(
      hire: Hire(
        id: 9,
        agentId: agentId,
        consumer: consumer,
        price: hirePrice,
        manifestVersion: 1,
      ),
      preparedCreateJob: _prepared('create_job', signer: signer),
    );
  }

  @override
  Future<PreparedTransaction> prepareFund(
    StellarAddress wallet,
    int hireId,
  ) async {
    calls.add('prepareFund $hireId');
    return _prepared('fund');
  }

  @override
  Future<PreparedTransaction> prepareComplete(
    StellarAddress wallet,
    int hireId,
  ) async {
    calls.add('prepareComplete $hireId');
    return _prepared('complete');
  }

  @override
  Future<void> submitEscrowCall(
    StellarAddress wallet,
    int hireId,
    String preparationId,
    String signedTransactionXdr,
  ) async {
    calls.add('submit $preparationId');
    signed[preparationId] = signedTransactionXdr;
  }
}

final class _FakeChain implements AgentHireChain {
  _FakeChain(this.log);

  final List<String> log;

  @override
  Future<String> confirmed(String preparationId) async {
    log.add('confirmed $preparationId');
    return 'hash-${preparationId.substring('prep-'.length)}';
  }

  @override
  Future<String> delivered(int hireId) async {
    log.add('delivered $hireId');
    return 'hash-submit';
  }
}

void main() {
  group('AgentHireService.hire', () {
    late _FakeEscrow escrow;
    late List<String> signers;

    AgentHireService serviceWith(
      _FakeEscrow on, {
      AgentSummary? agent,
    }) {
      signers = [];
      return AgentHireService(
        escrow: on,
        chain: _FakeChain(on.calls),
        agentOf: (id) async => id == 42 ? (agent ?? _agent()) : null,
        sign: (xdr, signer) async {
          signers.add(signer.value);
          return 'signed($xdr)';
        },
      );
    }

    Future<AgentHireReceipt> hire(AgentHireService service, {int? budget}) =>
        service.hire(
          hiringWallet: StellarAddress.parse(_hiring),
          agentId: 42,
          input: 'Summarise this.',
          budgetUsdcStroops: budget ?? 1000000,
          requestId: 'a2a-1',
        );

    test('signs create_job, fund and complete with the hiring wallet and '
        'returns every transaction hash', () async {
      escrow = _FakeEscrow();
      final receipt = await hire(serviceWith(escrow));

      expect(escrow.calls, [
        'createHire 42 $_hiring',
        'submit prep-create_job',
        'confirmed prep-create_job',
        'prepareFund 9',
        'submit prep-fund',
        'confirmed prep-fund',
        'delivered 9',
        'prepareComplete 9',
        'submit prep-complete',
        'confirmed prep-complete',
      ]);
      expect(signers, [_hiring, _hiring, _hiring]);
      expect(escrow.signed['prep-fund'], 'signed(unsigned-fund)');
      expect(receipt.hireId, 9);
      expect(receipt.priceUsdcStroops, 500000);
      expect(receipt.createJobTransaction, 'hash-create_job');
      expect(receipt.fundTransaction, 'hash-fund');
      expect(receipt.submitTransaction, 'hash-submit');
      expect(receipt.completeTransaction, 'hash-complete');
    });

    test('refuses an agent priced above the budget before anything is '
        'created', () async {
      escrow = _FakeEscrow();
      final service = serviceWith(escrow, agent: _agent(price: 2000000));

      await expectLater(
        hire(service, budget: 1000000),
        throwsA(
          isA<AgentHireOverBudget>()
              .having((e) => e.priceUsdcStroops, 'price', 2000000)
              .having((e) => e.budgetUsdcStroops, 'budget', 1000000),
        ),
      );
      expect(escrow.calls, isEmpty);
      expect(signers, isEmpty);
    });

    test('refuses a created hire whose price exceeds the budget, signing '
        'nothing', () async {
      escrow = _FakeEscrow(hirePrice: 3000000);

      await expectLater(
        hire(serviceWith(escrow)),
        throwsA(isA<AgentHireOverBudget>()),
      );
      expect(signers, isEmpty);
    });

    test('refuses an envelope prepared for another signer', () async {
      escrow = _FakeEscrow(signer: _other);

      await expectLater(
        hire(serviceWith(escrow)),
        throwsA(isA<AgentHireRefused>()),
      );
      expect(signers, isEmpty);
    });

    test('refuses an agent the catalog does not have', () async {
      escrow = _FakeEscrow();
      final service = serviceWith(escrow);

      await expectLater(
        service.hire(
          hiringWallet: StellarAddress.parse(_hiring),
          agentId: 7,
          input: 'x',
          budgetUsdcStroops: 1000000,
          requestId: 'a2a-2',
        ),
        throwsA(isA<AgentHireRefused>()),
      );
      expect(escrow.calls, isEmpty);
    });

    test('refuses a non-positive budget', () async {
      escrow = _FakeEscrow();

      await expectLater(
        hire(serviceWith(escrow), budget: 0),
        throwsA(isA<AgentHireOverBudget>()),
      );
      expect(escrow.calls, isEmpty);
    });
  });
}
