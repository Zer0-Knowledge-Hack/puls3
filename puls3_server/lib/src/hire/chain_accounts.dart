import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;

import '../generated/protocol.dart' show Puls3ApiException;
import '../ledger/envelope_codec.dart';
import '../ledger/ledger_errors.dart';
import '../ledger/soroban_rpc_client.dart';
import '../ledger/xdr_invoke_encoder.dart';

/// Signer thresholds of one Stellar account.
///
/// [masterWeight] is `thresholds[0]` and [mediumThreshold] is `thresholds[2]`.
/// [signers] holds the extra ed25519 signers. The master key is not in that
/// map, and a pre-auth or hash-x signer is not either.
final class AccountAuthority {
  const AccountAuthority({
    required this.masterWeight,
    required this.mediumThreshold,
    required this.signers,
  });

  final int masterWeight;
  final int mediumThreshold;
  final Map<StellarAddress, int> signers;
}

/// What the relay reads from the chain before it prepares an envelope, and
/// what wallet auth reads before it accepts a signature: the signer's sequence
/// number, the simulation of the call, and the account's signer thresholds.
///
/// [sequenceOf] and [simulate] fail as `ChainUnavailable` with
/// `details.reason = simulationFailed` (P3): a hire cannot tell a missing
/// account, an unreachable node and a rejected simulation apart.
/// [authorityOf] returns `null` when the account does not exist, and the same
/// `ChainUnavailable` when the node cannot be read.
abstract interface class ChainAccounts {
  /// The sequence number [account] has on the ledger now.
  Future<int> sequenceOf(StellarAddress account);

  /// Simulates the call in [spec] (its signer, sequence and fee) and returns
  /// the data the envelope needs.
  Future<SimulationData> simulate(EnvelopeSpec spec);

  /// Signer thresholds of [account], or `null` when it is not on the ledger.
  Future<AccountAuthority?> authorityOf(StellarAddress account);
}

/// [ChainAccounts] over Soroban RPC.
final class RpcChainAccounts implements ChainAccounts {
  RpcChainAccounts(this._rpc);

  final SorobanRpcClient _rpc;

  @override
  Future<int> sequenceOf(StellarAddress account) async {
    final int? sequence;
    try {
      sequence = await _rpc.accountSequence(account);
    } on LedgerException {
      throw chainUnavailable();
    }
    if (sequence == null) throw chainUnavailable();
    return sequence;
  }

  @override
  Future<SimulationData> simulate(EnvelopeSpec spec) async {
    final envelope = encodeInvokeEnvelope(
      source: spec.source,
      fee: spec.inclusionFee,
      sequence: spec.accountSequence + 1,
      contract: spec.contract,
      function: spec.function,
      args: spec.args,
    );
    try {
      return await _rpc.simulateTransactionBase64(envelope);
    } on LedgerException {
      throw chainUnavailable();
    }
  }

  @override
  Future<AccountAuthority?> authorityOf(StellarAddress account) async {
    final Uint8List? xdr;
    try {
      xdr = await _rpc.accountEntry(account);
    } on LedgerException {
      throw chainUnavailable();
    }
    if (xdr == null) return null;
    try {
      return _authorityOf(xdr);
    } on Object {
      // A truncated or non-account entry is unreadable. Wallet auth must not
      // fall back to the master key.
      throw chainUnavailable();
    }
  }
}

AccountAuthority _authorityOf(Uint8List xdr) {
  final decoded = stellar.LedgerEntryData.fromStruct(
    stellar.XDRVariantSerialization.deserialize(
      bytes: xdr,
      layout: stellar.LedgerEntryData.layout(),
    ),
  );
  if (decoded is! stellar.AccountEntry) {
    throw const FormatException('not an account');
  }
  final signers = <StellarAddress, int>{};
  for (final signer in decoded.signers) {
    final key = signer.key;
    if (key is! stellar.SignerKeyEd25519) continue;
    final address = StellarAddress.parse(
      stellar.StellarPublicKey.fromPublicBytes(
        key.ed25519,
      ).toAddress().address,
    );
    signers[address] = signer.weight;
  }
  return AccountAuthority(
    masterWeight: decoded.thresholds[0],
    mediumThreshold: decoded.thresholds[2],
    signers: signers,
  );
}

/// The error every unreadable chain or failed simulation maps to.
Puls3ApiException chainUnavailable() => Puls3ApiException(
  code: 'ChainUnavailable',
  message: 'The chain could not be read or the call could not be simulated.',
  details: {'reason': 'simulationFailed'},
);
