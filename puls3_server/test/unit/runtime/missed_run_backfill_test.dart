import 'package:puls3_server/src/chain/chain_log.dart';
import 'package:puls3_server/src/runtime/missed_run_backfill.dart';
import 'package:puls3_server/src/runtime/serverpod_hire_run_store.dart';
import 'package:test/test.dart';

void main() {
  group('isDuplicateRun', () {
    test('is the unique violation of hire_run_hire_idx only', () {
      expect(
        isDuplicateRun(code: '23505', constraintName: 'hire_run_hire_idx'),
        isTrue,
      );
    });

    test('any other unique index, code or missing value is not', () {
      expect(
        isDuplicateRun(code: '23505', constraintName: 'hire_run_pkey'),
        isFalse,
      );
      expect(isDuplicateRun(code: '23505', constraintName: null), isFalse);
      // Permission, missing table, connection and FK failures.
      for (final code in ['42501', '42P01', '08006', '23503']) {
        expect(
          isDuplicateRun(code: code, constraintName: 'hire_run_hire_idx'),
          isFalse,
          reason: code,
        );
      }
      expect(
        isDuplicateRun(code: null, constraintName: 'hire_run_hire_idx'),
        isFalse,
      );
    });
  });

  group('MissedRunBackfill', () {
    late List<(ChainLogLevel, String)> logs;
    late MissedRunBackfill backfill;

    setUp(() {
      logs = [];
      backfill = MissedRunBackfill(log: (level, m) => logs.add((level, m)));
    });

    test('runs once after a success', () async {
      var calls = 0;
      Future<int> enqueue() async {
        calls++;
        return 2;
      }

      await backfill.run(enqueue);
      await backfill.run(enqueue);

      expect(calls, 1);
      expect(backfill.isDone, isTrue);
      expect(logs, [(ChainLogLevel.info, 'Queued 2 missed runs')]);
    });

    test('nothing to queue logs nothing and is done', () async {
      await backfill.run(() async => 0);
      expect(backfill.isDone, isTrue);
      expect(logs, isEmpty);
    });

    test('a failure is logged by type only, never marks it done, and the '
        'next pass tries again', () async {
      var calls = 0;
      await backfill.run(() async {
        calls++;
        throw StateError('permission denied for table hire_run: GSECRET');
      });

      expect(backfill.isDone, isFalse);
      expect(logs.single.$1, ChainLogLevel.error);
      expect(logs.single.$2, contains('StateError'));
      expect(logs.single.$2, isNot(contains('GSECRET')));

      await backfill.run(() async {
        calls++;
        return 1;
      });
      expect(calls, 2);
      expect(backfill.isDone, isTrue);
    });
  });
}
