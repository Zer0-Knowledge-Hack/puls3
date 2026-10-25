import 'package:flutter/widgets.dart';

import 'locale_store.dart';

/// The languages the app ships. English is the fallback.
const supportedAppLocales = <Locale>[
  Locale('en'),
  Locale('es'),
  Locale('pt', 'BR'),
  Locale('pt', 'PT'),
];

/// Holds the active [Locale], persists it, and notifies the app root so
/// [MaterialApp] rebuilds with the new copy.
class LocaleController extends ChangeNotifier {
  LocaleController({
    required this.store,
    Locale? deviceLocale,
    Locale? initial,
  }) {
    _locale =
        initial ??
        parseSavedLocale(store.read()) ??
        resolveDeviceLocale(deviceLocale);
  }

  final LocaleStore store;
  late Locale _locale;

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    final resolved = canonicalLocale(locale) ?? const Locale('en');
    if (resolved == _locale) return;
    _locale = resolved;
    store.write(languageTag(resolved));
    notifyListeners();
  }
}

/// `en`, `es`, `pt-BR`, `pt-PT`.
String languageTag(Locale locale) {
  final country = locale.countryCode;
  if (country == null || country.isEmpty) return locale.languageCode;
  return '${locale.languageCode}-$country';
}

/// Reads a tag we wrote (`en`, `es`, `pt-BR`) or a common variant (`pt_BR`).
Locale? parseSavedLocale(String? raw) {
  if (raw == null) return null;
  final tag = raw.trim().replaceAll('_', '-');
  if (tag.isEmpty) return null;
  final parts = tag.split('-');
  final language = parts.first.toLowerCase();
  final country = parts.length > 1 ? parts[1].toUpperCase() : null;
  return canonicalLocale(
    country == null ? Locale(language) : Locale(language, country),
  );
}

/// Maps a device locale onto [supportedAppLocales]. A bare `pt` becomes
/// `pt_BR`. Anything else falls back to English.
Locale resolveDeviceLocale(Locale? device) {
  if (device == null) return const Locale('en');
  final matched = canonicalLocale(device);
  if (matched != null) return matched;
  if (device.languageCode == 'pt') return const Locale('pt', 'BR');
  return const Locale('en');
}

/// The supported locale that [candidate] should use, or null if none match.
Locale? canonicalLocale(Locale candidate) {
  for (final supported in supportedAppLocales) {
    if (supported.languageCode != candidate.languageCode) continue;
    final country = supported.countryCode;
    if (country == null || country.isEmpty) return supported;
    if (country == candidate.countryCode) return supported;
  }
  return null;
}
