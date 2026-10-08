/// What Freighter reports for the active account.
class FreighterSession {
  const FreighterSession({
    required this.address,
    required this.networkPassphrase,
  });

  final String address;
  final String networkPassphrase;
}

/// Freighter's answer to an auth-entry preimage signing request.
class AuthEntrySignature {
  const AuthEntrySignature({required this.signature, this.signerAddress});

  /// Base64 of the raw 64-byte ed25519 signature.
  final String signature;

  /// Signer reported by the wallet, when it reports one.
  final String? signerAddress;
}

/// The calls [FreighterWallet] makes into the Freighter extension. The web
/// implementation goes through JS interop; tests use a fake.
///
/// Every method throws a `WalletException` on failure (not installed,
/// rejected, wrong network, account changed), never a raw JS error.
abstract interface class FreighterBridge {
  /// Asks for access and returns the active account and network.
  Future<FreighterSession> connect();

  /// The active account and network, without prompting.
  Future<FreighterSession> currentSession();

  /// Signs [xdr] for [address] on [networkPassphrase]; returns the signed
  /// envelope XDR.
  Future<String> signTransaction(
    String xdr,
    String networkPassphrase,
    String address,
  );

  /// Mirrors Freighter's `signAuthEntry`: [preimageXdr] is the base64 XDR of
  /// a `HashIdPreimage`, and the wallet answers with an ed25519 signature
  /// over sha256(preimage), not with a signed entry.
  Future<AuthEntrySignature> signAuthEntryPreimage(
    String preimageXdr,
    String networkPassphrase,
    String address,
  );
}
