import 'runtime_task.dart';

/// Sends each task to the [ModelRuntime] of its manifest's provider
/// (`workers-ai`, `anthropic`, ...). A provider with no configured runtime
/// fails the run as `unsupported_provider` without any call.
final class ProviderRouter implements ModelRuntime {
  ProviderRouter(Map<String, ModelRuntime> byProvider)
    : _byProvider = Map.unmodifiable(byProvider);

  final Map<String, ModelRuntime> _byProvider;

  /// The providers this router can run.
  Iterable<String> get providers => _byProvider.keys;

  @override
  Future<String> complete(RuntimeTask task, {Future<void>? abortTrigger}) {
    final runtime = _byProvider[task.provider];
    if (runtime == null) {
      return Future.error(RuntimeUnsupportedProvider(task.provider));
    }
    return runtime.complete(task, abortTrigger: abortTrigger);
  }
}
