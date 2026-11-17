import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;

import '../agent/stellar_agent_wallet_custody.dart';
import '../generated/protocol.dart';
import '../ledger/envelope_codec.dart';
import 'escrow_relay_service.dart';
import 'hire_services.dart';

/// The escrow calls one agent makes as the hire client of another (#312):
/// the same `HireService` and `EscrowRelayService` a human consumer uses.
abstract interface class AgentHireEscrow {
  Future<CreateHireResult> createHire({
    required int agentId,
    required String consumer,
    required String input,
    required String requestId,
  });

  Future<PreparedTransaction> prepareFund(StellarAddress wallet, int hireId);

  Future<PreparedTransaction> prepareComplete(
    StellarAddress wallet,
    int hireId,
  );

  Future<void> submitEscrowCall(
    StellarAddress wallet,
    int hireId,
    String preparationId,
    String signedTransactionXdr,
  );
}

/// [AgentHireEscrow] over the request-scoped [HireServices].
final class HireServicesEscrow implements AgentHireEscrow {
  const HireServicesEscrow(this._services);

  final HireServices _services;

  @override
  Future<CreateHireResult> createHire({
    required int agentId,
    required String consumer,
    required String input,
    required String requestId,
  }) => _services.hires.createHire(
    agentId: agentId,
    consumer: consumer,
    input: input,
    requestId: requestId,
  );

  @override
  Future<PreparedTransaction> prepareFund(StellarAddress wallet, int hireId) =>
      _services.relay.prepareFund(wallet, hireId);

  @override
  Future<PreparedTransaction> prepareComplete(
    StellarAddress wallet,
    int hireId,
  ) => _services.relay.prepareComplete(wallet, hireId);

  @override
  Future<void> submitEscrowCall(
    StellarAddress wallet,
    int hireId,
    String preparationId,
    String signedTransactionXdr,
  ) => _services.relay.submitEscrowCall(
    wallet,
    hireId,
    preparationId,
    signedTransactionXdr,
  );
}

/// What the chain tracker tells the hiring agent while it waits.
abstract interface class AgentHireChain {
  /// The transaction hash of [preparationId] once its submission is
  /// confirmed. Throws [AgentHireFailed] when it failed or never confirmed.
  Future<String> confirmed(String preparationId);

  /// The hash of the provider's confirmed `submit` of [hireId], once the
  /// hire is `submitted`. The provider's custodied key signs it (#208).
  Future<String> delivered(int hireId);
}

/// Signs [unsignedXdr] with the custodied key of [signer] and returns the
/// signed envelope.
typedef UnsignedEnvelopeSigner =
    Future<String> Function(String unsignedXdr, StellarAddress signer);

/// An [UnsignedEnvelopeSigner] over the custodied keys of [signer]: the
/// seed is decrypted inside it and never returned.
UnsignedEnvelopeSigner custodiedEnvelopeSigner(
  AgentEnvelopeSigner signer,
  EnvelopeCodec codec,
) => (unsignedXdr, address) {
  final parsed = codec.parse(unsignedXdr);
  return signer.sign(
    PreparedEnvelope(
      envelopeXdr: unsignedXdr,
      body: parsed.body,
      hash: parsed.hash,
    ),
    address,
  );
};

/// Every transaction of one agent-to-agent hire.
final class AgentHireReceipt {
  const AgentHireReceipt({
    required this.hireId,
    required this.priceUsdcStroops,
    required this.createJobTransaction,
    required this.fundTransaction,
    required this.submitTransaction,
    required this.completeTransaction,
  });

  final int hireId;
  final int priceUsdcStroops;
  final String createJobTransaction;
  final String fundTransaction;
  final String submitTransaction;
  final String completeTransaction;
}

/// The hire was refused before the hiring agent signed anything more.
class AgentHireRefused implements Exception {
  const AgentHireRefused(this.message);

  final String message;

  @override
  String toString() => 'AgentHireRefused: $message';
}

