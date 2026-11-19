import 'package:http/http.dart' as http;

import '../runtime/adapters/anthropic_runtime.dart';
import '../runtime/adapters/workers_ai_runtime.dart';
import '../runtime/agent_runner.dart';
import '../runtime/runtime_config.dart';
import '../runtime/runtime_task.dart';
import 'builder_credential.dart';

/// Runs [task] with [credential]. This is the builder's account, never the
/// team `workersAiApiToken`.
Future<String> runBuilderTask(
  RuntimeTask task,
  BuilderProviderCredential credential,
) => withBuilderRunner(credential, (runner) => runner.run(task));

/// Runs [body] on an [AgentRunner] over [credential]'s provider, closing its
/// HTTP client after. Both adapters are `ConversationRuntime`s, so the tool
/// loop (ADR-0011 D8) can hold a conversation on it too.
Future<T> withBuilderRunner<T>(
  BuilderProviderCredential credential,
  Future<T> Function(AgentRunner runner) body,
) async {
  final client = http.Client();
  try {
    final ModelRuntime runtime = switch (credential.provider) {
      WorkersAiRuntime.provider => WorkersAiRuntime(
        httpClient: client,
        accountId: credential.accountId ?? '',
        apiToken: credential.secret,
      ),
      AnthropicRuntime.provider => AnthropicRuntime(
        httpClient: client,
        apiKey: credential.secret,
      ),
      _ => throw RuntimeUnsupportedProvider(credential.provider),
    };
    return await body(
      AgentRunner(runtime: runtime, timeout: RuntimeConfig.defaultTimeout),
    );
  } finally {
    client.close();
  }
}
