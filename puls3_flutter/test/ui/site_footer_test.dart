import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('footer Brand link opens the brand page', (tester) async {
    await pumpApp(tester);

    final link = find.widgetWithText(TextButton, 'Brand');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await advance(tester, const Duration(milliseconds: 800));

    expect(find.text('Brand guidelines'), findsOneWidget);
    expect(find.text('The agent hub on Stellar.'), findsNothing);
  });
}
