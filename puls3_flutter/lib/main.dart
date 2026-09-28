import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puls3_client/puls3_client.dart';

import 'src/app.dart';
import 'src/data/agent_repository.dart';
import 'src/wallet/mock_wallet.dart';

/// Starts the demo shell and verifies the generated Serverpod client connection.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config =
      jsonDecode(
            await rootBundle.loadString('assets/config.json'),
          )
          as Map<String, dynamic>;
  final client = Client(config['apiUrl']! as String);

  runApp(
    Puls3App(
      repository: AssetAgentRepository(),
      wallet: MockWallet(),
      healthCheck: client.health.check().then((health) => health.version),
    ),
  );
}
