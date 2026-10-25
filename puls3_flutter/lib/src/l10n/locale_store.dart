/// Persists the user's language tag (`en`, `es`, `pt-BR`, `pt-PT`).
abstract interface class LocaleStore {
  String? read();
  void write(String languageTag);
}

/// In memory: survives the session, not a reload. Used in tests and on
/// platforms without browser storage.
class MemoryLocaleStore implements LocaleStore {
  MemoryLocaleStore([this._value]);

  String? _value;

  @override
  String? read() => _value;

  @override
  void write(String languageTag) => _value = languageTag;
}

/// Browser `localStorage` key. Not a secret.
const localeStorageKey = 'puls3.locale';
