import 'dart:convert';

import 'package:integration_test/integration_test_driver.dart';

/// Prints what the test reports on failure: the driver's own failure details
/// carry no message on the web, so the test puts it in `reportData`.
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    // ignore: avoid_print
    if (data != null) print('E2E report: ${jsonEncode(data)}');
  },
  writeResponseOnFailure: true,
);
