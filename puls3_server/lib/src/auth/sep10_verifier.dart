import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';

import '../generated/protocol.dart' show Puls3ApiException;
import '../hire/chain_accounts.dart';
import '../ledger/envelope_codec.dart';
import '../ledger/sep10_codec.dart';
import '../ledger/strkey.dart';
import 'challenge_store.dart';

/// Checks a signed SEP-10 challenge against the stored row and the account's
/// signer weight.
///
/// The checks run outside any database transaction. A passing result is the
/// stored row, still unconsumed: the caller consumes it in the same
/// transaction that issues the session.
final class Sep10Verifier {
  Sep10Verifier({
    required this.codec,
    required this.store,
    required this.chain,
    required this.serverAccount,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Sep10Codec codec;
  final ChallengeStore store;
  final ChainAccounts chain;
  final StellarAddress serverAccount;
  final DateTime Function() _now;

  /// The first failing check wins. A pass does not consume the challenge.
  Future<StoredChallenge> verify({
    required String challengeId,
    required String wallet,
    required String signedChallengeXdr,
  }) async {
    final row = await store.find(challengeId);
    if (row == null) {
      throw Puls3ApiException(
        code: 'ChallengeNotFound',
        message: 'That challenge does not exist.',
      );
    }

    final account = _account(wallet);
    if (account.value != row.wallet) {
      throw _signature('walletMismatch');
    }
    if (row.consumedAt != null) {
      throw Puls3ApiException(
        code: 'ChallengeConsumed',
        message: 'That challenge was already used.',
      );
    }
    final now = _now().toUtc();
    if (!row.expiresAt.toUtc().isAfter(now)) {
      throw Puls3ApiException(
        code: 'ChallengeExpired',
        message: 'That challenge has expired.',
      );
    }

    final signed = _parse(signedChallengeXdr);
    final stored = _parse(row.challengeXdr);
    if (!_same(signed.body, stored.body)) {
      throw _signature('tampered');
    }
    final clientSignatures = _clientSignatures(signed);
    final authority = await _authority(account);
    _acceptWeight(
      account: account,
      authority: authority,
      signatures: clientSignatures,
      hash: signed.hash,
    );
    return row;
  }

  StellarAddress _account(String wallet) {
    final StellarAddress parsed;
    try {
      parsed = StellarAddress.parse(wallet);
    } on InvalidStellarAddress {
      throw Puls3ApiException(code: 'InvalidStellarAddress');
    }
    if (parsed.kind != StellarAddressKind.account) {
      throw Puls3ApiException(code: 'InvalidStellarAddress');
    }
    return parsed;
  }

  SignedEnvelope _parse(String xdr) {
    try {
      return codec.parse(xdr);
    } on InvalidSignedEnvelope {
      throw _signature('malformed');
    }
  }

  /// Signatures that are not the one valid server signature.
  ///
  /// Exactly one signature must verify with [serverAccount]. Any other
  /// signature, including a second server signature, is a client signature.
  List<EnvelopeSignature> _clientSignatures(SignedEnvelope signed) {
    final server = <EnvelopeSignature>[];
    final client = <EnvelopeSignature>[];
    for (final signature in signed.signatures) {
      if (codec.verifies(serverAccount, signature, signed.hash)) {
        server.add(signature);
      } else {
        client.add(signature);
      }
    }
    if (server.length != 1) throw _signature('serverSignature');
    return client;
  }

  Future<AccountAuthority?> _authority(StellarAddress account) async {
    try {
      return await chain.authorityOf(account);
    } on Puls3ApiException catch (error) {
      if (error.code == 'ChainUnavailable') {
        throw Puls3ApiException(
          code: 'AuthenticationUnavailable',
          message: 'The account signers could not be read.',
        );
      }
      rethrow;
    }
  }

  void _acceptWeight({
    required StellarAddress account,
    required AccountAuthority? authority,
    required List<EnvelopeSignature> signatures,
    required Uint8List hash,
  }) {
    if (authority == null) {
      _acceptUnfunded(account, signatures, hash);
      return;
    }

    final counted = <StellarAddress>{};
    var weight = 0;
    var verified = 0;
    for (final signature in signatures) {
      final signer = _signerFor(account, authority, signature, hash);
      if (signer == null) continue;
      verified++;
      if (!counted.add(signer)) continue;
      weight += signer == account
          ? authority.masterWeight
          : authority.signers[signer]!;
    }
    if (verified == 0) throw _signature('noClientSignature');
    if (verified != signatures.length) {
      throw _signature('invalidClientSignature');
    }
    final required = authority.mediumThreshold == 0
        ? 1
        : authority.mediumThreshold;
    if (weight < required) throw _signature('insufficientWeight');
  }

  /// An account that is not on the ledger is its master key alone.
  void _acceptUnfunded(
    StellarAddress account,
    List<EnvelopeSignature> signatures,
    Uint8List hash,
  ) {
    if (signatures.isEmpty) throw _signature('noClientSignature');
    if (signatures.length != 1) throw _signature('invalidClientSignature');
    final only = signatures.single;
    if (codec.verifies(account, only, hash)) return;
    if (_hintMatches(only, account)) throw _signature('noClientSignature');
    throw _signature('invalidClientSignature');
  }

  StellarAddress? _signerFor(
    StellarAddress account,
    AccountAuthority authority,
    EnvelopeSignature signature,
    Uint8List hash,
  ) {
    if (codec.verifies(account, signature, hash)) return account;
    for (final signer in authority.signers.keys) {
      if (codec.verifies(signer, signature, hash)) return signer;
    }
    return null;
  }

  bool _hintMatches(EnvelopeSignature signature, StellarAddress account) {
    final raw = rawKey(account);
    return _same(signature.hint, raw.sublist(raw.length - 4));
  }
}

Puls3ApiException _signature(String reason) => Puls3ApiException(
  code: 'InvalidWalletSignature',
  message: 'The challenge signature was rejected.',
  details: {'reason': reason},
);

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
