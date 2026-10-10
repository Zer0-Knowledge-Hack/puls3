import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puls3_client/puls3_client.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import 'src/app.dart';
import 'src/data/agent_repository.dart';
import 'src/data/app_config.dart';
import 'src/data/server_agent_repository.dart';
import 'src/hire/hire_gateway.dart';
import 'src/hire/server_hire_gateway.dart';
import 'src/hire/wallet_session.dart';
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
  );
}

/// Starts the demo shell and verifies the generated Serverpod client connection.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // PULS3_API_URL (dart-define) overrides the bundled config.json.
  final configJson = await rootBundle.loadString('assets/config.json');
  final client = Client(resolveApiUrl(configJson))
    // Stores the wallet session (#136) and sends it on every call.
    ..authSessionManager = FlutterAuthSessionManager();

  runApp(
    Puls3App(
      // The server catalog (#17). When it is unreachable the bundled demo
      // catalog is shown, labelled as a demo, with a Retry.
      repository: ServerAgentRepository(
        () => client.agent.list(),
        byId: (id) => client.agent.get(id),
      ),
      demoRepository: AssetAgentRepository(),
      wallet: _createWallet(),
      hireGateway: _createHireGateway(client, configJson),
      healthCheck: client.health.check().then((health) => health.version),
    ),
  );
}
