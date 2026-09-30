import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the documented harness command: the SDK barrel pulls in
/// `package:flutter` (-> `dart:ui`), which the plain Dart VM cannot load.
void main() {
  test('`dart run bin/rpc_payment_harness.dart` compiles on the Dart VM and '
      'prints usage without arguments', () async {
    final result = await Process.run('dart', [
      'run',
      'bin/rpc_payment_harness.dart',
    ], runInShell: true);
    expect(result.stderr, isNot(contains('dart:ui')));
    expect(result.stderr, contains('Usage: dart run'));
    expect(result.exitCode, 64);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
