import 'package:flutter/foundation.dart';

import '../wallet/wallet_port.dart';

/// The wallet as the UI sees it.
enum WalletStatus { disconnected, connecting, connected, error }

/// Observable wrapper around a [WalletPort]: the container that owns the
/// connection state (#25). Presentational widgets get its values through
/// their constructors.
class WalletController extends ChangeNotifier {
  WalletController(this._wallet);

  final WalletPort _wallet;
  bool _connecting = false;
  WalletException? _lastError;

  String get walletName => _wallet.name;
  Uri? get installUrl => _wallet.installUrl;
  String? get address => _wallet.address;
  String? get network => _wallet.network;
  bool get isConnected => _wallet.address != null;
  bool get isConnecting => _connecting;
  bool get isOnTestnet => _wallet.network == stellarTestnetPassphrase;

  /// Why the last connection attempt from the UI failed, until the next one.
  WalletException? get lastError => _lastError;

  WalletStatus get status {
    if (_connecting) return WalletStatus.connecting;
    if (isConnected) return WalletStatus.connected;
    if (_lastError != null) return WalletStatus.error;
    return WalletStatus.disconnected;
  }

  /// Connects and returns the address. Throws a [WalletException] on
  /// failure, for flows that map it themselves (deploy, hire). UI buttons
  /// use [tryConnect] instead.
  Future<String> connect() async {
    final existing = _wallet.address;
    if (existing != null) return existing;
    _connecting = true;
    _lastError = null;
    notifyListeners();
    try {
      return await _wallet.connect();
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  /// Connects from a button: a failure becomes [lastError] (a recoverable
  /// state), never an unhandled exception. Returns whether it connected.
  Future<bool> tryConnect() async {
    if (_connecting) return false;
    try {
      await connect();
      return true;
    } on WalletException catch (e) {
      _lastError = e;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _wallet.disconnect();
    _lastError = null;
    notifyListeners();
  }

  /// Signs a server-prepared transaction unchanged; returns the signed XDR.
  Future<String> signTransaction(String unsignedXdr) async {
    final signed = await _wallet.signTransaction(unsignedXdr);
    notifyListeners();
    return signed;
  }

  /// Signs a Soroban authorization entry; returns the signed entry XDR.
  Future<String> signAuthEntry(String entryXdr) =>
      _wallet.signAuthEntry(entryXdr);
}
