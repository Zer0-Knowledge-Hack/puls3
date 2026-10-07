import '../domain/stellar_format.dart';
import 'wallet_port.dart';

/// Fake wallet for tests and the demo console (#32). It never touches a
/// network or a real key: its "signed" payloads are placeholders a real
/// server would reject.
class MockWallet implements WalletPort {
  MockWallet({
    FakeLedgerIds? ids,
    this.connectDelay = const Duration(milliseconds: 500),
    this.signDelay = const Duration(milliseconds: 1200),
  }) : _ids = ids ?? FakeLedgerIds();

  /// Prefix of every payload this wallet "signs".
  static const signedPrefix = 'mock-signed:';

  final FakeLedgerIds _ids;
  final Duration connectDelay;
  final Duration signDelay;

  @override
  String get name => 'Demo wallet';

  @override
  Uri? get installUrl => null;

  /// The network the simulated wallet is on. Set it to the public network
  /// passphrase to reproduce the wrong-network error.
  String walletNetwork = stellarTestnetPassphrase;

  /// While true, connection requests are declined, as if the user pressed
  /// "Reject" in the wallet's connect prompt.
  bool rejectConnection = false;

  /// While true, every signature request is declined with
  /// [WalletSignatureRejected].
  bool rejectSignatures = false;

  /// When set, connection and signature requests fail with it, for example
  /// [WalletNotInstalled], [WalletUnavailable] or [WalletWrongNetwork].
  WalletException? failure;

  String? _address;

  @override
  String? get address => _address;

  @override
  String? get network => _address == null ? null : walletNetwork;

  @override
  Future<void> disconnect() async => _address = null;

  /// Simulates the user switching to another account in the wallet.
  void switchAccount() => _address = _ids.accountAddress();

  @override
  Future<String> connect() async {
    await Future<void>.delayed(connectDelay);
    final failure = this.failure;
    if (failure != null) throw failure;
    if (rejectConnection) throw const WalletSignatureRejected();
    if (walletNetwork != stellarTestnetPassphrase) {
      throw const WalletWrongNetwork();
    }
    return _address ??= _ids.accountAddress();
  }

  /// Returns [unsignedXdr] marked as signed: a stand-in for the signed
  /// envelope a real wallet returns, not a valid Stellar signature.
  @override
  Future<String> signTransaction(String unsignedXdr) => _sign(unsignedXdr);

  @override
  Future<String> signAuthEntry(String entryXdr) => _sign(entryXdr);

  Future<String> _sign(String payload) async {
    if (_address == null) await connect();
    await Future<void>.delayed(signDelay);
    final failure = this.failure;
    if (failure != null) throw failure;
    if (rejectSignatures) throw const WalletSignatureRejected();
    if (walletNetwork != stellarTestnetPassphrase) {
      throw const WalletWrongNetwork();
    }
    return '$signedPrefix$payload';
  }
}
