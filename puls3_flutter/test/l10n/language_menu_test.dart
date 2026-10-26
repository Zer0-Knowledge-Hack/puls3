import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/l10n/locale_store.dart';

import '../helpers.dart';

void main() {
  testWidgets('picking Español updates the landing headline', (tester) async {
    final store = MemoryLocaleStore();
    await pumpApp(tester, localeStore: store);

    expect(
      find.text('Your AI works. It still can\'t get paid.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('language-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Español').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('Tu IA trabaja. Todavía no cobra.'),
      findsOneWidget,
    );
    expect(find.text('Ya usas IA. ¿Puede cobrar?'), findsOneWidget);
    expect(find.text('Press Hire'), findsNothing);
    expect(find.text('Presiona Contratar'), findsOneWidget);
    expect(store.read(), 'es');
  });

  testWidgets('pt-BR and pt-PT are distinct catalogs', (tester) async {
    await pumpApp(tester, locale: const Locale('pt', 'BR'));
    expect(find.textContaining('ser concluído'), findsWidgets);
    expect(find.textContaining('estar concluído'), findsNothing);

    await pumpApp(tester, locale: const Locale('pt', 'PT'));
    expect(find.textContaining('estar concluído'), findsWidgets);
    expect(find.textContaining('ser concluído'), findsNothing);
  });

  testWidgets('a saved locale is restored on a first visit', (tester) async {
    await pumpApp(
      tester,
      localeStore: MemoryLocaleStore('es'),
      locale: null,
    );
    expect(
      find.text('Tu IA trabaja. Todavía no cobra.'),
      findsOneWidget,
    );
  });

  testWidgets('Español localizes marketplace skills and studio fields', (
    tester,
  ) async {
    await pumpApp(
      tester,
      location: '/market',
      localeStore: MemoryLocaleStore('es'),
      locale: null,
    );
    expect(find.text('Análisis on-chain'), findsWidgets);
    expect(find.textContaining('Monitorea cuentas'), findsWidgets);

    await pumpApp(
      tester,
      location: '/studio',
      localeStore: MemoryLocaleStore('es'),
      locale: null,
    );
    expect(find.text('Nombre del agente'), findsOneWidget);
    expect(find.text('Guardar borrador'), findsOneWidget);
  });

  testWidgets('the language menu fits a phone landing', (tester) async {
    await pumpApp(tester, size: const Size(390, 844));
    expect(find.byKey(const Key('language-menu')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
