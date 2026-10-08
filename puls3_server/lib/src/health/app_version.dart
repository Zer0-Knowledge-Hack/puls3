/// The server package version. A unit test keeps it equal to the `version`
/// in `pubspec.yaml`.
const packageVersion = '1.0.0';

const _gitShaName = 'PULS3_GIT_SHA';

/// Semver build identifiers: dot-separated, non-empty `[0-9A-Za-z-]` runs.
final _buildMetadata = RegExp(r'^[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*$');

/// The version `health.check` reports, built from [env] (normally
/// `Platform.environment`).
///
/// It is [packageVersion], plus `+<sha>` when `PULS3_GIT_SHA` is set, so a
/// deployed server names the commit it runs (for example `1.0.0+63fbad2`).
/// An unset or empty variable reports [packageVersion] alone. A value that is
/// not a semver build identifier throws an [ArgumentError].
String appVersionFromEnvironment(Map<String, String> env) {
  final sha = env[_gitShaName];
  if (sha == null || sha.isEmpty) return packageVersion;
  if (!_buildMetadata.hasMatch(sha)) {
    throw ArgumentError.value(
      sha,
      _gitShaName,
      'must contain only letters, digits, "-" and "."',
    );
  }
  return '$packageVersion+$sha';
}
