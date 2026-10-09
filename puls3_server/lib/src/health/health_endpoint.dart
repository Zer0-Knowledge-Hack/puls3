import 'dart:io';

import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'app_version.dart';

/// Reports whether the backend is reachable and which app version it runs.
class HealthEndpoint extends Endpoint {
  /// The running version: the package version, plus the deployed commit when
  /// `PULS3_GIT_SHA` is set (see [appVersionFromEnvironment]).
  static final appVersion = appVersionFromEnvironment(Platform.environment);

  /// Returns basic health information without requiring authentication.
  Future<BackendHealth> check(Session session) async {
    return BackendHealth(version: appVersion);
  }
}
