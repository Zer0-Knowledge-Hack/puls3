import 'dart:io';

import 'package:puls3_cli/puls3_cli.dart';
import 'package:puls3_sdk/puls3_sdk.dart';

/// `puls3`. Hire and Studio commands use the wallet session that
/// `CliSession.open` reads from the environment: `PULS3_REFRESH_TOKEN` seeds
/// it once, and the rotated tokens stay in `PULS3_SESSION_FILE`. Without
/// either, only the catalog works.
Future<void> main(List<String> arguments) async {
  CliSession? session;
  exitCode = await runPuls3(
    arguments,
    connect: (apiUrl) async {
      session = await CliSession.open(
        apiUrl,
        environment: Platform.environment,
      );
      return Puls3Sdk.connect(apiUrl, session: session);
    },
    environment: Platform.environment,
    out: stdout,
    err: stderr,
  );
  session?.close();
}
