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

  Future<String> failing() => Future<String>.error('down')..ignore();

  testWidgets('shows "Backend unavailable" on app screens', (tester) async {
    await pumpApp(tester, healthCheck: failing());
    await tester.pump();

    expect(find.text('Backend unavailable'), findsOneWidget);
  });

  testWidgets('hides the backend banner on /brand', (tester) async {
    await pumpApp(tester, location: '/brand', healthCheck: failing());
    await tester.pump();

    expect(find.text('Backend unavailable'), findsNothing);
    expect(find.text('Brand guidelines'), findsOneWidget);
  });
}
