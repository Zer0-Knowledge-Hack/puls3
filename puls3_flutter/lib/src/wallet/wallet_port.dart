/// The Stellar Testnet passphrase: the only network the MVP accepts.
const stellarTestnetPassphrase = 'Test SDF Network ; September 2015';

/// Port for anything that can hold a Stellar account and sign transactions
/// (#25, ADR-0003).
///
/// Adapters: [FreighterWallet] in Chrome and [MockWallet] for tests and the
/// demo console (#32). It is the only signing boundary: keys and seeds never
/// leave the wallet, and the app never submits a transaction itself (API
/// contract #77, Decision A).
abstract interface class WalletPort {
  /// The wallet's name for the UI, for example "Freighter".
  String get name;

  /// Where to install the wallet when it is missing, if it has such a page.
  Uri? get installUrl;

  /// Connects the wallet and returns the public Stellar address.
  ///
  /// Throws a [WalletException]: [WalletWrongNetwork] when the wallet is not
  /// on Stellar Testnet, [WalletSignatureRejected] when the user declines,
  /// [WalletNotInstalled] when there is no wallet.
  Future<String> connect();

  /// Forgets the connection. Nothing is signed or revoked on chain.
  Future<void> disconnect();

  /// The connected public address (`G…`), or null while disconnected.
  String? get address;

  /// The connected wallet's network passphrase, or null while disconnected.
  String? get network;

  /// Signs the server-prepared transaction [unsignedXdr] unchanged and
  /// returns the signed envelope as base64 XDR. The server submits it.
  ///
  /// Throws a [WalletException], for example [WalletSignatureRejected] when
  /// the user declines or [WalletInvalidPayload] when the envelope is not
  /// one the connected account can safely sign.
  Future<String> signTransaction(String unsignedXdr);

  /// Signs a server-simulated Soroban authorization entry for the connected
  /// account (ADR-0003: the builder's step of `set_agent_wallet`, #18) and
  /// returns the signed entry as base64 XDR.
  Future<String> signAuthEntry(String entryXdr);
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

/// No supported wallet is installed in this browser.
final class WalletNotInstalled extends WalletException {
  const WalletNotInstalled();
}

/// A wallet is installed but cannot be used now (locked, not connected).
final class WalletUnavailable extends WalletException {
  const WalletUnavailable();
}

/// The wallet is on another network than Stellar Testnet.
final class WalletWrongNetwork extends WalletException {
  const WalletWrongNetwork();
}

/// The active wallet account is not the one the app connected to.
final class WalletAccountChanged extends WalletException {
  const WalletAccountChanged();
}

/// The payload is not one the connected account can safely sign: malformed
/// XDR, an unsupported envelope, another account's transaction, or a wallet
/// answer that changed it. Rejected before the wallet prompt when possible.
final class WalletInvalidPayload extends WalletException {
  const WalletInvalidPayload(this.reason);

  /// A short technical reason, safe to show under "details".
  final String reason;

  @override
  String toString() => 'WalletInvalidPayload: $reason';
}
