import 'dart:js_interop';

import 'wallet_session.dart';

@JS('localStorage')
external _Storage? get _localStorage;

extension type _Storage(JSObject _) implements JSObject {
  external JSString? getItem(JSString key);
  external void setItem(JSString key, JSString value);
  external void removeItem(JSString key);
}

const _key = 'puls3.sessionWallet';

/// The browser's `localStorage`: which wallet the stored Serverpod session
/// belongs to survives a reload, like the session the client keeps, so a
/// reload does not ask for a new sign-in (#334 T8.2). It holds a public
/// address only. When storage is blocked it falls back to memory.
class BrowserSessionWalletStore implements SessionWalletStore {
  final _fallback = InMemorySessionWalletStore();

  @override
  Future<String?> read() async {
    try {
      final storage = _localStorage;
      if (storage != null) return storage.getItem(_key.toJS)?.toDart;
    } on Object {
      // Storage blocked: use the memory copy.
    }
    return _fallback.read();
  }

  @override
  Future<void> write(String? wallet) async {
    await _fallback.write(wallet);
    try {
      final storage = _localStorage;
      if (wallet == null) {
        storage?.removeItem(_key.toJS);
      } else {
        storage?.setItem(_key.toJS, wallet.toJS);
      }
    } on Object {
      // Storage blocked or full: the memory copy still serves this visit.
    }
  }
}

SessionWalletStore createSessionWalletStore() => BrowserSessionWalletStore();
