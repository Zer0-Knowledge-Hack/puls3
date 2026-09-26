import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

/// Reports whether the backend is reachable and which app version it runs.
class HealthEndpoint extends Endpoint {
  /// Must stay aligned with the server package version in `pubspec.yaml`.
  static const appVersion = '1.0.0';

  /// Returns basic health information without requiring authentication.
  Future<BackendHealth> check(Session session) async {
    return BackendHealth(version: appVersion);
  }
}