/// The hired agent costs more than the hiring agent may spend on this run.
final class AgentHireOverBudget extends AgentHireRefused {
  const AgentHireOverBudget({
    required this.priceUsdcStroops,
    required this.budgetUsdcStroops,
  }) : super('price exceeds the per-run budget');

  final int priceUsdcStroops;
  final int budgetUsdcStroops;

  @override
  String toString() =>
      'AgentHireOverBudget: price $priceUsdcStroops > budget '
      '$budgetUsdcStroops USDC stroops';
}

/// A step reached the chain and did not succeed.
final class AgentHireFailed implements Exception {
  const AgentHireFailed(this.message);

  final String message;

  @override
  String toString() => 'AgentHireFailed: $message';
}

/// One agent hires and pays another through the escrow, with no human
/// signature (#312, SOW week 2).
///
/// The hiring agent's custodied wallet is the hire's client and evaluator:
/// it signs `create_job`, `fund` and `complete`. The hired agent signs its
/// own `submit` through the runtime path (#208). The spend is bounded by a
/// per-run budget, checked against the catalog price before anything is
/// created and against the stored hire price before anything is signed.
final class AgentHireService {
  AgentHireService({
    required AgentHireEscrow escrow,
    required AgentHireChain chain,
    required AgentSummaryLookup agentOf,
    required UnsignedEnvelopeSigner sign,
  }) : _escrow = escrow,
       _chain = chain,
       _agentOf = agentOf,
       _sign = sign;

  final AgentHireEscrow _escrow;
  final AgentHireChain _chain;
  final AgentSummaryLookup _agentOf;
  final UnsignedEnvelopeSigner _sign;

  /// Hires [agentId] on [input] for [hiringWallet], spending at most
  /// [budgetUsdcStroops], and returns every transaction hash.
  Future<AgentHireReceipt> hire({
    required StellarAddress hiringWallet,
    required int agentId,
    required String input,
    required int budgetUsdcStroops,
    required String requestId,
  }) async {
    final agent = await _agentOf(agentId);
    if (agent == null) {
      throw AgentHireRefused('agent $agentId is not in the catalog');
    }
    _withinBudget(agent.priceUsdcStroops, budgetUsdcStroops);

    final created = await _escrow.createHire(
      agentId: agentId,
      consumer: hiringWallet.value,
      input: input,
      requestId: requestId,
    );
    final hireId = created.hire.id;
    _withinBudget(created.hire.price, budgetUsdcStroops);
    final createJob = created.preparedCreateJob;
    if (createJob == null) {
      throw AgentHireRefused('hire $hireId has no create_job to sign');
    }

    final createJobHash = await _signAndSend(hiringWallet, hireId, createJob);
    final fundHash = await _signAndSend(
      hiringWallet,
      hireId,
      await _escrow.prepareFund(hiringWallet, hireId),
    );
    final submitHash = await _chain.delivered(hireId);
    final completeHash = await _signAndSend(
      hiringWallet,
      hireId,
      await _escrow.prepareComplete(hiringWallet, hireId),
    );
    return AgentHireReceipt(
      hireId: hireId,
      priceUsdcStroops: created.hire.price,
      createJobTransaction: createJobHash,
      fundTransaction: fundHash,
      submitTransaction: submitHash,
      completeTransaction: completeHash,
    );
  }

  static void _withinBudget(int price, int budget) {
    if (budget <= 0 || price > budget) {
      throw AgentHireOverBudget(
        priceUsdcStroops: price,
        budgetUsdcStroops: budget,
      );
    }
  }

  Future<String> _signAndSend(
    StellarAddress wallet,
    int hireId,
    PreparedTransaction prepared,
  ) async {
    final unsigned = prepared.unsignedTransactionXdr;
    if (prepared.signer != wallet.value || unsigned == null) {
      throw AgentHireRefused(
        '${prepared.purpose} of hire $hireId is not for the hiring wallet',
      );
    }
    final signed = await _sign(unsigned, wallet);
    await _escrow.submitEscrowCall(
      wallet,
      hireId,
      prepared.preparationId,
      signed,
    );
    return _chain.confirmed(prepared.preparationId);
  }
}
