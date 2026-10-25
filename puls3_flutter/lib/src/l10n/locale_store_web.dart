import 'dart:js_interop';

import 'locale_store.dart';

@JS('localStorage')
external _Storage? get _localStorage;

extension type _Storage(JSObject _) implements JSObject {
  external JSString? getItem(JSString key);
  external void setItem(JSString key, JSString value);
}

/// The browser's `localStorage`: the language survives a reload. When
/// storage is blocked (private mode, disabled site data) it keeps the
/// tag in memory, so the choice still holds for the session.
class BrowserLocaleStore implements LocaleStore {
  final _fallback = MemoryLocaleStore();

  @override
  String? read() {
    try {
      final storage = _localStorage;
      if (storage != null) {
        return storage.getItem(localeStorageKey.toJS)?.toDart;
      }
    } on Object {
      // Storage blocked: use the session copy.
    }
    return _fallback.read();
  }

  @override
  void write(String languageTag) {
    _fallback.write(languageTag);
    try {
      _localStorage?.setItem(localeStorageKey.toJS, languageTag.toJS);
    } on Object {
      // Storage blocked or full: the session copy still holds.
    }
  }
}

LocaleStore createLocaleStore() => BrowserLocaleStore();
