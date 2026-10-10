import 'package:puls3_server/src/runtime/agent_runtime_wiring.dart';
import 'package:puls3_server/src/runtime/demo_manifests.dart';
import 'package:puls3_server/src/runtime/run_manifest.dart';
import 'package:test/test.dart';

RunManifest _manifest(String provider) => RunManifest(
  provider: provider,
  modelId: 'model',
  systemPrompt: 'prompt',
  inputMaxChars: 10,
  outputMaxChars: 10,
);

void main() {
  test('a complete setup for every manifest provider warns nothing', () {
    expect(
      providerSetupWarnings(
        workersAiAccountSet: true,
        workersAiTokenSet: true,
        configured: {'workers-ai'},
        manifests: demoManifests,
      ),
      isEmpty,
    );
  });

  test('Workers AI with only the account id or only the token is named, '
      'never its value', () {
    final onlyAccount = providerSetupWarnings(
      workersAiAccountSet: true,
      workersAiTokenSet: false,
      configured: {},
      manifests: const {},
    );
    expect(onlyAccount.single, contains('PULS3_WORKERS_AI_ACCOUNT_ID is set'));
    expect(onlyAccount.single, contains('"workersAiApiToken" password is not'));

    final onlyToken = providerSetupWarnings(
      workersAiAccountSet: false,
      workersAiTokenSet: true,
      configured: {},
      manifests: const {},
    );
    expect(onlyToken.single, contains('"workersAiApiToken" password is set'));
    expect(onlyToken.single, contains('PULS3_WORKERS_AI_ACCOUNT_ID is not'));
  });

  test('neither part of Workers AI set is not a partial setup', () {
    expect(
      providerSetupWarnings(
        workersAiAccountSet: false,
        workersAiTokenSet: false,
        configured: {'anthropic'},
        manifests: const {},
      ),
      isEmpty,
    );
  });

  test('each manifest provider without credentials names its agents', () {
    final warnings = providerSetupWarnings(
      workersAiAccountSet: false,
      workersAiTokenSet: false,
      configured: {'anthropic'},
      manifests: {
        'agt-b': {1: _manifest('workers-ai')},
        'agt-a': {1: _manifest('anthropic'), 2: _manifest('workers-ai')},
        'agt-c': {1: _manifest('other')},
      },
    );
    expect(warnings, [
      'Provider "other" has no credentials; runs of agt-c fail as '
          'unsupported_provider',
      'Provider "workers-ai" has no credentials; runs of agt-a, agt-b fail '
          'as unsupported_provider',
    ]);
  });

  test('the seeded demo agents need Workers AI', () {
    final warnings = providerSetupWarnings(
      workersAiAccountSet: false,
      workersAiTokenSet: false,
      configured: {'anthropic'},
      manifests: demoManifests,
    );
    expect(warnings.single, startsWith('Provider "workers-ai"'));
    expect(warnings.single, contains('agt-007'));
  });
}
