import 'dart:convert';

/// One deploy of a draft, including the envelopes the builder still has to sign.
final class StudioDeployRow {
  const StudioDeployRow({
    required this.draftId,
    required this.owner,
    required this.state,
    required this.agentWallet,
    required this.registrationUri,
    required this.updatedAt,
    this.manifestJson,
    this.preparationId,
    this.unsignedEnvelopeXdr,
    this.authorizationEntryXdr,
    this.signatureExpirationLedger,
    this.registrationHash,
    this.walletTxHash,
    this.registryAgentId,
    this.expiresAt,
    this.failureCode,
    this.retryFromStep,
    this.walletAuthJson,
  });

  final int draftId;
  final String owner;

  /// One of the deploy session states in api.md.
  final String state;
  final String agentWallet;
  final String registrationUri;

  /// The draft document hashed into `register_full`. Later edits do not
  /// change what was registered or what a hire runs.
  final String? manifestJson;
  final String? preparationId;
  final String? unsignedEnvelopeXdr;
  final String? authorizationEntryXdr;
  final int? signatureExpirationLedger;
  final String? registrationHash;
  final String? walletTxHash;
  final int? registryAgentId;
  final DateTime? expiresAt;
  final String? failureCode;
  final int? retryFromStep;

  /// Rebuild inputs for the `set_agent_wallet` envelope.
  final String? walletAuthJson;
  final DateTime updatedAt;

  StudioDeployRow copy({
    String? state,
    String? preparationId,
    String? unsignedEnvelopeXdr,
    String? authorizationEntryXdr,
    int? signatureExpirationLedger,
    String? registrationHash,
    String? walletTxHash,
    int? registryAgentId,
    DateTime? expiresAt,
    String? failureCode,
    int? retryFromStep,
    String? walletAuthJson,
    String? manifestJson,
    bool clearFailure = false,
    bool clearAuthorization = false,
    required DateTime updatedAt,
  }) => StudioDeployRow(
    draftId: draftId,
    owner: owner,
    state: state ?? this.state,
    agentWallet: agentWallet,
    registrationUri: registrationUri,
    manifestJson: manifestJson ?? this.manifestJson,
    updatedAt: updatedAt,
    preparationId: preparationId ?? this.preparationId,
    unsignedEnvelopeXdr: unsignedEnvelopeXdr ?? this.unsignedEnvelopeXdr,
    authorizationEntryXdr: clearAuthorization
        ? null
        : authorizationEntryXdr ?? this.authorizationEntryXdr,
    signatureExpirationLedger: clearAuthorization
        ? null
        : signatureExpirationLedger ?? this.signatureExpirationLedger,
    registrationHash: registrationHash ?? this.registrationHash,
    walletTxHash: walletTxHash ?? this.walletTxHash,
    registryAgentId: registryAgentId ?? this.registryAgentId,
    expiresAt: expiresAt ?? this.expiresAt,
    failureCode: clearFailure ? null : failureCode ?? this.failureCode,
    retryFromStep: clearFailure ? null : retryFromStep ?? this.retryFromStep,
    walletAuthJson: walletAuthJson ?? this.walletAuthJson,
  );
}

/// Persistence for [StudioDeployRow]. One row per draft.
abstract interface class StudioDeployStore {
  Future<StudioDeployRow?> findByDraft(int draftId);

  /// The active deploy whose registration URI ends with [hash], if any.
  Future<StudioDeployRow?> findByManifestHash(String hash);

  /// The deploy that registered [agentId], if any.
  Future<StudioDeployRow?> findByRegistryAgent(int agentId);

  /// Inserts [row], or replaces the row of the same draft.
  Future<StudioDeployRow> save(StudioDeployRow row);
}

/// Process-local [StudioDeployStore]. A restart drops in-flight envelopes;
/// the custodied wallet is stored separately and is reused.
final class MemoryStudioDeployStore implements StudioDeployStore {
  final _rows = <int, StudioDeployRow>{};

  @override
  Future<StudioDeployRow?> findByDraft(int draftId) async => _rows[draftId];

  @override
  Future<StudioDeployRow?> findByManifestHash(String hash) async {
    for (final row in _rows.values) {
      if (row.registrationUri.endsWith('/$hash')) return row;
    }
    return null;
  }

  @override
  Future<StudioDeployRow?> findByRegistryAgent(int agentId) async {
    for (final row in _rows.values) {
      if (row.registryAgentId == agentId) return row;
    }
    return null;
  }

  @override
  Future<StudioDeployRow> save(StudioDeployRow row) async {
    _rows[row.draftId] = row;
    return row;
  }
}

/// The simulated `set_agent_wallet` call, enough to rebuild the envelope
/// after the builder signs their entry.
final class WalletAuthDraft {
  const WalletAuthDraft({
    required this.accountSequence,
    required this.validUntil,
    required this.inclusionFee,
    required this.minResourceFee,
    required this.transactionData,
    required this.auth,
    required this.builderIndex,
  });

  final int accountSequence;
  final int validUntil;
  final int inclusionFee;
  final int minResourceFee;
  final String transactionData;
  final List<String> auth;
  final int builderIndex;

  String toJson() => jsonEncode({
    'accountSequence': accountSequence,
    'validUntil': validUntil,
    'inclusionFee': inclusionFee,
    'minResourceFee': minResourceFee,
    'transactionData': transactionData,
    'auth': auth,
    'builderIndex': builderIndex,
  });

  static WalletAuthDraft parse(String json) {
    final raw = jsonDecode(json);
    if (raw is! Map) throw const FormatException('wallet auth');
    final auth = raw['auth'];
    return WalletAuthDraft(
      accountSequence: raw['accountSequence'] as int,
      validUntil: raw['validUntil'] as int,
      inclusionFee: raw['inclusionFee'] as int,
      minResourceFee: raw['minResourceFee'] as int,
      transactionData: raw['transactionData'] as String,
      auth: [for (final entry in auth as List) entry as String],
      builderIndex: raw['builderIndex'] as int,
    );
  }
}
