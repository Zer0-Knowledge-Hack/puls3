import 'package:puls3_domain/puls3_domain.dart';

import '../chain/chain_log.dart';
import '../ledger/ledger_errors.dart';
import 'agent_runner.dart';
import 'hire_run_store.dart';
import 'run_manifest.dart';
import 'runtime_task.dart';

/// Failure code for a run whose manifest version is not known.
const manifestUnavailable = 'manifest_unavailable';

/// Failure code for a run that was still `running` when it should long have
/// ended, for example because the server restarted mid-run.
const runInterrupted = 'interrupted';

/// Failure code for a queued run whose hire can no longer run (not funded,
/// or missing), so it leaves the queue instead of blocking it.
const runNotRunnable = 'not_runnable';

/// Failure code for a run that could not end before the job's `expired_at`:
/// its result could never be submitted, so the model is not called.
const runJobExpired = 'job_expired';

/// Failure code for an unexpected error during the run, for example a TLS
/// failure that is not a `RuntimeFailure`. The detail goes to the log only.
const runInternalError = 'internal_error';

/// Waits before each retry of a run after a retryable provider failure
/// (rate limit, server error, no response, provider without credentials).
/// One entry per retry: after these, the next such failure is final.
const retryBackoff = [
  Duration(seconds: 30),
  Duration(minutes: 2),
  Duration(minutes: 8),
];

/// Whether [failure] may pass on a later attempt: the provider was rate
/// limited, failed on its side, did not answer, or has no credentials
/// configured right now. A timeout, a refusal or a limit is final.
bool isRetryable(RuntimeFailure failure) => switch (failure) {
  RuntimeProviderFailed() => failure.retryable,
  RuntimeUnsupportedProvider() => true,
  _ => false,
};

/// What one [HireRunner.pass] did.
final class RunPassSummary {
  const RunPassSummary({
    required this.succeeded,
    required this.failed,
    required this.interrupted,
    required this.deferred,
    this.retried = 0,
  });

  final int succeeded;
  final int failed;
  final int interrupted;

  /// Queued runs left for a later pass (the chain could not be read).
  final int deferred;

  /// Runs put back in the queue after a retryable provider failure.
  final int retried;

  int get total => succeeded + failed + interrupted + deferred + retried;

  @override
  String toString() =>
      'succeeded $succeeded, failed $failed, interrupted $interrupted, '
      'deferred $deferred, retried $retried';
}

/// Runs the agent of every funded hire once (#20, ADR-0004).
///
/// Each run goes through the domain: `Hire.startRun` before the model is
/// called and `Hire.failRun` on a failure, so a hire that is not funded, or
/// whose run already moved, is never run. The stored state changes only by
/// conditional writes ([HireRunStore]), so two runners never run one hire.
///
/// A successful run stores the result; the hire stays `funded` until the
/// server-signed escrow `submit` (#97) makes it `submitted`.
final class HireRunner {
  /// [staleAfter] must exceed the runtime timeout: a run still `running`
  /// after it is failed as [runInterrupted].
  HireRunner({
    required RunManifestSource manifests,
    required AgentRunner runner,
    required Duration staleAfter,
    DateTime Function() now = DateTime.now,
    ChainLog log = ignoreChainLog,
    int batchSize = 10,
  }) : _manifests = manifests,
       _runner = runner,
       _staleAfter = staleAfter,
       _now = now,
       _log = log,
       _batchSize = batchSize;

  final RunManifestSource _manifests;
  final AgentRunner _runner;
  final Duration _staleAfter;
  final DateTime Function() _now;
  final ChainLog _log;
  final int _batchSize;

  /// Fails interrupted runs, then runs up to one batch of queued ones, one at
  /// a time.
  Future<RunPassSummary> pass({
    required HireRunStore runs,
    required HireRepository hires,
  }) async {
    var interrupted = 0;
    for (final hireId in await runs.listRunningStartedBefore(
      _now().subtract(_staleAfter),
    )) {
      if (await runs.markFailed(hireId, runInterrupted, _now())) {
        interrupted++;
        _log(ChainLogLevel.warning, 'Run of hire $hireId was interrupted');
      }
    }

    var succeeded = 0;
    var failed = 0;
    var deferred = 0;
    var retried = 0;
    for (final queued in await runs.listQueued(
      limit: _batchSize,
      now: _now(),
    )) {
      final outcome = await _runOne(queued, runs, hires);
      switch (outcome) {
        case _Outcome.succeeded:
          succeeded++;
        case _Outcome.failed:
          failed++;
        case _Outcome.deferred:
          deferred++;
        case _Outcome.retried || _Outcome.rateLimited:
          retried++;
        case _Outcome.skipped:
          break;
      }
      // The provider is rate limited: the rest of the batch would only hit
      // the same limit, so it waits for a later pass.
      if (outcome == _Outcome.rateLimited) break;
    }
    return RunPassSummary(
      succeeded: succeeded,
      failed: failed,
      interrupted: interrupted,
      deferred: deferred,
      retried: retried,
    );
  }

