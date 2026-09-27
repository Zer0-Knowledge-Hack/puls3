import 'package:test/test.dart';

void main() {
  test('intentional CI negative proof', () {
    expect(true, isFalse, reason: 'This test must fail to prove the domain gate blocks the PR.');
  });
}
