import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('never shows backend status text to visitors', (tester) async {
    await pumpApp(tester);

    expect(find.textContaining('Backend'), findsNothing);
    expect(find.textContaining('backend'), findsNothing);
  });
}