  Future<_Outcome> _runOne(
    QueuedRun queued,
    HireRunStore runs,
    HireRepository hires,
  ) async {
    final hire = await hires.findById(HireId(queued.hireId));
    if (hire == null ||
        hire.status != HireStatus.funded ||
        hire.runtimeStatus != RuntimeStatus.queued) {
      // Not funded, missing, or the run already moved: never call the model,
      // and take the run out of the queue so it does not block later hires.
      _log(
        ChainLogLevel.error,
        'Hire ${queued.hireId} cannot run (status ${hire?.status.name}, '
        'run ${hire?.runtimeStatus?.name})',
      );
      return await runs.markFailed(queued.hireId, runNotRunnable, _now())
          ? _Outcome.failed
          : _Outcome.skipped;
    }
    final running = hire.startRun();

    final RunManifest? manifest;
    try {
      manifest = await _manifests.find(queued.agentId, queued.manifestVersion);
    } on Object catch (e) {
      // An unreadable registry, or any other lookup error: the run stays
      // queued for a later pass.
      _log(
        e is LedgerException ? ChainLogLevel.warning : ChainLogLevel.error,
        'Run of hire ${queued.hireId} deferred, its manifest is unreadable: '
        '${e.runtimeType}',
      );
      return _Outcome.deferred;
    }

    if (!await runs.markRunning(queued.hireId, _now())) {
      return _Outcome.skipped;
    }
    if (manifest == null) {
      return _fail(running, runs, manifestUnavailable);
    }
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      queued.expiredAt * 1000,
      isUtc: true,
    );
    if (!_now().add(_runner.timeout).isBefore(expiresAt)) {
      return _fail(running, runs, runJobExpired);
    }

    final String output;
    try {
      output = await _runner.run(manifest.task(queued.input));
    } on RuntimeFailure catch (failure) {
      if (isRetryable(failure) && queued.attempts < retryBackoff.length) {
        return _retry(queued, runs, failure);
      }
      return _fail(running, runs, failure.code);
    } on Object catch (e) {
      // Never leave the run `running` until it is reported as interrupted.
      _log(
        ChainLogLevel.error,
        'Run of hire ${queued.hireId} hit an unexpected ${e.runtimeType}',
      );
      return _fail(running, runs, runInternalError);
    }
    if (!await runs.markSucceeded(queued.hireId, output, _now())) {
      // Another pass already ended the run (for example as interrupted); its
      // state wins and this output is dropped.
      _log(
        ChainLogLevel.warning,
        'Run of hire ${queued.hireId} had already ended; its output was not '
        'stored',
      );
      return _Outcome.skipped;
    }
    return _Outcome.succeeded;
  }

  /// Puts the run back in the queue for its next attempt, after the backoff
  /// of that attempt. The hire stays `funded` and its run `queued`.
  Future<_Outcome> _retry(
    QueuedRun queued,
    HireRunStore runs,
    RuntimeFailure failure,
  ) async {
    final wait = retryBackoff[queued.attempts];
    final now = _now();
    if (!await runs.markRetry(
      queued.hireId,
      failure.code,
      notBefore: now.add(wait),
      at: now,
    )) {
      _log(
        ChainLogLevel.warning,
        'Run of hire ${queued.hireId} had already ended; its retry was not '
        'stored',
      );
      return _Outcome.skipped;
    }
    _log(
      ChainLogLevel.warning,
      'Run of hire ${queued.hireId} will retry in ${wait.inSeconds}s '
      '(attempt ${queued.attempts + 2} of ${retryBackoff.length + 1}): '
      '${failure.code}',
    );
    final rateLimited =
        failure is RuntimeProviderFailed && failure.status == 429;
    return rateLimited ? _Outcome.rateLimited : _Outcome.retried;
  }

  Future<_Outcome> _fail(Hire running, HireRunStore runs, String code) async {
    // The domain rule (a funded hire, a non-blank reason) holds before the
    // failure is stored.
    running.failRun(reason: code);
    if (!await runs.markFailed(running.id.value, code, _now())) {
      // Another pass already ended the run; its state wins.
      _log(
        ChainLogLevel.warning,
        'Run of hire ${running.id.value} had already ended; its failure '
        '($code) was not stored',
      );
      return _Outcome.skipped;
    }
    _log(
      ChainLogLevel.warning,
      'Run of hire ${running.id.value} failed: $code',
    );
    return _Outcome.failed;
  }
}

enum _Outcome { succeeded, failed, deferred, retried, rateLimited, skipped }
