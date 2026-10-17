import 'package:puls3_domain/puls3_domain.dart';

import '../runtime/runtime_task.dart';
import 'builder_credential.dart';
import 'studio_draft_service.dart';
import 'studio_test_errors.dart';
import 'test_run_quota.dart';

/// The answer of one test run.
final class StudioTestRunResult {
  const StudioTestRunResult({
    required this.output,
    required this.remainingDailyRuns,
  });

  final String output;
  final int remainingDailyRuns;
}

/// Runs a saved draft on the builder's own provider account.
///
/// No hire and no payment. The team Workers AI token is not read here.
typedef StudioTestRunner =
    Future<String> Function(
      RuntimeTask task,
      BuilderProviderCredential credential,
    );

/// `StudioEndpoint.testRun` (api.md, F9).
final class StudioTestRunService {
  StudioTestRunService({
    required StudioDraftService drafts,
    required TestRunQuota quota,
    required BuilderCredentialStore credentials,
    required ModelPolicy policy,
    required StudioTestRunner run,
    DateTime Function()? now,
  }) : _drafts = drafts,
       _quota = quota,
       _credentials = credentials,
       _policy = policy,
       _run = run,
       _now = now ?? DateTime.now;

  final StudioDraftService _drafts;
  final TestRunQuota _quota;
  final BuilderCredentialStore _credentials;
  final ModelPolicy _policy;
  final StudioTestRunner _run;
  final DateTime Function() _now;

  /// Stores [credential] for [owner]. An empty secret is refused and the
  /// previous credential, if any, stays.
  Future<void> saveCredential({
    required StellarAddress owner,
    required BuilderProviderCredential credential,
  }) async {
    final known =
        credential.provider == ModelPolicy.freeProvider ||
        _policy.paidProviders.contains(credential.provider);
    final workersAccount =
        credential.provider != ModelPolicy.freeProvider ||
        (credential.accountId != null && credential.accountId!.isNotEmpty);
    if (!known || credential.secret.trim().isEmpty || !workersAccount) {
      throw const StudioRuntimeUnavailable();
    }
    await _credentials.save(owner: owner.value, credential: credential);
  }

  Future<StudioTestRunResult> testRun({
    required StellarAddress owner,
    required int draftId,
    required String input,
  }) async {
    final draft = await _drafts.get(owner: owner, draftId: draftId);
    final manifest = draft.manifest.validate(_policy, ManifestVersion.first);
    if (input.runes.length > manifest.inputMaxChars) {
      throw const StudioInputTooLong();
    }
    final credential = await _credentials.find(
      owner: owner.value,
      provider: manifest.model.provider,
    );
    if (credential == null ||
        credential.secret.isEmpty ||
        (manifest.model.provider == ModelPolicy.freeProvider &&
            (credential.accountId == null || credential.accountId!.isEmpty))) {
      throw const StudioRuntimeUnavailable();
    }
    final remaining = await _quota.reserve(
      owner: owner.value,
      now: _now(),
    );
    try {
      final output = await _run(
        RuntimeTask(
          provider: manifest.model.provider,
          modelId: manifest.model.id,
          systemPrompt: manifest.systemPrompt,
          input: input,
          maxInputChars: manifest.inputMaxChars,
          maxOutputChars: manifest.outputMaxChars,
        ),
        credential,
      );
      return StudioTestRunResult(
        output: output,
        remainingDailyRuns: remaining,
      );
    } on RuntimeFailure catch (failure) {
      throw StudioRunFailed(failure.code);
    }
  }
}
