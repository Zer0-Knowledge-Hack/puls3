import 'dart:async';

import 'package:puls3_server/src/chain/tracker_loop.dart';
import 'package:test/test.dart';

/// A periodic timer that fires only when the test calls [fire].
final class _ManualTimer implements Timer {
  _ManualTimer(this.interval, this._callback);

  final Duration interval;
  final void Function(Timer) _callback;
  bool _active = true;

  void fire() {
    if (_active) _callback(this);
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

void main() {
  group('TrackerLoopConfig.fromEnvironment', () {
    test('is disabled with a 5 second interval by default', () {
      final config = TrackerLoopConfig.fromEnvironment(const {});

      expect(config.enabled, isFalse);
      expect(config.interval, const Duration(seconds: 5));
    });

    test('reads PULS3_TRACKER_ENABLED and the interval', () {
      final config = TrackerLoopConfig.fromEnvironment(const {
        'PULS3_TRACKER_ENABLED': 'true',
        'PULS3_TRACKER_INTERVAL_SECONDS': '12',
      });

      expect(config.enabled, isTrue);
      expect(config.interval, const Duration(seconds: 12));
    });

    test('only "true" enables it', () {
      for (final value in ['false', '', 'yes', '1']) {
        expect(
          TrackerLoopConfig.fromEnvironment({
            'PULS3_TRACKER_ENABLED': value,
          }).enabled,
          isFalse,
          reason: value,
        );
      }
    });

    test('rejects an interval that is not a positive integer', () {
      for (final value in ['0', '-1', 'soon', '1.5']) {
        expect(
          () => TrackerLoopConfig.fromEnvironment({
            'PULS3_TRACKER_INTERVAL_SECONDS': value,
          }),
          throwsArgumentError,
          reason: value,
        );
      }
    });
  });

  group('TrackerLoop', () {
    late List<_ManualTimer> timers;
    late List<String> logged;
    late int passes;
    late Completer<void>? gate;

    setUp(() {
      timers = [];
      logged = [];
      passes = 0;
      gate = null;
    });

    TrackerLoop loop() => TrackerLoop(
      interval: const Duration(seconds: 5),
      passTimeout: const Duration(minutes: 1),
      runPass: () async {
        passes++;
        await gate?.future;
      },
      log: (level, message) => logged.add('${level.name}: $message'),
      periodic: (interval, callback) {
        final timer = _ManualTimer(interval, callback);
        timers.add(timer);
        return timer;
      },
    );

    test('start schedules passes at the interval', () async {
      final l = loop()..start();

      expect(timers.single.interval, const Duration(seconds: 5));
      expect(l.isRunning, isTrue);
      timers.single.fire();
      await pumpEventQueue();
      timers.single.fire();
      await pumpEventQueue();

      expect(passes, 2);
    });

    test('a second start does not schedule twice', () {
      loop()
        ..start()
        ..start();

      expect(timers, hasLength(1));
    });

    test('a tick while a pass is in flight is skipped', () async {
      gate = Completer<void>();
      loop().start();

      timers.single.fire();
      timers.single.fire();
      await pumpEventQueue();
      expect(passes, 1);

      gate!.complete();
      await pumpEventQueue();
      timers.single.fire();
      await pumpEventQueue();
      expect(passes, 2);
    });

    test('a failing pass is logged and the loop goes on', () async {
      var calls = 0;
      final l = TrackerLoop(
        interval: const Duration(seconds: 5),
        passTimeout: const Duration(minutes: 1),
        runPass: () async {
          calls++;
          if (calls == 1) throw StateError('database down');
        },
        log: (level, message) => logged.add('${level.name}: $message'),
        periodic: (interval, callback) {
          final timer = _ManualTimer(interval, callback);
          timers.add(timer);
          return timer;
        },
      )..start();

      timers.single.fire();
      await pumpEventQueue();
      timers.single.fire();
      await pumpEventQueue();

      expect(calls, 2);
      expect(l.isRunning, isTrue);
      expect(
        logged,
        contains(allOf(startsWith('error'), contains('database down'))),
      );
    });

    test('a hung pass times out, is logged and a later tick runs a new '
        'pass', () async {
      var calls = 0;
      final l = TrackerLoop(
        interval: const Duration(seconds: 5),
        passTimeout: const Duration(milliseconds: 20),
        runPass: () {
          calls++;
          return calls == 1 ? Completer<void>().future : Future.value();
        },
        log: (level, message) => logged.add('${level.name}: $message'),
        periodic: (interval, callback) {
          final timer = _ManualTimer(interval, callback);
          timers.add(timer);
          return timer;
        },
      )..start();

      timers.single.fire();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      timers.single.fire();
      await pumpEventQueue();

      expect(calls, 2);
      expect(l.isRunning, isTrue);
      expect(
        logged,
        contains(allOf(startsWith('error'), contains('timed out'))),
      );
    });

    test('stop cancels the timer and waits for the pass in flight', () async {
      gate = Completer<void>();
      final l = loop()..start();
      timers.single.fire();
      await pumpEventQueue();

      var stopped = false;
      final stopping = l.stop().then((_) => stopped = true);
      await pumpEventQueue();
      expect(stopped, isFalse);
      expect(timers.single.isActive, isFalse);
      expect(l.isRunning, isFalse);

      gate!.complete();
      await stopping;
      expect(stopped, isTrue);
      timers.single.fire();
      await pumpEventQueue();
      expect(passes, 1);
    });

    test('stop runs onStop after the pass in flight, to release what the '
        'passes use', () async {
      gate = Completer<void>();
      final events = <String>[];
      final l = TrackerLoop(
        interval: const Duration(seconds: 5),
        passTimeout: const Duration(minutes: 1),
        runPass: () async {
          await gate!.future;
          events.add('pass done');
        },
        log: (level, message) => logged.add('${level.name}: $message'),
        periodic: (interval, callback) {
          final timer = _ManualTimer(interval, callback);
          timers.add(timer);
          return timer;
        },
        onStop: () async => events.add('closed'),
      )..start();
      timers.single.fire();
      await pumpEventQueue();

      final stopping = l.stop();
      await pumpEventQueue();
      expect(events, isEmpty);

      gate!.complete();
      await stopping;
      expect(events, ['pass done', 'closed']);
    });
  });
}
