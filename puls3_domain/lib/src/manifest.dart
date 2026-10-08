import 'errors.dart';

/// The version of a deployed agent manifest: an integer from 1 to 2^53-1.
///
/// Drafts have no version. The caller passes `latest?.next() ?? first` when it
/// validates a draft, because only storage knows the latest version.
final class ManifestVersion implements Comparable<ManifestVersion> {
  const ManifestVersion._(this.value);

  factory ManifestVersion(int value) {
    if (value < 1 || value > maxValue) {
      throw InvalidManifest([ManifestProblem.versionInvalid]);
    }
    return ManifestVersion._(value);
  }

  static const first = ManifestVersion._(1);

  /// The largest version: 2^53-1, so it stays exact when serialized as JSON.
  static const maxValue = 9007199254740991;

  final int value;

  /// The following version. Fails with [ManifestProblem.versionInvalid] at
  /// [maxValue].
  ManifestVersion next() => ManifestVersion(value + 1);

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

/// The model one agent runs on: a provider and a provider-specific id.
///
/// It never holds a credential. A paid provider's key is a reference in the
/// server's deploy record, so rotating it needs no new manifest version.
final class ModelId {
  const ModelId._(this.provider, this.id);

  /// [provider] is kebab-case of at most 32 characters. [id] is non-blank,
  /// has no whitespace and is at most 128 runes.
  factory ModelId({required String provider, required String id}) {
    if (provider.length > _maxProviderLength ||
        !_kebabCase.hasMatch(provider) ||
        id.isEmpty ||
        id.runes.length > _maxIdRunes ||
        _whitespace.hasMatch(id)) {
      throw InvalidManifest([ManifestProblem.modelMalformed]);
    }
    return ModelId._(provider, id);
  }

  final String provider;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is ModelId && other.provider == provider && other.id == id;

  @override
  int get hashCode => Object.hash(provider, id);

  @override
  String toString() => '$provider/$id';
}

const _maxProviderLength = 32;
const _maxIdRunes = 128;
final _kebabCase = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
final _whitespace = RegExp(r'\s');

/// Which models agents may use. It is injected into validation, never a
/// domain constant: the lists are configuration.
///
/// `workers-ai` (free) passes only for ids in [workersAiModels]. A paid
/// provider (BYOK) passes when it is in [paidProviders], with any id.
final class ModelPolicy {
  /// Throws [ArgumentError] if [paidProviders] contains [freeProvider].
  ModelPolicy({
    required Set<String> workersAiModels,
    required Set<String> paidProviders,
  }) : workersAiModels = Set.unmodifiable(workersAiModels),
       paidProviders = Set.unmodifiable(paidProviders) {
    if (paidProviders.contains(freeProvider)) {
      throw ArgumentError.value(
        paidProviders,
        'paidProviders',
        '$freeProvider is the free provider, not a paid one',
      );
    }
  }

  static const freeProvider = 'workers-ai';

  final Set<String> workersAiModels;
  final Set<String> paidProviders;

  bool allows(ModelId model) => model.provider == freeProvider
      ? workersAiModels.contains(model.id)
      : paidProviders.contains(model.provider);

  /// Whether [provider] needs the builder's own API key.
  bool isPaid(String provider) => provider != freeProvider;
}
