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
    return await AgentRunner(
      runtime: runtime,
      timeout: RuntimeConfig.defaultTimeout,
    ).run(task);
  } finally {
    client.close();
  }
}
