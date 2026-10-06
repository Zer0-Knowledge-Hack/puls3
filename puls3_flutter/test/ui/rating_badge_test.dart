import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/ui/atoms/rating_badge.dart';

Future<void> pumpBadge(WidgetTester tester, double rating) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: RatingBadge(rating: rating)),
  ),
);

void main() {
  testWidgets('a zero rating renders nothing', (tester) async {
    await pumpBadge(tester, 0.0);

    expect(find.byType(RatingBadge), findsOneWidget);
    expect(find.byType(Text), findsNothing);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('a negative rating renders nothing', (tester) async {
    await pumpBadge(tester, -1.0);

    expect(find.byType(RatingBadge), findsOneWidget);
    expect(find.byType(Text), findsNothing);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('a rated agent shows the star and one decimal', (tester) async {
    await pumpBadge(tester, 4.5);

    expect(find.text('4.5'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });

  testWidgets('the maximum rating shows 5.0', (tester) async {
    await pumpBadge(tester, 5.0);

    expect(find.text('5.0'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });
}
