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

  final Puls3Sdk sdk;
  try {
    sdk = Puls3Sdk.connect(Uri.parse(apiUrl.trim()));
  } on FormatException {
    stderr.writeln('PULS3_API_URL is not a URL: $apiUrl');
    exitCode = 64;
    return;
  } on ArgumentError {
    stderr.writeln(
      'PULS3_API_URL must be an absolute http or https URL with no query or '
      'fragment: $apiUrl',
    );
    exitCode = 64;
    return;
  }
  try {
    final agents = await sdk.listAgents();
    stdout.writeln('${agents.length} agents');
    for (final agent in agents) {
      final usdc = formatUsdc(agent.priceUsdcStroops);
      stdout.writeln(
        '${agent.id.padRight(10)} #${agent.registryId.toString().padRight(4)} '
        '$usdc USDC  ${agent.rating.toStringAsFixed(1)}★  ${agent.name}',
      );
    }
  } on AgentCatalogUnavailable catch (e) {
    stderr.writeln('catalog unavailable: ${e.message}');
    exitCode = 1;
  } on Puls3ApiException catch (e) {
    // The server answered with a Puls3ApiException code of its own. The
    // catalog calls raise none today; a future one must not crash this.
    stderr.writeln('server error ${e.code}: ${e.message ?? ''}');
    exitCode = 1;
  } on ServerpodClientException catch (e) {
    // The server was not reached, timed out or answered with an HTTP error.
    stderr.writeln('cannot reach $apiUrl: ${e.message}');
    exitCode = 1;
  } on IOException catch (e) {
    // Below the client: a TLS handshake the machine refuses (for example a
    // certificate it does not trust) or a socket error.
    stderr.writeln('cannot reach $apiUrl: $e');
    exitCode = 1;
  } finally {
    sdk.close();
  }
}
