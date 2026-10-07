// Serverpod Cloud pre-deploy script (see scloud.yaml and README "Deploy to
// Serverpod Cloud"). `scloud deploy` runs it on the deploying machine, in
// puls3_server/, before it uploads the project. It sets PULS3_GIT_SHA in the
// linked project to the current commit, so health.check reports it. A non-zero
// exit stops the deploy.
import 'dart:io';

import 'deploy_sha.dart';

Future<void> main() async {
  final sha = await _git(['rev-parse', '--short', 'HEAD']);
  final changes = await _git(['status', '--porcelain', '--untracked-files=no']);
  final value = deployShaValue(sha: sha, dirty: changes.trim().isNotEmpty);

  stdout.writeln('Setting PULS3_GIT_SHA=$value');
  final result = await Process.run(
    'scloud',
    scloudSetShaArguments(value),
    runInShell: Platform.isWindows,
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  exitCode = result.exitCode;
}

Future<String> _git(List<String> arguments) async {
  final result = await Process.run('git', arguments);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    throw ProcessException('git', arguments, 'git failed', result.exitCode);
  }
  return result.stdout as String;
}
