import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puls3_client/puls3_client.dart';

import 'src/app.dart';
import 'src/data/agent_repository.dart';
import 'src/data/app_config.dart';
import 'src/data/fallback_agent_repository.dart';
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

WalletPort _createWallet() => _walletKind == 'freighter'
    ? FreighterWallet(createFreighterBridge())
    : MockWallet();

/// Starts the demo shell and verifies the generated Serverpod client connection.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // PULS3_API_URL (dart-define) overrides the bundled config.json.
  final client = Client(
    resolveApiUrl(await rootBundle.loadString('assets/config.json')),
  );

  runApp(
    Puls3App(
      // Server catalog first; the bundled demo catalog covers an unreachable
      // or slow server.
      repository: FallbackAgentRepository(
        ServerAgentRepository(() => client.agent.list()),
        AssetAgentRepository(),
      ),
      wallet: _createWallet(),
      healthCheck: client.health.check().then((health) => health.version),
    ),
  );
}
