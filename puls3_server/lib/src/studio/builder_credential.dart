/// A builder's provider account (ADR-0004 amendment). The secret is the
/// Cloudflare token or the paid provider's key. It is never part of the
/// manifest and never the team Workers AI token.
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
