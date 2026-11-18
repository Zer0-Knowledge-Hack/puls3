import '../studio/builder_credential.dart';
import '../studio/builder_task_runner.dart';
import 'adapters/workers_ai_runtime.dart';
import 'agent_runner.dart';
import 'run_manifest.dart';
import 'runtime_task.dart';

/// Finds the credential a builder saved for one provider.
typedef BuilderCredentialLookup =
    Future<BuilderProviderCredential?> Function({
      required String owner,
      required String provider,
    });

/// Runs one task on a builder's own provider account.
typedef BuilderRun =
    Future<String> Function(
      RuntimeTask task,
      BuilderProviderCredential credential,
    );

/// How [HireRunner] executes a manifest (#220, #318):
///
/// - a free-provider (`workers-ai`) manifest runs on [team], the platform's
///   Workers AI account, whether it is a Studio deploy or a seeded agent. A
///   builder does not need a Cloudflare account for it;
/// - any other [OwnedRunManifest] (a paid provider, for example Anthropic)
///   runs on its owner's credential from [credentials], through [builder];
///   a missing or incomplete credential fails the run as
///   [RuntimeUnsupportedProvider];
/// - any other manifest (a seeded demo agent) runs on [team].
Future<String> Function(RunManifest manifest, String input) runExecutor({
  required AgentRunner team,
  required BuilderCredentialLookup credentials,
  BuilderRun builder = runBuilderTask,
}) {
  return (manifest, input) async {
    if (manifest is! OwnedRunManifest ||
        manifest.provider == WorkersAiRuntime.provider) {
      return team.run(manifest.task(input));
    }
    final credential = await credentials(
      owner: manifest.owner,
      provider: manifest.provider,
    );
    if (credential == null || credential.secret.isEmpty) {
      throw RuntimeUnsupportedProvider(manifest.provider);
    }
    return builder(manifest.task(input), credential);
  };
}
