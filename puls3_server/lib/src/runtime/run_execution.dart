import '../studio/builder_credential.dart';
import '../studio/builder_task_runner.dart';
import 'adapters/workers_ai_runtime.dart';
import 'agent_runner.dart';
import 'run_manifest.dart';
import 'runtime_task.dart';
import 'subcontract_setup.dart';
import 'tool_loop.dart';

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
    final credential = await _ownerCredential(manifest, credentials);
    return builder(manifest.task(input), credential);
  };
}

/// Runs a body on a builder's own provider account (see [withBuilderRunner]).
typedef BuilderLease =
    Future<LoopOutcome> Function(
      BuilderProviderCredential credential,
      Future<LoopOutcome> Function(AgentRunner runner) body,
    );

/// The [RunnerLease] of the tool loop, with [runExecutor]'s routing: an
/// [OwnedRunManifest] holds its conversation on its owner's credential
/// through [builder], and fails as [RuntimeUnsupportedProvider] without one;
/// a free-provider (`workers-ai`) manifest and any other non-owned manifest
/// run on [team].
RunnerLease runnerLease({
  required AgentRunner team,
  required BuilderCredentialLookup credentials,
  BuilderLease builder = withBuilderRunner,
}) {
  return (manifest, body) async {
    if (manifest is! OwnedRunManifest ||
        manifest.provider == WorkersAiRuntime.provider) {
      return body(team);
    }
    final credential = await _ownerCredential(manifest, credentials);
    return builder(credential, body);
  };
}

Future<BuilderProviderCredential> _ownerCredential(
  OwnedRunManifest manifest,
  BuilderCredentialLookup credentials,
) async {
  final credential = await credentials(
    owner: manifest.owner,
    provider: manifest.provider,
  );
  final account = credential?.accountId;
  if (credential == null ||
      credential.secret.isEmpty ||
      (manifest.provider == WorkersAiRuntime.provider &&
          (account == null || account.isEmpty))) {
    throw RuntimeUnsupportedProvider(manifest.provider);
  }
  return credential;
}
