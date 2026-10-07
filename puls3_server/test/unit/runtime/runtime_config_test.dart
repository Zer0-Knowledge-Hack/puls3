import 'package:puls3_server/src/runtime/runtime_config.dart';
import 'package:test/test.dart';

void main() {
  test('reads the key and the timeout', () {
    final config = RuntimeConfig.fromEnvironment({
      'PULS3_ANTHROPIC_API_KEY': 'secret-key',
      'PULS3_RUNTIME_TIMEOUT_SECONDS': '90',
    });

    expect(config.anthropicApiKey, 'secret-key');
    expect(config.timeout, const Duration(seconds: 90));
    expect(config.isEnabled, isTrue);
  });

  test('without a key the runtime is disabled', () {
    for (final env in [
      <String, String>{},
      {'PULS3_ANTHROPIC_API_KEY': ''},
    ]) {
      final config = RuntimeConfig.fromEnvironment(env);
      expect(config.isEnabled, isFalse);
      expect(config.anthropicApiKey, isNull);
    }
  });

  test('an unset or empty timeout uses the default', () {
    for (final env in [
      <String, String>{},
      {'PULS3_RUNTIME_TIMEOUT_SECONDS': ''},
    ]) {
      expect(
        RuntimeConfig.fromEnvironment(env).timeout,
        RuntimeConfig.defaultTimeout,
      );
    }
  });

  test('an invalid timeout fails fast', () {
    for (final value in ['0', '-5', 'abc', '1.5']) {
      expect(
        () => RuntimeConfig.fromEnvironment({
          'PULS3_RUNTIME_TIMEOUT_SECONDS': value,
        }),
        throwsFormatException,
        reason: value,
      );
    }
  });

  test('toString never shows the key', () {
    final config = RuntimeConfig.fromEnvironment({
      'PULS3_ANTHROPIC_API_KEY': 'secret-key',
    });

    expect(config.toString(), isNot(contains('secret-key')));
    expect(config.toString(), contains('enabled'));
  });
}
