import 'package:puls3_domain/puls3_domain.dart';

import '../hire/chain_accounts.dart';
import '../ledger/envelope_codec.dart';
import '../ledger/ledger_errors.dart';
import '../ledger/soroban_rpc_client.dart';
import '../studio/auth_entry.dart';
import '../studio/deploy_chain.dart';
import '../studio/registration_call.dart';
import 'agent_wallet_custody.dart';
import 'stellar_agent_wallet_custody.dart';

/// Reads the identity registry for the demo-agent rebind (#209).
abstract interface class DemoAgentRegistry {
  Future<int> totalAgents();

  Future<String?> uriOf(int agentId);

  Future<StellarAddress?> walletOf(int agentId);
}

/// What happened to one seed agent.
enum DemoRebindOutcome {
  /// On-chain wallet already matches the custodied row.
  alreadyBound,

  /// On-chain wallet is some other G-address this process does not hold.
  foreignWallet,

  /// `set_agent_wallet` was sent.
  rebound,
}

final class DemoRebindResult {
  const DemoRebindResult({
    required this.agentId,
    required this.uri,
    required this.wallet,
    required this.outcome,
    this.transactionHash,
  });

  final int agentId;
  final String uri;
  final StellarAddress wallet;
  final DemoRebindOutcome outcome;
  final String? transactionHash;
}

/// Creates a custodied wallet per seed URI and rebinds `set_agent_wallet`
/// (owner auth entry + agent envelope) so demo hires can sign `submit`.
final class DemoWalletRebinder {
  DemoWalletRebinder({
    required DemoAgentRegistry registry,
    required AgentWalletCustody custody,
    required AccountFunder funder,
    required ChainAccounts accounts,
    required AddressAuthAssembler assembler,
    required AgentEnvelopeSigner signer,
    required Future<String> Function(String entryXdr) signOwnerEntry,
    required Future<SendTransactionResult> Function(
      String envelopeXdr,
      String expectedHash,
    )
    send,
    required ChainTxReader transactions,
    required StellarAddress owner,
    required StellarAddress adminWallet,
    required StellarAddress identityRegistry,
    required Set<String> seedUris,
    required int inclusionFee,
    required int validitySeconds,
    DateTime Function()? now,
  }) : _registry = registry,
       _custody = custody,
       _funder = funder,
       _accounts = accounts,
       _assembler = assembler,
       _signer = signer,
       _signOwnerEntry = signOwnerEntry,
       _send = send,
       _transactions = transactions,
       _owner = owner,
       _adminWallet = adminWallet,
       _identityRegistry = identityRegistry,
       _seedUris = seedUris,
       _inclusionFee = inclusionFee,
       _validitySeconds = validitySeconds,
       _now = now ?? DateTime.now;

  final DemoAgentRegistry _registry;
  final AgentWalletCustody _custody;
  final AccountFunder _funder;
  final ChainAccounts _accounts;
  final AddressAuthAssembler _assembler;
  final AgentEnvelopeSigner _signer;
  final Future<String> Function(String entryXdr) _signOwnerEntry;
  final Future<SendTransactionResult> Function(
    String envelopeXdr,
    String expectedHash,
  )
  _send;
  final ChainTxReader _transactions;
  final StellarAddress _owner;
  final StellarAddress _adminWallet;
  final StellarAddress _identityRegistry;
  final Set<String> _seedUris;
  final int _inclusionFee;
  final int _validitySeconds;
  final DateTime Function() _now;

  /// Idempotency key so a retry returns the same custodied account.
  static String idempotencyKey(String uri) => 'seed:$uri';

  Future<List<DemoRebindResult>> rebindAll() async {
    final total = await _registry.totalAgents();
    final results = <DemoRebindResult>[];
    for (var id = 0; id < total; id++) {
      final uri = await _registry.uriOf(id);
      if (uri == null || !_seedUris.contains(uri)) continue;
      results.add(await rebindOne(id, uri));
    }
    return results;
  }

  Future<DemoRebindResult> rebindOne(int agentId, String uri) async {
    final onChain = await _registry.walletOf(agentId);
    final wallet = await _custody.create(
      owner: _owner,
      idempotencyKey: idempotencyKey(uri),
    );
    if (onChain == wallet) {
      return DemoRebindResult(
        agentId: agentId,
        uri: uri,
        wallet: wallet,
        outcome: DemoRebindOutcome.alreadyBound,
      );
    }
    if (onChain != null && onChain != _adminWallet) {
      return DemoRebindResult(
        agentId: agentId,
        uri: uri,
        wallet: wallet,
        outcome: DemoRebindOutcome.foreignWallet,
      );
    }
    if (await _accounts.authorityOf(wallet) == null) {
      await _funder.fund(wallet);
    }
    final hash = await _submitSetAgentWallet(agentId, wallet);
    return DemoRebindResult(
      agentId: agentId,
      uri: uri,
      wallet: wallet,
      outcome: DemoRebindOutcome.rebound,
      transactionHash: hash,
    );
  }

  Future<String> _submitSetAgentWallet(
    int agentId,
    StellarAddress wallet,
  ) async {
    final sequence = await _accounts.sequenceOf(wallet);
    final validUntil =
        _now().toUtc().millisecondsSinceEpoch ~/ 1000 + _validitySeconds;
    final spec = EnvelopeSpec(
      source: wallet,
      accountSequence: sequence,
      contract: _identityRegistry,
      function: 'set_agent_wallet',
      args: setAgentWalletArgs(
        caller: _owner,
        agentId: agentId,
        newWallet: wallet,
      ),
      inclusionFee: _inclusionFee,
      validUntil: validUntil,
    );
    final simulation = await _accounts.simulate(spec);
    final index = addressAuthIndex(simulation.auth);
    if (index == null) {
      throw const LedgerUnavailable(
        'set_agent_wallet simulation had no owner auth',
      );
    }
    final preparedEntry = simulation.auth[index];
    final signedEntry = await _signOwnerEntry(preparedEntry);
    _requireSignedEntry(preparedEntry, signedEntry);
    final auth = [...simulation.auth];
    auth[index] = signedEntry;
    final prepared = _assembler.assembleAllowingAddressAuth(
      spec,
      SimulationData(
        transactionData: simulation.transactionData,
        minResourceFee: simulation.minResourceFee,
        auth: auth,
      ),
    );
    final signed = await _signer.sign(prepared, wallet);
    await _send(signed, prepared.hashHex);
    return _wait(prepared.hashHex);
  }

  void _requireSignedEntry(String prepared, String signed) {
    if (prepared == signed) {
      throw const FormatException('owner auth entry was not signed');
    }
    final preparedView = readAuthEntry(prepared);
    final signedView = readAuthEntry(signed);
    if (!signedView.covers(_owner) ||
        !sameAuthorization(preparedView, signedView)) {
      throw const FormatException(
        'owner auth entry does not match the simulation',
      );
    }
  }

  Future<String> _wait(String hash) async {
    for (var i = 0; i < 90; i++) {
      final tx = await _transactions.read(hash);
      switch (tx.status) {
        case ChainTxStatus.success:
          return hash;
        case ChainTxStatus.failed:
          throw LedgerUnavailable('set_agent_wallet $hash failed');
        case ChainTxStatus.pending:
          await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    throw LedgerUnavailable('set_agent_wallet $hash timed out');
  }
}
