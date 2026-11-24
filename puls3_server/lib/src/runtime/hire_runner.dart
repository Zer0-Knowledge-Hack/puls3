import 'package:puls3_domain/puls3_domain.dart';

import '../chain/chain_log.dart';
import '../ledger/ledger_errors.dart';
import 'agent_runner.dart';
import 'hire_run_store.dart';
import 'run_manifest.dart';
import 'runtime_task.dart';
import 'subcontract_setup.dart';
import 'subcontract_tools.dart';
import 'team_run_quota.dart';
import 'tool_loop.dart';
import 'tool_loop_codec.dart';

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

/// Failure code for a free-model run above the agent's daily cap on the
/// platform account (#318). The hire stays funded, so the consumer can
/// reject it for a refund.
const teamRunQuotaExceeded = 'team_run_quota_exceeded';

/// Failure code for an unexpected error during the run, for example a TLS
/// failure that is not a `RuntimeFailure`. The detail goes to the log only.
const runInternalError = 'internal_error';

/// Failure code for a run whose stored loop state or child request cannot
/// be read (another codec version, or a damaged row).
const runLoopStateUnreadable = 'loop_state_unreadable';

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
    this.awaiting = 0,
  });

  final int succeeded;
  final int failed;
  final int interrupted;

  /// Queued runs left for a later pass (the chain could not be read).
  final int deferred;

  /// Runs put back in the queue after a retryable provider failure.
  final int retried;

  /// Runs that paused this pass to wait for a child hire. A run still
  /// waiting from an earlier pass is not counted.
  final int awaiting;

  int get total =>
      succeeded + failed + interrupted + deferred + retried + awaiting;

  @override
  String toString() =>
      'succeeded $succeeded, failed $failed, interrupted $interrupted, '
      'deferred $deferred, retried $retried, awaiting $awaiting';
}

