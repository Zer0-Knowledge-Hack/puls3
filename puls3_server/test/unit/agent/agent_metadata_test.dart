import 'dart:convert';
import 'dart:typed_data';

import 'package:puls3_server/src/agent/agent_metadata.dart';
import 'package:test/test.dart';

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  group('parseAgentId', () {
    test('accepts a non-empty id', () {
      expect(parseAgentId(_bytes('agt-001')), 'agt-001');
    });

    test('rejects an unset value, an empty id and invalid UTF-8', () {
      expect(parseAgentId(null), isNull);
      expect(parseAgentId(_bytes('')), isNull);
      expect(parseAgentId(Uint8List.fromList([0xff, 0xfe])), isNull);
    });
  });

  group('parseName', () {
    test('accepts 3 and 48 characters', () {
      expect(parseName(_bytes('abc')), 'abc');
      expect(parseName(_bytes('a' * 48)), 'a' * 48);
    });

    test('rejects 2 and 49 characters or an unset value', () {
      expect(parseName(_bytes('ab')), isNull);
      expect(parseName(_bytes('a' * 49)), isNull);
      expect(parseName(null), isNull);
    });

    test('counts characters, not UTF-8 bytes', () {
      // 3 characters, 6 bytes.
      expect(parseName(_bytes('ñññ')), 'ñññ');
    });
  });

  group('parseDescription', () {
    test('accepts 10 and 280 characters', () {
      expect(parseDescription(_bytes('x' * 10)), 'x' * 10);
      expect(parseDescription(_bytes('x' * 280)), 'x' * 280);
    });

    test('rejects 9 and 281 characters or an unset value', () {
      expect(parseDescription(_bytes('x' * 9)), isNull);
      expect(parseDescription(_bytes('x' * 281)), isNull);
      expect(parseDescription(null), isNull);
    });
  });

  group('parseSkills', () {
    test('keeps the order of a valid array', () {
      expect(parseSkills(_bytes('["code-review","testing"]')), [
        'code-review',
        'testing',
      ]);
    });

    test('accepts 1 and 5 skills and rejects 0 and 6', () {
      expect(parseSkills(_bytes('["a"]')), ['a']);
      expect(parseSkills(_bytes('["a","b","c","d","e"]')), hasLength(5));
      expect(parseSkills(_bytes('[]')), isNull);
      expect(parseSkills(_bytes('["a","b","c","d","e","f"]')), isNull);
    });

    test('rejects an object, invalid JSON and a non-string element', () {
      expect(parseSkills(_bytes('{"a":1}')), isNull);
      expect(parseSkills(_bytes('not json')), isNull);
      expect(parseSkills(_bytes('["a",1]')), isNull);
      expect(parseSkills(null), isNull);
    });

    test('rejects an id that is not kebab-case', () {
      expect(parseSkills(_bytes('["Code Review"]')), isNull);
      expect(parseSkills(_bytes('["code_review"]')), isNull);
      expect(parseSkills(_bytes('["-a"]')), isNull);
      expect(parseSkills(_bytes('["a--b"]')), isNull);
    });
  });

  group('parsePriceUsdcStroops', () {
    test('parses a valid price', () {
      expect(parsePriceUsdcStroops(_bytes('25000000')), 25000000);
    });

    test('accepts 2^53 - 1 and rejects 2^53', () {
      expect(
        parsePriceUsdcStroops(_bytes('9007199254740991')),
        9007199254740991,
      );
      expect(parsePriceUsdcStroops(_bytes('9007199254740992')), isNull);
    });

    test('rejects zero, negative, non-numeric and fractional values', () {
      for (final bad in ['0', '-5', 'abc', '1.5', '', '01', ' 5', '+5']) {
        expect(parsePriceUsdcStroops(_bytes(bad)), isNull, reason: bad);
      }
      expect(parsePriceUsdcStroops(null), isNull);
    });
  });

  group('parseModel', () {
    test('keeps a valid model', () {
      expect(parseModel(_bytes('claude-sonnet-4')), 'claude-sonnet-4');
    });

    test('an unset, empty or invalid UTF-8 model is null', () {
      expect(parseModel(null), isNull);
      expect(parseModel(_bytes('')), isNull);
      expect(parseModel(Uint8List.fromList([0xff])), isNull);
    });
  });
}
