import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puls3_client/puls3_client.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import 'src/app.dart';
import 'src/data/agent_repository.dart';
import 'src/data/app_config.dart';
import 'src/data/server_agent_repository.dart';
import 'src/deploy/deploy_gateway.dart';
import 'src/deploy/server_deploy_gateway.dart';
import 'src/hire/hire_gateway.dart';
import 'src/hire/server_hire_gateway.dart';
import 'src/hire/wallet_funds.dart';
import 'src/hire/wallet_session.dart';
import 'src/studio/server_studio_gateway.dart';
import 'src/studio/studio_gateway.dart';
import 'src/wallet/freighter/create_freighter_bridge.dart';
import 'src/wallet/freighter/freighter_wallet.dart';
import 'src/wallet/mock_wallet.dart';
import 'src/wallet/wallet_port.dart';

/// Which wallet the app signs with: `freighter` (default on the web) or
/// `mock` for the demo console (#32): `--dart-define=WALLET=mock`.
const _walletKind = String.fromEnvironment(
  'WALLET',
  defaultValue: kIsWeb ? 'freighter' : 'mock',
);

WalletPort _createWallet() => switch (_walletKind) {
  'freighter' => FreighterWallet(createFreighterBridge()),
  'mock' => MockWallet(),
  // A typo must not silently ship the mock wallet.
  _ => throw StateError(
    'Unknown WALLET "$_walletKind": use "freighter" or "mock".',
  ),
};

/// Which hire backend the app uses: `demo` (default, labelled, moves no
/// funds) or `server` for the escrow relay (#96):
/// `--dart-define=HIRE=server`. The server needs wallet sessions (#136).
const _hireKind = String.fromEnvironment('HIRE', defaultValue: 'demo');

HireGateway? _createHireGateway(Client client, String configJson) =>
    switch (_hireKind) {
      'demo' => null,
      'server' => ServerHireGateway(
        createHire: client.hire.createHire,
        prepareCreateJob: client.hire.prepareCreateJob,
        prepareFund: client.hire.prepareFund,
        submitEscrowCall: client.hire.submitEscrowCall,
        getHire: client.hire.getHire,
        session: _walletSession(client, configJson),
        readFunds: readTestnetFunds,
      ),
      // A typo must not silently ship the demo.
      _ => throw StateError(
        'Unknown HIRE "$_hireKind": use "demo" or "server".',
      ),
    };

/// The wallet-bound session (#136): SEP-10 sign-in through
/// `client.walletAuth`, stored by the client's auth session manager, which
/// then sends it on every call.
WalletSession _walletSession(Client client, String configJson) {
  final auth = readAuthConfig(configJson);
  return WalletSession(
    createChallenge: client.walletAuth.createChallenge,
    verifyChallenge: client.walletAuth.verifyChallenge,
    isAuthenticated: () => client.auth.isAuthenticated,
    storeSession: client.auth.updateSignedInUser,
    serverSigningKey: auth.serverSigningKey,
    homeDomain: auth.homeDomain,
    webAuthDomain: auth.webAuthDomain,
  );
}

/// Which Studio backend the app uses: `demo` (default, labelled, stores
/// nothing) or `server` for `StudioEndpoint` (#35):
/// `--dart-define=STUDIO=server`. Drafts need a wallet session (#136).
const _studioKind = String.fromEnvironment('STUDIO', defaultValue: 'demo');

StudioGateway? _createStudioGateway(
  Client client,
  WalletPort wallet,
  String configJson,
) => switch (_studioKind) {
  'demo' => null,
  'server' => ServerStudioGateway(
    saveDraft: client.studio.saveDraft,
    getDraft: client.studio.getDraft,
    listDrafts: client.studio.listDrafts,
    testRun: client.studio.testRun,
    saveProviderCredential: client.studio.saveProviderCredential,
    wallet: wallet,
    session: _walletSession(client, configJson),
  ),
  _ => throw StateError(
    'Unknown STUDIO "$_studioKind": use "demo" or "server".',
  ),
};

/// The same switch as Studio. `server` signs `register_full` and
/// `set_agent_wallet` for real; `demo` keeps the labelled stand-in.
DeployGateway? _createDeployGateway(
  Client client,
  WalletPort wallet,
  String configJson,
) => switch (_studioKind) {
  'demo' => null,
  'server' => ServerDeployGateway(
    prepareDeploy: client.studio.prepareDeploy,
    submitRegistration: client.studio.submitRegistration,
    getDeploySession: client.studio.getDeploySession,
    prepareWalletAuthorization: client.studio.prepareWalletAuthorization,
    submitWalletAuthorization: client.studio.submitWalletAuthorization,
    wallet: wallet,
    session: _walletSession(client, configJson),
  ),
  _ => throw StateError(
    'Unknown STUDIO "$_studioKind": use "demo" or "server".',
  ),
};

/// Starts the demo shell and verifies the generated Serverpod client connection.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // PULS3_API_URL (dart-define) overrides the bundled config.json.
  final configJson = await rootBundle.loadString('assets/config.json');
  final client = Client(resolveApiUrl(configJson))
    // Stores the wallet session (#136) and sends it on every call.
    ..authSessionManager = FlutterAuthSessionManager();

  final wallet = _createWallet();
  runApp(
    Puls3App(
      // The server catalog (#17). When it is unreachable the bundled demo
      // catalog is shown, labelled as a demo, with a Retry.
      repository: ServerAgentRepository(
        () => client.agent.list(),
        byId: (id) => client.agent.get(id),
      ),
      demoRepository: AssetAgentRepository(),
      wallet: wallet,
      hireGateway: _createHireGateway(client, configJson),
      studioGateway: _createStudioGateway(client, wallet, configJson),
      deployGateway: _createDeployGateway(client, wallet, configJson),
      healthCheck: client.health.check().then((health) => health.version),
    ),
  );
}
