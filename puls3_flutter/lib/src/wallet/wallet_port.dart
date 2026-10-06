/// Port for anything that can hold a Stellar account and sign transactions.
///
/// The demo ships only [MockWallet]; a real adapter (Freighter, passkeys,
/// Stellar Wallets Kit) can implement this without touching the UI. It is
/// the only signing boundary: keys and seeds never leave the wallet.
abstract interface class WalletPort {
  /// Connects the wallet and returns the public Stellar address.
  ///
  /// Throws a [WalletException] when the wallet cannot be used.
  Future<String> connect();

  /// The connected public address, or null while disconnected.
  String? get address;

  /// Forgets the connection. Nothing is signed or revoked on chain.
  Future<void> disconnect();

  /// Signs and submits [unsignedXdr]. Returns the transaction hash.
  ///
  /// Throws a [WalletException], for example [WalletSignatureRejected] when
  /// the user declines the request.
  Future<String> signTransaction(String unsignedXdr);
}

/// Why the wallet could not connect or sign. Nothing was signed, so the
/// request can be made again once the cause is fixed.
sealed class WalletException implements Exception {
  const WalletException();

  @override
  String toString() => '$runtimeType';
}

/// The user declined a connection or signature request in the wallet.
final class WalletSignatureRejected extends WalletException {
  const WalletSignatureRejected();
}

/// No wallet is installed, unlocked or connected.
final class WalletUnavailable extends WalletException {
  const WalletUnavailable();
}

/// The wallet is on another network than the app (for example mainnet).
final class WalletWrongNetwork extends WalletException {
  const WalletWrongNetwork();
}
