import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('shows the backend version returned by the health call', (
    tester,
  ) async {
    await pumpApp(tester, healthCheck: Future.value('1.0.0'));
    await tester.pump();

    expect(find.text('Backend v1.0.0'), findsOneWidget);
  });
}
