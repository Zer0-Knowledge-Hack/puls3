import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/data/agent_repository.dart';
import 'src/wallet/mock_wallet.dart';

/// puls3 demo shell. Mock data only: it makes no server, chain or wallet
/// calls. The generated Serverpod client stays a dependency for later wiring.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    Puls3App(
      repository: AssetAgentRepository(),
      wallet: MockWallet(),
    ),
  );
}
