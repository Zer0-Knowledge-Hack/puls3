import 'dart:async';
import 'dart:io';

import 'package:puls3_domain/puls3_domain.dart' show StellarAddress;
import 'package:serverpod/serverpod.dart';

import '../agent/aes_gcm_secret_cipher.dart';
import '../agent/secret_cipher.dart';
import '../agent/serverpod_agent_index_repository.dart';
import '../agent/serverpod_agent_wallet_store.dart';
import '../agent/stellar_agent_wallet_custody.dart';
import '../agent/wallet_custody_config.dart';
import '../chain/serverpod_chain_submission_store.dart';
import '../ledger/stellar_envelope_codec.dart';
import 'agent_hire_service.dart';
import 'hire_agent_lookup.dart';
import 'hire_services.dart';
import 'serverpod_hire_repository.dart';
import 'tracker_agent_hire_chain.dart';

/// Starts one agent-to-agent hire and returns its hire id once it exists;
/// the rest of the hire continues in the background.
typedef AgentHireLauncher =
    Future<int> Function({
      required Session session,
      required StellarAddress hiringWallet,
      required int agentId,
      required String input,
      required int budgetUsdcStroops,
      required String requestId,
    });

/// Prefix of every server log line of a builder-orchestrated hire.
const agentHireLogPrefix = '[agent-hire]';

/// Builds [AgentHireService] from the production pieces (#312): the hire
/// services of `HireEndpoint`, the chain tracker's submission rows and the
/// custodied signer of `PULS3_AGENT_WALLET_SECRET_KEY`.
///
/// Throws `AgentWalletCustodyUnavailable` or `ArgumentError` when the
/// custody key is missing or invalid, and `HireConfigurationMissing` when a
/// Stellar setting is.
final class AgentHireWiring {
  AgentHireWiring._(this._hires, this._cipher, this._codec);

  factory AgentHireWiring.fromEnvironment([Map<String, String>? env]) {
    final environment = env ?? Platform.environment;
    final custody = WalletCustodyConfig.fromEnvironment(environment);
    final hires = HireWiring.fromEnvironment(environment: environment);
    return AgentHireWiring._(
      hires,
      AesGcmSecretCipher(
        keys: {custody.keyVersion: custody.secretKey},
        writeKeyVersion: custody.keyVersion,
      ),
      StellarEnvelopeCodec.forPassphrase(hires.stellar.networkPassphrase),
    );
  }

  final HireWiring _hires;
  final SecretCipher _cipher;
  final StellarEnvelopeCodec _codec;

  /// The service with its stores on [session].
  AgentHireService serviceOn(
    Session session, {
    void Function(String message)? log,
  }) {
    final wallets = ServerpodAgentWalletStore(session);
    return AgentHireService(
      escrow: HireServicesEscrow(_hires.servicesOn(session)),
      chain: TrackerAgentHireChain(
        hires: ServerpodHireRepository(session),
        submissions: ServerpodChainSubmissionStore(session),
      ),
      agentOf: hireAgentLookup(
        index: ServerpodAgentIndexRepository(
          session,
          network: _hires.stellar.networkPassphrase,
        ),
        fallback: _hires.catalog,
      ),
      sign: custodiedEnvelopeSigner(
        CustodiedEnvelopeSigner(
          wallets: wallets,
          cipher: _cipher,
          codec: _codec,
        ),
        _codec,
      ),
      log: log,
    );
  }

  /// An [AgentHireLauncher] that runs each hire on its own Serverpod session,
  /// so it outlives the request that started it.
  AgentHireLauncher get launcher => backgroundAgentHire(
    (session, log) => serviceOn(session, log: log),
  );
}

/// An [AgentHireLauncher] that runs the hire of [serviceOn] in an unawaited
/// future on a new session of the request's Serverpod. Every step, tx hash,
/// the receipt or the failure is logged with [agentHireLogPrefix]; nothing
/// escapes the background future.
AgentHireLauncher backgroundAgentHire(
  AgentHireService Function(Session session, void Function(String) log)
  serviceOn, {
  Future<Session> Function(Session request)? sessionFor,
  void Function(String line)? write,
}) {
  final out = write ?? stdout.writeln;
  return ({
    required Session session,
    required StellarAddress hiringWallet,
    required int agentId,
    required String input,
    required int budgetUsdcStroops,
    required String requestId,
  }) {
    final created = Completer<int>();
    void log(String message) => out('$agentHireLogPrefix $message');
    unawaited(() async {
      Session? background;
      try {
        background = await (sessionFor ?? _newSession)(session);
        log(
          '${hiringWallet.value} hires agent $agentId '
          '(budget $budgetUsdcStroops USDC stroops, request $requestId)',
        );
        final receipt = await serviceOn(background, log).hire(
          hiringWallet: hiringWallet,
          agentId: agentId,
          input: input,
          budgetUsdcStroops: budgetUsdcStroops,
          requestId: requestId,
          onCreated: (hireId) {
            if (!created.isCompleted) created.complete(hireId);
          },
        );
        log(
          'hire ${receipt.hireId} done: price ${receipt.priceUsdcStroops}, '
          'create_job ${receipt.createJobTransaction}, '
          'fund ${receipt.fundTransaction}, '
          'submit ${receipt.submitTransaction}, '
          'complete ${receipt.completeTransaction}',
        );
      } on Object catch (error, stack) {
        log('${hiringWallet.value} hiring agent $agentId failed: $error');
        if (!created.isCompleted) created.completeError(error, stack);
      } finally {
        try {
          await background?.close();
        } on Object catch (error) {
          log('closing the hire session failed: $error');
        }
      }
    }());
    return created.future;
  };
}

Future<Session> _newSession(Session request) =>
    request.serverpod.createSession();
