import 'package:puls3_server/src/hire/hire_relay_config.dart';
import 'package:puls3_server/src/runtime/agent_runtime_wiring.dart';
import 'package:puls3_server/src/runtime/tool_loop.dart';
import 'package:test/test.dart';

const _duration = {HireRelayConfig.jobDurationKey: '3600'};

void main() {
  group('subcontractOffReason', () {
    test('is null when submit is on and the job duration is set', () {
      expect(subcontractOffReason(_duration, submitOn: true), isNull);
      expect(subcontractEnabled(_duration, submitOn: true), isTrue);
    });

    test('is off wherever submit is off, even with every setting', () {
      expect(subcontractOffReason(_duration, submitOn: false), isNotNull);
      expect(subcontractEnabled(_duration, submitOn: false), isFalse);
    });

    test('is off when the job duration is missing', () {
      expect(
        subcontractOffReason(const {}, submitOn: true),
        contains(HireRelayConfig.jobDurationKey),
      );
      expect(subcontractEnabled(const {}, submitOn: true), isFalse);
    });

    test('is off when the job duration is not a positive number', () {
      for (final value in ['0', '-5', 'abc', '']) {
        expect(
          subcontractEnabled({
            HireRelayConfig.jobDurationKey: value,
          }, submitOn: true),
          isFalse,
          reason: value,
        );
      }
    });
  });

  group('agentRuntimeTimings', () {
    const timeout = Duration(seconds: 120);

    test('without subcontracting a run is one call, as before the tool '
        'loop', () {
      final timings = agentRuntimeTimings(
        timeout: timeout,
        batchSize: 10,
        subcontracting: false,
      );

      expect(timings.staleAfter, const Duration(seconds: 120 + 60));
      expect(timings.passTimeout, const Duration(seconds: 2 * 10 * 120 + 60));
    });

    test('with subcontracting a run may hold up to the loop turns', () {
      final timings = agentRuntimeTimings(
        timeout: timeout,
        batchSize: 10,
        subcontracting: true,
      );

      expect(
        timings.staleAfter,
        timeout * defaultMaxLoopTurns + const Duration(minutes: 1),
      );
      expect(
        timings.passTimeout,
        timeout * (2 * 10 * defaultMaxLoopTurns) + const Duration(minutes: 1),
      );
    });
  });
}
