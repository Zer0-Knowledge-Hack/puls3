import '../chain/chain_log.dart';

/// Queues the runs of hires paid before the `hire_run` table existed, once
/// per process.
///
/// Only a call that returns marks the backfill done. A failed call (a
/// database error that is not the expected duplicate run) is logged and
/// tried again on the next pass, and never stops that pass.
final class MissedRunBackfill {
  MissedRunBackfill({required ChainLog log}) : _log = log;

  final ChainLog _log;
  var _done = false;

  bool get isDone => _done;

  /// Calls [enqueueMissing] unless an earlier call already succeeded.
  Future<void> run(Future<int> Function() enqueueMissing) async {
    if (_done) return;
    try {
      final queued = await enqueueMissing();
      if (queued > 0) _log(ChainLogLevel.info, 'Queued $queued missed runs');
      _done = true;
    } on Object catch (e) {
      // Only the type: a database error can carry SQL and row values.
      _log(
        ChainLogLevel.error,
        'Queuing missed runs failed (${e.runtimeType}); '
        'trying again on the next pass',
      );
    }
  }
}
