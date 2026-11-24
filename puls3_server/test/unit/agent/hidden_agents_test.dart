import 'package:puls3_server/src/agent/hidden_agents.dart';
import 'package:test/test.dart';

const _key = 'PULS3_HIDDEN_AGENT_IDS';

void main() {
  group('HiddenAgents.fromEnvironment', () {
    test('an unset variable hides nothing', () {
      final hidden = HiddenAgents.fromEnvironment(const {});

      expect(hidden.ids, isEmpty);
      expect(hidden.contains(0), isFalse);
    });

    test('a blank variable hides nothing', () {
      final hidden = HiddenAgents.fromEnvironment(const {_key: '  '});

      expect(hidden.ids, isEmpty);
    });

    test('reads comma-separated registry ids', () {
      final hidden = HiddenAgents.fromEnvironment(const {_key: '15,16'});

      expect(hidden.ids, {15, 16});
      expect(hidden.contains(15), isTrue);
      expect(hidden.contains(16), isTrue);
      expect(hidden.contains(7), isFalse);
    });

    test('tolerates whitespace and ignores empty entries', () {
      final hidden = HiddenAgents.fromEnvironment(const {_key: ' 0 , ,16,'});

      expect(hidden.ids, {0, 16});
    });

    test('a null registry id is never hidden', () {
      final hidden = HiddenAgents.fromEnvironment(const {_key: '15'});

      expect(hidden.contains(null), isFalse);
    });

    for (final bad in ['abc', '-1', '+3', '1.5', '99999999999999999999999']) {
      test('the malformed entry "$bad" is an ArgumentError', () {
        expect(
          () => HiddenAgents.fromEnvironment({_key: '15,$bad'}),
          throwsA(
            isA<ArgumentError>()
                .having((e) => e.name, 'name', _key)
                .having((e) => e.invalidValue, 'invalidValue', bad),
          ),
        );
      });
    }

    test('the error names only the bad token, not the whole value', () {
      try {
        HiddenAgents.fromEnvironment(const {_key: '15,secret-ish,16'});
        fail('expected an ArgumentError');
      } on ArgumentError catch (e) {
        final text = e.toString();
        expect(text, contains(_key));
        expect(text, contains('secret-ish'));
        expect(text, isNot(contains('15,secret-ish,16')));
      }
    });
  });
}
