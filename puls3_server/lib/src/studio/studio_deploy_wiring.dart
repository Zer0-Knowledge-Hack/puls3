import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:puls3_domain/puls3_domain.dart';
import 'package:serverpod/serverpod.dart';

import '../agent/aes_gcm_secret_cipher.dart';
import '../agent/serverpod_agent_wallet_store.dart';
import '../agent/stellar_agent_wallet_custody.dart';
import '../agent/usdc_trustline.dart';
import '../agent/wallet_custody_config.dart';
import '../chain/chain_log.dart';
import '../hire/chain_accounts.dart';
import '../hire/hire_relay_config.dart';
import '../generated/protocol.dart';
import '../ledger/soroban_rpc_client.dart';
import '../ledger/soroban_submission_ledger.dart';
import '../ledger/stellar_config.dart';
import '../ledger/stellar_envelope_codec.dart';
import 'deploy_chain.dart';
import 'serverpod_studio_agent_version_store.dart';
import 'serverpod_studio_deploy_store.dart';
import 'serverpod_studio_draft_store.dart';
import 'studio_deploy_service.dart';
import 'studio_draft_service.dart';

const _rpcTimeout = Duration(seconds: 20);

/// Public origin of the registration file. `PULS3_REGISTRATION_BASE_URL`
/// wins; otherwise the web server's public URL.
Uri _registrationBase(Session session, Map<String, String> env) {
  final override = env['PULS3_REGISTRATION_BASE_URL'];
  if (override != null && override.trim().isNotEmpty) {
    return Uri.parse(override.trim());
  }
  final web = session.serverpod.config.webServer;
  if (web == null) {
    throw HireConfigurationMissing(setting: 'PULS3_REGISTRATION_BASE_URL');
  }
  return Uri(
    scheme: web.publicScheme,
    host: web.publicHost,
    port: web.publicPort,
  );
}

/// Builds the deploy service from the process environment.
///
/// Tests never use this wiring: they pass a [StudioDeployService] through
/// the endpoint seam.
final class StudioDeployWiring {
  StudioDeployWiring._(this._build, this.networkPassphrase);

  factory StudioDeployWiring.fromEnvironment([Map<String, String>? env]) {
    final environment = env ?? Platform.environment;
    final stellar = StellarConfig.fromEnvironment(environment);
    final relay = HireRelayConfig(environment);
    final custody = WalletCustodyConfig.fromEnvironment(environment);
    final cipher = AesGcmSecretCipher(
      keys: {custody.keyVersion: custody.secretKey},
      writeKeyVersion: custody.keyVersion,
    );
    final rpc = SorobanRpcClient(
      httpClient: http.Client(),
      url: stellar.rpcUrl,
      timeout: _rpcTimeout,
    );
    final codec = StellarEnvelopeCodec.forPassphrase(
      stellar.networkPassphrase,
    );
    final validity = relay.preparationValiditySeconds;
    final fee = relay.inclusionFeeStroops;
    final friendbot = http.Client();
    return StudioDeployWiring._((session) {
      final wallets = ServerpodAgentWalletStore(session);
      final signer = CustodiedEnvelopeSigner(
        wallets: wallets,
        cipher: cipher,
        codec: codec,
      );
      return StudioDeployService(
        drafts: StudioDraftService(ServerpodStudioDraftStore(session)),
        deploys: ServerpodStudioDeployStore(session),
        versions: ServerpodStudioAgentVersionStore(session),
        wallets: StellarAgentWalletCustody(wallets: wallets, cipher: cipher),
        accounts: RpcChainAccounts(rpc),
        codec: codec,
        assembler: codec,
        sender: SorobanSubmissionLedger(rpc, escrow: stellar.escrow),
        transactions: RpcChainTxReader(
          rpc,
          identityRegistry: stellar.identityRegistry.value,
        ),
        funder: FriendbotFunder(friendbot),
        trustlines: RpcTrustlineEnsurer(
          rpc: rpc,
          signer: signer,
          asset: stellar.usdcAsset,
          networkPassphrase: stellar.networkPassphrase,
        ),
        signer: signer,
        stellar: stellar,
        registrationBase: _registrationBase(session, environment),
        preparationValiditySeconds: validity,
        inclusionFeeStroops: fee,
      );
    }, stellar.networkPassphrase);
  }

  final StudioDeployService Function(Session session) _build;
  final String networkPassphrase;

  StudioDeployService serviceOn(Session session) => _build(session);
}

/// Adds the missing USDC trustline of every custodied agent wallet, once, in
/// the background (wallets created before deploys added it themselves).
///
/// Does nothing when the custody key is unset or the Stellar configuration
/// is invalid. Logs one info line per trustline added and one warning per
/// failure; it never throws, so it cannot crash the server.
void startTrustlineBackfill(Serverpod pod, Map<String, String> env) {
  final StellarConfig stellar;
  final WalletCustodyConfig custody;
  try {
    stellar = StellarConfig.fromEnvironment(env);
    custody = WalletCustodyConfig.fromEnvironment(env);
  } on Object {
    return;
  }
  final cipher = AesGcmSecretCipher(
    keys: {custody.keyVersion: custody.secretKey},
    writeKeyVersion: custody.keyVersion,
  );
  final codec = StellarEnvelopeCodec.forPassphrase(stellar.networkPassphrase);
  unawaited(() async {
    final httpClient = http.Client();
    Session? session;
    try {
      session = await pod.createSession();
      final open = session;
      await backfillTrustlines(
        wallets: () async => [
          for (final row in await AgentWallet.db.find(open))
            StellarAddress.parse(row.address),
        ],
        ensurer: RpcTrustlineEnsurer(
          rpc: SorobanRpcClient(
            httpClient: httpClient,
            url: stellar.rpcUrl,
            timeout: _rpcTimeout,
          ),
          signer: CustodiedEnvelopeSigner(
            wallets: ServerpodAgentWalletStore(open),
            cipher: cipher,
            codec: codec,
          ),
          asset: stellar.usdcAsset,
          networkPassphrase: stellar.networkPassphrase,
        ),
        log: _trustlineLog,
      );
    } on Object catch (e) {
      _trustlineLog(
        ChainLogLevel.warning,
        'USDC trustline backfill stopped: ${e.runtimeType}',
      );
    } finally {
      await session?.close();
      httpClient.close();
    }
  }());
}

void _trustlineLog(ChainLogLevel level, String message) {
  final line = '[usdc-trustline] ${level.name}: $message';
  if (level == ChainLogLevel.info) {
    stdout.writeln(line);
  } else {
    stderr.writeln(line);
  }
}
