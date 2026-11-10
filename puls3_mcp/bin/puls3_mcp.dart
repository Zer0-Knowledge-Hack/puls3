import 'dart:io';

import 'package:dart_mcp/stdio.dart';
import 'package:puls3_mcp/puls3_mcp.dart';
import 'package:puls3_sdk/puls3_sdk.dart';

/// Starts the puls3 MCP server on stdin and stdout.
///
/// The server URL comes from `PULS3_API_URL`. stdout carries the protocol
/// only, so every message for a person goes to stderr.
Future<void> main() async {
  final apiText = (Platform.environment['PULS3_API_URL'] ?? '').trim();
  if (apiText.isEmpty) {
    stderr.writeln('error: Usage: set PULS3_API_URL to the puls3 server URL.');
    exitCode = 64;
    return;
  }
  final Puls3Sdk sdk;
  try {
    sdk = Puls3Sdk.connect(Uri.parse(apiText));
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
  );
  await server.done;
  sdk.close();
}
