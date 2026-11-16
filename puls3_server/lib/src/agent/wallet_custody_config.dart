import 'dart:convert';

import 'agent_wallet_custody.dart';

/// The Serverpod password that holds the custody key.
///
/// On Serverpod Cloud, set it with
/// `scloud password set agentWalletSecretKey --from-file <file>`: passwords are
/// write-only, while variables are listed in plain text.
const agentWalletSecretKeyPassword = 'agentWalletSecretKey';

const _environmentName = 'PULS3_AGENT_WALLET_SECRET_KEY';

/// The key that encrypts custodied agent secrets (ADR-0003 decision 4, #18;
/// the secret is managed per #30).
///
/// A base64-encoded 32-byte key, read from the Serverpod password
/// [agentWalletSecretKeyPassword] or, when that is not set, from
/// `PULS3_AGENT_WALLET_SECRET_KEY` (local `.env` and the tools). It is a
/// secret: it never appears in `.env.example` with a value, is never logged,
/// and MUST NOT be included in an error message. The value is trimmed before
/// decoding, because keys pasted from `.env` files often carry a trailing
/// newline.
final class WalletCustodyConfig {
  const WalletCustodyConfig({required this.secretKey, this.keyVersion = 1});

  /// Reads the key from [password] (normally
  /// `Serverpod.instance.getPassword(agentWalletSecretKeyPassword)`), or from
  /// [env] (normally `Platform.environment`) when [password] is null or blank.
  ///
  /// Throws [AgentWalletCustodyUnavailable] when neither is set, and
  /// [ArgumentError] when the key is not base64 or not 32 bytes. The errors
  /// never contain the value.
  factory WalletCustodyConfig.fromEnvironment(
    Map<String, String> env, {
    String? password,
  }) {
    final fromPassword = password?.trim();
    final String name;
    final String? raw;
    if (fromPassword != null && fromPassword.isNotEmpty) {
      name = agentWalletSecretKeyPassword;
      raw = fromPassword;
    } else {
      name = _environmentName;
      raw = env[_environmentName]?.trim();
    }
    if (raw == null || raw.isEmpty) {
      throw const AgentWalletCustodyUnavailable(
        'neither the $agentWalletSecretKeyPassword password nor '
        '$_environmentName is set; agent wallet custody is unavailable',
      );
    }
    final List<int> decoded;
    try {
      decoded = base64.decode(raw);
    } on FormatException {
      throw ArgumentError('$name must be base64');
    }
    if (decoded.length != 32) {
      throw ArgumentError('$name must decode to 32 bytes');
    }
    return WalletCustodyConfig(secretKey: decoded);
  }

  /// The 32-byte AES-256 key.
  final List<int> secretKey;

  /// The version new secrets are written under; stored with each secret so the
  /// key can be rotated later.
  final int keyVersion;
}
