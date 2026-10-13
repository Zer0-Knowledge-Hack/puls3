import 'package:puls3_server/src/chain/chain_log.dart';
import 'package:puls3_server/src/runtime/agent_runtime_wiring.dart';
import 'package:test/test.dart';

void main() {
  late List<String> logs;
  void log(ChainLogLevel level, String message) =>
      logs.add('${level.name}: $message');

  setUp(() => logs = []);

  test('disabled by default: no settings and nothing logged', () {
    expect(runtimeSettingsOrNull({}, anthropicApiKey: null, log: log), isNull);
    expect(logs, isEmpty);
  });

  test('enabled: the loop and runtime settings', () {
    final settings = runtimeSettingsOrNull(
      {
        'PULS3_RUNTIME_ENABLED': 'true',
        'PULS3_RUNTIME_INTERVAL_SECONDS': '7',
        'PULS3_RUNTIME_TIMEOUT_SECONDS': '90',
      },
      anthropicApiKey: null,
      log: log,
    );

    expect(settings, isNotNull);
    final (loop, runtime) = settings!;
    expect(loop.interval, const Duration(seconds: 7));
    expect(runtime.timeout, const Duration(seconds: 90));
  });

  test(
    'an invalid value never stops the server: it is logged, runtime off',
    () {
      for (final env in [
        {
          'PULS3_RUNTIME_ENABLED': 'true',
          'PULS3_RUNTIME_INTERVAL_SECONDS': '0',
        },
        {'PULS3_RUNTIME_ENABLED': 'true', 'PULS3_RUNTIME_TIMEOUT_SECONDS': 'x'},
      ]) {
        logs.clear();
        expect(
          runtimeSettingsOrNull(env, anthropicApiKey: null, log: log),
          isNull,
          reason: '$env',
        );
        expect(logs.single, startsWith('error: Agent runtime not started'));
      }
    },
  );
}
