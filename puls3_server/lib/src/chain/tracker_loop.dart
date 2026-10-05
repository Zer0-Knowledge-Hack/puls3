import 'dart:async';

import 'chain_log.dart';

/// Whether and how often the chain submission tracker runs.
///
/// | Variable | Field | Default |
/// |---|---|---|
/// | `PULS3_TRACKER_ENABLED` | [enabled] (only `true` enables it) | `false` |
/// | `PULS3_TRACKER_INTERVAL_SECONDS` | [interval] | `5` |
///
/// It is off by default so tests, CI and existing deployments do not poll
/// the chain unless asked to.
final class TrackerLoopConfig {
  const TrackerLoopConfig({required this.enabled, required this.interval});

  /// Reads [env] (normally `Platform.environment`). Throws [ArgumentError]
  /// when the interval is set but is not a positive whole number of seconds.
  factory TrackerLoopConfig.fromEnvironment(Map<String, String> env) {
    const intervalName = 'PULS3_TRACKER_INTERVAL_SECONDS';
    final rawInterval = env[intervalName];
    var seconds = _defaultIntervalSeconds;
    if (rawInterval != null && rawInterval.isNotEmpty) {
      final parsed = int.tryParse(rawInterval);
      if (parsed == null || parsed < 1) {
        throw ArgumentError.value(
          rawInterval,
          intervalName,
          'must be a positive whole number of seconds',
        );
      }
      seconds = parsed;
    }
    return TrackerLoopConfig(
      enabled: env['PULS3_TRACKER_ENABLED'] == 'true',
      interval: Duration(seconds: seconds),
    );
  }

  final bool enabled;

  /// Time between the starts of two passes.
  final Duration interval;
}

const _defaultIntervalSeconds = 5;

/// Creates a periodic timer; [Timer.periodic] in production.
typedef PeriodicTimerFactory =
    Timer Function(Duration interval, void Function(Timer) callback);

/// Runs [runPass] every interval, never two at a time: a tick that finds
/// a pass still running is skipped. A pass that throws is logged and the
/// loop goes on.
final class TrackerLoop {
  TrackerLoop({
    required Duration interval,
    required Future<void> Function() runPass,
    required ChainLog log,
    PeriodicTimerFactory periodic = Timer.periodic,
  }) : _interval = interval,
       _runPass = runPass,
       _log = log,
       _periodic = periodic;

  final Duration _interval;
  final Future<void> Function() _runPass;
  final ChainLog _log;
  final PeriodicTimerFactory _periodic;

  Timer? _timer;
  Future<void>? _inFlight;

  bool get isRunning => _timer != null;

  /// Schedules passes. Does nothing when already running.
  void start() {
    _timer ??= _periodic(_interval, (_) => _tick());
  }

  /// Stops scheduling passes and completes when the pass in flight, if
  /// any, has finished.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _inFlight;
  }

  void _tick() {
    if (_inFlight != null || _timer == null) return;
    _inFlight = _guardedPass().whenComplete(() => _inFlight = null);
  }

  Future<void> _guardedPass() async {
    try {
      await _runPass();
    } catch (e) {
      _log(ChainLogLevel.error, 'Tracker pass failed: $e');
    }
  }
}
