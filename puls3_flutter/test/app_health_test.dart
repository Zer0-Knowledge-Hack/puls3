import 'dart:async';

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

  // The health call fails after the app is up, like a real request. The
  // error is not pre-handled: on /brand nothing renders the banner, so the
  // app itself must handle it (unhandled, it is "Uncaught" on web).
  Future<void> pumpWithFailingHealth(
    WidgetTester tester, {
    String location = '/',
  }) async {
    final health = Completer<String>();
    await pumpApp(tester, location: location, healthCheck: health.future);
    health.completeError(Exception('down'));
    await tester.pump();
  }

  testWidgets('shows "Backend unavailable" on app screens', (tester) async {
    await pumpWithFailingHealth(tester);

    expect(find.text('Backend unavailable'), findsOneWidget);
  });

  testWidgets('hides the backend banner on /brand without an uncaught error', (
    tester,
  ) async {
    await pumpWithFailingHealth(tester, location: '/brand');

    expect(tester.takeException(), isNull);
    expect(find.text('Backend unavailable'), findsNothing);
    expect(find.text('Brand guidelines'), findsOneWidget);
  });
}
