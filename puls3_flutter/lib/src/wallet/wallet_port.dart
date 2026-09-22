/// Port for anything that can hold a Stellar account and sign transactions.
///
/// The demo ships only [MockWallet]; a real adapter (Freighter, passkeys,
/// Stellar Wallets Kit) can implement this without touching the UI.
abstract interface class WalletPort {
  /// Connects the wallet and returns the public Stellar address.
  Future<String> connect();

  /// The connected public address, or null while disconnected.
  String? get address;

  /// Signs and submits [unsignedXdr]. Returns the transaction hash.
  Future<String> signTransaction(String unsignedXdr);
}
