import 'dart:io';

import 'package:dart_mcp/stdio.dart';
import 'package:puls3_mcp/puls3_mcp.dart';
import 'package:puls3_sdk/puls3_sdk.dart';

/// Starts the puls3 MCP server on stdin and stdout.
///
/// The server URL comes from `PULS3_API_URL`. The hire and Studio tools use
/// the wallet session that `CliSession.open` reads from the environment:
/// `PULS3_REFRESH_TOKEN` seeds it once, and the rotated tokens stay in
/// `PULS3_SESSION_FILE`, the file the `puls3` CLI uses too. Without a
/// session the server still starts and the catalog tools work.
///
/// stdout carries the protocol only, so every message for a person goes to
/// stderr. No token is ever written there.
Future<void> main() async {
  final apiText = (Platform.environment['PULS3_API_URL'] ?? '').trim();
  if (apiText.isEmpty) {
    stderr.writeln('error: Usage: set PULS3_API_URL to the puls3 server URL.');
    exitCode = 64;
    return;
  }
  final Puls3Sdk sdk;
  CliSession? session;
  try {
    final apiUrl = Uri.parse(apiText);
    try {
      session = await CliSession.open(
        apiUrl,
        environment: Platform.environment,
      );
    } on FileSystemException catch (e) {
      // A session file that cannot be read must not take the catalog down.
      stderr.writeln(
        'puls3_mcp: SessionFile: ${e.message}: ${e.path ?? '-'}. '
        'Starting without a wallet session.',
      );
    }
    sdk = Puls3Sdk.connect(apiUrl, session: session);
  } on FormatException {
    stderr.writeln('error: Usage: PULS3_API_URL is not a URL: $apiText');
    exitCode = 64;
    return;
  } on ArgumentError {
    stderr.writeln(
      'error: Usage: PULS3_API_URL must be an absolute http or https URL: '
      '$apiText',
    );
    exitCode = 64;
    return;
  }
  final server = Puls3McpServer(
    stdioChannel(input: stdin, output: stdout),
    sdk: sdk,
    apiUrl: apiText,
    wallet: Platform.environment[walletVariable],
  );
  await server.done;
  sdk.close();
  session?.close();
}
