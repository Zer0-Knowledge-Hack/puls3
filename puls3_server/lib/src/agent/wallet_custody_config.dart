import 'dart:convert';

import 'agent_wallet_custody.dart';

/// The key that encrypts custodied agent secrets (ADR-0003 decision 4, #30).
///
/// Read from `PULS3_AGENT_WALLET_SECRET_KEY`, a base64-encoded 32-byte key.
/// It is a secret: it never appears in `.env.example` with a value and is
/// never logged. When it is unset, custody is unavailable, so a missing
/// configuration is reported instead of weakening storage.
final class WalletCustodyConfig {
  const WalletCustodyConfig({required this.secretKey, this.keyVersion = 1});

  /// Reads the key from [env] (normally `Platform.environment`).
  ///
  /// Throws [AgentWalletCustodyUnavailable] when the variable is unset, and
  /// [ArgumentError] when it is not base64 or not 32 bytes.
  factory WalletCustodyConfig.fromEnvironment(Map<String, String> env) {
    const name = 'PULS3_AGENT_WALLET_SECRET_KEY';
    final raw = env[name];
    if (raw == null || raw.isEmpty) {
      throw const AgentWalletCustodyUnavailable(
        'PULS3_AGENT_WALLET_SECRET_KEY is not set; agent wallet custody is '
        'unavailable',
      );
    }
    final List<int> decoded;
    try {
      decoded = base64.decode(raw);
    } on FormatException {
      throw ArgumentError.value(raw, name, 'must be base64');
    }
    if (decoded.length != 32) {
      throw ArgumentError.value(raw, name, 'must decode to 32 bytes');
    }
    return WalletCustodyConfig(secretKey: decoded);
  }

  /// The 32-byte AES-256 key.
  final List<int> secretKey;

  /// Stored with each secret so the key can be rotated later.
  final int keyVersion;
}
