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

/// What one [HireRunner.pass] did.
final class RunPassSummary {
  const RunPassSummary({
    required this.succeeded,
    required this.failed,
    required this.interrupted,
    required this.deferred,
  });

  final int succeeded;
  final int failed;
  final int interrupted;

  /// Queued runs left for a later pass (the chain could not be read).
  final int deferred;

  int get total => succeeded + failed + interrupted + deferred;

  @override
  String toString() =>
      'succeeded $succeeded, failed $failed, interrupted $interrupted, '
      'deferred $deferred';
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
    for (final queued in await runs.listQueued(limit: _batchSize)) {
      switch (await _runOne(queued, runs, hires)) {
        case _Outcome.succeeded:
          succeeded++;
        case _Outcome.failed:
          failed++;
        case _Outcome.deferred:
          deferred++;
        case _Outcome.skipped:
          break;
      }
    }
    return RunPassSummary(
      succeeded: succeeded,
      failed: failed,
      interrupted: interrupted,
      deferred: deferred,
    );
  }

  Future<_Outcome> _runOne(
    QueuedRun queued,
    HireRunStore runs,
    HireRepository hires,
  ) async {
    final hire = await hires.findById(HireId(queued.hireId));
    final Hire running;
    try {
      if (hire == null) throw StateError('hire ${queued.hireId} is missing');
      running = hire.startRun();
    } on Object catch (e) {
      // Not funded, or the run already moved: never call the model.
      _log(ChainLogLevel.error, 'Hire ${queued.hireId} cannot run: $e');
      return _Outcome.skipped;
    }

    final RunManifest? manifest;
    try {
      manifest = await _manifests.find(queued.agentId, queued.manifestVersion);
    } on LedgerException catch (e) {
      _log(
        ChainLogLevel.warning,
        'Run of hire ${queued.hireId} deferred, the registry is unreadable: $e',
      );
      return _Outcome.deferred;
    }

    if (!await runs.markRunning(queued.hireId, _now())) {
      return _Outcome.skipped;
    }
    if (manifest == null) {
      return _fail(running, runs, manifestUnavailable);
    }

    try {
      final output = await _runner.run(manifest.task(queued.input));
      await runs.markSucceeded(queued.hireId, output, _now());
      return _Outcome.succeeded;
    } on RuntimeFailure catch (failure) {
      return _fail(running, runs, failure.code);
    }
  }

  Future<_Outcome> _fail(Hire running, HireRunStore runs, String code) async {
    // The domain rule (a funded hire, a non-blank reason) holds before the
    // failure is stored.
    running.failRun(reason: code);
    await runs.markFailed(running.id.value, code, _now());
    _log(
      ChainLogLevel.warning,
      'Run of hire ${running.id.value} failed: $code',
    );
    return _Outcome.failed;
  }
}

enum _Outcome { succeeded, failed, deferred, skipped }
