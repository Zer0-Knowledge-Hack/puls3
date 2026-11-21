import 'dart:io';

import 'package:puls3_cli/puls3_cli.dart';
import 'package:puls3_sdk/puls3_sdk.dart';
import 'package:test/test.dart';

/// The CLI reference (#225), read from the repository.
String _reference() =>
    File('../docs/cli/reference.md').readAsStringSync();

/// The commands `puls3 --help` lists, as `group action`.
Future<List<String>> _commandsInUsage() async {
  final out = StringBuffer();
  await runPuls3(
    ['--help'],
    connect: (_) => throw StateError('no connection for --help'),
    environment: const {},
    out: out,
    err: StringBuffer(),
  );
  final commands = <String>[];
  var inList = false;
  for (final line in '$out'.split('\n')) {
    if (line.startsWith('Commands:')) {
      inList = true;
      continue;
    }
    if (inList && line.trim().isEmpty) break;
    final match = RegExp(r'^  ([a-z]+(?: [a-z-]+)?)\b').firstMatch(line);
    if (inList && match != null) {
      final words = match.group(1)!.split(' ');
      // `run --manifest` has no action word; `hire get <id>` has one.
      commands.add(
        words.length > 1 && !words[1].startsWith('-')
            ? '${words[0]} ${words[1]}'
            : words[0],
      );
    }
  }
  return commands;
}

/// The commands the reference has a `### \`...\`` section for, as
/// `group action`.
List<String> _commandsInReference() {
  final commands = <String>[];
  for (final line in _reference().split('\n')) {
    if (!line.startsWith('### `')) continue;
    // A heading can name two commands: `hire prepare-complete <id>` and
    // `hire prepare-reject <id> ...`.
    for (final m in RegExp('`([a-z]+(?: [a-z-]+)?)[^`]*`').allMatches(line)) {
      final words = m.group(1)!.split(' ');
      commands.add(
        words.length > 1 && !words[1].startsWith('-')
            ? '${words[0]} ${words[1]}'
            : words[0],
      );
    }
  }
  return commands;
}

void main() {
  group('docs/cli/reference.md (#225)', () {
    test('documents every command of the binary, and no other', () async {
      final usage = await _commandsInUsage();
      final reference = _commandsInReference();

      expect(usage, isNotEmpty);
      expect(reference.toSet(), usage.toSet());
    });

    test('documents every exit code', () {
      final reference = _reference();
      for (final code in [
        ExitCodes.ok,
        ExitCodes.serverError,
        ExitCodes.notFound,
        ExitCodes.usage,
        ExitCodes.unavailable,
        ExitCodes.sessionFile,
        ExitCodes.noSession,
      ]) {
        expect(reference, contains('| $code |'), reason: 'exit $code');
      }
    });

    test('documents every environment variable the CLI reads', () {
      final reference = _reference();
      for (final name in [
        apiUrlVariable,
        walletVariable,
        refreshTokenVariable,
        sessionFileVariable,
        'CLOUDFLARE_ACCOUNT_ID',
        'CLOUDFLARE_API_TOKEN',
        'ANTHROPIC_API_KEY',
      ]) {
        expect(reference, contains('`$name`'), reason: name);
      }
    });

    test('holds no secret, seed or token', () {
      final reference = _reference();
      // A Stellar secret seed, a puls3 refresh token, an Anthropic key.
      expect(reference, isNot(matches(RegExp(r'\bS[A-Z2-7]{55}\b'))));
      expect(reference, isNot(contains('sajrt:')));
      expect(reference, isNot(matches(RegExp(r'sk-ant-[A-Za-z0-9_-]{10,}'))));
    });

    test('says the CLI never signs and points at the app', () {
      final reference = _reference();
      expect(reference, contains('never signs or submits a transaction'));
      expect(reference, contains('puls3.org'));
    });
  });
}
