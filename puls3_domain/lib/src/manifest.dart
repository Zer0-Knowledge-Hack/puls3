import 'errors.dart';

/// The version of a deployed agent manifest: an integer of at least 1.
///
/// Drafts have no version. The caller passes `latest?.next() ?? first` when it
/// validates a draft, because only storage knows the latest version.
final class ManifestVersion implements Comparable<ManifestVersion> {
  const ManifestVersion._(this.value);

  factory ManifestVersion(int value) {
    if (value < 1) throw InvalidManifest([ManifestProblem.versionInvalid]);
    return ManifestVersion._(value);
  }

  static const first = ManifestVersion._(1);

  final int value;

  ManifestVersion next() => ManifestVersion._(value + 1);

  @override
  int compareTo(ManifestVersion other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      other is ManifestVersion && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'v$value';
}
