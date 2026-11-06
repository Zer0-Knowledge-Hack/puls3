// Lists the puls3 catalog from the server in PULS3_API_URL.
//
//   PULS3_API_URL=https://puls3-hub-on-stellar.api.serverpod.space/ \
//     dart run example/list_catalog.dart
import 'dart:io';

import 'package:puls3_sdk/puls3_sdk.dart';

Future<void> main() async {
  final apiUrl = Platform.environment['PULS3_API_URL'];
  if (apiUrl == null || apiUrl.trim().isEmpty) {
    stderr.writeln('Set PULS3_API_URL to the puls3 server URL.');
    exitCode = 64;
    return;
  }

  final sdk = Puls3Sdk.connect(Uri.parse(apiUrl.trim()));
  try {
    final agents = await sdk.listAgents();
    stdout.writeln('${agents.length} agents');
    for (final agent in agents) {
      final usdc = (agent.priceUsdcStroops / 10000000).toStringAsFixed(2);
      stdout.writeln(
        '${agent.id.padRight(10)} #${agent.registryId.toString().padRight(4)} '
        '$usdc USDC  ${agent.rating.toStringAsFixed(1)}★  ${agent.name}',
      );
    }
  } on AgentCatalogUnavailable catch (e) {
    stderr.writeln('catalog unavailable: ${e.message}');
    exitCode = 1;
  } on ServerpodClientException catch (e) {
    // The server was not reached, timed out or answered with an HTTP error.
    stderr.writeln('cannot reach $apiUrl: ${e.message}');
    exitCode = 1;
  } finally {
    sdk.close();
  }
}
