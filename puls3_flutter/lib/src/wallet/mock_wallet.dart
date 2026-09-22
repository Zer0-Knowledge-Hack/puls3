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

  String? _address;

  @override
  String? get address => _address;

  @override
  Future<String> connect() async {
    await Future<void>.delayed(connectDelay);
    return _address ??= _ids.accountAddress();
  }

  @override
  Future<String> signTransaction(String unsignedXdr) async {
    if (_address == null) await connect();
    await Future<void>.delayed(signDelay);
    return _ids.txHash();
  }
}
