import 'package:puls3_server/src/runtime/provider_router.dart';
import 'package:puls3_server/src/runtime/runtime_task.dart';
import 'package:test/test.dart';

RuntimeTask _task(String provider) => RuntimeTask(
  provider: provider,
  modelId: 'm',
  systemPrompt: 'p',
  input: 'i',
  maxInputChars: 10,
  maxOutputChars: 10,
);

final class _Named implements ModelRuntime {
  _Named(this.name);

  final String name;
  Future<void>? lastTrigger;

  @override
  Future<String> complete(
    RuntimeTask task, {
    Future<void>? abortTrigger,
  }) async {
    lastTrigger = abortTrigger;
    return '$name:${task.provider}';
  }
}

void main() {
  final free = _Named('free');
  final byok = _Named('byok');
  final router = ProviderRouter({'workers-ai': free, 'anthropic': byok});

  test('sends each task to its provider runtime', () async {
    expect(await router.complete(_task('workers-ai')), 'free:workers-ai');
    expect(await router.complete(_task('anthropic')), 'byok:anthropic');
  });

  test('passes the abort trigger through', () async {
    final trigger = Future<void>.value();
    await router.complete(_task('workers-ai'), abortTrigger: trigger);
    expect(free.lastTrigger, same(trigger));
  });

  test('a provider without credentials is unsupported, with no call', () {
    expect(
      router.complete(_task('openai')),
      throwsA(
        isA<RuntimeUnsupportedProvider>()
            .having((e) => e.provider, 'provider', 'openai')
            .having((e) => e.code, 'code', 'unsupported_provider'),
      ),
    );
  });

  test('lists the providers it can run', () {
    expect(router.providers, unorderedEquals(['workers-ai', 'anthropic']));
  });
}
