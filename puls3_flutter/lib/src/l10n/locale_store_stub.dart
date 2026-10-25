import 'locale_store.dart';

/// Without browser storage, the locale lives for the session.
LocaleStore createLocaleStore() => MemoryLocaleStore();
