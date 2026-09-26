import 'package:test/test.dart';

import 'package:puls3_server/src/health/health_endpoint.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Given Health endpoint', (sessionBuilder, endpoints) {
    test('when checking health then it returns the app version', () async {
      final health = await endpoints.health.check(sessionBuilder);

      expect(health.version, HealthEndpoint.appVersion);
    });
  });
}
