import 'dart:io';

import 'package:puls3_cli/puls3_cli.dart';
import 'package:puls3_sdk/puls3_sdk.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runPuls3(
    arguments,
    connect: Puls3Sdk.connect,
    environment: Platform.environment,
    out: stdout,
    err: stderr,
  );
}
