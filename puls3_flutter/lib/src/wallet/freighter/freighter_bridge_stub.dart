import '../wallet_port.dart';
import 'freighter_bridge.dart';

/// Off the web (tests on the Dart VM, desktop builds) there is no Freighter:
/// every call reports [WalletNotInstalled].
FreighterBridge createFreighterBridge() => const _NoFreighter();

final class _NoFreighter implements FreighterBridge {
  const _NoFreighter();

  @override
  Future<FreighterSession> connect() async => throw const WalletNotInstalled();

  @override
  Future<FreighterSession> currentSession() async =>
      throw const WalletNotInstalled();

  @override
  Future<String> signTransaction(
    String xdr,
    String networkPassphrase,
    String address,
  ) async => throw const WalletNotInstalled();

  @override
  Future<AuthEntrySignature> signAuthEntryPreimage(
    String preimageXdr,
    String networkPassphrase,
    String address,
  ) async => throw const WalletNotInstalled();
}
