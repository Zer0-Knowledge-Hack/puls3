import 'conversation.dart';

/// Sends each task to the [ModelRuntime] of its manifest's provider
/// (`workers-ai`, `anthropic`, ...). A provider with no configured runtime
/// fails the run as `unsupported_provider` without any call.
final class ProviderRouter implements ConversationRuntime {
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

  /// Like [complete]; a provider whose runtime is not a
  /// [ConversationRuntime] fails as `tools_unsupported`.
  @override
  Future<ModelTurn> converse(
    ConversationTask task, {
    Future<void>? abortTrigger,
  }) {
    final runtime = _byProvider[task.provider];
    if (runtime == null) {
      return Future.error(RuntimeUnsupportedProvider(task.provider));
    }
    if (runtime is! ConversationRuntime) {
      return Future.error(const RuntimeToolsUnsupported());
    }
    return runtime.converse(task, abortTrigger: abortTrigger);
  }
}
