import '../domain/stellar_format.dart';
import 'wallet_port.dart';

/// Fake wallet for the demo. It never touches a network or a real key.
class MockWallet implements WalletPort {
  MockWallet({
    FakeLedgerIds? ids,
    this.connectDelay = const Duration(milliseconds: 500),
    this.signDelay = const Duration(milliseconds: 1200),
  }) : _ids = ids ?? FakeLedgerIds();

  final FakeLedgerIds _ids;
  final Duration connectDelay;
  final Duration signDelay;

  /// While true, every signature request is declined with
  /// [WalletSignatureRejected], as if the user pressed "Reject".
  bool rejectSignatures = false;

  /// When set, connection and signature requests fail with it, for example
  /// [WalletUnavailable] or [WalletWrongNetwork].
  WalletException? failure;

  String? _address;

  @override
  String? get address => _address;

  @override
  Future<void> disconnect() async => _address = null;

  /// Simulates the user switching to another account in the wallet.
  void switchAccount() => _address = _ids.accountAddress();

  @override
  Future<String> connect() async {
    await Future<void>.delayed(connectDelay);
    final failure = this.failure;
    if (failure != null) throw failure;
    return _address ??= _ids.accountAddress();
  }

  @override
  Future<String> signTransaction(String unsignedXdr) async {
    if (_address == null) await connect();
    await Future<void>.delayed(signDelay);
    final failure = this.failure;
    if (failure != null) throw failure;
    if (rejectSignatures) throw const WalletSignatureRejected();
    return _ids.txHash();
  }
}
