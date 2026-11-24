import 'package:http/http.dart' as http;

import '../runtime/adapters/workers_ai_runtime.dart';
import '../runtime/agent_runner.dart';
import '../runtime/agent_runtime_wiring.dart'
    show workersAiAccountId, workersAiAccountVariable;
import '../runtime/runtime_config.dart';
import 'studio_test_run_service.dart' show StudioTeamTestRunner;

/// The platform runner for free-model Studio test runs (#318), or `null` when
/// the team Workers AI account or token is missing.
///
/// Paid providers keep the builder's credential; only `workers-ai` uses this
/// runner, for both test runs and paid hires.
StudioTeamTestRunner? teamTestRunnerFromEnvironment(
  Map<String, String> env, {
  required String? workersAiToken,
  http.Client? httpClient,
}) {
  final accountId = workersAiAccountId(env[workersAiAccountVariable]);
  final token = workersAiToken?.trim();
  if (accountId == null || token == null || token.isEmpty) return null;
  const timeout = RuntimeConfig.defaultTimeout;
  return (task) async {
    final client = httpClient ?? http.Client();
    try {
      return await AgentRunner(
        runtime: WorkersAiRuntime(
          httpClient: client,
          accountId: accountId,
          apiToken: token,
        ),
        timeout: timeout,
      ).run(task);
    } finally {
      if (httpClient == null) client.close();
    }
  };
}