/// Runs the agent of every funded hire once (#20, ADR-0004).
///
/// Each run goes through the domain: `Hire.startRun` before the model is
/// called and `Hire.failRun` on a failure, so a hire that is not funded, or
/// whose run already moved, is never run. The stored state changes only by
/// conditional writes ([HireRunStore]), so two runners never run one hire.
///
/// A successful run stores the result; the hire stays `funded` until the
/// server-signed escrow `submit` (#208) is confirmed.
///
/// With a [SubcontractSetup], a manifest that opted in to subcontract on a
/// tool-calling model ([ToolLoop.offersTools]) runs the tool loop
/// (ADR-0011 D8): its run pauses as `awaitingChild` when it opens a child
/// hire, and a later pass resumes it with the child's result. Every other
/// run, and every run without the setup, is the single plain segment it
/// always was. A retryable failure mid-loop stores the conversation, and the
/// next attempt continues it instead of starting again, so no finished
/// segment is paid twice and no child is opened twice.
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
    TeamRunQuota? teamQuota,
    Future<String> Function(RunManifest manifest, String input)? execute,
    SubcontractSetup? subcontracting,
  }) : _manifests = manifests,
       _runner = runner,
       _staleAfter = staleAfter,
       _now = now,
       _log = log,
       _batchSize = batchSize,
       _teamQuota = teamQuota ?? MemoryTeamRunQuota(),
       _execute = execute,
       _subcontracting = subcontracting;

  final RunManifestSource _manifests;
  final AgentRunner _runner;
  final Duration _staleAfter;
  final DateTime Function() _now;
  final ChainLog _log;
  final int _batchSize;
  final TeamRunQuota _teamQuota;
  final Future<String> Function(RunManifest manifest, String input)? _execute;
  final SubcontractSetup? _subcontracting;

  /// Fails interrupted runs, resumes up to one batch of paused runs whose
  /// child finished, then runs up to one batch of queued ones, one at a
  /// time.
  Future<RunPassSummary> pass({
    required HireRunStore runs,
    required HireRepository hires,
  }) async {
    var interrupted = 0;
    // Only `running` runs are swept: an `awaitingChild` run holds no model
    // call, so its age says nothing about a crash.
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
    var awaiting = 0;
    var rateLimited = false;
    void count(_Outcome outcome) {
      switch (outcome) {
        case _Outcome.succeeded:
          succeeded++;
        case _Outcome.failed:
          failed++;
        case _Outcome.deferred:
          deferred++;
        case _Outcome.retried || _Outcome.rateLimited:
          retried++;
        case _Outcome.awaiting:
          awaiting++;
        case _Outcome.skipped || _Outcome.waiting:
          break;
      }
      if (outcome == _Outcome.rateLimited) rateLimited = true;
    }

    // Paused runs first: their child is already paid for, and the parent's
    // deadline keeps running.
    if (_subcontracting case final setup?) {
      for (final entry in await runs.listAwaitingChild(limit: _batchSize)) {
        count(switch (entry) {
          AwaitingRun() => await _resumeOne(entry, setup, runs, hires),
          DamagedAwaitingRun() => await _failDamaged(entry, runs),
        });
        if (rateLimited) break;
      }
      // A failed parent never resumes, so its open children are judged here
      // (T6.4.4). It makes no model call, so a rate limit does not skip it.
      try {
        await setup.children.judgeOrphans();
      } on Object catch (e) {
        _log(
          ChainLogLevel.error,
          'Verdicts of children of failed parents deferred: ${e.runtimeType}',
        );
      }
    }
    // The provider is rate limited: the rest of the batch would only hit
    // the same limit, so it waits for a later pass.
    if (!rateLimited) {
      for (final queued in await runs.listQueued(
        limit: _batchSize,
        now: _now(),
      )) {
        count(await _runOne(queued, runs, hires));
        if (rateLimited) break;
      }
    }
    return RunPassSummary(
      succeeded: succeeded,
      failed: failed,
      interrupted: interrupted,
      deferred: deferred,
      retried: retried,
      awaiting: awaiting,
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
    if (manifest.provider == ModelPolicy.freeProvider &&
        !_teamQuota.reserve(agentId: queued.agentId, now: _now())) {
      return _fail(running, runs, teamRunQuotaExceeded);
    }

    final setup = _subcontracting;
    if (setup != null && ToolLoop.offersTools(manifest)) {
      final run = ToolLoopRun(
        hireId: queued.hireId,
        manifest: manifest,
        input: queued.input,
        expiresAt: expiresAt,
        reserveStroops: queued.reserveStroops,
      );
      final stored = queued.loopState;
      final ToolLoopState? state;
      try {
        state = stored == null ? null : decodeToolLoopState(stored);
      } on FormatException {
        return _fail(running, runs, runLoopStateUnreadable);
      }
      return _drive(
        setup,
        run,
        running,
        queued.attempts,
        runs,
        (loop) =>
            state == null ? loop.start(run) : loop.continueFrom(run, state),
      );
    }

    final String output;
    try {
      final execute = _execute;
      output = execute == null
          ? await _runner.run(manifest.task(queued.input))
          : await execute(manifest, queued.input);
    } on RuntimeFailure catch (failure) {
      if (isRetryable(failure) && queued.attempts < retryBackoff.length) {
        return _retry(queued.hireId, queued.attempts, runs, failure);
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

  /// Resumes [paused] once its child finished (ADR-0011 D8). The hire must
  /// still be funded and its job submittable; only then is the child's
  /// result asked for, and the run goes back to `running` before the model
  /// is called again.
  Future<_Outcome> _resumeOne(
    AwaitingRun paused,
    SubcontractSetup setup,
    HireRunStore runs,
    HireRepository hires,
  ) async {
    final hire = await hires.findById(HireId(paused.hireId));
    if (hire == null ||
        hire.status != HireStatus.funded ||
        hire.runtimeStatus == RuntimeStatus.failed) {
      _log(
        ChainLogLevel.error,
        'Paused hire ${paused.hireId} cannot resume (status '
        '${hire?.status.name}, run ${hire?.runtimeStatus?.name})',
      );
      return await runs.markFailed(paused.hireId, runNotRunnable, _now())
          ? _Outcome.failed
          : _Outcome.skipped;
    }
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      paused.expiredAt * 1000,
      isUtc: true,
    );
    if (!_now().add(_runner.timeout).isBefore(expiresAt)) {
      return _fail(hire, runs, runJobExpired);
    }
    final LoopAwaitingChild awaiting;
    try {
      awaiting = LoopAwaitingChild(
        decodeToolLoopState(paused.loopState),
        pendingToolCallId: paused.pendingToolCallId,
        childHireId: paused.childHireId,
        request: decodeChildRequest(paused.childRequest),
      );
    } on FormatException {
      return _fail(hire, runs, runLoopStateUnreadable);
    }

    final ChildToolResult? result;
    final RunManifest? manifest;
    try {
      result = await setup.children.resultOf(paused.childHireId);
      if (result == null) return _Outcome.waiting;
      manifest = await _manifests.find(paused.agentId, paused.manifestVersion);
    } on Object catch (e) {
      // The child's state or the manifest is unreadable: the run keeps
      // waiting for a later pass.
      _log(
        e is LedgerException ? ChainLogLevel.warning : ChainLogLevel.error,
        'Resume of hire ${paused.hireId} deferred: ${e.runtimeType}',
      );
      return _Outcome.deferred;
    }
    if (manifest == null) return _fail(hire, runs, manifestUnavailable);
    // The child's result joins the stored transcript in the same write that
    // resumes the run, before any lease or model call: a retry from here on
    // continues a transcript whose last tool call has its result, so the
    // paid child's output is never lost or asked for again.
    final child = result;
    // The runner's loop keeps the default headroom (`_drive`).
    final resumed = ToolLoop.resumedState(
      awaiting,
      child,
      maxConversationChars:
          manifest.inputMaxChars + defaultConversationHeadroomChars,
    );
    if (!await runs.markResumed(
      paused.hireId,
      _now(),
      loopState: encodeToolLoopState(resumed),
    )) {
      return _Outcome.skipped;
    }
    final run = ToolLoopRun(
      hireId: paused.hireId,
      manifest: manifest,
      input: paused.input,
      expiresAt: expiresAt,
      reserveStroops: paused.reserveStroops,
    );
    return _drive(
      setup,
      run,
      hire,
      paused.attempts,
      runs,
      (loop) => loop.resume(run, awaiting, child),
    );
  }

  /// Fails a paused row that cannot be resumed, so it leaves the awaiting
  /// batch instead of holding its place there on every pass.
  Future<_Outcome> _failDamaged(
    DamagedAwaitingRun damaged,
    HireRunStore runs,
  ) async {
    final code = damaged.hireMissing ? runNotRunnable : runLoopStateUnreadable;
    _log(
      ChainLogLevel.error,
      'Paused hire ${damaged.hireId} cannot resume, its row is damaged: '
      '$code',
    );
    return await runs.markFailed(damaged.hireId, code, _now())
        ? _Outcome.failed
        : _Outcome.skipped;
  }

  /// Runs [segment] of the tool loop for a run already `running`, on the
  /// runner the manifest's lease gives, and stores how it ended: succeeded,
  /// failed, retried with its conversation, or paused on a child.
  Future<_Outcome> _drive(
    SubcontractSetup setup,
    ToolLoopRun run,
    Hire running,
    int attempts,
    HireRunStore runs,
    Future<LoopOutcome> Function(ToolLoop loop) segment,
  ) async {
    final hireId = run.hireId;
    final lease = setup.lease ?? (manifest, body) => body(_runner);
    final LoopOutcome outcome;
    try {
      outcome = await lease(
        run.manifest,
        (runner) => segment(
          ToolLoop(
            runner: runner,
            tools: SubcontractTools(search: setup.search, port: setup.port),
            clock: _now,
            maxTurns: setup.maxTurns,
          ),
        ),
      );
    } on RuntimeFailure catch (failure) {
      // The lease failed before the loop ran (no builder credential): any
      // stored conversation is kept for the retry.
      if (isRetryable(failure) && attempts < retryBackoff.length) {
        return _retry(hireId, attempts, runs, failure);
      }
      return _fail(running, runs, failure.code);
    } on Object catch (e) {
      // A port or search error the loop does not own: a child may be
      // half-opened, so the run fails rather than opening it again.
      _log(
        ChainLogLevel.error,
        'Run of hire $hireId hit an unexpected ${e.runtimeType}',
      );
      return _fail(running, runs, runInternalError);
    }
    switch (outcome) {
      case LoopCompleted(:final text):
        if (!await runs.markSucceeded(hireId, text, _now())) {
          _log(
            ChainLogLevel.warning,
            'Run of hire $hireId had already ended; its output was not '
            'stored',
          );
          return _Outcome.skipped;
        }
        return _Outcome.succeeded;
      case LoopAwaitingChild():
        if (!await runs.markAwaitingChild(
          hireId,
          loopState: encodeToolLoopState(outcome.state),
          pendingToolCallId: outcome.pendingToolCallId,
          childHireId: outcome.childHireId,
          childRequest: encodeChildRequest(outcome.request),
          at: _now(),
        )) {
          _log(
            ChainLogLevel.warning,
            'Run of hire $hireId had already ended; its pause on child '
            '${outcome.childHireId} was not stored',
          );
          return _Outcome.skipped;
        }
        _log(
          ChainLogLevel.info,
          'Run of hire $hireId waits for child hire ${outcome.childHireId}',
        );
        return _Outcome.awaiting;
      case LoopFailed(:final code, :final failure):
        if (failure != null &&
            isRetryable(failure) &&
            attempts < retryBackoff.length) {
          return _retry(
            hireId,
            attempts,
            runs,
            failure,
            loopState: encodeToolLoopState(outcome.state),
          );
        }
        return _fail(running, runs, code);
    }
  }

  /// Puts the run back in the queue for its next attempt, after the backoff
  /// of that attempt. The hire stays `funded` and its run `queued`. A
  /// [loopState] is the conversation the next attempt continues.
  Future<_Outcome> _retry(
    int hireId,
    int attempts,
    HireRunStore runs,
    RuntimeFailure failure, {
    String? loopState,
  }) async {
    final wait = retryBackoff[attempts];
    final now = _now();
    if (!await runs.markRetry(
      hireId,
      failure.code,
      notBefore: now.add(wait),
      at: now,
      loopState: loopState,
    )) {
      _log(
        ChainLogLevel.warning,
        'Run of hire $hireId had already ended; its retry was not stored',
      );
      return _Outcome.skipped;
    }
    _log(
      ChainLogLevel.warning,
      'Run of hire $hireId will retry in ${wait.inSeconds}s '
      '(attempt ${attempts + 2} of ${retryBackoff.length + 1}): '
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

enum _Outcome {
  succeeded,
  failed,
  deferred,
  retried,
  rateLimited,
  skipped,

  /// The run paused on a new child hire.
  awaiting,

  /// A paused run's child is still working; nothing changed.
  waiting,
}
