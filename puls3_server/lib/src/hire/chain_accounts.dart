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

// XDR discriminants of the account entry (CAP stellar-ledger-entries).
const _ledgerEntryTypeAccount = 0;
const _publicKeyTypeEd25519 = 0;
const _signerKeyEd25519 = 0;
const _signerKeyPreAuthTx = 1;
const _signerKeyHashX = 2;
const _signerKeyEd25519SignedPayload = 3;
const _maxHomeDomain = 32;
const _maxSigners = 20;

/// Reads the thresholds and the ed25519 signers of an `AccountEntry` ledger
/// entry (XDR).
///
/// It walks the fixed layout up to the signers on purpose and ignores the
/// extension tail: a real account carries liabilities and sponsorship
/// extensions that the general-purpose decoder of `stellar_dart` cannot read.
/// Anything that does not fit the layout throws, and the caller treats that as
/// unreadable, never as a master-key account.
AccountAuthority _authorityOf(Uint8List xdr) {
  final data = ByteData.sublistView(xdr);
  var at = 0;

  void need(int bytes) {
    if (bytes < 0 || at + bytes > xdr.length) {
      throw const FormatException('truncated account entry');
    }
  }

  int u32() {
    need(4);
    final value = data.getUint32(at);
    at += 4;
    return value;
  }

  void skip(int bytes) {
    need(bytes);
    at += bytes;
  }

  Uint8List take(int bytes) {
    need(bytes);
    final out = Uint8List.sublistView(xdr, at, at + bytes);
    at += bytes;
    return out;
  }

  // XDR pads variable data to a multiple of four bytes.
  int padded(int length) => (length + 3) & ~3;

  if (u32() != _ledgerEntryTypeAccount) {
    throw const FormatException('not an account');
  }
  if (u32() != _publicKeyTypeEd25519) {
    throw const FormatException('unknown account id type');
  }
  skip(32); // account id
  skip(8); // balance
  skip(8); // sequence number
  skip(4); // number of sub entries
  switch (u32()) {
    case 0: // no inflation destination
      break;
    case 1:
      if (u32() != _publicKeyTypeEd25519) {
        throw const FormatException('unknown inflation destination type');
      }
      skip(32);
    default:
      throw const FormatException('bad inflation destination flag');
  }
  skip(4); // flags
  final homeDomain = u32();
  if (homeDomain > _maxHomeDomain) {
    throw const FormatException('home domain too long');
  }
  skip(padded(homeDomain));
  final thresholds = take(4);
  final count = u32();
  if (count > _maxSigners) throw const FormatException('too many signers');

  final signers = <StellarAddress, int>{};
  for (var i = 0; i < count; i++) {
    final type = u32();
    Uint8List? ed25519;
    switch (type) {
      case _signerKeyEd25519:
        ed25519 = take(32);
      case _signerKeyPreAuthTx || _signerKeyHashX:
        skip(32);
      case _signerKeyEd25519SignedPayload:
        skip(32);
        skip(padded(u32()));
      default:
        throw const FormatException('unknown signer key type');
    }
    final weight = u32();
    if (ed25519 == null) continue;
    final address = StellarAddress.parse(
      stellar.StellarPublicKey.fromPublicBytes(ed25519).toAddress().address,
    );
    signers[address] = weight;
  }
  return AccountAuthority(
    masterWeight: thresholds[0],
    mediumThreshold: thresholds[2],
    signers: signers,
  );
}

/// The error every unreadable chain or failed simulation maps to.
Puls3ApiException chainUnavailable() => Puls3ApiException(
  code: 'ChainUnavailable',
  message: 'The chain could not be read or the call could not be simulated.',
  details: {'reason': 'simulationFailed'},
);
