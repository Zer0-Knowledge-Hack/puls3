/// A builder's account for a paid provider (ADR-0004 amendment, #318). The
/// secret is the paid provider's key. Free `workers-ai` models run on the team
/// account and never read this store, and no credential is part of the
/// manifest.
final class BuilderProviderCredential {
  const BuilderProviderCredential({
    required this.provider,
    required this.secret,
    this.accountId,
  });

  final String provider;

  /// API token or key. Callers must not log or return it.
  final String secret;

  /// Cloudflare account id for `workers-ai`. Null for other providers.
  final String? accountId;
}

/// Stores builder credentials outside the manifest. A missing row means the
/// test run cannot call a model.
abstract interface class BuilderCredentialStore {
  Future<BuilderProviderCredential?> find({
    required String owner,
    required String provider,
  });

  /// Replaces the credential for [owner] and [credential.provider].
  Future<void> save({
    required String owner,
    required BuilderProviderCredential credential,
  });
}

/// In-memory [BuilderCredentialStore].
final class MemoryBuilderCredentialStore implements BuilderCredentialStore {
  final Map<String, BuilderProviderCredential> _rows = {};

  @override
  Future<BuilderProviderCredential?> find({
    required String owner,
    required String provider,
  }) async => _rows['$owner|$provider'];

  @override
  Future<void> save({
    required String owner,
    required BuilderProviderCredential credential,
  }) async {
    _rows['$owner|${credential.provider}'] = credential;
  }
}
