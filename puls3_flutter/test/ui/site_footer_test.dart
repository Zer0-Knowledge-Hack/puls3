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

  testWidgets('navigating to /brand hides the backend banner', (tester) async {
    await pumpApp(tester, healthCheck: Future.value('1.0.0'));
    await tester.pump();
    expect(find.text('Backend v1.0.0'), findsOneWidget);

    final link = find.widgetWithText(TextButton, 'Brand');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await advance(tester, const Duration(milliseconds: 800));

    expect(find.text('Backend v1.0.0'), findsNothing);
  });
}
