import 'dart:math';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';

import '../generated/protocol.dart';
import '../hire/chain_accounts.dart';
import '../ledger/envelope_codec.dart';
import '../ledger/stellar_sep10_codec.dart';
import 'challenge_store.dart';
import 'sep10_verifier.dart';
import 'wallet_auth_config.dart';
import 'wallet_idp.dart';

/// Issues and verifies SEP-10 challenges.
///
/// Create parses the address, reads config, then spends one rate-limit
/// attempt, and only then builds and stores the challenge. Verify runs the
/// verifier outside a transaction. The consume and the session are one
/// transaction, so a token failure puts the challenge back.
final class WalletAuthService {
  WalletAuthService({
    required this.session,
    required this.readConfig,
    required this.store,
    required this.chain,
    required this.tokens,
    required this.rateLimiter,
    required this.log,
    DateTime Function()? now,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random.secure();

  final Session session;
  final WalletAuthConfig Function() readConfig;
  final ChallengeStore store;
  final ChainAccounts chain;
  final TokenManager tokens;
  final RateLimiter rateLimiter;
  final void Function(String message, {required bool failure}) log;
  final DateTime Function() _now;
  final Random _random;

  /// A challenge for [wallet], expiring 15 minutes from now.
  Future<WalletChallenge> createChallenge(String wallet) async {
    final account = _account(wallet);
    final WalletAuthConfig config;
    try {
      config = readConfig();
    } on Puls3ApiException catch (error) {
      _report(code: error.code, failure: true, wallet: account.value);
      rethrow;
    }

    final admitted = await rateLimiter.tryRecordAttempt(
      session,
      key: account.value,
    );
    if (!admitted) {
      _report(
        code: 'ChallengeRateLimited',
        failure: true,
        wallet: account.value,
      );
      throw Puls3ApiException(
        code: 'ChallengeRateLimited',
        message: 'Too many challenges for this wallet. Try again shortly.',
      );
    }

    final now = _now().toUtc();
    final built = _codec(config).build(
      wallet: account,
      nonce: List<int>.generate(48, (_) => _random.nextInt(256)),
      now: now,
    );
    final challengeId = const Uuid().v4();
    final expiresAt = now.add(const Duration(seconds: 900));
    await store.insert(
      NewChallenge(
        challengeId: challengeId,
        wallet: account.value,
        challengeXdr: built.envelopeXdr,
        transactionHash: hexOf(built.hash),
        expiresAt: expiresAt,
      ),
    );
    _report(
      code: 'ok',
      failure: false,
      challengeId: challengeId,
      wallet: account.value,
    );
    return WalletChallenge(
      challengeId: challengeId,
      wallet: account.value,
      payload: built.envelopeXdr,
      networkPassphrase: config.networkPassphrase,
      expiresAt: expiresAt,
    );
  }

  /// Checks [signedChallengeXdr] and returns a session for [wallet].
  Future<AuthSuccess> verifyChallenge(
    String challengeId,
    String wallet,
    String signedChallengeXdr,
  ) async {
    final WalletAuthConfig config;
    try {
      config = readConfig();
    } on Puls3ApiException catch (error) {
      _report(
        code: error.code,
        failure: true,
        challengeId: challengeId,
        wallet: wallet,
      );
      rethrow;
    }

    final verifier = Sep10Verifier(
      codec: _codec(config),
      store: store,
      chain: chain,
      serverAccount: StellarAddress.parse(config.serverAccount),
      now: _now,
    );
    try {
      await verifier.verify(
        challengeId: challengeId,
        wallet: wallet,
        signedChallengeXdr: signedChallengeXdr,
      );
      final success = await session.db.transaction((transaction) async {
        final outcome = await store.consume(
          challengeId,
          transaction: transaction,
        );
        switch (outcome) {
          case ConsumeOutcome.consumed:
            return WalletIdp(tokenManager: tokens).signIn(
              session,
              wallet: wallet,
              transaction: transaction,
            );
          case ConsumeOutcome.alreadyConsumed:
            throw Puls3ApiException(
              code: 'ChallengeConsumed',
              message: 'That challenge was already used.',
            );
          case ConsumeOutcome.expired:
            throw Puls3ApiException(
              code: 'ChallengeExpired',
              message: 'That challenge has expired.',
            );
          case ConsumeOutcome.notFound:
            throw Puls3ApiException(
              code: 'ChallengeNotFound',
              message: 'That challenge does not exist.',
            );
        }
      });
      _report(
        code: 'ok',
        failure: false,
        challengeId: challengeId,
        wallet: wallet,
      );
      return success;
    } catch (error) {
      final code = error is Puls3ApiException ? error.code : 'InternalError';
      _report(
        code: code,
        failure: true,
        challengeId: challengeId,
        wallet: wallet,
      );
      rethrow;
    }
  }

  StellarSep10Codec _codec(WalletAuthConfig config) => StellarSep10Codec(
    signingKey: config.signingKey,
    homeDomain: config.homeDomain,
    webAuthDomain: config.webAuthDomain,
    networkPassphrase: config.networkPassphrase,
  );

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

  void _report({
    required String code,
    required bool failure,
    required String wallet,
    String? challengeId,
  }) {
    final id = challengeId == null ? '' : ' challengeId=$challengeId';
    log(
      'walletAuth ${failure ? 'failed' : 'ok'} code=$code$id wallet=$wallet',
      failure: failure,
    );
  }
}
