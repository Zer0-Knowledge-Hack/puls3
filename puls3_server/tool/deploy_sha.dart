/// Helpers for `tool/set_deploy_sha.dart`, the Serverpod Cloud pre-deploy
/// script that records the deployed commit in `PULS3_GIT_SHA`.
library;

/// The `PULS3_GIT_SHA` value for the commit [sha] (from
/// `git rev-parse --short HEAD`). A [dirty] working tree is uploaded as is
/// but is not that commit, so the value gets a `-dirty` suffix.
String deployShaValue({required String sha, required bool dirty}) {
  final trimmed = sha.trim();
  if (trimmed.isEmpty) {
    throw StateError('git rev-parse --short HEAD returned no commit');
  }
  return dirty ? '$trimmed-dirty' : trimmed;
}

/// The `scloud` arguments that set `PULS3_GIT_SHA` to [value] in the linked
/// project. `--non-interactive` makes it fail instead of prompting, for
/// example when the CLI is not logged in.
List<String> scloudSetShaArguments(String value) => [
  '--non-interactive',
  'variable',
  'set',
  'PULS3_GIT_SHA',
  value,
];
