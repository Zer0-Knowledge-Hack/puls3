import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/l10n/locale_controller.dart';
import 'package:puls3_flutter/src/l10n/locale_store.dart';

void main() {
  test('parseSavedLocale accepts BCP-47 and underscore tags', () {
    expect(parseSavedLocale('en'), const Locale('en'));
    expect(parseSavedLocale('es'), const Locale('es'));
    expect(parseSavedLocale('pt-BR'), const Locale('pt', 'BR'));
    expect(parseSavedLocale('pt_PT'), const Locale('pt', 'PT'));
    expect(parseSavedLocale('fr'), isNull);
    expect(parseSavedLocale(null), isNull);
  });

  test('resolveDeviceLocale maps pt without region to pt_BR', () {
    expect(resolveDeviceLocale(const Locale('pt')), const Locale('pt', 'BR'));
    expect(
      resolveDeviceLocale(const Locale('pt', 'PT')),
      const Locale('pt', 'PT'),
    );
    expect(
      resolveDeviceLocale(const Locale('es', 'AR')),
      const Locale('es'),
    );
    expect(resolveDeviceLocale(const Locale('fr')), const Locale('en'));
    expect(resolveDeviceLocale(null), const Locale('en'));
  });

  test('setLocale persists the language tag', () {
    final store = MemoryLocaleStore();
    final controller = LocaleController(
      store: store,
      initial: const Locale('en'),
    );
    controller.setLocale(const Locale('pt', 'PT'));
    expect(store.read(), 'pt-PT');
    expect(controller.locale, const Locale('pt', 'PT'));
  });

  test('saved tag wins over the device locale', () {
    final controller = LocaleController(
      store: MemoryLocaleStore('es'),
      deviceLocale: const Locale('en', 'US'),
    );
    expect(controller.locale, const Locale('es'));
  });
}
