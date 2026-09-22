import 'package:flutter/foundation.dart';

import '../wallet/wallet_port.dart';

/// Observable wrapper around a [WalletPort] for the UI.
class WalletController extends ChangeNotifier {
  WalletController(this._wallet);

  final WalletPort _wallet;
  bool _connecting = false;

  String? get address => _wallet.address;
  bool get isConnected => _wallet.address != null;
  bool get isConnecting => _connecting;

  Future<String> connect() async {
    final existing = _wallet.address;
    if (existing != null) return existing;
    _connecting = true;
    notifyListeners();
    try {
      return await _wallet.connect();
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  Future<String> signTransaction(String unsignedXdr) async {
    final hash = await _wallet.signTransaction(unsignedXdr);
    notifyListeners();
    return hash;
  }
}
