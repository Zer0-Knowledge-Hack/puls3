import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puls3_client/puls3_client.dart';

import 'src/app.dart';
import 'src/data/agent_repository.dart';
import 'src/data/app_config.dart';
import 'src/data/server_agent_repository.dart';
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

/// Starts the demo shell and verifies the generated Serverpod client connection.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // PULS3_API_URL (dart-define) overrides the bundled config.json.
  final client = Client(
    resolveApiUrl(await rootBundle.loadString('assets/config.json')),
  );

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
      healthCheck: client.health.check().then((health) => health.version),
    ),
  );
}
