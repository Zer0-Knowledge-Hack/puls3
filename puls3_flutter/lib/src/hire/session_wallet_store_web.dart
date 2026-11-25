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

/// The browser's `localStorage` as [SessionWalletStorage]: which wallet the
/// stored Serverpod session belongs to survives a reload, like the session
/// the client keeps, so a reload does not ask for a new sign-in (#334 T8.2).
/// It holds a public address only.
final class _LocalStorage implements SessionWalletStorage {
  const _LocalStorage(this._storage);

  final _Storage _storage;

  @override
  String? getItem() => _storage.getItem(_key.toJS)?.toDart;

  @override
  void setItem(String wallet) => _storage.setItem(_key.toJS, wallet.toJS);

  @override
  void removeItem() => _storage.removeItem(_key.toJS);
}

/// `localStorage`, or memory when the browser blocks it or a write fails
/// ([FallbackSessionWalletStore]).
SessionWalletStore createSessionWalletStore() {
  _Storage? storage;
  try {
    storage = _localStorage;
  } on Object {
    // Blocked (for example by a privacy setting): memory only.
  }
  return FallbackSessionWalletStore(
    storage == null ? null : _LocalStorage(storage),
  );
}
